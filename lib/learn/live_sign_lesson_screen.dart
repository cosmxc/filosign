import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'category.dart'; // LearnCategory, lettersCategoryId
import 'lesson.dart';
import '../../features/practice/live_sign_view.dart';
import '../../features/practice/live_practice_screen.dart' show FeedbackBanner, Top3Panel;
import '../../recognizer/sign_labels.dart';
import '../../recognizer/v4_sign_recognizer.dart';

const _teal = Color(0xFF087F73);
const _ink = Color(0xFF153B39);
const _muted = Color(0xFF6B8581);
const _bg = Color(0xFFF6FBFA);

/// Live sign check shown after a video lesson ("Sign: lesson just watched").
/// Same layout and recognizer flow as the quiz's live camera challenge, but
/// with no countdown and no scoring. Unlimited attempts; help escalates:
///   - after [hintAfterWrong] wrong locks (or [hintAfterSeconds] with hands
///     visible): "Watch again" button (reference video + posture tip)
///   - after [skipAfterWrong] wrong locks (or [skipFallbackSeconds] on screen,
///     e.g. camera/hand detection not working): "Skip"
///
/// After every wrong lock, and after the hint dialog closes, the recognizer
/// is reset through LiveSignView.resetToken (no camera rebuild), so a stuck
/// lock / stale Top 3 can't block a correct sign.
///
/// Pops with:
///   {'success': true, 'attempts': n}  when the sign is matched,
///   {'skipped': true, 'attempts': n}  when the user taps Skip,
///   null                              when the user backs out.
class LessonLiveSignScreen extends StatefulWidget {
  final Lesson lesson; // the lesson just watched
  final LearnCategory category;
  const LessonLiveSignScreen({
    super.key,
    required this.lesson,
    required this.category,
  });

  @override
  State<LessonLiveSignScreen> createState() => _LessonLiveSignScreenState();
}

class _LessonLiveSignScreenState extends State<LessonLiveSignScreen> {
  static const int hintAfterWrong = 2;
  static const int skipAfterWrong = 3;
  static const int hintAfterSeconds = 20; // counted from the first hand seen
  static const int skipFallbackSeconds = 45; // counted from screen open
  static const Duration resetDelay = Duration(milliseconds: 1200);

  late final Map<String, String> _titleByLabel = {
    for (final l in widget.category.lessons) modelLabelForLesson(l.id): l.title
  };
  late final String _target = modelLabelForLesson(widget.lesson.id);

  Timer? _hintTimer;
  Timer? _skipTimer;
  Timer? _resetTimer;
  bool _started = false; // a hand has been seen
  bool _hintByTime = false;
  bool _skipByTime = false;
  bool _done = false; // matched
  bool _paused = false; // hint dialog open: ignore recognizer updates
  LiveSignState? _state;
  bool _mountView = false;

  // Passed to LiveSignView.resetToken: bumping it resets the recognizer
  // (lock + Top 3) without recreating the camera.
  int _session = 0;

  int _wrongLocks = 0;

  bool get _hintAvailable => _wrongLocks >= hintAfterWrong || _hintByTime;
  bool get _skipAvailable => _wrongLocks >= skipAfterWrong || _skipByTime;

 @override
  void initState() {
    super.initState();
    _skipTimer = Timer(const Duration(seconds: skipFallbackSeconds), () {
      if (mounted && !_done) setState(() => _skipByTime = true);
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _mountView = true);
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _skipTimer?.cancel();
    _resetTimer?.cancel();
    super.dispose();
  }

  

  String? _titleOf(String? label) => label == null
      ? null
      : (label == V4SignRecognizer.noneLabel ? 'Not a sign' : (_titleByLabel[label] ?? label));

  /// Fresh recognizer state: clears the lock and the Top 3.
  void _resetRecognizer() {
    _resetTimer?.cancel();
    setState(() {
      _session++;
      _state = null;
    });
  }

  void _onUpdate(LiveSignState s) {
    if (_done || _paused) return;
    final sign = s.prediction.sign;

    // Correct sign.
    if (s.locked && sign == _target) {
      setState(() {
        _state = s;
        _done = true;
      });
      _hintTimer?.cancel();
      _skipTimer?.cancel();
      _resetTimer?.cancel();
      // Let the green "Correct!" bar show briefly, then return to the player.
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) {
          Navigator.pop(context, {'success': true, 'attempts': _wrongLocks + 1});
        }
      });
      return;
    }

    // Wrong sign locked: count it once, show "try again" briefly, then reset
    // the recognizer so the lock can't stay stuck on the wrong sign.
    if (s.locked && sign != null) {
      if (_resetTimer?.isActive != true) {
        setState(() {
          _state = s;
          _wrongLocks++;
        });
        _resetTimer = Timer(resetDelay, () {
          if (mounted && !_done) _resetRecognizer();
        });
      } else {
        setState(() => _state = s);
      }
      return;
    }

    setState(() => _state = s);

    if (!_started && s.handCount > 0) {
      _started = true;
      _hintTimer = Timer(const Duration(seconds: hintAfterSeconds), () {
        if (mounted && !_done) setState(() => _hintByTime = true);
      });
    }
  }

  Future<void> _showHint() async {
    _paused = true; // don't count locks that happen while the dialog is open
    await showDialog<void>(
      context: context,
      builder: (_) => _HintDialog(
          lesson: widget.lesson, months: widget.category.id == 'months'),
    );
    _paused = false;
    if (mounted && !_done) _resetRecognizer(); // start clean after watching
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _ink,
        elevation: 0,
        title: Text('${widget.category.title} practice',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (_skipAvailable && !_done)
            TextButton(
              onPressed: () => Navigator.pop(
                  context, {'skipped': true, 'attempts': _wrongLocks}),
              child: const Text('Skip'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _liveView()),
            if (_hintAvailable && !_done) _watchAgain(),
            if (_done) _feedback(),
          ],
        ),
      ),
    );
  }

  Widget _liveView() {
    final s = _state;
    final wrongLock = s != null &&
        s.locked &&
        s.prediction.sign != null &&
        s.prediction.sign != _target;
    final chipText = wrongLock
        ? 'Try again'
        : (s != null && s.handCount > 0 ? 'Hands detected' : 'Show hands');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            children: [
              const Icon(Icons.videocam_rounded, color: _teal),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(TextSpan(children: [
                  const TextSpan(
                      text: 'Sign:  ',
                      style: TextStyle(color: _muted, fontSize: 16)),
                  TextSpan(
                      text: widget.lesson.title,
                      style: const TextStyle(
                          color: _ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                ])),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: wrongLock
                      ? Colors.red.shade50
                      : const Color(0xFFE6F4F1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(chipText,
                    style: TextStyle(
                        color: wrongLock ? Colors.red.shade700 : _teal,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _mountView ? LiveSignView(
                      resetToken: _session,
                      candidates: _titleByLabel.keys.toList(),
                      letters: widget.category.id == lettersCategoryId,
                      onUpdate: _onUpdate,
                    ): const Center (
                      child: CircularProgressIndicator(color: Color(0xFF0D9488))
                    ),
                    if (kShowDebugUi && s != null && s.top3.isNotEmpty)
                      Positioned(
                          top: 10,
                          left: 10,
                          child: Top3Panel(
                              state: s, titleOf: (l) => _titleOf(l)!)),
                    if (!_done)
                      Positioned(
                        bottom: 10,
                        left: 10,
                        right: 10,
                        child: FeedbackBanner(
                          sign: _titleOf(s?.prediction.sign),
                          confidence: s?.prediction.confidence ?? 0,
                          locked: false,
                          notRecognized: s?.notRecognized ?? false,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Appears once the user has struggled: opens the same reference-video
  /// pop-up the quiz shows after a wrong answer.
  Widget _watchAgain() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: OutlinedButton.icon(
        onPressed: _showHint,
        icon: const Icon(Icons.ondemand_video_rounded, size: 20),
        label: const Text('Watch again'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _teal,
          side: const BorderSide(color: _teal, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  /// Same green bar as the quiz's correct answer, without the point.
  Widget _feedback() {
    final color = Colors.green.shade600;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Correct!',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                Text(widget.lesson.title,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Muted, looping lesson video (copied from quiz_screen.dart).
class _LoopingVideo extends StatefulWidget {
  final String asset;
  const _LoopingVideo({required this.asset});

  @override
  State<_LoopingVideo> createState() => _LoopingVideoState();
}

class _LoopingVideoState extends State<_LoopingVideo> {
  late final VideoPlayerController _c =
      VideoPlayerController.asset(widget.asset);
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _c.initialize().then((_) {
      if (!mounted) return;
      _c
        ..setVolume(0)
        ..setLooping(true)
        ..play();
      setState(() => _ready = true);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        color: Colors.black,
        child: AspectRatio(
          aspectRatio: _ready ? _c.value.aspectRatio : 16 / 9,
          child: _ready
              ? VideoPlayer(_c)
              : const Center(
                  child: CircularProgressIndicator(color: Color(0xFF0D9488))),
        ),
      ),
    );
  }
}

/// Reference video plus a short posture tip (copied from quiz_screen.dart).
class _HintDialog extends StatelessWidget {
  final Lesson lesson;
  final bool months;
  const _HintDialog({required this.lesson, required this.months});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How to sign "${lesson.title}"',
                style: const TextStyle(
                    color: _ink, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            if (lesson.videoAsset != null)
              _LoopingVideo(asset: lesson.videoAsset!),
            const SizedBox(height: 12),
            Text(
              months
                  ? 'Watch which hand stays still and which hand moves behind it. '
                      'Stand back so both elbows show, and turn slightly so the camera sees your signing hand.'
                  : 'Match three things: the hand shape, where the hand is (face, chest, side), '
                      'and the movement. Keep your hands inside the camera view.',
              style: const TextStyle(color: _muted, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(backgroundColor: _teal),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}