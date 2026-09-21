// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_barras_cofre_texto.dart — PART de
// settings_sheet_new.dart: los TEXTOS de un diseño dentro del cofre.
//
// Es el nombre del diseño (que toma el color de su paleta) y, debajo, una
// sola línea de estado: "En uso", "Usar" o cómo se abre ("Se abre con 50 h de
// escucha" / "Viene con la v1.0.0").
//
// Va aparte de _cofre_tile para que cada archivo haga una sola cosa: uno
// dibuja la tarjeta del diseño, este escribe qué es.
//
// Se conecta con: _cofre_tile (lo usa) + _etiquetaPaleta (el estado).
// Parte del flujo: Ajustes → Apariencia → Barras → Cofre.
// ─────────────────────────────────────────────────────────────

part of '../../../../settings_sheet_new.dart';

/// Nombre del diseño y, debajo, su estado: "En uso", "Usar" o cómo se abre.
class _TextoPaleta extends StatelessWidget {
  final DisenoBarra diseno;
  final StringsCofrePaletas t;
  final Responsive r;
  final Color onBg;
  final Color glowColor;

  /// Colores del diseño (vacío = no tiñe): el nombre toma el primero.
  final List<Color> colores;

  final bool enUso;
  final bool abierto;

  const _TextoPaleta({
    required this.diseno,
    required this.t,
    required this.r,
    required this.onBg,
    required this.glowColor,
    required this.colores,
    required this.enUso,
    required this.abierto,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          t.nombre(diseno.id),
          maxLines: 1,
          style: TextStyle(
            fontSize: r.footerSize - 2,
            fontWeight: enUso ? FontWeight.w700 : FontWeight.w600,
            color:
                enUso
                    ? (colores.isEmpty ? glowColor : colores.first)
                    : onBg.withValues(alpha: abierto ? 0.8 : 0.4),
          ),
        ),
      ),
      Text(
        diseno.llegoConVersion.isNotEmpty
            ? t.vieneCon(diseno.llegoConVersion)
            : _etiquetaPaleta(diseno, enUso: enUso, abierto: abierto, t: t),
        textAlign: TextAlign.center,
        maxLines: 2,
        style: TextStyle(
          fontSize: r.footerSize - 3,
          height: 1.15,
          color: onBg.withValues(alpha: enUso ? 0.8 : (abierto ? 0.55 : 0.35)),
        ),
      ),
    ],
  );
}
