import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

/// Đường dẫn asset audio mặc định (bài đóng gói sẵn).
String sentenceAudioAsset(String lessonId, int idx) =>
    'assets/lessons/audio/$lessonId/${idx.toString().padLeft(2, '0')}.mp3';

class LessonRepository {
  List<Lesson>? _cache;
  Map<String, Lesson> _remote = {};
  Directory? _docDir;

  Future<Directory> docs() async =>
      _docDir ??= await getApplicationDocumentsDirectory();

  /// Bài tổng hợp: bundled + remote (remote đè cùng id).
  Future<List<Lesson>> loadAll() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/lessons/lessons.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final bundled = (data['lessons'] as List)
        .map((e) => Lesson.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    try {
      final f = File('${(await docs()).path}/lessons_remote.json');
      if (f.existsSync()) {
        final rd = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
        _remote = ((rd['lessons'] as List?) ?? const [])
            .map((e) => Lesson.fromJson(Map<String, dynamic>.from(e as Map)))
            .fold<Map<String, Lesson>>({}, (m, l) {
          m[l.id] = l;
          return m;
        });
      }
    } catch (_) {
      _remote = {};
    }
    final byId = {for (final l in bundled) l.id: l};
    byId.addAll(_remote);
    _cache = byId.values.toList();
    return _cache!;
  }

  bool isRemote(String id) => _remote.containsKey(id);

  /// Lưu bài tải về từ sync (đè file cache + reset cache).
  Future<void> setRemote(Map<String, Lesson> m) async {
    _remote = m;
    _cache = null;
    final f = File('${(await docs()).path}/lessons_remote.json');
    await f.writeAsString(jsonEncode({
      'lessons': m.values.map((e) => e.toJson()).toList(),
    }));
  }

  /// Nguồn audio: bài remote → file đã tải; bundled → asset.
  Future<AudioRef> audioFor(Lesson l, int idx1) async {
    if (isRemote(l.id)) {
      final p =
          '${(await docs()).path}/audio/${l.id}/${idx1.toString().padLeft(2, '0')}.mp3';
      if (File(p).existsSync()) return AudioRef.file(p);
    }
    return AudioRef.asset(sentenceAudioAsset(l.id, idx1));
  }
}
