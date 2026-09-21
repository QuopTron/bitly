// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_barras_cofre_grillas.dart — PART de
// settings_sheet_new.dart: las DOS grillas del cofre (Diseños y Colores).
//
// Va aparte del panel (que se ocupa de desplegarse y del encabezado) para que
// cada archivo haga una sola cosa: este mide el ancho de las tarjetas para que
// entren EXACTAS en la fila —sin sobras desparejas ni apretujones— y dibuja las
// dos secciones con las listas YA FILTRADAS por el aparato del que se trate.
//
// Se conecta con: _cofre_panel (lo usa) + _cofre_seccion + _cofre_entrada.
// Parte del flujo: Ajustes → Apariencia → Barras → Cofre.
// ─────────────────────────────────────────────────────────────

part of '../../../../settings_sheet_new.dart';

/// Las dos grillas del cofre: los diseños del aparato y sus colores.
class _GrillasCofre extends StatelessWidget {
  /// Diseños y colores que le tocan al aparato (ya filtrados).
  final List<DisenoBarra> disenos;
  final List<DisenoBarra> colores;

  /// Control de la animación de entrada escalonada.
  final Animation<double> entrada;

  final bool navbar;
  final int horas;
  final int version;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final StringsCofrePaletas t;

  const _GrillasCofre({
    required this.disenos,
    required this.colores,
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limites) {
      // 3 por fila si hay ancho cómodo; 2 en pantallas angostas (y en TV, que
      // presenta un lienzo lógico de 1280: ahí entran 3 holgadas).
      final columnas = limites.maxWidth > r.width * 0.62 ? 3 : 2;
      final hueco = r.spacingS;
      final ancho = (limites.maxWidth - hueco * (columnas - 1)) / columnas;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _seccion(t.seccionDisenos, disenos, 0, ancho, hueco),
          SizedBox(height: r.spacingM),
          _seccion(t.seccionColores, colores, disenos.length, ancho, hueco),
        ],
      );
    },
  );

  /// Una sección del cofre (ver _cofre_seccion).
  Widget _seccion(
    String titulo,
    List<DisenoBarra> items,
    int base,
    double ancho,
    double hueco,
  ) => _SeccionCofre(
    titulo: titulo,
    items: items,
    base: base,
    ancho: ancho,
    hueco: hueco,
    entrada: entrada,
    navbar: navbar,
    horas: horas,
    version: version,
    glowColor: glowColor,
    onBg: onBg,
    r: r,
    t: t,
  );
}
