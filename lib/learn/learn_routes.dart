import 'package:flutter/foundation.dart';

/// Route name of CategoryDetailScreen. Kept for callers that still want to
/// pop back to it by name; the primary result path is now the chained
/// `Navigator.pop(QuizResult(...))` flow.
const kCategoryDetailRoute = 'category_detail';

/// Bumped after quiz progress changes so other tabs (Practice) reload.
final ValueNotifier<int> progressVersion = ValueNotifier<int>(0);

/// DB categories.id for each Learn category id (same order as the Learn grid).
const kCategoryDbIds = <String, int>{
  'basic': 1, 'letters': 2, 'numbers': 3, 'days': 4, 'months': 5, 'colors': 6,
  'greetings': 7, 'family': 8, 'food': 9, 'drinks': 10, 'communication': 11,
};

/// Result the quiz hands back up the stack when it finishes. `passed` and
/// `nextUnlocked` are both decided by the server's `submit_quiz` response.
class QuizResult {
  final String categoryId;
  final int score;
  final int total;
  final bool passed;
  final bool nextUnlocked;
  const QuizResult({
    required this.categoryId,
    required this.score,
    required this.total,
    required this.passed,
    required this.nextUnlocked,
  });
}

