import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/lesson_repository.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import 'practice_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _topic;
  String? _level;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  Text('Shadow Talk',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const Spacer(),
                  Chip(
                    avatar: const Text('🔥',
                        style: TextStyle(fontSize: 14)),
                    label: Text('${app.progress.streakDays} ngày'),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text('Nghe câu — nói lại — chấm ngay.',
                  style: TextStyle(color: Colors.white54)),
            ),
            _filters(),
            Expanded(
              child: FutureBuilder<List<Lesson>>(
                future: context.read<LessonRepository>().loadAll(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final lessons = snap.data!
                      .where((l) =>
                          _topic == null || l.topic == _topic)
                      .where((l) => _level == null || l.level == _level)
                      .toList();
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: lessons.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) =>
                        _card(context, lessons[i], app),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filters() {
    Widget chips(List<String> labels, String? sel, void Function(String?) onSel) {
      return SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            ChoiceChip(
              label: const Text('Tất cả'),
              selected: sel == null,
              onSelected: (_) => setState(() => onSel(null)),
            ),
            for (var i = 0; i < labels.length; i++)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ChoiceChip(
                  label: Text(labels[i]),
                  selected: sel == labels[i],
                  onSelected: (_) => setState(() => onSel(labels[i])),
                ),
              ),
          ],
        ),
      );
    }

    return Column(
      children: [
        chips(const ['A2', 'B1', 'B2'], _level, (v) => _level = v),
        chips(kTopicNames.values.toList(), _topic, (v) => _topic = v),
      ],
    );
  }

  Widget _card(BuildContext context, Lesson l, AppState app) {
    final p = app.progressOf(l.id);
    final done = (p.lastIdx + 1) / l.sentences.length;
    return Card(
      color: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PracticeScreen(lesson: l)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _levelBadge(l.level),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(l.titleVi,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  Text(
                    p.bestScore == null
                        ? '—'
                        : '★ ${p.bestScore!.round()}',
                    style: const TextStyle(
                        color: Color(0xFFFFB703),
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${kTopicNames[l.topic] ?? l.topic} · ${l.sentences.length} câu',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: done.clamp(0.0, 1.0)),
              const SizedBox(height: 4),
              Text(
                p.lastIdx < 0
                    ? 'Chưa luyện'
                    : (done >= 1 ? 'Hoàn thành' : 'Đang luyện · câu ${p.lastIdx + 1}/${l.sentences.length}'),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _levelBadge(String level) {
    final colors = {
      'A2': const Color(0xFF3FB950),
      'B1': const Color(0xFF4493F8),
      'B2': const Color(0xFFD29922),
    };
    final c = colors[level] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(level,
          style: TextStyle(
              color: c, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
