// ─────────────────────────────────────────────────────────────
// reproductor_pagina.dart — Página del reproductor completo
// (NowPlaying): portada/video visualizador con alternancia,
// metadata del track, seek bar, controles (like/shuffle/prev/play/
// next/repeat/letras), velocidad y swipe-down para cerrar. Sesión
// de video recordada por track; letras karaoke en modal.
// Parts: _estado, _video, _letras, _gestos, _fondo, _build.
// Se conecta con: cubit_cola + cubit_reproductor + cubit_like +
// backend Go (video visualizador) + l10n + shared.
// Parte del flujo: reproductor (ruta now_playing, diseño actual).
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/inyeccion.dart';
import '../../core/cache/estado_cola.dart';
import '../../core/cache/estado_reproductor.dart';
import '../../core/modelos/item_feed.dart';
import '../../core/modelos/perfil_rendimiento.dart';
import '../../core/plataforma/servicio_conectividad.dart';
import '../../estado/cubit_cola.dart';
import '../../estado/cubit_like.dart';
import '../../estado/cubit_reproductor.dart';
import '../../shared/tema/colores_app.dart';
import '../../shared/utilidades/responsive.dart';
import '../../shared/widgets/imagen_portada.dart';
import 'area_portada_video.dart';
import 'barra_seek_reproductor.dart';
import 'fila_controles_reproductor.dart';
import 'hoja_letras.dart';
import 'modal_cola.dart';
import 'selector_velocidad_reproductor.dart';
import 'textura_video_fondo.dart';

part 'reproductor_pagina_estado.dart';
part 'reproductor_pagina_video.dart';
part 'reproductor_pagina_letras.dart';
part 'reproductor_pagina_gestos.dart';
part 'reproductor_pagina_fondo.dart';
part 'reproductor_pagina_build.dart';
part 'reproductor_pagina_piezas.dart';
part 'reproductor_pagina_metadata.dart';

/// Remembers the cover/video choice of the last full-player session.
class _SesionVideo {
  static String? trackKey;
  static String? url;
  static bool habilitada = false;
}

/// Página del reproductor completo (NowPlaying).
class ReproductorPagina extends StatefulWidget {
  const ReproductorPagina({super.key});

  @override
  State<ReproductorPagina> createState() => _ReproductorPaginaState();
}

class _ReproductorPaginaState extends State<ReproductorPagina>
    with SingleTickerProviderStateMixin {
  // ── Video visualizador ────────────────────────────────────
  bool _mostrarVideo = false;
  bool _videoCargando = false;
  final Player _videoPlayer = Player();
  VideoController? _videoController;
  StreamSubscription<void>? _videoCompSub;
  bool _videoLoopArmado = false;
  bool _tieneVideo = false;
  String? _videoTrackId;
  ValueNotifier<String?>? _videoListoSrc;

  // ── Letras ────────────────────────────────────────────────
  bool _letrasCargando = false;

  // ── Estado de cola / sesión ───────────────────────────────
  String? _ultimaClaveCola;

  // ── Swipe-down para cerrar ────────────────────────────────
  final ValueNotifier<double> _desplazamiento = ValueNotifier(0);
  late final AnimationController _animArrastre;
  double _arrastreDesde = 0;
  double _arrastreHasta = 0;

  @override
  void initState() {
    super.initState();
    _videoController = VideoController(_videoPlayer);
    _animArrastre = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..addListener(() => _enTickArrastre(this));
    _escucharCambiosCola(this);
    _videoListoSrc = sl<CubitReproductor>().videoPrecargadoListo
      ..addListener(() => _enVideoListo(this));
    WidgetsBinding.instance.addPostFrameCallback((_) => _enVideoListo(this));
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _restaurarSesionVideo(this));
  }

  @override
  void dispose() {
    _videoListoSrc?.removeListener(() => _enVideoListo(this));
    _videoCompSub?.cancel();
    _videoPlayer.dispose();
    _animArrastre.dispose();
    _desplazamiento.dispose();
    super.dispose();
  }

  /// Repinta la página tras mutar campos desde los parts (video/letras).
  void repintar() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => _buildReproductor(this, context);
}