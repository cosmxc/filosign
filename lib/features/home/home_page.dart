import 'package:filosign/features/home/practice_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:filosign/learn/learn_repository.dart';
import 'package:filosign/learn/lesson.dart';


import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:filosign/learn/lesson_player_screen.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'learn_screen.dart';
import 'search_results_screen.dart';
import 'package:filosign/learn/category.dart';

class CurrentLessonData {
  final LearnCategory category;
  final int videoId;
  final List<Lesson> lessons;
  final int initialIndex;

  CurrentLessonData({
    required this.category,
    required this.videoId,
    required this.lessons,
    required this.initialIndex,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final _searchController = TextEditingController();
  late Future<int> _streakFuture;
  late Future<int> _lessonsCompletedFuture;
  late Future<CurrentLessonData?> _currentLessonFuture;

  @override
  void initState() {
    super.initState();
    _streakFuture = _fetchStreak(); 
    _lessonsCompletedFuture = _fetchLessonsCompleted();
    _currentLessonFuture = _fetchCurrentLesson();
  }

   Future<int> _fetchStreak() async {
    try {
      final response = await Supabase.instance.client.rpc('get_streak');
      // Supabase RPC returns a List for set-returning functions, or a scalar.
      if (response is List) {
        return response.isNotEmpty ? response.first as int : 0;
      }
      return response as int? ?? 0;
    } catch (e) {
      debugPrint('Error fetching streak: $e');
      return 0;
    }
  }

  Future<int> _fetchLessonsCompleted() async {
    try {
      final response =
          await Supabase.instance.client.rpc('get_lessons_completed');
      if (response is List) {
        return response.isNotEmpty ? response.first as int : 0;
      }
      return response as int? ?? 0;
    } catch (e) {
      debugPrint('Error fetching lessons completed: $e');
      return 0;
    }
  }
  
  Future<CurrentLessonData?> _fetchCurrentLesson() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response =  
          await Supabase.instance.client.rpc('get_current_lesson');
      if (response == null) return null;

      final map = response as Map<String, dynamic>;
      final videoId = map['video_id'] as int;

      // ✅ Correct way to access a static getter
      for (final catId in LearnRepository.allCategoryIds) {
        final category = await LearnRepository.instance.getCategory(catId);

        final initialIndex = category.sortedLessons.indexWhere((lesson) {
          if (lesson.videoAsset == null || lesson.videoAsset!.isEmpty) {
            return false;
          }
          final filename = lesson.videoAsset!.split('/').last;
          final idStr = filename.split('.').first;
          return idStr == videoId.toString();
        });

        if (initialIndex != -1) {
          return CurrentLessonData(
            category: category,
            videoId: videoId,
            lessons: category.sortedLessons,
            initialIndex: initialIndex,
          );
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error fetching current lesson: $e');
      return null;
    }
  }

   Future<void> _saveCurrentLesson(int videoId) async {
    try {
      await Supabase.instance.client.rpc(
        'save_current_lesson',
        params: {'p_video_id': videoId},
      );
    } catch (e) {
      debugPrint('Error saving current lesson: $e');
    }
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final username = Supabase.instance.client.auth.currentUser?.userMetadata?['full_name'] as String?;
    final pages = [_buildDashboard(), const ProfilePage(), SettingsPage()];

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
                   onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PracticeScreen()),
                  ),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your learning streak',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                 FutureBuilder<int>(
                  future: _streakFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 30,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      );
                    }
                    final streak = snapshot.data ?? 0;
                    return Text(
                      '$streak ${streak == 1 ? 'day' : 'days'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 3),
                const Text(
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
    return FutureBuilder<CurrentLessonData?>(
      future: _currentLessonFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2EEEB)),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Color(0xFF087F73),
                  strokeWidth: 2,
                ),
              ),
            ),
          );
        }

        final data = snapshot.data;


        if (data == null) {
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
                    Icons.school_rounded,
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
                        'Start Learning',
                        style: TextStyle(
                          color: Color(0xFF153B39),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Pick a category to begin',
                        style: TextStyle(color: Color(0xFF6B8581), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

  
        final lesson = data.lessons[data.initialIndex];
        final lessonTitle = lesson.title;
        final videoAsset = lesson.videoAsset ?? '';

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
                  Icons.play_circle_fill_rounded,
                  color: Color(0xFF087F73),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.category.title, 
                      style: const TextStyle(
                        color: Color(0xFF153B39),
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      lessonTitle, 
                      style: const TextStyle(
                        color: Color(0xFF6B8581),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: videoAsset.isEmpty
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LessonPlayerScreen(
                              lessons: data.lessons,
                              initialIndex: data.initialIndex,
                              category: data.category,
                            ),
                          ),
                        ),
                icon: Icon(
                  Icons.play_circle_fill_rounded,
                  color: videoAsset.isEmpty
                      ? Colors.grey
                      : const Color(0xFF087F73),
                  size: 32,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}