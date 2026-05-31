import 'dart:io';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/constants/app_info.dart';
import 'package:bitly/l10n/l10n.dart';
import 'package:bitly/providers/playback_queue_provider.dart';
import 'package:bitly/providers/settings_provider.dart';
import 'package:bitly/screens/settings/about_page.dart';
import 'package:bitly/screens/settings/appearance_settings_page.dart';
import 'package:bitly/screens/settings/cache_management_page.dart';
import 'package:bitly/screens/settings/download_settings_page.dart';
import 'package:bitly/screens/settings/files_settings_page.dart';
import 'package:bitly/screens/settings/log_screen.dart';
import 'package:bitly/screens/settings/lyrics_settings_page.dart';
import 'package:bitly/screens/settings/metadata_settings_page.dart';
import 'package:bitly/services/biblioteca/portadas/cover_cache_manager.dart';
import 'package:bitly/theme/app_theme.dart';
import 'package:bitly/widgets/animation_utils.dart';
import 'package:bitly/widgets/glass_container.dart';
import 'package:bitly/widgets/settings_group.dart';
import 'package:bitly/widgets/stats_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

void showSettingsModal(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    constraints: BoxConstraints(
      maxWidth: MediaQuery.of(context).size.width * 0.95,
      maxHeight: MediaQuery.of(context).size.height * 0.9,
    ),
    builder: (_) => const _SettingsFuturisticModal(),
  );
}

class _SettingsFuturisticModal extends ConsumerWidget {
  const _SettingsFuturisticModal();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentCover = ref.watch(
      playbackQueueProvider.select(
        (q) => q.currentIndex >= 0 && q.currentIndex < q.items.length
            ? q.items[q.currentIndex].track.coverUrl
            : null,
      ),
    );

    return _SettingsGlassContent(coverUrl: currentCover, colorScheme: colorScheme);
  }
}

class _SettingsGlassContent extends StatelessWidget {
  final String? coverUrl;
  final ColorScheme colorScheme;

  const _SettingsGlassContent({required this.coverUrl, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: AppTheme.modalBlurSigma,
            sigmaY: AppTheme.modalBlurSigma,
          ),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              gradient: isDark ? AppTheme.modalGradientDark : AppTheme.modalGradientLight,
              border: Border.all(
                color: isDark ? AppTheme.modalBorderDark : AppTheme.modalBorderLight,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: isDark ? AppTheme.primaryDark.withOpacity(0.3) : AppTheme.primaryLight.withOpacity(0.3),
                  blurRadius: 40,
                  spreadRadius: 4,
                  offset: const Offset(0, 20),
                ),
                // Inner glow for futuristic effect
                BoxShadow(
                  color: isDark ? AppTheme.primaryDark.withOpacity(0.08) : AppTheme.primaryLight.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 0),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                // Top drag handle
                Container(
                  margin: const EdgeInsets.only(top: 16, bottom: 8),
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
                        isDark ? AppTheme.glowDark : AppTheme.glowLight,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? AppTheme.primaryDark.withOpacity(0.4) : AppTheme.primaryLight.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text(
                    context.l10n.settingsTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                      fontSize: 24,
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(
                          color: isDark ? AppTheme.primaryDark.withOpacity(0.3) : AppTheme.primaryLight.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
                // Content
                Expanded(
                  child: Navigator(
                    onGenerateRoute: (_) => MaterialPageRoute<void>(
                      builder: (_) => const _SettingsMenu(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsMenu extends StatelessWidget {
  const _SettingsMenu();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _ProfileCardModal()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Text(
                l10n.settingsTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  fontSize: 22,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: NeonCard(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              padding: const EdgeInsets.all(12),
              child: SettingsGroup(
                margin: EdgeInsets.zero,
                children: [
                  SettingsItem(
                    icon: Icons.palette_outlined,
                    title: l10n.settingsAppearance,
                    subtitle: l10n.settingsAppearanceSubtitle,
                    onTap: () => _push(context, const AppearanceSettingsPage()),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: NeonCard(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              padding: const EdgeInsets.all(12),
              child: SettingsGroup(
                margin: EdgeInsets.zero,
                children: [
                  SettingsItem(
                    icon: Icons.download_outlined,
                    title: l10n.settingsDownload,
                    subtitle: l10n.settingsDownloadSubtitle,
                    onTap: () => _push(context, const DownloadSettingsPage()),
                  ),
                  SettingsItem(
                    icon: Icons.folder_outlined,
                    title: l10n.settingsFiles,
                    subtitle: l10n.settingsFilesSubtitle,
                    onTap: () => _push(context, const FilesSettingsPage()),
                  ),
                  SettingsItem(
                    icon: Icons.sell_outlined,
                    title: l10n.settingsMetadata,
                    subtitle: l10n.settingsMetadataSubtitle,
                    onTap: () => _push(context, const MetadataSettingsPage()),
                  ),
                  SettingsItem(
                    icon: Icons.lyrics_outlined,
                    title: l10n.settingsLyrics,
                    subtitle: l10n.settingsLyricsSubtitle,
                    onTap: () => _push(context, const LyricsSettingsPage()),
                    showDivider: false,
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: NeonCard(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              padding: const EdgeInsets.all(12),
              child: SettingsGroup(
                margin: EdgeInsets.zero,
                children: [
                  SettingsItem(
                    icon: Icons.storage_outlined,
                    title: l10n.settingsCache,
                    subtitle: l10n.settingsCacheSubtitle,
                    onTap: () => _push(context, const CacheManagementPage()),
                  ),
                  SettingsItem(
                    icon: Icons.article_outlined,
                    title: l10n.logTitle,
                    subtitle: l10n.settingsLogsSubtitle,
                    onTap: () => _push(context, const LogScreen()),
                  ),
                  SettingsItem(
                    icon: Icons.info_outline,
                    title: l10n.settingsAbout,
                    subtitle: '${l10n.aboutVersion} ${AppInfo.displayVersion}',
                    onTap: () => _push(context, const AboutPage()),
                    showDivider: false,
                  ),
                ],
              ),
            ),
          ),
          const SliverFillRemaining(hasScrollBody: false, child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget page) {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).push(slidePageRoute<void>(page: page));
  }
}

class _ProfileCardModal extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final username = settings.username;
    final isPremium = settings.isPremium;
    final premiumUntil = settings.premiumUntil;
    final trialActive = premiumUntil > 0 && isPremium;
    final trialUsed = premiumUntil > 0 && !isPremium;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: NeonCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(16),
        glowColor: isPremium ? Colors.amber : null,
        onTap: () => _push(context, const _ProfilePage()),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isPremium
                      ? [Colors.amber[700]!, Colors.amber[900]!]
                      : [
                          isDark ? colorScheme.primaryContainer : AppTheme.primaryLight,
                          isDark ? colorScheme.secondaryContainer : AppTheme.primaryHoverLight,
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: isPremium
                        ? Colors.amber.withOpacity(0.4)
                        : (isDark ? AppTheme.primaryDark.withOpacity(0.3) : AppTheme.primaryLight.withOpacity(0.3)),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: colorScheme.surface.withValues(alpha: 0.3),
                child: Icon(
                  Icons.person,
                  size: 28,
                  color: isPremium
                      ? Colors.white
                      : (isDark ? colorScheme.onPrimaryContainer : colorScheme.onPrimary),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username.isNotEmpty ? username : 'Sin nombre',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isPremium
                          ? Colors.white
                          : (isDark ? colorScheme.onPrimaryContainer : colorScheme.onPrimary),
                      shadows: [
                        Shadow(
                          color: (isDark ? AppTheme.primaryDark : AppTheme.primaryLight).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (trialActive)
                    _RemainingTimeModal(premiumUntil: premiumUntil)
                  else if (isPremium)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.workspace_premium,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Premium',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  else if (trialUsed)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gratis',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: (isDark ? colorScheme.onPrimaryContainer : colorScheme.onPrimary)
                                .withValues(alpha: 0.7),
                          ),
                        ),
                        Text(
                          'Prueba gratis usada',
                          style: TextStyle(
                            fontSize: 10,
                            color: (isDark ? colorScheme.onPrimaryContainer : colorScheme.onPrimary)
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gratis',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: (isDark ? colorScheme.onPrimaryContainer : colorScheme.onPrimary)
                                .withValues(alpha: 0.7),
                          ),
                        ),
                        Text(
                          'Sin prueba gratis',
                          style: TextStyle(
                            fontSize: 10,
                            color: (isDark ? colorScheme.onPrimaryContainer : colorScheme.onPrimary)
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isPremium
                  ? Colors.white
                  : (isDark ? colorScheme.onPrimaryContainer : colorScheme.onPrimary),
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget page) {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).push(slidePageRoute<void>(page: page));
  }
}

class _ProfilePage extends ConsumerWidget {
  const _ProfilePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final username = settings.username;
    final isPremium = settings.isPremium;
    final premiumUntil = settings.premiumUntil;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgPrimaryDark : AppTheme.bgPrimaryLight,
      appBar: AppBar(
        title: Text(
          'Mi Perfil',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: isDark ? AppTheme.primaryDark.withOpacity(0.3) : AppTheme.primaryLight.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        backgroundColor: isDark ? AppTheme.surfaceDark.withOpacity(0.8) : AppTheme.surfaceLight.withOpacity(0.8),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPremium
                    ? [Colors.amber[700]!, Colors.amber[900]!]
                    : [
                        isDark ? colorScheme.primaryContainer : AppTheme.primaryLight,
                        isDark ? colorScheme.secondaryContainer : AppTheme.primaryHoverLight,
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isPremium
                      ? Colors.amber.withOpacity(0.4)
                      : (isDark ? AppTheme.primaryDark.withOpacity(0.3) : AppTheme.primaryLight.withOpacity(0.3)),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: colorScheme.surface.withValues(alpha: 0.3),
                  child: Icon(
                    Icons.person,
                    size: 48,
                    color: isPremium ? Colors.white : Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  username.isNotEmpty ? username : 'Sin nombre',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (premiumUntil > 0)
                  Column(
                    children: [
                      Icon(
                        Icons.timer,
                        color: Colors.white,
                        size: 32,
                        shadows: [
                          Shadow(
                            color: Colors.amber.withOpacity(0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _RemainingTimeModal(premiumUntil: premiumUntil),
                    ],
                  )
                else if (isPremium)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.workspace_premium,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'PREMIUM',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Text(
                          'GRATIS',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sin prueba gratis',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Nombre',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          NeonCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(16),
            onTap: () => _showUsernameDialog(context, ref, username),
            child: Row(
              children: [
                Icon(Icons.person_outline, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    username.isNotEmpty
                        ? username
                        : 'Toca para agregar nombre',
                    style: TextStyle(
                      color: username.isEmpty
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.onSurface,
                    ),
                  ),
                ),
                Icon(
                  Icons.edit,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Stats Card
          NeonCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(16),
            child: StatsCard(),
          ),
          const SizedBox(height: 24),
          Center(
            child: NeonCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              glowColor: Colors.redAccent,
              onTap: () => _showResetDialog(context, ref),
              child: Text(
                'Reiniciar configuración',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showUsernameDialog(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: AlertDialog(
          backgroundColor: isDark ? AppTheme.surfaceDark.withOpacity(0.9) : AppTheme.surfaceLight.withOpacity(0.9),
          title: Text('Tu nombre'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Ingresa tu nombre...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onSubmitted: (value) {
              ref.read(settingsProvider.notifier).setUsername(value.trim());
              Navigator.pop(ctx);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                ref
                    .read(settingsProvider.notifier)
                    .setUsername(controller.text.trim());
                Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: AlertDialog(
          backgroundColor: isDark ? AppTheme.surfaceDark.withOpacity(0.9) : AppTheme.surfaceLight.withOpacity(0.9),
          title: const Text('Reiniciar configuración'),
          content: const Text(
              '¿Deseas restablecer la app al asistente de configuración inicial?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.dialogCancel),
            ),
            FilledButton(
              onPressed: () async {
                final router = GoRouter.of(context);
                final navigator = Navigator.of(context, rootNavigator: true);
                
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('setup_initial_step');
                await ref.read(settingsProvider.notifier).resetToFirstLaunch(hardReset: true);
                
                if (!context.mounted) return;
                Navigator.pop(ctx);
                navigator.pop();
                router.go(
                  '/setup?reset=${DateTime.now().millisecondsSinceEpoch}',
                  extra: {'initialStep': 0},
                );
              },
              child: const Text('Reiniciar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RemainingTimeModal extends StatefulWidget {
  final int premiumUntil;

  const _RemainingTimeModal({required this.premiumUntil});

  @override
  State<_RemainingTimeModal> createState() => _RemainingTimeModalState();
}

class _RemainingTimeModalState extends State<_RemainingTimeModal> {
  late int _remainingMs;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
  }

  void _updateRemaining() {
    final now = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _remainingMs = widget.premiumUntil - now;
    });
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _updateRemaining();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_remainingMs <= 0) {
      final startDate = DateTime.fromMillisecondsSinceEpoch(
        widget.premiumUntil - Duration.millisecondsPerDay,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Prueba usada el:',
            style: TextStyle(fontSize: 11, color: Colors.red[300]),
          ),
          Text(
            '${startDate.day}/${startDate.month}/${startDate.year}',
            style: TextStyle(fontSize: 10, color: Colors.red[200]),
          ),
        ],
      );
    }
    final horas = _remainingMs ~/ (1000 * 60 * 60);
    final minutos = (_remainingMs % (1000 * 60 * 60)) ~/ (1000 * 60);
    final segundos = ((_remainingMs % (1000 * 60 * 60)) % (1000 * 60)) ~/ 1000;
    return Text(
      '${horas}h ${minutos}m ${segundos}s restantes',
      style: TextStyle(
        fontSize: 12,
        color: Colors.white.withValues(alpha: 0.9),
        fontWeight: FontWeight.w500,
        shadows: [
          Shadow(
            color: Colors.amber.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}
