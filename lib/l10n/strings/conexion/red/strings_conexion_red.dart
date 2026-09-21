// ─────────────────────────────────────────────────────────────
// strings_conexion_red.dart — Textos del vínculo entre aparatos de la MISMA
// red: la sección "En tu red" de Conexión y el pedido de vínculo.
//
// Va aparte de strings_conexion.dart para que cada archivo de textos quede
// chico; se expone como `redConexion`.
//
// Español primario, inglés secundario. Las frases con números o nombres se
// arman con [ingles], igual que el resto de la app.
// Se conecta con: app_localizations.dart + la sección de red de Conexión.
// Parte del flujo: Ajustes → Conexión → biblioteca en tu red.
// ─────────────────────────────────────────────────────────────

class StringsConexionRed {
  /// true = textos en inglés (lo necesitan los parametrizados).
  final bool ingles;

  final String titulo;
  final String ayuda;
  final String vincular;
  final String esperando;
  final String traer;
  final String olvidar;
  final String vacio;
  final String sinLugar;
  final String fallo;
  final String pedidoTitulo;
  final String aceptar;
  final String rechazar;
  final String qrBoton;
  final String qrTitulo;
  final String qrAyuda;
  final String qrCodigo;
  final String qrEsperando;
  final String qrEscanear;
  final String qrEscanearAyuda;
  final String qrSinCamara;
  final String qrCamara;
  final String qrInvalido;
  final String qrListo;
  final String qrSoloDueno;
  final String qrOtroCodigo;
  final String cerrar;

  const StringsConexionRed({
    required this.ingles,
    required this.titulo,
    required this.ayuda,
    required this.vincular,
    required this.esperando,
    required this.traer,
    required this.olvidar,
    required this.vacio,
    required this.sinLugar,
    required this.fallo,
    required this.pedidoTitulo,
    required this.aceptar,
    required this.rechazar,
    required this.qrBoton,
    required this.qrTitulo,
    required this.qrAyuda,
    required this.qrCodigo,
    required this.qrEsperando,
    required this.qrEscanear,
    required this.qrEscanearAyuda,
    required this.qrSinCamara,
    required this.qrCamara,
    required this.qrInvalido,
    required this.qrListo,
    required this.qrSoloDueno,
    required this.qrOtroCodigo,
    required this.cerrar,
  });

  /// "Vinculado con «Celu de Pablo»."
  String qrVinculado(String nombre) =>
      ingles ? 'Linked with “$nombre”.' : 'Vinculado con «$nombre».';

  /// "«PC del cuarto» quiere vincularse…"
  String pedidoTexto(String nombre) =>
      ingles
          ? '“$nombre” wants to link so it can share its library. Accept only if it is yours.'
          : '«$nombre» quiere vincularse para prestarte su biblioteca. Aceptá solo si es tuyo.';

  static const es = StringsConexionRed(
    ingles: false,
    titulo: 'En tu red',
    ayuda:
        'Tus otros aparatos en la misma red. De acá te traés lo que ya está descargado allá: directo, sin internet y sin ningún servidor en el medio.',
    vincular: 'Vincular',
    esperando: 'Esperando que aceptes en el otro aparato…',
    traer: 'Traer lo que falta',
    olvidar: 'Olvidar',
    vacio:
        'Todavía no se ve otro aparato. Abrí Bitly en el otro y esperá unos segundos.',
    sinLugar:
        'Con el plan free tenés un solo aparato. La prueba de 9 horas o Premium habilitan el vínculo.',
    fallo:
        'No se pudo vincular. Probá de nuevo con los dos aparatos en la misma red.',
    pedidoTitulo: 'Un aparato quiere vincularse',
    aceptar: 'Aceptar',
    rechazar: 'Rechazar',
    qrBoton: 'Vincular con QR',
    qrTitulo: 'Vincular aparatos',
    qrAyuda:
        'En el aparato que quiere entrar, mostrá el QR. En este (el que controla la cuenta), escanealo: el vínculo se hace solo.',
    qrCodigo: 'Código por si no tenés cámara',
    qrEsperando: 'Esperando a que el otro aparato lo escanee…',
    qrEscanear: 'Escanear el QR del otro aparato',
    qrEscanearAyuda:
        'Apuntá la cámara al QR que muestra el otro aparato.',
    qrSinCamara:
        'Este aparato no tiene cámara: escribí el código de 6 dígitos que se ve debajo del QR del otro aparato.',
    qrCamara: 'Cámara',
    qrInvalido: 'Ese código no sirve. Pedí uno nuevo (los códigos vencen a los 3 minutos).',
    qrListo: 'Listo, ya se ven entre ustedes.',
    qrSoloDueno:
        'Para vincular hay que escanear desde el aparato que controla la cuenta.',
    qrOtroCodigo: 'Probar otro código',
    cerrar: 'Cerrar',
  );

  static const en = StringsConexionRed(
    ingles: true,
    titulo: 'On your network',
    ayuda:
        'Your other devices on the same network. Bring over what is already downloaded there: direct, no internet and no server in between.',
    vincular: 'Link',
    esperando: 'Waiting for you to accept on the other device…',
    traer: 'Bring missing songs',
    olvidar: 'Forget',
    vacio:
        'No other device yet. Open Bitly on the other one and wait a moment.',
    sinLugar:
        'The free plan has a single device. The 9-hour trial or Premium enable linking.',
    fallo: 'Could not link. Try again with both devices on the same network.',
    pedidoTitulo: 'A device wants to link',
    aceptar: 'Accept',
    rechazar: 'Reject',
    qrBoton: 'Link with QR',
    qrTitulo: 'Link devices',
    qrAyuda:
        'On the device that wants to join, show the QR. On this one (the one that controls the account), scan it: the link is made by itself.',
    qrCodigo: 'Code if you do not have a camera',
    qrEsperando: 'Waiting for the other device to scan it…',
    qrEscanear: 'Scan the other device’s QR',
    qrEscanearAyuda: 'Point the camera at the QR the other device shows.',
    qrSinCamara:
        'This device has no camera: type the 6-digit code shown under the other device’s QR.',
    qrCamara: 'Camera',
    qrInvalido: 'That code does not work. Ask for a new one (codes expire after 3 minutes).',
    qrListo: 'Done, you can see each other now.',
    qrSoloDueno:
        'To link, you have to scan from the device that controls the account.',
    qrOtroCodigo: 'Try another code',
    cerrar: 'Close',
  );
}
