import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/constants/app_info.dart';
import 'package:bitly/l10n/l10n.dart';
import 'package:bitly/providers/settings_provider.dart';
import 'package:bitly/screens/settings/appearance_settings_page.dart';
import 'package:bitly/screens/settings/download_settings_page.dart';
import 'package:bitly/screens/settings/files_settings_page.dart';
import 'package:bitly/screens/settings/lyrics_settings_page.dart';
import 'package:bitly/screens/settings/metadata_settings_page.dart';
import 'package:bitly/screens/settings/extensions_page.dart';
import 'package:bitly/screens/settings/library_settings_page.dart';
import 'package:bitly/widgets/settings_modal.dart';
import 'package:bitly/screens/settings/about_page.dart';
import 'package:bitly/screens/settings/cache_management_page.dart';
import 'package:bitly/screens/settings/donate_page.dart';
import 'package:bitly/screens/settings/log_screen.dart';
import 'package:bitly/utils/app_bar_layout.dart';
import 'package:bitly/widgets/settings_group.dart';
import 'package:bitly/widgets/animation_utils.dart';
import 'package:bitly/widgets/stats_card.dart';
import 'dart:async';

class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final topPadding = normalizedHeaderTopPadding(context);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 120 + topPadding,
          collapsedHeight: kToolbarHeight,
          floating: false,
          pinned: true,
          backgroundColor: colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          flexibleSpace: LayoutBuilder(
            builder: (context, constraints) {
              final maxHeight = 120 + topPadding;
              final minHeight = kToolbarHeight + topPadding;
              final expandRatio =
                  ((constraints.maxHeight - minHeight) /
                          (maxHeight - minHeight))
                      .clamp(0.0, 1.0);

              return FlexibleSpaceBar(
                expandedTitleScale: 1.0,
                titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
                title: Text(
                  context.l10n.settingsTitle,
                  style: TextStyle(
                    fontSize: 20 + (14 * expandRatio),
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              );
            },
          ),
        ),

        SliverToBoxAdapter(child: const _PerfilCard()),

        SliverToBoxAdapter(child: const StatsCard()),

        SliverToBoxAdapter(
          child: Builder(
            builder: (context) {
              final l10n = context.l10n;
              return SettingsGroup(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                children: [
                  SettingsItem(
                    icon: Icons.palette_outlined,
                    title: l10n.settingsAppearance,
                    subtitle: l10n.settingsAppearanceSubtitle,
                    onTap: () =>
                        _navigateTo(context, const AppearanceSettingsPage()),
                  ),
                  SettingsItem(
                    icon: Icons.library_music_outlined,
                    title: l10n.settingsLocalLibrary,
                    subtitle: l10n.settingsLocalLibrarySubtitle,
                    onTap: () =>
                        _navigateTo(context, const LibrarySettingsPage()),
                  ),
                  SettingsItem(
                    icon: Icons.extension_outlined,
                    title: l10n.settingsExtensions,
                    subtitle: l10n.settingsExtensionsSubtitle,
                    onTap: () => _navigateTo(context, const ExtensionsPage()),
                    showDivider: false,
                  ),
                ],
              );
            },
          ),
        ),

        SliverToBoxAdapter(
          child: Builder(
            builder: (context) {
              final l10n = context.l10n;
              return SettingsGroup(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                children: [
                  SettingsItem(
                    icon: Icons.download_outlined,
                    title: l10n.settingsDownload,
                    subtitle: l10n.settingsDownloadSubtitle,
                    onTap: () =>
                        _navigateTo(context, const DownloadSettingsPage()),
                  ),
                  SettingsItem(
                    icon: Icons.folder_outlined,
                    title: l10n.settingsFiles,
                    subtitle: l10n.settingsFilesSubtitle,
                    onTap: () =>
                        _navigateTo(context, const FilesSettingsPage()),
                  ),
                  SettingsItem(
                    icon: Icons.sell_outlined,
                    title: l10n.settingsMetadata,
                    subtitle: l10n.settingsMetadataSubtitle,
                    onTap: () =>
                        _navigateTo(context, const MetadataSettingsPage()),
                  ),
                  SettingsItem(
                    icon: Icons.lyrics_outlined,
                    title: l10n.settingsLyrics,
                    subtitle: l10n.settingsLyricsSubtitle,
                    onTap: () =>
                        _navigateTo(context, const LyricsSettingsPage()),
                    showDivider: false,
                  ),
                ],
              );
            },
          ),
        ),

        SliverToBoxAdapter(
          child: Builder(
            builder: (context) {
              final l10n = context.l10n;
              return SettingsGroup(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                children: [
                  SettingsItem(
                    icon: Icons.storage_outlined,
                    title: l10n.settingsCache,
                    subtitle: l10n.settingsCacheSubtitle,
                    onTap: () =>
                        _navigateTo(context, const CacheManagementPage()),
                  ),
                  SettingsItem(
                    icon: Icons.tune_outlined,
                    title: l10n.settingsApp,
                    subtitle: l10n.settingsAppSubtitle,
                    onTap: () => showSettingsModal(context),
                  ),
                  SettingsItem(
                    icon: Icons.article_outlined,
                    title: l10n.logTitle,
                    subtitle: l10n.settingsLogsSubtitle,
                    onTap: () => _navigateTo(context, const LogScreen()),
                  ),
                  SettingsItem(
                    icon: Icons.favorite_outline,
                    title: l10n.settingsDonate,
                    subtitle: l10n.settingsDonateSubtitle,
                    onTap: () => _navigateTo(context, const DonatePage()),
                  ),
                  SettingsItem(
                    icon: Icons.info_outline,
                    title: l10n.settingsAbout,
                    subtitle: '${l10n.aboutVersion} ${AppInfo.displayVersion}',
                    onTap: () => _navigateTo(context, const AboutPage()),
                    showDivider: false,
                  ),
                ],
              );
            },
          ),
        ),

        const SliverFillRemaining(hasScrollBody: false, child: SizedBox()),
      ],
    );
  }

  void _navigateTo(BuildContext context, Widget page) {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).push(slidePageRoute<void>(page: page));
  }
}

class _PerfilCard extends ConsumerWidget {
  const _PerfilCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final username = settings.username;
    final isPremium = settings.isPremium;
    final premiumUntil = settings.premiumUntil;
    final trialActive = premiumUntil > 0 && isPremium;
    final trialUsed = premiumUntil > 0 && !isPremium;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isPremium
                ? [Colors.amber[700]!, Colors.amber[900]!]
                : [
                    colorScheme.primaryContainer,
                    colorScheme.secondaryContainer,
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: colorScheme.surface.withAlpha(77),
              child: Icon(
                Icons.person,
                size: 32,
                color: isPremium
                    ? Colors.white
                    : colorScheme.onPrimaryContainer,
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
                          : colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (trialActive)
                    _TiempoRestante(premiumUntil: premiumUntil)
                  else if (isPremium)
                    const Row(
                      children: [
                        Icon(
                          Icons.workspace_premium,
                          size: 16,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Premium',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
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
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        Text(
                          'Prueba gratis usada',
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onPrimaryContainer.withValues(
                              alpha: 0.6,
                            ),
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
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        Text(
                          'Sin prueba gratis',
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onPrimaryContainer.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (!isPremium)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withAlpha(51),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  trialActive
                      ? 'Prueba activa'
                      : trialUsed
                      ? 'Prueba usada'
                      : 'Gratis',
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TiempoRestante extends StatefulWidget {
  final int premiumUntil;

  const _TiempoRestante({required this.premiumUntil});

  @override
  State<_TiempoRestante> createState() => _TiempoRestanteState();
}

class _TiempoRestanteState extends State<_TiempoRestante> {
  late int _remainingMs;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateRemaining();
      }
    });
  }

  void _updateRemaining() {
    final now = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _remainingMs = widget.premiumUntil - now;
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remainingMs <= 0) {
      return Text(
        '¡Expiraste ahorita!',
        style: TextStyle(
          fontSize: 12,
          color: Colors.red[100],
          fontWeight: FontWeight.bold,
        ),
      );
    }

    final horas = _remainingMs ~/ (1000 * 60 * 60);
    final minutos = (_remainingMs % (1000 * 60 * 60)) ~/ (1000 * 60);
    final segundos = ((_remainingMs % (1000 * 60 * 60)) % (1000 * 60)) ~/ 1000;

    return Text(
      'Eres premium por: ${horas}h ${minutos}m ${segundos}s',
      style: TextStyle(
        fontSize: 12,
        color: Colors.white.withAlpha(230),
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
