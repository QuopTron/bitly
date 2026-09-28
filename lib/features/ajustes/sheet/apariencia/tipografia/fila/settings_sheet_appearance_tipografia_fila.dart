// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_tipografia_fila.dart — PART de
// settings_sheet_new.dart: una TIPOGRAFÍA dentro del catálogo.
//
// Muestra la palabra "Aa" en SU tipografía, su nombre (también en ella), una
// línea de estado ("En uso", "Usar", cómo se abre) y la marca de la derecha.
//
// Detalle importante: si la fuente todavía NO se bajó, su `fontFamily` no está
// registrada y Flutter cae a la del tema. O sea que la muestra se ve como la
// tipografía ACTUAL en vez de verse rota — y pasa a verse con la propia apenas
// termina la bajada, sin cerrar Ajustes.
//
// Se conecta con: _previa/_marca (las otras piezas) +
// settings_sheet_appearance_tipografia.dart (la tarjeta, que decide el estado).
// Parte del flujo: Ajustes → Apariencia → Tipografía.
// ─────────────────────────────────────────────────────────────

part of '../../../settings_sheet_new.dart';

/// Una fuente del catálogo: muestra, nombre, estado y su marca.
class _FilaFuente extends StatelessWidget {
  final FuenteApp fuente;
  final Responsive r;
  final Color onBg;
  final Color glowColor;

  /// Nombre legible (localizado por id).
  final String nombre;

  /// Línea de estado: "En uso", "Usar", "Bajando…" o cómo se abre.
  final String estado;

  final bool enUso;
  final bool desbloqueada;
  final bool bajando;
  final VoidCallback onTap;

  const _FilaFuente({
    required this.fuente,
    required this.r,
    required this.onBg,
    required this.glowColor,
    required this.nombre,
    required this.estado,
    required this.enUso,
    required this.desbloqueada,
    required this.bajando,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final lado = r.val(42, 34, 58);
    // Una fuente bloqueada no se toca: el candado ya lo dice, pero dejarla
    // "a medias" descargaría algo que el usuario todavía no puede usar.
    final accionable = desbloqueada && !enUso && !bajando;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: accionable ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        margin: EdgeInsets.only(top: r.spacingXS),
        padding: EdgeInsets.all(r.spacingS),
        decoration: BoxDecoration(
          color:
              enUso
                  ? glowColor.withValues(alpha: 0.12)
                  : onBg.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                enUso
                    ? glowColor.withValues(alpha: 0.45)
                    : onBg.withValues(alpha: 0.08),
            width: enUso ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: lado,
              height: lado,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: onBg.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Aa',
                style: TextStyle(
                  fontFamily: fuente.familia,
                  fontSize: lado * 0.42,
                  fontWeight: FontWeight.w600,
                  color: desbloqueada ? onBg : onBg.withValues(alpha: 0.45),
                ),
              ),
            ),
            SizedBox(width: r.spacingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: fuente.familia,
                      fontSize: r.subtitleSize - 1,
                      fontWeight: FontWeight.w700,
                      color: onBg,
                    ),
                  ),
                  Text(
                    estado,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: r.footerSize - 2,
                      color:
                          enUso ? glowColor : onBg.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: r.spacingXS),
            _MarcaFuente(
              enUso: enUso,
              desbloqueada: desbloqueada,
              bajando: bajando,
              onBg: onBg,
              glowColor: glowColor,
              r: r,
            ),
          ],
        ),
      ),
    );
  }
}
