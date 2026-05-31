# Project Knowledge — Bitly (bitly)

A Flutter app for downloading Spotify tracks in FLAC quality from Tidal, Qobuz & Deezer. Uses a Go backend for metadata, downloads, and extension runtime.

## What This Is
- **Frontend:** Flutter (Dart) — cross-platform UI with Riverpod state management.
- **Backend:** Go (`go_backend_bitly/`) — compiled to `Bitly-backend.exe` for desktop and an `.aar` for Android.
- **Android Bridge:** Kotlin (`android/app/src/main/kotlin/...`) — handles platform-specific calls (e.g., YouTube search via yt-dlp).
- **Communication:** Desktop runs the Go binary; Android uses MethodChannel + gomobile bindings.

## Key Directories
| Directory | Purpose |
|-----------|---------|
| `lib/` | Flutter Dart source (screens, providers, services, widgets, models, theme) |
| `go_backend_bitly/` | Go backend (HTTP API, downloads, metadata, extensions, DB, FFmpeg wrappers) |
| `android/` | Android-specific config and Kotlin bridge code |
| `windows/` | Windows runner and CMake config |
| `assets/` | Fonts, images, localization ARB files |

## Architecture Notes
- **State Management:** `flutter_riverpod` with `StateNotifier` pattern. Providers live in `lib/providers/`.
- **Navigation:** `go_router` with a shell (`MainShell`) and tab-based routing.
- **Platform Bridge:** `lib/services/núcleo/platform_bridge.dart` abstracts Android MethodChannel and desktop process calls.
- **Database:** Go backend uses `ncruces/go-sqlite3` (WASM on mobile, native on desktop). Flutter does **not** talk to SQLite directly.
- **Extensions:** The Go backend manages a JS extension runtime (gomobile on Android, direct on desktop).
- **Audio/Video:** `media_kit` for in-app playback; `ffmpeg_kit_flutter_new_full` for audio conversion.
- **Dynamic Theming:** `dynamic_color` wrapper supports Material You / Expressive 3 on Android 12+.

## Commands

### Flutter
```bash
# Install dependencies
flutter pub get

# Run (debug)
flutter run

# Build APK
flutter build apk --debug        # or --release

# Build Windows
flutter build windows

# Analyze / lint
flutter analyze

# Generate code (JSON serializers, Riverpod, icons)
flutter pub run build_runner build --delete-conflicting-outputs
flutter pub run flutter_launcher_icons:main
```

### Go Backend
```bash
cd go_backend_bitly

# Build Windows backend
go build -o ../Bitly-backend.exe .

# Build Android AAR (requires gomobile + Android NDK)
gomobile bind -target=android/arm,android/arm64 -o ../Bitly.aar .

# Run tests
go test ./...
```

## Conventions
- **Language:** Dart code is in English; UI strings are localized via `l10n/` (English + Spanish).
- **Linting:** `package:flutter_lints/flutter.yaml` is included in `analysis_options.yaml`. Keep warnings clean.
- **Imports:** Use `package:bitly/...` for internal imports.
- **Models:** JSON-serializable models use `json_serializable` + `json_annotation` (e.g., `track.dart` + `track.g.dart`).
- **Providers:** Keep providers in `lib/providers/`, one per domain (settings, downloads, audio player, etc.).
- **Services:** Platform-specific or heavy logic belongs in `lib/services/`, not directly in UI code.
- **Theme:** All theming goes through `lib/theme/` — do not hardcode colors in widgets.

## Gotchas
- **Go Backend on Desktop:** `main.dart` calls `PlatformBridge.initDesktopBackend()` on non-mobile platforms. The executable must be present next to the app or in PATH.
- **Android Go Initialization:** `main.dart` invokes `initGoBackend` via MethodChannel, passing `db_path` and `ytdlp_path`. If this fails, the app continues but DB-dependent features break.
- **Image Cache:** The app configures `PaintingBinding.instance.imageCache` bounds at startup based on device RAM to avoid OOM on low-end Android devices.
- **Overscroll:** Disabled on low-RAM / 32-bit Android devices via `disableOverscrollEffects`.
- **Extension Bootstrap:** The Go backend auto-downloads and enables "essential" extensions on first run. Do not duplicate this logic in Flutter.
- **Local Library Auto-Scan:** Triggered on app resume based on settings (`on_open`, `daily`, `weekly`). Uses `SharedPreferences` to throttle scans.
- **yt-dlp:** Required on both desktop and Android for YouTube fallback downloads. On Android it must be available in the app documents directory or via Termux.
- **FFmpeg:** The `ffmpeg_kit_flutter_new_full` package is large; builds may take a while.
