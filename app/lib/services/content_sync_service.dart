import 'dart:convert';
import 'dart:io';

import '../data/lesson_repository.dart';
import '../models/models.dart';

/// Đồng bộ bài học từ GitHub (raw main): fetch lessons.json, so rev,
/// tải audio file mới cho bài thêm/sửa. Chạy 1 lần/ngày khi mở app
/// + khi anh bấm "Làm mới". Offline thì bỏ qua, dùng bài đã có.
class ContentSyncService {
  static const _rawBase =
      'https://raw.githubusercontent.com/gamedior13-sys/shadow-talk/main/content';

  final LessonRepository repo;

  ContentSyncService(this.repo);

  Future<Map<String, dynamic>?> _fetchJson(String url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final req = await client.getUrl(Uri.parse(url));
      final resp = await req.close();
      if (resp.statusCode != 200) return null;
      final body = await resp.transform(utf8.decoder).join();
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  Future<void> _downloadAudio(String lessonId, int idx1, String savePath) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final url = '$_rawBase/audio/$lessonId/${idx1.toString().padLeft(2, '0')}.mp3';
      final req = await client.getUrl(Uri.parse(url));
      final resp = await req.close();
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
      final bytes = await resp.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
      await File(savePath).create(recursive: true);
      await File(savePath).writeAsBytes(bytes, flush: true);
    } finally {
      client.close();
    }
  }

  /// Trả về số bài thêm mới + số bài cập nhật. null = lỗi mạng.
  Future<SyncResult> sync() async {
    try {
      final data = await _fetchJson('$_rawBase/lessons.json');
      if (data == null) return const SyncResult(false, 0, 0, 'Không có mạng');
      final remoteAll = ((data['lessons'] as List?) ?? const [])
          .map((e) => Lesson.fromJson(Map<String, dynamic>.from(e as Map)));
      final docs = await repo.docs();

      var added = 0, updated = 0;
      final merged = <String, Lesson>{};
      for (final l in remoteAll) {
        final old = await _currentRemoteById(l.id);
        if (old == null) {
          added++;
        } else if (l.rev > old.rev) {
          updated++;
        } else if (l.rev <= old.rev) {
          merged[l.id] = old; // giữ nguyên bản đã tải
          continue;
        }
        // Tải audio của bài mới/cập nhật
        for (var i = 0; i < l.sentences.length; i++) {
          final savePath =
              '${docs.path}/audio/${l.id}/${(i + 1).toString().padLeft(2, '0')}.mp3';
          try {
            await _downloadAudio(l.id, i + 1, savePath);
          } catch (_) {
            // thiếu 1 file không chặn cả bài
          }
        }
        merged[l.id] = l;
      }
      await repo.setRemote(merged);
      return SyncResult(true, added, updated, 'Đã đồng bộ');
    } catch (e) {
      return SyncResult(false, 0, 0, 'Lỗi đồng bộ: $e');
    }
  }

  Future<Lesson?> _currentRemoteById(String id) async {
    await repo.loadAll();
    if (repo.isRemote(id)) {
      final all = await repo.loadAll();
      return all.firstWhere((l) => l.id == id, orElse: () => all.first);
    }
    return null;
  }
}

class SyncResult {
  final bool ok;
  final int added;
  final int updated;
  final String message;
  const SyncResult(this.ok, this.added, this.updated, this.message);
}
