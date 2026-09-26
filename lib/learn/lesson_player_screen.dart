import 'package:flutter/material.dart';
import 'video_player_widget.dart';
import 'lesson.dart';

class LessonPlayerScreen extends StatefulWidget {
  final List<Lesson> lessons;
  final int initialIndex;
  final String categoryTitle;

  const LessonPlayerScreen({
    super.key,
    required this.lessons,
    required this.initialIndex,
    required this.categoryTitle,
  });

  @override
  State<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends State<LessonPlayerScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  void _goNext() {
    if (_currentIndex < widget.lessons.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _goPrev() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lessons[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _WhiteAppBar(
        title: lesson.title,
        onClose: () => Navigator.pop(context),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.lessons.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (_, i) {
          final l = widget.lessons[i];
          return Center(
            child: VideoPlayerWidget(
              videoAsset: l.videoAsset,
              posterAsset: l.thumbnailAsset,
              lessonTitle: l.title,
            ),
          );
        },
      ),
      bottomNavigationBar: _WhiteBottomBar(
        currentIndex: _currentIndex,
        total: widget.lessons.length,
        onPrev: _currentIndex == 0 ? null : _goPrev,
        onNext: _currentIndex == widget.lessons.length - 1 ? null : _goNext,
      ),
    );
  }
}

class _WhiteAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback onClose;

  const _WhiteAppBar({required this.title, required this.onClose});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded, color: Color(0xFF153B39), size: 28),
        onPressed: onClose,
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF153B39),
          fontWeight: FontWeight.w800,
          fontSize: 22,
        ),
      ),
      centerTitle: true,
      actions: const [SizedBox(width: 48)],
    );
  }
}

class _WhiteBottomBar extends StatelessWidget {
  final int currentIndex;
  final int total;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _WhiteBottomBar({
    required this.currentIndex,
    required this.total,
    this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _NavButton(
              icon: Icons.chevron_left_rounded,
              onPressed: onPrev,
            ),
            Text(
              '${currentIndex + 1} / $total',
              style: const TextStyle(color: Color(0xFF6B8581), fontSize: 14, fontWeight: FontWeight.w600),
            ),
            _NavButton(
              icon: Icons.chevron_right_rounded,
              onPressed: onNext,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _NavButton({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: enabled ? const Color(0xFF087F73) : const Color(0xFFE2EEEB),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            icon,
            color: enabled ? Colors.white : const Color(0xFF9DB3AE),
            size: 28,
          ),
        ),
      ),
    );
  }
}