// Parte del split de settings_sheet_new.dart — _SongTintedBackground.
// Extraído del archivo original (ver git log). No editar a mano.
part of 'settings_sheet_new.dart';

class _SongTintedBackground extends StatefulWidget {
  final EstadoCola queue;
  final bool isDark;
  final Color defaultBg;
  final Widget child;

  const _SongTintedBackground({
    super.key,
    required this.queue,
    required this.isDark,
    required this.defaultBg,
    required this.child,
  });

  @override
  State<_SongTintedBackground> createState() => _SongTintedBackgroundState();
}

class _SongTintedBackgroundState extends State<_SongTintedBackground> {
  Color _bg = const Color(0xFF000000);
  String? _cover;
  bool _hasTrack = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant _SongTintedBackground old) {
    super.didUpdateWidget(old);
    if (old.queue != widget.queue) _refresh();
  }

  Future<void> _refresh() async {
    final track = widget.queue.actual;
    final hasTrack = track != null;
    String? cover;
    if (hasTrack) {
      try {
        cover = sl<CubitLikes>().caratulaLocalPara(track) ?? track.coverUrl;
      } catch (_) {
        cover = track.coverUrl;
      }
    }
    final bg =
        hasTrack
            ? (await _dominantFor(cover)) ?? widget.defaultBg
            : widget.defaultBg;
    if (!mounted) return;
    setState(() {
      _bg = bg;
      _cover = cover;
      _hasTrack = hasTrack;
    });
  }

  Future<Color?> _dominantFor(String? cover) async {
    if (cover == null || cover.isEmpty) return null;
    final palette = await paletaParaPortada(cover);
    if (palette == null) return null;
    // Dark theme keeps the surface dark-ish; light theme uses the cover's
    // dominant hue directly. Blend toward the default so it never shouts.
    final mix = widget.isDark ? 0.30 : 0.45;
    return Color.lerp(widget.defaultBg, palette.dominante, mix);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        color: _bg,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (_hasTrack && _cover != null && _cover!.isNotEmpty)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: sl<ValueNotifier<PerfilRendimiento>>().value.sigmaDesenfoque,
                  sigmaY: sl<ValueNotifier<PerfilRendimiento>>().value.sigmaDesenfoque,
                ),
                child: Transform.scale(
                  scale: 1.3,
                  child: imagenDesdeUrl(
                    _cover!,
                    ajuste: BoxFit.cover,
                    ancho: 512,
                    alto: double.infinity,
                  ),
                ),
              ),
            ),
          // Veil keeps content readable over the artwork.
          Positioned.fill(
            child: ColoredBox(
              color: _bg.withValues(alpha: widget.isDark ? 0.72 : 0.55),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

/// Opens the new tabbed settings sheet.
