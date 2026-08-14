import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/particle_background.dart';
import '../../../backend/rpc/backend_service.dart';
import '../../../backend/services/like_cubit.dart';
import '../../../backend/services/download_cubit.dart';
import '../../../backend/services/verification_service.dart';
import '../../../backend/services/playlist_cubit.dart';
import '../../../backend/services/queue_cubit.dart';
import '../../../backend/services/player_cubit.dart';
import '../../shared/widgets/mini_player.dart';
import '../../../backend/cache/search_cache.dart';
import '../../../injection.dart';
import '../feed/widgets/feed_page.dart';
import '../feed/bloc/feed_bloc.dart';
import '../feed/bloc/feed_event.dart';
import '../feed/bloc/feed_state.dart';
import '../../shared/models/feed_models.dart';
import '../search/widgets/search_page.dart';
import '../search/bloc/search_bloc.dart';
import '../miespacio/mi_espacio_page.dart';
import 'widgets/floating_navbar.dart';

class _PageAnimatedWrapper extends StatelessWidget {
  final int index;
  final PageController controller;
  final Widget child;

  const _PageAnimatedWrapper({
    required this.index,
    required this.controller,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final page = controller.hasClients
            ? (controller.page ?? index.toDouble())
            : index.toDouble();
        final diff = (page - index).abs();
        final opacity = (1.0 - diff * 0.4).clamp(0.0, 1.0);
        final scale = (1.0 - diff * 0.05).clamp(0.9, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: child,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final PageController _pageCtrl;
  late final BackendService _backend;
  late final FeedBloc _feedBloc;
  late final SearchBloc _searchBloc;
  int _tab = 1;
  // Blocks the whole home UI (feed, search, downloads, playback) until every
  // signed-session source is verified/skipped, so nothing runs before sessions
  // are provisioned.
  bool _ready = false;
  // Global safety net: never let session verification block the app for more
  // than this even if a captcha modal/browser flow drags on or fails silently.
  Timer? _unlockTimer;
  bool _feedRequested = false;

  late final LikeCubit _likeCubit;
  late final DownloadCubit _downloadCubit;
  late final PlaylistCubit _playlistCubit;
  StreamSubscription? _downloadSub;
  bool _restartSnackShown = false;
  bool _decryptSnackShown = false;
  StreamSubscription<FeedState>? _feedSub;
  bool _feedPrecached = false;

  @override
  void initState() {
    super.initState();
    _backend = sl<BackendService>();
    _likeCubit = sl<LikeCubit>()..initialize();
    _downloadCubit = sl<DownloadCubit>()..initialize();
    _playlistCubit = sl<PlaylistCubit>()..initialize();
    _feedBloc = FeedBloc(_backend);
    _searchBloc = SearchBloc(_backend, sl<SearchCache>());
    _pageCtrl = PageController(initialPage: 1);

    // Gate the app behind signed-session verification BEFORE anything can run.
    // A blocking overlay stays up while every source is verified/skipped, and
    // only then the feed (and everything else) is unlocked.
    _acquireSessions();

    // Preload stream URLs for the visible feed context so the first track the
    // user taps plays instantly (see PlayerCubit.precacheContext).
    _feedSub = _feedBloc.stream.listen((state) {
      if (_feedPrecached || state.sections.isEmpty) return;
      final tracks = <FeedItem>[];
      for (final s in state.sections) {
        for (final it in s.items) {
          if (it.type == 'track') tracks.add(it);
        }
      }
      if (tracks.isEmpty) return;
      _feedPrecached = true;
      sl<PlayerCubit>().precacheContext(tracks);
    });

    // Watch for backend restart while downloads were in-progress and for
    // decrypt failures (encrypted/DRM download, no ffmpeg-kit).
    _downloadSub = _downloadCubit.stream.listen((state) {
      final loc = AppLocalizations.of(context);
      if (state.backendRestarted && !_restartSnackShown && mounted) {
        _restartSnackShown = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.setup.downloadInterruptedOne),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: loc.setup.ok,
              onPressed: () {
                _restartSnackShown = false;
                _downloadCubit.acknowledgeRestart();
              },
            ),
          ),
        );
      }
      if (state.decryptError != null && !_decryptSnackShown && mounted) {
        _decryptSnackShown = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.setup.downloadDecryptFailed),
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: loc.setup.ok,
              onPressed: () {
                _decryptSnackShown = false;
                _downloadCubit.acknowledgeDecryptError();
              },
            ),
          ),
        );
      }
    });
  }

  /// Verifies/skips every signed-session source before unlocking the app.
  /// The verification modals are pushed on the root navigator (above this page
  /// and above the overlay), so the user completes each challenge here and the
  /// feed only loads once ALL sources have been provisioned.
  Future<void> _acquireSessions() async {
    // Hard cap so a stuck captcha (e.g. Cloudflare Turnstile failing to render
    // on low-end GPUs) can never leave the app locked behind the overlay.
    _unlockTimer = Timer(const Duration(minutes: 3, seconds: 30), _skipSessions);
    try {
      await VerificationService().provisionSignedSessions();
    } catch (_) {
      // Never trap the UI: if provisioning throws, proceed anyway.
    }
    _unlockTimer?.cancel();
    _unlockTimer = null;
    if (!mounted) return;
    _unlock();
  }

  void _unlock() {
    if (_ready) return;
    if (!mounted) return;
    setState(() => _ready = true);
    if (!_feedRequested) {
      _feedRequested = true;
      _feedBloc.add(const LoadFeed());
    }
  }

  void _skipSessions() {
    _unlockTimer?.cancel();
    _unlockTimer = null;
    VerificationService().skipAll();
    _unlock();
  }

  @override
  void dispose() {
    _unlockTimer?.cancel();
    _downloadSub?.cancel();
    _feedSub?.cancel();
    _pageCtrl.dispose();
    _feedBloc.close();
    _searchBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glowColor = isDark ? AppColors.greenBright : AppColors.greenMedium;
    final queueCubit = sl<QueueCubit>();
    final playerCubit = sl<PlayerCubit>();

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: Stack(
        children: [
          ParticleBackground(glowColor: glowColor, particleColor: glowColor, particleCount: 6),
          SafeArea(
            child: Stack(
              children: [
                BlocProvider.value(value: queueCubit,
                  child: BlocProvider.value(value: playerCubit,
                    child: PageView(
                      controller: _pageCtrl,
                      onPageChanged: (i) => setState(() => _tab = i),
                      children: [
                        _PageAnimatedWrapper(index: 0, controller: _pageCtrl,
                          child: BlocProvider.value(value: _searchBloc,
                            child: BlocProvider.value(value: _likeCubit,
                              child: BlocProvider.value(value: _downloadCubit, child: const SearchPage())))),
                        _PageAnimatedWrapper(index: 1, controller: _pageCtrl,
                          child: BlocProvider.value(value: _feedBloc,
                            child: BlocProvider.value(value: _likeCubit,
                              child: BlocProvider.value(value: _downloadCubit, child: const FeedPage())))),
                        _PageAnimatedWrapper(index: 2, controller: _pageCtrl,
                          child: BlocProvider.value(value: _likeCubit,
                            child: BlocProvider.value(value: _downloadCubit,
                              child: BlocProvider.value(value: _playlistCubit, child: const MiEspacioPage())))),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BlocProvider.value(value: queueCubit,
                        child: BlocProvider.value(value: playerCubit,
                          child: BlocProvider.value(value: _likeCubit,
                            child: const MiniPlayer(),
                          ),
                        ),
                      ),
                      FloatingNavbar(isDark: isDark, currentIndex: _tab, onTap: _onNavTap),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Hard gate: nothing is interactive until all signed sessions are
          // ready. The verification modal opens above this overlay on the root
          // navigator.
          if (!_ready)
            Positioned.fill(
              child: AbsorbPointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.82),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 20),
                        const Text(
                          'Verificando sesiones firmadas…',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Si el captcha no aparece, podés omitirlo y verificar después.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _skipSessions,
                          icon: const Icon(Icons.skip_next, size: 20),
                          label: const Text('Omitir verificación'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.white12,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onNavTap(int i) {
    _pageCtrl.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
  }
}

