part of 'settings_sheet_new.dart';

/// Fila de contenido del tile de Google: ícono, textos de estado y el
/// check / chevron según esté conectado o no.
class _GoogleTileContent extends StatelessWidget {
  final bool isConnected;
  final Color glowColor;
  final Color onBg;
  final Responsive r;

  const _GoogleTileContent({
    required this.isConnected,
    required this.glowColor,
    required this.onBg,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final glow = glowColor;

    return Row(
      children: [
        // Google icon
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
              ),
            ],
          ),
          child: Center(
            child: Text(
              'G',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF4285F4),
              ),
            ),
          ),
        ),
        SizedBox(width: r.spacingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isConnected ? 'Google conectado' : 'Conectar con Google',
                style: TextStyle(
                  fontSize: r.subtitleSize - 1,
                  fontWeight: FontWeight.w600,
                  color: isConnected ? glow : onBg,
                ),
              ),
              SizedBox(height: 2),
              Text(
                isConnected
                    ? 'Tu cuenta de Google esta conectada'
                    : 'Mejora la calidad del streaming',
                style: TextStyle(
                  fontSize: r.footerSize - 2,
                  color: onBg.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
        if (isConnected)
          Icon(Icons.check_circle_rounded, color: glow, size: r.subtitleSize)
        else
          Icon(
            Icons.chevron_right_rounded,
            color: onBg.withValues(alpha: 0.3),
            size: r.subtitleSize,
          ),
      ],
    );
  }
}
