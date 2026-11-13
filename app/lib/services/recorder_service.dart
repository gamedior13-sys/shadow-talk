import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../dsp/filters.dart';

/// Ghi âm qua Foreground Service (tắt màn vẫn chạy) + WebRTC
/// NoiseSuppressor/EchoCanceler + lọc thông cao 85 Hz trong Dart.
/// Ghi dạng stream PCM 16 kHz để sau này nhét thẳng vào chấm điểm offline.
class RecorderService {
  final AudioRecorder _rec = AudioRecorder();
  static const MethodChannel _sco = MethodChannel('shadow_talk/audio');

  StreamSubscription<Uint8List>? _sub;
  final List<int> _pcm = [];
  late BiquadHighPass _hpf;
  late Vad _vad;
  bool _recording = false;

  void Function(double rms, bool speech)? onLevel;
  void Function(List<int> pcm)? onDone;

  Future<bool> hasPermission() => _rec.hasPermission();

  /// Chuyển đường mic sang tai nghe Bluetooth (SCO) nếu có cắm.
  Future<void> startSco() async {
    try {
      await _sco.invokeMethod('startBluetoothSco');
    } catch (_) {}
  }

  Future<void> stopSco() async {
    try {
      await _sco.invokeMethod('stopBluetoothSco');
    } catch (_) {}
  }

  Future<void> start() async {
    if (_recording) return;
    _pcm.clear();
    _hpf = BiquadHighPass(85, 16000);
    _vad = Vad();
    _recording = true;
    final stream = await _rec.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
      autoGain: true,
      echoCancel: true,
      noiseSuppress: true,
    ));
    _sub = stream.listen(_onChunk);
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
      await _rec.stop();
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
    await _sub?.cancel();
    try {
      await _rec.dispose();
    } catch (_) {}
  }
}
