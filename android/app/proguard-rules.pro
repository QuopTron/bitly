# Keep webview_flutter for release builds
-keep class io.flutter.plugins.webviewflutter.** { *; }
-dontwarn io.flutter.plugins.webviewflutter.**

# Keep media_kit
-keep class com.media_kit.** { *; }

# Keep Go backend JNI bridge
-keep class gobackend.** { *; }

# Keep FFmpeg kit
-keep class com.arthenica.ffmpegkit.** { *; }

# Flutter general
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**
-keep class io.flutter.plugins.** { *; }
