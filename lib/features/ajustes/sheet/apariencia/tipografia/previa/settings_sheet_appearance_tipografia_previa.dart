// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_tipografia_previa.dart — PART de
// settings_sheet_new.dart: el recuadro "así se ve" de Tipografía.
//
// Es la previa EN VIVO de verdad: acá NO se declara `fontFamily`, así que se
// dibuja con la tipografía del tema — la misma que acaba de elegir el usuario.
// Cuando una bajada termina de registrarse, la tarjeta se repinta y esto cambia
// al instante, sin cerrar Ajustes.
//
// Se conecta con: settings_sheet_appearance_tipografia.dart (la tarjeta).
// Parte del flujo: Ajustes → Apariencia → Tipografía.
// ─────────────────────────────────────────────────────────────

part of '../../../settings_sheet_new.dart';

/// Recuadro de muestra con la tipografía ACTIVA.
class _PreviaFuente extends StatelessWidget {
  final Responsive r;
  final Color onBg;
  final String titulo;
  final String texto;

  const _PreviaFuente({
    required this.r,
    required this.onBg,
    required this.titulo,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.spacingM),
      decoration: BoxDecoration(
        color: onBg.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: onBg.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo.toUpperCase(),
            style: TextStyle(
              fontSize: r.footerSize - 3,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: onBg.withValues(alpha: 0.4),
            ),
          ),
          SizedBox(height: r.spacingS),
          Row(
            children: [
              Text(
                'Aa',
                style: TextStyle(
                  fontSize: r.titleSize * 2.1,
                  fontWeight: FontWeight.w700,
                  color: onBg,
                  height: 1.0,
                ),
              ),
              SizedBox(width: r.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      texto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: r.subtitleSize,
                        fontWeight: FontWeight.w600,
                        color: onBg,
                      ),
                    ),
                    SizedBox(height: r.spacingXS * 0.5),
                    // Muestra sin idioma: sirve para comparar letras y cifras
                    // sin agregar texto nuevo que traducir.
                    Text(
                      'ABCDEFG abcdefg 0123456789',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: r.footerSize - 1,
                        color: onBg.withValues(alpha: 0.5),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
