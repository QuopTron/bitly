// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_vistas_muestra.dart — PART de
// settings_sheet_new.dart: la muestra en vivo del bloque "Diseño por vista".
//
// Por qué existe: mover un deslizador sin ver el efecto obliga a cerrar
// Ajustes, mirar la app y volver. Acá se ven las tres cosas que el bloque
// cambia —el color de las tarjetas, el redondeo y el aire entre ellas— al
// instante y en el mismo lugar donde se mueve el control.
//
// No dibuja una tarjeta real (necesitaría cubits, descargas y portadas): dibuja
// la SILUETA, que es exactamente lo que el control cambia. Las medidas salen
// resueltas por parámetro, así que respeta la cascada: lo heredado se ve como
// lo heredado.
//
// Lo único REAL es el texto de muestra, que se escribe EN la tipografía de la
// vista: es lo que hace que la previa sea fiel de verdad —letra, color, forma y
// aire en la misma pieza—, en vez de cuatro previas separadas donde el usuario
// tiene que imaginarse el resultado combinado.
//
// Se conecta con: settings_sheet_appearance_vistas.dart (la tarjeta).
// Parte del flujo: Ajustes → Apariencia → Vistas.
// ─────────────────────────────────────────────────────────────

part of '../../../settings_sheet_new.dart';

/// Silueta de tarjetas con el redondeo y la separación que va a tener la vista.
class _VistasMuestra extends StatelessWidget {
  /// Redondeo ya resuelto, en píxeles lógicos.
  final double radio;

  /// Separación horizontal ya resuelta.
  final double espacioX;

  /// Separación vertical ya resuelta.
  final double espacioY;

  /// Paleta del cofre que tiene puesta la vista (vacía = ninguna: las tarjetas
  /// se tiñen con el color de su carátula, que es lo de siempre).
  final List<Color> paleta;

  /// Familia tipográfica de la vista (null = la del tema).
  final String? familia;

  /// Texto de muestra, escrito en esa familia.
  final String texto;
  final Responsive r;
  final Color onBg;
  final Color glowColor;

  const _VistasMuestra({
    required this.radio,
    required this.espacioX,
    required this.espacioY,
    required this.paleta,
    required this.familia,
    required this.texto,
    required this.r,
    required this.onBg,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    // La separación real de la app va de 0 a ~24: acá se dibuja a la mitad para
    // que la muestra no ocupe media pantalla y siga notándose el cambio.
    final huecoX = (espacioX / 2).clamp(0.0, 14.0);
    final huecoY = (espacioY / 3).clamp(0.0, 10.0);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: EdgeInsets.all(r.spacingS),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: onBg.withValues(alpha: 0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dos "filas de canción" apiladas y separadas como quedarían.
          for (var i = 0; i < 2; i++) ...[
            if (i > 0) SizedBox(height: huecoY),
            _fila(i),
          ],
          SizedBox(height: huecoY + 4),
          // Una grilla de tres, para ver el redondeo en cuadrado.
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) SizedBox(width: huecoX),
                _cuadrado(),
              ],
              const Spacer(),
            ],
          ),
        ],
      ),
    );
  }

  /// Una tarjeta de canción en silueta: portada + dos líneas de texto.
  Widget _fila(int i) => Container(
    padding: EdgeInsets.all(r.spacingXS + 2),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radio),
      color: _tinteDeCard(0.06),
      border: Border.all(color: onBg.withValues(alpha: 0.08)),
    ),
    child: Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radioInterno(radio, 6)),
            // Con paleta, la portada se ve teñida como la va a ver la app.
            gradient:
                paleta.isEmpty
                    ? null
                    : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: paleta,
                    ),
            color: paleta.isEmpty ? glowColor.withValues(alpha: _alphaInterno(i)) : null,
          ),
        ),
        SizedBox(width: r.spacingS),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // El único texto real de la previa: se ve la LETRA de esta vista.
              Text(
                texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: familia,
                  fontSize: r.footerSize + 1,
                  fontWeight: FontWeight.w600,
                  color: onBg.withValues(alpha: 0.85),
                ),
              ),
              SizedBox(height: r.spacingXS),
              _linea(0.4, 5),
            ],
          ),
        ),
      ],
    ),
  );

  /// Un cuadrado de grilla: se ve el redondeo en las cuatro esquinas.
  Widget _cuadrado() => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radio),
      color: _tinteDeCard(0.07),
      border: Border.all(color: onBg.withValues(alpha: 0.08)),
    ),
  );

  /// El fondo de una card de la muestra: con paleta toma su color, y sin ella
  /// queda el neutro de siempre (no se inventa un tinte que la vista no tiene).
  Color _tinteDeCard(double alpha) =>
      paleta.isEmpty
          ? onBg.withValues(alpha: alpha)
          : paleta.first.withValues(alpha: alpha + 0.16);

  /// Una línea de texto de mentira.
  Widget _linea(double ancho, double alto) => FractionallySizedBox(
    alignment: Alignment.centerLeft,
    widthFactor: ancho,
    child: Container(
      height: alto,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(alto / 2),
        color: onBg.withValues(alpha: 0.14),
      ),
    ),
  );

  /// La portada de adentro también se redondea, pero menos: si copiara el radio
  /// de la tarjeta, con un radio grande la portada quedaría circular.
  static double _radioInterno(double radio, double max) =>
      radio > max ? max : radio;

  static double _alphaInterno(int i) => i == 0 ? 0.30 : 0.18;
}
