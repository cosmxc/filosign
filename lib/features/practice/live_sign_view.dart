import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pose_detection/flutter_pose_detection.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

import '../../recognizer/sign_recognizer.dart';
import '../../recognizer/v4_sign_recognizer.dart';

/// Developer overlays (hand landmarks, top-3, debug capture button).
/// Off in normal builds; turn on with
/// `flutter build apk --dart-define=FILOSIGN_DEBUG_UI=true`.
const bool kShowDebugUi = bool.fromEnvironment('FILOSIGN_DEBUG_UI');

/// Snapshot of the live recognizer, sent to the parent after every frame.
class LiveSignState {
  final SignPrediction prediction;
  final bool locked;
  final List<MapEntry<String, double>> top3;
  final int handCount;
  final String head;
  final int latencyMs;
  final List<bool> present;
  final bool notRecognized;
  final bool bodyVisible;
  const LiveSignState({
    required this.prediction,
    required this.locked,
    required this.top3,
    required this.handCount,
    required this.head,
    required this.latencyMs,
    required this.present,
    this.notRecognized = false,
    this.bodyVisible = true,
  });
}

/// Front camera + MediaPipe Hands + Pose + v4 recognizer, with the hand
/// skeleton drawn on the preview. Used by live practice and the quiz.
/// Change [resetToken] (or [dominantLeft]) to start a fresh attempt.
class LiveSignView extends StatefulWidget {
  final List<String> candidates; // model labels allowed for this screen
  final bool letters; // letters head (alphabet) or words head
  final bool dominantLeft;
  final int resetToken;
  final ValueChanged<LiveSignState>? onUpdate;
  final bool active; // false = stop processing frames (camera stays open)
  /// Gives the parent the recognizer (used for the debug capture).
  final ValueChanged<V4SignRecognizer>? onRecognizer;

  const LiveSignView({
    super.key,
    required this.candidates,
    required this.letters,
    this.dominantLeft = false,
    this.resetToken = 0,
    this.active = true,
    this.onUpdate,
    this.onRecognizer,
  });
  @override
  State<LiveSignView> createState() => _LiveSignViewState();
}

class _LiveSignViewState extends State<LiveSignView> with WidgetsBindingObserver {
  CameraController? _controller;
  String? _cameraError;
  bool _streaming = false;
  int _lastSentMs = 0;
  int _lastPoseMs = 0;
  int _lastUpdateMs = 0;
  bool _lastLocked = false;
  int _lastPoseOkMs = 0;
  bool _disposed = false;

  // Serializes camera teardown/setup across LiveSignView instances, so a new
  // view never opens the front camera while the previous one is still closing.
  // Every job is isolated: a failure or hang in one never blocks the next.
  static Future<void> _lastTeardown = Future.value();

  static void _enqueue(Future<void> Function() job) {
    _lastTeardown = _lastTeardown
        .catchError((_) {})            // a previous failure never blocks the next job
        .then((_) => job())
        .catchError((_) {});
  }

  /// Runs [f] with a timeout; swallows failures and hangs. Used for every
  /// native dispose/stop call so one bad step can't wedge the chain.
  static Future<void> _quiet(FutureOr<void> Function() f) async {
    try {
      await Future.sync(f).timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  HandLandmarkerPlugin? _landmarker;
  StreamSubscription<List<Hand>>? _landmarkSub;
  List<Hand> _hands = const [];

  final NpuPoseDetector _pose =
      NpuPoseDetector(config: PoseDetectorConfig.realtime());
  bool _poseReady = false;
  bool _poseBusy = false;
  List<PoseLandmark> _latestPose = const [];

  late final V4SignRecognizer _recognizer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recognizer = V4SignRecognizer(letters: widget.letters)
      ..dominantLeft = widget.dominantLeft;
    _recognizer.init();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onRecognizer?.call(_recognizer));
    _pose.initialize().then((_) {
      if (mounted) setState(() => _poseReady = true);
    }).catchError((_) {});
    _landmarker = HandLandmarkerPlugin.create(
      numHands: 2,
      minHandDetectionConfidence: 0.5,
      delegate: HandLandmarkerDelegate.gpu,
    );
    _landmarkSub = _landmarker!.landmarkStream.listen((hands) {
      if (!mounted || _disposed || !widget.active) return;
      final p = _recognizer.addFrame(hands, _latestPose, widget.candidates);
      setState(() => _hands = hands);
      // The parent rebuilds on every update; ~8 per second is plenty for the
      // text and keeps the UI thread free (lock changes go out at once).
      final now = DateTime.now().millisecondsSinceEpoch;
      final locked = _recognizer.isLocked;
      if (now - _lastUpdateMs < 120 && locked == _lastLocked) return;
      _lastUpdateMs = now;
      _lastLocked = locked;
      widget.onUpdate?.call(LiveSignState(
        prediction: p,
        locked: _recognizer.isLocked,
        top3: _recognizer.top3,
        handCount: hands.length,
        head: _recognizer.headName,
        latencyMs: _recognizer.lastLatencyMs,
        present: _recognizer.lastPresent,
        notRecognized: _recognizer.notRecognized,
        bodyVisible: _recognizer.lastPoseOk,
      ));
    });
    _setupCamera();
  }

  @override
  void didUpdateWidget(covariant LiveSignView old) {
    super.didUpdateWidget(old);
    if (old.resetToken != widget.resetToken ||
        old.dominantLeft != widget.dominantLeft) {
      _recognizer.dominantLeft = widget.dominantLeft;
      _recognizer.reset();
    }
    if (old.active != widget.active) {
      if (widget.active) {
        _recognizer.reset();
        _startStream();
      } else {
        _stopStream();
      }
    }
  }

  Future<void> _setupCamera() async {
    // Bounded wait: a hung teardown can't block this view forever.
    try {
      await _lastTeardown.timeout(const Duration(seconds: 3));
    } catch (_) {}
    if (!mounted) return;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _cameraError = 'No cameras found on this device.');
        return;
      }
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        // 480p: at 240x320 the body/pose detector usually found nothing and hand
        // tracking dropped frames (teammate debug captures); training was 720p.
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) {
        await _quiet(controller.dispose);
        return;
      }
      setState(() => _controller = controller);
      await _startStream();
    } on CameraException catch (e) {
      if (mounted) {
        setState(() => _cameraError =
            'Camera error: ${e.code}\n${e.description ?? ''}\n\n'
            'If you denied the camera permission, enable it in Settings and reopen.');
      }
    }
  }

  Future<void> _startStream() async {
    final controller = _controller;
    final landmarker = _landmarker;
    if (controller == null || landmarker == null || _streaming) return;
    // Flip before the await so _setupCamera and didUpdateWidget can't both
    // enter and trigger "already streaming".
    _streaming = true;
    try {
      final orientation = controller.description.sensorOrientation;
      await controller.startImageStream((CameraImage image) {
        if (_disposed || !widget.active) return;
        if (!_recognizer.hasImageSize) {
          _recognizer.configureCamera(
              sensorOrientation: orientation,
              imageWidth: image.width,
              imageHeight: image.height);
        }
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastSentMs >= 33) {
          _lastSentMs = now;
          try {
            landmarker.processFrame(image, orientation);
          } catch (_) {}
        }
        // Pose frames are copied over the platform channel; 5 per second keeps
        // the UI thread responsive (the recognizer reuses the latest pose).
        if (now - _lastPoseMs >= 200) {
          _lastPoseMs = now;
          _feedPose(image, orientation);
        }
      });
    } catch (_) {
      _streaming = false;
    }
  }

  Future<void> _feedPose(CameraImage image, int orientation) async {
    if (!_poseReady || _poseBusy) return;
    _poseBusy = true;
    try {
      final planes = [
        for (final p in image.planes)
          {
            'bytes': p.bytes,
            'bytesPerRow': p.bytesPerRow,
            'bytesPerPixel': p.bytesPerPixel ?? 1,
          }
      ];
      final res = await _pose.processFrame(
        planes: planes,
        width: image.width,
        height: image.height,
        format: 'yuv420',
        rotation: orientation,
      );
      if (_disposed) return;
      // Keep the last good pose for a moment when one detection fails, so the
      // body location doesn't flicker on and off (training always had it).
      final now = DateTime.now().millisecondsSinceEpoch;
      if (res.poses.isNotEmpty) {
        _latestPose = res.poses.first.landmarks;
        _lastPoseOkMs = now;
      } else if (now - _lastPoseOkMs > 1500) {
        _latestPose = const [];
      }
    } catch (_) {
    } finally {
      _poseBusy = false;
    }
  }

  Future<void> _stopStream([CameraController? c]) async {
    final controller = c ?? _controller;
    if (controller != null && _streaming) {
      try {
        await controller.stopImageStream();
      } catch (_) {}
    }
    _streaming = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      final controller = _controller;
      if (controller == null) return;
      _controller = null;
      _recognizer.reset();
      if (mounted) setState(() {});
      _enqueue(() async {
        await _quiet(() => _stopStream(controller));
        await _quiet(controller.dispose);
      });
    } else if (state == AppLifecycleState.resumed) {
      if (_controller == null && !_disposed) _setupCamera();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _landmarkSub?.cancel();
    _enqueue(_teardown);
    super.dispose();
  }

  /// Ordered shutdown: stop frames, let any pose call finish, then free native
  /// resources. Every step is isolated and time-boxed, so one failure can't
  /// skip the rest. Runs in the background so dispose() returns immediately.
  Future<void> _teardown() async {
    final controller = _controller;
    _controller = null;
    await _quiet(() => _stopStream(controller));
    for (var i = 0; i < 20 && _poseBusy; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    await _quiet(_recognizer.dispose);
    await _quiet(() => controller?.dispose());
    await _quiet(() => _landmarker?.dispose());
    await _quiet(_pose.dispose);
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_cameraError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white)),
        ),
      );
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF0D9488)));
    }
    final previewSize = controller.value.previewSize;
    return Center(
      child: AspectRatio(
        aspectRatio: 1 / controller.value.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(controller),
            if (kShowDebugUi && previewSize != null)
              CustomPaint(
                painter: _HandOverlayPainter(
                  hands: _hands,
                  previewSize: previewSize,
                  sensorOrientation: controller.description.sensorOrientation,
                  isFront: controller.description.lensDirection ==
                      CameraLensDirection.front,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HandOverlayPainter extends CustomPainter {
  final List<Hand> hands;
  final Size previewSize;
  final int sensorOrientation;
  final bool isFront;
  _HandOverlayPainter({
    required this.hands,
    required this.previewSize,
    required this.sensorOrientation,
    required this.isFront,
  });

  static const List<List<int>> _connections = [
    [0, 1], [1, 2], [2, 3], [3, 4], [0, 5], [5, 6], [6, 7], [7, 8],
    [5, 9], [9, 10], [10, 11], [11, 12], [9, 13], [13, 14], [14, 15], [15, 16],
    [13, 17], [17, 18], [18, 19], [19, 20], [0, 17],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (hands.isEmpty) return;
    final scale = size.width / previewSize.height;
    if (scale <= 0 || scale.isNaN || scale.isInfinite) return;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(sensorOrientation * math.pi / 180);
    if (isFront) {
      canvas.scale(-1, 1);
      canvas.rotate(math.pi);
    }
    canvas.scale(scale);
    final pointPaint = Paint()
      ..color = const Color(0xFF5EEAD4)
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 3 / scale
      ..style = PaintingStyle.stroke;
    final r = 5 / scale;
    Offset pt(Landmark lm) =>
        Offset((lm.x - 0.5) * previewSize.width, (lm.y - 0.5) * previewSize.height);
    for (final hand in hands) {
      if (hand.landmarks.length < 21) continue;
      for (final c in _connections) {
        canvas.drawLine(pt(hand.landmarks[c[0]]), pt(hand.landmarks[c[1]]), linePaint);
      }
      for (final lm in hand.landmarks) {
        canvas.drawCircle(pt(lm), r, pointPaint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HandOverlayPainter old) =>
      old.hands != hands ||
      old.previewSize != previewSize ||
      old.sensorOrientation != sensorOrientation ||
      old.isFront != isFront;
}