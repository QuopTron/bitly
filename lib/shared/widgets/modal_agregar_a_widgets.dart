// ─────────────────────────────────────────────────────────────
// modal_agregar_a_widgets.dart — PART de modal_agregar_a.dart:
// piezas visuales reutilizadas por la hoja — vista previa del ítem
// (carátula + nombre + artista) y la fila de opción con icono y
// etiqueta táctil.
// Se conecta con: modal_agregar_a.dart (misma library).
// Parte del flujo: acciones de ítem (modal agregar a).
// ─────────────────────────────────────────────────────────────

part of 'modal_agregar_a.dart';

/// Vista previa del ítem (carátula + nombre + artista).
Widget _vistaPrevia(Responsive r, Color onBg, ItemFeed item) {
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: r.spacingM),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: onBg.withValues(alpha: 0.06),
          ),
          child: item.coverUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    item.coverUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, e, s) => Icon(
                      Icons.music_note_rounded,
                      color: onBg.withValues(alpha: 0.3),
                      size: 20,
                    ),
                  ),
                )
              : Icon(Icons.music_note_rounded,
                  color: onBg.withValues(alpha: 0.3), size: 20),
        ),
        SizedBox(width: r.spacingS),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: r.subtitleSize - 1,
                  fontWeight: FontWeight.w600,
                  color: onBg,
                ),
              ),
              if (item.artists != null && item.artists!.isNotEmpty)
                Text(
                  item.artists!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: r.footerSize - 1,
                    color: onBg.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Fila de opción táctil con icono y etiqueta.
Widget _opcion(Responsive r, Color onBg, IconData icono, String etiqueta,
    VoidCallback onTap) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            EdgeInsets.symmetric(horizontal: r.spacingM + 8, vertical: r.spacingM),
        child: Row(
          children: [
            Icon(icono, size: r.subtitleSize, color: onBg.withValues(alpha: 0.65)),
            SizedBox(width: r.spacingM),
            Text(
              etiqueta,
              style: TextStyle(
                fontSize: r.subtitleSize - 1,
                color: onBg,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}