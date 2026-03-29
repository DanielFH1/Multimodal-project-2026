import 'dart:async';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';

import '../../models/match_result.dart';
import '../../models/search_query.dart';
import 'text_matcher_service.dart';
import 'text_recognizer_service.dart';

// ─── State ─────────────────────────────────────────────────

class ScannerState {
  final bool isInitialized;
  final bool isScanning;
  final bool isProcessing;
  final List<MatchResult> currentMatches;
  final String? errorMessage;
  final int framesProcessed;
  final double? lastProcessingTimeMs;
  final Size? imageSize;
  final String? debugMessage;
  final String? lastRecognizedText;

  const ScannerState({
    this.isInitialized = false,
    this.isScanning = false,
    this.isProcessing = false,
    this.currentMatches = const [],
    this.errorMessage,
    this.framesProcessed = 0,
    this.lastProcessingTimeMs,
    this.imageSize,
    this.debugMessage,
    this.lastRecognizedText,
  });

  ScannerState copyWith({
    bool? isInitialized,
    bool? isScanning,
    bool? isProcessing,
    List<MatchResult>? currentMatches,
    String? errorMessage,
    int? framesProcessed,
    double? lastProcessingTimeMs,
    Size? imageSize,
    String? debugMessage,
    String? lastRecognizedText,
  }) {
    return ScannerState(
      isInitialized: isInitialized ?? this.isInitialized,
      isScanning: isScanning ?? this.isScanning,
      isProcessing: isProcessing ?? this.isProcessing,
      currentMatches: currentMatches ?? this.currentMatches,
      errorMessage: errorMessage ?? this.errorMessage,
      framesProcessed: framesProcessed ?? this.framesProcessed,
      lastProcessingTimeMs: lastProcessingTimeMs ?? this.lastProcessingTimeMs,
      imageSize: imageSize ?? this.imageSize,
      debugMessage: debugMessage ?? this.debugMessage,
      lastRecognizedText: lastRecognizedText ?? this.lastRecognizedText,
    );
  }
}

// ─── Notifier ──────────────────────────────────────────────

class ScannerNotifier extends StateNotifier<ScannerState> {
  CameraController? _cameraController;
  final TextRecognizerService _textRecognizer = TextRecognizerService();
  final TextMatcherService _textMatcher = const TextMatcherService();

  SearchQuery? _currentQuery;
  CameraDescription? _camera;
  int _frameSkipCounter = 0;

  /// How many frames to skip between OCR processing.
  static const int _frameSkipInterval = 2;

  /// Vibration state: true = already vibrated for current continuous match.
  /// Resets only when the match disappears for several frames.
  bool _hasVibratedForCurrentMatch = false;

  /// Count of consecutive frames with NO match (used to reset vibration flag).
  int _noMatchFrameCount = 0;

  /// How many consecutive no-match frames before resetting vibration.
  static const int _noMatchResetThreshold = 5;

  ScannerNotifier() : super(const ScannerState());

  CameraController? get cameraController => _cameraController;

  /// Initialize camera and text recognizer.
  Future<void> initialize(OcrLanguage language) async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        state = state.copyWith(errorMessage: 'No cameras available');
        return;
      }

      _camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        _camera!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      _textRecognizer.initialize(language);

      state = state.copyWith(isInitialized: true, errorMessage: null);
      print('[Scanner] Camera initialized: ${_camera!.name}, '
          'sensor=${_camera!.sensorOrientation}°');
    } catch (e) {
      state = state.copyWith(errorMessage: 'Camera init failed: $e');
      print('[Scanner] Init error: $e');
    }
  }

  /// Start scanning for the given search query.
  void startScanning(SearchQuery query) {
    if (!state.isInitialized || _cameraController == null) return;

    _currentQuery = query;
    _frameSkipCounter = 0;
    _hasVibratedForCurrentMatch = false;
    _noMatchFrameCount = 0;
    state = state.copyWith(isScanning: true, currentMatches: []);

    _cameraController!.startImageStream(_processFrame);
    print('[Scanner] Scanning for: "${query.text}"');
  }

  /// Stop scanning.
  Future<void> stopScanning() async {
    if (_cameraController?.value.isStreamingImages ?? false) {
      await _cameraController!.stopImageStream();
    }
    state = state.copyWith(
      isScanning: false,
      isProcessing: false,
      currentMatches: [],
    );
  }

  /// Process each camera frame for OCR.
  void _processFrame(CameraImage image) async {
    _frameSkipCounter++;
    if (_frameSkipCounter % _frameSkipInterval != 0) return;
    if (state.isProcessing || _currentQuery == null) return;

    state = state.copyWith(isProcessing: true);
    final stopwatch = Stopwatch()..start();

    try {
      final recognizedText = await _textRecognizer.processImage(
        image,
        _camera!,
      );

      if (recognizedText == null) {
        _onNoMatch('OCR: conversion failed');
        return;
      }

      if (recognizedText.blocks.isEmpty) {
        _onNoMatch('OCR: no text in frame');
        return;
      }

      // ── Image size for bounding box coordinate transform ──
      // ML Kit returns bounding boxes in the ROTATED coordinate space.
      // Camera sensor is landscape, phone is portrait → rotation is 90° or 270°.
      // So bounding boxes are in (height, width) space, not (width, height).
      final sensorRotation = _camera!.sensorOrientation;
      final Size imgSize;
      if (sensorRotation == 90 || sensorRotation == 270) {
        // Swap: bounding boxes use rotated dimensions
        imgSize = Size(image.height.toDouble(), image.width.toDouble());
      } else {
        imgSize = Size(image.width.toDouble(), image.height.toDouble());
      }

      // ── Match OCR text against query ──
      final matches = <MatchResult>[];

      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final score = _textMatcher.match(
            _currentQuery!.text,
            line.text,
          );

          if (score > 0) {
            matches.add(MatchResult(
              recognizedText: line.text,
              queryText: _currentQuery!.text,
              similarity: score,
              boundingBox: line.boundingBox,
              detectedAt: DateTime.now(),
            ));
          }
        }
      }

      stopwatch.stop();

      // ── Vibration logic: vibrate ONCE per continuous match ──
      if (matches.isNotEmpty) {
        _noMatchFrameCount = 0; // reset no-match counter

        if (!_hasVibratedForCurrentMatch) {
          // First time seeing a match → vibrate!
          _hasVibratedForCurrentMatch = true;
          final bestMatch = matches.reduce(
            (a, b) => a.similarity > b.similarity ? a : b,
          );
          if (bestMatch.isExactMatch) {
            Vibration.vibrate(duration: 300, amplitude: 255);
          } else if (bestMatch.isStrongMatch) {
            Vibration.vibrate(duration: 200, amplitude: 180);
          } else {
            Vibration.vibrate(duration: 100, amplitude: 128);
          }
          print('[Scanner] MATCH! "${matches.first.recognizedText}" '
              '${(matches.first.similarity * 100).toInt()}% — vibrating');
        }
      } else {
        // No match this frame
        _noMatchFrameCount++;
        if (_noMatchFrameCount >= _noMatchResetThreshold) {
          // User moved camera away → allow vibration again next time
          _hasVibratedForCurrentMatch = false;
        }
      }

      // ── Debug text ──
      final allText = recognizedText.blocks.map((b) => b.text).join(' | ');
      final debugText = allText.length > 120
          ? '${allText.substring(0, 120)}...'
          : allText;

      state = state.copyWith(
        isProcessing: false,
        currentMatches: matches,
        framesProcessed: state.framesProcessed + 1,
        lastProcessingTimeMs: stopwatch.elapsedMilliseconds.toDouble(),
        imageSize: imgSize,
        debugMessage: 'OCR OK: ${recognizedText.blocks.length} blocks',
        lastRecognizedText: debugText,
      );
    } catch (e) {
      print('[Scanner] Frame error: $e');
      state = state.copyWith(isProcessing: false);
    }
  }

  /// Helper: update state for a frame with no match.
  void _onNoMatch(String debugMsg) {
    _noMatchFrameCount++;
    if (_noMatchFrameCount >= _noMatchResetThreshold) {
      _hasVibratedForCurrentMatch = false;
    }
    state = state.copyWith(
      isProcessing: false,
      currentMatches: [],
      framesProcessed: state.framesProcessed + 1,
      debugMessage: debugMsg,
    );
  }

  /// Switch OCR language.
  void switchLanguage(OcrLanguage language) {
    _textRecognizer.switchLanguage(language);
  }

  @override
  void dispose() {
    stopScanning();
    _cameraController?.dispose();
    _textRecognizer.dispose();
    super.dispose();
  }
}

// ─── Provider ──────────────────────────────────────────────

final scannerProvider =
    StateNotifierProvider.autoDispose<ScannerNotifier, ScannerState>(
  (ref) => ScannerNotifier(),
);
