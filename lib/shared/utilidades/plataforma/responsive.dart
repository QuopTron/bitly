// ─────────────────────────────────────────────────────────────
// responsive.dart — Utilidad de diseño responsive para la app:
// calcula escalas de tamaño a partir del lado más corto de la
// pantalla (base 400) y del APARATO (ver tema/especificaciones)
// para que textos, tarjetas y espaciados se vean bien en celular,
// tablet, PC y TV sin duplicar lógica.
//
// Por qué también por aparato: el ancho solo no alcanza. Una tele
// de 1080p entra como "escritorio" por tamaño, pero se mira a tres
// metros y necesita todo más grande; y una ventana de PC angosta no
// debe encogerse como un celular. Con el factor del aparato, TODO
// componente que use Responsive —que son todos los de la app— queda
// con su versión de TV, PC y celular sin copiar widgets.
//
// Se conecta con: todas las vistas (features/) y widgets (shared/) +
// especificaciones_plataforma.
// Parte del flujo: presentación (escalado UI global).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../tema/especificaciones/especificaciones_plataforma.dart';

/// Escalado responsive del lado más corto de la pantalla × el aparato.
class Responsive {
  final BuildContext context;
  late final double width;
  late final double height;

  /// Escala del aparato: se aplica a las medidas Y a sus topes.
  late final double factor;
  late final double scale;

  static const double _base = 400;

  Responsive(this.context) {
    // `sizeOf` en vez de `of`: solo se depende del tamaño, así un cambio de
    // teclado/insets/texto del sistema no reconstruye al consumidor.
    final size = MediaQuery.sizeOf(context);
    width = size.width;
    height = size.height;
    factor = EspecificacionesPlataforma.de(context).factorEscala;
    scale = (size.shortestSide / _base).clamp(0.6, 1.1) * factor;
  }

  /// Medida a escala: crece con la pantalla y con el aparato (TV más grande).
  /// Los topes también se escalan, si no el valor quedaría recortado al máximo
  /// de celular y en la tele no se notaría la diferencia.
  double val(double ideal, double min, double max) =>
      (ideal * scale).clamp(min * factor, max * factor);

  double get logoSize => val(90, 56, 150);
  double get circlePadding => val(18, 10, 30);
  double get titleSize => val(18, 14, 26);
  double get subtitleSize => val(12, 10, 16);
  double get footerSize => val(10, 9, 13);
  double get retryButtonHeight => val(36, 28, 44);
  double get continueButtonHeight => val(38, 32, 48);
  double get languageCardMargin => val(22, 14, 40);
  double get languageCardIconSize => val(28, 22, 38);
  double get languageCheckSize => val(11, 9, 14);

  /// Medida ya probada en celular que NO debe encogerse: el valor actual es
  /// el piso y sólo crece con la pantalla y con el aparato (hasta [hasta],
  /// 1.6× por defecto).
  ///
  /// Se usa en los textos, íconos y aros de las vistas: así el celular sigue
  /// viéndose igual que siempre y en la tele —donde un texto de 14 no se
  /// lee— crece solo.
  double sobre(double actual, [double? hasta]) =>
      val(actual, actual, hasta ?? actual * 1.6);

  double get spacingXS => val(4, 3, 6);
  double get spacingS => val(6, 4, 8);
  double get spacingM => val(10, 8, 16);
  double get spacingL => val(14, 10, 22);
  double get spacingXL => val(20, 16, 32);
  double get bottomPadding => val(20, 14, 34);
  double get topPadding => val(30, 20, 52);
}
