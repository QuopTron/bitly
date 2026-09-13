// ─────────────────────────────────────────────────────────────
// pagina_mi_espacio_banner.dart — PART de pagina_mi_espacio.dart:
// banner de descargas interrumpidas — aviso ámbar con el conteo
// y un botón para reintentar todas de una vez (reintentarTodos-
// Interrumpidos del CubitDescargas).
// Se conecta con: pagina_mi_espacio.dart (misma library) + l10n.
// Parte del flujo: Home → Mi Espacio (aviso de reintento).
// ─────────────────────────────────────────────────────────────

part of 'pagina_mi_espacio.dart';

/// Banner ámbar de descargas interrumpidas con botón de reintento.
Widget _bannerReintentar(
  BuildContext context,
  Color onBg,
  int count,
) {
  final r = Responsive(context);
  final loc = AppLocalizations.of(context);
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: r.spacingM),
    child: Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.spacingM,
        vertical: r.spacingS,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFFFA726).withValues(alpha: 0.12),
        border: Border.all(
          color: const Color(0xFFFFA726).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: r.footerSize + 4,
            color: const Color(0xFFFFA726),
          ),
          SizedBox(width: r.spacingS),
          Expanded(
            child: Text(
              count > 1
                  ? loc.setup.downloadInterruptedMany.replaceAll(
                      '{count}',
                      '$count',
                    )
                  : loc.setup.downloadInterruptedOne,
              style: TextStyle(
                fontSize: r.footerSize,
                color: onBg.withValues(alpha: 0.85),
              ),
            ),
          ),
          SizedBox(width: r.spacingS),
          GestureDetector(
            onTap: () =>
                context.read<CubitDescargas>().reintentarTodosInterrumpidos(),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: r.spacingM,
                vertical: r.spacingXS,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFFFFA726).withValues(alpha: 0.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.refresh,
                    size: r.footerSize - 2,
                    color: const Color(0xFFFFA726),
                  ),
                  SizedBox(width: 4),
                  Text(
                    loc.setup.retryInterrupted,
                    style: TextStyle(
                      fontSize: r.footerSize - 1,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFFFA726),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}