// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_diseno_avanzado.dart — PART de
// settings_sheet_new.dart: el desplegable "Avanzado" del bloque
// Diseño de Apariencia.
//
// El control general mueve todo junto; acá el usuario ajusta por
// COMPONENTE y por EJE: cards de canción y cards de grilla, cada una con su
// horizontal (mueve el hueco entre columnas Y el margen contra los bordes
// izq/der) y su vertical (hueco entre filas).
//
// Está detrás de un desplegable (cerrado por defecto) para no ensuciar el
// bloque: el 90% usa el control general.
//
// Se conecta con: apariencia_helper (cambiar cada eje) + la fila
// _FilaAvanzado y el _Deslizador de esta misma library.
// Parte del flujo: Ajustes → Apariencia → Diseño → Avanzado.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Desplegable "Avanzado": separa canción/grilla y horizontal/vertical.
class _SeccionAvanzadoDiseno extends StatefulWidget {
  final PreferenciasApariencia prefs;
  final StringsApariencia t;
  final Color glowColor;
  final Color onBg;
  final Responsive r;

  const _SeccionAvanzadoDiseno({
    required this.prefs,
    required this.t,
    required this.glowColor,
    required this.onBg,
    required this.r,
  });

  @override
  State<_SeccionAvanzadoDiseno> createState() => _SeccionAvanzadoDisenoState();
}

class _SeccionAvanzadoDisenoState extends State<_SeccionAvanzadoDiseno> {
  bool _abierto = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final r = widget.r;
    final prefs = widget.prefs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FilaAvanzado(
          titulo: t.avanzadoTitulo,
          ayuda: t.avanzadoAyuda,
          abierto: _abierto,
          glowColor: widget.glowColor,
          onBg: widget.onBg,
          r: r,
          onTap: () => setState(() => _abierto = !_abierto),
        ),
        // El cuerpo se arma sólo si está abierto: así el bloque no paga por
        // cuatro sliders que nadie está mirando.
        if (_abierto) ...[
          SizedBox(height: r.spacingS),
          _grupo(
            titulo: t.avanzadoCancion,
            x: prefs.cancionX,
            y: prefs.cancionY,
            onX: (v) => AparienciaEspacios.cambiarCancionX(context, v),
            onY: (v) => AparienciaEspacios.cambiarCancionY(context, v),
          ),
          SizedBox(height: r.spacingS),
          _grupo(
            titulo: t.avanzadoGrilla,
            x: prefs.grillaX,
            y: prefs.grillaY,
            onX: (v) => AparienciaEspacios.cambiarGrillaX(context, v),
            onY: (v) => AparienciaEspacios.cambiarGrillaY(context, v),
          ),
        ],
      ],
    );
  }

  /// Un componente (canción o grilla): título chico y sus dos ejes.
  Widget _grupo({
    required String titulo,
    required double x,
    required double y,
    required ValueChanged<double> onX,
    required ValueChanged<double> onY,
  }) {
    final r = widget.r;
    final t = widget.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: TextStyle(
            fontSize: r.footerSize - 2,
            fontWeight: FontWeight.w700,
            color: widget.onBg.withValues(alpha: 0.55),
          ),
        ),
        SizedBox(height: r.spacingXS),
        _Deslizador(
          etiqueta: t.separacionX,
          valor: x,
          maximo: PreferenciasApariencia.maxEspacio,
          onChanged: onX,
        ),
        _Deslizador(
          etiqueta: t.separacionY,
          valor: y,
          maximo: PreferenciasApariencia.maxEspacio,
          onChanged: onY,
        ),
      ],
    );
  }
}
