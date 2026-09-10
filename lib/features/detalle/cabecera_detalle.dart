// ─────────────────────────────────────────────────────────────
// cabecera_detalle.dart — Cabecera a pantalla completa para las
// páginas de detalle (álbum/playlist/artista): fondo con la
// carátula difuminada + gradiente oscuro, portada con glow,
// título/subtítulo/badge, acciones (BotónAccionVidrio) y el
// contenido debajo. Extrae el color dominante de la carátula.
// Parts: _color (dominante), _imagen (portada/blur), _fondo
// (capas de fondo + retroceso) y _contenido (ListView).
// Se conecta con: colores_app + responsive + perfil_rendimiento.
// Parte del flujo: Detalle (cabecera compartida).
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app/inyeccion.dart';
import '../../core/modelos/perfil_rendimiento.dart';
import '../../shared/utilidades/responsive.dart';

part 'cabecera_detalle_color.dart';
part 'cabecera_detalle_imagen.dart';
part 'cabecera_detalle_fondo.dart';
part 'cabecera_detalle_contenido.dart';

/// Cabecera de detalle: fondo blur + portada + acciones + contenido.
class CabeceraDetalle extends StatefulWidget {
  final String? coverUrl;
  final String titulo;
  final String subtitulo;
  final String? heroTag;
  final Widget? acciones;
  final List<Widget> children;
  final String? badge;
  final double? tamanoPortada;

  const CabeceraDetalle({
    super.key,
    this.coverUrl,
    required this.titulo,
    required this.subtitulo,
    this.heroTag,
    this.acciones,
    this.children = const [],
    this.badge,
    this.tamanoPortada,
  });

  @override
  State<CabeceraDetalle> createState() => _CabeceraDetalleState();
}

class _CabeceraDetalleState extends State<CabeceraDetalle>
    with SingleTickerProviderStateMixin {
  Color? _colorDominante;
  String? _ultimaUrlExtraida;
  late final AnimationController _animCtrl;
  late final Animation<double> _anim;

  /// Cache global: url → color dominante (evita re-extraer).
  static final Map<String, Color> _cacheColor = {};

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    _cargarColorCacheado();
  }

  @override
  void didUpdateWidget(covariant CabeceraDetalle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverUrl != widget.coverUrl) _cargarColorCacheado();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  /// Lee el color desde cache o lanza la extracción asíncrona.
  void _cargarColorCacheado() {
    final url = widget.coverUrl;
    if (url == null || url.isEmpty) return;
    _ultimaUrlExtraida = url;
    if (_cacheColor.containsKey(url)) {
      _colorDominante = _cacheColor[url];
      return;
    }
    _extraerColor();
  }

  Future<void> _extraerColor() async {
    final url = widget.coverUrl;
    if (url == null || url.isEmpty) return;
    try {
      final color = await _extraerColorDominante(
        providerPara(url, _esPortadaLocal(widget)),
      );
      if (mounted && color != null && _ultimaUrlExtraida == url) {
        _cacheColor[url] = color;
        while (_cacheColor.length > 100) {
          _cacheColor.remove(_cacheColor.keys.first);
        }
        setState(() => _colorDominante = color);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final anchoPantalla = MediaQuery.sizeOf(context).width;
    final tamanoPortada =
        widget.tamanoPortada ?? (anchoPantalla * 0.52).clamp(140.0, 240.0);
    final barraEstado = MediaQuery.paddingOf(context).top;
    final colorFondo =
        esOscuro ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5);
    final acento = _colorDominante ??
        (esOscuro ? const Color(0xFF1A1A2E) : const Color(0xFFE8E8E8));
    final efectosPesados =
        sl<ValueNotifier<PerfilRendimiento>>().value.efectosPesados;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final t = _anim.value;
        return Stack(
          children: [
            ..._capasFondo(this, t, acento, colorFondo, efectosPesados),
            _contenidoDetalle(this, t, acento, tamanoPortada, barraEstado),
            _botonRetroceso(context, barraEstado),
          ],
        );
      },
    );
  }
}