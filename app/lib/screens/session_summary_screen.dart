import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/practice_controller.dart';
import '../scoring/scoring.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Tổng kết 1 buổi luyện/kiểm tra: điểm trung bình, từng câu, từ sai.
class SessionSummaryScreen extends StatelessWidget {
  final PracticeController controller;
  const SessionSummaryScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final rec = controller.record;
    if (rec == null) {
      return const Scaffold(body: Center(child: Text('Không có dữ liệu')));
    }
    final app = context.read<AppState>();
    final pass = rec.avg >= app.settings.passThreshold;
    return Scaffold(
      appBar: AppBar(title: const Text('Tổng kết buổi học')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  if (controller.mode == PracticeMode.placement) ...[
                    const Icon(Icons.assessment, size: 44, color: kBlue),
                    const SizedBox(height: 8),
                    Text(
                      'Trình độ của bạn: ${rec.resultLevel}',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const Text('Lộ trình đã mở theo đúng trình độ',
                        style: TextStyle(color: kMuted, fontSize: 13)),
                  ] else if (controller.mode == PracticeMode.promotion) ...[
                    Icon(
                      controller.promoted ? Icons.emoji_events : Icons.schedule,
                      size: 44,
                      color: controller.promoted ? kBlue : kRed,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      controller.promoted
                          ? 'Lên level ${rec.resultLevel}! 🎉'
                          : 'Chưa đạt — thử lại sau',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: controller.promoted ? kBlue : kRed),
                    ),
                    Text(
                      controller.promoted
                          ? 'Cấp độ mới đã mở trong lộ trình'
                          : 'Luyện thêm rồi quay lại nhé',
                      style: const TextStyle(color: kMuted, fontSize: 13),
                    ),
                  ] else ...[
                    const Text('Điểm buổi học',
                        style: TextStyle(color: kMuted)),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    rec.avg.round().toString(),
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w800,
                      color: pass ? kBlue : kRed,
                    ),
                  ),
                  Text(
                    '${rec.scores.length} câu · '
                    '${DateTime.parse(rec.dateIso).toLocal().toString().substring(0, 16)}',
                    style: const TextStyle(color: kMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < controller.takes.length; i++)
            _row(context, i),
          const SizedBox(height: 16),
          if (controller.mode == PracticeMode.practice) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, 'retry'),
                    child: const Text('Luyện lại bài'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, 'done'),
                    child: const Text('Xong'),
                  ),
                ),
              ],
            ),
          ] else
            FilledButton(
              onPressed: () => Navigator.pop(context, 'done'),
              child: const Text('Xong'),
            ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, int i) {
    final t = controller.takes[i];
    final score = t.score ?? 0;
    final wrong = t.matches
        .where((m) => m.status == WordStatus.sub || m.status == WordStatus.del)
        .toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Câu ${t.idx + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(
                  score.round().toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: score >= context.read<AppState>().settings.passThreshold
                        ? kBlue
                        : kRed,
                  ),
                ),
              ],
            ),
            if (wrong.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final m in wrong)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: kRedSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        m.status == WordStatus.del
                            ? '${m.expected} (thiếu)'
                            : '${m.expected} → ${m.heard}',
                        style: const TextStyle(
                            fontSize: 12, color: kRed),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
