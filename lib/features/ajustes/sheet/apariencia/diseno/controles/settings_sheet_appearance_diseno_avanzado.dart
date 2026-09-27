// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_diseno_avanzado.dart — PART de
// settings_sheet_new.dart: el desplegable "Personalizado" del bloque
// Diseño de Apariencia.
//
// El control general mueve todo junto; acá el usuario afina POR COSA:
// elige con una burbujita si está tocando las cards de canción o las de
// grilla, y abajo mueve los dos ejes de ESA sola (el horizontal mueve el hueco
// entre columnas Y el margen contra los bordes izq/der; el vertical, el hueco
// entre filas).
//
// Antes esto era una pila de cuatro deslizadores (dos componentes x dos ejes)
// que no se sabía cuál movía qué. Ahora se ve un componente por vez.
//
// Está detrás de un desplegable (cerrado por defecto) para no ensuciar el
// bloque: el 90% usa el control general.
//
// Se conecta con: apariencia_helper (cambiar cada eje) + la fila
// _FilaAvanzado y el _Deslizador de esta misma library + las burbujitas
// (burbujas_personalizado.dart).
// Parte del flujo: Ajustes → Apariencia → Diseño → Personalizado.
// ─────────────────────────────────────────────────────────────

part of '../../../settings_sheet_new.dart';

/// Desplegable "Personalizado": una burbujita por componente y, abajo, sus
/// dos ejes.
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

  /// 0 = cards de canción, 1 = cards de grilla.
  int _componente = 0;

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final r = widget.r;
    final prefs = widget.prefs;
    final cancion = _componente == 0;

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
        // los controles que nadie está mirando.
        if (_abierto) ...[
          SizedBox(height: r.spacingS),
          BurbujasPersonalizado(
            opciones: [
              OpcionBurbuja(
                icono: Icons.music_note_rounded,
                etiqueta: t.avanzadoCancion,
              ),
              OpcionBurbuja(
                icono: Icons.grid_view_rounded,
                etiqueta: t.avanzadoGrilla,
              ),
            ],
            seleccionada: _componente,
            onSeleccion: (i) => setState(() => _componente = i),
            glowColor: widget.glowColor,
            onBg: widget.onBg,
            r: r,
          ),
          SizedBox(height: r.spacingS),
          _Deslizador(
            etiqueta: t.separacionX,
            valor: cancion ? prefs.cancionX : prefs.grillaX,
            maximo: PreferenciasApariencia.maxEspacio,
            onChanged:
                cancion
                    ? (v) => AparienciaEspacios.cambiarCancionX(context, v)
                    : (v) => AparienciaEspacios.cambiarGrillaX(context, v),
          ),
          _Deslizador(
            etiqueta: t.separacionY,
            valor: cancion ? prefs.cancionY : prefs.grillaY,
            maximo: PreferenciasApariencia.maxEspacio,
            onChanged:
                cancion
                    ? (v) => AparienciaEspacios.cambiarCancionY(context, v)
                    : (v) => AparienciaEspacios.cambiarGrillaY(context, v),
          ),
        ],
      ],
    );
  }
}
