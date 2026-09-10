// ─────────────────────────────────────────────────────────────
// servicio_foco_audio.dart — Gestiona la sesión de audio del SO
// (audio focus en Android / AVAudioSession en iOS) y pausa la
// reproducción cuando otra app toma el audio. Reglas: foco al
// reproducir y se libera al pausar; pérdida permanente → pausar y
// quedarse pausado; interrupción transitoria → duck de volumen y
// reanudar al volver el foco; auriculares desconectados → pausar.
// Se conecta con: audio_session + PlayerCubit (estado).
// Parte del flujo: reproducción (concurrencia con otras apps).
// ─────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:audio_session/audio_session.dart';

/// Contrato mínimo que el reproductor (CubitReproductor) debe exponer para
/// que el foco de audio pueda pausar/reanudar. Evita que esta capa de
/// plataforma dependa del cubit concreto.
abstract class ControladorReproductor {
  Stream<bool> get streamReproduciendo;
  bool get estaReproduciendoAhora;
  void pausar();
  void reproducir();
}

/// Dueño de la sesión de audio de la plataforma.
class ServicioFocoAudio {
  ServicioFocoAudio._();

  static final ServicioFocoAudio instance = ServicioFocoAudio._();

  bool _inicializado = false;
  bool _pausadoPorInterrupcion = false;

  /// Se inyecta el controlador del reproductor (se registra en el arranque,
  /// después de que GetIt esté listo).
  ControladorReproductor? _controlador;
  set controlador(ControladorReproductor? c) => _controlador = c;

  /// Escucha el estado de reproducción + interrupciones de plataforma.
  /// Es seguro llamarlo más de una vez.
  Future<void> init() async {
    if (_inicializado) return;
    _inicializado = true;

    try {
      final sesion = await AudioSession.instance;

      // Stream de interrupciones: otra app pidió la salida de audio.
      sesion.interruptionEventStream.listen(_alInterrumpir);

      // Auriculares desconectados / BT desconectado mientras reproduce.
      sesion.becomingNoisyEventStream.listen((_) {
        if (_pausadoPorInterrupcion) return;
        _pausadoPorInterrupcion = true;
        _controlador?.pausar();
      });

      // Refleja el estado real de reproducción en la sesión: el foco se
      // mantiene mientras reproduce y se libera al pausar.
      _controlador?.streamReproduciendo.listen((reproduciendo) {
        unawaited(reproduciendo
            ? sesion.setActive(true).catchError((_) => false)
            : sesion.setActive(false).catchError((_) => false));
      });
    } catch (_) {
      // audio_session no disponible en esta plataforma — la reproducción
      // sigue funcionando, solo se omite la pausa automática por otra app.
      _inicializado = false;
    }
  }

  void _alInterrumpir(AudioInterruptionEvent evento) {
    final controlador = _controlador;
    if (controlador == null) return;
    if (evento.begin) {
      switch (evento.type) {
        case AudioInterruptionType.duck:
          // Duck: baja volumen en vez de pausar (el plugin audio_session
          // gestiona el ducking automático en Android). Permite música de
          // fondo mientras el usuario interactúa con apps transitorias.
          break;
        case AudioInterruptionType.pause:
          // Pausa transitoria (nota de voz, alarma, navegación). Pausa
          // rápido y reanuda automáticamente cuando vuelve el foco.
          if (!_pausadoPorInterrupcion && controlador.estaReproduciendoAhora) {
            _pausadoPorInterrupcion = true;
            controlador.pausar();
          }
        case AudioInterruptionType.unknown:
          // Pérdida permanente — otro player tomó el control. Pausa y NO
          // auto-reanuda (el usuario cambió de app a propósito).
          _pausadoPorInterrupcion = false;
          if (controlador.estaReproduciendoAhora) controlador.pausar();
      }
    } else {
      // Foco recuperado. Reanuda si estábamos pausados por interrupción
      // transitoria (no por pérdida permanente).
      final debeReanudar = _pausadoPorInterrupcion &&
          evento.type != AudioInterruptionType.unknown;
      _pausadoPorInterrupcion = false;
      if (debeReanudar && !controlador.estaReproduciendoAhora) {
        // Pequeño delay para que el otro audio termine su transición.
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!controlador.estaReproduciendoAhora) controlador.reproducir();
        });
      }
    }
  }
}