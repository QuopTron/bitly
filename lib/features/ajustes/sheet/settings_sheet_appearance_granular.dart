// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_granular.dart — PART de settings_sheet_new.dart:
// los controles AVANZADOS del estilo con cover, uno por zona.
//
// Están detrás de un desplegable para no ensuciar el bloque: el 90% de la
// gente usa el control general y el que quiere afinar abre esto y deja, por
// ejemplo, las cards con color y los fondos en Normal.
//
// Se conecta con: estilo_helper (cambiar cada nivel) +
// settings_sheet_appearance_style.dart (lo monta).
// Parte del flujo: Ajustes → Apariencia → Estilo con cover → Avanzado.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Desplegable "Avanzado" con un slider por componente.
class _SeccionGranular extends StatefulWidget {
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final PreferenciasEstilo prefs;
  final StringsAparienciaEstilo textos;

  const _SeccionGranular({
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.prefs,
    required this.textos,
  });

  @override
  State<_SeccionGranular> createState() => _SeccionGranularState();
}

class _SeccionGranularState extends State<_SeccionGranular> {
  bool _abierto = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.textos;
    final r = widget.r;
    final prefs = widget.prefs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FilaAvanzado(
          titulo: t.estiloAvanzado,
          ayuda: t.estiloAvanzadoAyuda,
          abierto: _abierto,
          glowColor: widget.glowColor,
          onBg: widget.onBg,
          r: r,
          onTap: () => setState(() => _abierto = !_abierto),
        ),
        // Se arma el cuerpo sólo si está abierto: así el bloque no paga por
        // 5 sliders que nadie está mirando.
        if (_abierto) ...[
          SizedBox(height: r.spacingS),
          _nivel(
            t.compCancion,
            t.compCancionAyuda,
            prefs.cardsCancion,
            ComponenteEstilo.cardsCancion,
          ),
          _nivel(
            t.compGrilla,
            t.compGrillaAyuda,
            prefs.cardsGrilla,
            ComponenteEstilo.cardsGrilla,
          ),
          _nivel(
            t.compFondoPrincipal,
            t.compFondoPrincipalAyuda,
            prefs.fondoPrincipal,
            ComponenteEstilo.fondoPrincipal,
          ),
          _nivel(
            t.compFondoReproductor,
            t.compFondoReproductorAyuda,
            prefs.fondoReproductor,
            ComponenteEstilo.fondoReproductor,
          ),
          _nivel(
            t.compModals,
            t.compModalsAyuda,
            prefs.fondosModals,
            ComponenteEstilo.fondosModals,
          ),
        ],
      ],
    );
  }

  /// Una zona: el slider arriba y su explicación abajo, para que no se
  /// apriete en pantallas chicas.
  Widget _nivel(
    String etiqueta,
    String ayuda,
    double valor,
    ComponenteEstilo componente,
  ) {
    final r = widget.r;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Deslizador(
          etiqueta: etiqueta,
          valor: valor,
          maximo: 1,
          // 100 pasos: la barra avanza de a 1%.
          divisiones: 100,
          formato: _porcentaje,
          onChanged: (v) => EstiloHelper.cambiarNivel(context, componente, v),
        ),
        Padding(
          padding: EdgeInsets.only(left: r.width * 0.24),
          child: Text(
            ayuda,
            style: TextStyle(
              fontSize: r.footerSize - 2,
              color: widget.onBg.withValues(alpha: 0.4),
            ),
          ),
        ),
        SizedBox(height: r.spacingXS),
      ],
    );
  }
}
