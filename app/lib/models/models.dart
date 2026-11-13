/// Mô hình dữ liệu của Shadow Talk.
library;

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
  const Lesson(this.id, this.topic, this.level, this.titleVi, this.sentences);

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
        j['id'] as String,
        j['topic'] as String,
        j['level'] as String,
        j['title_vi'] as String,
        (j['sentences'] as List)
            .map((e) => Sentence.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

const Map<String, String> kTopicNames = {
  'daily': 'Giao tiếp hằng ngày',
  'work': 'Công việc / bán hàng',
  'travel': 'Du lịch',
};

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
