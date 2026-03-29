import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Supported OCR languages for text recognition.
enum OcrLanguage {
  latin('English', TextRecognitionScript.latin),
  korean('한국어', TextRecognitionScript.korean),
  chinese('中文', TextRecognitionScript.chinese),
  japanese('日本語', TextRecognitionScript.japanese);

  final String displayName;
  final TextRecognitionScript script;
  const OcrLanguage(this.displayName, this.script);
}

/// Service wrapping Google ML Kit Text Recognition v2.
/// Handles lifecycle of the TextRecognizer and processes camera images.
class TextRecognizerService {
  TextRecognizer? _recognizer;
  OcrLanguage _currentLanguage = OcrLanguage.latin;
  bool _isBusy = false;
  int _convertFailCount = 0;
  int _successCount = 0;

  OcrLanguage get currentLanguage => _currentLanguage;
  bool get isBusy => _isBusy;

  /// Initialize recognizer with the specified language.
  void initialize([OcrLanguage language = OcrLanguage.latin]) {
    _currentLanguage = language;
    _recognizer?.close();
    _convertFailCount = 0;
    _successCount = 0;

    try {
      _recognizer = TextRecognizer(script: language.script);
      print('[OCR] Initialized with language: ${language.displayName}');
    } catch (e) {
      // Fallback to Latin if the requested language model is unavailable
      print('[OCR] Failed to init ${language.displayName}: $e — falling back to Latin');
      _currentLanguage = OcrLanguage.latin;
      _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    }
  }

  /// Switch OCR language at runtime.
  void switchLanguage(OcrLanguage language) {
    if (language == _currentLanguage && _recognizer != null) return;
    initialize(language);
  }

  /// Process a camera image and return recognized text with bounding boxes.
  Future<RecognizedText?> processImage(CameraImage image, CameraDescription camera) async {
    if (_isBusy || _recognizer == null) return null;
    _isBusy = true;

    try {
      final inputImage = _buildInputImage(image, camera);
      if (inputImage == null) {
        _convertFailCount++;
        if (_convertFailCount <= 5 || _convertFailCount % 50 == 0) {
          print('[OCR] Image conversion failed #$_convertFailCount — '
              'format.raw=${image.format.raw}, '
              'planes=${image.planes.length}, '
              'size=${image.width}x${image.height}');
          if (image.planes.isNotEmpty) {
            print('[OCR]   plane0: bytesPerRow=${image.planes[0].bytesPerRow}, '
                'bytes=${image.planes[0].bytes.length}');
            if (image.planes.length > 1) {
              print('[OCR]   plane1: bytesPerRow=${image.planes[1].bytesPerRow}, '
                  'pixelStride=${image.planes[1].bytesPerPixel}');
            }
          }
        }
        return null;
      }

      final recognizedText = await _recognizer!.processImage(inputImage);
      _successCount++;

      if (recognizedText.text.isNotEmpty) {
        final preview = recognizedText.text.length > 100
            ? '${recognizedText.text.substring(0, 100)}...'
            : recognizedText.text;
        print('[OCR] ✅ Recognized ${recognizedText.blocks.length} blocks: "$preview"');
      } else if (_successCount <= 3) {
        print('[OCR] ✅ ML Kit processed OK but found no text in frame');
      }

      return recognizedText;
    } catch (e) {
      print('[OCR] ❌ processImage ERROR: $e');
      return null;
    } finally {
      _isBusy = false;
    }
  }

  /// Build InputImage from CameraImage.
  /// Properly converts YUV_420_888 (CameraX default) to NV21 for ML Kit.
  InputImage? _buildInputImage(CameraImage image, CameraDescription camera) {
    // 1. Determine rotation
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    if (camera.lensDirection == CameraLensDirection.back) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else {
      rotation = InputImageRotationValue.fromRawValue(
        (360 - sensorOrientation) % 360,
      );
    }

    if (rotation == null) {
      print('[OCR] Unknown rotation for sensor=$sensorOrientation');
      return null;
    }

    if (image.planes.isEmpty) {
      print('[OCR] No image planes');
      return null;
    }

    // 2. Convert to NV21 bytes (the format ML Kit handles best)
    final Uint8List nv21Bytes;
    try {
      if (image.planes.length == 1) {
        // Already NV21 (single plane)
        nv21Bytes = image.planes[0].bytes;
      } else if (image.planes.length >= 3) {
        // YUV_420_888 from CameraX → convert to NV21
        nv21Bytes = _yuv420toNv21(image);
      } else {
        print('[OCR] Unexpected plane count: ${image.planes.length}');
        return null;
      }
    } catch (e) {
      print('[OCR] Byte conversion error: $e');
      return null;
    }

    // 3. Build InputImage with NV21 format
    return InputImage.fromBytes(
      bytes: nv21Bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.width, // NV21 bytesPerRow = width
      ),
    );
  }

  /// Convert YUV_420_888 (3-plane) to NV21 (single interleaved plane).
  /// NV21 layout: [Y plane] [V U V U V U ...] (interleaved VU)
  Uint8List _yuv420toNv21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    // NV21 total size = width * height * 3 / 2
    final int nv21Size = width * height + (width * height ~/ 2);
    final nv21 = Uint8List(nv21Size);

    // Copy Y plane row by row (handle potential padding in bytesPerRow)
    int destIndex = 0;
    if (yPlane.bytesPerRow == width) {
      // No padding, fast copy
      nv21.setRange(0, width * height, yPlane.bytes);
      destIndex = width * height;
    } else {
      // Has padding, copy row by row
      for (int row = 0; row < height; row++) {
        final srcOffset = row * yPlane.bytesPerRow;
        nv21.setRange(destIndex, destIndex + width,
            yPlane.bytes.buffer.asUint8List(yPlane.bytes.offsetInBytes + srcOffset, width));
        destIndex += width;
      }
    }

    // Interleave V and U planes for NV21 (VUVU order)
    final int uvHeight = height ~/ 2;
    final int uvWidth = width ~/ 2;
    final int uvPixelStride = uPlane.bytesPerPixel ?? 1;

    if (uvPixelStride == 2) {
      // Pixel stride 2 means UV data is already semi-interleaved.
      // V plane bytes are: V0 U0 V1 U1 ... (or vice versa)
      // We can copy directly from V plane (which contains interleaved VU)
      for (int row = 0; row < uvHeight; row++) {
        final srcOffset = row * vPlane.bytesPerRow;
        final copyLen = uvWidth * 2; // VU pairs
        nv21.setRange(destIndex, destIndex + copyLen,
            vPlane.bytes.buffer.asUint8List(vPlane.bytes.offsetInBytes + srcOffset, copyLen));
        destIndex += copyLen;
      }
    } else {
      // Pixel stride 1 means separate U and V planes, need manual interleave
      for (int row = 0; row < uvHeight; row++) {
        for (int col = 0; col < uvWidth; col++) {
          final vIndex = row * vPlane.bytesPerRow + col;
          final uIndex = row * uPlane.bytesPerRow + col;
          nv21[destIndex++] = vPlane.bytes[vIndex];
          nv21[destIndex++] = uPlane.bytes[uIndex];
        }
      }
    }

    return nv21;
  }

  /// Release resources.
  void dispose() {
    _recognizer?.close();
    _recognizer = null;
  }
}
