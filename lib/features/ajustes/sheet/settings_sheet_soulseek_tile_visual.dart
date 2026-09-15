// ─────────────────────────────────────────────────────────────
// settings_sheet_soulseek_tile_visual.dart — PART de settings_sheet
// _new.dart: parte visual del tile de Soulseek (estado cargando y
// estado listo con badge, título, subtítulo y chevron/check).
// Se conecta con: settings_sheet_new.dart (misma library) +
// settings_sheet_soulseek_tile (lo monta).
// Parte del flujo: Ajustes → Más (visual del tile Soulseek).
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Visual del tile de Soulseek. Recibe el estado ya resuelto por el tile.
class _SoulseekTileVisual extends StatelessWidget {
  final bool cargando;
  final bool conectada;
  final String usuario;
  final String usuarioApp;
  final Color glow;
  final Color onBg;
  final Responsive r;
  final VoidCallback onTap;

  const _SoulseekTileVisual({
    required this.cargando,
    required this.conectada,
    required this.usuario,
    required this.usuarioApp,
    required this.glow,
    required this.onBg,
    required this.r,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (cargando) return _cargandoBox();
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(r.spacingM),
        decoration: _decoracion(),
        child: Row(
          children: [
            _SoulseekBadge(glowColor: glow),
            SizedBox(width: r.spacingM),
            Expanded(child: _textos()),
            Icon(
              conectada
                  ? Icons.check_circle_rounded
                  : Icons.chevron_right_rounded,
              color: conectada ? glow : onBg.withValues(alpha: 0.3),
              size: r.subtitleSize,
            ),
          ],
        ),
      ),
    );
  }

  Widget _cargandoBox() => Container(
        padding: EdgeInsets.all(r.spacingM),
        decoration: BoxDecoration(
          color: onBg.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: onBg.withValues(alpha: 0.1)),
        ),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: glow),
          ),
        ),
      );

  BoxDecoration _decoracion() => BoxDecoration(
        gradient: conectada
            ? LinearGradient(
                colors: [
                  glow.withValues(alpha: 0.16),
                  glow.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: conectada ? null : onBg.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: conectada
              ? glow.withValues(alpha: 0.35)
              : onBg.withValues(alpha: 0.1),
        ),
      );

  Widget _textos() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _titulo(),
            style: TextStyle(
              fontSize: r.subtitleSize - 1,
              fontWeight: FontWeight.w600,
              color: conectada ? glow : onBg,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _subtitulo(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: r.footerSize - 2,
              color: onBg.withValues(alpha: 0.4),
            ),
          ),
        ],
      );

  String _titulo() => conectada
      ? 'Soulseek conectado'
      : (usuarioApp.isNotEmpty ? 'Sincronizar Soulseek' : 'Conectar Soulseek');

  String _subtitulo() => conectada
      ? '@$usuario'
      : (usuarioApp.isNotEmpty
          ? 'Usar tu nombre: $usuarioApp'
          : 'Elegís un nombre y listo');
}
