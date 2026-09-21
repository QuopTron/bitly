// ─────────────────────────────────────────────────────────────
// strings_fiesta.dart — Textos del MODO FIESTA: varios aparatos sonando a la
// vez como un solo parlante grande, con el audio saliendo por la red local.
//
// Español primario, inglés secundario; se expone como `fiesta`. Las frases con
// números o nombres se arman con métodos (los dos idiomas cambian de orden).
//
// Se conecta con: app_localizations.dart + la hoja de fiesta del reproductor.
// Parte del flujo: reproductor → modo fiesta.
// ─────────────────────────────────────────────────────────────

class StringsFiesta {
  /// true = textos en inglés (lo necesitan los parametrizados).
  final bool ingles;

  final String titulo;
  final String ayuda;
  final String arrancar;
  final String cortar;
  final String unirse;
  final String salir;
  final String conectando;
  final String sincronizado;
  final String ajustando;
  final String sinOtros;
  final String sinAudio;
  final String fallo;
  final String invitados;
  final String avisoRed;
  final String premium;
  final String a11y;

  const StringsFiesta({
    required this.ingles,
    required this.titulo,
    required this.ayuda,
    required this.arrancar,
    required this.cortar,
    required this.unirse,
    required this.salir,
    required this.conectando,
    required this.sincronizado,
    required this.ajustando,
    required this.sinOtros,
    required this.sinAudio,
    required this.fallo,
    required this.invitados,
    required this.avisoRed,
    required this.premium,
    required this.a11y,
  });

  /// "3 aparatos en la fiesta".
  String unidos(int n) =>
      ingles
          ? (n == 1 ? '1 device in the party' : '$n devices in the party')
          : (n == 1 ? '1 aparato en la fiesta' : '$n aparatos en la fiesta');

  /// "Sonando: «Titulo»".
  String suena(String cancion) =>
      ingles ? 'Playing: “$cancion”' : 'Sonando: «$cancion»';

  static const es = StringsFiesta(
    ingles: false,
    titulo: 'Modo fiesta',
    ayuda:
        'Conectá los aparatos que quieras y suenan todos juntos, como un solo parlante grande. El audio sale de este aparato por la red local: los demás lo siguen al instante.',
    arrancar: 'Armar el parlante',
    cortar: 'Cortar la fiesta',
    unirse: 'Unirme a la fiesta',
    salir: 'Salir de la fiesta',
    conectando: 'Conectando con la fiesta…',
    sincronizado: 'Sincronizado',
    ajustando: 'Ajustando el tiempo…',
    sinOtros:
        'Todavía no hay otro aparato. Vinculá uno en Ajustes → Conexión y volvé.',
    sinAudio: 'Poné una canción y después armá la fiesta.',
    fallo: 'Se cortó la fiesta. Probá de nuevo con los dos en la misma red.',
    invitados: 'Los que están sonando',
    avisoRed:
        'Los aparatos tienen que estar en la misma red y con la fiesta abierta. Si uno se va, los demás siguen.',
    premium:
        'El modo fiesta entra en la prueba de 9 horas y en Premium. Con el plan free suena solo este aparato.',
    a11y: 'Modo fiesta',
  );

  static const en = StringsFiesta(
    ingles: true,
    titulo: 'Party mode',
    ayuda:
        'Connect as many devices as you want and they all play together, like one big speaker. The audio leaves this device over the local network: the others follow instantly.',
    arrancar: 'Build the speaker',
    cortar: 'Stop the party',
    unirse: 'Join the party',
    salir: 'Leave the party',
    conectando: 'Connecting to the party…',
    sincronizado: 'In sync',
    ajustando: 'Adjusting timing…',
    sinOtros:
        'There is no other device yet. Link one in Settings → Connection and come back.',
    sinAudio: 'Play a song and then build the party.',
    fallo: 'The party stopped. Try again with both on the same network.',
    invitados: 'Playing along',
    avisoRed:
        'Devices must be on the same network with the party open. If one leaves, the rest keep going.',
    premium:
        'Party mode is included in the 9-hour trial and in Premium. On the free plan only this device plays.',
    a11y: 'Party mode',
  );
}
