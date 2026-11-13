import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/asr_service.dart';
import '../services/player_service.dart';
import '../services/practice_controller.dart';
import '../services/recorder_service.dart';
import '../state/app_state.dart';
import 'session_summary_screen.dart';
import '../theme.dart';

class PracticeScreen extends StatefulWidget {
  final List<PracticeItem> items;
  final PracticeMode mode;
  final String lessonId;
  final String title;
  const PracticeScreen({
    super.key,
    required this.items,
    required this.mode,
    required this.lessonId,
    required this.title,
  });

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  late final PracticeController _c;
  bool showText = false;
  bool _summaryShown = false;

  @override
  void initState() {
    super.initState();
    _c = PracticeController(
      items: widget.items,
      mode: widget.mode,
      lessonId: widget.lessonId,
      title: widget.title,
      app: context.read<AppState>(),
      player: context.read<PlayerService>(),
      recorder: context.read<RecorderService>(),
      asr: context.read<AsrService>(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _c.playCurrent());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        if (_c.phase == Phase.finished && !_summaryShown) {
          _summaryShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => SessionSummaryScreen(controller: _c),
              ),
            );
          });
        }
        final s = _c.current;
        final isTest = widget.mode != PracticeMode.practice;
        return Scaffold(
          appBar: AppBar(
            title: Text('${widget.title} · ${_c.idx + 1}/${_c.items.length}'),
            actions: [
              if (!isTest)
                IconButton(
                  tooltip: 'Chế độ đi xe (tự động)',
                  icon: Icon(app.settings.autoMode
                      ? Icons.autorenew
                      : Icons.touch_app),
                  onPressed: () => app
                      .updateSettings((st) => st.autoMode = !st.autoMode),
                ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // ===== Câu mẫu — ẩn chữ mặc định, nút hiện khi cần =====
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          if (showText) ...[
                            Text(s.en,
                                style: const TextStyle(
                                    fontSize: 24,
                                    height: 1.4,
                                    fontWeight: FontWeight.w600)),
                            if (!isTest) ...[
                              const SizedBox(height: 12),
                              Text(s.vi,
                                  style: const TextStyle(
                                      fontSize: 15, color: kMuted)),
                            ],
                          ] else ...[
                            const Icon(Icons.hearing, size: 40, color: kBlue),
                            const SizedBox(height: 10),
                            const Text('Nghe rồi nhắc lại theo',
                                style: TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                                isTest
                                    ? 'Không xem chữ — luyện tai và miệng'
                                    : 'Bật "Hiện chữ" nếu cần đọc theo',
                                style: const TextStyle(
                                    fontSize: 13, color: kMuted)),
                          ],
                          TextButton.icon(
                            onPressed: () => setState(() => showText = !showText),
                            icon: Icon(showText
                                ? Icons.visibility_off
                                : Icons.visibility),
                            label: Text(showText ? 'Ẩn chữ' : 'Hiện chữ'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _phaseBody(),
                  if (_c.phase == Phase.scored) ...[
                    const SizedBox(height: 14),
                    _scoreBlock(),
                  ],
                ],
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!app.settings.autoMode && !isTest)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => _c.playCurrent(autoNext: false),
                          child: const Text('Nghe lại'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _c.startRecording,
                          child: const Text('Ghi'),
                        ),
                      ],
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                          ),
                          onPressed: _c.repeat,
                          child: const Text('🔁 Lặp lại',
                              style: TextStyle(fontSize: 17)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                          ),
                          onPressed: _c.next,
                          child: const Text('Tiếp ▶',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tai nghe: bấm ⏯ = lặp lại · giữ = sang câu',
                    style: TextStyle(fontSize: 12, color: kMuted),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _phaseBody() {
    switch (_c.phase) {
      case Phase.loadingModel:
        return Column(
          children: [
            const Text('Đang tải model chấm điểm (28MB · 1 lần duy nhất)…',
                style: TextStyle(color: kMuted)),
            const SizedBox(height: 10),
            SizedBox(
              width: 240,
              child: LinearProgressIndicator(value: _c.modelProgress),
            ),
          ],
        );
      case Phase.playing:
        return const Text('Đang phát câu mẫu…',
            style: TextStyle(fontSize: 16, color: kMuted));
      case Phase.countdown:
        return const Text('Chuẩn bị nói…',
            style: TextStyle(fontSize: 16, color: kMuted));
      case Phase.recording:
        return Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mic, color: kBlue),
                SizedBox(width: 8),
                Text('Đang nghe bạn nói…',
                    style: TextStyle(fontSize: 16, color: kBlue)),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 220,
              child: LinearProgressIndicator(
                value: min(_c.level * 3, 1.0),
                minHeight: 8,
              ),
            ),
          ],
        );
      case Phase.scoring:
        return const Column(
          children: [
            SizedBox(height: 8),
            SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(height: 10),
            Text('Đang chấm điểm…', style: TextStyle(fontSize: 16, color: kMuted)),
          ],
        );
      case Phase.scored:
        return Text(
            'Đã ghi ${(_c.lastRecordMs / 1000).toStringAsFixed(1)}s',
            style: const TextStyle(fontSize: 13, color: kMuted));
      case Phase.finished:
        return const Text('Hoàn thành phiên! 🎉',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600));
      case Phase.idle:
        return const Text('Bấm "Nghe lại" hoặc "Ghi"',
            style: TextStyle(fontSize: 14, color: kMuted));
    }
  }

  Widget _scoreBlock() {
    final score = _c.lastScore;
    final pass = (score ?? 0) >= context.read<AppState>().settings.passThreshold;
    return Column(
      children: [
        _ring(score ?? 0, pass),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (final m in _c.lastMatches)
              if (m.status != WordStatus.ins)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: m.status == WordStatus.ok ? kBlueSoft : kRedSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    m.expected,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: m.status == WordStatus.ok
                          ? const Color(0xFF1D4ED8)
                          : kRed,
                      decoration: m.status == WordStatus.del
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                ),
          ],
        ),
        if (_c.heardText != null && _c.heardText!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Bạn nói: "${_c.heardText}"',
              style: const TextStyle(fontSize: 12, color: kMuted)),
        ],
        const SizedBox(height: 6),
        OutlinedButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: const Text('Nghe giọng của mình'),
          onPressed: _c.playMyRecording,
        ),
      ],
    );
  }

  Widget _ring(double score, bool pass) {
    final color = pass ? kBlue : kRed;
    return Column(
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 12,
                  backgroundColor: kLine,
                  color: color,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(score.round().toString(),
                      style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: color)),
                  Text(pass ? 'đạt ✓' : 'chưa đạt',
                      style: const TextStyle(fontSize: 12, color: kMuted)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
