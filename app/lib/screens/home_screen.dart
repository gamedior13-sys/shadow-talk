import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/lesson_repository.dart';
import '../models/models.dart';
import '../services/content_sync_service.dart';
import '../services/practice_controller.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'practice_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _topic;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoSync());
  }

  Future<void> _autoSync() async {
    final app = context.read<AppState>();
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (app.lastSyncDay != today) await _sync();
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    final app = context.read<AppState>();
    final r = await context.read<ContentSyncService>().sync();
    final now = DateTime.now();
    app.setSyncDay(
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}');
    if (mounted) {
      setState(() => _syncing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r.ok
            ? (r.added + r.updated > 0
                ? 'Đã cập nhật: ${r.added} bài mới, ${r.updated} bài sửa'
                : 'Bài học đã là mới nhất')
            : 'Không đồng bộ được (${r.message}) — dùng bài hiện có'),
        duration: const Duration(seconds: 3),
      ));
    }
  }

  Future<List<PracticeItem>> _lessonItems(Lesson l) async {
    final repo = context.read<LessonRepository>();
    final out = <PracticeItem>[];
    for (var i = 0; i < l.sentences.length; i++) {
      out.add(PracticeItem(
          l.sentences[i], await repo.audioFor(l, i + 1), l.level));
    }
    return out;
  }

  Future<List<PracticeItem>> _placementItems() async {
    final lessons = await context.read<LessonRepository>().loadAll();
    final out = <PracticeItem>[];
    for (final lv in ['A2', 'B1', 'B2']) {
      final ls = lessons.where((l) => l.level == lv).toList();
      if (ls.isEmpty) continue;
      final l = ls.first;
      for (var i = 0; i < min(2, l.sentences.length); i++) {
        out.add(PracticeItem(
            l.sentences[i], await context.read<LessonRepository>().audioFor(l, i + 1), lv));
      }
    }
    return out;
  }

  Future<List<PracticeItem>> _promotionItems() async {
    final app = context.read<AppState>();
    final repo = context.read<LessonRepository>();
    final lessons = (await repo.loadAll())
        .where((l) => l.level == kLevels[app.levelIndex])
        .toList();
    final out = <PracticeItem>[];
    var k = 0;
    while (out.length < 8 && lessons.isNotEmpty) {
      final l = lessons[k % lessons.length];
      final si = (k ~/ lessons.length) % l.sentences.length;
      out.add(PracticeItem(l.sentences[si],
          await repo.audioFor(l, si + 1), l.level));
      k++;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
              child: Row(
                children: [
                  Text('Shadow Talk',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const Spacer(),
                  _streakChip(app.progress.streakDays),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Làm mới bài học',
                    onPressed: _syncing ? null : _sync,
                    icon: _syncing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2.4))
                        : const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 2, 20, 6),
              child: Text('Nghe câu — nói lại — chấm ngay.',
                  style: TextStyle(color: kMuted, fontSize: 13)),
            ),
            _topicFilters(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _sync,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  children: [
                    if (!app.placementDone) _placementCard(),
                    if (app.eligibleForPromotion) _promotionBanner(app),
                    _roadmap(app),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _streakChip(int days) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: kBlueSoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text('🔥 $days ngày',
            style: const TextStyle(
                color: Color(0xFF1D4ED8),
                fontWeight: FontWeight.w700,
                fontSize: 13)),
      );

  Widget _topicFilters() {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ChoiceChip(
            label: const Text('Tất cả'),
            selected: _topic == null,
            onSelected: (_) => setState(() => _topic = null),
          ),
          for (final t in kTopicNames.entries)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ChoiceChip(
                label: Text(t.value),
                selected: _topic == t.key,
                onSelected: (_) => setState(() => _topic = t.key),
              ),
            ),
        ],
      ),
    );
  }

  Widget _placementCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: kBlue, width: 1.5)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.assessment, color: kBlue),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Kiểm tra trình độ để mở lộ trình',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '~2 phút, 6 câu ngắn. Xong là app xếp đúng bài cho trình độ của anh.',
              style: TextStyle(color: kMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () async {
                final items = await _placementItems();
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PracticeScreen(
                      items: items,
                      mode: PracticeMode.placement,
                      lessonId: 'test-placement',
                      title: 'Kiểm tra trình độ',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Bắt đầu kiểm tra'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _promotionBanner(AppState app) {
    final next = kLevels[min(app.levelIndex + 1, kLevels.length - 1)];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: kBlueSoft.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: kBlue)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events, color: kBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Đủ 7 ngày luyện — kiểm tra lên $next!',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text('8 câu của level hiện tại. Đạt ngưỡng là mở level mới.',
                style: TextStyle(color: kMuted, fontSize: 13)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () async {
                final items = await _promotionItems();
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PracticeScreen(
                      items: items,
                      mode: PracticeMode.promotion,
                      lessonId: 'test-promotion',
                      title: 'Kiểm tra nâng $next',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Vào bài kiểm tra'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roadmap(AppState app) {
    return FutureBuilder<List<Lesson>>(
      future: context.read<LessonRepository>().loadAll(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final widgets = <Widget>[];
        for (var li = 0; li < kLevels.length; li++) {
          final lv = kLevels[li];
          if (li == app.levelIndex) {
            widgets.add(_sectionHeader('$lv · LEVEL HIỆN TẠI'));
            final lessons = snap.data!
                .where((l) => l.level == lv)
                .where((l) => _topic == null || l.topic == _topic)
                .toList();
            if (lessons.isEmpty) {
              widgets.add(const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Chưa có bài cho level này — bấm làm mới bài học',
                    style: TextStyle(color: kMuted, fontSize: 13)),
              ));
            }
            for (final l in lessons) {
              widgets.add(_lessonCard(l, app));
            }
          } else if (li < app.levelIndex) {
            widgets.add(_lockedRow('$lv', '✓ Đã vượt qua', kGreen));
          } else {
            widgets.add(_lockedRow('$lv', '🔒 Làm bài kiểm tra để mở', null));
          }
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
      },
    );
  }

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: kMuted,
                letterSpacing: 0.5)),
      );

  Widget _lockedRow(String lv, String label, Color? color) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kLine),
        ),
        child: Row(
          children: [
            Text(lv,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: color ?? kMuted,
                    fontSize: 15)),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(color: kMuted))),
          ],
        ),
      );

  Widget _lessonCard(Lesson l, AppState app) {
    final p = app.progressOf(l.id);
    final done = (p.lastIdx + 1) / l.sentences.length;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          final items = await _lessonItems(l);
          if (!context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PracticeScreen(
                items: items,
                mode: PracticeMode.practice,
                lessonId: l.id,
                title: l.titleVi,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.headphones, size: 20, color: kBlue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(l.titleVi,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  Text(
                    p.bestScore == null ? '—' : '${p.bestScore!.round()}',
                    style: const TextStyle(
                        color: kBlue, fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${kTopicNames[l.topic] ?? l.topic} · ${l.sentences.length} câu',
                style: const TextStyle(color: kMuted, fontSize: 12),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: done.clamp(0.0, 1.0)),
            ],
          ),
        ),
      ),
    );
  }
}
