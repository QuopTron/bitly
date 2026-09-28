// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_tipografia_marca.dart — PART de
// settings_sheet_new.dart: la MARCA de la derecha de cada fuente.
//
// Es una sola pieza con cuatro caras —bajando, en uso, con candado y
// disponible— porque para el usuario es el mismo lugar de la fila siempre:
// cambiar de ícono es lo que hace legible que pasó algo, sin agregar texto.
//
// Se conecta con: settings_sheet_appearance_tipografia_fila.dart (la fila).
// Parte del flujo: Ajustes → Apariencia → Tipografía.
// ─────────────────────────────────────────────────────────────

part of '../../../settings_sheet_new.dart';

/// La marca de la derecha de la fila.
class _MarcaFuente extends StatelessWidget {
  final bool enUso;
  final bool desbloqueada;
  final bool bajando;
  final Color onBg;
  final Color glowColor;
  final Responsive r;

  const _MarcaFuente({
    required this.enUso,
    required this.desbloqueada,
    required this.bajando,
    required this.onBg,
    required this.glowColor,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final lado = EspecificacionesPlataforma.de(context).iconoTile * 0.85;
    // Bajando: la marca toma la forma del icono que va a quedar ahí (tilde,
    // candado o flecha), del mismo tamaño, así la fila no se mueve.
    if (bajando) {
      return EsqueletoMarca(lado: lado);
    }
    if (enUso) {
      return Icon(
        Icons.check_circle_rounded,
        size: lado,
        color: glowColor,
      );
    }
    if (!desbloqueada) {
      return Icon(
        Icons.lock_outline_rounded,
        size: lado,
        color: onBg.withValues(alpha: 0.35),
      );
    }
    // Disponible: se ve que hay algo para bajar, apagado para no competir con
    // el tilde de la que ya está puesta.
    return Icon(
      Icons.arrow_downward_rounded,
      size: lado,
      color: onBg.withValues(alpha: 0.5),
    );
  }
}

/// Aviso de que la bajada falló, con la acción para reintentarla.
///
/// Existe porque el silencio es lo peor que puede pasar acá: el usuario elige
/// una tipografía, no pasa nada y no hay forma de saber si falta internet o si
/// la app se olvidó. La app sigue andando con la empaquetada —eso no se toca—
/// pero el motivo se dice.
class _AvisoBajada extends StatelessWidget {
  final Responsive r;
  final Color onBg;
  final Color glowColor;
  final String texto;
  final String accion;
  final VoidCallback onReintentar;

  const _AvisoBajada({
    required this.r,
    required this.onBg,
    required this.glowColor,
    required this.texto,
    required this.accion,
    required this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.cloud_off_rounded,
          size: EspecificacionesPlataforma.de(context).iconoTile * 0.8,
          color: onBg.withValues(alpha: 0.45),
        ),
        SizedBox(width: r.spacingXS),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(
              fontSize: r.footerSize - 2,
              color: onBg.withValues(alpha: 0.5),
            ),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onReintentar,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: r.spacingS,
              vertical: r.spacingXS,
            ),
            child: Text(
              accion,
              style: TextStyle(
                fontSize: r.footerSize - 1,
                fontWeight: FontWeight.w700,
                color: glowColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
