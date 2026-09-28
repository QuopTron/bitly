// ─────────────────────────────────────────────────────────────
// hoja_letras_traduccion.dart — PART de hoja_letras.dart: botón de
// traducción (icono de MUNDO), selector de idioma destino y el MINI
// KARAOKE donde se ve la traducción sincronizada.
//
// El idioma de origen NO se pregunta: lo detecta el traductor. La
// traducción se pide una sola vez por idioma (el servicio la guarda en
// memoria y en la base) y se muestra en la tira de abajo, con el mismo
// barrido que la letra grande: el karaoke original queda limpio.
//
// Se conecta con: hoja_letras.dart (misma library) +
// servicio_traduccion_letras.dart + strings_letras.dart (l10n).
// Parte del flujo: reproductor → letras (traducción).
// ─────────────────────────────────────────────────────────────

part of '../base/hoja_letras.dart';

/// Botón de la cabecera: abre el selector de idioma (o muestra que traduce).
Widget _botonTraducir(
  _HojaLetrasState st,
  BuildContext context,
  bool esOscuro,
) {
  final loc = AppLocalizations.of(context).letras;
  final fg = esOscuro ? Colors.white : Colors.black;
  // Traduciendo: el hueco del botón de idiomas (el mundo) se ve como el ícono
  // que va a volver, del tamaño del IconButton.
  if (st._traduciendo) {
    return const Padding(
      padding: EdgeInsets.all(12),
      child: EsqueletoMarca(lado: 24),
    );
  }
  final activa = st._traducciones != null;
  return IconButton(
    tooltip: loc.traducirBoton,
    // Icono de MUNDO: es el botón de idiomas (traducir la letra y elegir a
    // cuál), y se enciende cuando ya hay una traducción mostrándose.
    icon: Icon(
      Icons.public_rounded,
      color: activa ? Theme.of(context).colorScheme.primary : fg,
    ),
    onPressed: () => _abrirSelectorIdioma(st, context),
  );
}

/// Selector de idioma destino. Incluye \"ocultar\" cuando ya hay traducción.
Future<void> _abrirSelectorIdioma(_HojaLetrasState st, BuildContext ctx) async {
  final loc = AppLocalizations.of(ctx).letras;
  final esOscuro = Theme.of(ctx).brightness == Brightness.dark;
  final fg = esOscuro ? Colors.white : Colors.black;
  // `sobreHoja`: el selector se abre DENTRO del karaoke, así que tapa por
  // completo la hoja de la letra (si no, parecía un modal sobre otro).
  final elegido = await mostrarHoja<String?>(
    context: ctx,
    sobreHoja: true,
    backgroundColor:
        esOscuro ? const Color(0xFF141414) : const Color(0xFFF6F6F6),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder:
        (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.tituloSelector,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _pieSelector(st, loc),
                      style: TextStyle(
                        color: fg.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final e in loc.idiomas.entries)
                      ListTile(
                        title: Text(e.value, style: TextStyle(color: fg)),
                        trailing:
                            st._idiomaDestino == e.key
                                ? Icon(Icons.check_rounded, color: fg)
                                : null,
                        onTap: () => Navigator.pop(context, e.key),
                      ),
                    if (st._traducciones != null)
                      ListTile(
                        leading: Icon(Icons.visibility_off_rounded, color: fg),
                        title: Text(
                          loc.ocultarTraduccion,
                          style: TextStyle(color: fg),
                        ),
                        onTap: () => Navigator.pop(context, ''),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
  );
  if (!st.mounted) return;
  if (elegido == null) return;
  // Cadena vacía = \"ocultar\" (showModalBottomSheet no distingue null de cierre).
  await st.traducirA(elegido.isEmpty ? null : elegido);
}

/// Ayuda del selector: explica de dónde sale el idioma de origen y, si ya hay
/// traducción, cuál se detectó.
String _pieSelector(_HojaLetrasState st, StringsLetras loc) {
  final detectado = st._idiomaOrigen;
  if (detectado == null || detectado.isEmpty) return loc.ayudaSelector;
  return '${loc.detectadoPrefijo} $detectado';
}

/// Mini karaoke de la traducción: la tira de abajo del modal, con la línea que
/// se está cantando traducida (mismo barrido y mismo retraso que la letra
/// grande) y la siguiente en tono bajo para leer adelantado.
///
/// Devuelve un widget vacío cuando no hay traducción activa: así el modal
/// recupera su altura normal al ocultarla.
Widget _miniKaraoke(
  _HojaLetrasState st,
  Responsive r,
  bool esOscuro,
  PaletaPortada? paleta,
  int activa,
  Duration posicion,
) {
  final tr = st._traducciones;
  if (tr == null || st._lineas.isEmpty) return const SizedBox.shrink();
  final panelBg = _colorPanel(esOscuro, paleta);
  final fg = mejorNeutro(panelBg);
  final acento =
      paleta?.acentoTexto(sobreSuperficieOscura: esOscuro, fondo: panelBg) ??
      fg;

  return Padding(
    padding: EdgeInsets.fromLTRB(r.spacingL, r.spacingXS, r.spacingL, 0),
    child: Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.spacingM,
        vertical: r.spacingS,
      ),
      decoration: BoxDecoration(
        color: (esOscuro ? Colors.white : Colors.black).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.public_rounded,
            size: r.footerSize + 4,
            color: acento.withValues(alpha: 0.85),
          ),
          SizedBox(width: r.spacingS),
          Expanded(
            child: MiniKaraokeLetra(
              actual: _textoTraduccion(tr, activa),
              siguiente: _textoTraduccion(tr, activa + 1),
              progreso: _progresoLinea(st, activa, posicion),
              brillo: acento,
              tenue: fg.withValues(alpha: 0.55),
              siguienteColor: fg.withValues(alpha: 0.4),
              tamanoFuente: r.footerSize + 3,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Traducción de la línea [i] si existe y tiene texto (null si no).
String? _textoTraduccion(List<String?> traducciones, int i) {
  if (i < 0 || i >= traducciones.length) return null;
  final texto = traducciones[i];
  if (texto == null || texto.trim().isEmpty) return null;
  return texto;
}
