import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoLessonPage extends StatefulWidget {
  final String title;
  final String assetPath;

  const VideoLessonPage({
    super.key,
    required this.title,
    required this.assetPath,
  });

  @override
  State<VideoLessonPage> createState() => _VideoLessonPageState();
}

class _VideoLessonPageState extends State<VideoLessonPage> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.assetPath)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _initialized = true);
        _controller.play();
      });
    _controller.addListener(_onVideoUpdate);
  }

  void _onVideoUpdate() {
    if (_controller.value.isPlaying && _showControls) {
      _startHideControlsTimer();
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls && _controller.value.isPlaying) {
      _startHideControlsTimer();
    }
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _hideControlsTimer?.cancel();
      } else {
        _controller.play();
        _startHideControlsTimer();
      }
    });
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controller.removeListener(_onVideoUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FBFA),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: _initialized
                      ? _buildVideoPlayer()
                      : const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF087F73),
                          ),
                        ),
                ),
              ),
            ),
            if (_initialized) _buildBottomInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF153B39)),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(
                color: Color(0xFF153B39),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    final size = _controller.value.size;
    final aspectRatio = size.width > 0 && size.height > 0
        ? size.width / size.height
        : 16 / 9;

    return GestureDetector(
      onTap: _toggleControls,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_controller),
            if (_showControls) _buildOverlayControls(),
            _buildPlayPauseButton(),
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      _buildTimeText(_controller.value.position),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    const Spacer(),
                    Text(
                      _buildTimeText(_controller.value.duration),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
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

  Widget _buildPlayPauseButton() {
    if (!_showControls && _controller.value.isPlaying) return const SizedBox();

    return AnimatedOpacity(
      opacity: _showControls || !_controller.value.isPlaying ? 1 : 0,
      duration: const Duration(milliseconds: 250),
      child: GestureDetector(
        onTap: _togglePlayPause,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              color: Color(0xFF153B39),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Filipino Sign Language · Beginner',
            style: TextStyle(
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
            onPressed: () {},
            icon: const Icon(Icons.bookmark_border_rounded, size: 20),
            label: const Text('Save'),
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
            onPressed: () {},
            icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
            label: const Text('Mark Complete'),
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