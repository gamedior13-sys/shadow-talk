import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// State toàn cục: cài đặt, tiến độ, lịch sử buổi học, level & lộ trình.
class AppState extends ChangeNotifier {
  SharedPreferences? _sp;
  AppSettings settings = AppSettings();
  ProgressData progress = ProgressData();
  List<SessionRecord> sessions = [];
  int levelIndex = 1; // mặc định A2 cho tới khi placement
  bool placementDone = false;
  String? lastPromotionDay; // 'yyyy-MM-dd' lần kiểm tra/placement gần nhất
  String? lastSyncDay;
  bool syncing = false;

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
    final ssj = _sp!.getString('sessions');
    if (ssj != null) {
      sessions = ((jsonDecode(ssj) as List?) ?? const [])
          .map((e) =>
              SessionRecord.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    levelIndex = _sp!.getInt('levelIndex') ?? 1;
    placementDone = _sp!.getBool('placementDone') ?? false;
    lastPromotionDay = _sp!.getString('lastPromotionDay');
    lastSyncDay = _sp!.getString('lastSyncDay');
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

  void addSession(SessionRecord r) {
    sessions.insert(0, r);
    if (sessions.length > 60) sessions.removeRange(60, sessions.length);
    _persist();
    notifyListeners();
  }

  void setPlacement(int idx) {
    levelIndex = idx.clamp(0, kLevels.length - 1);
    placementDone = true;
    lastPromotionDay = _today();
    _persist();
    notifyListeners();
  }

  bool get canPromote => levelIndex < kLevels.length - 1;

  /// Đủ 7 ngày luyện từ lần kiểm tra gần nhất → mở bài kiểm tra nâng cấp.
  bool get eligibleForPromotion {
    if (!placementDone || !canPromote) return false;
    final d = lastPromotionDay;
    if (d == null) return false;
    return DateTime.now().difference(DateTime.parse(d)).inDays >= 7;
  }

  void promote() {
    if (canPromote) levelIndex += 1;
    lastPromotionDay = _today();
    _persist();
    notifyListeners();
  }

  void setSyncDay(String day) {
    lastSyncDay = day;
    _persist();
    notifyListeners();
  }

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
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
    _sp?.setString('sessions', jsonEncode(sessions.map((s) => s.toJson()).toList()));
    _sp?.setInt('levelIndex', levelIndex);
    _sp?.setBool('placementDone', placementDone);
    _sp?.setString('lastPromotionDay', lastPromotionDay);
    _sp?.setString('lastSyncDay', lastSyncDay);
  }
}
