// ─────────────────────────────────────────────────────────────
// settings_sheet_download_pool_qobuz_piezas.dart — PART de
// settings_sheet_new.dart: las piezas chicas de la tarjeta "Sesiones de
// Qobuz": la fila de estado (chip de color + explicación) y la elección del
// color según el estado.
//
// Va aparte para que el árbol principal de la tarjeta se lea de un vistazo.
//
// Se conecta con: settings_sheet_download_pool_qobuz_build.dart (las usa) y
// ajustes_pool_qobuz (los estados) + strings_pool_qobuz (sus etiquetas).
// Parte del flujo: Ajustes → Descargas → sesiones de Qobuz.
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

/// El color del chip según el estado: verde solo cuando hay sesiones, ámbar si
/// la fuente respondió sin tokens, rojo si está caída o no se pudo consultar.
/// Cualquier estado desconocido cae en gris apagado (nunca verde por error).
Color _colorEstadoPoolQobuz(String estado, Color onBg) {
  switch (estado) {
    case AjustesPoolQobuz.estadoOk:
      return Colors.green.shade400;
    case AjustesPoolQobuz.estadoSinTokens:
      return Colors.orange.shade400;
    case AjustesPoolQobuz.estadoFuenteCaida:
    case AjustesPoolQobuz.estadoError:
      return Colors.red.shade400;
    default:
      return onBg.withValues(alpha: 0.5);
  }
}

/// La fila de estado: un punto de color, la etiqueta corta del estado y la
/// explicación (del backend si vino, del respaldo local si no).
Widget _filaEstadoPoolQobuz({
  required StringsPoolQobuz t,
  required String estado,
  required Color color,
  required String texto,
  required Color onBg,
  required Responsive r,
}) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Container(
      margin: const EdgeInsets.only(top: 3),
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
    SizedBox(width: r.spacingS),
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.etiquetaEstado(estado),
            style: TextStyle(
              fontSize: r.subtitleSize - 2,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            texto,
            style: TextStyle(
              fontSize: r.footerSize - 2,
              color: onBg.withValues(alpha: 0.5),
              height: 1.3,
            ),
          ),
        ],
      ),
    ),
  ],
);
