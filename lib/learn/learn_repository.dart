import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'category.dart';
import 'lesson.dart';

class LearnRepository {
  LearnRepository._();
  static final instance = LearnRepository._();

  final Map<String, LearnCategory> _cache = {};

  Future<LearnCategory> getCategory(String catId) async {
    if (_cache.containsKey(catId)) return _cache[catId]!;

    final meta = _categoryMeta[catId]!;
    final jsonString = await rootBundle.loadString('assets/learn/$catId.json');
    final List<dynamic> raw = jsonDecode(jsonString);
    final lessons = raw
        .map((e) => Lesson.fromMap(e as Map<String, dynamic>))
        .toList();

    final category = LearnCategory(
      id: catId,
      title: meta['title']! as String,
      icon: meta['icon']! as IconData,
      totalSigns: meta['total']! as int,
      lessons: lessons,
    );

    _cache[catId] = category;
    return category;
  }

  static final Map<String, Map<String, dynamic>> _categoryMeta = {
    'letters': {
      'title': 'Letters',
      'icon': Icons.abc_outlined,
      'total': 26,
    },
    'greetings': {
      'title': 'Greetings',
      'icon': Icons.waving_hand_outlined,
      'total': 10,
    },
    'survival': {
      'title': 'Survival',
      'icon': Icons.emergency_outlined,
      'total': 10,
    },
    'numbers': {
      'title': 'Numbers',
      'icon': Icons.numbers_outlined,
      'total': 10,
    },
    'calendar': {
      'title': 'Months',
      'icon': Icons.date_range_outlined,
      'total': 12,
    },
    'days': {
      'title': 'Days',
      'icon': Icons.calendar_today_outlined,
      'total': 10,
    },
    'family': {
      'title': 'Family',
      'icon': Icons.family_restroom_outlined,
      'total': 10,
    },
    'relationships': {
      'title': 'Relationships',
      'icon': Icons.people_outline,
      'total': 10,
    },
    'colors': {
      'title': 'Colors',
      'icon': Icons.palette_outlined,
      'total': 13,
    },
    'food': {
      'title': 'Food',
      'icon': Icons.restaurant_outlined,
      'total': 10,
    },
    'drinks': {
      'title': 'Drinks',
      'icon': Icons.local_drink_outlined,
      'total': 10,
    },
  };

  static List<String> get allCategoryIds => _categoryMeta.keys.toList();
}