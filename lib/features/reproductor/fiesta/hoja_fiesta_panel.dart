// ─────────────────────────────────────────────────────────────
// hoja_fiesta_panel.dart — PART de hoja_fiesta.dart: el PANEL de la hoja
// (fondo, márgenes y el orden de las piezas), como función suelta.
//
// Va aparte para que el archivo de la hoja quede con el estado y las acciones,
// y el dibujo en un solo lugar. Acá también se decide qué se muestra según el
// plan: sin prueba de 9 h ni Premium, el modo fiesta explica por qué no entra
// en vez de ofrecer botones que no van a hacer nada.
//
// Se conecta con: hoja_fiesta.dart (su build) + las piezas y los cuerpos.
// Parte del flujo: reproductor → modo fiesta.
// ─────────────────────────────────────────────────────────────

part of 'hoja_fiesta.dart';

/// Dibuja la hoja completa del modo fiesta.
Widget panelFiesta({
  required ServicioFiesta? fiesta,
  required ServicioLan? lan,
  required bool habilitado,
  required bool ocupado,
  required Future<void> Function() onArmar,
  required Future<void> Function(ParLan) onUnirse,
  required Future<void> Function() onCortar,
  required Future<void> Function() onSalir,
}) => Builder(
  builder: (context) {
    final f = AppLocalizations.of(context).fiesta;
    final r = Responsive(context);
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: ColoresApp.superficie(oscuro),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            r.spacingL,
            r.spacingS,
            r.spacingL,
            r.spacingL,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TiradorFiesta(r: r, onBg: ColoresApp.enSuperficie(oscuro)),
              SizedBox(height: r.spacingS),
              _CabeceraFiesta(r: r, oscuro: oscuro),
              SizedBox(height: r.spacingS),
              _AyudaFiesta(
                texto: f.ayuda,
                onBg: ColoresApp.enSuperficieApagado(oscuro),
                r: r,
              ),
              SizedBox(height: r.spacingM),
              if (fiesta == null)
                const Center(child: CircularProgressIndicator(strokeWidth: 2))
              else if (!habilitado)
                _AvisoFiesta(texto: f.premium, r: r, oscuro: oscuro)
              else
                ValueListenableBuilder<ModoFiesta>(
                  valueListenable: fiesta.modo,
                  builder:
                      (_, modo, _) => _CuerpoFiesta(
                        modo: modo,
                        fiesta: fiesta,
                        lan: lan,
                        r: r,
                        oscuro: oscuro,
                        ocupado: ocupado,
                        onArmar: onArmar,
                        onUnirse: onUnirse,
                        onCortar: onCortar,
                        onSalir: onSalir,
                      ),
                ),
              SizedBox(height: r.spacingS),
              _AyudaFiesta(
                texto: f.avisoRed,
                onBg: ColoresApp.enSuperficieTenue(oscuro),
                r: r,
              ),
            ],
          ),
        ),
      ),
    );
  },
);
