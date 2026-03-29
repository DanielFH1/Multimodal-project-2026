# Shelfie

[![Shelfie](assets/app_icon.png)](https://play.google.com/store/apps/details?id=com.shelfie.shelfie_app)

> Click the logo!

You can check my [blog](https://danielfh1.github.io/categories/projects) for more information

## Why I Built This

Even when you know a book's call number, you still end up scanning every spine by eye.
I wanted the camera to do that for you — type in a title, point at the shelf, and let the app tell you exactly where it is.

## How It Works

1. Enter the book title on the home screen.
2. Tap **Scan** to open the camera.
3. Pan slowly across the shelf. OCR runs on each frame and extracts any visible text.
4. When extracted text matches the query above a similarity threshold, the app draws a bounding box around the spine and triggers a haptic buzz.

## Tech Stack

| Area | Technology |
|---|---|
| Framework | Flutter (Dart) |
| OCR | Google ML Kit Text Recognition v2 |
| State management | Riverpod (`StateNotifier`) |
| Camera | `camera` package, YUV_420_888 → NV21 conversion |
| Languages | English, Korean, Chinese, Japanese |

## Real-Time OCR Pipeline

Running OCR on every frame kills performance. The fix is straightforward: skip frames, and drop any frame that arrives while the previous one is still being processed.

```dart
static const int _frameSkipInterval = 2;

void _processFrame(CameraImage image) async {
  _frameSkipCounter++;
  if (_frameSkipCounter % _frameSkipInterval != 0) return;
  if (state.isProcessing) return;
  // ...
}
```

### YUV → NV21 Conversion

Android delivers camera frames in `YUV_420_888`. ML Kit wants `NV21`. The conversion merges three separate Y/U/V planes into a single interleaved byte array, with two code paths depending on `pixelStride`:

```dart
if (uvPixelStride == 2) {
  // V plane is already interleaved — copy rows directly
  for (int row = 0; row < uvHeight; row++) {
    final srcOffset = row * vPlane.bytesPerRow;
    nv21.setRange(destIndex, destIndex + uvWidth * 2,
        vPlane.bytes.buffer.asUint8List(...));
    destIndex += uvWidth * 2;
  }
} else {
  // Manually interleave V and U bytes
  for (int row = 0; row < uvHeight; row++) {
    for (int col = 0; col < uvWidth; col++) {
      nv21[destIndex++] = vPlane.bytes[vIndex];
      nv21[destIndex++] = uPlane.bytes[uIndex];
    }
  }
}
```

## Text Matching

OCR output is noisy — lighting, typefaces, and camera angle all introduce errors. Fuzzy matching handles this in three stages:

1. **Exact containment** — if the recognized text directly contains the query, score `0.8–1.0`.
2. **Word-level matching** — for multi-word queries, check whether each word appears individually in the result.
3. **Levenshtein distance** — if neither above rule fires, fall back to edit-distance similarity.

The minimum threshold is `0.55`; anything below that is silently ignored.

## Haptic Feedback

A match triggers a vibration, but vibrating on every frame while the camera is held still would be annoying. The logic is:

```
Match found → already buzzed? → No  → vibrate + set flag
                              → Yes → skip

Match gone for 5 consecutive frames → reset flag
```

Vibration intensity also scales with confidence:

| Similarity | Duration | Amplitude |
|---|---|---|
| ≥ 95% (exact) | 300 ms | max |
| ≥ 75% (strong) | 200 ms | medium |
| < 75% | 100 ms | light |

## Project Structure

```
lib/
├── main.dart
├── app.dart                      # theme, routing
├── models/
│   ├── search_query.dart         # query + mode (library / store)
│   └── match_result.dart         # match result + bounding box
├── features/
│   ├── search/
│   │   └── search_screen.dart
│   ├── scanner/
│   │   ├── scanner_screen.dart
│   │   ├── scanner_provider.dart         # state + frame handling
│   │   ├── text_recognizer_service.dart  # ML Kit wrapper
│   │   ├── text_matcher_service.dart     # fuzzy matching
│   │   └── overlay_painter.dart          # bounding box overlay
│   └── update/
│       └── ...
└── services/
    └── update_service.dart
```

Each feature directory holds its UI, business logic, and service layer side by side — no global `utils/` dumping ground.

## What's Next

It's MVP quality but genuinely useful in a real library. Things I want to add:

- **Multi-query** — search for several books in one scan
- **Search history**
- **Barcode scanning** as a fallback
