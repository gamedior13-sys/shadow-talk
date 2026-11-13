import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/lesson_repository.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import 'player_service.dart';
import 'recorder_service.dart';

enum Phase { idle, playing, countdown, recording, recorded, finished }

/// Máy trạng thái 1 câu: phát mẫu → (đợi) → ghi → VAD dừng → (chấm — bước 4)
/// → sang câu kế. Chế độ đi xe chạy trọn chu trình tự động.
class PracticeController extends ChangeNotifier {
  PracticeController({
    required this.lesson,
    required this.app,
    required this.player,
    required this.recorder,
  });

  final Lesson lesson;
  final AppState app;
  final PlayerService player;
  final RecorderService recorder;

  int idx = 0;
  Phase phase = Phase.idle;
  double level = 0;
  double? lastScore; // bước 4 sẽ điền điểm thật
  int lastRecordMs = 0;
  bool speechSeen = false;
  List<int> lastPcm = [];
  Timer? _safety;

  Sentence get current => lesson.sentences[idx];
  String get sentenceAudio => sentenceAudioAsset(lesson.id, idx + 1);

  Future<void> playCurrent({bool autoNext = true}) async {
    phase = Phase.playing;
    notifyListeners();
    await player.setSpeed(app.settings.speed);
    await player.playAsset(sentenceAudio,
        title: lesson.titleVi,
        album: kTopicNames[lesson.topic] ?? lesson.topic);
    if (autoNext && app.settings.autoMode) {
      await _countdownAndRecord();
    } else {
      phase = Phase.idle;
      notifyListeners();
    }
  }

  Future<void> _countdownAndRecord() async {
    phase = Phase.countdown;
    notifyListeners();
    await Future.delayed(Duration(milliseconds: app.settings.preRecordDelayMs));
    await startRecording();
  }

  Future<void> startRecording() async {
    if (phase == Phase.recording) return;
    final ok = await recorder.hasPermission();
    if (!ok) {
      phase = Phase.idle;
      notifyListeners();
      return;
    }
    if (app.settings.bluetoothMic) await recorder.startSco();
    speechSeen = false;
    level = 0;
    phase = Phase.recording;
    notifyListeners();
    recorder.onLevel = (rms, speech) {
      level = rms;
      if (speech) speechSeen = true;
      notifyListeners();
    };
    recorder.onDone = _onRecorded;
    await recorder.start();
    // An toàn: câu quá 20 s thì buộc dừng để không ghi vĩnh viễn.
    _safety?.cancel();
    _safety = Timer(const Duration(seconds: 20), () => recorder.finish());
  }

  void _onRecorded(List<int> pcm) {
    _safety?.cancel();
    lastPcm = List<int>.from(pcm);
    lastRecordMs = pcm.length ~/ 16; // 16 sample = 1 ms
    phase = Phase.recorded;
    lastScore = null; // bước 4 thay bằng chấm điểm thật
    notifyListeners();
    app.markProgress(lesson.id, idx);
  }

  Future<void> playMyRecording() async {
    if (lastPcm.isEmpty) return;
    final path = await recorder.saveWav(lastPcm, 'last_take.wav');
    await player.playFile(path);
  }

  void repeat() => playCurrent();

  void next() {
    if (idx < lesson.sentences.length - 1) {
      idx++;
      playCurrent();
    } else {
      phase = Phase.finished;
      notifyListeners();
    }
  }

  void previous() {
    if (idx > 0) {
      idx--;
      playCurrent();
    }
  }

  @override
  void dispose() {
    _safety?.cancel();
    recorder.onLevel = null;
    recorder.onDone = null;
    recorder.finish();
    player.stop();
    super.dispose();
  }
}
