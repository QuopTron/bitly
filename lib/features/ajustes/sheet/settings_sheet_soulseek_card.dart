// ─────────────────────────────────────────────────────────────
// settings_sheet_soulseek_card.dart — PART de settings_sheet_new
// .dart: tarjeta de Soulseek en Ajustes → Más y su ícono circular
// (badge). La tarjeta solo presenta la sección; el tile de estado
// vive en settings_sheet_soulseek_tile.dart.
// Se conecta con: settings_sheet_new.dart (misma library).
// Parte del flujo: Ajustes → Más (Soulseek).
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Soulseek en Ajustes → Más.
///
/// Qué automatiza: el usuario escribe UNA cosa (el nombre que quiere tener en
/// la red) y al tocar "Siguiente" la app genera la contraseña, conecta, y la
/// cuenta queda creada — porque en Soulseek conectar ES registrarse, lo da de
/// alta el propio servidor en ese paso. Sin mail, sin captcha, sin pago.
class _SoulseekCard extends StatelessWidget {
  final Color glowColor;

  const _SoulseekCard({required this.glowColor});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.hub_rounded, color: glowColor, size: r.subtitleSize),
            SizedBox(width: r.spacingS),
            Text(
              'Soulseek',
              style: TextStyle(
                fontSize: r.subtitleSize,
                fontWeight: FontWeight.w700,
                color: onBg,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          'Música en FLAC compartida entre usuarios. Sin invitación, sin pago '
          'y sin cuentas de otros servicios.',
          style: TextStyle(
            fontSize: r.footerSize - 1,
            color: onBg.withValues(alpha: 0.5),
            height: 1.3,
          ),
        ),
        SizedBox(height: r.spacingS),
        _SoulseekTile(glowColor: glowColor),
      ],
    );
  }
}

/// Círculo con el ícono de Soulseek, para el tile y la hoja. El halo usa el
/// acento de la app en vez de un color propio, así respeta el tema elegido.
class _SoulseekBadge extends StatelessWidget {
  final Color glowColor;
  final double size;

  const _SoulseekBadge({required this.glowColor, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            glowColor.withValues(alpha: 0.30),
            glowColor.withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(Icons.hub_rounded, size: size * 0.5, color: glowColor),
      ),
    );
  }
}
