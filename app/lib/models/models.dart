import 'dart:ui';

/// Bảng màu v0.4: trắng tối giản + xanh + đỏ hiện đại.
const Color kBg = Color(0xFFF6F8FB);
const Color kCard = Color(0xFFFFFFFF);
const Color kLine = Color(0xFFE5E9F0);
const Color kText = Color(0xFF0F172A);
const Color kMuted = Color(0xFF64748B);
const Color kBlue = Color(0xFF2563EB);
const Color kBlueSoft = Color(0xFFDBEAFE);
const Color kRed = Color(0xFFDC2626);
const Color kRedSoft = Color(0xFFFEE2E2);
const Color kGreen = Color(0xFF16A34A);
const Color kGreenSoft = Color(0xFFDCFCE7);

/// Danh sách cấp độ — index là vị trí trong lộ trình.
const List<String> kLevels = ['A1', 'A2', 'B1', 'B2', 'C1'];

const Map<String, String> kTopicNames = {
  'daily': 'Giao tiếp hằng ngày',
  'work': 'Công việc / bán hàng',
  'travel': 'Du lịch',
};

class Sentence {
  final String en;
  final String vi;
  const Sentence(this.en, this.vi);

  factory Sentence.fromJson(Map<String, dynamic> j) =>
      Sentence(j['en'] as String, j['vi'] as String);

  Map<String, dynamic> toJson() => {'en': en, 'vi': vi};
}

class Lesson {
  final String id;
  final String topic;
  final String level;
  final String titleVi;
  final List<Sentence> sentences;
  final int rev; // tăng khi nội dung/audio đổi → app sync tải lại
  const Lesson(this.id, this.topic, this.level, this.titleVi, this.sentences,
      {this.rev = 1});

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
        j['id'] as String,
        j['topic'] as String,
        j['level'] as String,
        j['title_vi'] as String,
        (j['sentences'] as List)
            .map((e) => Sentence.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        rev: (j['rev'] as int?) ?? 1,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'topic': topic,
        'level': level,
        'title_vi': titleVi,
        'rev': rev,
        'sentences': sentences.map((s) => s.toJson()).toList(),
      };
}

/// Nguồn phát audio: asset đóng gói sẵn hoặc file đã tải về máy.
class AudioRef {
  final bool isFile;
  final String path;
  const AudioRef.asset(this.path) : isFile = false;
  const AudioRef.file(this.path) : isFile = true;
}

/// 1 câu trong phiên luyện/kiểm tra: câu + audio nguồn + level của câu.
class PracticeItem {
  final Sentence sentence;
  final AudioRef audio;
  final String level;
  const PracticeItem(this.sentence, this.audio, this.level);
}

class LessonProgress {
  double? bestScore;
  int attempts;
  int lastIdx;
  LessonProgress({this.bestScore, this.attempts = 0, this.lastIdx = -1});

  Map<String, dynamic> toJson() =>
      {'best': bestScore, 'attempts': attempts, 'lastIdx': lastIdx};

  factory LessonProgress.fromJson(Map<String, dynamic> j) => LessonProgress(
        bestScore: (j['best'] as num?)?.toDouble(),
        attempts: (j['attempts'] as int?) ?? 0,
        lastIdx: (j['lastIdx'] as int?) ?? -1,
      );
}

/// Kết quả 1 buổi luyện/kiểm tra — lưu lịch sử để xem lại điểm mỗi buổi.
class SessionRecord {
  final String dateIso;
  final String lessonId;
  final String title;
  final List<double> scores;
  final double avg;
  final String kind; // practice | placement | promotion
  final String? resultLevel; // level kết quả (với bài kiểm tra)

  SessionRecord({
    required this.dateIso,
    required this.lessonId,
    required this.title,
    required this.scores,
    required this.avg,
    required this.kind,
    this.resultLevel,
  });

  Map<String, dynamic> toJson() => {
        'dateIso': dateIso,
        'lessonId': lessonId,
        'title': title,
        'scores': scores,
        'avg': avg,
        'kind': kind,
        'resultLevel': resultLevel,
      };

  factory SessionRecord.fromJson(Map<String, dynamic> j) => SessionRecord(
        dateIso: j['dateIso'] as String,
        lessonId: j['lessonId'] as String,
        title: j['title'] as String,
        scores: ((j['scores'] as List?) ?? const [])
            .map((e) => (e as num).toDouble())
            .toList(),
        avg: (j['avg'] as num?)?.toDouble() ?? 0,
        kind: j['kind'] as String? ?? 'practice',
        resultLevel: j['resultLevel'] as String?,
      );
}

class AppSettings {
  double speed;
  bool autoMode;
  int preRecordDelayMs;
  int passThreshold;
  bool bluetoothMic;
  AppSettings({
    this.speed = 0.85,
    this.autoMode = true,
    this.preRecordDelayMs = 1200,
    this.passThreshold = 70,
    this.bluetoothMic = true,
  });

  Map<String, dynamic> toJson() => {
        'speed': speed,
        'autoMode': autoMode,
        'preRecordDelayMs': preRecordDelayMs,
        'passThreshold': passThreshold,
        'bluetoothMic': bluetoothMic,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        speed: (j['speed'] as num?)?.toDouble() ?? 0.85,
        autoMode: (j['autoMode'] as bool?) ?? true,
        preRecordDelayMs: (j['preRecordDelayMs'] as int?) ?? 1200,
        passThreshold: (j['passThreshold'] as int?) ?? 70,
        bluetoothMic: (j['bluetoothMic'] as bool?) ?? true,
      );
}

class ProgressData {
  String? lastDate;
  int streakDays;
  Map<String, LessonProgress> lessons;
  ProgressData({
    this.lastDate,
    this.streakDays = 0,
    Map<String, LessonProgress>? lessons,
  }) : lessons = lessons ?? {};

  Map<String, dynamic> toJson() => {
        'lastDate': lastDate,
        'streakDays': streakDays,
        'lessons': lessons.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory ProgressData.fromJson(Map<String, dynamic> j) => ProgressData(
        lastDate: j['lastDate'] as String?,
        streakDays: (j['streakDays'] as int?) ?? 0,
        lessons: ((j['lessons'] as Map?) ?? const {}).map((k, v) =>
            MapEntry(k as String,
                LessonProgress.fromJson(Map<String, dynamic>.from(v as Map)))),
      );
}
