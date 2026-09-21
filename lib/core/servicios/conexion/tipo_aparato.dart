// ─────────────────────────────────────────────────────────────
// tipo_aparato.dart — ¿Qué tipo de aparato es ESTA copia de la app?
//
// Se usa una sola vez, para que el aparato se registre solo en la burbuja
// Conexión con el tipo correcto (PC, celu o TV). Si el sistema no alcanza
// para decidir, queda `extra`, que es justo el cuarto lugar de la cuenta.
//
// Se conecta con: deteccion_plataforma (layout por plataforma) +
// servicio_conexion (registro del aparato propio).
// Parte del flujo: Ajustes → Conexión (alta del aparato).
// ─────────────────────────────────────────────────────────────

import '../../../shared/utilidades/plataforma/deteccion_plataforma.dart';
import '../../../shared/utilidades/plataforma/deteccion_tv.dart'
    show esTelevisor;
import '../../modelos/usuario/dispositivo_conectado.dart';

/// El tipo de ESTE aparato, sin necesidad de contexto de UI.
///
/// Se fija por plataforma y no por ancho de pantalla: una ventana de
/// escritorio achicada sigue siendo una PC, y una TV angosta sigue siendo
/// una TV.
TipoDispositivo tipoDeEsteAparato() {
  if (esEscritorio()) return TipoDispositivo.pc;
  if (esMovil()) {
    // Dato del sistema (Android TV / Google TV / Fire TV reportan ser
    // Android): sin esto una tele se registraría como celular.
    return esTelevisor ? TipoDispositivo.tv : TipoDispositivo.celu;
  }
  // Web u otra plataforma rara: cae al lugar extra en vez de mentir.
  return TipoDispositivo.extra;
}
