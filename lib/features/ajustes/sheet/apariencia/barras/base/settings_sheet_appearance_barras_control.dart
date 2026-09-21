// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_barras_control.dart — PART de
// settings_sheet_new.dart: el CONTROL de la barra que se está editando.
//
// Es un solo deslizador, pero cambia de significado con el diseño del cofre:
//   · esquinas → mueve el redondeo de las dos esquinas de arriba (lo de
//                siempre, de recto a pastilla)
//   · OLAS     → el borde de arriba ondula y el control da MÁS o MENOS olas
// Así un diseño de adorno no necesita que el usuario siga pensando en curvas.
//
// Va aparte de _barras para que el archivo de la tarjeta siga corto.
//
// Se conecta con: settings_sheet_appearance_barras.dart (misma library) +
// apariencia_disenos_helper + el deslizador compartido.
// Parte del flujo: Ajustes → Apariencia → Barras.
// ─────────────────────────────────────────────────────────────

part of '../../../settings_sheet_new.dart';

/// ¿La barra elegida tiene el adorno de OLAS puesto?
bool _barrasTieneOlas(BuildContext context, {required bool navbar}) =>
    AparienciaDisenos.adornoDe(context, navbar: navbar) == AdornoBarra.olas;

/// El deslizador de la barra elegida: esquinas de arriba u olas.
Widget _controlBarra(
  BuildContext context, {
  required bool navbar,
  required PreferenciasApariencia prefs,
  required StringsApariencia t,
}) {
  if (_barrasTieneOlas(context, navbar: navbar)) {
    return _Deslizador(
      etiqueta: t.barras.olas,
      valor: AparienciaDisenos.intensidadOlas(context, navbar: navbar),
      maximo: PreferenciasApariencia.maxOlas,
      // El número de la derecha es CUÁNTAS olas se van a ver.
      formato: (v) => '${PreferenciasApariencia.olasDe(v)}',
      divisiones: 4,
      onChanged: (v) => _cambiarOlas(context, navbar: navbar, valor: v),
    );
  }
  return _Deslizador(
    etiqueta: t.barras.esquinasArriba,
    valor: navbar ? prefs.radioNavbar : prefs.radioMiniplayer,
    maximo: PreferenciasApariencia.maxRadioBarra,
    onChanged:
        (v) =>
            navbar
                ? AparienciaBarras.cambiarRadioNavbar(context, v)
                : AparienciaBarras.cambiarRadioMiniplayer(context, v),
  );
}

/// Mueve la intensidad de las olas de la barra elegida.
void _cambiarOlas(
  BuildContext context, {
  required bool navbar,
  required double valor,
}) {
  final p = AparienciaHelper.actual(context);
  AparienciaHelper.cambiar(
    context,
    navbar
        ? p.copiarCon(olasNavbar: valor)
        : p.copiarCon(olasMiniplayer: valor),
  );
}
