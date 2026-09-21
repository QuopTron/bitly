// ─────────────────────────────────────────────────────────────
// vista_reproductor.dart — PART de reproductor_pagina.dart: lo que reciben
// las TRES variantes del reproductor y el selector que elige una.
//
// Existe para que celular, PC y TV compartan el mismo punto de partida: el
// marco de la página (barra superior, fondo ambiental y estado) se arma UNA vez
// en reproductor_pagina_build, y cada variante solo decide CÓMO ordena el
// contenido. Así una diferencia de plataforma —el control de volumen, que solo
// va en PC y TV— se ve de un vistazo: vive en un archivo.
//
// Se conecta con: reproductor_pagina_build (lo usa) + vistas/reproductor_movil,
// vistas/reproductor_escritorio y vistas/reproductor_tv.
// Parte del flujo: reproductor (elección de variante).
// ─────────────────────────────────────────────────────────────

part of '../pagina/base/reproductor_pagina.dart';

/// Todo lo que necesita una variante para armar su cuerpo.
class _VistaReproductor {
  final _ReproductorPaginaState st;
  final BuildContext context;
  final Responsive r;
  final bool esOscuro;
  final ItemFeed track;
  final String? caratula;
  final EstadoCola cola;
  final EstadoAudioReproductor reproductor;
  final Color activo;

  const _VistaReproductor({
    required this.st,
    required this.context,
    required this.r,
    required this.esOscuro,
    required this.track,
    required this.caratula,
    required this.cola,
    required this.reproductor,
    required this.activo,
  });
}

/// Elige la variante del reproductor: TV → PC → celular.
///
/// La TV se pregunta PRIMERO porque una tele ancha también entra en el layout
/// de escritorio (ver deteccion_plataforma).
Widget _elegirCuerpoReproductor(_VistaReproductor v) {
  if (usarLayoutTv(v.context)) return _cuerpoReproductorTv(v);
  if (usarLayoutEscritorio(v.context)) return _cuerpoReproductorEscritorio(v);
  return _cuerpoReproductorMovil(v);
}
