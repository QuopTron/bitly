import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/particle_background.dart';
import '../../shared/widgets/app_navigator_observer.dart';
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

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final PageController _pageCtrl;
  late final BackendService _backend;
  late final FeedBloc _feedBloc;
  late final SearchBloc _searchBloc;
  int _tab = 1;
  bool _ready = false;
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

  /// Animation controller for sliding MiniPlayer + Navbar in/out.
  late final AnimationController _chromeAnimCtrl;
  late final Animation<double> _chromeSlideAnim;

  /// Listener that reacts to modal or full-screen player visibility changes.
  void _onChromeVisibilityChanged() {
    if (!mounted) return;
    final observer = sl<AppNavigatorObserver>();
    final isModal = observer.isModalShowing.value;
    final isFullPlayer = observer.topRouteName.value == 'now_playing';
    if (isModal || isFullPlayer) {
      _chromeAnimCtrl.forward();
    } else {
      _chromeAnimCtrl.reverse();
    }
  }

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

    // Chrome animation: slides the miniplayer + navbar down (off-screen) when
    // a modal is showing so the modal properly covers them.
    _chromeAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _chromeSlideAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _chromeAnimCtrl, curve: Curves.easeOutCubic),
    );

    // Listen to modal visibility AND route changes from the navigator observer.
    // Hides MiniPlayer+Navbar when a modal or the full-screen player is open.
    sl<AppNavigatorObserver>().isModalShowing.addListener(_onChromeVisibilityChanged);
    sl<AppNavigatorObserver>().topRouteName.addListener(_onChromeVisibilityChanged);

    _acquireSessions();
    _requestNotificationPermission();

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
      // Bound by the device profile: the feed is long but only the first few
      // tracks are likely to be tapped; pre-firing 10+ stream resolutions
      // would keep the backend bridge busy while the user searches.
      //
      // Also DEFER the pre-warm ~12s: the native bridge serializes every Go
      // RPC on one thread, and right after the feed appears the user may open
      // Search immediately. Four stream resolutions fired at once would hold
      // the bridge for seconds and make that FIRST search look dead (it just
      // queues behind them). By the time the pre-warm starts, the first
      // searches/navigation have already gone through.
      Future<void>.delayed(const Duration(seconds: 12), () {
        if (!mounted) return;
        sl<PlayerCubit>().precacheContext(tracks, limit: 4);
      });
    });

    _downloadSub = _downloadCubit.stream.listen((state) {
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      if (state.backendRestarted && !_restartSnackShown) {
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
      if (state.decryptError != null && !_decryptSnackShown) {
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

  Future<void> _acquireSessions() async {
    _unlockTimer = Timer(const Duration(minutes: 3, seconds: 30), _skipSessions);
    try {
      await VerificationService().provisionSignedSessions();
    } catch (_) {}
    _unlockTimer?.cancel();
    _unlockTimer = null;
    if (!mounted) return;
    _unlock();
  }

  Future<void> _requestNotificationPermission() async {
    try {
      if (!Platform.isAndroid) return;
      final status = await Permission.notification.status;
      if (!status.isGranted && !status.isPermanentlyDenied) {
        await Permission.notification.request();
      }
    } catch (_) {}
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
    _chromeAnimCtrl.dispose();
    sl<AppNavigatorObserver>().isModalShowing.removeListener(_onChromeVisibilityChanged);
    sl<AppNavigatorObserver>().topRouteName.removeListener(_onChromeVisibilityChanged);
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
                // MiniPlayer + Navbar — slide down when modals are showing.
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: AnimatedBuilder(
                    animation: _chromeSlideAnim,
                    builder: (context, child) {
                      // Translate the chrome down by 120% of its height when
                      // the animation is at 1.0 (modal showing).
                      final offset = _chromeSlideAnim.value;
                      return Transform.translate(
                        offset: Offset(0, offset * 120),
                        child: Opacity(
                          opacity: (1.0 - offset).clamp(0.0, 1.0),
                          child: child,
                        ),
                      );
                    },
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
                ),
              ],
            ),
          ),
          // Hard gate: nothing is interactive until all signed sessions are
          // ready.
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
