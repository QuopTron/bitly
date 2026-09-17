// apariencia_helper.dart — Helper de las preferencias de DISEÑO: leerlas
// desde cualquier widget (grillas, cards, miniplayer) y cambiarlas desde
// Ajustes. Evita que cada archivo importe el notifier + la caché.
//
// Los valores salen de `ValueNotifier<PreferenciasApariencia>` (registrado
// en la inyección y cargado al arrancar), así tocar un control en Ajustes
// repinta la app entera sin reiniciar.

import 'package:flutter/material.dart';

import '../../../app/inyeccion.dart';
import '../../../core/cache/almacenes/cache_ajustes.dart';
import '../../../core/modelos/usuario/preferencias_apariencia.dart';

/// Acceso a las preferencias de diseño del usuario.
class AparienciaHelper {
  AparienciaHelper._();

  /// Preferencias actuales.
  static PreferenciasApariencia actual(BuildContext context) =>
      sl<ValueNotifier<PreferenciasApariencia>>().value;

  /// Notifier global (para escuchar cambios con ValueListenableBuilder).
  static ValueNotifier<PreferenciasApariencia> notifier() =>
      sl<ValueNotifier<PreferenciasApariencia>>();

  /// Separación horizontal entre cards, como multiplicador del diseño base.
  static double espacioX(BuildContext context) => actual(context).espacioX;

  /// Separación vertical entre cards.
  static double espacioY(BuildContext context) => actual(context).espacioY;

  /// Redondeo de las cards de grilla.
  static double radioCards(BuildContext context) => actual(context).radioCards;

  /// Borde elegido para el reproductor (navbar/miniplayer).
  static BordeMiniplayer borde(BuildContext context) =>
      actual(context).bordeMiniplayer;

  /// Opacidad y grosor del borde del reproductor según lo elegido. Con
  /// `sinBorde` devuelve grosor 0: la barra no dibuja contorno.
  static (double opacidad, double grosor) trazoBorde(BuildContext context) {
    switch (borde(context)) {
      case BordeMiniplayer.sinBorde:
        return (0, 0);
      case BordeMiniplayer.suave:
        return (0.10, 0.5);
      case BordeMiniplayer.marcado:
        return (0.22, 1.0);
    }
  }

  /// Guarda las preferencias nuevas (repinta y persiste).
  static void cambiar(BuildContext context, PreferenciasApariencia prefs) {
    notifier().value = prefs;
    sl<CacheAjustes>().guardarPreferenciasApariencia(prefs);
  }

  /// Cambia el borde del reproductor.
  static void cambiarBorde(BuildContext context, BordeMiniplayer borde) =>
      cambiar(context, actual(context).copiarCon(bordeMiniplayer: borde));

  /// Cambia la separación horizontal de las grillas.
  static void cambiarEspacioX(BuildContext context, double valor) =>
      cambiar(context, actual(context).copiarCon(espacioX: valor));

  /// Cambia la separación vertical de las grillas.
  static void cambiarEspacioY(BuildContext context, double valor) =>
      cambiar(context, actual(context).copiarCon(espacioY: valor));

  /// Cambia el redondeo de las cards.
  static void cambiarRadio(BuildContext context, double valor) =>
      cambiar(context, actual(context).copiarCon(radioCards: valor));

  /// Vuelve al diseño de fábrica.
  static void restablecer(BuildContext context) =>
      cambiar(context, PreferenciasApariencia.deFabrica);
}
