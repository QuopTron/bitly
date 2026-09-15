// ─────────────────────────────────────────────────────────────
// settings_sheet_soulseek_password.dart — PART de settings_sheet
// _new.dart: fila de contraseña guardada de Soulseek con botón
// Ver/Ocultar y el valor seleccionable cuando está revelada
// (Soulseek no tiene recuperación de contraseña).
// Se conecta con: settings_sheet_new.dart (misma library) +
// settings_sheet_soulseek_form (lo monta).
// Parte del flujo: Ajustes → Más (contraseña Soulseek).
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Fila de contraseña guardada con botón Ver/Ocultar y, si está revelada,
/// el valor seleccionable (Soulseek no tiene recuperación de contraseña).
class _SoulseekPasswordRow extends StatelessWidget {
  final bool revelada;
  final String password;
  final Color glow;
  final Color onBg;
  final Responsive r;
  final VoidCallback onToggle;

  const _SoulseekPasswordRow({
    required this.revelada,
    required this.password,
    required this.glow,
    required this.onBg,
    required this.r,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.key_rounded,
              size: r.footerSize + 2,
              color: onBg.withValues(alpha: 0.45),
            ),
            SizedBox(width: r.spacingS),
            Expanded(
              child: Text(
                revelada
                    ? 'Guardala: Soulseek no tiene recuperación'
                    : 'Contraseña guardada',
                style: TextStyle(
                  fontSize: r.footerSize - 1,
                  color: onBg.withValues(alpha: 0.45),
                ),
              ),
            ),
            TextButton(
              onPressed: onToggle,
              child: Text(
                revelada ? 'Ocultar' : 'Ver',
                style: TextStyle(fontSize: r.footerSize, color: glow),
              ),
            ),
          ],
        ),
        if (revelada)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(r.spacingS),
            decoration: BoxDecoration(
              color: onBg.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: onBg.withValues(alpha: 0.08)),
            ),
            child: SelectableText(
              password,
              style: TextStyle(
                fontSize: r.subtitleSize - 2,
                color: onBg.withValues(alpha: 0.85),
                height: 1.3,
              ),
            ),
          ),
      ],
    );
  }
}
