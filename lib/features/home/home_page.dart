import 'package:flutter/material.dart';

import 'video_lesson_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'learn_screen.dart';
import 'search_results_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [_buildDashboard(), const ProfilePage(), const SettingsPage()];

    return Scaffold(
      backgroundColor: const Color(0xFFF6FBFA),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: pages[_selectedIndex],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFD8F3EE),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() {}),
            onSubmitted: (query) {
              final trimmed = query.trim();
              if (trimmed.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SearchResultsScreen(query: trimmed),
                  ),
                );
              }
            },
            decoration: InputDecoration(
              hintText: 'Search FSL lessons, signs, or topics',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2EEEB)),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 17),
            ),
          ),
          const SizedBox(height: 22),
          _buildStreakCard(),
          const SizedBox(height: 28),
          const Text(
            'Keep learning',
            style: TextStyle(
              color: Color(0xFF153B39),
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.school_rounded,
                  title: 'Learn',
                  subtitle: 'New lessons',
                  color: const Color(0xFF087F73),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LearnScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.fitness_center_rounded,
                  title: 'Practice',
                  subtitle: 'Test your skills',
                  color: const Color(0xFFE8782F),
                  onTap: () => _showComingSoon('Practice'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'Continue where you left off',
            style: TextStyle(
              color: Color(0xFF153B39),
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 13),
          _buildLessonPreview(),
        ],
      ),
    );
  }

  Widget _buildStreakCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF087F73), Color(0xFF10A99A), Color(0xFFF18A3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26087F73),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your learning streak',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                SizedBox(height: 3),
                Text(
                  '3 days',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Keep it going today!',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Colors.white,
            size: 28,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2EEEB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF153B39),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF6B8581), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonPreview() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2EEEB)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFD8F3EE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.waving_hand_rounded,
              color: Color(0xFF087F73),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Everyday Greetings',
                  style: TextStyle(
                    color: Color(0xFF153B39),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Beginner lesson  ·  20 min',
                  style: TextStyle(color: Color(0xFF6B8581), fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const VideoLessonPage(
                  title: 'Everyday Greetings',
                  assetPath: 'assets/0.mp4',
                ),
              ),
            ),
            icon: const Icon(
              Icons.play_circle_fill_rounded,
              color: Color(0xFF087F73),
              size: 32,
            ),
          ),
        ],
      ),
    );
}
 
  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is ready for your next lesson.')),
    );
  }
 
}
