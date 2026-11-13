import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_talk/dsp/filters.dart';
import 'package:shadow_talk/models/models.dart';
import 'package:shadow_talk/scoring/scoring.dart';

void main() {
  test('Lesson.fromJson đọc đủ câu + rev mặc định', () {
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
    expect(l.rev, 1);
  });

  test('AppSettings vòng đời JSON', () {
    final s = AppSettings(
        speed: 0.7,
        autoMode: false,
        preRecordDelayMs: 2000,
        passThreshold: 80,
        bluetoothMic: false);
    final back = AppSettings.fromJson(s.toJson());
    expect(back.speed, 0.7);
    expect(back.autoMode, false);
    expect(back.preRecordDelayMs, 2000);
    expect(back.passThreshold, 80);
    expect(back.bluetoothMic, false);
  });

  test('SessionRecord vòng đời JSON', () {
    final r = SessionRecord(
        dateIso: '2026-11-13T10:00:00',
        lessonId: 'x',
        title: 'Bài thử',
        scores: [80, 90],
        avg: 85,
        kind: 'practice',
        resultLevel: null);
    final back = SessionRecord.fromJson(r.toJson());
    expect(back.avg, 85);
    expect(back.scores.length, 2);
    expect(back.kind, 'practice');
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

  test('alignWords: khớp + lệch + thiếu + thừa', () {
    final m = alignWords(['how', 'much', 'is', 'this'], ['how', 'much', 'bag']);
    // how=ok, much=ok, is=sub(bag), this=del
    final st = m.map((w) => w.status).toList();
    expect(st, [WordStatus.ok, WordStatus.ok, WordStatus.sub, WordStatus.del]);
  });

  test('normalizeWords bỏ dấu câu, chữ thường', () {
    final w = normalizeWords("Hello, World! It's 5 o'clock.");
    expect(w, ["hello", "world", "it's", "5", "o'clock"]);
  });

  test('scoreSentence: không nói gì = 0 điểm', () {
    final s = scoreSentence(
        expectedWords: normalizeWords('How are you'),
        heardWords: [],
        spokenMs: 2000);
    expect(s.total, 0);
  });

  test('scoreSentence: đọc đúng chuẩn theo nhịp hợp lý = điểm cao', () {
    final s = scoreSentence(
        expectedWords: normalizeWords('How much is this bag'),
        heardWords: normalizeWords('How much is this bag'),
        spokenMs: 2500); // ~120 wpm
    expect(s.total, greaterThan(85));
  });

  test('scoreSentence: nói thiếu từ bị trừ', () {
    final full = scoreSentence(
        expectedWords: normalizeWords('How much is this bag'),
        heardWords: normalizeWords('How much is this bag'),
        spokenMs: 2500);
    final short = scoreSentence(
        expectedWords: normalizeWords('How much is this bag'),
        heardWords: normalizeWords('How much is bag'),
        spokenMs: 2000);
    expect(short.total, lessThan(full.total));
  });
}
