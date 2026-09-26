import 'package:flutter/material.dart';
import 'lesson.dart';

class LearnCategory {
  final String id;
  final String title;
  final IconData icon;
  final int totalSigns;
  final List<Lesson> lessons;

  const LearnCategory({
    required this.id,
    required this.title,
    required this.icon,
    required this.totalSigns,
    required this.lessons,
  });

  List<Lesson> get sortedLessons =>
      [...lessons]..sort((a, b) => a.order.compareTo(b.order));
}