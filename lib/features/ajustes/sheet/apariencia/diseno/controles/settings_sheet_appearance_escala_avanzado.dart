// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_escala_avanzado.dart — PART de
// settings_sheet_new.dart: el desplegable "Avanzado" de los TAMAÑOS
// (letras e iconos) del bloque Diseño de Apariencia.
//
// Los dos controles generales ("Tamaño de las letras" y "Tamaño de los
// iconos") mueven TODO junto; acá el usuario los separa por componente, que es
// lo que hace falta cuando una sola cosa molesta: los títulos se ven chicos
// pero los textos de abajo están bien, o el navbar queda enorme y las tarjetas
// bien.
//
// Cada control dice QUÉ modifica, porque "títulos" y "textos secundarios" no
// significan nada hasta que se aclara dónde se ven.
//
// Se multiplica con el general (no lo reemplaza): subir "Letras" sigue
// agrandando los títulos aunque estén afinados acá.
//
// Se conecta con: apariencia_espacios_helper (cambiar cada componente) + la
// fila _FilaAvanzado y el _Deslizador de esta misma library.
// Parte del flujo: Ajustes → Apariencia → Diseño → Tamaños avanzados.
// ─────────────────────────────────────────────────────────────

part of '../../../settings_sheet_new.dart';

/// Desplegable "Avanzado" de los tamaños: letras e iconos por componente.
class _SeccionAvanzadoEscala extends StatefulWidget {
  final PreferenciasApariencia prefs;
  final StringsApariencia t;
  final Color glowColor;
  final Color onBg;
  final Responsive r;

  const _SeccionAvanzadoEscala({
    required this.prefs,
    required this.t,
    required this.glowColor,
    required this.onBg,
    required this.r,
  });

  @override
  State<_SeccionAvanzadoEscala> createState() => _SeccionAvanzadoEscalaState();
}

class _SeccionAvanzadoEscalaState extends State<_SeccionAvanzadoEscala> {
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
          titulo: t.escalaAvanzadoTitulo,
          ayuda: t.escalaAvanzadoAyuda,
          abierto: _abierto,
          glowColor: widget.glowColor,
          onBg: widget.onBg,
          r: r,
          onTap: () => setState(() => _abierto = !_abierto),
        ),
        // El cuerpo se arma sólo si está abierto: el bloque no paga por cuatro
        // deslizadores que nadie está mirando.
        if (_abierto) ...[
          SizedBox(height: r.spacingS),
          _grupo(t.escalaGrupoLetras),
          _control(
            etiqueta: t.escalaTitulos,
            ayuda: t.escalaTitulosAyuda,
            valor: prefs.escalaTitulos,
            onChanged:
                (v) => AparienciaEspacios.cambiarEscalaTitulos(context, v),
          ),
          _control(
            etiqueta: t.escalaTextos,
            ayuda: t.escalaTextosAyuda,
            valor: prefs.escalaTextos,
            onChanged:
                (v) => AparienciaEspacios.cambiarEscalaTextos(context, v),
          ),
          SizedBox(height: r.spacingS),
          _grupo(t.escalaGrupoIconos),
          _control(
            etiqueta: t.escalaIconosCards,
            ayuda: t.escalaIconosCardsAyuda,
            valor: prefs.escalaIconosCards,
            onChanged:
                (v) => AparienciaEspacios.cambiarEscalaIconosCards(context, v),
          ),
          _control(
            etiqueta: t.escalaIconosBarras,
            ayuda: t.escalaIconosBarrasAyuda,
            valor: prefs.escalaIconosBarras,
            onChanged:
                (v) => AparienciaEspacios.cambiarEscalaIconosBarras(context, v),
          ),
        ],
      ],
    );
  }

  /// Título de grupo ("Letras" / "Iconos").
  Widget _grupo(String titulo) => Padding(
    padding: EdgeInsets.only(top: widget.r.spacingXS),
    child: Text(
      titulo,
      style: TextStyle(
        fontSize: widget.r.footerSize - 2,
        fontWeight: FontWeight.w700,
        color: widget.onBg.withValues(alpha: 0.55),
      ),
    ),
  );

  /// Un componente: su deslizador y la línea que explica QUÉ toca.
  Widget _control({
    required String etiqueta,
    required String ayuda,
    required double valor,
    required ValueChanged<double> onChanged,
  }) {
    final r = widget.r;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Deslizador(
          etiqueta: etiqueta,
          valor: valor,
          minimo: PreferenciasApariencia.minEscala,
          maximo: PreferenciasApariencia.maxEscala,
          divisiones: 11,
          formato: (v) => '${(v * 100).round()}%',
          onChanged: onChanged,
        ),
        Padding(
          padding: EdgeInsets.only(left: r.width * 0.24, top: 2),
          child: Text(
            ayuda,
            style: TextStyle(
              fontSize: r.footerSize - 2,
              color: widget.onBg.withValues(alpha: 0.4),
            ),
          ),
        ),
      ],
    );
  }
}
