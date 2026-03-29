import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../models/match_result.dart';

/// Custom painter that draws highlighted bounding boxes over matched text
/// on the camera preview.
class OverlayPainter extends CustomPainter {
  final List<MatchResult> matches;
  final Size imageSize;
  final Size widgetSize;

  OverlayPainter({
    required this.matches,
    required this.imageSize,
    required this.widgetSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (matches.isEmpty) return;

    for (final match in matches) {
      // Transform bounding box from image coordinates to screen coordinates
      final rect = _transformRect(match.boundingBox, size);

      // Draw glow effect
      final glowPaint = Paint()
        ..color = _getMatchColor(match).withValues(alpha: 0.25)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(6), const Radius.circular(8)),
        glowPaint,
      );

      // Draw filled rectangle with transparency
      final fillPaint = Paint()
        ..color = _getMatchColor(match).withValues(alpha: 0.25)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        fillPaint,
      );

      // Draw border
      final borderPaint = Paint()
        ..color = _getMatchColor(match)
        ..style = PaintingStyle.stroke
        ..strokeWidth = match.isExactMatch ? 3.5 : 2.5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        borderPaint,
      );

      // Draw corner accents for premium look
      _drawCornerAccents(canvas, rect, match);

      // Draw match percentage label
      _drawLabel(canvas, rect, match);
    }
  }

  Color _getMatchColor(MatchResult match) {
    if (match.isExactMatch) return const Color(0xFF00E676); // Bright Green
    if (match.isStrongMatch) return const Color(0xFFFFD740); // Amber
    return const Color(0xFFFF6E40); // Orange
  }

  void _drawCornerAccents(Canvas canvas, Rect rect, MatchResult match) {
    final paint = Paint()
      ..color = _getMatchColor(match)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    const cornerLen = 14.0;

    // Top-left
    canvas.drawLine(rect.topLeft, Offset(rect.left + cornerLen, rect.top), paint);
    canvas.drawLine(rect.topLeft, Offset(rect.left, rect.top + cornerLen), paint);

    // Top-right
    canvas.drawLine(rect.topRight, Offset(rect.right - cornerLen, rect.top), paint);
    canvas.drawLine(rect.topRight, Offset(rect.right, rect.top + cornerLen), paint);

    // Bottom-left
    canvas.drawLine(rect.bottomLeft, Offset(rect.left + cornerLen, rect.bottom), paint);
    canvas.drawLine(rect.bottomLeft, Offset(rect.left, rect.bottom - cornerLen), paint);

    // Bottom-right
    canvas.drawLine(rect.bottomRight, Offset(rect.right - cornerLen, rect.bottom), paint);
    canvas.drawLine(rect.bottomRight, Offset(rect.right, rect.bottom - cornerLen), paint);
  }

  void _drawLabel(Canvas canvas, Rect rect, MatchResult match) {
    final percentage = '${(match.similarity * 100).toInt()}%';
    final textStyle = ui.TextStyle(
      color: Colors.white,
      fontSize: 11,
      fontWeight: FontWeight.w700,
    );

    final paragraphBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: TextAlign.center,
      maxLines: 1,
    ))
      ..pushStyle(textStyle)
      ..addText(percentage);

    final paragraph = paragraphBuilder.build()
      ..layout(const ui.ParagraphConstraints(width: 44));

    // Position label above the bounding box
    final labelRect = Rect.fromLTWH(
      rect.right - 48,
      rect.top - 22,
      48,
      18,
    );

    // Background pill for label
    final bgPaint = Paint()
      ..color = _getMatchColor(match)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(9)),
      bgPaint,
    );

    canvas.drawParagraph(paragraph, Offset(labelRect.left + 2, labelRect.top + 2));
  }

  /// Transform bounding box from ML Kit image coordinates to widget coordinates.
  Rect _transformRect(Rect rect, Size canvasSize) {
    final scaleX = canvasSize.width / imageSize.width;
    final scaleY = canvasSize.height / imageSize.height;

    return Rect.fromLTRB(
      rect.left * scaleX,
      rect.top * scaleY,
      rect.right * scaleX,
      rect.bottom * scaleY,
    );
  }

  @override
  bool shouldRepaint(OverlayPainter oldDelegate) {
    return matches != oldDelegate.matches ||
        imageSize != oldDelegate.imageSize;
  }
}
