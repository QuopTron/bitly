// ─────────────────────────────────────────────────────────────
// indicador_red_etiqueta.dart — PART de indicador_red.dart: etiqueta
// legible del tipo de conexión (wifi, móvil, ethernet, otra, ninguna).
// Se conecta con: indicador_red.dart (misma library) + l10n (StringsRed).
// Parte del flujo: Home → barra superior → detalle de red (etiqueta).
// ─────────────────────────────────────────────────────────────

part of 'indicador_red.dart';

// Etiqueta legible del tipo de conexión.
String etiquetaTipoRed(AppLocalizations loc, TipoRed tipo) {
  switch (tipo) {
    case TipoRed.wifi:
      return loc.red.typeWifi;
    case TipoRed.movil:
      return loc.red.typeMobile;
    case TipoRed.ethernet:
      return loc.red.typeEthernet;
    case TipoRed.otra:
      return loc.red.typeOther;
    case TipoRed.ninguna:
      return loc.red.typeNone;
  }
}
