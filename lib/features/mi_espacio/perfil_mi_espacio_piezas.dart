// ─────────────────────────────────────────────────────────────
// perfil_mi_espacio_piezas.dart — PART de perfil_mi_espacio.dart:
// la barra de nivel/progreso del perfil (insignia de nivel + barra
// de progreso hacia el siguiente nivel), visible solo con nivel > 0.
// La fila del avatar vive en perfil_mi_espacio_avatar.dart.
// Se conecta con: perfil_mi_espacio.dart (misma library) +
// l10n + responsive.
// Parte del flujo: Home → Mi Espacio (barra de nivel del perfil).
// ─────────────────────────────────────────────────────────────

part of 'perfil_mi_espacio.dart';

/// Barra de nivel/progreso (visible solo con nivel > 0).
Widget _barraNivel(PerfilMiEspacio p, BuildContext context) {
  final loc = AppLocalizations.of(context);
  final r = Responsive(context);
  if (p.nivel <= 0) return const SizedBox.shrink();

  return Row(
    children: [
      Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: p.colorBrillo.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              size: r.footerSize - 2,
              color: p.colorBrillo,
            ),
            SizedBox(width: 4),
            Text(
              '${loc.setup.level} ${p.nivel}',
              style: TextStyle(
                fontSize: r.footerSize - 1,
                fontWeight: FontWeight.w600,
                color: p.colorBrillo,
              ),
            ),
          ],
        ),
      ),
      SizedBox(width: r.spacingS),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: p.progresoNivel.clamp(0.0, 1.0),
                backgroundColor: p.onBg.withValues(alpha: 0.08),
                valueColor:
                    AlwaysStoppedAnimation(
                      p.colorBrillo.withValues(alpha: 0.6),
                    ),
                minHeight: 6,
              ),
            ),
            SizedBox(height: 2),
            Text(
              '${(p.progresoNivel * 100).toInt()}% → '
              '${loc.setup.nextLevel} ${p.siguienteNivel}',
              style: TextStyle(
                fontSize: r.footerSize - 2,
                color: p.onBg.withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}