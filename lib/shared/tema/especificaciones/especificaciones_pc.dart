// ─────────────────────────────────────────────────────────────
// especificaciones_pc.dart — Medidas para PC.
//
// En una PC el apuntador es el mouse y la pantalla está a un brazo:
// los controles pueden ser un poco MÁS CHICOS que en el celular (no
// hace falta el tamaño de dedo) y las esquinas un poco menos
// redondeadas, que en un monitor se ven mejor. No se marca el foco
// porque el mouse ya dice dónde estás.
//
// Se conecta con: especificaciones_plataforma.dart (las elige).
// Parte del flujo: presentación (medidas de PC).
// ─────────────────────────────────────────────────────────────

import 'especificaciones_plataforma.dart';

/// Medidas de PC: mouse, pantalla a un brazo.
const especificacionesPc = EspecificacionesPlataforma(
  altoBoton: 34,
  altoBotonGrande: 42,
  radioBoton: 18,
  iconoBoton: 17,
  // Un punto más grande que en celular: en un monitor el texto se lee a más
  // distancia, pero sin llegar a los 17 de la tele.
  textoBoton: 13,
  altoBotonIcono: 40,
  iconoAccion: 19,
  radioTarjeta: 12,
  altoTile: 48,
  iconoTile: 20,
  altoFila: 56,
  altoIndicador: 22,
  radioEsqueleto: 10,
  // Un poco menos redondeada que en celular: en un monitor se ve mejor.
  radioHoja: 24,
  textoEtiqueta: 12,
  focoVisible: false,
  grosorFoco: 0,
);
