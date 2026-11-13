import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/lesson_repository.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Tiến độ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 36)),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${app.progress.streakDays} ngày liên tiếp',
                          style: const TextStyle(
                              fontSize: 19, fontWeight: FontWeight.w800)),
                      Text('Level hiện tại: ${kLevels[app.levelIndex]}',
                          style: const TextStyle(color: kMuted, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Text('ĐIỂM TỪNG BUỔI HỌC',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: kMuted,
                    letterSpacing: 0.5)),
          ),
          if (app.sessions.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('Chưa có buổi học nào — vào 1 bài luyện để bắt đầu.',
                    style: TextStyle(color: kMuted)),
              ),
            )
          else
            for (final s in app.sessions)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Text(
                    s.avg.round().toString(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color:
                          s.avg >= app.settings.passThreshold ? kBlue : kRed,
                    ),
                  ),
                  title: Text(s.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${DateTime.parse(s.dateIso).toLocal().toString().substring(0, 16)} · '
                      '${s.scores.length} câu · '
                      '${s.kind == 'placement' ? 'kiểm tra trình độ' : s.kind == 'promotion' ? 'kiểm tra nâng level' : 'luyện tập'}',
                      style: const TextStyle(fontSize: 12, color: kMuted)),
                  trailing: s.resultLevel == null
                      ? null
                      : Chip(
                          label: Text(s.resultLevel!,
                              style: const TextStyle(fontSize: 12)),
                          backgroundColor: kBlueSoft,
                        ),
                ),
              ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Text('ĐIỂM TỐT NHẤT TỪNG BÀI',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: kMuted,
                    letterSpacing: 0.5)),
          ),
          FutureBuilder<List<Lesson>>(
            future: context.read<LessonRepository>().loadAll(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return Column(
                children: [
                  for (final l in snap.data!)
                    ListTile(
                      dense: true,
                      title: Text(l.titleVi),
                      subtitle: Text(kTopicNames[l.topic] ?? l.topic,
                          style: const TextStyle(fontSize: 12)),
                      trailing: Text(
                        app.progressOf(l.id).bestScore == null
                            ? '—'
                            : '${app.progressOf(l.id).bestScore!.round()}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, color: kBlue),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
