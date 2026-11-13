import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_talk/dsp/filters.dart';
import 'package:shadow_talk/models/models.dart';

void main() {
  test('Lesson.fromJson đọc đủ câu', () {
    final l = Lesson.fromJson({
      'id': 'test',
      'topic': 'daily',
      'level': 'A2',
      'title_vi': 'Thử',
      'sentences': [
        {'en': 'Hello world.', 'vi': 'Xin chào.'},
        {'en': 'How are you?', 'vi': 'Bạn thế nào?'},
      ],
    });
    expect(l.sentences.length, 2);
    expect(l.sentences.first.vi, 'Xin chào.');
  });

  test('AppSettings vòng đời JSON', () {
    final s = AppSettings(speed: 0.7, autoMode: false, preRecordDelayMs: 2000,
        passThreshold: 80, bluetoothMic: false);
    final back = AppSettings.fromJson(s.toJson());
    expect(back.speed, 0.7);
    expect(back.autoMode, false);
    expect(back.preRecordDelayMs, 2000);
    expect(back.passThreshold, 80);
    expect(back.bluetoothMic, false);
  });

  test('High-pass 85 Hz chặn tín hiệu một chiều (DC)', () {
    final f = BiquadHighPass(85, 16000);
    var maxErr = 0.0;
    for (var i = 0; i < 5000; i++) {
      final y = f.process(1000);
      if (i > 3500) maxErr = max(maxErr, y.abs());
    }
    expect(maxErr, lessThan(60));
  });

  test('VAD: phát hiện nói rồi im lặng sau ngắt nghỉ', () {
    final vad = Vad();
    for (var i = 0; i < 10; i++) {
      vad.feed(0.05, 100); // -26 dB > ngưỡng
    }
    expect(vad.speech, isTrue);
    expect(vad.silenceAfterSpeech, isFalse);
    for (var i = 0; i < 20; i++) {
      vad.feed(1e-6, 100); // im lặng 2 s > ngắt nghỉ 1,5 s
    }
    expect(vad.silenceAfterSpeech, isTrue);
  });

  test('buildWav đúng kích thước header', () {
    final wav = buildWav([100, -100, 3000], 16000);
    expect(wav.length, 44 + 6);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
  });
}
