// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_barras_cofre_piezas.dart — PART de
// settings_sheet_new.dart: las piezas chicas del cofre de paletas.
//
// Son dos y ninguna tiene estado:
//   _BotonListo      → el botón que cierra el submodal,
//   _etiquetaPaleta  → qué dice abajo de cada paleta: "En uso", "Usar" o
//                      cómo se abre (horas de escucha o versión que la trae),
//   _encabezadoCofre → el título del panel con cuántos regalos quedan.
// La muestra de la paleta vive en _cofre_muestra y la entrada escalonada en
// _cofre_entrada.
//
// Se conecta con: _cofre_panel (usa el botón) + _cofre_tile (usa la
// etiqueta) + catalogo_disenos_barra_lista.
// Parte del flujo: Ajustes → Apariencia → Barras → Cofre.
// ─────────────────────────────────────────────────────────────

part of '../../../../settings_sheet_new.dart';

/// El botón "Listo" del panel: chico, sin peso visual.
class _BotonListo extends StatelessWidget {
  final String texto;
  final Color onBg;
  final Responsive r;
  final VoidCallback onTap;

  const _BotonListo({
    required this.texto,
    required this.onBg,
    required this.r,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.spacingS,
        vertical: r.spacingXS,
      ),
      decoration: BoxDecoration(
        color: onBg.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: r.footerSize - 1,
          fontWeight: FontWeight.w600,
          color: onBg.withValues(alpha: 0.8),
        ),
      ),
    ),
  );
}

/// Encabezado del panel: qué queda por abrir y el botón para cerrarlo.
Widget _encabezadoCofre({
  required StringsCofrePaletas t,
  required Responsive r,
  required Color onBg,
  required int disponibles,
  required VoidCallback onCerrar,
}) {
  return Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.regalosTitulo,
              style: TextStyle(
                fontSize: r.footerSize,
                fontWeight: FontWeight.w700,
                color: onBg.withValues(alpha: 0.85),
              ),
            ),
            Text(
              disponibles == 0 ? t.todoVisto : t.regalos(disponibles),
              style: TextStyle(
                fontSize: r.footerSize - 2,
                color: onBg.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
      _BotonListo(texto: t.listo, onBg: onBg, r: r, onTap: onCerrar),
    ],
  );
}

/// Qué dice abajo de una paleta: "En uso", "Usar" o cómo se abre.
String _etiquetaPaleta(
  DisenoBarra diseno, {
  required bool enUso,
  required bool abierto,
  required StringsCofrePaletas t,
}) {
  if (enUso) return t.enUso;
  if (abierto) return t.usar;
  switch (diseno.desbloqueo) {
    case DesbloqueoBarra.horas:
      return t.horas(diseno.valor);
    case DesbloqueoBarra.version:
      return t.llegaConVersion(versionLegible(diseno.valor));
    case DesbloqueoBarra.libre:
      return t.usar;
  }
}
