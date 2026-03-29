import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/search_query.dart';
import 'overlay_painter.dart';
import 'scanner_provider.dart';
import 'text_recognizer_service.dart';

/// Full-screen camera scanner with real-time OCR matching.
class ScannerScreen extends ConsumerStatefulWidget {
  final SearchQuery query;
  final OcrLanguage language;

  const ScannerScreen({
    super.key,
    required this.query,
    required this.language,
  });

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scanLineController;
  bool _showDebugInfo = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notifier = ref.read(scannerProvider.notifier);
      await notifier.initialize(widget.language);
      notifier.startScanning(widget.query);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanLineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scannerProvider);
    final notifier = ref.read(scannerProvider.notifier);
    final hasMatch = state.currentMatches.isNotEmpty;
    final hasExactMatch = state.currentMatches.any((m) => m.isExactMatch);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera Preview ──
          if (state.isInitialized && notifier.cameraController != null)
            _buildCameraPreview(notifier.cameraController!, state)
          else if (state.errorMessage != null)
            _buildErrorView(state.errorMessage!)
          else
            _buildLoadingView(),

          // ── Scan frame corners (viewfinder look) ──
          if (state.isInitialized && !hasExactMatch)
            _buildScanFrame(),

          // ── Center status message ──
          if (state.isScanning && !hasMatch)
            _buildSearchingOverlay(),

          // ── Top bar ──
          _buildTopBar(context, state),

          // ── Bottom panel ──
          if (state.isScanning) _buildBottomPanel(state),

          // ── Match found banner ──
          if (hasExactMatch) _buildMatchFoundBanner(),
        ],
      ),
    );
  }

  // ─── Camera Preview ─────────────────────────────────────────

  Widget _buildCameraPreview(CameraController controller, ScannerState state) {
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.previewSize?.height ?? 1,
            height: controller.value.previewSize?.width ?? 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(controller),
                if (state.currentMatches.isNotEmpty && state.imageSize != null)
                  CustomPaint(
                    painter: OverlayPainter(
                      matches: state.currentMatches,
                      imageSize: state.imageSize!,
                      widgetSize: Size(
                        controller.value.previewSize?.height ?? 1,
                        controller.value.previewSize?.width ?? 1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Scan Frame (viewfinder corners + scan line) ──────────

  Widget _buildScanFrame() {
    return Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.35,
        child: AnimatedBuilder(
          animation: _scanLineController,
          builder: (context, child) {
            return CustomPaint(
              painter: _ScanFramePainter(
                progress: _scanLineController.value,
                pulseValue: _pulseController.value,
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── "Searching..." center overlay ────────────────────────

  Widget _buildSearchingOverlay() {
    return Positioned.fill(
      child: Center(
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated radar icon
                Transform.scale(
                  scale: 1.0 + (_pulseController.value * 0.15),
                  child: Icon(
                    Icons.document_scanner_outlined,
                    color: Colors.white.withValues(
                      alpha: 0.5 + (_pulseController.value * 0.3),
                    ),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                // "Searching..."
                Text(
                  'Searching...',
                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: 0.6 + (_pulseController.value * 0.4),
                    ),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                // Instruction
                Text(
                  'Move your camera slowly across the shelf',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ─── Top Bar ──────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context, ScannerState state) {
    final hasMatch = state.currentMatches.isNotEmpty;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildGlassButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),

                // Query chip with status indicator
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: hasMatch
                          ? const Color(0xFF00E676).withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: hasMatch
                            ? const Color(0xFF00E676).withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          hasMatch
                              ? Icons.check_circle_rounded
                              : Icons.search_rounded,
                          color: hasMatch
                              ? const Color(0xFF00E676)
                              : Colors.white.withValues(alpha: 0.7),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.query.text,
                            style: TextStyle(
                              color: hasMatch
                                  ? const Color(0xFF00E676)
                                  : Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (state.isScanning && !hasMatch) ...[
                          const SizedBox(width: 8),
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color.lerp(
                                    const Color(0xFF6C5CE7),
                                    const Color(0xFF00E676),
                                    _pulseController.value,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 12),
                _buildGlassButton(
                  icon: _showDebugInfo
                      ? Icons.bug_report
                      : Icons.bug_report_outlined,
                  onTap: () => setState(() => _showDebugInfo = !_showDebugInfo),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Bottom Panel ─────────────────────────────────────────

  Widget _buildBottomPanel(ScannerState state) {
    final hasMatch = state.currentMatches.isNotEmpty;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.85),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status row
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Row(
                    key: ValueKey(hasMatch),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        hasMatch
                            ? Icons.check_circle_rounded
                            : Icons.radar_rounded,
                        color: hasMatch
                            ? const Color(0xFF00E676)
                            : Colors.white70,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        hasMatch
                            ? '${state.currentMatches.length} match${state.currentMatches.length > 1 ? 'es' : ''} found!'
                            : 'Scanning — move camera slowly',
                        style: TextStyle(
                          color: hasMatch
                              ? const Color(0xFF00E676)
                              : Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Performance indicator
                if (state.lastProcessingTimeMs != null && !_showDebugInfo) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${state.lastProcessingTimeMs!.toInt()}ms · ${state.framesProcessed} frames',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 11,
                    ),
                  ),
                ],

                // Debug info
                if (_showDebugInfo) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _debugRow('Frames', '${state.framesProcessed}'),
                        _debugRow('OCR', '${state.lastProcessingTimeMs?.toStringAsFixed(1) ?? '-'} ms'),
                        _debugRow('Image', '${state.imageSize?.width.toInt() ?? '-'} × ${state.imageSize?.height.toInt() ?? '-'}'),
                        _debugRow('Status', state.debugMessage ?? 'waiting...'),
                        _debugRow('Text', state.lastRecognizedText ?? '(none)'),
                        _debugRow(
                          'Match',
                          state.currentMatches.isEmpty
                              ? '(none)'
                              : state.currentMatches
                                  .map((m) => '"${m.recognizedText}" ${(m.similarity * 100).toInt()}%')
                                  .join(', '),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Match Found Banner ───────────────────────────────────

  Widget _buildMatchFoundBanner() {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.15,
      left: 20,
      right: 20,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00E676), Color(0xFF00C853)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E676).withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.celebration_rounded, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'FOUND IT! 🎉',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Shared Widgets ───────────────────────────────────────

  Widget _buildGlassButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Color(0xFF6C5CE7)),
          SizedBox(height: 16),
          Text(
            'Starting camera...',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          SizedBox(height: 6),
          Text(
            'This may take a moment',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Camera Error',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Go Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _debugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(label,
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Scan Frame Painter ────────────────────────────────────

class _ScanFramePainter extends CustomPainter {
  final double progress;
  final double pulseValue;

  _ScanFramePainter({required this.progress, required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final cornerLen = size.width * 0.08;
    final strokeWidth = 2.5;

    // Corner bracket paint
    final paint = Paint()
      ..color = Color.lerp(
        const Color(0xFF6C5CE7),
        const Color(0xFFA29BFE),
        pulseValue,
      )!
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

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

    // Animated scan line
    final scanY = rect.top + (rect.height * progress);
    final scanPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF6C5CE7).withValues(alpha: 0.6),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(rect.left, scanY - 1, rect.width, 2));

    canvas.drawLine(
      Offset(rect.left + 8, scanY),
      Offset(rect.right - 8, scanY),
      scanPaint..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_ScanFramePainter oldDelegate) =>
      progress != oldDelegate.progress || pulseValue != oldDelegate.pulseValue;
}
