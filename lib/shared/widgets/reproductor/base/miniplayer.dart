// ─────────────────────────────────────────────────────────────
// miniplayer.dart — Barra del miniplayer sobre el shell de Home:
// muestra el track actual (carátula + nombre + artista) con
// controles (shuffle/prev/play/next/repeat), barra de progreso
// animada y swipe horizontal para cambiar de canción. Tap abre el
// reproductor completo. El build y las piezas viven en parts
// (_build, _piezas, _animacion, _pintor, _progreso).
// Se conecta con: cubit_cola + cubit_reproductor + cubit_like.
// Parte del flujo: Home (miniplayer sobre el shell).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/cache/estado/estado_cola.dart';
import '../../../../core/cache/estado/estado_reproductor.dart';
import '../../../../core/modelos/feed/item_feed.dart';
import '../../../../core/modelos/usuario/disenos/base/catalogo_disenos_barra.dart';
import '../../../../core/modelos/usuario/preferencias/preferencias_apariencia.dart';
import '../../../../estado/cola/cubit_cola.dart';
import '../../../../estado/like/base/cubit_like.dart';
import '../../../../estado/reproductor/cubit_reproductor.dart';
import '../../../tema/colores_app.dart';
import '../../../utilidades/interaccion/haptico.dart';
import '../../../utilidades/plataforma/pantalla/efectos_app.dart';
import '../../../utilidades/plataforma/pantalla/escala_ui.dart';
import '../../../utilidades/plataforma/responsive.dart';
import '../../tarjetas/portada/imagen_portada.dart';
import '../../../utilidades/formato/apariencia/barras/apariencia_barras_helper.dart';
import '../../../utilidades/formato/apariencia/barras/miniplayer_geometria.dart';
import '../../../utilidades/formato/apariencia/base/apariencia_disenos_helper.dart';
import '../../../utilidades/formato/apariencia/visual/apariencia_paleta_helper.dart';
import '../../../utilidades/formato/apariencia/base/apariencia_helper.dart';
import '../../barras/barra_adornada.dart';

part '../visual/miniplayer_animacion.dart';
part 'miniplayer_build.dart';
part '../controles/miniplayer_controles.dart';
part '../visual/miniplayer_piezas.dart';
part '../visual/miniplayer_pintor.dart';
part '../controles/miniplayer_progreso.dart';
part 'miniplayer_barra.dart';

/// Miniplayer con el track actual y sus controles.
class Miniplayer extends StatefulWidget {
  /// Abre el reproductor completo; null = el ensamblador no lo cablea aún.
  final VoidCallback? onAbrirReproductor;

  const Miniplayer({super.key, this.onAbrirReproductor});

  @override
  State<Miniplayer> createState() => _MiniplayerState();
}

class _MiniplayerState extends State<Miniplayer> {
  void _abrirCompleto() {
    widget.onAbrirReproductor?.call();
  }

  @override
  Widget build(BuildContext context) => _buildMiniplayer(this, context);
}
