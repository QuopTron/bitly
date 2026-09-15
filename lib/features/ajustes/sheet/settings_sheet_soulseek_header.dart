// ─────────────────────────────────────────────────────────────
// settings_sheet_soulseek_header.dart — PART de settings_sheet_new
// .dart: encabezado de la hoja de Soulseek (badge + título y
// subtítulo de estado conectado/sin conectar).
// Se conecta con: settings_sheet_new.dart (misma library) +
// settings_sheet_soulseek_sheet (lo monta).
// Parte del flujo: Ajustes → Más (encabezado Soulseek).
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Encabezado de la hoja: badge + título y subtítulo de estado.
class _SoulseekSheetHeader extends StatelessWidget {
  final Color glow;
  final bool conectada;
  final Color onBg;
  final Responsive r;

  const _SoulseekSheetHeader({
    required this.glow,
    required this.conectada,
    required this.onBg,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingM),
      child: Row(
        children: [
          _SoulseekBadge(glowColor: glow, size: 34),
          SizedBox(width: r.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Soulseek',
                  style: TextStyle(
                    fontSize: r.subtitleSize,
                    fontWeight: FontWeight.w700,
                    color: onBg,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  conectada
                      ? 'Cuenta conectada'
                      : 'Sin mail, sin captcha, sin invitación',
                  style: TextStyle(
                    fontSize: r.footerSize - 2,
                    color: onBg.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
