// ─────────────────────────────────────────────────────────────
// strings_soulseek.dart — Textos de Soulseek (Ajustes → Más): la
// tarjeta, el tile de estado, la hoja de alta/conexión y la fila de
// contraseña. Español primario, inglés secundario.
// Se conecta con: app_localizations.dart (lo expone como `soulseek`)
// y settings_sheet_soulseek_*.
// Parte del flujo: Ajustes (conectar Soulseek).
// ─────────────────────────────────────────────────────────────

class StringsSoulseek {
  final String titulo;
  final String cardDesc;
  final String estadoConectada;
  final String estadoDesconectada;
  final String passRevelada;
  final String passGuardada;
  final String ocultar;
  final String ver;
  final String nombreVacio;
  final String campoLabel;
  final String campoHint;
  final String propuesta;
  final String ayudaSiguiente;
  final String reconectar;
  final String siguiente;
  final String tileConectado;
  final String tileSincronizar;
  final String tileConectar;
  final String snackConectado;
  final String elegisNombre;

  const StringsSoulseek({
    required this.titulo,
    required this.cardDesc,
    required this.estadoConectada,
    required this.estadoDesconectada,
    required this.passRevelada,
    required this.passGuardada,
    required this.ocultar,
    required this.ver,
    required this.nombreVacio,
    required this.campoLabel,
    required this.campoHint,
    required this.propuesta,
    required this.ayudaSiguiente,
    required this.reconectar,
    required this.siguiente,
    required this.tileConectado,
    required this.tileSincronizar,
    required this.tileConectar,
    required this.snackConectado,
    required this.elegisNombre,
  });

  /// Botón de la fila de contraseña según esté revelada o no.
  String botonPassword({required bool revelada}) => revelada ? ocultar : ver;

  /// Botón principal de la hoja ("Siguiente" o "Reconectar").
  String botonPrincipal({required bool conectada}) =>
      conectada ? reconectar : siguiente;

  /// Subtítulo del tile cuando aún no hay cuenta y se propone el nombre de la app.
  String usarNombre(String usuario, {required bool en}) =>
      en ? 'Use your name: $usuario' : 'Usar tu nombre: $usuario';

  static const es = StringsSoulseek(
    titulo: 'Soulseek',
    cardDesc:
        'Música en FLAC compartida entre usuarios. Sin invitación, '
        'sin pago y sin cuentas de otros servicios.',
    estadoConectada: 'Cuenta conectada',
    estadoDesconectada: 'Sin mail, sin captcha, sin invitación',
    passRevelada: 'Guardala: Soulseek no tiene recuperación',
    passGuardada: 'Contraseña guardada',
    ocultar: 'Ocultar',
    ver: 'Ver',
    nombreVacio: 'Elegí un nombre para tu cuenta.',
    campoLabel: 'Tu nombre en Soulseek',
    campoHint: 'p. ej. pablo_bz',
    propuesta:
        'Es el nombre de tu cuenta de la app. Si no te sirve, '
        'cambiá lo que quieras antes de continuar.',
    ayudaSiguiente:
        'Al tocar Siguiente se crea tu cuenta con ese nombre. '
        'La contraseña la genera la app.',
    reconectar: 'Reconectar',
    siguiente: 'Siguiente',
    tileConectado: 'Soulseek conectado',
    tileSincronizar: 'Sincronizar Soulseek',
    tileConectar: 'Conectar Soulseek',
    snackConectado: 'Soulseek conectado. Tu cuenta ya está lista.',
    elegisNombre: 'Elegís un nombre y listo',
  );

  static const en = StringsSoulseek(
    titulo: 'Soulseek',
    cardDesc:
        'FLAC music shared between users. No invite, no payment and '
        'no accounts from other services.',
    estadoConectada: 'Account connected',
    estadoDesconectada: 'No email, no captcha, no invite',
    passRevelada: 'Save it: Soulseek has no recovery',
    passGuardada: 'Saved password',
    ocultar: 'Hide',
    ver: 'Show',
    nombreVacio: 'Choose a name for your account.',
    campoLabel: 'Your Soulseek name',
    campoHint: 'e.g. pablo_bz',
    propuesta:
        "It's your app account name. If it doesn't work for you, "
        'change whatever you want before continuing.',
    ayudaSiguiente:
        'Tapping Next creates your account with that name. '
        'The app generates the password.',
    reconectar: 'Reconnect',
    siguiente: 'Next',
    tileConectado: 'Soulseek connected',
    tileSincronizar: 'Sync Soulseek',
    tileConectar: 'Connect Soulseek',
    snackConectado: 'Soulseek connected. Your account is ready.',
    elegisNombre: "Pick a name and you're done",
  );
}
