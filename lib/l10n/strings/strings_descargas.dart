// ─────────────────────────────────────────────────────────────
// strings_descargas.dart — Textos de los avisos de descarga: fallo
// definitivo de una canción, carpeta inaccesible, gate del plan free,
// decrypt fallido y reinicio del backend con descargas en curso.
// Español primario, inglés secundario (se elige por el locale).
// Se conecta con: app_localizations.dart (lo expone como `descargas`)
// y shared/widgets/descargas/avisos_descarga.dart.
// Parte del flujo: descargas (avisos al usuario).
// ─────────────────────────────────────────────────────────────

class StringsDescargas {
  final String falloTitulo;
  final String falloMotivo;
  final String falloAyuda;
  final String falloAyudaUsuario;
  final String reintentar;
  final String descartar;
  final String reintentoChip;
  final String carpetaTitulo;
  final String carpetaMensaje;
  final String carpetaAccion;
  final String gateTitulo;
  final String decryptTitulo;
  final String reinicioTitulo;
  final String reinicioMensaje;
  final String a11yCerrar;

  /// Motivo entendible por código de fallo (ver `MotivosDescarga` en
  /// core/servicios/descargas/motivos_descarga.dart). El motivo crudo del
  /// backend nunca se muestra: se elige uno de estos por su código.
  final Map<String, String> motivosDescarga;
  final String motivoDesconocido;

  /// Texto del motivo que corresponde a [clave].
  String motivoDescarga(String clave) =>
      motivosDescarga[clave] ?? motivoDesconocido;

  const StringsDescargas({
    required this.falloTitulo,
    required this.falloMotivo,
    required this.falloAyuda,
    required this.falloAyudaUsuario,
    required this.reintentar,
    required this.descartar,
    required this.reintentoChip,
    required this.carpetaTitulo,
    required this.carpetaMensaje,
    required this.carpetaAccion,
    required this.gateTitulo,
    required this.decryptTitulo,
    required this.reinicioTitulo,
    required this.reinicioMensaje,
    required this.a11yCerrar,
    required this.motivosDescarga,
    required this.motivoDesconocido,
  });

  static const es = StringsDescargas(
    falloTitulo: 'No se pudo descargar «{titulo}»',
    falloMotivo: 'Motivo: {motivo}',
    falloAyuda: 'Puedes reintentar: se buscará otra calidad o fuente.',
    falloAyudaUsuario: 'Revisa tus ajustes y vuelve a intentarlo.',
    reintentar: 'Reintentar',
    descartar: 'Descartar',
    reintentoChip: 'Reintento {n}/{total}',
    carpetaTitulo: 'La carpeta de descargas no está disponible',
    carpetaMensaje:
        'No se puede escribir donde guardas la música. Elige otra carpeta para seguir descargando.',
    carpetaAccion: 'Elegir carpeta',
    gateTitulo: 'Descargas en pausa',
    decryptTitulo: 'No se pudo descifrar una descarga',
    reinicioTitulo: 'Se reinició el motor de descargas',
    reinicioMensaje:
        'Las descargas en curso se cortaron. Puedes reintentarlas.',
    a11yCerrar: 'Cerrar el aviso',
    motivosDescarga: {
      'espacio': 'No queda espacio libre en el dispositivo',
      'permiso': 'La carpeta de destino no permite escribir',
      'verificacion': 'La fuente pidió verificar la sesión',
      'premium': 'Esa calidad necesita una cuenta de pago',
      'carpeta': 'La carpeta de descargas no está disponible',
      'red': 'Se cortó la conexión durante la descarga',
      'sin_archivo': 'La descarga no dejó un archivo reproducible',
      'sin_fin': 'El backend no reportó el fin de la descarga',
    },
    motivoDesconocido: 'La fuente no pudo entregar el archivo',
  );

  static const en = StringsDescargas(
    falloTitulo: 'Couldn\'t download "{titulo}"',
    falloMotivo: 'Reason: {motivo}',
    falloAyuda: 'You can retry: another quality or source will be tried.',
    falloAyudaUsuario: 'Check your settings and try again.',
    reintentar: 'Retry',
    descartar: 'Dismiss',
    reintentoChip: 'Retry {n}/{total}',
    carpetaTitulo: 'Download folder is unavailable',
    carpetaMensaje:
        'Your music folder can\'t be written to. Pick another folder to keep downloading.',
    carpetaAccion: 'Pick folder',
    gateTitulo: 'Downloads paused',
    decryptTitulo: 'A download couldn\'t be decrypted',
    reinicioTitulo: 'Download engine restarted',
    reinicioMensaje: 'Downloads in progress were cut off. You can retry them.',
    a11yCerrar: 'Dismiss notice',
    motivosDescarga: {
      'espacio': 'Not enough free space left on the device',
      'permiso': "The destination folder isn't writable",
      'verificacion': 'The source asked to verify the session',
      'premium': 'That quality needs a paid account',
      'carpeta': "The downloads folder isn't available",
      'red': 'The connection dropped during the download',
      'sin_archivo': "The download didn't leave a playable file",
      'sin_fin': "The backend didn't report the download's end",
    },
    motivoDesconocido: "The source couldn't deliver the file",
  );
}
