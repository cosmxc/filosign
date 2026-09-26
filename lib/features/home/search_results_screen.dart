import 'package:flutter/material.dart';
import 'package:filosign/learn/learn_repository.dart';
import 'package:filosign/learn/lesson_player_screen.dart';
import 'package:filosign/learn/category.dart';
import 'package:filosign/learn/lesson.dart';

class SearchResultsScreen extends StatefulWidget {
  final String query;
  const SearchResultsScreen({super.key, required this.query});

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late Future<List<_SearchResult>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadResults(widget.query);
  }

  Future<List<_SearchResult>> _loadResults(String query) async {
    final repo = LearnRepository.instance;
    final categoryIds = LearnRepository.allCategoryIds;
    final results = <_SearchResult>[];
    final lower = query.toLowerCase();

    for (final id in categoryIds) {
      final cat = await repo.getCategory(id);
      for (int i = 0; i < cat.sortedLessons.length; i++) {
        final lesson = cat.sortedLessons[i];
        if (lesson.title.toLowerCase().contains(lower)) {
          results.add(_SearchResult(category: cat, lesson: lesson, lessonIndex: i));
        }
      }
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF153B39)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Results for "${widget.query}"',
          style: const TextStyle(color: Color(0xFF153B39), fontWeight: FontWeight.w800, fontSize: 20),
        ),
      ),
      body: FutureBuilder<List<_SearchResult>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(
              child: Text('No lessons found', style: TextStyle(color: Color(0xFF6B8581), fontSize: 16)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(22),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final r = items[index];
              return _ResultTile(result: r);
            },
          );
        },
      ),
    );
  }
}

class _SearchResult {
  final LearnCategory category;
  final Lesson lesson;
  final int lessonIndex;
  _SearchResult({required this.category, required this.lesson, required this.lessonIndex});
}

class _ResultTile extends StatelessWidget {
  final _SearchResult result;
  const _ResultTile({required this.result});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LessonPlayerScreen(
                lessons: result.category.sortedLessons,
                initialIndex: result.lessonIndex,
                categoryTitle: result.category.title,
              ),
            ),
          );
          // The LessonFlowController will start at the correct index via its constructor
          // which finds the first locked lesson. To jump directly, we could modify controller,
          // but for simplicity we rely on existing flow.
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2EEEB)),
            boxShadow: const [
              BoxShadow(color: Color(0x14087F73), blurRadius: 8, offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 128,
                  child: Container(
                    color: const Color(0xFFF0F5F4),
                    alignment: Alignment.center,
                    child: const Icon(Icons.videocam_off_rounded, size: 28, color: Color(0xFF9DB3AE)),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.lesson.title,
                      style: const TextStyle(
                        color: Color(0xFF153B39),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.category.title,
                      style: const TextStyle(color: Color(0xFF6B8581), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF6B8581)),
            ],
          ),
        ),
      ),
    );
  }
}