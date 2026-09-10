// ─────────────────────────────────────────────────────────────
// hoja_opciones_descarga_widgets.dart — PART de
// hoja_opciones_descarga.dart: piezas base de la hoja — metadata
// de calidad (etiqueta/bitrate/nivel), cabecera de sección con
// divider y el botón de radio circular animado.
// Se conecta con: hoja_opciones_descarga.dart (misma library).
// Parte del flujo: descargar (selección de calidad).
// ─────────────────────────────────────────────────────────────

part of 'hoja_opciones_descarga.dart';

/// Metadata de una calidad de audio (etiqueta, bitrate, nivel).
class _QMeta {
  final String etiqueta;
  final int bitrate;
  final String nivel;
  const _QMeta(this.etiqueta, this.bitrate, this.nivel);
}

/// Cabecera de sección (LOSSLESS / LOSSY) con línea divisoria.
Widget _cabeceraSeccion(Responsive r, String titulo, Color onBg) {
  return Padding(
    padding: EdgeInsets.fromLTRB(r.spacingM + 4, r.spacingS, r.spacingM + 4, 2),
    child: Row(
      children: [
        Text(
          titulo,
          style: TextStyle(
            fontSize: r.footerSize - 1,
            fontWeight: FontWeight.w700,
            color: onBg.withValues(alpha: 0.25),
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(width: r.spacingM),
        Expanded(child: Divider(color: onBg.withValues(alpha: 0.06), height: 1)),
      ],
    ),
  );
}

/// Botón de radio circular con relleno cuando está seleccionado.
class _BotonRadio<T> extends StatelessWidget {
  final T valor;
  final T? grupoValor;
  final Color colorActivo;
  final ValueChanged<T> alCambiar;

  const _BotonRadio({
    required this.valor,
    required this.grupoValor,
    required this.colorActivo,
    required this.alCambiar,
  });

  @override
  Widget build(BuildContext context) {
    final seleccionado = valor == grupoValor;
    return GestureDetector(
      onTap: () => alCambiar(valor),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color:
                seleccionado ? colorActivo : Colors.grey.withValues(alpha: 0.4),
            width: 2,
          ),
          color: seleccionado
              ? colorActivo.withValues(alpha: 0.15)
              : Colors.transparent,
        ),
        child: seleccionado
            ? Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorActivo,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}