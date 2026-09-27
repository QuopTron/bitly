// ─────────────────────────────────────────────────────────────
// modal_info_cancion_widgets.dart — PART de
// modal_info_cancion.dart: piezas visuales del modal — el botón de
// compartir con el texto del ítem (track + álbum) y la fila de
// detalle con icono, etiqueta y valor.
// Se conecta con: modal_info_cancion.dart (misma library) +
// share_plus + l10n.
// Parte del flujo: acciones de ítem (info del track).
// ─────────────────────────────────────────────────────────────

part of 'modal_info_cancion.dart';

/// Formatea milisegundos como mm:ss.
String _formatearDuracion(int ms) {
  final minutos = (ms ~/ 60000).toString().padLeft(2, '0');
  final segundos = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
  return '$minutos:$segundos';
}

/// Botón de compartir: manda el enlace de Bitly con los datos cifrados
/// (ISRC, nombre, carátula y quién lo comparte).
Widget _botonCompartir(
  BuildContext context,
  Responsive r,
  Color onBg,
  ItemFeed item,
) {
  return GestureDetector(
    onTap: () => ServicioCompartir.instance.compartir(item),
    child: Container(
      margin: EdgeInsets.symmetric(horizontal: r.spacingXL),
      padding: EdgeInsets.symmetric(vertical: r.spacingM),
      decoration: BoxDecoration(
        color: onBg.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.share,
            size: r.subtitleSize,
            color: onBg.withValues(alpha: 0.7),
          ),
          SizedBox(width: r.spacingS),
          Text(
            AppLocalizations.of(context).setup.share,
            style: TextStyle(
              fontSize: r.subtitleSize,
              color: onBg.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Selector de idioma destino para traducir los datos.
///
/// Reusa `loc.letras.idiomas` a propósito: es la MISMA lista ya localizada
/// que usa la traducción de la letra, y duplicarla acá sólo traería dos
/// listas que se desincronizan.
Future<String?> _abrirSelectorIdiomaInfo(
  BuildContext contexto,
  AppLocalizations loc,
  bool esOscuro,
  String? idiomaActual,
) async {
  final i = loc.infoCancion;
  final onBg = esOscuro ? Colors.white : Colors.black;
  return mostrarHoja<String>(
    context: contexto,
    // `sobreHoja`: el selector se abre DENTRO de la hoja de info.
    sobreHoja: true,
    backgroundColor: esOscuro
        ? const Color(0xFF141414)
        : const Color(0xFFF6F6F6),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => SafeArea(
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
                  i.traduccionTitulo,
                  style: TextStyle(
                    color: onBg,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  i.traduccionAyuda,
                  style: TextStyle(
                    color: onBg.withValues(alpha: 0.6),
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
                for (final e in loc.letras.idiomas.entries)
                  ListTile(
                    title: Text(e.value, style: TextStyle(color: onBg)),
                    trailing: idiomaActual == e.key
                        ? Icon(Icons.check_rounded, color: onBg)
                        : null,
                    onTap: () => Navigator.pop(context, e.key),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Cabecera de las filas de datos, con el botón de traducir los textos.
///
/// El botón no traduce etiquetas (esas ya vienen del APK): traduce los
/// VALORES, que son datos del proveedor. Por eso se llama "traducir datos".
Widget _cabeceraInfo(
  BuildContext context,
  Responsive r,
  Color onBg,
  AppLocalizations loc,
  bool traduciendo,
  bool activa,
  VoidCallback onTraducir,
) {
  final i = loc.infoCancion;
  return Padding(
    padding: EdgeInsets.fromLTRB(r.spacingXL, 0, r.spacingL, r.spacingXS),
    child: Row(
      children: [
        Icon(Icons.info_outline, size: r.footerSize + 2, color: onBg.withValues(alpha: 0.4)),
        SizedBox(width: r.spacingM),
        Expanded(
          child: Text(
            i.titulo,
            style: TextStyle(
              fontSize: r.footerSize,
              fontWeight: FontWeight.w700,
              color: onBg.withValues(alpha: 0.8),
            ),
          ),
        ),
        if (traduciendo)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: onBg.withValues(alpha: 0.6),
            ),
          )
        else
          Semantics(
            button: true,
            label: i.traduccionTitulo,
            child: GestureDetector(
              onTap: onTraducir,
              child: Tooltip(
                message: activa ? i.traduccionOcultar : i.traduccionTitulo,
                child: Icon(
                  Icons.translate,
                  size: r.footerSize + 4,
                  color: activa
                      ? Theme.of(context).colorScheme.primary
                      : onBg.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Pie de las filas cuando la traducción está activa: de dónde se tradujo y
/// el atajo para volver al original.
Widget _pieTraduccion(
  Responsive r,
  Color onBg,
  AppLocalizations loc,
  String? idiomaOrigen,
  VoidCallback onTraducir,
) {
  final i = loc.infoCancion;
  final detectado = idiomaOrigen;
  return Padding(
    padding: EdgeInsets.fromLTRB(r.spacingXL, r.spacingXS, r.spacingL, 0),
    child: Row(
      children: [
        Icon(Icons.public_rounded, size: r.footerSize, color: onBg.withValues(alpha: 0.4)),
        SizedBox(width: r.spacingS),
        Expanded(
          child: Text(
            detectado == null || detectado.isEmpty
                ? i.traduccionTitulo
                : '${i.traduccionDetectado} $detectado',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: r.footerSize - 1, color: onBg.withValues(alpha: 0.45)),
          ),
        ),
        GestureDetector(
          onTap: onTraducir,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: r.spacingS,
              vertical: r.spacingXS,
            ),
            child: Text(
              i.traduccionOcultar,
              style: TextStyle(
                fontSize: r.footerSize - 1,
                fontWeight: FontWeight.w600,
                color: onBg.withValues(alpha: 0.75),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Fila de detalle del modal: icono + etiqueta + valor.
Widget _filaInfo(
  Responsive r,
  Color onBg,
  IconData icono,
  String etiqueta,
  String valor,
) {
  return Padding(
    padding: EdgeInsets.symmetric(
      horizontal: r.spacingXL,
      vertical: r.spacingXS,
    ),
    child: Row(
      children: [
        Icon(icono, size: r.footerSize + 2, color: onBg.withValues(alpha: 0.4)),
        SizedBox(width: r.spacingM),
        Text(
          etiqueta,
          style: TextStyle(
            fontSize: r.footerSize,
            color: onBg.withValues(alpha: 0.5),
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            valor,
            style: TextStyle(
              fontSize: r.footerSize,
              fontWeight: FontWeight.w500,
              color: onBg,
            ),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}
