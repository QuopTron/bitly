// ─────────────────────────────────────────────────────────────
// catalogo_disenos_barra_desbloqueo.dart — CUÁNDO se abre un diseño del
// cofre: la lectura de la versión de la app y la comparación con las horas
// de escucha.
//
// Va aparte de catalogo_disenos_barra.dart (que describe qué ES un diseño)
// para que cada archivo haga una sola cosa: este responde "¿ya lo puedo
// usar?". La lista lo reexporta, así que alcanza con importarla.
//
// Se conecta con: catalogo_disenos_barra.dart (el modelo) +
// catalogo_disenos_barra_lista.dart (lo usa para contar regalos).
// Parte del flujo: Ajustes → Apariencia → Barras → Cofre.
// ─────────────────────────────────────────────────────────────

import '../base/catalogo_disenos_barra.dart';

/// Convierte "0.9.22" (o "0.9.22+3") al número comparable 922.
/// Cualquier cosa ilegible devuelve 0, que desbloquea solo lo libre.
int versionEnNumero(String? version) {
  if (version == null || version.isEmpty) return 0;
  final limpio = version.split('+').first.trim();
  final partes = limpio.split('.');
  if (partes.length < 3) return 0;
  final mayor = int.tryParse(partes[0]);
  final menor = int.tryParse(partes[1]);
  final parche = int.tryParse(partes[2]);
  if (mayor == null || menor == null || parche == null) return 0;
  return mayor * 10000 + menor * 100 + parche;
}

/// 922 → "0.9.22" (para los textos del cofre).
String versionLegible(int numero) {
  final mayor = numero ~/ 10000;
  final menor = (numero ~/ 100) % 100;
  final parche = numero % 100;
  return '$mayor.$menor.$parche';
}

/// ¿El diseño [d] ya se puede usar, con [horas] acumuladas y la app en
/// [version] (ver [versionEnNumero])?
bool disenoDesbloqueado(
  DisenoBarra d, {
  required int horas,
  required int version,
}) {
  switch (d.desbloqueo) {
    case DesbloqueoBarra.libre:
      return true;
    case DesbloqueoBarra.horas:
      return horas >= d.valor;
    case DesbloqueoBarra.version:
      // Si no se pudo leer la versión (0) no se desbloquea nada por
      // versión: mejor que el usuario no vea un regalo fantasma.
      return version > 0 && version >= d.valor;
  }
}
