// ─────────────────────────────────────────────────────────────
// release_notas_vista.dart — Dibuja las notas de una release como se leen:
// el título de cada sección y sus viñetas, con el destacado en negrita
// separado del resto.
//
// Qué arregla: la hoja de versiones (y la de actualización) mostraban el
// markdown crudo del changelog dentro de un `Text` recortado a 3 líneas. El
// resultado era un párrafo corrido con almohadillas y asteriscos —imposible de
// leer y encima con el texto en español y en inglés pegados—. Acá cada
// novedad queda en su renglón, con su puntito y su título en negrita, y la
// lista se puede abrir para ver el resto.
//
// Es un widget público (no una PART de la hoja) porque lo usan DOS librarys:
// la hoja de versiones (Ajustes → Más) y la hoja de actualización.
//
// Se conecta con: release_notas.dart (el parser) + strings_actualizacion
// ("Ver todo" / "Ver menos").
// Parte del flujo: Ajustes → Versión (novedades).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import 'release_notas.dart';

/// Las novedades de una release, ya formateadas.
///
/// Con [colapsable] (por defecto) muestra las primeras [maxItems] viñetas y
/// ofrece "Ver todo"; sin él dibuja todo lo que haya (para la hoja de
/// actualización, que ya tiene su propio alto acotado).
class NotasReleaseVista extends StatefulWidget {
  /// Cuerpo de la release, en markdown.
  final String cuerpo;

  /// Versión de la release (sirve para descartar el encabezado repetido).
  final String version;

  /// Color del texto de las viñetas.
  final Color colorTexto;

  /// Color del título de cada sección.
  final Color colorTitulo;

  /// Color del puntito de cada viñeta.
  final Color colorPunto;

  /// Tamaño base del texto.
  final double tamano;

  /// Cuántas viñetas se ven sin abrir "Ver todo".
  final int maxItems;

  /// ¿Se puede abrir y cerrar el detalle?
  final bool colapsable;

  const NotasReleaseVista({
    super.key,
    required this.cuerpo,
    required this.colorTexto,
    required this.colorTitulo,
    required this.colorPunto,
    required this.tamano,
    this.version = '',
    this.maxItems = 3,
    this.colapsable = true,
  });

  @override
  State<NotasReleaseVista> createState() => _NotasReleaseVistaState();
}

class _NotasReleaseVistaState extends State<NotasReleaseVista> {
  bool _abierto = false;

  @override
  Widget build(BuildContext context) {
    final notas = NotasRelease.parsear(
      widget.cuerpo,
      esEspanol: _esEspanol(context),
      version: widget.version,
    );
    if (notas.vacias) return const SizedBox.shrink();

    final recorta = widget.colapsable && notas.total > widget.maxItems;
    final abierto = _abierto && recorta;
    var restantes = abierto ? 1 << 30 : widget.maxItems;

    final hijos = <Widget>[];
    for (final bloque in notas.bloques) {
      if (restantes <= 0) break;
      final items = bloque.items.take(restantes).toList();
      if (items.isEmpty && bloque.titulo.isEmpty) continue;
      restantes -= items.length;

      if (hijos.isNotEmpty) hijos.add(SizedBox(height: widget.tamano * 0.5));
      if (bloque.titulo.isNotEmpty) {
        hijos.add(
          Padding(
            padding: EdgeInsets.only(bottom: widget.tamano * 0.18),
            child: Text(
              bloque.titulo,
              style: TextStyle(
                fontSize: widget.tamano - 1,
                fontWeight: FontWeight.w800,
                color: widget.colorTitulo,
                letterSpacing: 0.1,
              ),
            ),
          ),
        );
      }
      for (final item in items) {
        hijos.add(
          Padding(
            padding: EdgeInsets.only(top: widget.tamano * 0.18),
            child: _vineta(item),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...hijos,
        if (recorta) ...[
          SizedBox(height: widget.tamano * 0.3),
          _BotonVerTodo(
            texto:
                abierto
                    ? AppLocalizations.of(context).update.verMenos
                    : AppLocalizations.of(context).update.verTodo,
            color: widget.colorTitulo,
            tamano: widget.tamano,
            onTap: () => setState(() => _abierto = !_abierto),
          ),
        ],
      ],
    );
  }

  /// Una viñeta: el puntito, el título en negrita (si venía) y el resto.
  Widget _vineta(ItemNotas item) {
    final texto =
        item.texto.isEmpty
            ? item.titulo
            : (item.titulo.isEmpty
                ? item.texto
                : '${item.titulo}: ${item.texto}');
    final corte = item.titulo.isEmpty ? 0 : item.titulo.length;
    // El puntito acompaña al tamaño del texto (sale de Responsive, vía
    // [tamano]): en la tele queda proporcionado en vez de diminuto.
    final punto = (widget.tamano * 0.42).clamp(3.0, 9.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: punto, right: punto + 4),
          child: Container(
            width: punto,
            height: punto,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.colorPunto,
            ),
          ),
        ),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: widget.tamano,
                color: widget.colorTexto,
                height: 1.35,
              ),
              children: [
                if (corte > 0)
                  TextSpan(
                    text: texto.substring(0, corte),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                TextSpan(text: texto.substring(corte)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// El idioma de la app decide qué mitad de las notas se muestra: el cuerpo
  /// trae primero el español y después el inglés.
  static bool _esEspanol(BuildContext context) => Localizations.localeOf(
    context,
  ).languageCode.toLowerCase().startsWith('es');
}

/// "Ver todo" / "Ver menos": abre y cierra el resto de las novedades.
class _BotonVerTodo extends StatelessWidget {
  final String texto;
  final Color color;
  final double tamano;
  final VoidCallback onTap;

  const _BotonVerTodo({
    required this.texto,
    required this.color,
    required this.tamano,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          // Área de toque cómoda sin agrandar el texto.
          padding: EdgeInsets.symmetric(vertical: tamano * 0.34),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.unfold_more_rounded, size: tamano + 2, color: color),
              SizedBox(width: tamano * 0.34),
              Text(
                texto,
                style: TextStyle(
                  fontSize: tamano,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
