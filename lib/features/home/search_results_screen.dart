import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:filosign/learn/learn_repository.dart';
import 'package:filosign/learn/lesson_player_screen.dart';
import 'package:filosign/learn/category.dart';
import 'package:filosign/learn/lesson.dart';
import 'package:filosign/learn/learn_routes.dart';

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
    final lower = query.toLowerCase();

    final accessList = await Future.wait([
      for (final id in categoryIds) _fetchAccess(id),
    ]);
    final accessById = <String, bool>{
      for (var i = 0; i < categoryIds.length; i++)
        categoryIds[i]: accessList[i],
    };

    final results = <_SearchResult>[];
    for (final id in categoryIds) {
      final cat = await repo.getCategory(id);
      final canAccess = accessById[id] ?? false;
      for (int i = 0; i < cat.sortedLessons.length; i++) {
        final lesson = cat.sortedLessons[i];
        if (lesson.title.toLowerCase().contains(lower)) {
          results.add(_SearchResult(
            category: cat,
            lesson: lesson,
            lessonIndex: i,
            canAccess: canAccess,
          ));
        }
      }
    }
    return results;
  }

  Future<bool> _fetchAccess(String categoryId) async {
    if (categoryId == 'basic') return true;
    final dbId = kCategoryDbIds[categoryId];
    if (dbId == null) return false;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;
    try {
      final result = await Supabase.instance.client.rpc(
        'can_access_category',
        params: {'p_user': user.id, 'p_category': dbId},
      );
      return _asBool(result);
    } catch (_) {
      return false;
    }
  }

  static bool _asBool(dynamic r) {
    if (r is bool) return r;
    if (r is List) return r.isNotEmpty && _asBool(r.first);
    if (r is Map) return r.isNotEmpty && _asBool(r.values.first);
    return false;
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
          style: const TextStyle(
              color: Color(0xFF153B39),
              fontWeight: FontWeight.w800,
              fontSize: 20),
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
              child: Text('No lessons found',
                  style: TextStyle(color: Color(0xFF6B8581), fontSize: 16)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(22),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _ResultTile(result: items[index]),
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
  final bool canAccess;
  _SearchResult({
    required this.category,
    required this.lesson,
    required this.lessonIndex,
    required this.canAccess,
  });
}

class _ResultTile extends StatelessWidget {
  final _SearchResult result;
  const _ResultTile({required this.result});

  void _showLockedHint(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
              'Pass the previous category\'s quiz to unlock ${result.category.title}.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF087F73),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final locked = !result.canAccess;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: locked
            ? () => _showLockedHint(context)
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LessonPlayerScreen(
                      lessons: result.category.sortedLessons,
                      initialIndex: result.lessonIndex,
                      category: result.category,
                    ),
                  ),
                );
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: locked ? Colors.grey.shade200 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: locked ? Colors.grey.shade400 : const Color(0xFFE2EEEB),
            ),
            boxShadow: locked
                ? null
                : const [
                    BoxShadow(
                        color: Color(0x14087F73),
                        blurRadius: 8,
                        offset: Offset(0, 4)),
                  ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      result.lesson.title,
                      style: TextStyle(
                        color:
                            locked ? Colors.grey : const Color(0xFF153B39),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.category.title,
                      style: TextStyle(
                        color: locked
                            ? Colors.grey.shade500
                            : const Color(0xFF6B8581),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                locked
                    ? Icons.lock_outline_rounded
                    : Icons.chevron_right_rounded,
                color: locked ? Colors.grey : const Color(0xFF6B8581),
              ),
            ],
          ),
        ),
      ),
    );
  }
}