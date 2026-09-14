// El alta de la cuenta de Soulseek ocurre durante el setup, con el nombre que
// el usuario acaba de elegir. Lo que fija este test es la regla completa:
//
//   * un nombre TOMADO bloquea: el usuario se entera en el mismo paso donde lo
//     puede corregir, y no pasa de largo hacia el final del setup;
//   * un fallo que el usuario NO puede resolver (sin internet, servidor lleno)
//     NO bloquea: la bienvenida no depende de Soulseek.
//
// El servicio se inyecta falso: el alta real pega contra la red y el servidor
// de Soulseek, así que no se puede disparar desde un test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bitly/core/servicios/proveedores/servicio_soulseek.dart';
import 'package:bitly/features/setup/bloc/setup_bloc.dart';
import 'package:bitly/features/setup/bloc/setup_estado.dart';
import 'package:bitly/features/setup/bloc/setup_evento.dart';

/// Cliente de Soulseek falso: devuelve lo que el test decide, sin tocar la red.
class _SoulseekFalso extends ServicioSoulseek {
  final ResultadoSoulseek respuesta;
  final List<String> nombresRecibidos = [];

  _SoulseekFalso(this.respuesta);

  @override
  Future<ResultadoSoulseek> crearOConectar(String usuarioEscrito) async {
    nombresRecibidos.add(usuarioEscrito);
    return respuesta;
  }
}

ResultadoSoulseek _tomado() => const ResultadoSoulseek(
      ok: false,
      mensaje: 'ese nombre ya está tomado en la red: elegí otro',
      motivo: MotivoSoulseek.nombreTomado,
    );

ResultadoSoulseek _sinRed() => const ResultadoSoulseek(
      ok: false,
      mensaje: 'no se pudo conectar al servidor',
      motivo: MotivoSoulseek.ninguno,
    );

/// Lleva el bloc hasta el paso de nombre y toca Siguiente con [nombre].
Future<SetupBloc> _llegarAlPasoDeNombre(
  _SoulseekFalso falso, {
  String nombre = 'pablo_bz',
}) async {
  final bloc = SetupBloc(ValueNotifier(const Locale('es')), soulseek: falso);
  bloc.add(const ChequearDatosExistentes());
  await bloc.stream.firstWhere((s) => s.paso == PasoSetup.idioma);
  bloc.add(const SiguientePaso());
  await bloc.stream.firstWhere((s) => s.paso == PasoSetup.usuario);
  bloc.add(UsuarioCambiado(nombre));
  bloc.add(const SiguientePaso());
  return bloc;
}

void main() {
  test('con el nombre libre el setup avanza y la cuenta queda lista', () async {
    final falso = _SoulseekFalso(const ResultadoSoulseek(
      ok: true,
      mensaje: 'Cuenta conectada y lista para buscar en la red.',
      usuario: 'pablo_bz',
      password: 'clave',
      passwordGenerada: true,
    ));
    final bloc = await _llegarAlPasoDeNombre(falso);
    addTearDown(bloc.close);

    final listo = await bloc.stream
        .firstWhere((s) => s.syncSoulseek == SyncSoulseek.listo)
        .timeout(const Duration(seconds: 5));

    expect(listo.paso, PasoSetup.googleSignIn);
    expect(falso.nombresRecibidos, ['pablo_bz'],
        reason: 'se crea con el nombre que el usuario escribió, no con otro');
  });

  test('con el nombre TOMADO no avanza y se le pide que elija otro', () async {
    final falso = _SoulseekFalso(_tomado());
    final bloc = await _llegarAlPasoDeNombre(falso);
    addTearDown(bloc.close);

    final rechazado = await bloc.stream
        .firstWhere((s) => s.syncSoulseek == SyncSoulseek.fallo)
        .timeout(const Duration(seconds: 5));

    expect(rechazado.paso, PasoSetup.usuario,
        reason: 'tiene que quedarse en el paso del nombre para corregirlo');
    expect(rechazado.motivoSoulseek, 'nombre_tomado');
    expect(rechazado.mensajeSoulseek, isNotEmpty);
  });

  test('un nombre inválido también bloquea', () async {
    final falso = _SoulseekFalso(const ResultadoSoulseek(
      ok: false,
      mensaje: 'no es válido: solo ASCII imprimible',
      motivo: MotivoSoulseek.nombreInvalido,
    ));
    final bloc = await _llegarAlPasoDeNombre(falso, nombre: 'pabloé');
    addTearDown(bloc.close);

    final rechazado = await bloc.stream
        .firstWhere((s) => s.syncSoulseek == SyncSoulseek.fallo)
        .timeout(const Duration(seconds: 5));

    expect(rechazado.paso, PasoSetup.usuario);
    expect(rechazado.motivoSoulseek, 'nombre_invalido');
  });

  test('sin internet el setup NO se frena', () async {
    final falso = _SoulseekFalso(_sinRed());
    final bloc = await _llegarAlPasoDeNombre(falso);
    addTearDown(bloc.close);

    final fallo = await bloc.stream
        .firstWhere((s) => s.syncSoulseek == SyncSoulseek.fallo)
        .timeout(const Duration(seconds: 5));

    expect(fallo.paso, PasoSetup.googleSignIn,
        reason: 'un fallo de red no puede dejar al usuario pegado en el setup');
    expect(fallo.motivoSoulseek, isEmpty);
  });

  test('sin nombre no se inventa una cuenta', () async {
    final falso = _SoulseekFalso(_sinRed());
    final bloc = await _llegarAlPasoDeNombre(falso, nombre: '   ');
    addTearDown(bloc.close);

    final rechazado = await bloc.stream
        .firstWhere((s) => s.syncSoulseek == SyncSoulseek.fallo)
        .timeout(const Duration(seconds: 5));

    expect(rechazado.paso, PasoSetup.usuario);
    expect(falso.nombresRecibidos, isEmpty,
        reason: 'sin nombre no se llama al servicio');
  });

  test('sin pasar por el paso de nombre el alta queda inactiva', () async {
    final falso = _SoulseekFalso(_sinRed());
    final bloc = SetupBloc(ValueNotifier(const Locale('es')), soulseek: falso);
    addTearDown(bloc.close);

    bloc.add(const ChequearDatosExistentes());
    await bloc.stream.firstWhere((s) => s.paso == PasoSetup.idioma);

    expect(bloc.state.syncSoulseek, SyncSoulseek.inactivo);
    expect(falso.nombresRecibidos, isEmpty);
  });
}
