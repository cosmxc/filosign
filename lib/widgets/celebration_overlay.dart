import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _teal = Color(0xFF087F73);
const _ink = Color(0xFF153B39);
const _muted = Color(0xFF6B8581);
const _border = Color(0xFFE2EEEB);
const _gold = Color(0xFFE8782F);

/// Full-screen celebration: dim barrier, confetti blasting in from both
/// sides, and a congratulations card with a countdown bar. Calls [onFinished]
/// once, either when [duration] elapses or when the user taps the button.
///
/// Place it with Positioned.fill inside a Stack.
class CelebrationOverlay extends StatefulWidget {
  final String title;
  final String message;
  final String actionLabel;
  final Duration duration;
  final VoidCallback onFinished;

  const CelebrationOverlay({
    super.key,
    required this.title,
    required this.message,
    required this.onFinished,
    this.actionLabel = 'Continue',
    this.duration = const Duration(seconds: 5),
  });

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  static const _confettiTime = Duration(seconds: 3);

  late final ConfettiController _left =
      ConfettiController(duration: _confettiTime);
  late final ConfettiController _right =
      ConfettiController(duration: _confettiTime);
  late final AnimationController _countdown =
      AnimationController(vsync: this, duration: widget.duration);

  bool _started = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _countdown.addStatusListener((s) {
      if (s == AnimationStatus.completed) _finish();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _countdown.forward();
    if (!MediaQuery.of(context).disableAnimations) {
      _left.play();
      _right.play();
      HapticFeedback.mediumImpact();
    }
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    widget.onFinished();
  }

  @override
  void dispose() {
    _left.dispose();
    _right.dispose();
    _countdown.dispose();
    super.dispose();
  }

  Widget _blast(Alignment alignment, ConfettiController c, double direction) {
    return Align(
      alignment: alignment,
      child: ConfettiWidget(
        confettiController: c,
        blastDirectionality: BlastDirectionality.directional,
        blastDirection: direction, // 0 = right, pi = left, -pi/2 = up
        emissionFrequency: 0.06,
        numberOfParticles: 14,
        minBlastForce: 15,
        maxBlastForce: 40,
        gravity: 0.2,
        colors: const [
          _teal,
          Color(0xFF5EEAD4),
          Color(0xFF0D9488),
          _gold,
          Colors.white,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Blocks taps on the summary underneath.
        ModalBarrier(
          dismissible: false,
          color: Colors.black.withValues(alpha: 0.45),
        ),
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutBack,
            builder: (_, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      size: 72, color: _gold),
                  const SizedBox(height: 12),
                  Text(widget.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: _ink,
                          fontSize: 26,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(widget.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _muted, fontSize: 15)),
                  const SizedBox(height: 20),
                  AnimatedBuilder(
                    animation: _countdown,
                    builder: (_, __) => ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: 1 - _countdown.value,
                        color: _teal,
                        backgroundColor: _border,
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _finish,
                      style: FilledButton.styleFrom(
                        backgroundColor: _teal,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(widget.actionLabel,
                          style:
                              const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Confetti last so it flies over the card. Left edge shoots up-right,
        // right edge shoots up-left.
        _blast(Alignment.centerLeft, _left, -math.pi / 4),
        _blast(Alignment.centerRight, _right, -3 * math.pi / 4),
      ],
    );
  }
}