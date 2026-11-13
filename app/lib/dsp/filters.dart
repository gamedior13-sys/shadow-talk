import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// Lọc thông cao 85 Hz (RBJ cookbook) — bỏ ù máy và tiếng động cơ xe.
class BiquadHighPass {
  final double b0, b1, b2, a1, a2;
  double _x1 = 0, _x2 = 0, _y1 = 0, _y2 = 0;

  factory BiquadHighPass(double freqHz, double sampleRate, {double q = 0.7071}) {
    final w0 = 2 * pi * freqHz / sampleRate;
    final c = cos(w0), s = sin(w0);
    final alpha = s / (2 * q);
    final a0 = 1 + alpha;
    final bb = (1 + c) / 2;
    return BiquadHighPass._(
        bb / a0, -2 * bb / a0, bb / a0, -2 * c / a0, (1 - alpha) / a0);
  }

  BiquadHighPass._(this.b0, this.b1, this.b2, this.a1, this.a2);

  double process(double x) {
    final y = b0 * x + b1 * _x1 + b2 * _x2 - a1 * _y1 - a2 * _y2;
    _x2 = _x1;
    _x1 = x;
    _y2 = _y1;
    _y1 = y;
    return y;
  }
}

double rmsOf(List<double> x) {
  if (x.isEmpty) return 0;
  var sum = 0.0;
  for (final v in x) {
    sum += v * v;
  }
  return sqrt(sum / x.length);
}

/// Chuyển PCM little-endian 16-bit (Uint8List) sang danh sách sample.
List<int> int16FromBytes(Uint8List bytes) {
  final out = List<int>.filled(bytes.length ~/ 2, 0);
  for (var i = 0; i < out.length; i++) {
    var v = (bytes[2 * i + 1] << 8) | bytes[2 * i];
    if (v >= 32768) v -= 65536;
    out[i] = v;
  }
  return out;
}

/// Ghép file WAV 16-bit mono từ PCM thô.
Uint8List buildWav(List<int> pcm16, int sampleRate) {
  final dataLen = pcm16.length * 2;
  final b = BytesBuilder();
  void str(String s) => b.add(ascii.encode(s));
  void u32(int v) =>
      b.add([v & 255, (v >> 8) & 255, (v >> 16) & 255, (v >> 24) & 255]);
  void u16(int v) => b.add([v & 255, (v >> 8) & 255]);
  str('RIFF');
  u32(36 + dataLen);
  str('WAVE');
  str('fmt ');
  u32(16);
  u16(1);
  u16(1);
  u32(sampleRate);
  u32(sampleRate * 2);
  u16(2);
  u16(16);
  str('data');
  u32(dataLen);
  for (final s in pcm16) {
    u16(s & 0xFFFF);
  }
  return b.toBytes();
}

/// VAD năng lượng với ngưỡng thích nghi theo sàn nhiễu — dùng để
/// tự dừng ghi khi anh nói xong 1 câu (kể cả môi trường ồn).
class Vad {
  double noiseDb;
  final double hangTargetMs;
  bool speechSeen = false;
  bool speech = false;
  int _hangMs = 0;

  Vad({double floorStartDb = -58, this.hangTargetMs = 1500})
      : noiseDb = floorStartDb;

  static double _db(double rms) => 20 * log(max(rms, 1e-10)) / ln10;

  void feed(double rms, double stepMs) {
    final db = _db(rms);
    final thresh = max(noiseDb + 8, -42);
    if (db >= thresh) {
      speech = true;
      speechSeen = true;
      _hangMs = hangTargetMs.round();
    } else {
      speech = false;
      // Sàn nhiễu chỉ trôi lên rất chậm để không "tự phóng đại" ngưỡng.
      noiseDb = max(noiseDb, min(db, noiseDb + 0.02));
      _hangMs = max(0, _hangMs - stepMs.round());
    }
  }

  bool get silenceAfterSpeech => speechSeen && _hangMs == 0;
}
