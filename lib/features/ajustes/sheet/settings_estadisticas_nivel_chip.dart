// ─────────────────────────────────────────────────────────────
// settings_estadisticas_nivel_chip.dart — PART de settings_sheet_new
// .dart: ficha de UN nivel de escucha dentro de la tira horizontal —
// nombre y premio si ya se alcanzó; si no, ocultos con su umbral.
//
// Se conecta con: settings_sheet_new.dart (misma library) +
// settings_estadisticas_niveles.dart (la usa) + niveles_escucha.
// Parte del flujo: Ajustes → Estadísticas (niveles y recompensas).
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Ficha de un nivel: revelada si ya se alcanzó, oculta si no.
class _FichaNivel extends StatelessWidget {
  final NivelEscucha nivel;
  final bool abierto;
  final Color glowColor;
  final Color onBg;
  final Responsive r;

  const _FichaNivel({
    required this.nivel,
    required this.abierto,
    required this.glowColor,
    required this.onBg,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: r.width * 0.42,
      padding: EdgeInsets.all(r.spacingS),
      decoration: BoxDecoration(
        color:
            abierto ? glowColor.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              abierto ? glowColor.withValues(alpha: 0.35) : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(
                abierto ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                size: r.footerSize + 1,
                color: abierto ? glowColor : onBg.withValues(alpha: 0.35),
              ),
              SizedBox(width: r.spacingXS),
              Expanded(
                child: Text(
                  abierto ? nivel.nombre : '???',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: r.footerSize,
                    fontWeight: FontWeight.w700,
                    color: abierto ? glowColor : onBg.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: r.spacingXS),
          Text(
            // El umbral SIEMPRE se ve: es lo que motiva a seguir escuchando.
            '${_formatoHoras(nivel.horas)} h',
            style: TextStyle(
              fontSize: r.footerSize - 2,
              color: onBg.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: r.spacingXS),
          Text(
            // El premio queda oculto hasta desbloquearlo.
            abierto ? nivel.premio : 'Premio oculto',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: r.footerSize - 2,
              height: 1.2,
              color: onBg.withValues(alpha: abierto ? 0.75 : 0.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horas legibles: 1.234 / 35.040 (separador de miles, sin decimales).
String _formatoHoras(int horas) {
  final texto = horas.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < texto.length; i++) {
    if (i > 0 && (texto.length - i) % 3 == 0) buffer.write('.');
    buffer.write(texto[i]);
  }
  return buffer.toString();
}
