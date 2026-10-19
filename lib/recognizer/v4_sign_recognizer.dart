import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_pose_detection/flutter_pose_detection.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'sign_recognizer.dart';
import 'v4/canonical_v4.dart';
import 'v4/features_v4.dart';

/// FiloSign v4 recognizer (Dual-Layer). MediaPipe Hands + Pose -> canonical
/// space (upright, isotropic, dominant hand = slot0) -> v4 features over a
/// sliding time window -> average of 3 TFLite LSTMs of ONE head:
///   letters head (alphabet category) or words head (every other category).
/// Same lock rule as before: a class must dominate recent votes at >= 0.85.
class V4SignRecognizer implements SignRecognizer {
  static const int seqLen = 30;
  static const int _predictEveryN = 5;
  static const int _handsAwayReset = 10;
  static const int _bufferMaxMs = 5000;
  // Live window ~ the typical sign length in training (hand-visible span):
  // letters median 2.7 s, words median 1.6 s (p75 2.2 s).
  static const double lettersWindowS = 2.5;
  static const double wordsWindowS = 1.8;
  static const int _minWindowFrames = 12;
  static const int _stableLockCount = 3;
  static const int _voteWindow = 5;
  static const double _stableLockMinConf = 0.85;
  static const double _minMargin = 0.25;
  /// Minimum probability the best sign must have among ALL signs (before the
  /// category filter). Random movements spread probability thin.
  static const double _minRawConf = 0.5;
  /// Reject ("not a sign") class name in the label files.
  static const String noneLabel = '__none__';
  /// True when the latest prediction was rejected (show "Not recognized").
  bool notRecognized = false;

  final bool letters;
  final List<Interpreter> _interpreters = [];
  final List<IsolateInterpreter> _isoInterpreters = [];
  bool _predicting = false;
  List<String> _labels = const [];
  bool _ready = false;

  int _sensorOrientation = 0;
  double _imgW = 0, _imgH = 0; // upright image size
  bool dominantLeft = false;

  final Stopwatch _clock = Stopwatch()..start();
  final List<CanonFrame> _buffer = [];
  final List<RawFrameV4> _rawBuffer = [];
  final List<int> _voteClass = [];
  final List<double> _voteConf = [];
  int _framesSincePredict = 0;
  int _handsAway = 0;
  bool _locked = false;
  SignPrediction _last = SignPrediction.none;
  List<MapEntry<String, double>> _top3 = const [];
  int lastLatencyMs = 0;
  List<bool> lastPresent = const [false, false];
  /// Shoulders visible in the latest frame (body location features available).
  bool lastPoseOk = false;
  /// Copy of the previous attempt, kept when the buffer is cleared (e.g. the
  /// hands leave the frame to tap the debug button).
  List<RawFrameV4> _lastAttemptRaw = const [];

  V4SignRecognizer({required this.letters});

  String get headName => letters ? 'letters' : 'words';
  double get windowS => letters ? lettersWindowS : wordsWindowS;
  List<MapEntry<String, double>> get top3 => _top3;
  bool get isLocked => _locked;
  @override
  bool get isReady => _ready;

  /// [imageWidth]/[imageHeight] are the CameraImage size (sensor orientation).
  void configureCamera({required int sensorOrientation, int? imageWidth, int? imageHeight}) {
    _sensorOrientation = ((sensorOrientation % 360) + 360) % 360;
    if (imageWidth != null && imageHeight != null) {
      final swap = _sensorOrientation == 90 || _sensorOrientation == 270;
      _imgW = (swap ? imageHeight : imageWidth).toDouble();
      _imgH = (swap ? imageWidth : imageHeight).toDouble();
    }
  }

  bool get hasImageSize => _imgW > 0;

  @override
  Future<void> init() async {
    for (final s in [101, 202, 303]) {
      final interp =
          await Interpreter.fromAsset('assets/models/filosign_v4_${headName}_seed$s.tflite');
      _interpreters.add(interp);
      _isoInterpreters.add(await IsolateInterpreter.create(address: interp.address));
    }
    final raw = await rootBundle.loadString('assets/models/labels_v4_$headName.json');
    _labels = (jsonDecode(raw) as List<dynamic>).map((e) => e.toString()).toList();
    _ready = true;
  }

  /// Rotate a sensor-oriented normalized point to the upright image.
  (double, double) _rotateXY(double x, double y) {
    switch (_sensorOrientation) {
      case 90:
        return (1.0 - y, x);
      case 180:
        return (1.0 - x, 1.0 - y);
      case 270:
        return (y, 1.0 - x);
      default:
        return (x, y);
    }
  }

  @override
  SignPrediction addFrame(List<Hand> hands, List<PoseLandmark> pose, List<String> candidates) {
    if (!_ready || _locked || !hasImageSize) return _last;
    if (hands.isEmpty) {
      _handsAway++;
      if (_handsAway >= _handsAwayReset) _clearAttempt();
      return _last;
    }
    _handsAway = 0;

    final rawHands = <List<double>>[
      for (final h in hands.take(2))
        if (h.landmarks.length >= kHandLm)
          [
            for (var j = 0; j < kHandLm; j++) ...() {
              final (x, y) = _rotateXY(h.landmarks[j].x, h.landmarks[j].y);
              return [x, y, h.landmarks[j].z];
            }()
          ]
    ];
    if (rawHands.isEmpty) return _last;
    final rawPose = pose.length >= kPoseLm
        ? [for (var j = 0; j < kPoseLm; j++) ...[pose[j].x, pose[j].y, pose[j].z, pose[j].visibility]]
        : null;
    final raw = RawFrameV4(tMs: _clock.elapsedMilliseconds, hands: rawHands, pose: rawPose);
    final frame = canonicalizeFrame(raw, _imgW, _imgH, dominantLeft);
    lastPresent = frame.present;
    lastPoseOk = frame.poseOk;
    _buffer.add(frame);
    _rawBuffer.add(raw);
    final cutoff = frame.t - _bufferMaxMs / 1000.0;
    while (_buffer.isNotEmpty && _buffer.first.t < cutoff) {
      _buffer.removeAt(0);
      _rawBuffer.removeAt(0);
    }

    _framesSincePredict++;
    if (_framesSincePredict >= _predictEveryN) {
      _framesSincePredict = 0;
      _predictAndVote(candidates, frame.t); // async, not awaited
    }
    return _last;
  }

  /// Features + the 3 models run OFF the UI thread (background isolate +
  /// IsolateInterpreter), so the camera preview never freezes. Only one
  /// prediction is in flight at a time; new requests are skipped meanwhile.
  Future<void> _predictAndVote(List<String> candidates, double now) async {
    if (_predicting) return;
    final window = [for (final f in _buffer) if (f.t >= now - windowS) f];
    if (window.length < _minWindowFrames) return;
    _predicting = true;
    try {
      final sw = Stopwatch()..start();
      final isLetters = letters;
      final input = await Isolate.run(() => _featureInput(window, isLetters));
      final models = [..._isoInterpreters];
      if (input == null || _locked || models.isEmpty) return;
      final probs = List<double>.filled(_labels.length, 0.0);
      final perModel = <List<double>>[];
      for (final interp in models) {
        final output = [List<double>.filled(_labels.length, 0.0)];
        await interp.run(input, output);
        perModel.add(List<double>.of(output[0]));
        for (var i = 0; i < probs.length; i++) {
          probs[i] += output[0][i] / models.length;
        }
      }
      if (!_ready) return;
      lastLatencyMs = sw.elapsedMilliseconds;
      _vote(probs, perModel, candidates);
    } finally {
      _predicting = false;
    }
  }

  /// Not a sign: the model's reject class, a weak raw score, or the three
  /// models disagreeing. Shows "Not recognized" and clears pending votes, so a
  /// half-done or random movement can never add up to a lock.
  void _reject(double conf) {
    notRecognized = true;
    _last = SignPrediction(sign: null, confidence: conf);
    _voteClass.clear();
    _voteConf.clear();
  }

  void _vote(List<double> probs, List<List<double>> perModel, List<String> candidates) {
    final noneIdx = _labels.indexOf(noneLabel);
    final allowed = <int>{
      for (final c in candidates)
        if (_labels.contains(c)) _labels.indexOf(c)
    };
    if (allowed.isEmpty) allowed.addAll(List<int>.generate(_labels.length, (i) => i));
    if (noneIdx >= 0) allowed.add(noneIdx);

    // raw (all-sign) score of the best candidate, before narrowing to the
    // category: a real sign keeps most of the probability for itself
    var rawBest = -1;
    for (final i in allowed) {
      if (i == noneIdx) continue;
      if (rawBest < 0 || probs[i] > probs[rawBest]) rawBest = i;
    }
    final masked = [for (var i = 0; i < probs.length; i++) allowed.contains(i) ? probs[i] : 0.0];
    final sum = masked.fold<double>(0.0, (a, b) => a + b);
    if (sum <= 0 || rawBest < 0) return;
    final disp = [for (final p in masked) p / sum];
    final order = List<int>.generate(disp.length, (i) => i)..sort((a, b) => disp[b].compareTo(disp[a]));
    _top3 = [for (final i in order.take(3)) MapEntry(_labels[i], disp[i])];
    final idx = order.first;
    final conf = disp[idx];
    final second = order.length > 1 ? disp[order[1]] : 0.0;

    int argmaxAllowed(List<double> p) {
      var b = -1;
      for (final i in allowed) {
        if (b < 0 || p[i] > p[b]) b = i;
      }
      return b;
    }

    final agree = perModel.every((p) => argmaxAllowed(p) == idx);
    if (idx == noneIdx || probs[rawBest] < _minRawConf || !agree) {
      _reject(conf);
      return;
    }
    notRecognized = false;
    _last = SignPrediction(sign: _labels[idx], confidence: conf);
    if (conf - second < _minMargin) return; // ambiguous: show, don't vote

    _voteClass.add(idx);
    _voteConf.add(conf);
    if (_voteClass.length > _voteWindow) {
      _voteClass.removeAt(0);
      _voteConf.removeAt(0);
    }
    // only lock once the buffer covers most of a sign
    if (_buffer.last.t - _buffer.first.t < 0.8 * windowS) return;
    final counts = <int, int>{}, sums = <int, double>{};
    for (var i = 0; i < _voteClass.length; i++) {
      counts[_voteClass[i]] = (counts[_voteClass[i]] ?? 0) + 1;
      sums[_voteClass[i]] = (sums[_voteClass[i]] ?? 0) + _voteConf[i];
    }
    var bestC = -1, bestN = 0;
    counts.forEach((c, n) {
      if (n > bestN) {
        bestN = n;
        bestC = c;
      }
    });
    if (bestC >= 0 && bestN >= _stableLockCount) {
      final mean = sums[bestC]! / bestN;
      if (mean >= _stableLockMinConf) {
        _locked = true;
        _last = SignPrediction(sign: _labels[bestC], confidence: mean);
      }
    }
  }

  /// Debug capture: the last few seconds exactly as the recognizer saw them
  /// (upright landmarks before canonicalization), plus camera settings and
  /// the current guesses. Replayed offline by src/replay_debug_v4.py.
  Map<String, dynamic> debugSnapshot({String? expected, List<String>? candidates}) => {
        'version': 1,
        'head': headName,
        'expected': expected,
        'candidates': candidates,
        'width': _imgW,
        'height': _imgH,
        'sensor_orientation': _sensorOrientation,
        'dominant_left': dominantLeft,
        'window_s': windowS,
        'top3': [for (final e in _top3) [e.key, e.value]],
        'locked': _locked,
        'frames': [
          for (final f in (_rawBuffer.length >= _lastAttemptRaw.length ? _rawBuffer : _lastAttemptRaw))
            {'t_ms': f.tMs, 'hands': f.hands, 'pose': f.pose}
        ],
      };

  void _clearAttempt() {
    if (_rawBuffer.length >= 5) _lastAttemptRaw = List.of(_rawBuffer);
    _rawBuffer.clear();
    _buffer.clear();
    _voteClass.clear();
    _voteConf.clear();
    _framesSincePredict = 0;
    _top3 = const [];
    _last = SignPrediction.none;
    notRecognized = false;
  }

  @override
  void reset() {
    _clearAttempt();
    _handsAway = 0;
    _locked = false;
  }

  @override
  void dispose() {
    _ready = false;
    final iso = [..._isoInterpreters];
    final interps = [..._interpreters];
    _isoInterpreters.clear();
    _interpreters.clear();
    // let an in-flight prediction finish before freeing the models
    Future(() async {
      while (_predicting) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      for (final i in iso) {
        await i.close();
      }
      for (final i in interps) {
        i.close();
      }
    });
  }
}

/// Runs in a background isolate: canonical frames -> model input [1][30][F].
List<List<List<double>>>? _featureInput(List<CanonFrame> window, bool letters) {
  final feats = featuresV4(window, letters, length: V4SignRecognizer.seqLen);
  if (feats == null) return null;
  return [
    [for (final row in feats) row.toList()]
  ];
}

