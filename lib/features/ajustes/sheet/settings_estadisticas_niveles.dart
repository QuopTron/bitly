// ─────────────────────────────────────────────────────────────
// settings_estadisticas_niveles.dart — PART de settings_sheet_new
// .dart: tarjeta de NIVELES DE ESCUCHA de la pestaña Estadísticas.
//
// Muestra el nivel actual, la barra hacia el siguiente y, en una tira
// horizontal, todos los niveles: los alcanzados con su premio a la
// vista y los que faltan como "???" (el premio recién se revela al
// llegar). La escalera vive en niveles_escucha.dart y llega hasta
// ~35.000 horas (más de 4 años escuchando 24/7).
//
// Se conecta con: settings_sheet_new.dart (misma library) +
// niveles_escucha (modelo) + Responsive/ColoresApp.
// Parte del flujo: Ajustes → Estadísticas.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Tarjeta con la escalera de niveles y premios.
class _NivelesEscuchaCard extends StatelessWidget {
  final ProgresoEscucha progreso;
  final int horasTotales;
  final Color glowColor;
  final Color onBg;
  final Responsive r;

  const _NivelesEscuchaCard({
    required this.progreso,
    required this.horasTotales,
    required this.glowColor,
    required this.onBg,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final siguiente = progreso.siguiente;
    return Container(
      padding: EdgeInsets.all(r.spacingM),
      decoration: BoxDecoration(
        color: onBg.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: onBg.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: glowColor, size: r.subtitleSize),
              SizedBox(width: r.spacingS),
              Expanded(
                child: Text(
                  'Niveles de escucha',
                  style: TextStyle(
                    fontSize: r.subtitleSize,
                    fontWeight: FontWeight.w700,
                    color: onBg,
                  ),
                ),
              ),
              Text(
                '${_formatoHoras(horasTotales)} h',
                style: TextStyle(
                  fontSize: r.footerSize,
                  fontWeight: FontWeight.w700,
                  color: glowColor,
                ),
              ),
            ],
          ),
          SizedBox(height: r.spacingXS),
          Text(
            // Con 0 horas todavía no hay nivel: se dice así en vez de mostrar
            // el nombre del primero como si ya lo tuviera.
            progreso.tieneNivel
                ? 'Nivel actual: ${progreso.actual.nombre}'
                : 'Todavía sin nivel — el primero llega a la hora de escucha',
            style: TextStyle(
              fontSize: r.footerSize,
              color: onBg.withValues(alpha: 0.75),
            ),
          ),
          if (siguiente != null) ...[
            SizedBox(height: r.spacingS),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progreso.avance,
                minHeight: 6,
                backgroundColor: onBg.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(glowColor),
              ),
            ),
            SizedBox(height: r.spacingXS),
            Text(
              'Faltan ${_formatoHoras(progreso.horasFaltantes)} h para '
              '"${siguiente.nombre}"',
              style: TextStyle(
                fontSize: r.footerSize - 1,
                color: onBg.withValues(alpha: 0.5),
              ),
            ),
          ] else ...[
            SizedBox(height: r.spacingXS),
            Text(
              'Escalera completa: ya desbloqueaste todos los premios.',
              style: TextStyle(
                fontSize: r.footerSize - 1,
                color: onBg.withValues(alpha: 0.6),
              ),
            ),
          ],
          SizedBox(height: r.spacingM),
          SizedBox(
            height: r.footerSize * 7.2,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: nivelesEscucha.length,
              separatorBuilder: (_, _) => SizedBox(width: r.spacingS),
              itemBuilder: (context, i) => _FichaNivel(
                nivel: nivelesEscucha[i],
                abierto: progreso.desbloqueado(i),
                glowColor: glowColor,
                onBg: onBg,
                r: r,
              ),
            ),
          ),
        ],
      ),
    );
  }

}
