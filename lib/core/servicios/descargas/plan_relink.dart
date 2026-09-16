// ─────────────────────────────────────────────────────────────
// plan_relink.dart — Lógica PURA (sin disco) de re-vinculación de
// descargas: cuando el usuario MUEVE o cambia la carpeta de
// descargas, las rutas guardadas en la BD apuntan a la ubicación
// vieja y la biblioteca daría por perdidos archivos que sí existen.
// Acá se decide, comparando nombres, qué fila pasa a qué archivo
// nuevo. Quien aplica el plan (y toca el disco) es
// cache_descargas_lotes.dart.
// Se conecta con: cache_descargas_lotes.dart (usa este plan).
// Parte del flujo: descargas (Ajustes → carpeta de descargas).
// ─────────────────────────────────────────────────────────────

import 'rutas_archivo.dart';

// El índice de la carpeta nueva y los helpers de rutas viven acá para que
// quien solo necesite reubicar archivos importe un único archivo.
export 'rutas_archivo.dart';

/// Una fila del historial de descargas (solo lo que hace falta para reubicar).
class EntradaHistorialDescarga {
  final String id;
  final String ruta;
  final String caratula;

  const EntradaHistorialDescarga({
    required this.id,
    required this.ruta,
    this.caratula = '',
  });
}

/// Qué filas del historial tienen que apuntar a qué archivo nuevo.
class PlanRelink {
  /// id del historial → ruta nueva del audio.
  final Map<String, String> rutas;

  /// id del historial → ruta nueva de la carátula.
  final Map<String, String> caratulas;

  const PlanRelink({this.rutas = const {}, this.caratulas = const {}});

  int get total => rutas.length;
  bool get vacio => rutas.isEmpty && caratulas.isEmpty;
}

/// Decide el plan de re-vinculación. [existe] responde si una ruta sigue en pie
/// (se inyecta para poder testear sin tocar disco).
///
/// Regla de oro: solo se toca una fila cuando la ruta vieja YA no existe en
/// disco. Así un archivo que sigue en su lugar nunca cambia de ruta, y una
/// biblioteca sana no se reescribe al abrir Ajustes.
PlanRelink planificarRelink({
  required List<EntradaHistorialDescarga> entradas,
  required ArchivosEnCarpeta carpeta,
  required bool Function(String ruta) existe,
}) {
  final rutas = <String, String>{};
  final caratulas = <String, String>{};
  for (final entrada in entradas) {
    if (!existe(entrada.ruta)) {
      final nueva = carpeta.buscar(entrada.ruta, entrada.id);
      if (nueva.isNotEmpty) rutas[entrada.id] = nueva;
    }
    if (entrada.caratula.isEmpty || existe(entrada.caratula)) continue;
    final nuevaCaratula = carpeta.buscarCaratula(entrada.caratula, entrada.ruta);
    if (nuevaCaratula.isNotEmpty) caratulas[entrada.id] = nuevaCaratula;
  }
  return PlanRelink(rutas: rutas, caratulas: caratulas);
}
