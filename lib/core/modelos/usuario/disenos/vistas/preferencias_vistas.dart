// ─────────────────────────────────────────────────────────────
// preferencias_vistas.dart — El diseño propio de cada vista de la app.
//
// Es un mapa vista → diseño, y sólo guarda las vistas que el usuario TOCÓ: la
// que no está hereda todo del estilo global. Guardar solo lo tocado es lo que
// hace que la app se vea igual que siempre para quien no entra a Ajustes, y
// que agregar una vista nueva en el futuro no obligue a migrar nada.
//
// Se conecta con: vista_app.dart (las vistas) + diseno_vista.dart (el diseño
// de cada una) + preferencias_vistas_json.dart (guardar/leer) +
// apariencia_vistas_helper.dart (leer y escribir desde toda la app).
// Parte del flujo: arranque (leer) y Ajustes → Apariencia → Vistas (guardar).
// ─────────────────────────────────────────────────────────────

import 'diseno_vista.dart';
import 'vista_app.dart';

/// Diseño propio de cada vista de la app.
class PreferenciasVistas {
  /// Solo las vistas personalizadas: la que no está hereda todo.
  final Map<VistaApp, DisenoVista> vistas;

  const PreferenciasVistas({this.vistas = const {}});

  /// Ninguna vista personalizada: la app se ve como el estilo global.
  static const deFabrica = PreferenciasVistas();

  /// Diseño de [vista] (heredado si el usuario no la tocó).
  DisenoVista para(VistaApp vista) => vistas[vista] ?? DisenoVista.hereda;

  /// ¿El usuario no tocó ninguna vista? Es el estado de fábrica.
  bool get esDeFabrica => vistas.isEmpty;

  /// Cuántas vistas quedaron personalizadas (para el resumen de Ajustes).
  int get cantidadPersonalizadas => vistas.length;

  /// Las vistas personalizadas, en el orden del enum (el del menú).
  List<VistaApp> get personalizadas =>
      VistaApp.values.where(vistas.containsKey).toList(growable: false);

  /// Guarda el diseño de una vista.
  ///
  /// Un diseño que no toca nada se SACA del mapa en vez de guardarse vacío:
  /// así "Restablecer" no deja entradas fantasma que después hagan creer que
  /// la vista está personalizada.
  PreferenciasVistas conVista(VistaApp vista, DisenoVista diseno) {
    final nuevo = Map<VistaApp, DisenoVista>.of(vistas);
    if (diseno.esHereda) {
      nuevo.remove(vista);
    } else {
      nuevo[vista] = diseno;
    }
    return PreferenciasVistas(vistas: Map.unmodifiable(nuevo));
  }

  /// Vuelve [vista] a heredar todo.
  PreferenciasVistas restablecer(VistaApp vista) =>
      conVista(vista, DisenoVista.hereda);

  /// Vuelve TODAS las vistas a heredar.
  PreferenciasVistas restablecerTodo() => deFabrica;
}
