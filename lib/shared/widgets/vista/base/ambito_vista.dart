// ─────────────────────────────────────────────────────────────
// ambito_vista.dart — El "ámbito" de una vista: el diseño que le toca, puesto
// en el árbol para que CUALQUIER pieza de adentro lo lea sin recibirlo por
// parámetro (un Slider, una card, una grilla de terceros).
//
// Por qué existe: la personalización por vista no puede depender de que cada
// widget se acuerde de preguntar de qué vista viene. Con el ámbito, una card
// escribe `AparienciaEspacios.radioCards(context)` y ya obedece a la vista en
// la que está — sin saber que existen las vistas.
//
// Guarda las DOS caras del diseño a propósito:
//   · [declarado] — lo que la vista pidió (vacío = no toca). Es lo que hay que
//     mirar para saber si la vista eligió algo propio.
//   · [resuelto]  — lo que hay que pintar, ya con la cascada aplicada.
// Si sólo se guardara el resuelto no se podría distinguir "heredó el radio
// global" de "eligió justo ese radio", y un control de Ajustes no sabría si
// mostrar el valor como propio o como heredado.
//
// No dibuja nada: lo monta DisenoDeVista, que es quien resuelve la cascada.
//
// Se conecta con: diseno_de_vista.dart (quien lo monta) + apariencia_vistas_
// helper.dart (la cascada) + apariencia_espacios_helper.dart (quien lo lee).
// Parte del flujo: presentación (personalización por vista).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../../core/modelos/usuario/disenos/vistas/diseno_vista.dart';
import '../../../../core/modelos/usuario/disenos/vistas/vista_app.dart';
import '../../../utilidades/formato/apariencia/vistas/apariencia_vistas_helper.dart';

/// El diseño de la vista que envuelve al widget. [of] devuelve null cuando no
/// hay ninguna: ahí manda el estilo global y nada más.
class AmbitoVista extends InheritedWidget {
  /// Qué vista es (lo lee el tutorial y el diagnóstico).
  final VistaApp vista;

  /// Lo que la vista pidió (vacío = hereda).
  final DisenoVista declarado;

  /// Lo que hay que pintar, ya resuelto por la cascada.
  final DisenoResuelto resuelto;

  const AmbitoVista({
    super.key,
    required this.vista,
    required this.declarado,
    required this.resuelto,
    required super.child,
  });

  /// El ámbito más cercano, o null si no hay ninguno.
  static AmbitoVista? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AmbitoVista>();

  /// Radio de cards que pide la vista (null = el global).
  static double? radioDe(BuildContext context) =>
      of(context)?.declarado.radioTarjeta;

  /// Densidad de espacios de la vista (1 = la del estilo global).
  static double densidadDe(BuildContext context) =>
      of(context)?.resuelto.densidad ?? 1;

  /// ¿La vista eligió su propio ancho de grilla? (0 = automático).
  static int columnasDe(BuildContext context) =>
      of(context)?.resuelto.columnasMax ?? 0;

  /// La paleta del cofre que el usuario le puso a esta vista (vacía = ninguna).
  /// Es lo que tiñe sus cards.
  static List<Color> paletaDe(BuildContext context) =>
      of(context)?.resuelto.paleta ?? const [];

  @override
  bool updateShouldNotify(AmbitoVista old) =>
      old.vista != vista ||
      old.declarado != declarado ||
      // La paleta sale del id, así que comparar el id alcanza y es exacto.
      old.resuelto.disenoId != resuelto.disenoId ||
      old.resuelto.radioTarjeta != resuelto.radioTarjeta ||
      old.resuelto.densidad != resuelto.densidad ||
      old.resuelto.tipografiaId != resuelto.tipografiaId ||
      old.resuelto.columnasMax != resuelto.columnasMax;
}
