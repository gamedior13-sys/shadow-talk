import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/lesson_repository.dart';
import '../models/models.dart';
import '../state/app_state.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Tiến độ')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            color: const Color(0xFF161B22),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 40)),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${app.progress.streakDays} ngày liên tiếp',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(
                        app.progress.lastDate == null
                            ? 'Hôm nay bấm vào 1 bài để bắt đầu chuỗi!'
                            : 'Lần luyện gần nhất: ${app.progress.lastDate}',
                        style:
                            const TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Điểm tốt nhất từng bài',
              style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 8),
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
                      leading: Text(l.level,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFFB703))),
                      title: Text(l.titleVi),
                      subtitle: Text(
                          '${app.progressOf(l.id).attempts} lượt luyện · ${kTopicNames[l.topic] ?? l.topic}'),
                      trailing: Text(
                        app.progressOf(l.id).bestScore == null
                            ? '—'
                            : '★ ${app.progressOf(l.id).bestScore!.round()}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFB703)),
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
