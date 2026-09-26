class Lesson {
  final String id;
  final String title;
  final String? videoAsset;
  final String? thumbnailAsset;
  final int order;
  final Duration? duration;

  const Lesson({
    required this.id,
    required this.title,
    this.videoAsset,
    this.thumbnailAsset,
    required this.order,
    this.duration,
  });

  factory Lesson.fromMap(Map<String, dynamic> m) => Lesson(
        id: m['id'] as String,
        title: m['title'] as String,
        videoAsset: m['videoAsset'] as String?,
        thumbnailAsset: m['thumbnailAsset'] as String?,
        order: m['order'] as int,
        duration: m['duration'] != null
            ? Duration(seconds: m['duration'] as int)
            : null,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'videoAsset': videoAsset,
        'thumbnailAsset': thumbnailAsset,
        'order': order,
        'duration': duration?.inSeconds,
      };
}