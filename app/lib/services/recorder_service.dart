import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../dsp/filters.dart';

/// Ghi âm qua AudioRecord native (MethodChannel/EventChannel tự viết — không
/// dùng package `record` vì mâu thuẫn version trên pub). Foreground Service
/// kiểu microphone cho phép ghi khi tắt màn hình; NS/EchoCanceler/AGC bật ở
/// native; lọc thông cao 85 Hz + VAD chạy trong Dart.
/// PCM 16 kHz mono 16-bit — dùng trực tiếp cho chấm điểm offline (bước 4).
class RecorderService {
  static const MethodChannel _ch = MethodChannel('shadow_talk/recorder');
  static const MethodChannel _audio = MethodChannel('shadow_talk/audio');
  static const EventChannel _stream = EventChannel('shadow_talk/recorder_stream');

  StreamSubscription? _sub;
  final List<int> _pcm = [];
  late BiquadHighPass _hpf;
  late Vad _vad;
  bool _recording = false;

  void Function(double rms, bool speech)? onLevel;
  void Function(List<int> pcm)? onDone;

  Future<bool> hasPermission() async {
    try {
      return await _audio.invokeMethod('hasPermission') == true;
    } catch (_) {
      return false;
    }
  }

  /// Chuyển đường mic sang tai nghe Bluetooth (SCO) nếu có cắm.
  Future<void> startSco() async {
    try {
      await _audio.invokeMethod('startBluetoothSco');
    } catch (_) {}
  }

  Future<void> stopSco() async {
    try {
      await _audio.invokeMethod('stopBluetoothSco');
    } catch (_) {}
  }

  Future<void> start() async {
    if (_recording) return;
    _pcm.clear();
    _hpf = BiquadHighPass(85, 16000);
    _vad = Vad();
    _recording = true;
    _sub = _stream.receiveBroadcastStream().listen(
      (chunk) {
        if (chunk is Uint8List) _onChunk(chunk);
      },
      onError: (_) {},
    );
    await _ch.invokeMethod('start');
  }

  void _onChunk(Uint8List chunk) {
    final samples = int16FromBytes(chunk);
    final filtered = [for (final s in samples) _hpf.process(s.toDouble())];
    final r = rmsOf(filtered);
    _pcm.addAll(samples);
    final stepMs = samples.length / 16.0; // 16 kHz => 16 sample = 1 ms
    _vad.feed(r, stepMs);
    onLevel?.call(r, _vad.speech);
    if (_vad.silenceAfterSpeech) {
      finish();
    }
  }

  /// Dừng ghi và trả PCM đã thu về callback onDone.
  Future<void> finish() async {
    if (!_recording) return;
    _recording = false;
    await _sub?.cancel();
    _sub = null;
    try {
      await _ch.invokeMethod('stop');
    } catch (_) {}
    await stopSco();
    final data = List<int>.from(_pcm);
    onDone?.call(data);
  }

  Future<String> saveWav(List<int> pcm, String name) async {
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/$name');
    await f.writeAsBytes(buildWav(pcm, 16000), flush: true);
    return f.path;
  }

  bool get isRecording => _recording;

  Future<void> dispose() async {
    await finish();
  }
}
