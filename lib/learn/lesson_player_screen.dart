import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:filosign/learn/category.dart';
import 'package:filosign/learn/lesson.dart';
import 'package:filosign/learn/live_sign_lesson_screen.dart';
import 'package:filosign/features/quiz/quiz_screen.dart';
import 'package:filosign/learn/learn_routes.dart';

class LessonPlayerScreen extends StatefulWidget {
  final List<Lesson> lessons;
  final int initialIndex;
  final LearnCategory category;

  const LessonPlayerScreen({
    super.key,
    required this.lessons,
    required this.initialIndex,
    required this.category,
  });

  @override
  State<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends State<LessonPlayerScreen> {
  int _currentIndex = 0;
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  bool _hasSavedCurrentLesson = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _initController(widget.lessons[_currentIndex]);
  }

  Future<void> _initController(Lesson lesson) async {
    if (mounted) setState(() => _initialized = false);
    _controller?.removeListener(_onVideoUpdate);
    await _controller?.dispose();
    _controller = null;
    _hasSavedCurrentLesson = false;

    if (lesson.videoAsset == null || lesson.videoAsset!.isEmpty) {
      if (mounted) setState(() => _initialized = false);
      return;
    }

    _controller = VideoPlayerController.asset(lesson.videoAsset!);
    try {
      await _controller!.initialize();
      if (!mounted) return;
      _controller!.setVolume(0);
      _controller!.addListener(_onVideoUpdate);
      setState(() => _initialized = true);
      _controller!.play();
      _startHideControlsTimer();
    } catch (_) {
      if (mounted) setState(() => _initialized = false);
    }
  }

  void _onVideoUpdate() {
    if (_controller == null) return;

    final isFinished = _controller!.value.position >=
            _controller!.value.duration &&
        _controller!.value.duration > Duration.zero;

    if (isFinished && !_hasSavedCurrentLesson) {
      _hasSavedCurrentLesson = true;
      _saveCurrentLesson(widget.lessons[_currentIndex]);
    }

    if (_controller!.value.isPlaying && _showControls) {
      _startHideControlsTimer();
    }
  }

  Future<void> _saveCurrentLesson(Lesson lesson) async {
    try {
      final RegExp regExp = RegExp(r'(\d+)\.mp4$');
      final match = regExp.firstMatch(lesson.videoAsset ?? '');

      if (match == null) {
        debugPrint('Could not parse video ID from asset: ${lesson.videoAsset}');
        return;
      }

      final videoId = int.tryParse(match.group(1)!);
      if (videoId == null) {
        debugPrint(
            'Parsed video ID is not a valid integer: ${match.group(1)}');
        return;
      }

      await Supabase.instance.client.rpc(
        'save_current_video',
        params: {'p_video_id': videoId},
      );
      debugPrint('Successfully saved current lesson for video ID: $videoId');
    } catch (e) {
      debugPrint('Error saving current lesson: $e');
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _controller != null && _controller!.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls && _controller != null && _controller!.value.isPlaying) {
      _startHideControlsTimer();
    }
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _hideControlsTimer?.cancel();
      } else {
        _controller!.play();
        _startHideControlsTimer();
      }
    });
  }

  Future<void> _goNext() async {
    _controller?.pause();
    final lesson = widget.lessons[_currentIndex];

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => LessonLiveSignScreen(
          lesson: lesson,
          category: widget.category,
        ),
      ),
    );
    if (!mounted) return;

    final passed = result?['success'] == true || result?['skipped'] == true;
    if (!passed) {
      // User backed out of the live-sign screen: resume the same video.
      _controller?.play();
      return;
    }

    // More lessons left in this category: advance to the next one.
    if (_currentIndex + 1 < widget.lessons.length) {
      setState(() => _currentIndex++);
      await _initController(widget.lessons[_currentIndex]);
      return;
    }

    // Last lesson of the category: run the 10-question quiz, then carry its
    // QuizResult all the way up so LearnScreen can unlock the next tile.
    final quizResult = await Navigator.push<QuizResult>(
      context,
      MaterialPageRoute<QuizResult>(
        builder: (_) => QuizScreen(category: widget.category),
      ),
    );
    if (!mounted) return;
    Navigator.pop(context, quizResult);
  }

  void _goPrev() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _initController(widget.lessons[_currentIndex]);
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lessons[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF6FBFA),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(lesson.title),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: _initialized && _controller != null
                      ? _buildVideoPlayer()
                      : const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF087F73),
                          ),
                        ),
                ),
              ),
            ),
            if (_initialized) _buildBottomInfo(lesson),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFF153B39)),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF153B39),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.lessons.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  '${_currentIndex + 1} / ${widget.lessons.length}',
                  style: const TextStyle(
                    color: Color(0xFF6B8581),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_controller == null) return const SizedBox();
    final size = _controller!.value.size;
    final aspectRatio =
        size.width > 0 && size.height > 0 ? size.width / size.height : 16 / 9;

    return GestureDetector(
      onTap: _toggleControls,
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! > 300) {
          _goPrev();
        } else if (details.primaryVelocity! < -300) {
          _goNext();
        }
      },
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_controller!),
            if (_showControls) _buildOverlayControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlayControls() {
    return AnimatedOpacity(
      opacity: _showControls ? 1 : 0,
      duration: const Duration(milliseconds: 250),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.7),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildControlButton(
                      icon: Icons.replay_10_rounded,
                      onPressed: _seekBackward,
                      tooltip: 'Rewind 3s',
                    ),
                    const SizedBox(width: 16),
                    _buildControlButton(
                      icon: _controller!.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      onPressed: _togglePlayPause,
                      size: 64,
                      iconSize: 36,
                    ),
                    const SizedBox(width: 16),
                    _buildControlButton(
                      icon: Icons.forward_10_rounded,
                      onPressed: _seekForward,
                      tooltip: 'Forward 3s',
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _buildSpeedSelector(),
                        ],
                      ),
                    ),
                    VideoProgressIndicator(
                      _controller!,
                      allowScrubbing: true,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      colors: VideoProgressColors(
                        playedColor: const Color(0xFF087F73),
                        bufferedColor: Colors.white30,
                        backgroundColor: Colors.white10,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        children: [
                          Text(
                            _buildTimeText(_controller!.value.position),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                          const Spacer(),
                          Text(
                            _buildTimeText(_controller!.value.duration),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _seekBackward() {
    final newPosition = _controller!.value.position - const Duration(seconds: 3);
    _controller!.seekTo(newPosition > Duration.zero ? newPosition : Duration.zero);
  }

  void _seekForward() {
    final newPosition = _controller!.value.position + const Duration(seconds: 3);
    if (newPosition < _controller!.value.duration) {
      _controller!.seekTo(newPosition);
    }
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    double size = 40,
    double iconSize = 24,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: iconSize),
        ),
      ),
    );
  }

  Widget _buildSpeedSelector() {
    return PopupMenuButton<double>(
      initialValue: _controller!.value.playbackSpeed,
      tooltip: 'Playback speed',
      color: Colors.black87,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.speed_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              '${_controller!.value.playbackSpeed.toStringAsFixed(1)}x',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        _buildSpeedItem(0.5),
        _buildSpeedItem(0.75),
        _buildSpeedItem(1.0),
        _buildSpeedItem(1.25),
        _buildSpeedItem(1.5),
        _buildSpeedItem(2.0),
      ],
      onSelected: (speed) => _controller!.setPlaybackSpeed(speed),
    );
  }

  PopupMenuItem<double> _buildSpeedItem(double speed) {
    final isSelected = _controller!.value.playbackSpeed == speed;
    return PopupMenuItem(
      value: speed,
      child: Row(
        children: [
          Text(
            '${speed.toStringAsFixed(speed == 1.0 ? 1 : 2)}x',
            style: TextStyle(
              color: isSelected ? const Color(0xFF087F73) : Colors.white,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          if (isSelected) ...[
            const SizedBox(width: 8),
            const Icon(Icons.check, color: Color(0xFF087F73), size: 18),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomInfo(Lesson lesson) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lesson.title,
            style: const TextStyle(
              color: Color(0xFF153B39),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.category.title} · Lesson ${_currentIndex + 1} of ${widget.lessons.length}',
            style: const TextStyle(
              color: Color(0xFF6B8581),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          _buildActionRow(),
        ],
      ),
    );
  }

  Widget _buildActionRow() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _goPrev,
            icon: const Icon(Icons.skip_previous_rounded, size: 20),
            label: const Text('Previous'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF087F73),
              side: const BorderSide(color: Color(0xFF087F73), width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: FilledButton.icon(
            onPressed: _goNext,
            icon: const Icon(Icons.skip_next_rounded, size: 20),
            label: const Text('Next'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF087F73),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _buildTimeText(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}