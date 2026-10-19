import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:filosign/learn/learn_routes.dart';
import '../../learn/learn_repository.dart';
import '../practice/live_practice_screen.dart';

const _teal = Color(0xFF087F73);
const _ink = Color(0xFF153B39);
const _muted = Color(0xFF6B8581);
const _bg = Color(0xFFF6FBFA);

class PracticeScreen extends StatefulWidget {
  /// Optional: lets the shell switch to the Learn tab from the empty state.
  final VoidCallback? onStartLearning;
  const PracticeScreen({super.key, this.onStartLearning});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  /// false: a category appears once its quiz was attempted (recommended).
  /// true:  only once its quiz was passed.
  static const bool _passedOnly = false;

  Map<int, bool> _progress = {}; // DB category id -> passed
  bool _loaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    progressVersion.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    progressVersion.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await Supabase.instance.client.rpc('get_practice_categories');
      final map = <int, bool>{};
      if (res is List) {
        for (final r in res) {
          if (r is Map) {
            final id = (r['category_id'] as num?)?.toInt();
            if (id != null) map[id] = r['passed'] == true;
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _progress = map;
        _loaded = true;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loaded = true;
        _error = 'Could not load your practice list. Pull down to retry.';
      });
    }
  }

  List<_PracticeCategory> get _visible => [
        for (final c in _categories)
          if (_progress.containsKey(kCategoryDbIds[c.id]) &&
              (!_passedOnly || _progress[kCategoryDbIds[c.id]] == true))
            c,
      ];

  @override
  Widget build(BuildContext context) {
    final visible = _visible;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: _teal,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
                  child: Text(
                    'Practice',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: _ink,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ),
              if (!_loaded)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                      child: CircularProgressIndicator(color: _teal)),
                )
              else if (visible.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    error: _error,
                    onStartLearning: widget.onStartLearning,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _CategoryTile(
                        category: visible[i],
                        passed: _progress[kCategoryDbIds[visible[i].id]] == true,
                      ),
                      childCount: visible.length,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.0,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String? error;
  final VoidCallback? onStartLearning;
  const _EmptyState({this.error, this.onStartLearning});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(error == null ? Icons.school_outlined : Icons.cloud_off_rounded,
              size: 64, color: _teal),
          const SizedBox(height: 16),
          Text(error == null ? 'Start learning first' : 'Something went wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _ink, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            error ??
                'Take a category quiz in Learn and that category will show up here for practice.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 15),
          ),
          if (error == null && onStartLearning != null) ...[
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onStartLearning,
              style: FilledButton.styleFrom(
                backgroundColor: _teal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Start learning',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}

class _PracticeCategory {
  final String id; // Learn category id (assets/learn/<id>.json)
  final String title;
  final IconData icon;
  final int totalItems;

  const _PracticeCategory(this.id, this.title, this.icon, this.totalItems);
}

const List<_PracticeCategory> _categories = [
  _PracticeCategory('basic', 'Basics', Icons.people_outline, 5),
  _PracticeCategory('letters', 'Letters', Icons.abc_outlined, 26),
  _PracticeCategory('numbers', 'Numbers', Icons.numbers_outlined, 10),
  _PracticeCategory('days', 'Days', Icons.calendar_today_outlined, 10),
  _PracticeCategory('months', 'Months', Icons.date_range_outlined, 12),
  _PracticeCategory('colors', 'Colors', Icons.palette_outlined, 13),
  _PracticeCategory('greetings', 'Greetings', Icons.waving_hand_outlined, 10),
  _PracticeCategory('family', 'Family', Icons.family_restroom_outlined, 15),
  _PracticeCategory('food', 'Food', Icons.restaurant_outlined, 10),
  _PracticeCategory('drinks', 'Drinks', Icons.local_drink_outlined, 10),
  _PracticeCategory('communication', 'Communication', Icons.emergency_outlined, 10),
];

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.passed});
  final _PracticeCategory category;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final learn = await LearnRepository.instance.getCategory(category.id);
          if (!context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LivePracticeScreen(category: learn)),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
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
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(category.icon, size: 36, color: _teal),
              const SizedBox(height: 10),
              Text(
                category.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${category.totalItems} Signs · ${passed ? 'Passed' : 'Retake quiz'}',
                  style: TextStyle(
                    color: passed ? _teal : Colors.amber.shade800,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}