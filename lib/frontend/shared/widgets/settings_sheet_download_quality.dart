// Parte del split de settings_sheet_new.dart — _DownloadQualityCard.
// Extraído del archivo original (ver git log). No editar a mano.
part of 'settings_sheet_new.dart';

class _DownloadQualityCard extends StatefulWidget {
  final Color glowColor;
  const _DownloadQualityCard({required this.glowColor});

  @override
  State<_DownloadQualityCard> createState() => _DownloadQualityCardState();
}

class _DownloadQualityCardState extends State<_DownloadQualityCard> {
  DownloadSettings _settings = const DownloadSettings();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await sl<SettingsCache>().getDownloadSettings();
    if (mounted)
      setState(() {
        _settings = s;
        _loaded = true;
      });
  }

  Future<void> _update(DownloadSettings s) async {
    setState(() => _settings = s);
    await sl<SettingsCache>().saveDownloadSettings(s);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = AppColors.onSurface(isDark);
    final loc = AppLocalizations.of(context);
    if (!_loaded) return SizedBox.shrink();

    return GlassContainer(
      borderRadius: 16,
      borderColor: onBg.withValues(alpha: 0.08),
      bgColor: onBg.withValues(alpha: 0.03),
      padding: EdgeInsets.all(r.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _downloadHeaderRow(
            Icons.music_note_rounded,
            loc.setup.audioQuality,
            onBg,
            r,
            widget.glowColor,
          ),
          SizedBox(height: r.spacingXS),
          _downloadDropdownRow(
            context,
            icon: Icons.audiotrack_rounded,
            hint: _downloadQualityLabel(_settings.audioQuality, loc),
            options: const ['flac', 'hifi', 'high', 'medium', 'low'],
            labelFor: (q) => _downloadQualityLabel(q, loc),
            current: _settings.audioQuality,
            onChanged: (v) => _update(_settings.copyWith(audioQuality: v)),
            glowColor: widget.glowColor,
            onBg: onBg,
          ),
          SizedBox(height: r.spacingM),
          // ── Video toggle + quality dropdown ──
          _downloadSwitchRow(
            context,
            icon: Icons.videocam_rounded,
            label: loc.setup.videoDownload,
            value: _settings.videoEnabled,
            onChanged: (v) => _update(_settings.copyWith(videoEnabled: v)),
            glowColor: widget.glowColor,
            onBg: onBg,
          ),
          if (_settings.videoEnabled) ...[
            SizedBox(height: r.spacingXS),
            _downloadDropdownRow(
              context,
              icon: Icons.high_quality_rounded,
              hint: _downloadVideoLabel(_settings.videoQuality),
              options: const ['720p', '1080p', '480p'],
              labelFor: _downloadVideoLabel,
              current: _settings.videoQuality,
              onChanged: (v) => _update(_settings.copyWith(videoQuality: v)),
              glowColor: widget.glowColor,
              onBg: onBg,
            ),
          ],
          SizedBox(height: r.spacingM),
          // ── Lyrics toggle + source dropdown ──
          _downloadSwitchRow(
            context,
            icon: Icons.lyrics_rounded,
            label: loc.setup.lyricsDownload,
            value: _settings.lyricsEnabled,
            onChanged: (v) => _update(_settings.copyWith(lyricsEnabled: v)),
            glowColor: widget.glowColor,
            onBg: onBg,
          ),
          if (_settings.lyricsEnabled) ...[
            SizedBox(height: r.spacingXS),
            _downloadDropdownRow(
              context,
              icon: Icons.format_quote_rounded,
              hint: _downloadLyricsLabel(_settings.lyricsSource),
              options: const ['lrclib', 'genius', 'musixmatch'],
              labelFor: _downloadLyricsLabel,
              current: _settings.lyricsSource,
              onChanged: (v) => _update(_settings.copyWith(lyricsSource: v)),
              glowColor: widget.glowColor,
              onBg: onBg,
            ),
          ],
        ],
      ),
    );
  }
}
