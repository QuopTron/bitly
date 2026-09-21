// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_barras_cofre_seccion.dart — PART de
// settings_sheet_new.dart: una SECCIÓN del cofre de diseños.
//
// El cofre se muestra en dos: "Diseños" (formas y adornos, con el regalo de
// fábrica) y "Colores" (las paletas). Cada sección es su título y su grilla de
// tarjetas, todas del mismo ancho para que la fila quede pareja.
//
// Va aparte de _cofre_panel para que el panel se ocupe de desplegarse y de
// medir el ancho, y este de dibujar una sección.
//
// Se conecta con: _cofre_panel (la usa) + _cofre_entrada + _cofre_tile.
// Parte del flujo: Ajustes → Apariencia → Barras → Cofre.
// ─────────────────────────────────────────────────────────────

part of '../../../../settings_sheet_new.dart';

/// Una sección del cofre: su título y su grilla de tarjetas.
class _SeccionCofre extends StatelessWidget {
  final String titulo;
  final List<DisenoBarra> items;

  /// Posición en la grilla COMPLETA: así la entrada escalonada sigue de
  /// corrido entre las dos secciones en vez de reiniciarse.
  final int base;

  /// Ancho exacto de cada tarjeta y hueco entre ellas.
  final double ancho;
  final double hueco;

  /// Control de la animación de entrada (0 → 1 al abrir el cofre).
  final Animation<double> entrada;

  final bool navbar;
  final int horas;
  final int version;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final StringsCofrePaletas t;

  const _SeccionCofre({
    required this.titulo,
    required this.items,
    required this.base,
    required this.ancho,
    required this.hueco,
    required this.entrada,
    required this.navbar,
    required this.horas,
    required this.version,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.t,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        titulo,
        style: TextStyle(
          fontSize: r.footerSize,
          fontWeight: FontWeight.w700,
          color: onBg.withValues(alpha: 0.6),
        ),
      ),
      SizedBox(height: r.spacingS),
      Wrap(
        spacing: hueco,
        runSpacing: hueco,
        children: [
          for (var i = 0; i < items.length; i++)
            _PaletaConEntrada(
              entrada: entrada,
              indice: base + i,
              child: _PotPaletaTile(
                diseno: items[i],
                navbar: navbar,
                abierto: disenoDesbloqueado(
                  items[i],
                  horas: horas,
                  version: version,
                ),
                glowColor: glowColor,
                onBg: onBg,
                r: r,
                t: t,
                ancho: ancho,
              ),
            ),
        ],
      ),
    ],
  );
}
