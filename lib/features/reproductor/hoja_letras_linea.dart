// PART de hoja_letras.dart: pintado de la línea karaoke (neon/acentos).

part of 'hoja_letras.dart';

double _progresoLinea(_HojaLetrasState st, int i, Duration posicion) {
  final inicio = st._lineas[i].tiempo;
  final fin = i + 1 < st._lineas.length
      ? st._lineas[i + 1].tiempo
      : inicio + const Duration(seconds: 4);
  final total = fin - inicio;
  if (total <= Duration.zero) return 1.0;
  return ((posicion - inicio).inMilliseconds / total.inMilliseconds)
      .clamp(0.0, 1.0);
}

Widget _lineaKaraoke(
  _HojaLetrasState st,
  Responsive r,
  bool esOscuro,
  int i,
  int activa,
  PaletaPortada? paleta,
  Duration posicion,
) {
  final distancia = i - activa;
  final panelBg = _colorPanel(esOscuro, paleta);
  final fg = mejorNeutro(panelBg);
  final acento = paleta?.acentoTexto(
        sobreSuperficieOscura: esOscuro,
        fondo: panelBg,
      ) ??
      fg;

  Color color;
  FontWeight peso;
  double tamanoFuente;
  if (distancia == 0) {
    color = acento;
    peso = FontWeight.bold;
    tamanoFuente = r.titleSize + 3;
  } else if (distancia > 0 && distancia <= 6) {
    // Líneas siguientes: tinte de portada, desvaneciendo a neutro.
    color = paleta != null
        ? paleta.acentoSiguienteLinea(
            sobreSuperficieOscura: esOscuro,
            distancia: distancia,
            fondo: panelBg,
          )
        : Color.lerp(
            fg.withValues(alpha: 0.55),
            acento,
            (0.72 - (distancia - 1) * 0.12).clamp(0.05, 0.72),
          )!;
    peso = distancia <= 2 ? FontWeight.w600 : FontWeight.w400;
    tamanoFuente = r.subtitleSize + 4;
  } else {
    color = fg.withValues(alpha: distancia < 0 ? 0.15 : 0.4);
    peso = FontWeight.w400;
    tamanoFuente = r.subtitleSize + 1;
  }

  // ── Línea activa: barrido neon que sigue los segundos ──────
  if (distancia == 0) {
    final linea = st._lineas[i];
    final progreso = _progresoLinea(st, i, posicion);
    final cantado = fg.withValues(alpha: 0.5); // tenue, aún no cantado
    final brillo = acento; // neon, ya cantado
    final pesoTenue = FontWeight.w500;

    final sombrasGlow = <Shadow>[
      Shadow(color: acento.withValues(alpha: 0.55), blurRadius: 14),
      Shadow(color: acento.withValues(alpha: 0.30), blurRadius: 26),
      Shadow(color: acento.withValues(alpha: 0.18), blurRadius: 42),
    ];

    Widget widgetTexto;
    if (linea.palabras.isNotEmpty) {
      final spans = <TextSpan>[];
      for (final (t, w) in linea.palabras) {
        final encendida = posicion >= t;
        final sp = TextStyle(
          color: encendida ? brillo : cantado,
          fontWeight: encendida ? FontWeight.w700 : pesoTenue,
          shadows: encendida ? sombrasGlow : null,
        );
        if (spans.isEmpty) {
          spans.add(TextSpan(text: w, style: sp));
        } else {
          spans.add(TextSpan(text: ' $w', style: sp));
        }
      }
      widgetTexto = Text.rich(
        TextSpan(children: spans),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } else {
      final pintado = (linea.texto.length * progreso)
          .round()
          .clamp(0, linea.texto.length);
      widgetTexto = Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: linea.texto.substring(0, pintado),
              style: TextStyle(
                  color: brillo,
                  fontWeight: FontWeight.w700,
                  shadows: sombrasGlow),
            ),
            TextSpan(
              text: linea.texto.substring(pintado),
              style: TextStyle(color: cantado, fontWeight: pesoTenue),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DefaultTextStyle(
        style: TextStyle(fontSize: tamanoFuente, height: 1.1),
        child: widgetTexto,
      ),
    );
  }

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 250),
      style: TextStyle(
        color: color,
        fontSize: tamanoFuente,
        fontWeight: peso,
        height: 1.1,
      ),
      child: Text(
        st._lineas[i].texto,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}