// ─────────────────────────────────────────────────────────────
// hoja_fiesta_cuerpos.dart — PART de hoja_fiesta.dart: el cuerpo de la hoja
// según en qué esté la fiesta.
//
// Tres caras: apagada (armar el parlante acá o sumarse a uno de la lista),
// mandando (quiénes están sonando, con el botón de cortar) y siguiendo (qué
// suena, si el tiempo está alineado, con el botón de salir).
//
// Se conecta con: hoja_fiesta_panel.dart (lo monta) + las acciones y piezas.
// Parte del flujo: reproductor → modo fiesta.
// ─────────────────────────────────────────────────────────────

part of 'hoja_fiesta.dart';

/// El cuerpo de la hoja según el modo de la fiesta.
class _CuerpoFiesta extends StatelessWidget {
  final ModoFiesta modo;
  final ServicioFiesta fiesta;
  final ServicioLan? lan;
  final Responsive r;
  final bool oscuro;
  final bool ocupado;
  final Future<void> Function() onArmar;
  final Future<void> Function(ParLan) onUnirse;
  final Future<void> Function() onCortar;
  final Future<void> Function() onSalir;

  const _CuerpoFiesta({
    required this.modo,
    required this.fiesta,
    required this.lan,
    required this.r,
    required this.oscuro,
    required this.ocupado,
    required this.onArmar,
    required this.onUnirse,
    required this.onCortar,
    required this.onSalir,
  });

  /// Aparatos ya vinculados que podrían ser el que manda la fiesta.
  List<ParLan> get _candidatos => lan?.pares.value
          .where((p) => p.vinculado && p.host.isNotEmpty)
          .toList(growable: false) ??
      const [];

  @override
  Widget build(BuildContext context) {
    final f = AppLocalizations.of(context).fiesta;
    if (modo == ModoFiesta.apagado) {
      final candidatos = _candidatos;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BotonFiesta(
            texto: f.arrancar,
            icono: Icons.nightlife_rounded,
            ocupado: ocupado,
            onTap: onArmar,
          ),
          SizedBox(height: r.spacingM),
          if (candidatos.isEmpty)
            _AvisoFiesta(texto: f.sinOtros, r: r, oscuro: oscuro)
          else ...[
            Text(
              f.invitados,
              style: TextStyle(
                fontSize: r.footerSize,
                fontWeight: FontWeight.w700,
                color: ColoresApp.enSuperficie(oscuro),
              ),
            ),
            SizedBox(height: r.spacingXS),
            for (final par in candidatos)
              _FilaUnirse(
                par: par,
                r: r,
                oscuro: oscuro,
                ocupado: ocupado,
                onUnirse: () => onUnirse(par),
              ),
          ],
        ],
      );
    }
    // Mandando: se ve quiénes están sonando y cómo cortarlo.
    if (modo == ModoFiesta.host) {
      return ValueListenableBuilder<List<String>>(
        valueListenable: fiesta.juntos,
        builder:
            (_, unidos, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AvisoFiesta(texto: f.unidos(unidos.length), r: r, oscuro: oscuro),
                SizedBox(height: r.spacingS),
                _ChipsUnidos(nombres: unidos, r: r, oscuro: oscuro),
                SizedBox(height: r.spacingM),
                _BotonFiesta(
                  texto: f.cortar,
                  icono: Icons.stop_circle_outlined,
                  ocupado: ocupado,
                  onTap: onCortar,
                ),
              ],
            ),
      );
    }
    // Siguiendo a otro aparato: qué suena y si el tiempo está alineado.
    return ValueListenableBuilder<FiestaEstado>(
      valueListenable: fiesta.ultimoEstado,
      builder:
          (_, estado, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (estado.hayPista)
                Text(
                  f.suena(estado.titulo),
                  style: TextStyle(
                    fontSize: r.footerSize,
                    fontWeight: FontWeight.w700,
                    color: ColoresApp.enSuperficie(oscuro),
                  ),
                ),
              SizedBox(height: r.spacingXS),
              ValueListenableBuilder<bool>(
                valueListenable: fiesta.ajustando,
                builder:
                    (_, ajustando, _) => _AvisoFiesta(
                      texto: ajustando ? f.ajustando : f.sincronizado,
                      r: r,
                      oscuro: oscuro,
                    ),
              ),
              SizedBox(height: r.spacingM),
              _BotonFiesta(
                texto: f.salir,
                icono: Icons.logout_rounded,
                ocupado: ocupado,
                onTap: onSalir,
              ),
            ],
          ),
    );
  }
}

