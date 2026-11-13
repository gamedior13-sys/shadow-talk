import 'dart:math';

/// Chấm điểm offline thuần Dart — không phụ thuộc engine ASR cụ thể.
/// Điểm = 70% khớp từ + 20% độ phủ (không bỏ từ) + 10% tốc độ nói hợp lý.

enum WordStatus { ok, sub, del, ins }

class WordMatch {
  final String expected;
  final String heard;
  final WordStatus status;
  const WordMatch(this.expected, this.heard, this.status);
}

class SentenceScore {
  final double total; // 0..100
  final double accuracy;
  final double coverage;
  final double rateScore;
  final List<WordMatch> matches;
  final int spokenMs;
  const SentenceScore({
    required this.total,
    required this.accuracy,
    required this.coverage,
    required this.rateScore,
    required this.matches,
    required this.spokenMs,
  });
}

/// Chuẩn hoá câu thành danh sách từ: chữ thường, bỏ dấu câu.
List<String> normalizeWords(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r"[^a-z0-9'\s]"), ' ')
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .toList();

/// Căn chỉnh 2 chuỗi từ bằng Levenshtein + backtrace.
/// ok = khớp, sub = nói lệch, del = thiếu (không nói), ins = thừa.
List<WordMatch> alignWords(List<String> expected, List<String> heard) {
  final m = expected.length, n = heard.length;
  // dp[i][j] = chi phí biến đổi expected[0..i) thành heard[0..j)
  final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));
  for (var i = 0; i <= m; i++) {
    dp[i][0] = i; // xoá hết
  }
  for (var j = 0; j <= n; j++) {
    dp[0][j] = j; // chèn hết
  }
  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      final same = expected[i - 1] == heard[j - 1];
      final cost = same ? 0 : 1;
      dp[i][j] = min(dp[i - 1][j - 1] + cost,
          min(dp[i - 1][j] + 1, dp[i][j - 1] + 1));
    }
  }
  // Backtrace từ (m, n)
  final out = <WordMatch>[];
  var i = m, j = n;
  while (i > 0 || j > 0) {
    if (i > 0 && j > 0 && dp[i][j] == dp[i - 1][j - 1] + (expected[i - 1] == heard[j - 1] ? 0 : 1)) {
      out.add(WordMatch(expected[i - 1], heard[j - 1],
          expected[i - 1] == heard[j - 1] ? WordStatus.ok : WordStatus.sub));
      i--;
      j--;
    } else if (i > 0 && dp[i][j] == dp[i - 1][j] + 1) {
      out.add(WordMatch(expected[i - 1], '', WordStatus.del));
      i--;
    } else {
      out.add(WordMatch('', heard[j - 1], WordStatus.ins));
      j--;
    }
  }
  return out.reversed.toList();
}

SentenceScore scoreSentence({
  required List<String> expectedWords,
  required List<String> heardWords,
  required int spokenMs,
}) {
  final matches = alignWords(expectedWords, heardWords);
  final matched = matches.where((w) => w.status == WordStatus.ok).length;
  final del = matches.where((w) => w.status == WordStatus.del).length;
  final accuracy = expectedWords.isEmpty
      ? 0.0
      : matched / expectedWords.length;
  final coverage =
      expectedWords.isEmpty ? 0.0 : (expectedWords.length - del) / expectedWords.length;
  final minutes = spokenMs / 60000.0;
  double rateScore;
  if (heardWords.isEmpty || minutes <= 0) {
    rateScore = 0;
  } else {
    final wpm = heardWords.length / minutes;
    if (wpm >= 90 && wpm <= 180) {
      rateScore = 1;
    } else if (wpm < 90) {
      rateScore = max(0, wpm / 90);
    } else {
      rateScore = max(0, 180 / wpm);
    }
  }
  final total = (100 * (0.7 * accuracy + 0.2 * coverage + 0.1 * rateScore))
      .clamp(0, 100)
      .toDouble();
  return SentenceScore(
    total: total,
    accuracy: accuracy,
    coverage: coverage,
    rateScore: rateScore,
    matches: matches,
    spokenMs: spokenMs,
  );
}
