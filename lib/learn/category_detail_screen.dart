import 'package:flutter/material.dart';
import 'learn_repository.dart';
import 'video_player_widget.dart';
import 'category.dart';
import 'lesson.dart';
import 'lesson_player_screen.dart';

class CategoryDetailScreen extends StatelessWidget {
  final String categoryId;
  const CategoryDetailScreen({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context) {
    final future = LearnRepository.instance.getCategory(categoryId);

    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<LearnCategory>(
        future: future,
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final cat = snap.data!;
          return CustomScrollView(
            slivers: [
              // Header matching HomePage secondary pages
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
                  child: Row(
                    children: [
                      Icon(cat.icon, color: const Color(0xFF087F73), size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          cat.title,
                          style: const TextStyle(
                            color: Color(0xFF153B39),
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _LessonTile(lesson: cat.sortedLessons[i], category: cat),
                    childCount: cat.sortedLessons.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  final Lesson lesson;
  final LearnCategory category;
  const _LessonTile({required this.lesson, required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2EEEB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14087F73),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LessonPlayerScreen(
                lessons: category.sortedLessons,
                initialIndex: category.sortedLessons.indexOf(lesson),
                categoryTitle: category.title,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 108,
                    height: 192,
                    child: VideoPlayerWidget(
                      videoAsset: lesson.videoAsset,
                      posterAsset: lesson.thumbnailAsset,
                      lessonTitle: lesson.title,
                      previewWidth: 108,
                      previewHeight: 192,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF153B39),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (lesson.duration != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _formatDuration(lesson.duration!),
                          style: const TextStyle(
                            color: Color(0xFF6B8581),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF6B8581), size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$mins:$secs';
  }
}