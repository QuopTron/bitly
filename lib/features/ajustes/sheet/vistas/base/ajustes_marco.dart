// ─────────────────────────────────────────────────────────────
// ajustes_marco.dart — El armado de la hoja de Ajustes, partido por
// plataforma: elige entre el diseño de CELULAR, el de PC y el de TV.
//
// Por qué existe: la hoja tenía el cuerpo escrito de una sola forma, con
// ternarios adentro (`ancho ? Row : Column`) y sin variante propia para la
// tele. Acá el selector pregunta la plataforma UNA vez y cada variante dibuja
// su panel como corresponde (el celular, una hoja que sube desde abajo; la PC,
// el mismo panel con el navegador al costado y ancho máximo; la tele, un panel
// PLANO a todo el lienzo, sin vidrio ni sombra, como pide la regla de vistas).
//
// Orden del selector: TV PRIMERO. Una tele ancha también entra en el layout de
// escritorio, así que preguntar PC antes le daría a la tele el diseño de PC.
//
// [MarcoAjustes] es lo que las tres variantes comparten: los colores, las
// medidas (con su `Responsive`, que crece por aparato) y los tres slots que
// arma la library de Ajustes —la cabecera con el perfil, el navegador y el
// contenido—. Las variantes NO saben qué hay adentro de cada slot: sólo lo
// ubican. Es el mismo criterio que las páginas de Home/Búsqueda/Feed.
//
// Se conecta con: ajustes_movil.dart, ajustes_escritorio.dart, ajustes_tv.dart
// (las tres variantes) + settings_sheet_body_state.dart (lo monta).
// Parte del flujo: Ajustes (armado de la hoja).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../../../app/inyeccion/inyeccion.dart';
import '../../../../../core/modelos/usuario/perfil/perfil_rendimiento.dart';
import '../../../../../shared/tema/especificaciones/especificaciones_plataforma.dart';
import '../../../../../shared/utilidades/plataforma/deteccion_plataforma.dart';
import '../../../../../shared/utilidades/plataforma/responsive.dart';
import '../../../../../shared/widgets/vidrio/base/desenfoque_adaptativo.dart';
import '../escritorio/ajustes_escritorio.dart';
import '../movil/ajustes_movil.dart';
import '../tv/ajustes_tv.dart';

/// Las tres formas de armar la hoja de Ajustes.
enum VarianteAjustes { movil, escritorio, tv }

/// Selector ÚNICO de la variante: TV → escritorio → celular.
///
/// Ninguna variante (ni la hoja) vuelve a preguntar por plataforma: todas leen
/// esto, que es lo que exige la regla de vistas.
VarianteAjustes varianteAjustes(BuildContext context) {
  if (usarLayoutTv(context)) return VarianteAjustes.tv;
  if (usarLayoutEscritorio(context)) return VarianteAjustes.escritorio;
  return VarianteAjustes.movil;
}

/// Lo que las tres variantes comparten.
class MarcoAjustes {
  /// Medidas del aparato (escala con el mismo `Responsive` de la app).
  final Responsive r;

  final bool isDark;

  /// ¿Hay algo sonando? Con cover, el celular y la PC dejan pasar el tinte del
  /// fondo desenfocado; la tele va plana igual.
  final bool hasTrack;

  final Color bg;
  final Color onBg;

  /// Perfil compacto (usuario, me gusta, descargas y premium).
  final Widget cabecera;

  /// Pestañas burbuja (celular) o riel lateral (PC/TV).
  final Widget navegacion;

  /// El contenido de la pestaña abierta.
  final Widget contenido;

  const MarcoAjustes({
    required this.r,
    required this.isDark,
    required this.hasTrack,
    required this.bg,
    required this.onBg,
    required this.cabecera,
    required this.navegacion,
    required this.contenido,
  });
}

/// Arma la hoja con la variante que toca según la plataforma.
class MarcoAjustesVista extends StatelessWidget {
  final MarcoAjustes marco;

  const MarcoAjustesVista({super.key, required this.marco});

  @override
  Widget build(BuildContext context) => switch (varianteAjustes(context)) {
    VarianteAjustes.movil => AjustesMovil(marco: marco),
    VarianteAjustes.escritorio => AjustesEscritorio(marco: marco),
    VarianteAjustes.tv => AjustesTv(marco: marco),
  };
}

/// Deja pasar el tinte del cover por detrás de la hoja (sólo cuando hay algo
/// sonando). Lo usan el celular y la PC; la tele va plana a propósito: el
/// desenfoque se paga en cada frame y a metros no se ve.
Widget conVidrioAjustes(BuildContext context, MarcoAjustes marco, Widget hoja) {
  if (!marco.hasTrack) return hoja;
  final esp = EspecificacionesPlataforma.de(context);
  return ClipRRect(
    borderRadius: BorderRadius.vertical(top: Radius.circular(esp.radioHoja)),
    child: DesenfoqueAdaptativo(
      sigma: sl<ValueNotifier<PerfilRendimiento>>().value.sigmaDesenfoque,
      child: hoja,
    ),
  );
}

/// Key del tirador de la hoja. La usan los tests para fijar quién lo muestra
/// (celular y PC sí; la tele no, porque ahí no hay arrastre).
const Key claveTiradorAjustes = Key('bitly-ajustes-tirador');

/// El tirador de la hoja: dice "esto se puede arrastrar para cerrar". La tele
/// no lo usa (ahí no hay arrastre: se navega con el control).
Widget tiradorAjustes(MarcoAjustes marco) {
  final r = marco.r;
  final alto = r.spacingXS;
  return Container(
    key: claveTiradorAjustes,
    width: r.sobre(40, 64),
    height: alto,
    decoration: BoxDecoration(
      color: marco.onBg.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(alto / 2),
    ),
  );
}
