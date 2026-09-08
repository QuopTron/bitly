part of 'settings_sheet_new.dart';

/// Card de conexión Google dentro del tab "Más".
/// Muestra el título + descripción y delega el estado real de la
/// conexión al tile [_GoogleConnectionTile].
class _GoogleConnectionCard extends StatelessWidget {
  final Color glowColor;

  const _GoogleConnectionCard({required this.glowColor});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = AppColors.onSurface(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.account_circle_rounded,
              color: glowColor,
              size: r.subtitleSize,
            ),
            SizedBox(width: r.spacingS),
            Text(
              'Google',
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
          'Conecta tu cuenta de Google para mejorar la calidad del streaming y obtener contenido personalizado.',
          style: TextStyle(
            fontSize: r.footerSize - 1,
            color: onBg.withValues(alpha: 0.5),
            height: 1.3,
          ),
        ),
        SizedBox(height: r.spacingS),
        _GoogleConnectionTile(glowColor: glowColor),
      ],
    );
  }
}

/// Card explicativa de la caché de streaming dentro del tab "Más".
/// La sección funcional (limpiar caché, ver tamaño) la aporta
/// [SettingsCacheSection].
