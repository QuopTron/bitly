// ─────────────────────────────────────────────────────────────
// especificaciones_celular.dart — Medidas para CELULAR.
//
// Es la referencia de todas las demás: el tamaño de dedo (un botón
// de ~38 de alto, un tile de ~54) que la app ya venía usando. El foco
// no se marca porque acá se toca directo con el dedo.
//
// Se conecta con: especificaciones_plataforma.dart (las elige).
// Parte del flujo: presentación (medidas de celular).
// ─────────────────────────────────────────────────────────────

import 'especificaciones_plataforma.dart';

/// Medidas de celular: táctil, con el dedo.
const especificacionesCelular = EspecificacionesPlataforma(
  altoBoton: 38,
  altoBotonGrande: 46,
  radioBoton: 22,
  iconoBoton: 18,
  textoBoton: 12,
  altoBotonIcono: 44,
  iconoAccion: 20,
  radioTarjeta: 14,
  altoTile: 54,
  iconoTile: 22,
  altoFila: 64,
  altoIndicador: 24,
  radioEsqueleto: 12,
  radioHoja: 28,
  textoEtiqueta: 11,
  focoVisible: false,
  grosorFoco: 0,
);
