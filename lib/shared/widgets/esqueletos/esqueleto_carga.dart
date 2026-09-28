// ─────────────────────────────────────────────────────────────
// esqueleto_carga.dart — Esqueletos de carga shimmer (animación
// de gradiente pulsante sobre formas placeholder) para dar un
// feel premium mientras cargan los datos. Aquí viven el bloque
// base EsqueletoCarga, el esqueleto de feed completo y el de
// detalle (portada circular + fila). La fila animada vive en el
// part esqueleto_fila.dart y la variante de búsqueda en
// esqueleto_busqueda.dart.
//
// También viven acá EsqueletoEtiqueta y EsqueletoMarca: el mismo
// shimmer pero con la FORMA de lo que va a aparecer en el hueco
// (el texto de un botón, el valor de una fila, la marca de un
// tile). Son la alternativa a dejar un círculo girando en el
// medio de un espacio que ya se sabe cómo va a quedar.
// Se conecta con: nada (solo tema del context).
// Parte del flujo: feed, detalle, búsqueda y acciones de Ajustes (loading).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../utilidades/plataforma/pantalla/efectos_app.dart';
import '../../utilidades/plataforma/responsive.dart';

part 'esqueleto_fila.dart';

/// Bloque shimmer base: gradiente pulsante sobre una forma redondeada.
class EsqueletoCarga extends StatefulWidget {
  final double ancho;
  final double alto;
  final double radioBorde;

  /// Color del bloque. En `null` sale del tema (blanco al 6% sobre fondo
  /// oscuro, negro al 5% sobre claro), que es lo correcto casi siempre.
  /// Se pasa cuando el hueco NO está sobre el fondo sino sobre un color
  /// (un botón relleno): ahí el blanco al 6% no se vería.
  final Color? color;

  /// Color del brillo que barre el gradiente. Misma idea que [color].
  final Color? colorBrillo;

  const EsqueletoCarga({
    super.key,
    this.ancho = double.infinity,
    this.alto = 16,
    this.radioBorde = 8,
    this.color,
    this.colorBrillo,
  });

  @override
  State<EsqueletoCarga> createState() => _EsqueletoCargaState();
}

class _EsqueletoCargaState extends State<EsqueletoCarga>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    // Gama baja (y modo fluido): sin shimmer. Cada esqueleto visible tendría su
    // propio controller repintando un gradiente en CADA frame; con 8 filas eso
    // solo ya come la GPU y es lo que hacía sentir la lista "trabada".
    // Se escuchan TODOS los interruptores de efectos (perfil, monitor y modo
    // fluido), así activar el modo fluido lo deja quieto al instante.
    EfectosApp.cambiosEfectos.addListener(_sincronizarShimmer);
    _sincronizarShimmer();
  }

  void _sincronizarShimmer() {
    if (!mounted) return;
    final animar = EfectosApp.desenfoqueActivo;
    if (animar) {
      if (!_ctrl.isAnimating) _ctrl.repeat();
    } else if (_ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 0;
    }
    setState(() {});
  }

  @override
  void dispose() {
    EfectosApp.cambiosEfectos.removeListener(_sincronizarShimmer);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final base =
        widget.color ??
        (oscuro
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.05));
    final brillo =
        widget.colorBrillo ??
        (oscuro
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.08));
    final estatico = !EfectosApp.desenfoqueActivo;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Container(
          width: widget.ancho,
          height: widget.alto,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radioBorde),
            color: estatico ? base : null,
            gradient:
                estatico
                    ? null
                    : LinearGradient(
                      begin: Alignment(-1.0 + 2.0 * _ctrl.value, 0),
                      end: Alignment(-0.5 + 2.0 * _ctrl.value, 0),
                      colors: [base, brillo, base],
                      stops: const [0.0, 0.5, 1.0],
                    ),
          ),
        );
      },
    );
  }
}

/// Bloque con la forma de una ETIQUETA: el texto de un botón, el valor de una
/// fila, una línea de título. Se usa en el hueco que hoy ocupa un spinner, para
/// que el lugar se vea como lo que está por llegar y no como un círculo suelto.
class EsqueletoEtiqueta extends StatelessWidget {
  final double ancho;
  final double alto;

  /// Radio de las esquinas. En `null` es una pastilla (la mitad del alto);
  /// un botón con esquinas de 8 px pasa las suyas para no cambiar de forma.
  final double? radioBorde;

  /// `true` cuando el hueco va encima de un color (un botón relleno verde o
  /// rojo): el shimmer del tema es blanco al 6% y ahí desaparecería.
  final bool sobreColor;

  const EsqueletoEtiqueta({
    super.key,
    this.ancho = double.infinity,
    this.alto = 14,
    this.radioBorde,
    this.sobreColor = false,
  });

  @override
  Widget build(BuildContext context) => EsqueletoCarga(
    ancho: ancho,
    alto: alto,
    radioBorde: radioBorde ?? alto / 2,
    color: sobreColor ? Colors.white.withValues(alpha: 0.22) : null,
    colorBrillo: sobreColor ? Colors.white.withValues(alpha: 0.4) : null,
  );
}

/// Bloque con la forma de una MARCA: el icono, el tilde, el candado o el badge
/// que va en ese hueco.
class EsqueletoMarca extends StatelessWidget {
  final double lado;

  /// Radio de las esquinas. En `null`, un cuadrado apenas redondeado; para un
  /// badge redondo se pasa la mitad del lado.
  final double? radioBorde;

  /// Misma idea que en [EsqueletoEtiqueta].
  final bool sobreColor;

  const EsqueletoMarca({
    super.key,
    required this.lado,
    this.radioBorde,
    this.sobreColor = false,
  });

  @override
  Widget build(BuildContext context) => EsqueletoCarga(
    ancho: lado,
    alto: lado,
    radioBorde: radioBorde ?? lado * 0.3,
    color: sobreColor ? Colors.white.withValues(alpha: 0.22) : null,
    colorBrillo: sobreColor ? Colors.white.withValues(alpha: 0.4) : null,
  );
}

/// Esqueleto de página completa para feed / carga de listas.
class EsqueletoFeed extends StatelessWidget {
  const EsqueletoFeed({super.key});

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final base =
        oscuro
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.05);
    final brillo =
        oscuro
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.08);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 8,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final esTrack = index % 3 != 2;
        return _FilaEsqueleto(esTrack: esTrack, base: base, brillo: brillo);
      },
    );
  }
}

/// Esqueleto centrado para páginas de detalle (álbum, playlist, artista).
class EsqueletoDetalle extends StatelessWidget {
  const EsqueletoDetalle({super.key});

  @override
  Widget build(BuildContext context) {
    // La separación sigue al aparato: en la TV el bloque de carga queda con
    // el aire del resto de la interfaz, no con un hueco fijo de celular.
    final r = Responsive(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EsqueletoCarga(
            ancho: r.val(180, 150, 300),
            alto: r.val(180, 150, 300),
            radioBorde: 90,
          ),
          SizedBox(height: r.spacingXL),
          EsqueletoCarga(
            ancho: r.val(260, 210, 420),
            alto: r.val(220, 180, 360),
            radioBorde: 16,
          ),
        ],
      ),
    );
  }
}
