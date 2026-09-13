part of 'settings_sheet_new.dart';

/// Tile de conexión de Google: verifica el estado de la cuenta de YouTube
/// al iniciar y permite conectar si aún no está conectada.
class _GoogleConnectionTile extends StatefulWidget {
  final Color glowColor;
  const _GoogleConnectionTile({required this.glowColor});

  @override
  State<_GoogleConnectionTile> createState() => _GoogleConnectionTileState();
}

class _GoogleConnectionTileState extends State<_GoogleConnectionTile> {
  bool _isConnected = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    try {
      final connected = await ServicioOAuthYouTube().estaConectado;
      if (mounted) {
        setState(() {
          _isConnected = connected;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(isDark);
    final glow = widget.glowColor;

    if (_loading) {
      return Container(
        padding: EdgeInsets.all(r.spacingM),
        decoration: BoxDecoration(
          color: onBg.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: onBg.withValues(alpha: 0.1)),
        ),
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: glow),
        ),
      );
    }

    return GestureDetector(
      onTap:
          _isConnected ? null : () => _connectGoogle(context, _checkConnection),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(r.spacingM),
        decoration: BoxDecoration(
          gradient:
              _isConnected
                  ? LinearGradient(
                    colors: [
                      glow.withValues(alpha: 0.16),
                      glow.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                  : null,
          color: _isConnected ? null : onBg.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                _isConnected
                    ? glow.withValues(alpha: 0.35)
                    : onBg.withValues(alpha: 0.1),
          ),
        ),
        child: _GoogleTileContent(
          isConnected: _isConnected,
          glowColor: glow,
          onBg: onBg,
          r: r,
        ),
      ),
    );
  }
}
