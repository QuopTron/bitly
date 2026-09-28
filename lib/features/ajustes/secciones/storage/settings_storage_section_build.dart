// ─────────────────────────────────────────────────────────────
// settings_storage_section_build.dart — PART de
// settings_storage_section.dart: tarjeta visual de la carpeta de
// descargas (icono, título, ruta actual, chevron o esqueleto) y el
// snackbar de aviso con el color de acento.
// Se conecta con: settings_storage_section.dart (misma library).
// Parte del flujo: Ajustes → Descargas → carpeta destino.
// ─────────────────────────────────────────────────────────────

part of 'settings_storage_section.dart';

/// Snackbar de aviso con el color de acento del tema (rojo si es error).
void _aviso(
  _SettingsStorageSectionState st,
  String texto, {
  bool error = false,
}) {
  if (!st.mounted) return;
  ScaffoldMessenger.of(st.context).showSnackBar(
    SnackBar(
      content: Text(texto, style: const TextStyle(color: Colors.white)),
      backgroundColor:
          error
              ? Colors.red.withValues(alpha: 0.8)
              : st.widget.glowColor.withValues(alpha: 0.9),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Tarjeta tocable de la carpeta de descargas.
Widget _seccionAlmacenamiento(_SettingsStorageSectionState st) {
  final r = Responsive(st.context);
  final onBg = st.widget.onBg;
  final glow = st.widget.glowColor;
  final ruta = st._ruta;

  return InkWell(
    onTap: st._elegirCarpeta,
    borderRadius: BorderRadius.circular(16),
    child: ContenedorVidrio(
      borderRadius: 16,
      borderColor: onBg.withValues(alpha: 0.08),
      bgColor: onBg.withValues(alpha: 0.03),
      margin: EdgeInsets.symmetric(horizontal: r.spacingM),
      padding: EdgeInsets.all(r.spacingM),
      child: Row(
        children: [
          Icon(Icons.folder_outlined, color: glow, size: r.footerSize + 4),
          SizedBox(width: r.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  st.widget.loc.setup.downloadFolder,
                  style: TextStyle(fontSize: r.subtitleSize, color: onBg),
                ),
                // Ayuda corta: qué hace esta carpeta (mismo estilo que el
                // resto de Ajustes).
                Text(
                  st.widget.loc.setup.storageDesc,
                  style: TextStyle(
                    fontSize: r.footerSize - 2,
                    color: onBg.withValues(alpha: 0.4),
                  ),
                ),
                if (ruta != null && ruta.isNotEmpty) ...[
                  SizedBox(height: 2),
                  Text(
                    ruta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: r.footerSize - 2,
                      color: onBg.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Eligiendo carpeta: el hueco del chevron se vuelve un bloque del
          // mismo tamaño, en vez de un circulito que empuja el layout.
          if (st._eligiendo)
            EsqueletoMarca(lado: r.footerSize + 2)
          else
            Icon(
              Icons.chevron_right,
              color: onBg.withValues(alpha: 0.3),
              size: r.footerSize + 2,
            ),
        ],
      ),
    ),
  );
}
