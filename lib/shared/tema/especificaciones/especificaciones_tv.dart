// ─────────────────────────────────────────────────────────────
// especificaciones_tv.dart — Medidas para TV.
//
// Acá todo es MÁS GRANDE y con más aire: la tele se mira a tres
// metros y se maneja con el puntero del control remoto, así que un
// botón de celular es un blanco imposible. Además el foco SÍ se
// marca (contorno grueso): sin mouse, el usuario necesita ver dónde
// está parado antes de decidir.
//
// Se conecta con: especificaciones_plataforma.dart (las elige).
// Parte del flujo: presentación (medidas de TV).
// ─────────────────────────────────────────────────────────────

import 'especificaciones_plataforma.dart';

/// Medidas de TV: de sillón, con el control remoto.
const especificacionesTv = EspecificacionesPlataforma(
  altoBoton: 56,
  altoBotonGrande: 64,
  radioBoton: 28,
  iconoBoton: 24,
  textoBoton: 17,
  altoBotonIcono: 62,
  iconoAccion: 30,
  radioTarjeta: 20,
  altoTile: 78,
  iconoTile: 30,
  altoFila: 92,
  altoIndicador: 34,
  radioEsqueleto: 16,
  radioHoja: 34,
  textoEtiqueta: 15,
  focoVisible: true,
  grosorFoco: 3,
  // Todo lo que sale de Responsive crece un 45% en la tele: a tres metros
  // un texto o un ícono de celular no se lee.
  factorEscala: 1.45,
);
