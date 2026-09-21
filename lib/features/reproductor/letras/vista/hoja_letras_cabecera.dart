// ─────────────────────────────────────────────────────────────
// hoja_letras_cabecera.dart — PART de hoja_letras.dart: cabecera del modal karaoke (título, artista y botón de cerrar) y el velo que reacciona al estilo visual.
// Se conecta con: hoja_letras.dart (misma library) + paleta_portada + estilo_helper.
// Parte del flujo: Reproductor → letras (cabecera y velo).
// ─────────────────────────────────────────────────────────────

part of '../base/hoja_letras.dart';

Widget _cabeceraHoja(
  _HojaLetrasState st,
  BuildContext context,
  Responsive r,
  bool esOscuro,
) {
  final fg = esOscuro ? Colors.white : Colors.black;
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: r.spacingL),
    child: Row(
      children: [
        Icon(Icons.lyrics_rounded, size: r.subtitleSize + 2, color: fg),
        SizedBox(width: r.spacingS),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                st.widget.track.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontSize: r.subtitleSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                st.widget.track.artists ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg.withValues(alpha: 0.5),
                  fontSize: r.footerSize,
                ),
              ),
            ],
          ),
        ),
        _botonTraducir(st, context, esOscuro),
        IconButton(
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: fg),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    ),
  );
}
