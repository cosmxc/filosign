import 'package:flutter/material.dart';

class PlaceholderVideo extends StatelessWidget {
  final String? title;
  final double? width;
  final double? height;

  const PlaceholderVideo({
    super.key,
    this.title,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF087F73).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.videocam_off_rounded,
              size: 36, color: Color(0xFF087F73)),
        ),
        if (title != null) ...[
          const SizedBox(height: 12),
          Text(
            title!,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF153B39),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 8),
        const Text(
          'Video not available yet',
          style: TextStyle(color: Color(0xFF6B8581), fontSize: 12),
        ),
      ],
    );

    if (width != null && height != null) {
      return SizedBox(width: width, height: height, child: content);
    }

    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        color: Colors.white,
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: content,
        ),
      ),
    );
  }
}