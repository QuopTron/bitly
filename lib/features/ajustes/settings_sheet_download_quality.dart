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
  AjustesDescarga _settings = const AjustesDescarga();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await sl<CacheAjustes>().getAjustesDescarga();
    if (mounted)
      setState(() {
        _settings = s;
        _loaded = true;
      });
  }

  Future<void> _update(AjustesDescarga s) async {
    setState(() => _settings = s);
    await sl<CacheAjustes>().guardarAjustesDescarga(s);
    try {
      sl<CubitReproductor>().aplicarAjustesDescarga(
        calidadAudio: s.calidadAudio,
        calidadVideo: s.calidadVideo,
        videoHabilitado: s.videoHabilitado,
        letrasHabilitadas: s.letrasHabilitadas,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(isDark);
    final loc = AppLocalizations.of(context);
    if (!_loaded) return SizedBox.shrink();

    return ContenedorVidrio(
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
            hint: _downloadQualityLabel(_settings.calidadAudio, loc),
            options: const ['flac', 'hifi', 'high', 'medium', 'low'],
            labelFor: (q) => _downloadQualityLabel(q, loc),
            current: _settings.calidadAudio,
            onChanged: (v) => _update(_settings.copiarCon(calidadAudio: v)),
            glowColor: widget.glowColor,
            onBg: onBg,
          ),
          SizedBox(height: r.spacingM),
          // ── Video toggle + quality dropdown ──
          _downloadSwitchRow(
            context,
            icon: Icons.videocam_rounded,
            label: loc.setup.videoDownload,
            value: _settings.videoHabilitado,
            onChanged: (v) => _update(_settings.copiarCon(videoHabilitado: v)),
            glowColor: widget.glowColor,
            onBg: onBg,
          ),
          if (_settings.videoHabilitado) ...[
            SizedBox(height: r.spacingXS),
            _downloadDropdownRow(
              context,
              icon: Icons.high_quality_rounded,
              hint: _downloadVideoLabel(_settings.calidadVideo),
              options: const ['720p', '1080p', '480p'],
              labelFor: _downloadVideoLabel,
              current: _settings.calidadVideo,
              onChanged: (v) => _update(_settings.copiarCon(calidadVideo: v)),
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
            value: _settings.letrasHabilitadas,
            onChanged: (v) => _update(_settings.copiarCon(letrasHabilitadas: v)),
            glowColor: widget.glowColor,
            onBg: onBg,
          ),
          if (_settings.letrasHabilitadas) ...[
            SizedBox(height: r.spacingXS),
            _downloadDropdownRow(
              context,
              icon: Icons.format_quote_rounded,
              hint: _downloadLyricsLabel(_settings.fuenteLetras),
              options: const ['lrclib', 'genius', 'musixmatch'],
              labelFor: _downloadLyricsLabel,
              current: _settings.fuenteLetras,
              onChanged: (v) => _update(_settings.copiarCon(fuenteLetras: v)),
              glowColor: widget.glowColor,
              onBg: onBg,
            ),
          ],
        ],
      ),
    );
  }
}
