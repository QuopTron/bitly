// ─────────────────────────────────────────────────────────────
// settings_compartidos_fila.dart — PART de settings_sheet_new.dart:
// la tarjeta de un compartido (carátula, quién lo mandó, canción,
// ISRC y fecha) y el estado vacío de la pestaña.
//
// Se conecta con: settings_compartidos_tab.dart (misma library).
// Parte del flujo: Ajustes → Compartidos.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Tarjeta de un compartido recibido.
Widget _filaCompartido(
  BuildContext context,
  Responsive r,
  CompartidoRecibido entrada, {
  required VoidCallback onTap,
}) {
  final datos = entrada.datos;
  final l = AppLocalizations.of(context).setup;
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.all(r.spacingM),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 46,
              height: 46,
              child: datos.caratula.isNotEmpty
                  ? imagenDesdeUrl(datos.caratula)
                  : ColoredBox(
                      color: Colors.white.withValues(alpha: 0.06),
                      child: const Icon(
                        Icons.music_note_rounded,
                        color: Colors.white54,
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
                  datos.emisor.isEmpty
                      ? l.compartidosDe.replaceAll('{user}', '?')
                      : l.compartidosDe.replaceAll('{user}', datos.emisor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: r.footerSize - 1,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  datos.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: r.subtitleSize - 1,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (datos.artista.isNotEmpty) datos.artista,
                    _fechaCorta(entrada.fecha),
                    if (datos.isrc.isNotEmpty) datos.isrc,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: r.footerSize - 2,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.playlist_add_rounded,
            size: r.subtitleSize,
            color: Colors.white.withValues(alpha: 0.35),
          ),
        ],
      ),
    ),
  );
}

/// Fecha corta: hoy / ayer / dd/mm.
String _fechaCorta(DateTime fecha) {
  final ahora = DateTime.now();
  final dias = DateTime(ahora.year, ahora.month, ahora.day)
      .difference(DateTime(fecha.year, fecha.month, fecha.day))
      .inDays;
  if (dias <= 0) return 'hoy';
  if (dias == 1) return 'ayer';
  final d = fecha.day.toString().padLeft(2, '0');
  final m = fecha.month.toString().padLeft(2, '0');
  return '$d/$m';
}

/// Estado vacío de la pestaña Compartidos.
Widget _vacio(Responsive r, String texto) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.share_outlined,
          size: r.titleSize + 10,
          color: Colors.white.withValues(alpha: 0.25),
        ),
        SizedBox(height: r.spacingM),
        Text(
          texto,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: r.subtitleSize - 1,
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ),
      ],
    ),
  );
}
