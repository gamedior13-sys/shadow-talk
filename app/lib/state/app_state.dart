import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// State toàn cục: cài đặt + tiến độ + streak, lưu cục bộ trên máy.
class AppState extends ChangeNotifier {
  SharedPreferences? _sp;
  AppSettings settings = AppSettings();
  ProgressData progress = ProgressData();

  Future<void> load() async {
    _sp = await SharedPreferences.getInstance();
    final sj = _sp!.getString('settings');
    if (sj != null) {
      settings = AppSettings.fromJson(
          Map<String, dynamic>.from(jsonDecode(sj) as Map));
    }
    final pj = _sp!.getString('progress');
    if (pj != null) {
      progress = ProgressData.fromJson(
          Map<String, dynamic>.from(jsonDecode(pj) as Map));
    }
    notifyListeners();
  }

  void updateSettings(void Function(AppSettings) fn) {
    fn(settings);
    _persist();
    notifyListeners();
  }

  LessonProgress progressOf(String lessonId) =>
      progress.lessons.putIfAbsent(lessonId, () => LessonProgress());

  void markProgress(String lessonId, int idx) {
    final p = progressOf(lessonId);
    if (idx > p.lastIdx) p.lastIdx = idx;
    _touchStreak();
    _persist();
    notifyListeners();
  }

  void recordScore(String lessonId, int idx, double score) {
    final p = progressOf(lessonId);
    p.attempts += 1;
    if (p.bestScore == null || score > p.bestScore!) p.bestScore = score;
    markProgress(lessonId, idx);
  }

  void _touchStreak() {
    String key(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final now = DateTime.now();
    final today = key(now);
    if (progress.lastDate == today) return;
    final yest = key(now.subtract(const Duration(days: 1)));
    progress.streakDays =
        progress.lastDate == yest ? progress.streakDays + 1 : 1;
    progress.lastDate = today;
  }

  void _persist() {
    _sp?.setString('settings', jsonEncode(settings.toJson()));
    _sp?.setString('progress', jsonEncode(progress.toJson()));
  }
}
