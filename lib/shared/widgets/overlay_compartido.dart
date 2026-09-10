// ─────────────────────────────────────────────────────────────
// overlay_compartido.dart — Overlay tipo TikTok "te compartieron":
// se muestra al abrir la app desde un deep link (WhatsApp, etc.)
// con la portada, nombre y botones de reproducir / omitir.
// Se conecta con: servicio_deep_link (datos del link) + ImagenPortada
// + ItemFeed + Responsive + ColoresApp.
// Parte del flujo: arranque / llegada de deep links (overlay global).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../core/modelos/item_feed.dart';
import '../tema/colores_app.dart';
import '../utilidades/responsive.dart';
import 'imagen_portada.dart';

/// Overlay "compartido contigo" para aperturas por deep link.
class OverlayCompartido extends StatefulWidget {
  final String? type;
  final String? id;
  final String? query;
  final VoidCallback onDismiss;
  final VoidCallback onPlay;

  const OverlayCompartido({
    super.key,
    this.type,
    this.id,
    this.query,
    required this.onDismiss,
    required this.onPlay,
  });

  @override
  State<OverlayCompartido> createState() => _OverlayCompartidoState();
}

class _OverlayCompartidoState extends State<OverlayCompartido>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  ItemFeed? _foundItem;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.ease);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
    _resolverItem();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  /// Usa el query como nombre del ítem para la vista del overlay.
  Future<void> _resolverItem() async {
    setState(() {
      _foundItem = ItemFeed(
        id: widget.id ?? '',
        type: widget.type ?? 'track',
        name: widget.query ?? 'Canción compartida',
        source: '',
      );
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final brillo = ColoresApp.primario;

    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, _) {
        return FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Scaffold(
              backgroundColor: Colors.black.withValues(alpha: 0.95),
              body: SafeArea(
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    Text(
                      'Te compartieron',
                      style: TextStyle(
                        fontSize: r.subtitleSize - 2,
                        color: Colors.white.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 2,
                      ),
                    ),
                    SizedBox(height: r.spacingL),
                    // Portada con glow (o spinner mientras carga).
                    if (_cargando)
                      SizedBox(
                        width: 180,
                        height: 180,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: brillo,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: brillo.withValues(alpha: 0.3),
                              blurRadius: 40,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: _foundItem?.coverUrl != null
                              ? ImagenPortada(coverUrl: _foundItem!.coverUrl)
                              : Container(
                                  color: brillo.withValues(alpha: 0.15),
                                  child: Icon(
                                    _iconoTipo(),
                                    size: 64,
                                    color: brillo,
                                  ),
                                ),
                        ),
                      ),
                    SizedBox(height: r.spacingL),
                    Text(
                      _foundItem?.name ?? 'Buscando...',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: r.titleSize + 2,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    if (_foundItem?.artists != null &&
                        _foundItem!.artists!.isNotEmpty) ...[
                      SizedBox(height: r.spacingXS),
                      Text(
                        _foundItem!.artists!,
                        style: TextStyle(
                          fontSize: r.subtitleSize,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                    SizedBox(height: r.spacingS),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: brillo.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: brillo.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _etiquetaTipo(),
                        style: TextStyle(
                          fontSize: r.footerSize - 1,
                          color: brillo,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(flex: 2),
                    // Botón reproducir.
                    GestureDetector(
                      onTap: widget.onPlay,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: brillo,
                          boxShadow: [
                            BoxShadow(
                              color: brillo.withValues(alpha: 0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          size: 36,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(height: r.spacingL),
                    // Botón omitir.
                    GestureDetector(
                      onTap: widget.onDismiss,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Text(
                          'Omitir',
                          style: TextStyle(
                            fontSize: r.subtitleSize - 1,
                            color: Colors.white.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: r.spacingXL),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _iconoTipo() {
    switch (widget.type) {
      case 'album':
        return Icons.album_rounded;
      case 'artist':
        return Icons.person_rounded;
      case 'playlist':
        return Icons.queue_music_rounded;
      default:
        return Icons.music_note_rounded;
    }
  }

  String _etiquetaTipo() {
    switch (widget.type) {
      case 'album':
        return 'Álbum';
      case 'artist':
        return 'Artista';
      case 'playlist':
        return 'Playlist';
      default:
        return 'Canción';
    }
  }
}