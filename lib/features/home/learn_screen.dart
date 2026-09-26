import 'package:flutter/material.dart';
import 'package:filosign/learn/category_detail_screen.dart';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  static String _categoryIdForTitle(String title) {
    const map = {
      'Letters': 'letters',
      'Numbers': 'numbers',
      'Days': 'days',
      'Months': 'calendar',
      'Colors': 'colors',
      'Greetings': 'greetings',
      'Family': 'family',
      'Relationships': 'relationships',
      'Food': 'food',
      'Drinks': 'drinks',
      'Survival': 'survival',
    };
    return map[title] ?? title.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final categories = _categories;

    return Scaffold(
      backgroundColor: const Color(0xFFF6FBFA),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
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

            // Grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _CategoryTile(category: categories[i]),
                  childCount: categories.length,
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

  static const List<_LearnCategory> _categories = [
    _LearnCategory('Letters', Icons.abc_outlined, 26),
    _LearnCategory('Numbers', Icons.numbers_outlined, 10),
    _LearnCategory('Days', Icons.calendar_today_outlined, 10),
    _LearnCategory('Months', Icons.date_range_outlined, 12),
    _LearnCategory('Colors', Icons.palette_outlined, 13),
    _LearnCategory('Greetings', Icons.waving_hand_outlined, 10),
    _LearnCategory('Family', Icons.family_restroom_outlined, 10),
    _LearnCategory('Relationships', Icons.people_outline, 10),
    _LearnCategory('Food', Icons.restaurant_outlined, 10),
    _LearnCategory('Drinks', Icons.local_drink_outlined, 10),
    _LearnCategory('Survival', Icons.emergency_outlined, 10),
  ];
}

class _LearnCategory {
  final String title;
  final IconData icon;
  final int totalSigns;

  const _LearnCategory(this.title, this.icon, this.totalSigns);
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});
  final _LearnCategory category;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CategoryDetailScreen(categoryId: LearnScreen._categoryIdForTitle(category.title)),
            ),
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
              Icon(category.icon, size: 36, color: const Color(0xFF087F73)),
              const SizedBox(height: 10),
              Text(
                category.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF153B39),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${category.totalSigns} signs',
                style: const TextStyle(
                  color: Color(0xFF6B8581),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}