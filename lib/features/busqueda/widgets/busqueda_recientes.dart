// ─────────────────────────────────────────────────────────────
// busqueda_recientes.dart — Lista de búsquedas recientes con
// cabecera (icono de historial + limpiar todo) y cada búsqueda en
// una tarjeta de vidrio con tap para re-buscar y botón para
// quitarla individualmente.
// Se conecta con: contenedor_vidrio + l10n + responsive.
// Parte del flujo: búsqueda (vista inicial con historial).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/tema/colores_app.dart';
import '../../../shared/utilidades/responsive.dart';
import '../../../shared/widgets/contenedor_vidrio.dart';

/// Lista de búsquedas recientes del usuario.
class ListaBusquedasRecientes extends StatelessWidget {
  final List<String> busquedas;
  final ValueChanged<String> onBusquedaTocada;
  final VoidCallback onLimpiarTodas;
  final ValueChanged<String> onQuitar;

  const ListaBusquedasRecientes({
    super.key,
    required this.busquedas,
    required this.onBusquedaTocada,
    required this.onLimpiarTodas,
    required this.onQuitar,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(esOscuro);
    final loc = AppLocalizations.of(context);

    return ListView(
      padding: EdgeInsets.fromLTRB(
          r.spacingS, r.spacingM, r.spacingS, r.spacingS + r.val(120, 100, 150)),
      children: [
        Row(
          children: [
            Icon(Icons.history,
                size: r.footerSize + 4, color: onBg.withValues(alpha: 0.5)),
            SizedBox(width: r.spacingXS),
            Text(
              loc.setup.recentSearches,
              style: TextStyle(
                fontSize: r.subtitleSize + 3,
                fontWeight: FontWeight.bold,
                color: onBg,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onLimpiarTodas,
              child: Text(
                loc.setup.clear,
                style: TextStyle(
                  fontSize: r.footerSize,
                  color: onBg.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: r.spacingM),
        ...busquedas.map((q) => Padding(
              padding: EdgeInsets.only(bottom: r.spacingXS),
              child: GestureDetector(
                onTap: () => onBusquedaTocada(q),
                child: ContenedorVidrio(
                  borderRadius: 12,
                  borderColor: onBg.withValues(alpha: 0.06),
                  bgColor: onBg.withValues(alpha: 0.02),
                  padding: EdgeInsets.symmetric(
                      horizontal: r.spacingM, vertical: r.spacingS),
                  child: Row(
                    children: [
                      Icon(Icons.search,
                          size: r.footerSize + 4,
                          color: onBg.withValues(alpha: 0.3)),
                      SizedBox(width: r.spacingM),
                      Expanded(
                        child: Text(
                          q,
                          style: TextStyle(
                            fontSize: r.subtitleSize,
                            color: onBg.withValues(alpha: 0.7),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => onQuitar(q),
                        child: Icon(Icons.close,
                            size: r.footerSize,
                            color: onBg.withValues(alpha: 0.2)),
                      ),
                    ],
                  ),
                ),
              ),
            )),
      ],
    );
  }
}