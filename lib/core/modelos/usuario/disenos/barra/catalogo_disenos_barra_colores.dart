// ─────────────────────────────────────────────────────────────
// catalogo_disenos_barra_colores.dart — Las PALETAS de color del cofre:
// tiñen la barra y no le tocan la forma.
//
// El orden es el de la escalera: primero lo que ya está abierto (los cálidos
// de fábrica) y después de menor a mayor esfuerzo, así el cofre se lee como una
// progresión y no como una lista suelta. La última llega con una versión de la
// app, para que las actualizaciones también traigan regalos.
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
  // ── Cálidos de fábrica (abiertos) ────────────────────────────────────
  // Son los primeros colores que el usuario puede APLICAR sin haber escuchado
  // nada. Un catálogo donde todo está con candado se ve roto: se elige y no
  // pasa nada. Y son cálidos porque es lo que más se pide.
  DisenoBarra(id: 'paleta_ambar', paleta: [0xFFFB923C, 0xFFF59E0B]),
  DisenoBarra(id: 'paleta_terracota', paleta: [0xFFE07A5F, 0xFF9C3F27]),

  // ── La escalera, de menos a más horas ────────────────────────────────
  DisenoBarra(
    id: 'paleta_aurora',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 2,
    paleta: [0xFF7C4DFF, 0xFF22D3EE],
  ),
  DisenoBarra(
    id: 'paleta_mandarina',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 10,
    paleta: [0xFFFF8A3D, 0xFFE85D04],
  ),
  DisenoBarra(
    id: 'paleta_coral',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 12,
    paleta: [0xFFFF8A5B, 0xFFF43F5E],
  ),
  DisenoBarra(
    id: 'paleta_atardecer',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 25,
    paleta: [0xFFFF7A59, 0xFFFF3D81],
  ),
  DisenoBarra(
    id: 'paleta_miel',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 40,
    paleta: [0xFFFCD34D, 0xFFD97706],
  ),
  DisenoBarra(
    id: 'paleta_glaciar',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 60,
    paleta: [0xFF7DD3FC, 0xFF1D4ED8],
  ),
  DisenoBarra(
    id: 'paleta_menta',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 100,
    paleta: [0xFF22C55E, 0xFFA3E635],
  ),
  DisenoBarra(
    id: 'paleta_cobre',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 180,
    paleta: [0xFFD08A4E, 0xFF7C4A21],
  ),
  DisenoBarra(
    id: 'paleta_oceano',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 250,
    paleta: [0xFF2563EB, 0xFF06B6D4],
  ),
  // Tres colores: el cálido se va al frío. Es la más "de atardecer" y, de paso,
  // la prueba de que el catálogo admite más de dos paradas.
  DisenoBarra(
    id: 'paleta_ocaso',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 400,
    paleta: [0xFFFFB86C, 0xFFE85D75, 0xFF6D28D9],
  ),
  DisenoBarra(
    id: 'paleta_oro',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 500,
    paleta: [0xFFF5C451, 0xFFB45309],
  ),
  DisenoBarra(
    id: 'paleta_brasas',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 750,
    paleta: [0xFFF97316, 0xFFB91C1C],
  ),
  DisenoBarra(
    id: 'paleta_selva',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 900,
    paleta: [0xFF4ADE80, 0xFF14532D],
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
