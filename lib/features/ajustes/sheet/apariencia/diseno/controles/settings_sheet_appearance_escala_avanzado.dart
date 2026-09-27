// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_escala_avanzado.dart — PART de
// settings_sheet_new.dart: el desplegable "Personalizado" de los TAMAÑOS
// (letras e iconos) del bloque Diseño de Apariencia.
//
// Los dos controles generales ("Tamaño de las letras" y "Tamaño de los
// iconos") mueven TODO junto; acá el usuario los separa por cosa, que es lo
// que hace falta cuando una sola molesta: los títulos se ven chicos pero los
// textos de abajo están bien, o el navbar queda enorme y las cards bien.
//
// Está dividido como el usuario piensa el problema —LETRAS por un lado, ICONOS
// por el otro— y cada grupo tiene sus burbujitas (una por cosa) con el
// deslizador de la elegida abajo. Antes eran cuatro deslizadores seguidos bajo
// dos títulos, y en una pantalla chica no se distinguía dónde empezaba cada
// cosa.
//
// Cada control dice QUÉ modifica, porque "títulos" y "textos secundarios" no
// significan nada hasta que se aclara dónde se ven.
//
// Se multiplica con el general (no lo reemplaza): subir "Letras" sigue
// agrandando los títulos aunque estén afinados acá.
//
// Se conecta con: apariencia_espacios_helper (cambiar cada componente) + la
// fila _FilaAvanzado y el _Deslizador de esta misma library + las burbujitas
// (burbujas_personalizado.dart).
// Parte del flujo: Ajustes → Apariencia → Diseño → Tamaños personalizados.
// ─────────────────────────────────────────────────────────────

part of '../../../settings_sheet_new.dart';

/// Desplegable "Personalizado" de los tamaños: letras e iconos, con una
/// burbujita por cosa.
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

  /// Burbuja elegida en LETRAS: 0 = títulos, 1 = textos secundarios.
  int _letra = 0;

  /// Burbuja elegida en ICONOS: 0 = de las cards, 1 = de las barras.
  int _icono = 0;

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final r = widget.r;
    final prefs = widget.prefs;

    // Texto y ayuda de la burbuja elegida en cada grupo: el deslizador de
    // abajo muestra siempre la cosa que está seleccionada arriba.
    final enLetras = _letra == 0;
    final enCards = _icono == 0;

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
        // El cuerpo se arma sólo si está abierto: el bloque no paga por los
        // deslizadores que nadie está mirando.
        if (_abierto) ...[
          _grupo(t.escalaGrupoLetras),
          BurbujasPersonalizado(
            opciones: [
              OpcionBurbuja(
                icono: Icons.title_rounded,
                etiqueta: t.escalaTitulos,
              ),
              OpcionBurbuja(
                icono: Icons.subject_rounded,
                etiqueta: t.escalaTextos,
              ),
            ],
            seleccionada: _letra,
            onSeleccion: (i) => setState(() => _letra = i),
            glowColor: widget.glowColor,
            onBg: widget.onBg,
            r: r,
          ),
          _control(
            etiqueta: enLetras ? t.escalaTitulos : t.escalaTextos,
            ayuda: enLetras ? t.escalaTitulosAyuda : t.escalaTextosAyuda,
            valor: enLetras ? prefs.escalaTitulos : prefs.escalaTextos,
            onChanged:
                enLetras
                    ? (v) => AparienciaEspacios.cambiarEscalaTitulos(context, v)
                    : (v) => AparienciaEspacios.cambiarEscalaTextos(context, v),
          ),
          SizedBox(height: r.spacingS),
          _grupo(t.escalaGrupoIconos),
          BurbujasPersonalizado(
            opciones: [
              OpcionBurbuja(
                icono: Icons.touch_app_rounded,
                etiqueta: t.escalaIconosCards,
              ),
              OpcionBurbuja(
                icono: Icons.space_bar_rounded,
                etiqueta: t.escalaIconosBarras,
              ),
            ],
            seleccionada: _icono,
            onSeleccion: (i) => setState(() => _icono = i),
            glowColor: widget.glowColor,
            onBg: widget.onBg,
            r: r,
          ),
          _control(
            etiqueta: enCards ? t.escalaIconosCards : t.escalaIconosBarras,
            ayuda:
                enCards ? t.escalaIconosCardsAyuda : t.escalaIconosBarrasAyuda,
            valor: enCards ? prefs.escalaIconosCards : prefs.escalaIconosBarras,
            onChanged:
                enCards
                    ? (v) =>
                        AparienciaEspacios.cambiarEscalaIconosCards(context, v)
                    : (v) => AparienciaEspacios.cambiarEscalaIconosBarras(
                      context,
                      v,
                    ),
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
        letterSpacing: 0.4,
        color: widget.onBg.withValues(alpha: 0.55),
      ),
    ),
  );

  /// El deslizador de la cosa elegida y la línea que explica QUÉ toca.
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
