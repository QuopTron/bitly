import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import '../utils/format_size.dart';
import '../../l10n/app_localizations.dart';
import '../models/feed_models.dart';
import '../models/download_settings.dart';
import '../theme/app_colors.dart';
import '../../../backend/services/download_cubit.dart';
import '../../../backend/cache/settings_cache.dart';
import '../../../backend/rpc/backend_service.dart';
import '../utils/download_strategy.dart';
import '../../../injection.dart';
import 'glass_container.dart';

class DownloadOptionsSheet extends StatefulWidget {
  final FeedItem item;
  final bool isDark;
  final DownloadSettings dlSettings;

  /// Optional callback for batch download. When set, tapping "Download" calls this
  /// with the selected quality instead of dispatching a single-track download.
  /// The caller is responsible for starting the actual download.
  final ValueChanged<String>? onQualitySelected;

  const DownloadOptionsSheet({
    super.key,
    required this.item,
    required this.isDark,
    required this.dlSettings,
    this.onQualitySelected,
  });

  @override
  State<DownloadOptionsSheet> createState() => _DownloadOptionsSheetState();
}

class _DownloadOptionsSheetState extends State<DownloadOptionsSheet> {
  Map<String, String> _sizes = {};
  String? _selected;
  bool _hasDuration = true;

  // Quality metadata: label, bitrate kbps, tier group
  static const _qualities = {
    'flac': _QMeta('FLAC', 1411, 'lossless', 'lossless'),
    'hifi': _QMeta('HiFi', 320, 'lossless', 'lossless'),
    'high': _QMeta('High', 192, 'lossy', 'lossy'),
    'medium': _QMeta('Medium', 128, 'lossy', 'lossy'),
    'low': _QMeta('Low', 64, 'lossy', 'lossy'),
  };

  static const _losslessKeys = ['flac', 'hifi'];
  static const _lossyKeys = ['high', 'medium', 'low'];

  @override
  void initState() {
    super.initState();
    _selected = widget.dlSettings.audioQuality;
    _loadSizes();
  }

  Future<void> _loadSizes() async {
    final dm = widget.item.durationMs;
    final hasDuration = dm != null && dm > 0;
    final sizes = <String, String>{};
    if (hasDuration) {
      final b = sl<BackendService>();
      for (final q in DownloadSettings.audioQualityOptions) {
        try {
          final raw = await b.estimateTrackFileSize(dm, q);
          final p = jsonDecode(raw) as Map?;
          final bytes = (p?['size_bytes'] as num?)?.toInt() ?? 0;
          sizes[q] = formatBytes(bytes);
        } catch (_) {
          sizes[q] = '';
        }
      }
    }
    if (mounted) {
      setState(() {
        _sizes = sizes;
        _hasDuration = hasDuration;
      });
    }
  }

  void _start() {
    final selectedQuality = _selected ?? widget.dlSettings.audioQuality;

    // If onQualitySelected is set, delegate to caller (batch download mode)
    if (widget.onQualitySelected != null) {
      widget.onQualitySelected!(selectedQuality);
      Navigator.pop(context);
      return;
    }

    // Normal single-track mode
    final cubit = sl<DownloadCubit>();
    final item = widget.item;
    final baseId = '${item.type}_${normalizeTrackId(item.id)}_${item.source}';
    final qualityOverride = selectedQuality;
    final commonMeta = buildTrackMeta(
      trackId: item.id,
      trackTitle: item.name,
      artistName: item.artists ?? '',
      albumName: item.albumName ?? '',
      source: item.source ?? '',
      isrc: item.isrc ?? '',
      durationMs: item.durationMs ?? 0,
      coverUrl: item.coverUrl,
    );
    dispatchDownloads(
      cubit: cubit,
      commonMeta: commonMeta,
      settings: widget.dlSettings,
      baseId: baseId,
      qualityOverride: qualityOverride,
    );
    Navigator.pop(context);
  }

  Widget _buildOption(
    BuildContext context,
    Responsive r,
    String q,
    Color glowColor,
    Color onBg,
  ) {
    final meta = _qualities[q]!;
    final selected = _selected == q;
    final isDefault = q == widget.dlSettings.audioQuality;
    final sizeStr = _hasDuration ? (_sizes[q] ?? '') : null;
    final showBestBadge = q == 'flac' || q == 'hifi';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _selected = q),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? glowColor : onBg.withValues(alpha: 0.07),
              width: selected ? 1.2 : 0.5,
            ),
            color:
                selected
                    ? glowColor.withValues(alpha: 0.08)
                    : onBg.withValues(alpha: 0.02),
          ),
          padding: EdgeInsets.all(r.spacingM),
          child: Row(
            children: [
              _RadioButton<String>(
                value: q,
                groupValue: _selected,
                activeColor: glowColor,
                onChanged: (v) => setState(() => _selected = v),
              ),
              SizedBox(width: r.spacingS),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          meta.label,
                          style: TextStyle(
                            fontSize: r.subtitleSize,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: onBg,
                          ),
                        ),
                        if (showBestBadge) ...[
                          SizedBox(width: 6),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  selected
                                      ? glowColor.withValues(alpha: 0.15)
                                      : glowColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              meta.tier == 'lossless' ? 'LOSSLESS' : '',
                              style: TextStyle(
                                fontSize: r.footerSize - 2,
                                fontWeight: FontWeight.w700,
                                color: glowColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                        if (isDefault) ...[
                          SizedBox(width: 6),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: onBg.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              'default',
                              style: TextStyle(
                                fontSize: r.footerSize - 2,
                                color: onBg.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 3),
                    Row(
                      children: [
                        if (sizeStr != null && sizeStr.isNotEmpty)
                          Text(
                            sizeStr,
                            style: TextStyle(
                              fontSize: r.footerSize - 1,
                              fontWeight: FontWeight.w500,
                              color: onBg.withValues(alpha: 0.5),
                            ),
                          ),
                        if (sizeStr != null && sizeStr.isNotEmpty) ...[
                          SizedBox(width: 8),
                          Container(
                            width: 1,
                            height: 10,
                            color: onBg.withValues(alpha: 0.08),
                          ),
                          SizedBox(width: 8),
                        ],
                        Text(
                          '${meta.bitrate} kbps',
                          style: TextStyle(
                            fontSize: r.footerSize - 1,
                            color: onBg.withValues(alpha: 0.35),
                          ),
                        ),
                        if (!_hasDuration) ...[
                          SizedBox(width: 8),
                          Container(
                            width: 1,
                            height: 10,
                            color: onBg.withValues(alpha: 0.08),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.hourglass_bottom,
                            size: r.footerSize - 2,
                            color: onBg.withValues(alpha: 0.2),
                          ),
                          SizedBox(width: 4),
                          Text(
                            AppLocalizations.of(context).setup.unknownSize,
                            style: TextStyle(
                              fontSize: r.footerSize - 1,
                              fontStyle: FontStyle.italic,
                              color: onBg.withValues(alpha: 0.25),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(
    BuildContext context,
    Responsive r,
    String title,
    Color onBg,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        r.spacingM + 4,
        r.spacingS,
        r.spacingM + 4,
        2,
      ),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: r.footerSize - 1,
              fontWeight: FontWeight.w700,
              color: onBg.withValues(alpha: 0.25),
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(width: r.spacingM),
          Expanded(
            child: Divider(color: onBg.withValues(alpha: 0.06), height: 1),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final loc = AppLocalizations.of(context);
    final onBg = widget.isDark ? Colors.white : Colors.black;
    final glowColor =
        widget.isDark ? AppColors.greenBright : AppColors.greenMedium;

    return Container(
      margin: EdgeInsets.only(top: r.spacingXL * 2),
      decoration: BoxDecoration(
        color:
            widget.isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: r.spacingM),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: onBg.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: r.spacingL),
              // ── Header ───────────────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.item.name,
                            style: TextStyle(
                              fontSize: r.subtitleSize + 1,
                              fontWeight: FontWeight.bold,
                              color: onBg,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.item.artists != null &&
                              widget.item.artists!.isNotEmpty)
                            Text(
                              widget.item.artists!,
                              style: TextStyle(
                                fontSize: r.footerSize,
                                color: onBg.withValues(alpha: 0.4),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    SizedBox(width: r.spacingM),
                    Icon(
                      Icons.download,
                      size: r.subtitleSize + 4,
                      color: glowColor,
                    ),
                  ],
                ),
              ),
              SizedBox(height: r.spacingM),
              // ── Lossless section ──────────────────────────────────
              _sectionHeader(context, r, 'LOSSLESS', onBg),
              ..._losslessKeys.map(
                (q) => _buildOption(context, r, q, glowColor, onBg),
              ),
              // ── Lossy section ────────────────────────────────────
              _sectionHeader(context, r, 'LOSSY', onBg),
              ..._lossyKeys.map(
                (q) => _buildOption(context, r, q, glowColor, onBg),
              ),
              SizedBox(height: r.spacingM),
              // ── Info banner ──────────────────────────────────────
              if (widget.dlSettings.videoEnabled ||
                  widget.dlSettings.lyricsEnabled)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: r.spacingM),
                  child: GlassContainer(
                    borderRadius: 12,
                    borderColor: glowColor.withValues(alpha: 0.2),
                    bgColor: glowColor.withValues(alpha: 0.06),
                    padding: EdgeInsets.all(r.spacingS),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: r.footerSize,
                          color: glowColor,
                        ),
                        SizedBox(width: r.spacingXS),
                        Expanded(
                          child: Text(
                            widget.dlSettings.videoEnabled &&
                                    widget.dlSettings.lyricsEnabled
                                ? '${loc.setup.videoDownload} + ${loc.setup.lyricsDownload} (${loc.setup.settings})'
                                : widget.dlSettings.videoEnabled
                                ? '${loc.setup.videoDownload} (${loc.setup.settings})'
                                : '${loc.setup.lyricsDownload} (${loc.setup.settings})',
                            style: TextStyle(
                              fontSize: r.footerSize - 1,
                              color: onBg.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SizedBox(height: r.spacingM),
              // ── Download button ──────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
                child: SizedBox(
                  width: double.infinity,
                  height: r.continueButtonHeight,
                  child: ElevatedButton(
                    onPressed: _start,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: glowColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.download, size: r.subtitleSize),
                        SizedBox(width: r.spacingXS),
                        Text(
                          '${loc.setup.downloaded}  ${_selected != null ? _qualities[_selected]!.label : ''}',
                          style: TextStyle(
                            fontSize: r.subtitleSize,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: r.spacingXL),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quality metadata.
class _QMeta {
  final String label;
  final int bitrate;
  final String tier;
  final String group;
  const _QMeta(this.label, this.bitrate, this.tier, this.group);
}

class _RadioButton<T> extends StatelessWidget {
  final T value;
  final T? groupValue;
  final Color activeColor;
  final ValueChanged<T> onChanged;

  const _RadioButton({
    required this.value,
    required this.groupValue,
    required this.activeColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? activeColor : Colors.grey.withValues(alpha: 0.4),
            width: 2,
          ),
          color:
              selected
                  ? activeColor.withValues(alpha: 0.15)
                  : Colors.transparent,
        ),
        child:
            selected
                ? Center(
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: activeColor,
                    ),
                  ),
                )
                : null,
      ),
    );
  }
}

/// Directly starts a download using saved settings without showing the options sheet.
/// Used when [DownloadSettings.quickDownload] is enabled.
void quickDownloadTrack(FeedItem item, DownloadSettings settings) {
  final cubit = sl<DownloadCubit>();
  final baseId = '${item.type}_${normalizeTrackId(item.id)}_${item.source}';
  final commonMeta = buildTrackMeta(
    trackId: item.id,
    trackTitle: item.name,
    artistName: item.artists ?? '',
    albumName: item.albumName ?? '',
    source: item.source ?? '',
    isrc: item.isrc ?? '',
    durationMs: item.durationMs ?? 0,
    coverUrl: item.coverUrl,
  );
  dispatchDownloads(
    cubit: cubit,
    commonMeta: commonMeta,
    settings: settings,
    baseId: baseId,
  );
}

Future<void> showDownloadOptions(
  BuildContext context,
  FeedItem item,
  bool isDark, {
  DownloadSettings? dlSettings,
  bool ignoreQuickDownload = false,
}) async {
  final settings =
      dlSettings ?? await sl<SettingsCache>().getDownloadSettings();
  if (!context.mounted) return;

  // If quick download is enabled, skip the options sheet entirely (unless the
  // caller explicitly wants the quality modal — e.g. Mi Espacio's manual icon).
  if (settings.quickDownload && !ignoreQuickDownload) {
    quickDownloadTrack(item, settings);
    return;
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder:
        (_) => DownloadOptionsSheet(
          item: item,
          isDark: isDark,
          dlSettings: settings,
        ),
  );
}
