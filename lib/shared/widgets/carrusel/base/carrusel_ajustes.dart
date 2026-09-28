// ─────────────────────────────────────────────────────────────
// carrusel_ajustes.dart — Carrusel de ajustes: las tarjetas de una sección,
// una por pantalla, con aviso de girar, contador y puntos.
//
// Por qué existe: cada pestaña de Ajustes era una columna larga (Apariencia
// llegó a tener nueve tarjetas apiladas), así que para llegar a la última había
// que bajar una barbaridad y no se sabía cuánto faltaba. Acá los ajustes se
// GIRAN: se ve uno por vez, con un contador ("3 de 9") que dice exactamente
// cuánto queda.
//
// Vive en `shared` y no dentro de la hoja de Ajustes porque el mismo gesto
// sirve en cualquier sección de tarjetas (Ajustes, onboarding, tutorial): no
// tiene nada de Ajustes adentro, sólo páginas.
//
// Tres decisiones que hacen que esto no moleste:
//   · CADA página scrollea sola (su `PageStorageKey` le guarda la posición): en
//     una tarjeta alta se sigue bajando normal, y al volver a ella se vuelve
//     donde estaba;
//   · hay FLECHAS además del gesto. En la tele y con el mouse no hay "deslizar",
//     y un carrusel que sólo se maneja con el dedo es un carrusel roto en la PC;
//   · con UNA sola página no se dibuja nada del carrusel (ni flechas ni puntos):
//     no hay nada que girar, y mostrarlo igual sería ruido.
//
// Se conecta con: haptico + responsive + l10n (tab `ajustes`).
// Parte del flujo: Ajustes (todas las pestañas).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../utilidades/interaccion/haptico.dart';
import '../../../utilidades/plataforma/responsive.dart';

/// Carrusel de ajustes: las tarjetas de una sección, una por pantalla.
class CarruselAjustes extends StatefulWidget {
  /// Las tarjetas, en orden. Una página cada una.
  final List<Widget> paginas;
  final Color glowColor;
  final Color onBg;
  final Responsive r;

  /// Rótulo del bloque, para el lector de pantalla y para los puntos (cada
  /// punto dice a qué ajuste lleva).
  final String etiqueta;

  const CarruselAjustes({
    super.key,
    required this.paginas,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.etiqueta,
  });

  @override
  State<CarruselAjustes> createState() => _CarruselAjustesState();
}

class _CarruselAjustesState extends State<CarruselAjustes> {
  final PageController _control = PageController();

  /// Página que se está viendo. Se guarda acá y no se lee del controller para
  /// que los puntos y el contador repinten aunque el gesto no haya terminado.
  int _pagina = 0;

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  /// Va a la página [i] con la misma animación que el gesto.
  void _irA(int i) {
    if (i < 0 || i >= widget.paginas.length) return;
    Haptico.tap();
    _control.animateToPage(
      i,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Una sola tarjeta: es la sección de siempre, sin carrusel.
    if (widget.paginas.length < 2) {
      return _pantalla(
        widget.paginas.isEmpty ? const SizedBox() : widget.paginas.first,
        0,
      );
    }
    final r = widget.r;
    return Column(
      children: [
        _barra(),
        Expanded(
          child: PageView.builder(
            controller: _control,
            itemCount: widget.paginas.length,
            onPageChanged: (i) => setState(() => _pagina = i),
            itemBuilder: (_, i) => _pantalla(widget.paginas[i], i),
          ),
        ),
        SizedBox(height: r.spacingXS),
        _puntos(),
        SizedBox(height: r.spacingS),
      ],
    );
  }

  /// Una página: scrolleable y con su propia posición guardada.
  Widget _pantalla(Widget child, int i) => SingleChildScrollView(
    key: PageStorageKey<String>('ajustes-pagina-$i'),
    padding: EdgeInsets.fromLTRB(
      widget.r.spacingL,
      0,
      widget.r.spacingL,
      widget.r.spacingL,
    ),
    child: child,
  );

  /// La barra de arriba: flecha, el aviso de girar, el contador y flecha.
  ///
  /// El aviso es lo que hace que el carrusel se descubra: sin él, el usuario ve
  /// un ajuste, no ve el resto y se queda con la mitad de Ajustes.
  Widget _barra() {
    final r = widget.r;
    final loc = AppLocalizations.of(context);
    final t = loc.ajustes;
    final hayAntes = _pagina > 0;
    final hayDespues = _pagina < widget.paginas.length - 1;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        r.spacingS,
        r.spacingXS,
        r.spacingS,
        r.spacingXS,
      ),
      child: Row(
        children: [
          _flecha(
            key: const ValueKey('carrusel-anterior'),
            icono: Icons.chevron_left_rounded,
            activa: hayAntes,
            onTap: () => _irA(_pagina - 1),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.swipe_rounded,
                  size: r.footerSize + 2,
                  color: widget.glowColor.withValues(
                    alpha: hayDespues ? 0.9 : 0.35,
                  ),
                ),
                SizedBox(width: r.spacingXS),
                Flexible(
                  child: Text(
                    t.girar,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: r.footerSize - 1,
                      fontWeight: FontWeight.w600,
                      color: widget.onBg.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            t.deTotal(_pagina + 1, widget.paginas.length),
            style: TextStyle(
              fontSize: r.footerSize - 1,
              fontWeight: FontWeight.w700,
              color: widget.onBg.withValues(alpha: 0.7),
            ),
          ),
          _flecha(
            key: const ValueKey('carrusel-siguiente'),
            icono: Icons.chevron_right_rounded,
            activa: hayDespues,
            onTap: () => _irA(_pagina + 1),
          ),
        ],
      ),
    );
  }

  /// Una flecha del carrusel (también hace falta en la PC y en la tele).
  ///
  /// Lleva clave propia (`carrusel-anterior` / `carrusel-siguiente`) porque el
  /// ícono de la flecha es el MISMO que usan un montón de tarjetas adentro: sin
  /// clave, "la flecha de este carrusel" no se puede distinguir de una flecha
  /// decorativa de una fila, y el tutorial (y las pruebas) agarraban la que no
  /// era.
  Widget _flecha({
    required Key key,
    required IconData icono,
    required bool activa,
    required VoidCallback onTap,
  }) => GestureDetector(
    key: key,
    behavior: HitTestBehavior.opaque,
    onTap: activa ? onTap : null,
    child: Padding(
      padding: EdgeInsets.all(widget.r.spacingXS),
      child: Icon(
        icono,
        size: widget.r.subtitleSize,
        // Apagada, no escondida: así se ve que hay más para ese lado sin poder
        // "girar al vacío".
        color: widget.onBg.withValues(alpha: activa ? 0.75 : 0.2),
      ),
    ),
  );

  /// Los puntos: dicen cuántos ajustes hay y llevan a cualquiera de ellos.
  Widget _puntos() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < widget.paginas.length; i++)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _irA(i),
          child: Semantics(
            label: '${widget.etiqueta} ${i + 1}',
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 3, vertical: 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: i == _pagina ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color:
                      i == _pagina
                          ? widget.glowColor
                          : widget.onBg.withValues(alpha: 0.22),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
