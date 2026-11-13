import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
            onChanged: (v) =>
                app.updateSettings((st) => st.speed = double.parse(v.toStringAsFixed(2))),
          ),
          SwitchListTile(
            title: const Text('Chế độ đi xe (tự động)'),
            subtitle: const Text(
                'Tự phát → tự ghi → tự chấm → tự sang câu. Tắt nếu muốn bấm từng bước.'),
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
            label: '${s.preRecordDelayMs / 1000}s',
            onChanged: (v) => app
                .updateSettings((st) => st.preRecordDelayMs = v.round()),
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
          const SizedBox(height: 8),
          const Text(
            'Chấm điểm offline chạy trên máy, không cần mạng. '
            'Chấm sâu bằng AI cloud sẽ có sau khi cài key Azure (bước 8).',
            style: TextStyle(fontSize: 12, color: Colors.white38),
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
      color: const Color(0xFF161B22),
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
