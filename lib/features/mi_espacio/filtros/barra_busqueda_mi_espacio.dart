// ─────────────────────────────────────────────────────────────
// barra_busqueda_mi_espacio.dart — Barra de búsqueda con debounce
// para Mi Espacio: filtra ítems por título, subtítulo o fuente.
// El debounce (400ms) evita repintar en cada tecla.
//
// El CONTROLADOR no es de acá: lo presta la página (pagina_mi_espacio.dart).
// Si viviera en este widget, cerrar el acordeón —que desmonta la barra— lo
// destruía y con él el texto escrito, así que la búsqueda se perdía por
// plegar y desplegar el panel. Con el controlador de la página, el texto
// sigue ahí al volver a abrirlo.
//
// Se conecta con: pagina_mi_espacio.dart (dueño del controlador).
// Parte del flujo: Home → Mi Espacio → búsqueda en tiempo real.
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';

import '../../../shared/utilidades/plataforma/responsive.dart';

/// Barra de búsqueda compacta con debounce y botón de limpiar.
class BarraBusquedaMiEspacio extends StatefulWidget {
  /// Controlador del texto (de la página, para que sobreviva al acordeón).
  final TextEditingController controller;
  final ValueChanged<String> onBusquedaCambiada;
  final String hintText;
  final Color onBg;

  const BarraBusquedaMiEspacio({
    super.key,
    required this.controller,
    required this.onBusquedaCambiada,
    required this.onBg,
    this.hintText = 'Buscar...',
  });

  @override
  State<BarraBusquedaMiEspacio> createState() => _BarraBusquedaMiEspacioState();
}

class _BarraBusquedaMiEspacioState extends State<BarraBusquedaMiEspacio> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    // El controlador lo cierra quien lo creó (la página).
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      widget.onBusquedaCambiada(value.trim().toLowerCase());
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final onBg = widget.onBg;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: r.spacingS,
        vertical: r.spacingXS,
      ),
      // La barra escucha su propio texto: el botón de limpiar tiene que
      // aparecer en cuanto se escribe (y desaparecer en cuanto se vacía), no
      // cuando a otro widget se le ocurra repintar la fila.
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: widget.controller,
        builder:
            (context, valor, _) => TextField(
              controller: widget.controller,
              onChanged: _onChanged,
              style: TextStyle(fontSize: r.footerSize, color: onBg),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  fontSize: r.footerSize,
                  color: onBg.withValues(alpha: 0.35),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: r.footerSize + 4,
                  color: onBg.withValues(alpha: 0.4),
                ),
                suffixIcon:
                    valor.text.isNotEmpty
                        ? IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            size: r.footerSize + 2,
                            color: onBg.withValues(alpha: 0.4),
                          ),
                          // Limpiar también CANCELA el debounce: si no, el
                          // filtro que estaba por aplicarse volvía a caer
                          // después de borrar el texto.
                          onPressed: () {
                            _debounce?.cancel();
                            widget.controller.clear();
                            widget.onBusquedaCambiada('');
                          },
                        )
                        : null,
                filled: true,
                fillColor: onBg.withValues(alpha: 0.05),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: r.spacingM,
                  vertical: r.spacingXS,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: onBg.withValues(alpha: 0.08),
                    width: 0.8,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: onBg.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
            ),
      ),
    );
  }
}
