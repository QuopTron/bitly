// ─────────────────────────────────────────────────────────────
// barra_busqueda.dart — Barra de búsqueda con vidrio: campo de
// texto con hint por fuente (del manifest), icono/trigger de
// selector de fuente como prefijo y botón de limpiar como sufijo
// cuando hay texto. Los chips de categoría viven en
// chips_tipo_busqueda.dart.
// Se conecta con: l10n + responsive + vidrio + colores_app +
// acordeon_fuente (selector de extensión dentro de la barra).
// Parte del flujo: búsqueda (entrada del usuario).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/tema/colores_app.dart';
import '../../../shared/utilidades/responsive.dart';
import '../../../shared/widgets/contenedor_vidrio.dart';

/// Campo de búsqueda con vidrio y selector de fuente como prefijo.
class BarraBusqueda extends StatefulWidget {
  final TextEditingController controlador;
  final ValueChanged<String> onTextoCambiado;
  final VoidCallback onLimpiar;

  /// Hint por fuente (p.ej. "Buscar en Deezer..." del manifest). Cuando es
  /// null se usa el hint genérico localizado.
  final String? hintTexto;

  /// El trigger del selector de fuente renderizado donde iba el icono de
  /// búsqueda (lo reemplaza). Al tocarlo abre el picker de extensiones.
  final Widget? triggerFuente;

  const BarraBusqueda({
    super.key,
    required this.controlador,
    required this.onTextoCambiado,
    required this.onLimpiar,
    this.hintTexto,
    this.triggerFuente,
  });

  @override
  State<BarraBusqueda> createState() => _BarraBusquedaState();
}

class _BarraBusquedaState extends State<BarraBusqueda> {
  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(esOscuro);

    return ContenedorVidrio(
      borderRadius: 14,
      borderColor: onBg.withValues(alpha: 0.08),
      margin: EdgeInsets.fromLTRB(r.spacingS, r.spacingS, r.spacingS, 0),
      padding: EdgeInsets.symmetric(horizontal: r.spacingM),
      child: TextField(
        controller: widget.controlador,
        onChanged: widget.onTextoCambiado,
        style: TextStyle(fontSize: r.subtitleSize + 3, color: onBg),
        decoration: InputDecoration(
          hintText: widget.hintTexto ??
              AppLocalizations.of(context).setup.searchHint,
          hintStyle: TextStyle(
            fontSize: r.subtitleSize + 3,
            color: onBg.withValues(alpha: 0.3),
          ),
          border: InputBorder.none,
          prefixIcon: widget.triggerFuente ??
              Icon(
                Icons.search,
                size: r.footerSize + 5,
                color: onBg.withValues(alpha: 0.5),
              ),
          suffixIcon: widget.controlador.text.isNotEmpty
              ? GestureDetector(
                  onTap: widget.onLimpiar,
                  child: Icon(
                    Icons.clear,
                    size: r.footerSize + 5,
                    color: onBg.withValues(alpha: 0.3),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}