import 'dart:math';

/// Service for matching recognized text against user's search query.
/// Supports fuzzy matching (Levenshtein distance), contains matching,
/// and word-level matching for robust real-world OCR results.
class TextMatcherService {
  /// Minimum similarity threshold for considering a match (0.0 - 1.0).
  final double threshold;

  const TextMatcherService({this.threshold = 0.55});

  /// Check if [recognized] text matches the [query].
  /// Returns similarity score (0.0 - 1.0) or 0 if below threshold.
  double match(String query, String recognized) {
    if (query.isEmpty || recognized.isEmpty) return 0.0;

    final q = _normalize(query);
    final r = _normalize(recognized);

    if (q.isEmpty || r.isEmpty) return 0.0;

    // 1. Exact contains match
    if (r.contains(q) || q.contains(r)) {
      final ratio = min(q.length, r.length) / max(q.length, r.length);
      final score = 0.8 + (0.2 * ratio);
      return score >= threshold ? score : 0.0;
    }

    // 2. Word-level matching: check if query words appear in recognized text
    final queryWords = q.split(RegExp(r'\s+'));
    final recognizedWords = r.split(RegExp(r'\s+'));
    if (queryWords.length > 1) {
      int matchedWords = 0;
      for (final qw in queryWords) {
        for (final rw in recognizedWords) {
          if (rw.contains(qw) || qw.contains(rw)) {
            matchedWords++;
            break;
          }
          if (_levenshteinSimilarity(qw, rw) >= 0.7) {
            matchedWords++;
            break;
          }
        }
      }
      final wordScore = matchedWords / queryWords.length;
      if (wordScore >= threshold) return wordScore;
    }

    // 3. Fuzzy matching using Levenshtein distance
    final fuzzyScore = _levenshteinSimilarity(q, r);
    return fuzzyScore >= threshold ? fuzzyScore : 0.0;
  }

  /// Find the best match among multiple recognized text blocks.
  /// Returns the highest score and the index of the best match.
  ({double score, int index}) findBestMatch(
    String query,
    List<String> recognizedTexts,
  ) {
    double bestScore = 0.0;
    int bestIndex = -1;

    for (int i = 0; i < recognizedTexts.length; i++) {
      final score = match(query, recognizedTexts[i]);
      if (score > bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }

    return (score: bestScore, index: bestIndex);
  }

  /// Normalize text for comparison: lowercase, trim, remove extra spaces.
  String _normalize(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\w\s가-힣ㄱ-ㅎㅏ-ㅣ\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]'), '');
  }

  /// Compute Levenshtein similarity as a ratio (0.0 - 1.0).
  double _levenshteinSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final distance = _levenshteinDistance(s1, s2);
    final maxLen = max(s1.length, s2.length);
    return 1.0 - (distance / maxLen);
  }

  /// Standard Levenshtein distance implementation.
  int _levenshteinDistance(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;

    // Optimize for memory: only keep current and previous rows
    List<int> prev = List.generate(len2 + 1, (i) => i);
    List<int> curr = List.filled(len2 + 1, 0);

    for (int i = 1; i <= len1; i++) {
      curr[0] = i;
      for (int j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        curr[j] = min(
          min(curr[j - 1] + 1, prev[j] + 1),
          prev[j - 1] + cost,
        );
      }
      final temp = prev;
      prev = curr;
      curr = temp;
    }

    return prev[len2];
  }
}
