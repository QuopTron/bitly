// ─────────────────────────────────────────────────────────────
// reproductor_avance_seguro.dart — PART de cubit_reproductor.dart:
// red de seguridad del FIN DE CANCIÓN. Un `completed` puede
// descartarse (evento espurio de media_kit, media reemplazado por un
// open más nuevo, generación sin confirmar) y entonces la canción
// termina, el player queda detenido y la siguiente NO suena aunque la
// cola esté llena. Acá se revisa a los pocos segundos si de verdad no
// hay nada sonando y, solo en ese caso, se avanza la cola.
// Dos garantías: (1) la cola nunca queda muda cuando hay siguiente y
// (2) una pausa del usuario jamás dispara el avance: la revisión solo
// se agenda desde un `completed` real del player.
// Se conecta con: reproductor_completado.dart (misma library).
// Parte del flujo: reproducción (fin de canción → siguiente).
// ─────────────────────────────────────────────────────────────

part of 'cubit_reproductor.dart';

/// Red de seguridad del avance de cola. Mixin aplicado en CubitReproductor,
/// justo entre limpieza y los guards de completación.
mixin ReproductorAvanceSeguro on ReproductorLimpieza {
  /// Avanza la cola por fin de canción — la implementación concreta vive en
  /// ReproductorCompletado (arriba en la cadena); declaración para la
  /// revisión diferida.
  Future<void> _avanzarColaDesdeCompletado();

  /// Número de revisión en curso: solo la última agendada puede ejecutarse
  /// (evita que varios `completed` seguidos acumulen timers y avancen de más).
  int _revisionAvance = 0;

  /// Espera antes de la revisión: da tiempo a que un open en vuelo confirme
  /// arranque (si suena, la revisión no hace nada).
  static const Duration _esperaRevisionAvance = Duration(seconds: 2);

  /// Agenda la revisión de seguridad tras descartar un `completed`.
  ///
  /// [motivo] solo se usa para el log. La revisión es conservadora: exige que
  /// el MISMO track siga de actual, que no haya un open en vuelo
  /// (`_generacionAbiertaEn` sin confirmar), que no haya un switch resolviendo
  /// y que el player esté realmente detenido fuera del final.
  void _agendarAvanceSeguro(String motivo) {
    final gen = _generacionOpen;
    final id = _idActualNormalizado();
    final revision = ++_revisionAvance;
    unawaited(
      Future<void>.delayed(_esperaRevisionAvance, () async {
        if (isClosed || revision != _revisionAvance) return;
        if (_generacionOpen != gen) return; // otro track ya abrió
        if (_generacionAbiertaEn != _generacionOpen) return; // open en vuelo
        if (_switchPendiente) return; // resolviendo otro track
        if (_idActualNormalizado() != id) return; // la cola ya avanzó
        if (_player.reproduciendo) return; // sigue sonando: nada que hacer
        if (state.estadoReproduccion == EstadoReproduccion.buffering) return;
        final cola = _queueCubit.state;
        if (!cola.tieneActual || cola.tracks.isEmpty) return;
        // A mitad de canción y detenido: es una pausa, no un fin de track.
        final dur = state.duracion;
        final pos = _player.posicion;
        if (dur > Duration.zero &&
            dur - pos > const Duration(seconds: 3) &&
            pos > Duration.zero) {
          return;
        }
        debugPrint(
          '[Player] fin de canción sin avance ($motivo) — la cola tiene '
          '${cola.tracks.length} pistas, avanzando.',
        );
        await _avanzarColaDesdeCompletado();
      }),
    );
  }
}
