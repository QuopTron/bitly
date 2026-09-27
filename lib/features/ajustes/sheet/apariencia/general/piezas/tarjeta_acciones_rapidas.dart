// ─────────────────────────────────────────────────────────────
// tarjeta_acciones_rapidas.dart — Burbuja "Acciones rápidas" de
// Ajustes → Apariencia: una fila por gesto (deslizar a los cuatro
// lados y dos toques) con el selector de qué hace ese gesto sobre una
// canción.
//
// Es un widget propio y no una PART de settings_sheet_new porque no
// necesita nada del estado de la hoja: la tarjeta se lee sola de la
// caché, guarda sola y avisa por el notifier (ver
// acciones_rapidas.dart), que es lo que hace que las tarjetas ya
// pintadas cambien en el momento.
//
// Se conecta con: ajustes_acciones_rapidas (datos) + cache_ajustes
// (persistencia) + inyeccion (sl) + l10n.
// Parte del flujo: Ajustes → Apariencia → acciones rápidas.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../../../../app/inyeccion/inyeccion.dart';
import '../../../../../../core/cache/almacenes/sistema/cache_ajustes.dart';
import '../../../../../../core/modelos/ajustes_acciones_rapidas.dart';
import '../../../../../../l10n/app_localizations.dart';
import '../../../../../../shared/tema/colores_app.dart';
import '../../../../../../shared/utilidades/plataforma/responsive.dart';

/// Tarjeta de configuración de los gestos de las tarjetas de canción.
class TarjetaAccionesRapidas extends StatelessWidget {
  final Color glowColor;
  final Color onBg;
  final Responsive r;

  const TarjetaAccionesRapidas({
    super.key,
    required this.glowColor,
    required this.onBg,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final t = loc.accionesRapidas;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.spacingM),
      decoration: BoxDecoration(
        color: onBg.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: onBg.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.touch_app_rounded, size: r.footerSize * 1.3, color: glowColor),
              SizedBox(width: r.spacingS),
              Expanded(
                child: Text(
                  t.titulo,
                  style: TextStyle(
                    fontSize: r.subtitleSize,
                    fontWeight: FontWeight.w700,
                    color: onBg,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: r.spacingXS),
          Text(
            t.ayuda,
            style: TextStyle(
              fontSize: r.footerSize,
              color: onBg.withValues(alpha: 0.55),
              height: 1.4,
            ),
          ),
          SizedBox(height: r.spacingS),
          // ValueListenableBuilder: la tarjeta se redibuja sola cuando el
          // notifier cambia (y así el selector muestra siempre lo guardado).
          ValueListenableBuilder<AjustesAccionesRapidas>(
            valueListenable: accionesRapidas,
            builder: (context, actual, _) => Column(
              children: [
                _FilaGesto(
                  icono: Icons.swipe_right_rounded,
                  etiqueta: t.gestoDerecha,
                  valor: actual.derecha,
                  onBg: onBg,
                  r: r,
                  onElegir: (a) => _guardar(actual.conGesto(AjustesAccionesRapidas.claveDerecha, a)),
                ),
                _FilaGesto(
                  icono: Icons.swipe_left_rounded,
                  etiqueta: t.gestoIzquierda,
                  valor: actual.izquierda,
                  onBg: onBg,
                  r: r,
                  onElegir: (a) => _guardar(actual.conGesto(AjustesAccionesRapidas.claveIzquierda, a)),
                ),
                _FilaGesto(
                  icono: Icons.swipe_up_rounded,
                  etiqueta: t.gestoArriba,
                  valor: actual.arriba,
                  onBg: onBg,
                  r: r,
                  onElegir: (a) => _guardar(actual.conGesto(AjustesAccionesRapidas.claveArriba, a)),
                ),
                _FilaGesto(
                  icono: Icons.swipe_down_rounded,
                  etiqueta: t.gestoAbajo,
                  valor: actual.abajo,
                  onBg: onBg,
                  r: r,
                  onElegir: (a) => _guardar(actual.conGesto(AjustesAccionesRapidas.claveAbajo, a)),
                ),
                _FilaGesto(
                  icono: Icons.ads_click_rounded,
                  etiqueta: t.gestoDobleToque,
                  valor: actual.dobleToque,
                  onBg: onBg,
                  r: r,
                  onElegir: (a) => _guardar(actual.conGesto(AjustesAccionesRapidas.claveDobleToque, a)),
                ),
              ],
            ),
          ),
          SizedBox(height: r.spacingXS),
          Text(
            t.ayudaVertical,
            style: TextStyle(
              fontSize: r.footerSize - 1,
              color: onBg.withValues(alpha: 0.4),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  /// Guarda y avisa a las tarjetas. El notifier se actualiza ANTES de
  /// escribir en disco: el cambio se ve al instante y la escritura es
  /// best-effort (si falla, igual queda aplicado en esta sesión).
  Future<void> _guardar(AjustesAccionesRapidas nuevos) async {
    accionesRapidas.value = nuevos;
    try {
      await nuevos.guardar(sl<CacheAjustes>());
    } catch (e) {
      debugPrint('[AccionesRapidas] no se pudo guardar: $e');
    }
  }
}

/// Una fila: gesto a la izquierda, acción elegida a la derecha.
class _FilaGesto extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final AccionRapida valor;
  final Color onBg;
  final Responsive r;
  final ValueChanged<AccionRapida> onElegir;

  const _FilaGesto({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    required this.onBg,
    required this.r,
    required this.onElegir,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.spacingXS * 0.5),
      child: Row(
        children: [
          Icon(icono, size: r.footerSize * 1.2, color: onBg.withValues(alpha: 0.6)),
          SizedBox(width: r.spacingS),
          Expanded(
            child: Text(
              etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: r.footerSize, color: onBg.withValues(alpha: 0.8)),
            ),
          ),
          // Dropdown y no un diálogo: son cinco filas y el usuario quiere
          // compararlas de un vistazo, con el valor puesto a la vista.
          DropdownButtonHideUnderline(
            child: DropdownButton<AccionRapida>(
              value: valor,
              isDense: true,
              borderRadius: BorderRadius.circular(12),
              dropdownColor: ColoresApp.superficie(
                Theme.of(context).brightness == Brightness.dark,
              ),
              style: TextStyle(fontSize: r.footerSize),
              onChanged: (a) {
                if (a != null) onElegir(a);
              },
              items: [
                for (final a in AccionRapida.values)
                  DropdownMenuItem<AccionRapida>(
                    value: a,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_iconoDe(a), size: r.footerSize, color: onBg.withValues(alpha: 0.7)),
                        SizedBox(width: r.spacingXS),
                        Text(_textoDe(a, loc)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Nombre visible de cada acción (l10n).
  String _textoDe(AccionRapida a, AppLocalizations loc) {
    final t = loc.accionesRapidas;
    switch (a) {
      case AccionRapida.ninguna:
        return t.ninguna;
      case AccionRapida.agregarCola:
        return t.agregarCola;
      case AccionRapida.meGusta:
        return t.meGusta;
      case AccionRapida.descargar:
        return t.descargar;
      case AccionRapida.compartir:
        return t.compartir;
      case AccionRapida.info:
        return t.info;
      case AccionRapida.irAlbum:
        return t.irAlbum;
      case AccionRapida.quitarMiEspacio:
        return t.quitarMiEspacio;
    }
  }

  /// Icono de cada acción, para reconocerla sin leer.
  static IconData _iconoDe(AccionRapida a) {
    switch (a) {
      case AccionRapida.ninguna:
        return Icons.block_rounded;
      case AccionRapida.agregarCola:
        return Icons.queue_music_rounded;
      case AccionRapida.meGusta:
        return Icons.favorite_rounded;
      case AccionRapida.descargar:
        return Icons.download_rounded;
      case AccionRapida.compartir:
        return Icons.share_rounded;
      case AccionRapida.info:
        return Icons.info_outline_rounded;
      case AccionRapida.irAlbum:
        return Icons.album_rounded;
      case AccionRapida.quitarMiEspacio:
        return Icons.remove_circle_outline_rounded;
    }
  }
}
