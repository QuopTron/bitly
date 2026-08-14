import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import '../utils/format_size.dart';
import '../../l10n/app_localizations.dart';
import '../models/download_settings.dart';
import '../../../backend/cache/settings_cache.dart';
import '../../../backend/rpc/backend_service.dart';
import '../../../backend/services/player_cubit.dart';
import '../../../injection.dart';
import 'glass_container.dart';

class SettingsDownloadSection extends StatefulWidget {
  final Color onBg;
  final Color glowColor;

  const SettingsDownloadSection({super.key, required this.onBg, required this.glowColor});

  @override
  State<SettingsDownloadSection> createState() => _SettingsDownloadSectionState();
}

class _SettingsDownloadSectionState extends State<SettingsDownloadSection> {
  DownloadSettings _settings = const DownloadSettings();
  Map<String, String> _sizeLabels = {};

  static const _refDurationMs = 240000;

  // Per-quality size labels are stable for the session; cache them so opening
  // the sheet doesn't re-fire one estimateTrackFileSize RPC per quality option.
  static Map<String, String>? _cachedSizes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await sl<SettingsCache>().getDownloadSettings();
    Map<String, String> sizes = _cachedSizes ?? {};
    if (_cachedSizes == null) {
      sizes = <String, String>{};
      _cachedSizes = sizes;
      for (final q in DownloadSettings.audioQualityOptions) {
        try {
          final raw = await sl<BackendService>().estimateTrackFileSize(_refDurationMs, q);
          final parsed = jsonDecode(raw) as Map?;
          final bytes = (parsed?['size_bytes'] as num?)?.toInt() ?? 0;
          sizes[q] = formatBytes(bytes);
        } catch (_) {
          sizes[q] = '';
        }
      }
    }
    if (mounted) setState(() { _settings = s; _sizeLabels = sizes; });
  }

  Future<void> _update(DownloadSettings s) async {
    setState(() => _settings = s);
    await sl<SettingsCache>().saveDownloadSettings(s);
    // Apply quality/video/lyrics choices to live playback (global state) so they
    // take effect on the next resolved stream. Guarded so DSL/AAR absence doesn't
    // crash the settings sheet on platforms without a player.
    try {
      sl<PlayerCubit>().applyDownloadSettings(
        audioQuality: s.audioQuality,
        videoQuality: s.videoQuality,
        videoEnabled: s.videoEnabled,
        lyricsEnabled: s.lyricsEnabled,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final loc = AppLocalizations.of(context);
    return GlassContainer(
      borderRadius: 16, borderColor: widget.onBg.withValues(alpha: 0.08),
      bgColor: widget.onBg.withValues(alpha: 0.03),
      margin: EdgeInsets.symmetric(horizontal: r.spacingM),
      padding: EdgeInsets.all(r.spacingM),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(loc.setup.downloadSettings,
          style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w600, color: widget.onBg)),
        SizedBox(height: r.spacingM),
        _qualitySelector(loc, r, loc.setup.audioQuality, DownloadSettings.audioQualityOptions,
          _settings.audioQuality, (v) => _update(_settings.copyWith(audioQuality: v))),
        SizedBox(height: r.spacingXS),
        Row(children: [
          Icon(Icons.info_outline, size: r.footerSize - 1, color: widget.onBg.withValues(alpha: 0.35)),
          SizedBox(width: 4),
          Expanded(child: Text(
            '${loc.setup.flac} ~${_sizeLabels['flac'] ?? '?'}  |  ${loc.setup.low} ~${_sizeLabels['low'] ?? '?'}',
            style: TextStyle(fontSize: r.footerSize - 2, color: widget.onBg.withValues(alpha: 0.35)))),
        ]),
        SizedBox(height: r.spacingM),
        _toggleRow(loc, r, loc.setup.quickDownloadLabel, _settings.quickDownload,
          (v) => _update(_settings.copyWith(quickDownload: v))),
        SizedBox(height: r.spacingM),
        _toggleRow(loc, r, loc.setup.videoDownload, _settings.videoEnabled,
          (v) => _update(_settings.copyWith(videoEnabled: v))),
        if (_settings.videoEnabled) ...[
          SizedBox(height: r.spacingS),
          _qualitySelector(loc, r, loc.setup.videoQuality, DownloadSettings.videoQualityOptions,
            _settings.videoQuality, (v) => _update(_settings.copyWith(videoQuality: v)), keyPrefix: 'vq'),
        ],
        SizedBox(height: r.spacingM),
        _toggleRow(loc, r, loc.setup.lyricsDownload, _settings.lyricsEnabled,
          (v) => _update(_settings.copyWith(lyricsEnabled: v))),
        if (_settings.lyricsEnabled) ...[
          SizedBox(height: r.spacingS),
          _qualitySelector(loc, r, loc.setup.lyricsSource, DownloadSettings.lyricsSourceOptions,
            _settings.lyricsSource, (v) => _update(_settings.copyWith(lyricsSource: v)), keyPrefix: 'ls'),
          SizedBox(height: r.spacingXS),
          Row(children: [
            Icon(Icons.info_outline, size: r.footerSize - 1, color: widget.onBg.withValues(alpha: 0.35)),
            SizedBox(width: 4),
            Expanded(child: Text(
              loc.setup.preferredLyricsSource,
              style: TextStyle(fontSize: r.footerSize - 2, color: widget.onBg.withValues(alpha: 0.35)))),
          ]),
        ],
        SizedBox(height: r.spacingM),
        _cacheTtlSlider(r),
      ]),
    );
  }

  Widget _toggleRow(AppLocalizations loc, Responsive r, String label, bool value, ValueChanged<bool> onChanged) {
    return Row(children: [
      Expanded(child: Text(label, style: TextStyle(fontSize: r.subtitleSize - 1, color: widget.onBg))),
      Switch(value: value, onChanged: onChanged,
        activeTrackColor: widget.glowColor.withValues(alpha: 0.3),
        activeThumbColor: widget.glowColor),
    ]);
  }

  Widget _qualitySelector(AppLocalizations loc, Responsive r, String label, List<String> options,
    String current, ValueChanged<String> onChanged, {String keyPrefix = 'aq'}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: r.footerSize, color: widget.onBg.withValues(alpha: 0.6))),
      SizedBox(height: r.spacingXS),
      // ignore: deprecated_member_use
      DropdownButtonFormField<String>(
        key: ValueKey('${keyPrefix}_$current'),
        initialValue: current,
        dropdownColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
        items: options.map((q) {
          final sizeStr = _sizeLabels[q] ?? '';
          final labelStr = _qualityLabel(loc, q);
          return DropdownMenuItem(value: q, child: Text(
            sizeStr.isNotEmpty ? '$labelStr (~$sizeStr)' : labelStr,
            style: TextStyle(fontSize: r.subtitleSize - 1, color: widget.onBg),
          ));
        }).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
        decoration: InputDecoration(
          isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: r.spacingS, vertical: r.spacingXS),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: widget.onBg.withValues(alpha: 0.15))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: widget.onBg.withValues(alpha: 0.15))),
        ),
      ),
    ]);
  }

  Widget _cacheTtlSlider(Responsive r) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        'Cache refresh: ${_settings.localFilesTtlSeconds}s',
        style: TextStyle(fontSize: r.footerSize, color: widget.onBg.withValues(alpha: 0.6)),
      ),
      Row(children: [
        Text('5s', style: TextStyle(fontSize: r.footerSize - 3, color: widget.onBg.withValues(alpha: 0.3))),
        Expanded(
          child: Slider(
            value: _settings.localFilesTtlSeconds.toDouble(),
            min: 5,
            max: 120,
            divisions: 23,
            activeColor: widget.glowColor,
            inactiveColor: widget.onBg.withValues(alpha: 0.1),
            onChanged: (v) => _update(_settings.copyWith(localFilesTtlSeconds: v.round())),
          ),
        ),
        Text('120s', style: TextStyle(fontSize: r.footerSize - 3, color: widget.onBg.withValues(alpha: 0.3))),
      ]),
    ]);
  }

  String _qualityLabel(AppLocalizations loc, String q) {
    switch (q) {
      case 'flac': return loc.setup.flac;
      case 'hifi': return loc.setup.hifi;
      case 'high': return loc.setup.high;
      case 'medium': return loc.setup.medium;
      case 'low': return loc.setup.low;
      default: return q;
    }
  }
}


