import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:filosign/learn/category_detail_screen.dart';
import 'package:filosign/learn/learn_routes.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  static const List<_LearnCategory> _categories = [
    _LearnCategory('Basics', 'basic', Icons.people_outline, 5),
    _LearnCategory('Letters', 'letters', Icons.abc_outlined, 26),
    _LearnCategory('Numbers', 'numbers', Icons.numbers_outlined, 10),
    _LearnCategory('Days', 'days', Icons.calendar_today_outlined, 10),
    _LearnCategory('Months', 'months', Icons.date_range_outlined, 12),
    _LearnCategory('Colors', 'colors', Icons.palette_outlined, 13),
    _LearnCategory('Greetings', 'greetings', Icons.waving_hand_outlined, 10),
    _LearnCategory('Family', 'family', Icons.family_restroom_outlined, 15),
    _LearnCategory('Food', 'food', Icons.restaurant_outlined, 10),
    _LearnCategory('Drinks', 'drinks', Icons.local_drink_outlined, 10),
    _LearnCategory('Communication', 'communication', Icons.emergency_outlined, 10),
  ];

  Map<String, bool> _access = {'basic': true};

  /// Categories we've seen unlock during this app session. Access is
  /// monotonic, so once it's true it should never flip back to false — even
  /// if a later [can_access_category] RPC hiccups.
  final Set<String> _unlockedThisSession = {};

  String? _justUnlocked;

  final Map<String, GlobalKey> _tileKeys = {
    for (final c in _categories) c.id: GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final map = await _fetchAll();
    if (!mounted) return;
    setState(() => _access = map);
  }

  Future<Map<String, bool>> _fetchAll() async {
    final results = await Future.wait([
      for (final c in _categories) _fetchAccess(kCategoryDbIds[c.id]!),
    ]);
    final merged = <String, bool>{..._access};
    for (var i = 0; i < _categories.length; i++) {
      final r = results[i];
      if (r != null) merged[_categories[i].id] = r;
    }
    return merged;
  }

  /// Returns null when the RPC fails — callers should keep their previous
  /// value instead of treating the failure as "locked."
  Future<bool?> _fetchAccess(int dbId) async {
    if (dbId == kCategoryDbIds['basic']) return true;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;
    try {
      final result = await Supabase.instance.client.rpc(
        'can_access_category',
        params: {'p_user': user.id, 'p_category': dbId},
      );
      return _asBool(result);
    } catch (_) {
      return null;
    }
  }

  static bool _asBool(dynamic r) {
    if (r is bool) return r;
    if (r is List) return r.isNotEmpty && _asBool(r.first);
    if (r is Map) return r.isNotEmpty && _asBool(r.values.first);
    return false;
  }

  Future<void> _openCategory(_LearnCategory c) async {
    QuizResult? result;
    try {
      result = await Navigator.push<QuizResult>(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: kCategoryDetailRoute),
          builder: (_) => CategoryDetailScreen(categoryId: c.id),
        ),
      );
    } catch (e) {
      debugPrint('quiz route returned unexpected value: $e'); // to be removed
    }
    if (!mounted) return;

    final next = (result?.nextUnlocked ?? false) ? _nextCategory(c.id) : null;

    if (next != null) {
      _unlockedThisSession.add(next.id);

      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;

      setState(() {
        _access = {..._access, next.id: true};
        _justUnlocked = next.id;
      });

      final ctx = _tileKeys[next.id]?.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
          alignment: 0.5,
          curve: Curves.easeOut,
        );
      }
      if (!mounted) return;
      HapticFeedback.lightImpact();

      Future.delayed(const Duration(milliseconds: 1600), () {
        if (mounted) setState(() => _justUnlocked = null);
      });
    }

    // Authoritative re-check, but pinned: nothing unlocked this session is
    // ever downgraded by a stale or failed read.
    final after = await _fetchAll();
    if (!mounted) return;
    setState(() {
      _access = {
        ...after,
        for (final id in _unlockedThisSession) id: true,
      };
    });
  }

  _LearnCategory? _nextCategory(String id) {
    final i = _categories.indexWhere((x) => x.id == id);
    if (i < 0 || i + 1 >= _categories.length) return null;
    return _categories[i + 1];
  }
  
  void _showLockedHint(int index) {
    final prev = _categories[index - 1];
    final c = _categories[index];
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
              'Score at least 90% on the ${prev.title} quiz to unlock ${c.title}.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF087F73),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FBFA),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
                child: Text(
                  'Start Learning',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: const Color(0xFF153B39),
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final c = _categories[i];
                    final open = _access[c.id] ?? false;
                    return KeyedSubtree(
                      key: _tileKeys[c.id],
                      child: _CategoryTile(
                        category: c,
                        canAccess: open,
                        highlight: _justUnlocked == c.id,
                        onTap: open
                            ? () => _openCategory(c)
                            : () => _showLockedHint(i),
                      ),
                    );
                  },
                  childCount: _categories.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
    );
  }
}

class _LearnCategory {
  final String title;
  final String id;
  final IconData icon;
  final int totalSigns;

  const _LearnCategory(this.title, this.id, this.icon, this.totalSigns);
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.canAccess,
    required this.onTap,
    this.highlight = false,
  });
  final _LearnCategory category;
  final bool canAccess;
  final bool highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = highlight
        ? const Color(0xFF087F73)
        : (canAccess ? const Color(0xFFE2EEEB) : Colors.grey.shade400);

    final shadows = highlight
        ? const [
            BoxShadow(
              color: Color(0x33087F73),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ]
        : (canAccess
            ? const [
                BoxShadow(
                  color: Color(0x14087F73),
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ]
            : null);

    return AnimatedScale(
      scale: highlight ? 1.06 : 1.0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: canAccess ? Colors.white : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: borderColor,
                width: highlight ? 1.8 : 1.0,
              ),
              boxShadow: shadows,
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    canAccess ? category.icon : Icons.lock_outline_rounded,
                    key: ValueKey(canAccess),
                    size: 36,
                    color: canAccess ? const Color(0xFF087F73) : Colors.grey,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  category.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: canAccess ? const Color(0xFF153B39) : Colors.grey,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${category.totalSigns} signs',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}