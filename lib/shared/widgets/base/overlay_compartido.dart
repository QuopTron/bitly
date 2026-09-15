// ─────────────────────────────────────────────────────────────
// overlay_compartido.dart — Overlay tipo TikTok "te compartieron":
// se muestra al abrir la app desde un deep link (WhatsApp, etc.)
// con la portada, nombre y botones de reproducir / omitir.
// Se conecta con: servicio_deep_link (datos del link) + ImagenPortada
// + ItemFeed + Responsive + ColoresApp.
// Parte del flujo: arranque / llegada de deep links (overlay global).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../core/modelos/feed/item_feed.dart';
import 'overlay_compartido_contenido.dart';

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
                child: OverlayCompartidoContenido(
                  item: _foundItem,
                  cargando: _cargando,
                  type: widget.type ?? 'track',
                  onPlay: widget.onPlay,
                  onDismiss: widget.onDismiss,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}