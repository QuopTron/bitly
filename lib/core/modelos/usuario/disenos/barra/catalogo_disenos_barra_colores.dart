// ─────────────────────────────────────────────────────────────
// catalogo_disenos_barra_colores.dart — Las PALETAS de color del cofre:
// tiñen la barra y no le tocan la forma.
//
// La escalera de horas acompaña a los niveles de escucha y la última llega
// con una versión de la app, para que las actualizaciones también traigan
// regalos.
//
// Va aparte de catalogo_disenos_barra_lista.dart (que las junta con las
// formas) para que cada archivo siga chico y haga una sola cosa.
//
// Se conecta con: catalogo_disenos_barra.dart (el modelo).
// Parte del flujo: Ajustes → Apariencia → Barras → Cofre.
// ─────────────────────────────────────────────────────────────

import '../base/catalogo_disenos_barra.dart';

/// Las paletas, en el orden en que se muestran.
const List<DisenoBarra> disenosColorBarra = [
  DisenoBarra(
    id: 'paleta_aurora',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 2,
    paleta: [0xFF7C4DFF, 0xFF22D3EE],
  ),
  DisenoBarra(
    id: 'paleta_atardecer',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 25,
    paleta: [0xFFFF7A59, 0xFFFF3D81],
  ),
  DisenoBarra(
    id: 'paleta_menta',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 100,
    paleta: [0xFF22C55E, 0xFFA3E635],
  ),
  DisenoBarra(
    id: 'paleta_oceano',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 250,
    paleta: [0xFF2563EB, 0xFF06B6D4],
  ),
  DisenoBarra(
    id: 'paleta_oro',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 500,
    paleta: [0xFFF5C451, 0xFFB45309],
  ),
  DisenoBarra(
    id: 'paleta_rosa',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 1_500,
    paleta: [0xFFF472B6, 0xFFA855F7],
  ),
  DisenoBarra(
    id: 'paleta_nocturno',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 3_000,
    paleta: [0xFF1E293B, 0xFF4C1D95],
  ),
  // Regalo de actualización: llega con la 0.9.23.
  DisenoBarra(
    id: 'paleta_fuego',
    desbloqueo: DesbloqueoBarra.version,
    valor: 923,
    paleta: [0xFFF59E0B, 0xFFEF4444],
  ),
];
