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
  Widget build(BuildContext context) => _construirBibliotecaLocal(context, widget.glowColor, _importando, _resumen, _importar);

}
