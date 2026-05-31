import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bitly/services/premium/premium_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bitly/l10n/l10n.dart';
import 'package:bitly/providers/download_queue_provider.dart';
import 'package:bitly/providers/settings_provider.dart';
import 'package:bitly/providers/track_provider.dart';
import 'package:bitly/screens/home_tab.dart';
import 'package:bitly/screens/queue_tab.dart';
import 'package:bitly/services/núcleo/platform_bridge.dart';

import 'package:bitly/services/navegación/share_intent_service.dart';
import 'package:bitly/services/notificaciones/notification_service.dart';
import 'package:bitly/services/actualizaciones/update_checker.dart';
import 'package:bitly/widgets/update_dialog.dart';
import 'package:bitly/widgets/animation_utils.dart';
import 'package:bitly/utils/logger.dart';
import 'package:bitly/widgets/mini_player.dart';

final _log = AppLogger('MainShell');

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late final PageController _pageController;
  late final AnimationController _tabJumpTransitionController;
  bool _hasCheckedUpdate = false;
  StreamSubscription<String>? _shareSubscription;
  DateTime? _lastBackPress;
  // final GlobalKey<NavigatorState> _homeTabNavigatorKey =
  //     ShellNavigationService.homeTabNavigatorKey;
  // final GlobalKey<NavigatorState> _libraryTabNavigatorKey =
  //     ShellNavigationService.libraryTabNavigatorKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    NotificationService().updateStrings(context.l10n);
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _tabJumpTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: 1,
    );
    // ShellNavigationService.syncState(
    //   currentTabIndex: _currentIndex,
    // );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // TODO: Descomentar cuando se configure GitHub Releases para actualizaciones de Bitly
      // _checkForUpdates();
      _setupShareListener();
      _checkSafMigration();
      _checkOnboarding();
    });
  }

  void _checkOnboarding() {
    if (!mounted) return;
    final settings = ref.read(settingsProvider);
    if (settings.isFirstLaunch && settings.username.isEmpty) {
      PremiumService.tryAutoRestore().then((restored) {
        if (!mounted) return;
        if (restored) {
          PremiumService.getSavedUsername().then((name) {
            if (name != null && name.isNotEmpty) {
              ref.read(settingsProvider.notifier).setUsername(name);
            }
          });
          return;
        }
        context.go('/setup');
      });
      return;
    }
    if (!settings.hasCompletedTutorial) {
      context.go('/tutorial');
    }
  }

  void _setupShareListener() {
    final pendingUrl = ShareIntentService().consumePendingUrl();
    if (pendingUrl != null) {
      _log.d('Processing pending shared URL: $pendingUrl');
      _handleSharedUrl(pendingUrl);
    }

    _shareSubscription = ShareIntentService().sharedUrlStream.listen(
      (url) {
        _log.d('Received shared URL from stream: $url');
        _handleSharedUrl(url);
      },
      onError: (Object error) {
        _log.e('Share stream error: $error');
      },
      cancelOnError: false,
    );
  }

  Future<void> _handleSharedUrl(String url) async {
    if (!mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);
    // _homeTabNavigatorKey.currentState?.popUntil((route) => route.isFirst);

    if (_currentIndex != 0) {
      _onNavTap(0);
    }
    ref.read(settingsProvider.notifier).setHasSearchedBefore();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.loadingSharedLink)),
      );
    }
    await ref.read(trackProvider.notifier).fetchFromUrl(url);
    final trackState = ref.read(trackProvider);
    if (trackState.error != null && mounted) {
      final l10n = context.l10n;
      final errorMsg = trackState.error!;
      final isRateLimit =
          errorMsg.contains('429') ||
          errorMsg.toLowerCase().contains('rate limit') ||
          errorMsg.toLowerCase().contains('too many requests');
      final displayMessage = errorMsg == 'url_not_recognized'
          ? l10n.errorUrlNotRecognizedMessage
          : isRateLimit
          ? l10n.errorRateLimitedMessage
          : l10n.errorUrlFetchFailed;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(displayMessage)),
      );
    }
  }

  // TODO: Descomentar cuando se configure GitHub Releases para actualizaciones de Bitly
  // Future<void> _checkForUpdates() async {
  //   if (_hasCheckedUpdate) return;
  //   _hasCheckedUpdate = true;
  //
  //   final settings = ref.read(settingsProvider);
  //   if (!settings.checkForUpdates) return;
  //
  //   final updateInfo = await UpdateChecker.checkForUpdate(
  //     channel: settings.updateChannel,
  //   );
  //   if (updateInfo != null && mounted) {
  //     showUpdateDialog(
  //       context,
  //       updateInfo: updateInfo,
  //       onDisableUpdates: () {
  //         ref.read(settingsProvider.notifier).setCheckForUpdates(false);
  //       },
  //     );
  //   }
  // }

  static const _safMigrationShownKey = 'saf_migration_prompt_shown';

  Future<void> _checkSafMigration() async {
    if (!Platform.isAndroid) return;

    final settings = ref.read(settingsProvider);
    if (settings.storageMode == 'saf') return;
    if (settings.downloadDirectory.isEmpty) return;

    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    if (androidInfo.version.sdkInt < 29) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_safMigrationShownKey) == true) return;
    await prefs.setBool(_safMigrationShownKey, true);

    if (!mounted) return;

    final colorScheme = Theme.of(context).colorScheme;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.folder_special_outlined,
          size: 32,
          color: colorScheme.primary,
        ),
        title: Text(context.l10n.safMigrationTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.safMigrationMessage1),
            const SizedBox(height: 12),
            Text(context.l10n.safMigrationMessage2),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.updateLater),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await PlatformBridge.pickSafTree();
              if (result != null) {
                final treeUri = result['tree_uri'] as String? ?? '';
                final displayName = result['display_name'] as String? ?? '';
                if (treeUri.isNotEmpty) {
                  ref.read(settingsProvider.notifier).setDownloadTreeUri(
                    treeUri,
                    displayName: displayName.isNotEmpty ? displayName : treeUri,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.l10n.safMigrationSuccess),
                      ),
                    );
                  }
                }
              }
            },
            child: Text(context.l10n.setupSelectFolder),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _shareSubscription?.cancel();
    _pageController.dispose();
    _tabJumpTransitionController.dispose();
    super.dispose();
  }

  void _resetHomeToMain() {
    FocusManager.instance.primaryFocus?.unfocus();
    ref.read(trackProvider.notifier).clear();
  }

  void _onNavTap(int index) {
    if (index == 0 && _currentIndex == 0) {
      _resetHomeToMain();
      return;
    }

    if (_currentIndex != index) {
      final previousIndex = _currentIndex;
      final isNonAdjacentJump = (previousIndex - index).abs() > 1;
      HapticFeedback.selectionClick();
      setState(() => _currentIndex = index);
      // ShellNavigationService.syncState(
      //   currentTabIndex: _currentIndex,
      // );
      FocusManager.instance.primaryFocus?.unfocus();
      if (isNonAdjacentJump) {
        _pageController.jumpToPage(index);
        _tabJumpTransitionController.forward(from: 0);
      } else {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  void _onPageChanged(int index) {
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
      // ShellNavigationService.syncState(
      //   currentTabIndex: _currentIndex,
      // );
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  Future<void> _handleBackPress() async {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final handledByRootNavigator = await rootNavigator.maybePop();
    if (handledByRootNavigator) {
      _log.i('Back: step 1 - root navigator handled back');
      _lastBackPress = null;
      return;
    }

    // Tab-level navigation removed (no nested navigators)
    if (false) {
      _lastBackPress = null;
      return;
    }

    if (!mounted) return;

    final trackState = ref.read(trackProvider);

    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    _log.d(
      'Back: state check - tab=$_currentIndex, '
      'isShowingRecentAccess=${trackState.isShowingRecentAccess}, '
      'hasSearchText=${trackState.hasSearchText}, '
      'hasContent=${trackState.hasContent}, '
      'isLoading=${trackState.isLoading}, '
      'isKeyboardVisible=$isKeyboardVisible',
    );

    if (_currentIndex == 0 &&
        trackState.isShowingRecentAccess &&
        !trackState.isLoading &&
        (trackState.hasSearchText || trackState.hasContent)) {
      _log.i(
        'Back: step 3a - dismiss recent access + clear search/content '
        '(hasSearchText=${trackState.hasSearchText}, hasContent=${trackState.hasContent})',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      ref.read(trackProvider.notifier).clear();
      _lastBackPress = null;
      return;
    }

    if (_currentIndex == 0 && trackState.isShowingRecentAccess) {
      _log.i('Back: step 3b - dismiss recent access only');
      ref.read(trackProvider.notifier).setShowingRecentAccess(false);
      FocusManager.instance.primaryFocus?.unfocus();
      _lastBackPress = null;
      return;
    }

    if (_currentIndex == 0 &&
        !trackState.isLoading &&
        (trackState.hasSearchText || trackState.hasContent)) {
      _log.i(
        'Back: step 4 - clear search/content '
        '(hasSearchText=${trackState.hasSearchText}, hasContent=${trackState.hasContent})',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      ref.read(trackProvider.notifier).clear();
      _lastBackPress = null;
      return;
    }

    if (_currentIndex == 0 && isKeyboardVisible) {
      _log.i('Back: step 5 - dismiss keyboard');
      FocusManager.instance.primaryFocus?.unfocus();
      _lastBackPress = null;
      return;
    }

    if (_currentIndex != 0) {
      _log.i('Back: step 6 - switch to home tab from tab=$_currentIndex');
      _onNavTap(0);
      _lastBackPress = null;
      return;
    }

    if (trackState.isLoading) {
      _log.i('Back: blocked - loading in progress');
      return;
    }

    final now = DateTime.now();
    if (_lastBackPress != null &&
        now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
      _log.i('Back: step 8 - double-tap exit');
      unawaited(PlatformBridge.exitApp());
    } else {
      _log.i('Back: step 7 - first tap, showing exit snackbar');
      _lastBackPress = now;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.pressBackAgainToExit),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // NavigatorState? _navigatorForTab(int index) {
  //   if (index == 0) return _homeTabNavigatorKey.currentState;
  //   if (index == 1) return _libraryTabNavigatorKey.currentState;
  //   return null;
  // }

  @override
  Widget build(BuildContext context) {
    final queueState = ref.watch(
      downloadQueueProvider.select((s) => s.queuedCount),
    );

    final tabs = <Widget>[
      _TabNavigator(
        key: const ValueKey('tab-home'),
        // navigatorKey: _homeTabNavigatorKey,
        child: const HomeTab(),
      ),
      _TabNavigator(
        key: const ValueKey('tab-library'),
        // navigatorKey: _libraryTabNavigatorKey,
        child: const QueueTab(),
      ),
    ];

    final l10n = context.l10n;

    final destinations = <NavigationDestination>[
      NavigationDestination(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const BouncingIcon(child: Icon(Icons.home)),
        label: l10n.navHome,
      ),
      NavigationDestination(
        icon: AnimatedBadge(
          count: queueState,
          child: Badge(
            isLabelVisible: queueState > 0,
            label: Text('$queueState'),
            child: const Icon(Icons.library_music_outlined),
          ),
        ),
        selectedIcon: SlidingIcon(
          child: AnimatedBadge(
            count: queueState,
            child: Badge(
              isLabelVisible: queueState > 0,
              label: Text('$queueState'),
              child: const Icon(Icons.library_music),
            ),
          ),
        ),
        label: l10n.navLibrary,
      ),
    ];

    final maxIndex = tabs.length - 1;
    if (_currentIndex > maxIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _currentIndex = maxIndex);
          _pageController.jumpToPage(maxIndex);
        }
      });
    }

    return BackButtonListener(
      onBackButtonPressed: () async {
        await _handleBackPress();
        return true;
      },
      child: Scaffold(
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: AnimatedBuilder(
                    animation: _tabJumpTransitionController,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: tabs.length,
                      onPageChanged: _onPageChanged,
                      physics: const NeverScrollableScrollPhysics(),
                      itemBuilder: (context, index) => _KeepAliveTabPage(
                        key: ValueKey('page-$index'),
                        child: tabs[index],
                      ),
                    ),
                    builder: (context, child) {
                      final t = Curves.easeOutCubic.transform(
                        _tabJumpTransitionController.value,
                      );
                      return Opacity(
                        opacity: t,
                        child: Transform.scale(
                          scale: 0.985 + (0.015 * t),
                          child: child,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            // MiniPlayer flotante sobre el contenido, arriba del navbar
            Positioned(
              left: 0,
              right: 0,
              bottom: 76, // Altura del navbar (72) + pequeño gap (4)
              child: const MiniPlayer(),
            ),
          ],
        ),
        bottomNavigationBar: _buildGlassNavigationBar(context, tabs, queueState),
      ),
    );
  }

  /// Build glassmorphism navigation bar
  Widget _buildGlassNavigationBar(BuildContext context, List<Widget> tabs, int queueState) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final maxIndex = tabs.length - 1;

    final destinations = <NavigationDestination>[
      NavigationDestination(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const BouncingIcon(child: Icon(Icons.home)),
        label: l10n.navHome,
      ),
      NavigationDestination(
        icon: AnimatedBadge(
          count: queueState,
          child: Badge(
            isLabelVisible: queueState > 0,
            label: Text('$queueState'),
            child: const Icon(Icons.library_music_outlined),
          ),
        ),
        selectedIcon: SlidingIcon(
          child: AnimatedBadge(
            count: queueState,
            child: Badge(
              isLabelVisible: queueState > 0,
              label: Text('$queueState'),
              child: const Icon(Icons.library_music),
            ),
          ),
        ),
        label: l10n.navLibrary,
      ),
    ];

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                (isDark ? Colors.white : Colors.black).withOpacity(0.08),
                (isDark ? Colors.white : Colors.black).withOpacity(0.03),
              ],
            ),
            border: Border(
              top: BorderSide(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.2),
                width: 1.5,
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex.clamp(0, maxIndex),
            onDestinationSelected: _onNavTap,
            animationDuration: const Duration(milliseconds: 500),
            backgroundColor: Colors.transparent,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            indicatorColor: isDark 
                ? const Color(0xFF00F5B0).withOpacity(0.15)
                : Theme.of(context).colorScheme.secondaryContainer,
            destinations: destinations,
            height: 72,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          ),
        ),
      ),
    );
  }
}

class _TabNavigator extends StatelessWidget {
  final Widget child;

  const _TabNavigator({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class _KeepAliveTabPage extends StatefulWidget {
  final Widget child;

  const _KeepAliveTabPage({super.key, required this.child});

  @override
  State<_KeepAliveTabPage> createState() => _KeepAliveTabPageState();
}

class _KeepAliveTabPageState extends State<_KeepAliveTabPage>
    with AutomaticKeepAliveClientMixin<_KeepAliveTabPage> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class BouncingIcon extends StatefulWidget {
  final Widget child;
  const BouncingIcon({super.key, required this.child});

  @override
  State<BouncingIcon> createState() => _BouncingIconState();
}

class _BouncingIconState extends State<BouncingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.1,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scaleAnimation, child: widget.child);
  }
}

class SlidingIcon extends StatefulWidget {
  final Widget child;
  const SlidingIcon({super.key, required this.child});

  @override
  State<SlidingIcon> createState() => _SlidingIconState();
}

class _SlidingIconState extends State<SlidingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(position: _offsetAnimation, child: widget.child),
    );
  }
}