import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/player_service.dart';
import '../services/recorder_service.dart';
import '../services/practice_controller.dart';
import '../state/app_state.dart';

class PracticeScreen extends StatefulWidget {
  final Lesson lesson;
  const PracticeScreen({super.key, required this.lesson});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  late final PracticeController _c;

  @override
  void initState() {
    super.initState();
    _c = PracticeController(
      lesson: widget.lesson,
      app: context.read<AppState>(),
      player: context.read<PlayerService>(),
      recorder: context.read<RecorderService>(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _c.playCurrent());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String _statusText() {
    switch (_c.phase) {
      case Phase.playing:
        return 'Đang phát câu mẫu…';
      case Phase.countdown:
        return 'Chuẩn bị nói…';
      case Phase.recording:
        return 'Đang nghe bạn nói…';
      case Phase.recorded:
        final sec = (_c.lastRecordMs / 1000).toStringAsFixed(1);
        return _c.lastScore == null
            ? 'Đã ghi ${sec}s — chấm điểm sẽ có ở bước tiếp theo'
            : 'Điểm: ${_c.lastScore!.round()}';
      case Phase.finished:
        return 'Hoàn thành bài! 🔥';
      case Phase.idle:
        return _c.speechSeen ? 'Đã nghe thấy giọng — bấm Tiếp nếu nói xong' : 'Bấm "Nghe lại" hoặc "Ghi"';
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final s = _c.current;
        return Scaffold(
          appBar: AppBar(
            title: Text(
                '${widget.lesson.titleVi} · ${_c.idx + 1}/${widget.lesson.sentences.length}'),
            actions: [
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
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Card(
                          color: const Color(0xFF161B22),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Text(s.en,
                                    style: const TextStyle(
                                        fontSize: 24,
                                        height: 1.4,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 12),
                                Text(s.vi,
                                    style: const TextStyle(
                                        fontSize: 15, color: Colors.white54)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_c.phase == Phase.recording) ...[
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.mic, color: Color(0xFF4493F8)),
                              SizedBox(width: 8),
                            ],
                          ),
                          const Text('Đang nghe bạn nói…',
                              style: TextStyle(color: Color(0xFF4493F8))),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: 220,
                            child: LinearProgressIndicator(
                              value: min(_c.level * 3, 1.0),
                              minHeight: 8,
                            ),
                          ),
                        ] else
                          Text(_statusText(),
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.white70)),
                        if (_c.phase == Phase.recorded) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Nghe giọng của mình'),
                            onPressed: _c.playMyRecording,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: Column(
                    children: [
                      if (!app.settings.autoMode)
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
                      const SizedBox(height: 8),
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
                                  style: TextStyle(fontSize: 18)),
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
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Tai nghe: bấm ⏯ = lặp lại · giữ = sang câu',
                        style: TextStyle(fontSize: 12, color: Colors.white38),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
