# ML Kit uses reflection
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Keep vibration plugin
-keep class com.benjaminabel.vibration.** { *; }

# CameraX
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**
