import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_kit/media_kit.dart';
import 'package:bitly/app.dart';
import 'package:bitly/providers/download_queue_provider.dart';
import 'package:bitly/providers/extension_provider.dart';
import 'package:bitly/providers/library_collections_provider.dart';
import 'package:bitly/providers/local_library_provider.dart';
import 'package:bitly/providers/settings_provider.dart';
import 'package:bitly/services/notificaciones/notification_service.dart';
import 'package:bitly/services/núcleo/platform_bridge.dart';
import 'package:bitly/services/núcleo/platform_service.dart';
import 'package:bitly/services/núcleo/service_locator.dart';
import 'package:bitly/services/navegación/share_intent_service.dart';
import 'package:bitly/services/biblioteca/portadas/cover_cache_manager.dart';
import 'package:bitly/utils/local_library_scan_prefs.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  if (!Platform.isAndroid && !Platform.isIOS) {
    await PlatformBridge.initDesktopBackend();
  }

  // Initialize Go backend (creates schema and handles all DB access)
  if (Platform.isAndroid || Platform.isIOS) {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final dbPath = '${docsDir.path}/bitly_master.db';
      final ytDlpPath = '${docsDir.path}/yt-dlp';

      debugPrint('[Init] Initializing Go backend...');
      await PlatformBridge.invoke('initGoBackend', {
        'db_path': dbPath,
        'ytdlp_path': ytDlpPath,
      });
      debugPrint('[Init] ✅ Go backend initialized successfully');
    } catch (e) {
      debugPrint('[Init] ❌ Failed to initialize Go backend: $e');
      // Try to continue anyway, some features might still work
    }
  }

  final runtimeProfile = await _resolveRuntimeProfile();
  _configureImageCache(runtimeProfile);

  runApp(
    ProviderScope(
      child: _EagerInitialization(
        child: BitlyApp(
          disableOverscrollEffects: runtimeProfile.disableOverscrollEffects,
        ),
      ),
    ),
  );
}

Future<_RuntimeProfile> _resolveRuntimeProfile() async {
  const defaults = _RuntimeProfile(
    imageCacheMaximumSize: 240,
    imageCacheMaximumSizeBytes: 60 << 20,
    disableOverscrollEffects: false,
  );

  if (!Platform.isAndroid) return defaults;

  try {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final isArm32Only = androidInfo.supported64BitAbis.isEmpty;
    final isLowRamDevice =
        androidInfo.isLowRamDevice || androidInfo.physicalRamSize <= 2500;

    if (!isArm32Only && !isLowRamDevice) {
      return defaults;
    }

    return _RuntimeProfile(
      imageCacheMaximumSize: 120,
      imageCacheMaximumSizeBytes: 24 << 20,
      disableOverscrollEffects: true,
    );
  } catch (e) {
    debugPrint('Failed to resolve runtime profile: $e');
    return defaults;
  }
}

void _configureImageCache(_RuntimeProfile runtimeProfile) {
  final imageCache = PaintingBinding.instance.imageCache;
  // Keep memory cache bounded so cover-heavy pages don't retain too many
  // full-resolution images simultaneously.
  imageCache.maximumSize = runtimeProfile.imageCacheMaximumSize;
  imageCache.maximumSizeBytes = runtimeProfile.imageCacheMaximumSizeBytes;
}

class _RuntimeProfile {
  final int imageCacheMaximumSize;
  final int imageCacheMaximumSizeBytes;
  final bool disableOverscrollEffects;

  const _RuntimeProfile({
    required this.imageCacheMaximumSize,
    required this.imageCacheMaximumSizeBytes,
    required this.disableOverscrollEffects,
  });
}

class _EagerInitialization extends ConsumerStatefulWidget {
  const _EagerInitialization({required this.child});
  final Widget child;

  @override
  ConsumerState<_EagerInitialization> createState() =>
      _EagerInitializationState();
}

class _EagerInitializationState extends ConsumerState<_EagerInitialization>
    with WidgetsBindingObserver {
  ProviderSubscription<bool>? _localLibraryEnabledSub;
  Timer? _downloadHistoryWarmupTimer;
  Timer? _libraryCollectionsWarmupTimer;
  Timer? _localLibraryWarmupTimer;
  bool _localLibraryWarmupScheduled = false;
  bool _autoScanTriggeredOnLaunch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeAppServices();
      _initializeExtensions();
      _initializeDeferredProviders();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _localLibraryEnabledSub?.close();
    _downloadHistoryWarmupTimer?.cancel();
    _libraryCollectionsWarmupTimer?.cancel();
    _localLibraryWarmupTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeAutoScanLocalLibrary();
    }
  }

  void _initializeDeferredProviders() {
    _downloadHistoryWarmupTimer = _scheduleProviderWarmup(
      const Duration(milliseconds: 400),
      () => ref.read(downloadHistoryProvider),
    );
    _libraryCollectionsWarmupTimer = _scheduleProviderWarmup(
      const Duration(milliseconds: 900),
      () => ref.read(libraryCollectionsProvider),
    );

    _maybeScheduleLocalLibraryWarmup(
      ref.read(
        settingsProvider.select((settings) => settings.localLibraryEnabled),
      ),
    );

    _localLibraryEnabledSub = ref.listenManual<bool>(
      settingsProvider.select((settings) => settings.localLibraryEnabled),
      (previous, next) {
        if (next == true) {
          _maybeScheduleLocalLibraryWarmup(true);
        }
      },
    );
  }

  Timer _scheduleProviderWarmup(Duration delay, VoidCallback action) {
    return Timer(delay, () {
      if (!mounted) return;
      action();
    });
  }

  void _maybeScheduleLocalLibraryWarmup(bool enabled) {
    if (!enabled || _localLibraryWarmupScheduled) return;
    _localLibraryWarmupScheduled = true;
    _localLibraryWarmupTimer = _scheduleProviderWarmup(
      const Duration(milliseconds: 1600),
      () {
        ref.read(localLibraryProvider);
        if (!_autoScanTriggeredOnLaunch) {
          _autoScanTriggeredOnLaunch = true;
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _maybeAutoScanLocalLibrary();
          });
        }
      },
    );
  }

  Future<void> _maybeAutoScanLocalLibrary() async {
    if (!mounted) return;

    final settings = ref.read(settingsProvider);
    if (!settings.localLibraryEnabled) return;
    if (settings.localLibraryPath.isEmpty) return;
    if (settings.localLibraryAutoScan == 'off') return;

    final libraryState = ref.read(localLibraryProvider);
    if (libraryState.isScanning) return;

    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final lastScanned = readLocalLibraryLastScannedAt(prefs);

    if (lastScanned != null) {
      final elapsed = now.difference(lastScanned);

      switch (settings.localLibraryAutoScan) {
        case 'on_open':
          if (elapsed.inMinutes < 10) return;
          break;
        case 'daily':
          if (elapsed.inHours < 24) return;
          break;
        case 'weekly':
          if (elapsed.inDays < 7) return;
          break;
        default:
          return;
      }
    }

    final iosBookmark = settings.localLibraryBookmark;
    ref
        .read(localLibraryProvider.notifier)
        .startScan(
          settings.localLibraryPath,
          iosBookmark: iosBookmark.isNotEmpty ? iosBookmark : null,
        );
  }

  Future<void> _initializeAppServices() async {
    try {
      await CoverCacheManager.initialize();
      
      // Initialize Service Locator
      final serviceLocator = ServiceLocator();
      
      // Register services
      serviceLocator.register(NotificationService());
      serviceLocator.register(ShareIntentService());
      serviceLocator.register(PlatformService());
      
      // Initialize all services
      await serviceLocator.initializeAll();
      
      debugPrint('All services initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize app services: $e');
    }
  }

  Future<void> _initializeExtensions() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final extensionsDir = '${appDir.path}/extensions';
      final dataDir = '${appDir.path}/extension_data';
      final tempDir = await getTemporaryDirectory();
      final bootstrapDir = '${tempDir.path}/bootstrap_extensions';

      // Create all necessary directories
      await Directory(extensionsDir).create(recursive: true);
      await Directory(dataDir).create(recursive: true);
      await Directory(bootstrapDir).create(recursive: true);

      // Initialize extension system and let the backend handle bootstrap.
      // The Go backend's BootstrapEssentialExtensions already downloads, installs,
      // and enables all essential extensions automatically.
      await ref
          .read(extensionProvider.notifier)
          .initialize(extensionsDir, dataDir);

      // No need to call ensureDefaultExtensionsInstalled() here anymore.
      // The backend handles everything during initialize().
      debugPrint('Extension system initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize extensions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
