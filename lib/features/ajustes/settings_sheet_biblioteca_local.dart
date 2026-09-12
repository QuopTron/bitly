// ─────────────────────────────────────────────────────────────
// settings_sheet_biblioteca_local.dart — PART de settings_sheet_new:
// tarjeta "Música local" en Ajustes → Más.
// Permite elegir una carpeta con archivos propios (compras de Amazon,
// iTunes Match, FLAC sueltos) y los indexa por ISRC para que la app
// los reconozca y no los vuelva a descargar.
// Se conecta con: backend_go (importarBibliotecaLocal) + file_picker.
// Parte del flujo: importación local de música del usuario.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

class _BibliotecaLocalCard extends StatefulWidget {
  final Color glowColor;

  const _BibliotecaLocalCard({required this.glowColor});

  @override
  State<_BibliotecaLocalCard> createState() => _BibliotecaLocalCardState();
}

class _BibliotecaLocalCardState extends State<_BibliotecaLocalCard> {
  bool _importando = false;
  String? _resumen;

  /// Abre el selector de carpeta y manda la ruta a Go para escanearla.
  Future<void> _importar() async {
    try {
      final carpeta = await FilePicker.getDirectoryPath(
        dialogTitle: 'Elegí la carpeta con tu música',
      );
      if (carpeta == null || !mounted) return;

      setState(() {
        _importando = true;
        _resumen = null;
      });

      final resultado = await ImportacionBiblioteca().importar(carpeta);
      if (!mounted) return;

      setState(() {
        _importando = false;
        _resumen =
            '${resultado.archivos} archivos · ${resultado.conIsrc} con ISRC · '
            '${resultado.guardados} en Mi Espacio';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _importando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo importar: $e'),
          backgroundColor: Colors.red.withValues(alpha: 0.8),
        ),
      );
    }
  }

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
            Icon(
              Icons.library_music_rounded,
              color: widget.glowColor,
              size: r.subtitleSize,
            ),
            SizedBox(width: r.spacingS),
            Text(
              'Música local',
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
          'Importá tu música propia (compras de Amazon, archivos de iTunes Match, '
          'FLAC sueltos). Se indexa por ISRC para que la app la reconozca y no la '
          'vuelva a descargar.',
          style: TextStyle(
            fontSize: r.footerSize - 1,
            color: onBg.withValues(alpha: 0.5),
            height: 1.3,
          ),
        ),
        SizedBox(height: r.spacingS),
        GestureDetector(
          onTap: _importando ? null : _importar,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: r.spacingM,
              vertical: r.spacingM,
            ),
            decoration: BoxDecoration(
              color: onBg.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: onBg.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_importando)
                  SizedBox(
                    width: r.subtitleSize,
                    height: r.subtitleSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: widget.glowColor,
                    ),
                  )
                else
                  Icon(
                    Icons.create_new_folder_rounded,
                    size: r.subtitleSize + 2,
                    color: widget.glowColor,
                  ),
                SizedBox(width: r.spacingS),
                Text(
                  _importando ? 'Importando…' : 'Importar carpeta',
                  style: TextStyle(
                    fontSize: r.subtitleSize,
                    fontWeight: FontWeight.w600,
                    color: onBg.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_resumen != null) ...[
          SizedBox(height: r.spacingXS),
          Text(
            'Importado: $_resumen',
            style: TextStyle(
              fontSize: r.footerSize - 1,
              color: widget.glowColor.withValues(alpha: 0.9),
            ),
          ),
        ],
      ],
    );
  }
}
