import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/models.dart';

/// Đường dẫn asset audio của 1 câu (idx đếm từ 1).
String sentenceAudioAsset(String lessonId, int idx) =>
    'assets/lessons/audio/$lessonId/${idx.toString().padLeft(2, '0')}.mp3';

class LessonRepository {
  List<Lesson>? _cache;

  Future<List<Lesson>> loadAll() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/lessons/lessons.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    _cache = (data['lessons'] as List)
        .map((e) => Lesson.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return _cache!;
  }
}
