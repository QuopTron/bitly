// ─────────────────────────────────────────────────────────────
// apariencia_vistas_helper.dart — Leer, escribir y RESOLVER el diseño por
// vista (Ajustes → Apariencia → Vistas).
//
// Es el equivalente por vista de apariencia_helper.dart: una sola puerta para
// que ninguna vista importe el notifier + la caché por su cuenta.
//
// Lo importante es [de]: aplica la CASCADA. Un eje que la vista no declara cae
// al estilo GLOBAL del usuario y, si el global tampoco lo tocó, al de fábrica:
//
// La PALETA va aparte de la cascada porque NO tiene equivalente global: el
// cofre vive en las barras y la vista es la única que puede tener una. Se
// resuelve acá —y no dentro de cada tarjeta— por un motivo de peso: buscar en
// el catálogo por id en cada card sería repetir el trabajo en la lista más
// larga de la app.
//
//     vista  →  global  →  fábrica
//
// Así el que nunca entra a Ajustes ve la app de siempre, y el que personaliza
// una vista ve solo esa vista cambiar (las demás siguen heredando).
//
// Se conecta con: apariencia_helper.dart (el estilo global) +
// preferencias_vistas.dart (lo que declaró cada vista) + cache_ajustes
// (persistencia) + inyeccion (el notifier global).
// Parte del flujo: Ajustes → Apariencia → Vistas (y el pintado de la app).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../../../app/inyeccion/inyeccion.dart';
import '../../../../../core/cache/almacenes/sistema/cache_ajustes.dart';
import '../../../../../core/modelos/usuario/disenos/base/catalogo_disenos_barra_lista.dart';
import '../../../../../core/modelos/usuario/disenos/vistas/diseno_vista.dart';
import '../../../../../core/modelos/usuario/disenos/vistas/preferencias_vistas.dart';
import '../../../../../core/modelos/usuario/disenos/vistas/vista_app.dart';
import '../base/apariencia_helper.dart';

/// Acceso y resolución del diseño por vista.
class AparienciaVistas {
  AparienciaVistas._();

  /// Preferencias por vista actuales.
  static PreferenciasVistas actual() => notifier().value;

  /// Notifier global (para escuchar cambios con ValueListenableBuilder).
  static ValueNotifier<PreferenciasVistas> notifier() =>
      sl<ValueNotifier<PreferenciasVistas>>();

  /// Diseño que declaró [vista] (heredado si no la tocó).
  static DisenoVista declarado(VistaApp vista) => actual().para(vista);

  /// Guarda el diseño de una vista (repinta y persiste).
  static void poner(VistaApp vista, DisenoVista diseno) =>
      cambiar(actual().conVista(vista, diseno));

  /// Vuelve [vista] a heredar todo el estilo global.
  static void restablecer(VistaApp vista) =>
      cambiar(actual().restablecer(vista));

  /// Vuelve TODAS las vistas a heredar.
  static void restablecerTodo() => cambiar(PreferenciasVistas.deFabrica);

  /// Persiste y repinta. Es el ÚNICO camino de escritura, igual que
  /// [AparienciaHelper.cambiar] para la apariencia global.
  static void cambiar(PreferenciasVistas prefs) {
    notifier().value = prefs;
    sl<CacheAjustes>().guardarPreferenciasVistas(prefs);
  }

  /// Valores ya resueltos de [vista], aplicando la cascada
  /// vista → global → fábrica.
  static DisenoResuelto de(BuildContext context, VistaApp vista) {
    final d = declarado(vista);
    // El estilo global: es el mismo dato que ya mueve Ajustes → Apariencia.
    final global = AparienciaHelper.actual(context);
    return DisenoResuelto(
      disenoId: d.disenoId,
      // La paleta del cofre puesta en esta vista: es lo que tiñe sus cards.
      paleta: paletaDeDiseno(d.disenoId),
      // Sin tipografía propia, la GLOBAL del usuario: así elegir una fuente en
      // Ajustes la aplica a todas las vistas que no digan lo contrario, y cada
      // vista puede salirse de esa decisión si quiere.
      tipografiaId: d.tipografiaId.isNotEmpty
          ? d.tipografiaId
          : global.fuenteId,
      estiloCardId: d.estiloCardId,
      fondoId: d.fondoId,
      // Sin radio propio, el de las cards del usuario; sin densidad propia, 1.
      radioTarjeta: d.radioTarjeta ?? global.radioCards,
      densidad: d.densidad ?? 1,
      columnasMax: d.columnasMax,
    );
  }
}

/// Los colores del diseño del cofre con ese id, listos para pintar.
///
/// Devuelve vacío cuando el diseño no existe, no tiene paleta o el id está
/// vacío: en los tres casos la card se queda con el color del cover, que es lo
/// de siempre.
List<Color> paletaDeDiseno(String disenoId) {
  final diseno = disenoPorId(disenoId);
  return [for (final c in diseno?.paleta ?? const <int>[]) Color(c)];
}

/// Valores de diseño de una vista, ya resueltos (nada queda en null).
class DisenoResuelto {
  /// Conjunto puesto en la vista ('' = el global).
  final String disenoId;

  /// Colores de la paleta del cofre puesta en la vista. Vacía = la vista no
  /// eligió ninguna y las cards se tiñen con el color del cover.
  final List<Color> paleta;

  /// Familia tipográfica de la vista ('' = la global).
  final String tipografiaId;

  /// Estilo de las cards de la vista ('' = el global).
  final String estiloCardId;

  /// Fondo de la vista ('' = el global).
  final String fondoId;

  /// Redondeo de las cards ya resuelto.
  final double radioTarjeta;

  /// Multiplicador de espacios sobre el global (1 = igual).
  final double densidad;

  /// Nº máximo de columnas (0 = automático).
  final int columnasMax;

  const DisenoResuelto({
    required this.disenoId,
    this.paleta = const [],
    required this.tipografiaId,
    required this.estiloCardId,
    required this.fondoId,
    required this.radioTarjeta,
    required this.densidad,
    required this.columnasMax,
  });

  /// Una separación ya calculada por la vista (o por `Responsive`), pasada por
  /// la densidad de la vista. Es lo que convierte el control en algo visible
  /// sin que cada grilla tenga que multiplicar a mano.
  double espacio(double base) => base * densidad;

  /// ¿La vista eligió su propio conjunto de color/forma?
  bool get tieneConjunto => disenoId.isNotEmpty;

  /// ¿La vista tiene tipografía propia?
  bool get tieneTipografia => tipografiaId.isNotEmpty;
}
