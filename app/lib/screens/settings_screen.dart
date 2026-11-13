import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/asr_service.dart';
import '../state/app_state.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _downloading = false;
  double _progress = 0;
  bool? _modelReady;

  @override
  void initState() {
    super.initState();
    context
        .read<AsrService>()
        .isModelReady()
        .then((v) => mounted ? setState(() => _modelReady = v) : null);
  }

  Future<void> _download() async {
    setState(() {
      _downloading = true;
      _progress = 0;
    });
    try {
      await context.read<AsrService>().downloadModel(
            onDownload: (done, total) {
              if (mounted) {
                setState(() => _progress = total > 0 ? done / total : 0);
              }
            },
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Đã tải model chấm điểm — dùng được offline')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Tải model lỗi: $e — thử lại khi có mạng')));
      }
    }
    final ready = await context.read<AsrService>().isModelReady();
    if (mounted) {
      setState(() {
        _downloading = false;
        _modelReady = ready;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _slider(
            context,
            title: 'Tốc độ phát câu mẫu',
            value: s.speed,
            min: 0.6,
            max: 1.0,
            divisions: 8,
            label: '${s.speed.toStringAsFixed(2)}x',
            onChanged: (v) => app.updateSettings(
                (st) => st.speed = double.parse(v.toStringAsFixed(2))),
          ),
          SwitchListTile(
            title: const Text('Chế độ đi xe (tự động)'),
            subtitle: const Text(
                'Tự phát → tự ghi → tự chấm → tự sang câu, tắt màn hình vẫn chạy.'),
            value: s.autoMode,
            onChanged: (v) => app.updateSettings((st) => st.autoMode = v),
          ),
          _slider(
            context,
            title: 'Thời gian chờ trước khi ghi',
            value: s.preRecordDelayMs.toDouble(),
            min: 500,
            max: 4000,
            divisions: 14,
            label: '${(s.preRecordDelayMs / 1000).toStringAsFixed(1)}s',
            onChanged: (v) =>
                app.updateSettings((st) => st.preRecordDelayMs = v.round()),
          ),
          _slider(
            context,
            title: 'Ngưỡng điểm "đạt"',
            value: s.passThreshold.toDouble(),
            min: 50,
            max: 90,
            divisions: 8,
            label: '${s.passThreshold}',
            onChanged: (v) =>
                app.updateSettings((st) => st.passThreshold = v.round()),
          ),
          SwitchListTile(
            title: const Text('Ưu tiên mic tai nghe Bluetooth'),
            subtitle: const Text(
                'Đeo tai nghe khi đi xe thì ghi bằng mic tai nghe (giảm tiếng gió).'),
            value: s.bluetoothMic,
            onChanged: (v) => app.updateSettings((st) => st.bluetoothMic = v),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology, color: kBlue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _modelReady == null
                              ? 'Đang kiểm tra model chấm điểm…'
                              : (_modelReady!
                                  ? 'Model chấm điểm offline: sẵn sàng ✓'
                                  : 'Model chấm điểm offline: chưa tải'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Nhận dạng giọng chạy trên máy (28MB, tải 1 lần khi có mạng). '
                    'Chấm sâu bằng AI cloud sẽ có sau khi cài key Azure.',
                    style: TextStyle(fontSize: 12, color: kMuted),
                  ),
                  if (_downloading) ...[
                    const SizedBox(height: 10),
                    LinearProgressIndicator(value: _progress),
                  ] else ...[
                    const SizedBox(height: 10),
                    if (_modelReady == false)
                      FilledButton.icon(
                        onPressed: _download,
                        icon: const Icon(Icons.download),
                        label: const Text('Tải model (28MB)'),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slider(
    BuildContext context, {
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String label,
    required void Function(double) onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              label: label,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
