// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_barras_cofre_muestra.dart — PART de
// settings_sheet_new.dart: la MUESTRA de un diseño del cofre.
//
// Es una MINI BARRA: se ve la FORMA (cuánto se curvan sus dos esquinas de
// arriba), el ADORNO (si el borde ondula, con las olas que hay puestas), la
// CALCOMANÍA que trae y, si el diseño tiñe, el gradiente de su paleta. Con
// radio 0 se ve cuadrada, con el máximo pastilla, y con olas se ve ondulada:
// así cada diseño se distingue de un vistazo, sin leer el nombre.
//
// Bloqueada va apagada y con candado; la que está puesta se marca con el color
// de acento en el contorno; y al abrir un diseño late con el glow de su color.
//
// Se conecta con: _cofre_tile (la usa) + apariencia_disenos_helper (le pasa la
// forma y el adorno ya resueltos) + barra_adornada (dibuja olas y sticker).
// Parte del flujo: Ajustes → Apariencia → Barras → Cofre.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Muestra de un diseño: forma, adorno, calcomanía, color y candado.
class _MuestraPaleta extends StatelessWidget {
  /// Colores del diseño (vacío = no tiñe: se ve el vidrio de siempre).
  final List<Color> colores;

  /// Redondeo de las dos esquinas de arriba de la muestra.
  final double radioArriba;

  /// Adorno del borde de arriba (esquinas u olas) y cuántas olas.
  final AdornoBarra adorno;
  final int olas;

  /// Id de la calcomanía que dibuja encima ('' = ninguna).
  final String sticker;

  /// Contorno del diseño: opacidad y grosor (0 de grosor = sin contorno).
  final (double, double) borde;

  /// Brillo de la apertura (0 = quieta, 1 = en el pico del pop).
  final double brillo;

  /// ¿Se puede usar? Las bloqueadas van apagadas y con candado.
  final bool abierto;

  /// ¿Es la que está puesta? Su contorno se marca con el color de acento.
  final bool enUso;

  final Color glowColor;
  final Color onBg;
  final Responsive r;

  const _MuestraPaleta({
    required this.colores,
    required this.radioArriba,
    required this.adorno,
    required this.olas,
    required this.sticker,
    required this.borde,
    required this.brillo,
    required this.abierto,
    required this.enUso,
    required this.glowColor,
    required this.onBg,
    required this.r,
  });

  bool get _esOlas => adorno == AdornoBarra.olas;

  @override
  Widget build(BuildContext context) {
    final colorBorde =
        enUso
            ? glowColor
            : onBg.withValues(alpha: borde.$1 == 0 ? 0.08 : borde.$1);
    final muestra = Container(
      height: r.spacingL * 1.8,
      decoration: BoxDecoration(
        gradient:
            colores.isEmpty
                ? null
                : LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: colores,
                ),
        color: colores.isEmpty ? onBg.withValues(alpha: 0.05) : null,
        // Con olas la forma la pone el adorno (que recorta la onda): acá no se
        // redondea nada, si no quedaría una línea recta cruzada arriba.
        borderRadius:
            _esOlas
                ? BorderRadius.zero
                : BorderRadius.vertical(top: Radius.circular(radioArriba)),
        border:
            _esOlas
                ? null
                : Border.all(
                  color: colorBorde,
                  width: enUso ? 1.6 : (borde.$2 == 0 ? 0.8 : borde.$2),
                ),
        boxShadow:
            brillo == 0 || colores.isEmpty
                ? null
                : [
                  BoxShadow(
                    color: colores.first.withValues(alpha: 0.55 * brillo),
                    blurRadius: 18 * brillo,
                    spreadRadius: 2 * brillo,
                  ),
                ],
      ),
      child:
          abierto
              ? null
              : Center(
                child: Icon(
                  Icons.lock_rounded,
                  size: 14,
                  color: onBg.withValues(alpha: 0.6),
                ),
              ),
    );
    return Opacity(
      opacity: abierto ? 1 : 0.35,
      child: BarraAdornada(
        adorno: adorno,
        olas: olas,
        radioArriba: radioArriba,
        colorBorde: colorBorde,
        sticker: sticker,
        colorSticker: glowColor,
        child: muestra,
      ),
    );
  }
}
