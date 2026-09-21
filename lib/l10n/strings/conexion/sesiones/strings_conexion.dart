// ─────────────────────────────────────────────────────────────
// strings_conexion.dart — Textos de la burbuja CONEXIÓN de Ajustes: los
// aparatos de la cuenta, quién manda y la prueba de 9 horas.
//
// Los motivos están separados uno por uno (en vez de recibir el enum del
// servicio) para que este archivo siga siendo solo texto.
//
// Español primario, inglés secundario; se expone como `conexion`.
// Parte del flujo: Ajustes → Conexión.
// ─────────────────────────────────────────────────────────────

class StringsConexion {
  final String titulo;
  final String ayuda;
  final String esteAparato;
  final String controla;
  final String vinculado;
  final String sinVincular;
  final String enLinea;
  final String agregar;
  final String sacar;
  final String renombrar;
  final String cancelar;
  final String vacio;
  final String notaPendiente;
  final String tipoPc;
  final String tipoCelu;
  final String tipoTv;
  final String tipoExtra;
  final String motivoNoEsDueno;
  final String motivoCupoLleno;
  final String motivoNoConectado;
  final String motivoEsEste;
  final String trialTitulo;
  final String trialAyuda;
  final String trialArrancar;
  final String trialAgotada;
  final String premiumAyuda;
  final String proximoPaso;

  const StringsConexion({
    required this.titulo,
    required this.ayuda,
    required this.esteAparato,
    required this.controla,
    required this.vinculado,
    required this.sinVincular,
    required this.enLinea,
    required this.agregar,
    required this.sacar,
    required this.renombrar,
    required this.cancelar,
    required this.vacio,
    required this.notaPendiente,
    required this.tipoPc,
    required this.tipoCelu,
    required this.tipoTv,
    required this.tipoExtra,
    required this.motivoNoEsDueno,
    required this.motivoCupoLleno,
    required this.motivoNoConectado,
    required this.motivoEsEste,
    required this.trialTitulo,
    required this.trialAyuda,
    required this.trialArrancar,
    required this.trialAgotada,
    required this.premiumAyuda,
    required this.proximoPaso,
  });

  /// "2 de 4 aparatos".
  String cupo(int usados, int total) => '$usados de $total aparatos';

  /// "Te quedan 8 h 40 m de prueba".
  String trialRestante(int horas, int minutos) =>
      'Te quedan ${horas}h ${minutos}m de prueba';

  static const es = StringsConexion(
    titulo: 'Conexión',
    ayuda:
        'Tu cuenta en hasta cuatro aparatos: la PC, el celu, la TV y uno más.',
    esteAparato: 'Este aparato',
    controla: 'Controla la cuenta',
    vinculado: 'Vinculado',
    sinVincular: 'Sin vincular',
    enLinea: 'En línea',
    agregar: 'Agregar aparato',
    sacar: 'Sacar',
    renombrar: 'Renombrar',
    cancelar: 'Cancelar',
    vacio: 'Todavía no hay otros aparatos en la cuenta.',
    notaPendiente:
        'Queda sin vincular hasta que ese aparato se conecte. Recién ahí cuenta como conectado.',
    tipoPc: 'PC',
    tipoCelu: 'Celular',
    tipoTv: 'TV',
    tipoExtra: 'Extra',
    motivoNoEsDueno: 'Solo el aparato que controla la cuenta puede cambiarlo.',
    motivoCupoLleno: 'No queda lugar en tu plan.',
    motivoNoConectado:
        'Para sacarlo tiene que estar conectado en este momento. Conectalo y volvé a intentar.',
    motivoEsEste: 'Este es el aparato que estás usando.',
    trialTitulo: 'Prueba de la conexión multi',
    trialAyuda:
        'Con el plan free tenés un aparato. La prueba te deja los cuatro durante 9 horas desde que la activás.',
    trialArrancar: 'Probar 9 horas',
    trialAgotada: 'La prueba terminó.',
    premiumAyuda:
        'Con Premium conectás los cuatro aparatos sin límite de tiempo.',
    proximoPaso:
        'El vínculo entre aparatos es el paso que sigue: por ahora la lista es tu declaración de la cuenta.',
  );

  static const en = StringsConexion(
    titulo: 'Connection',
    ayuda:
        'Your account on up to four devices: the PC, the phone, the TV and one more.',
    esteAparato: 'This device',
    controla: 'Controls the account',
    vinculado: 'Linked',
    sinVincular: 'Not linked',
    enLinea: 'Online',
    agregar: 'Add device',
    sacar: 'Remove',
    renombrar: 'Rename',
    cancelar: 'Cancel',
    vacio: 'There are no other devices on the account yet.',
    notaPendiente:
        'It stays unlinked until that device connects. Only then does it count as connected.',
    tipoPc: 'PC',
    tipoCelu: 'Phone',
    tipoTv: 'TV',
    tipoExtra: 'Extra',
    motivoNoEsDueno:
        'Only the device that controls the account can change this.',
    motivoCupoLleno: 'Your plan has no room left.',
    motivoNoConectado:
        'To remove it, it has to be connected right now. Connect it and try again.',
    motivoEsEste: 'This is the device you are using.',
    trialTitulo: 'Multi-connection trial',
    trialAyuda:
        'On the free plan you get one device. The trial gives you all four for 9 hours from the moment you start it.',
    trialArrancar: 'Try 9 hours',
    trialAgotada: 'The trial is over.',
    premiumAyuda:
        'With Premium you connect all four devices with no time limit.',
    proximoPaso:
        'Linking between devices is the next step: for now this list is your account declaration.',
  );
}
