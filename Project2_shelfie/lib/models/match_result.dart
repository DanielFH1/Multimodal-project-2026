import 'dart:ui';

/// Represents a single match found by OCR in the camera view.
class MatchResult {
  /// The recognized text that matched.
  final String recognizedText;

  /// The user's search query string.
  final String queryText;

  /// Similarity score (0.0 to 1.0).
  final double similarity;

  /// Bounding box of the matched text in image coordinates.
  final Rect boundingBox;

  /// Timestamp when this match was detected.
  final DateTime detectedAt;

  const MatchResult({
    required this.recognizedText,
    required this.queryText,
    required this.similarity,
    required this.boundingBox,
    required this.detectedAt,
  });

  bool get isExactMatch => similarity >= 0.95;
  bool get isStrongMatch => similarity >= 0.75;

  @override
  String toString() =>
      'MatchResult(text: "$recognizedText", similarity: ${(similarity * 100).toStringAsFixed(1)}%)';
}
