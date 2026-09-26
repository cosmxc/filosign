import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'placeholder_video.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String? videoAsset;
  final String? posterAsset;
  final BoxFit fit;
  final String? lessonTitle;
  final double? previewWidth;
  final double? previewHeight;

  const VideoPlayerWidget({
    super.key,
    this.videoAsset,
    this.posterAsset,
    this.fit = BoxFit.cover,
    this.lessonTitle,
    this.previewWidth,
    this.previewHeight,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    if (widget.videoAsset == null || widget.videoAsset!.isEmpty) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    _controller = VideoPlayerController.asset(widget.videoAsset!);
    try {
      await _controller!.initialize();
      if (!mounted) return;
      setState(() => _initialized = true);
      _controller!.setLooping(false);
      _controller!.setVolume(0);
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError || widget.videoAsset == null) {
      return PlaceholderVideo(
        title: widget.lessonTitle,
        width: widget.previewWidth,
        height: widget.previewHeight,
      );
    }

    if (!_initialized) {
      return widget.posterAsset != null
          ? Image.asset(widget.posterAsset!, fit: widget.fit)
          : const ColoredBox(
              color: Color(0xFFE2EEEB),
              child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2)));
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(_controller!),
          IconButton(
            iconSize: 56,
            icon: Icon(
              _controller!.value.isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_filled_rounded,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _controller!.value.isPlaying
                    ? _controller!.pause()
                    : _controller!.play();
              });
            },
          ),
        ],
      ),
    );
  }
}