// ─────────────────────────────────────────────────────────────
// setup_evento_soulseek.dart — Eventos del bloc de setup ligados al
// alta de la cuenta de Soulseek: iniciar la creación con el nombre
// elegido y recibir el resultado.
//
// setup_evento.dart los re-exporta, así los llamadores siguen
// importando un solo archivo.
// Se conecta con: setup_bloc.dart (maneja los eventos).
// Parte del flujo: setup (alta silenciosa en Soulseek).
// ─────────────────────────────────────────────────────────────

import 'setup_evento.dart';

/// Crea/conecta la cuenta de Soulseek con el nombre que el usuario escribió.
///
/// El nombre viaja EN EL EVENTO (no se lee de la base) porque durante el setup
/// todavía no se persistió: leerlo de ahí devolvía vacío y el alta no se
/// intentaba nunca.
class IniciarSyncSoulseek extends EventoSetup {
  final String usuario;

  const IniciarSyncSoulseek(this.usuario);

  @override
  List<Object?> get props => [usuario];
}

/// Resultado de la creación de la cuenta de Soulseek.
///
/// [motivo] es lo que decide si el setup avanza (`nombre_tomado`,
/// `nombre_invalido`, o vacío). Un nombre tomado o inválido lo tiene que
/// corregir el usuario ANTES de seguir: si no, llegaría al final del setup con
/// una cuenta que no existe y sin saber por qué. Cualquier otro fallo —sin
/// internet, servidor lleno— no bloquea nada.
class SoulseekSyncCompletada extends EventoSetup {
  final bool ok;
  final String mensaje;
  final String motivo;

  const SoulseekSyncCompletada({
    required this.ok,
    this.mensaje = '',
    this.motivo = '',
  });

  /// El usuario puede resolverlo eligiendo otro nombre.
  bool get problemaDeNombre =>
      motivo == 'nombre_tomado' || motivo == 'nombre_invalido';

  @override
  List<Object?> get props => [ok, mensaje, motivo];
}
