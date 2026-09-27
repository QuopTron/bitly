// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_granular.dart — PART de settings_sheet_new.dart:
// los controles PERSONALIZADOS del estilo con cover, uno por zona.
//
// Están detrás de un desplegable para no ensuciar el bloque: el 90% de la
// gente usa el control general y el que quiere afinar abre esto y deja, por
// ejemplo, las cards con color y los fondos en Normal.
//
// Cada zona tiene su burbujita (con su ícono y su nombre) y abajo queda el
// deslizador de la elegida, con la línea que explica dónde se ve. Antes eran
// cinco deslizadores apilados: entre el nombre y el de al lado no se sabía
// cuál estaba moviendo.
//
// Se conecta con: estilo_helper (cambiar cada nivel) +
// settings_sheet_appearance_style.dart (lo monta) + las burbujitas
// (burbujas_personalizado.dart).
// Parte del flujo: Ajustes → Apariencia → Estilo con cover → Personalizado.
// ─────────────────────────────────────────────────────────────

part of '../../../settings_sheet_new.dart';

/// Una zona del estilo: con qué se la nombra, dónde se ve, cuánto tiene ahora
/// y a quién hay que pedirle el cambio.
class _ZonaEstilo {
  final String etiqueta;
  final String ayuda;
  final double valor;
  final IconData icono;
  final ComponenteEstilo componente;

  const _ZonaEstilo({
    required this.etiqueta,
    required this.ayuda,
    required this.valor,
    required this.icono,
    required this.componente,
  });
}

/// Desplegable "Personalizado" con una burbujita por zona.
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

  /// Burbuja elegida: el orden es el mismo de las zonas del estilo.
  int _zona = 0;

  /// Las cinco zonas del estilo, en el mismo orden que las burbujitas.
  List<_ZonaEstilo> get _zonas {
    final t = widget.textos;
    final p = widget.prefs;
    return [
      _ZonaEstilo(
        etiqueta: t.compCancion,
        ayuda: t.compCancionAyuda,
        valor: p.cardsCancion,
        icono: Icons.music_note_rounded,
        componente: ComponenteEstilo.cardsCancion,
      ),
      _ZonaEstilo(
        etiqueta: t.compGrilla,
        ayuda: t.compGrillaAyuda,
        valor: p.cardsGrilla,
        icono: Icons.grid_view_rounded,
        componente: ComponenteEstilo.cardsGrilla,
      ),
      _ZonaEstilo(
        etiqueta: t.compFondoPrincipal,
        ayuda: t.compFondoPrincipalAyuda,
        valor: p.fondoPrincipal,
        icono: Icons.wallpaper_rounded,
        componente: ComponenteEstilo.fondoPrincipal,
      ),
      _ZonaEstilo(
        etiqueta: t.compFondoReproductor,
        ayuda: t.compFondoReproductorAyuda,
        valor: p.fondoReproductor,
        icono: Icons.play_circle_outline_rounded,
        componente: ComponenteEstilo.fondoReproductor,
      ),
      _ZonaEstilo(
        etiqueta: t.compModals,
        ayuda: t.compModalsAyuda,
        valor: p.fondosModals,
        icono: Icons.layers_rounded,
        componente: ComponenteEstilo.fondosModals,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final zonas = _zonas;
    final zona = _zona.clamp(0, zonas.length - 1);
    final elegida = zonas[zona];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FilaAvanzado(
          titulo: widget.textos.estiloAvanzado,
          ayuda: widget.textos.estiloAvanzadoAyuda,
          abierto: _abierto,
          glowColor: widget.glowColor,
          onBg: widget.onBg,
          r: r,
          onTap: () => setState(() => _abierto = !_abierto),
        ),
        // Se arma el cuerpo sólo si está abierto: así el bloque no paga por
        // los controles que nadie está mirando.
        if (_abierto) ...[
          SizedBox(height: r.spacingS),
          BurbujasPersonalizado(
            opciones: [
              for (final z in zonas)
                OpcionBurbuja(icono: z.icono, etiqueta: z.etiqueta),
            ],
            seleccionada: zona,
            onSeleccion: (i) => setState(() => _zona = i),
            glowColor: widget.glowColor,
            onBg: widget.onBg,
            r: r,
          ),
          SizedBox(height: r.spacingS),
          // La zona elegida: su deslizador arriba y dónde se ve, abajo.
          _Deslizador(
            etiqueta: elegida.etiqueta,
            valor: elegida.valor,
            maximo: 1,
            // 100 pasos: la barra avanza de a 1%.
            divisiones: 100,
            formato: _porcentaje,
            onChanged:
                (v) =>
                    EstiloHelper.cambiarNivel(context, elegida.componente, v),
          ),
          Padding(
            padding: EdgeInsets.only(left: r.width * 0.24),
            child: Text(
              elegida.ayuda,
              style: TextStyle(
                fontSize: r.footerSize - 2,
                color: widget.onBg.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
