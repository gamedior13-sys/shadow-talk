import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../scoring/scoring.dart';
import '../state/app_state.dart';
import 'asr_service.dart';
import 'player_service.dart';
import 'recorder_service.dart';

enum Phase {
  idle,
  loadingModel,
  playing,
  countdown,
  recording,
  scoring,
  scored,
  finished,
}

enum PracticeMode { practice, placement, promotion }

/// Kết quả 1 câu trong phiên.
class Take {
  final int idx;
  final double? score;
  final List<WordMatch> matches;
  final int spokenMs;
  final String level;
  Take(this.idx, this.score, this.matches, this.spokenMs, this.level);
}

class PracticeController extends ChangeNotifier {
  PracticeController({
    required this.items,
    required this.mode,
    required this.lessonId,
    required this.title,
    required this.app,
    required this.player,
    required this.recorder,
    required this.asr,
  });

  final List<PracticeItem> items;
  final PracticeMode mode;
  final String lessonId;
  final String title;
  final AppState app;
  final PlayerService player;
  final RecorderService recorder;
  final AsrService asr;

  int idx = 0;
  Phase phase = Phase.idle;
  double level = 0;
  double? lastScore;
  List<WordMatch> lastMatches = const [];
  String? heardText;
  int lastRecordMs = 0;
  bool speechSeen = false;
  double modelProgress = 0;
  final List<Take> takes = [];
  SessionRecord? record;
  bool promoted = false;
  int? newLevelIndex;
  Timer? _safety;
  bool _scoringBusy = false;

  PracticeItem get item => items[idx];
  Sentence get current => item.sentence;

  Future<void> playCurrent({bool autoNext = true}) async {
    phase = Phase.playing;
    notifyListeners();
    await player.setSpeed(app.settings.speed);
    await player.playRef(item.audio,
        title: title,
        album: mode == PracticeMode.practice ? 'Bài học' : 'Kiểm tra');
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
    _safety?.cancel();
    _safety = Timer(const Duration(seconds: 20), () => recorder.finish());
  }

  Future<void> _onRecorded(List<int> pcm) async {
    _safety?.cancel();
    lastPcm = List<int>.from(pcm);
    lastRecordMs = pcm.length ~/ 16; // 16 sample = 1 ms
    phase = Phase.scoring;
    notifyListeners();
    if (_scoringBusy) return;
    _scoringBusy = true;
    try {
      var ready = await asr.isModelReady();
      if (!ready) {
        phase = Phase.loadingModel;
        notifyListeners();
        await asr.downloadModel(onDownload: (done, total) {
          modelProgress = total > 0 ? done / total : 0;
          notifyListeners();
        });
      }
      await asr.ensureLoaded();
      final heard = await asr.transcribe(lastPcm);
      heardText = heard;
      final exp = normalizeWords(current.en);
      final heardW = (heard == null || heard.isEmpty)
          ? <String>[]
          : normalizeWords(heard);
      final sc = scoreSentence(
          expectedWords: exp, heardWords: heardW, spokenMs: lastRecordMs);
      lastScore = sc.total;
      lastMatches = sc.matches;
      takes.add(Take(idx, sc.total, sc.matches, lastRecordMs, item.level));
      if (mode == PracticeMode.practice) {
        app.recordScore(lessonId, idx, sc.total);
      }
      phase = Phase.scored;
      notifyListeners();
    } catch (_) {
      lastScore = null;
      lastMatches = const [];
      phase = Phase.scored;
      notifyListeners();
    } finally {
      _scoringBusy = false;
    }
  }

  Future<void> playMyRecording() async {
    if (lastPcm.isEmpty) return;
    final path = await recorder.saveWav(lastPcm, 'last_take.wav');
    await player.playFile(path);
  }

  void repeat() => playCurrent();

  void next() {
    if (idx < items.length - 1) {
      idx++;
      playCurrent();
    } else {
      _finishSession();
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

  void _finishSession() {
    final scores = takes
        .map((t) => t.score)
        .whereType<double>()
        .toList();
    final avg = scores.isEmpty
        ? 0.0
        : scores.reduce((a, b) => a + b) / scores.length;
    var rec = SessionRecord(
      dateIso: DateTime.now().toIso8601String(),
      lessonId: lessonId,
      title: title,
      scores: scores,
      avg: avg,
      kind: mode.name,
    );
    if (mode == PracticeMode.placement) {
      final rec2 = _recommendLevel();
      newLevelIndex = rec2;
      rec = SessionRecord(
        dateIso: rec.dateIso,
        lessonId: rec.lessonId,
        title: rec.title,
        scores: rec.scores,
        avg: avg,
        kind: rec.kind,
        resultLevel: kLevels[rec2],
      );
      app.setPlacement(rec2);
    } else if (mode == PracticeMode.promotion) {
      final pass = avg >= app.settings.passThreshold;
      promoted = pass;
      if (pass) {
        newLevelIndex = min(app.levelIndex + 1, kLevels.length - 1);
        rec = SessionRecord(
          dateIso: rec.dateIso,
          lessonId: rec.lessonId,
          title: rec.title,
          scores: rec.scores,
          avg: avg,
          kind: rec.kind,
          resultLevel: kLevels[newLevelIndex!],
        );
        app.promote();
      }
    } else {
      app.markProgress(lessonId, items.length - 1);
    }
    record = rec;
    app.addSession(rec);
  }

  /// Placement: level cao nhất mà điểm trung bình câu của level đó đạt ngưỡng.
  int _recommendLevel() {
    for (final li in [3, 2, 1]) {
      final lv = kLevels[li];
      final ss = takes
          .where((t) => t.level == lv)
          .map((t) => t.score)
          .whereType<double>()
          .toList();
      if (ss.isNotEmpty) {
        final a = ss.reduce((x, y) => x + y) / ss.length;
        if (a >= app.settings.passThreshold) return li;
      }
    }
    return 1; // A2
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
