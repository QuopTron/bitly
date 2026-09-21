// ─────────────────────────────────────────────────────────────
// strings_premium.dart — Textos de la validación de códigos premium.
// Go devuelve un MOTIVO estable (codigo_usado, codigo_expirado, …) y acá
// se convierte al idioma activo, así el usuario nunca ve el español del
// backend. Español primario, inglés secundario.
// Se conecta con: app_localizations.dart (lo expone como `premium`) +
// premium_mixin / ayudantes_backend.
// Parte del flujo: activación de códigos premium.
// ─────────────────────────────────────────────────────────────

class StringsPremium {
  final String codigoInvalido;
  final String activarTitulo;
  final String activarDescripcion;
  final String activar;
  final String activado;
  final Map<String, String> motivos;

  const StringsPremium({
    required this.codigoInvalido,
    required this.activarTitulo,
    required this.activarDescripcion,
    required this.activar,
    required this.activado,
    required this.motivos,
  });

  /// Mensaje localizado para el motivo que mandó Go, o el genérico si el
  /// motivo falta o es desconocido (nunca bloquea al usuario).
  String motivo(String? clave) => motivos[clave] ?? codigoInvalido;

  static const es = StringsPremium(
    codigoInvalido: 'Código inválido',
    activarTitulo: 'Activar Premium',
    activarDescripcion:
        'Ingresá tu código para desbloquear descargas ilimitadas',
    activar: 'Activar',
    activado: 'Premium activado',
    motivos: {
      'codigo_invalido': 'Código inválido',
      'error_validacion': 'Error de validación',
      'no_validar': 'No se pudo validar el código',
      'codigo_vacio': 'Escribí un código.',
      'formato_invalido': 'El código no tiene el formato correcto.',
      'datos_ilegibles': 'El código no tiene el formato correcto.',
      'payload_ilegible': 'El código no tiene el formato correcto.',
      'firma_invalida': 'El código no es válido.',
      'palabra_no_autorizada': 'El código no es válido.',
      'codigo_expirado': 'El código expiró.',
      'codigo_usado': 'Ese código ya se usó.',
      'codigo_no_encontrado': 'Ese código no existe.',
      'codigo_cancelado': 'Ese código fue cancelado.',
      'codigo_liberado': 'Ese código fue liberado.',
      'codigo_desconocido': 'Ese código no es válido.',
      'estado_desconocido': 'Ese código no es válido.',
      'limite_de_usos': 'Ese código alcanzó su límite de usos.',
      'registro_no_verificado':
          'No se pudo verificar el código. Revisá tu conexión e intentá de nuevo.',
      'descargas_requieren_premium':
          'Las descargas necesitan Premium. Activá un código en Ajustes.',
      'premium_expirado': 'Tu Premium expiró.',
    },
  );

  static const en = StringsPremium(
    codigoInvalido: 'Invalid code',
    activarTitulo: 'Activate Premium',
    activarDescripcion: 'Enter your code to unlock unlimited downloads',
    activar: 'Activate',
    activado: 'Premium activated',
    motivos: {
      'codigo_invalido': 'Invalid code',
      'error_validacion': 'Validation error',
      'no_validar': "Couldn't validate the code",
      'codigo_vacio': 'Enter a code.',
      'formato_invalido': "The code doesn't have the right format.",
      'datos_ilegibles': "The code doesn't have the right format.",
      'payload_ilegible': "The code doesn't have the right format.",
      'firma_invalida': "The code isn't valid.",
      'palabra_no_autorizada': "The code isn't valid.",
      'codigo_expirado': 'The code expired.',
      'codigo_usado': 'That code was already used.',
      'codigo_no_encontrado': "That code doesn't exist.",
      'codigo_cancelado': 'That code was cancelled.',
      'codigo_liberado': 'That code was released.',
      'codigo_desconocido': "That code isn't valid.",
      'estado_desconocido': "That code isn't valid.",
      'limite_de_usos': 'That code reached its usage limit.',
      'registro_no_verificado':
          "Couldn't verify the code. Check your connection and try again.",
      'descargas_requieren_premium':
          'Downloads need Premium. Activate a code in Settings.',
      'premium_expirado': 'Your Premium expired.',
    },
  );
}
