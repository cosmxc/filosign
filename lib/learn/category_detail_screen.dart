import 'package:flutter/material.dart';
import 'learn_repository.dart';
import 'category.dart';
import 'lesson_player_screen.dart';
import 'learn_routes.dart';

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
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final cat = snap.data!;
          return CustomScrollView(
            slivers: [
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
                sliver: SliverList.separated(
                  itemCount: cat.sortedLessons.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Color(0xFFE2EEEB)),
                  itemBuilder: (context, index) {
                    final lesson = cat.sortedLessons[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 0),
                      title: Text(
                        lesson.title,
                        style: const TextStyle(
                          color: Color(0xFF153B39),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () async {
                        final result = await Navigator.push<QuizResult>(
                          context,
                          MaterialPageRoute<QuizResult>(
                            builder: (_) => LessonPlayerScreen(
                              lessons: cat.sortedLessons,
                              initialIndex: index,
                              category: cat,
                            ),
                          ),
                        );
                        if (!context.mounted) return;
                        if (result != null) {
                          Navigator.of(context).pop(result);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}