import 'dart:io';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/providers/extension_provider.dart';
import 'package:bitly/l10n/l10n.dart';
import 'package:bitly/services/library/covers/cover_cache_manager.dart';
import 'package:bitly/providers/settings_provider.dart';
import 'package:bitly/utils/source_icons.dart';

class DownloadServicePicker extends ConsumerStatefulWidget {
  final String? trackName;
  final String? artistName;
  final String? coverUrl;
  final int? durationSecs;
  final void Function(String quality, String service) onSelect;
  final String? recommendedService;

  const DownloadServicePicker({
    super.key,
    this.trackName,
    this.artistName,
    this.coverUrl,
    this.durationSecs,
    required this.onSelect,
    this.recommendedService,
  });

  @override
  ConsumerState<DownloadServicePicker> createState() =>
      _DownloadServicePickerState();

  static void show(
    BuildContext context, {
    String? trackName,
    String? artistName,
    String? coverUrl,
    int? durationSecs,
    String? recommendedService,
    required void Function(String quality, String service) onSelect,
  }) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      isScrollControlled: true,
      builder: (context) => DownloadServicePicker(
        trackName: trackName,
        artistName: artistName,
        coverUrl: coverUrl,
        durationSecs: durationSecs,
        onSelect: onSelect,
        recommendedService: recommendedService,
      ),
    );
  }
}

class _DownloadServicePickerState extends ConsumerState<DownloadServicePicker> {

  List<Extension> _downloadExtensions() {
    final extensionState = ref.read(extensionProvider);
    return extensionState.extensions
        .where((ext) => ext.enabled && ext.hasDownloadProvider)
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(extensionProvider.notifier).refreshEnabledExtensionHealth();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final extensionState = ref.watch(extensionProvider);
    final settings = ref.watch(settingsProvider);
    final downloadExtensions = _downloadExtensions();
    final hasProviders = downloadExtensions.isNotEmpty;
    final duration = widget.durationSecs ?? 180;
    final coverUrl = widget.coverUrl;

    Widget? coverWidget;
    if (coverUrl != null && coverUrl.isNotEmpty) {
      if (coverUrl.startsWith('http://') || coverUrl.startsWith('https://')) {
        coverWidget = CachedNetworkImage(
          imageUrl: coverUrl,
          fit: BoxFit.cover,
          memCacheWidth: 200,
          cacheManager: CoverCacheManager.instance,
          errorWidget: (_, _, _) => const SizedBox.shrink(),
        );
      } else {
        coverWidget = Image.file(
          File(coverUrl),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        );
      }
    }

    final sheetContent = SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.trackName != null) ...[
              _TrackInfoHeader(
                trackName: widget.trackName!,
                artistName: widget.artistName,
                coverUrl: widget.coverUrl,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: colorScheme.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.settings_input_composite, size: 15, color: colorScheme.secondary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Opciones extra',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            
            _ExtraOptionToggle(
              icon: Icons.lyrics_outlined,
              label: 'Descargar Letra',
              value: settings.embedLyrics,
              onChanged: (v) => ref.read(settingsProvider.notifier).setEmbedLyrics(v),
            ),
            _ExtraOptionToggle(
              icon: Icons.movie_outlined,
              label: 'Descargar Video',
              value: settings.downloadVideo,
              onChanged: (v) => ref.read(settingsProvider.notifier).setDownloadVideo(v),
            ),

            const SizedBox(height: 12),
            if (hasProviders)
              for (final ext in downloadExtensions)
                _ProviderAccordion(
                  ext: ext,
                  healthStatus: ext.hasServiceHealth
                      ? extensionState.healthStatuses[ext.id]?.status
                      : null,
                  isRecommended: ext.id == widget.recommendedService,
                  qualities: ext.qualityOptions,
                  onSelect: (qualityId) {
                    Navigator.pop(context);
                    widget.onSelect(qualityId, ext.id);
                  },
                  estimateMB: (qId) => _estimateMB(duration, qId),
                )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _NoDownloadProviderHint(
                  primaryText: context.l10n.extensionsNoDownloadProvider,
                  secondaryText: context.l10n.storeAddRepoDescription,
                ),
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Stack(
          children: [
            if (coverWidget != null)
              Positioned.fill(child: ClipRRect(child: coverWidget)),
            Positioned.fill(
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(color: colorScheme.surface.withValues(alpha: 0.75)),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 0.5)),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
              ),
            ),
            sheetContent,
          ],
        ),
    );
  }

  double _estimateMB(int seconds, String qualityId) {
    final minutes = seconds / 60.0;
    final normalized = qualityId.toUpperCase();
    if (normalized.contains('320') || normalized == 'MP3_320') {
      return minutes * 2.4;
    }
    if (normalized.contains('256')) {
      return minutes * 1.9;
    }
    if (normalized.contains('160') || normalized == 'OPUS_160') {
      return minutes * 1.2;
    }
    if (normalized.contains('128') || normalized == 'MP3_128' || normalized == 'OPUS_128') {
      return minutes * 1.0;
    }
    if (normalized.contains('LOSSLESS') || normalized == 'FLAC' || normalized == 'LOSSLESS_16') {
      return minutes * 6;
    }
    if (normalized.contains('HI_RES') && normalized.contains('96')) {
      return minutes * 15;
    }
    if (normalized.contains('HI_RES') || normalized.contains('24_96') || normalized.contains('24_192')) {
      return minutes * 25;
    }
    return minutes * 3;
  }
}

class _ProviderAccordion extends StatefulWidget {
  final Extension ext;
  final String? healthStatus;
  final bool isRecommended;
  final List<QualityOption> qualities;
  final void Function(String qualityId) onSelect;
  final double Function(String qualityId) estimateMB;

  const _ProviderAccordion({
    required this.ext,
    this.healthStatus,
    required this.isRecommended,
    required this.qualities,
    required this.onSelect,
    required this.estimateMB,
  });

  @override
  State<_ProviderAccordion> createState() => _ProviderAccordionState();
}

class _ProviderAccordionState extends State<_ProviderAccordion> {
  bool _expanded = false;

  Widget _buildFallbackIcon(Extension ext, ColorScheme colorScheme) {
    final fromSource = sourceIcon(ext.id);
    if (fromSource != Icons.extension) {
      return Icon(fromSource, size: 16, color: colorScheme.onSurfaceVariant);
    }
    final fromName = sourceIcon(ext.displayName);
    if (fromName != Icons.extension) {
      return Icon(fromName, size: 16, color: colorScheme.onSurfaceVariant);
    }
    final letter = initialLetterFor(ext.displayName);
    final color = initialColorFor(ext.displayName, colorScheme: colorScheme);
    return Center(
      child: Text(letter,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ext = widget.ext;
    final hasQualities = widget.qualities.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──────────────────────────────────────────
              InkWell(
                onTap: hasQualities
                    ? () => setState(() => _expanded = !_expanded)
                    : null,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      // Provider icon
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ext.iconPath != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(ext.iconPath!),
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, a, b) => _buildFallbackIcon(ext, colorScheme),
                                ),
                              )
                            : _buildFallbackIcon(ext, colorScheme),
                      ),
                      const SizedBox(width: 10),
                      // Provider name + status
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    ext.displayName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: colorScheme.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (widget.isRecommended) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: colorScheme.tertiary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                      child: Text(
                                        'Mejor',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.tertiary,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (widget.healthStatus != null || hasQualities)
                              Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: Row(
                                  children: [
                                    if (widget.healthStatus != null) ...[
                                      _ServiceHealthDot(status: widget.healthStatus!, size: 6),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.healthStatus == 'online'
                                            ? 'En línea'
                                            : (widget.healthStatus == 'degraded'
                                                ? 'Degradado'
                                                : 'Fuera de línea'),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      if (hasQualities) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          width: 2,
                                          height: 2,
                                          decoration: BoxDecoration(
                                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                    ],
                                    if (hasQualities)
                                      Text(
                                        '${widget.qualities.length} ${widget.qualities.length == 1 ? 'cal' : 'cales'}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (hasQualities)
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.expand_more,
                            size: 18,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Qualities (expandable) ─────────────────────────
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 6),
                      for (int i = 0; i < widget.qualities.length; i++)
                        _QualityItem(
                          quality: widget.qualities[i],
                          estimatedMB: widget.estimateMB(widget.qualities[i].id),
                          onTap: () => widget.onSelect(widget.qualities[i].id),
                          showBottomGap: i < widget.qualities.length - 1,
                        ),
                    ],
                  ),
                ),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QualityItem extends StatelessWidget {
  final QualityOption quality;
  final double estimatedMB;
  final VoidCallback onTap;
  final bool showBottomGap;

  const _QualityItem({
    required this.quality,
    required this.estimatedMB,
    required this.onTap,
    required this.showBottomGap,
  });

  String _formatSize(double mb) {
    if (mb >= 100) {
      return '${mb.round()}';
    }
    return mb.toStringAsFixed(mb >= 10 ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final qualityId = quality.id.toUpperCase();

    IconData icon;
    Color iconColor;
    if (qualityId.contains('HI_RES') || qualityId.contains('24_')) {
      icon = Icons.four_k;
      iconColor = const Color(0xFF7C4DFF);
    } else if (qualityId.contains('LOSSLESS') || qualityId == 'FLAC') {
      icon = Icons.music_note;
      iconColor = const Color(0xFF00BFA5);
    } else if (qualityId.contains('320') || qualityId.contains('MP3')) {
      icon = Icons.audiotrack;
      iconColor = const Color(0xFFFF6D00);
    } else {
      icon = Icons.graphic_eq;
      iconColor = const Color(0xFF448AFF);
    }

    String? br, sr, bd;
    for (final setting in quality.settings) {
      final v = setting.defaultValue?.toString() ?? '';
      switch (setting.key.toLowerCase()) {
        case 'bitrate':
          br = v;
        case 'sample_rate':
          sr = v;
        case 'bit_depth':
          bd = v;
      }
    }

    final specParts = [
      if (br != null) '$br kbps',
      if (sr != null) '$sr kHz',
      if (bd != null) '$bd-bit',
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: showBottomGap ? 4 : 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                // Quality icon
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(icon, size: 14, color: iconColor),
                ),
                const SizedBox(width: 8),
                // Label + specs
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        quality.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (specParts.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(
                            specParts.join(' · '),
                            style: TextStyle(
                              fontSize: 9,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Size badge
                if (estimatedMB > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.storage, size: 9, color: colorScheme.onPrimaryContainer),
                        const SizedBox(width: 2),
                        Text(
                          '~${_formatSize(estimatedMB)} MB',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 4),
                Icon(
                  Icons.download,
                  size: 14,
                  color: colorScheme.primary.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceHealthDot extends StatelessWidget {
  final String status;
  final double size;

  const _ServiceHealthDot({required this.status, this.size = 8});

  @override
  Widget build(BuildContext context) {
    final color = _serviceHealthColor(status);
    return Tooltip(
      message: _serviceHealthTooltip(status),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

Color _serviceHealthColor(String status) {
  switch (status) {
    case 'online':
      return const Color(0xFF35D07F);
    case 'degraded':
    case 'unknown':
      return const Color(0xFFFFC857);
    case 'offline':
      return const Color(0xFFFF4D5E);
    default:
      return const Color(0xFFFFC857);
  }
}

String _serviceHealthTooltip(String status) {
  switch (status) {
    case 'online':
      return 'Servicio en línea';
    case 'degraded':
      return 'Servicio degradado';
    case 'offline':
      return 'Servicio fuera de línea';
    default:
      return 'Estado desconocido';
  }
}

class _NoDownloadProviderHint extends StatelessWidget {
  final String primaryText;
  final String secondaryText;

  const _NoDownloadProviderHint({
    required this.primaryText,
    required this.secondaryText,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.extension_outlined,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  primaryText,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  secondaryText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackInfoHeader extends StatefulWidget {
  final String trackName;
  final String? artistName;
  final String? coverUrl;

  const _TrackInfoHeader({
    required this.trackName,
    this.artistName,
    this.coverUrl,
  });

  @override
  State<_TrackInfoHeader> createState() => _TrackInfoHeaderState();
}

class _TrackInfoHeaderState extends State<_TrackInfoHeader> {
  bool _expanded = false;
  bool _isOverflowing = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isOverflowing
            ? () => setState(() => _expanded = !_expanded)
            : null,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: widget.coverUrl != null
                        ? Image.network(
                            widget.coverUrl!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  width: 48,
                                  height: 48,
                                  color: colorScheme.surfaceContainerHighest,
                                  child: Icon(
                                    Icons.music_note,
                                    size: 20,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                          )
                        : Container(
                            width: 48,
                            height: 48,
                            color: colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.music_note,
                              size: 20,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final titleStyle = Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600);
                        final titleSpan = TextSpan(
                          text: widget.trackName,
                          style: titleStyle,
                        );
                        final titlePainter = TextPainter(
                          text: titleSpan,
                          maxLines: 1,
                          textDirection: TextDirection.ltr,
                        )..layout(maxWidth: constraints.maxWidth);
                        final titleOverflows = titlePainter.didExceedMaxLines;

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && _isOverflowing != titleOverflows) {
                            setState(() => _isOverflowing = titleOverflows);
                          }
                        });

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.trackName,
                              style: titleStyle,
                              maxLines: _expanded ? 10 : 1,
                              overflow: _expanded
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                            ),
                            if (widget.artistName != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.artistName!,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                maxLines: _expanded ? 3 : 1,
                                overflow: _expanded
                                    ? TextOverflow.visible
                                    : TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                  if (_isOverflowing || _expanded)
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: colorScheme.onSurfaceVariant,
                      size: 18,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtraOptionToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ExtraOptionToggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
              SizedBox(
                height: 24,
                child: Transform.scale(
                  scale: 0.7,
                  child: Switch(
                    value: value,
                    onChanged: onChanged,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
