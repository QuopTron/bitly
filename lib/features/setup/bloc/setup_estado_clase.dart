// ─────────────────────────────────────────────────────────────
// setup_estado_clase.dart — PART de setup_estado.dart: la clase
// EstadoSetup (campos del flujo de bienvenida, copiarCon para emitir
// cambios y props para equatable). Los enums PasoSetup y SyncSoulseek
// quedan en el padre.
// Se conecta con: setup_bloc.dart (estado del bloc) + l10n.
// Parte del flujo: setup (estado del flujo de bienvenida).
// ─────────────────────────────────────────────────────────────

part of 'setup_estado.dart';

/// Estado del flujo de setup.
class EstadoSetup extends Equatable {
  final PasoSetup paso;
  final String idiomaSeleccionado;
  final String usuario;
  final bool googleConectado;
  final String? modoSeleccionado;
  final String codigoPremium;
  final bool guardando;
  final bool validandoCodigo;
  final bool codigoValido;
  final String? errorCodigo;
  final bool? tieneDatosExistentes;
  final bool? continuarConExistentes;
  final String? modoExistente;
  final String? idiomaExistente;
  final String? usuarioExistente;
  final bool trialExistenteExpirado;
  final String? trialExistenteIniciadoEn;
  final String? trialExistenteExpiraEn;
  final SyncSoulseek syncSoulseek;
  final String mensajeSoulseek;
  final String motivoSoulseek;

  const EstadoSetup({
    this.paso = PasoSetup.chequeandoExistente,
    this.idiomaSeleccionado = 'es',
    this.usuario = '',
    this.googleConectado = false,
    this.modoSeleccionado,
    this.codigoPremium = '',
    this.guardando = false,
    this.validandoCodigo = false,
    this.codigoValido = false,
    this.errorCodigo,
    this.tieneDatosExistentes,
    this.continuarConExistentes,
    this.modoExistente,
    this.idiomaExistente,
    this.usuarioExistente,
    this.trialExistenteExpirado = false,
    this.trialExistenteIniciadoEn,
    this.trialExistenteExpiraEn,
    this.syncSoulseek = SyncSoulseek.inactivo,
    this.mensajeSoulseek = '',
    this.motivoSoulseek = '',
  });

  EstadoSetup copiarCon({
    PasoSetup? paso,
    String? idiomaSeleccionado,
    String? usuario,
    bool? googleConectado,
    String? modoSeleccionado,
    String? codigoPremium,
    bool? guardando,
    bool? validandoCodigo,
    bool? codigoValido,
    String? errorCodigo,
    bool? tieneDatosExistentes,
    bool? continuarConExistentes,
    String? modoExistente,
    String? idiomaExistente,
    String? usuarioExistente,
    bool? trialExistenteExpirado,
    String? trialExistenteIniciadoEn,
    String? trialExistenteExpiraEn,
    SyncSoulseek? syncSoulseek,
    String? mensajeSoulseek,
    String? motivoSoulseek,
  }) =>
      EstadoSetup(
        paso: paso ?? this.paso,
        idiomaSeleccionado: idiomaSeleccionado ?? this.idiomaSeleccionado,
        usuario: usuario ?? this.usuario,
        googleConectado: googleConectado ?? this.googleConectado,
        modoSeleccionado: modoSeleccionado ?? this.modoSeleccionado,
        codigoPremium: codigoPremium ?? this.codigoPremium,
        guardando: guardando ?? this.guardando,
        validandoCodigo: validandoCodigo ?? this.validandoCodigo,
        codigoValido: codigoValido ?? this.codigoValido,
        errorCodigo: errorCodigo,
        tieneDatosExistentes: tieneDatosExistentes ?? this.tieneDatosExistentes,
        continuarConExistentes:
            continuarConExistentes ?? this.continuarConExistentes,
        modoExistente: modoExistente ?? this.modoExistente,
        idiomaExistente: idiomaExistente ?? this.idiomaExistente,
        usuarioExistente: usuarioExistente ?? this.usuarioExistente,
        trialExistenteExpirado:
            trialExistenteExpirado ?? this.trialExistenteExpirado,
        trialExistenteIniciadoEn:
            trialExistenteIniciadoEn ?? this.trialExistenteIniciadoEn,
        trialExistenteExpiraEn:
            trialExistenteExpiraEn ?? this.trialExistenteExpiraEn,
        syncSoulseek: syncSoulseek ?? this.syncSoulseek,
        mensajeSoulseek: mensajeSoulseek ?? this.mensajeSoulseek,
        motivoSoulseek: motivoSoulseek ?? this.motivoSoulseek,
      );

  @override
  List<Object?> get props => [
        paso,
        idiomaSeleccionado,
        usuario,
        googleConectado,
        modoSeleccionado,
        codigoPremium,
        guardando,
        validandoCodigo,
        codigoValido,
        errorCodigo,
        tieneDatosExistentes,
        continuarConExistentes,
        modoExistente,
        idiomaExistente,
        usuarioExistente,
        trialExistenteExpirado,
        trialExistenteIniciadoEn,
        trialExistenteExpiraEn,
        syncSoulseek,
        mensajeSoulseek,
        motivoSoulseek,
      ];
}
