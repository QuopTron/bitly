// ─────────────────────────────────────────────────────────────
// monitor_frames.dart — Adaptación EN VIVO al chip real.
//
// Por qué existe: el perfil de rendimiento se decide UNA vez, al arrancar, a
// partir de núcleos y RAM. Eso acierta en los extremos (un Helio G o un
// escritorio con RTX) pero se equivoca en el medio: hay equipos con muchos
// núcleos y una GPU floja, otros con poca RAM y buena GPU, emuladores,
// celulares con el gobernador térmico ya bajado, y equipos donde otra app se
// está comiendo la GPU. En todos esos casos el perfil dice "hay margen" y la
// app va a tirones sin que nadie lo note.
//
// Este monitor escucha los tiempos REALES de frame del motor
// (`addTimingsCallback`) y, si de forma SOSTENIDA no se llega al ritmo de la
// pantalla, apaga efectos por niveles:
//
//   nivel 1 → sin desenfoques (blur, partículas, pulsos, esqueletos animados)
//   nivel 2 → además, sin extracción de color por tarjeta (el trabajo que más
//             escala con la cantidad de items en pantalla)
//   nivel 3 → además, sin FOTOS a pantalla completa: el fondo queda con el color
//             dominante del cover. Es la textura más cara por frame, y es lo
//             último que queda cuando los dos escalones anteriores no alcanzan.
//
// Reglas para no degradar por un hipo puntual: se exige una ventana completa de
// frames, un arranque ya terminado, un enfriamiento entre rebajas y —lo más
// importante— que la ventana sea CONCLUYENTE: una ventana llena de frames de
// reposo (la app quieta dibuja ~1 fps) no dice nada del equipo y no se juzga.
//
// Y la degradación se DESHACE. Antes no: subía un nivel y no bajaba nunca más.
// Con el tercer nivel eso se veía como un bug de diseño — la foto del fondo
// desaparecía para el resto de la sesión por UN momento pesado (abrir una
// pantalla grande, una racha de red, el primer desplazamiento), aunque el equipo
// después fuera sobrado. Ahora hace falta que el mal ritmo se SOSTENGA para
// bajar, y el nivel vuelve solo cuando el equipo demuestra holgura de verdad
// (mediana con margen y sin picos) durante varias ventanas seguidas.
//
// La recuperación es conservadora a propósito: después de una rebaja se espera
// más, porque los efectos están apagados y el equipo va a verse mejor justo por
// eso — devolverlos en el acto haría parpadear el diseño.
//
// La ventana se juzga con TRES miradas, y no solo con la mediana. La mediana
// sola tiene un punto ciego que se midió en un Unisoc con PowerVR GE8322: al
// desplazar una lista, la mediana quedaba en 16,9 ms (justo el presupuesto de
// 60 Hz) mientras el 45% de los frames se pasaba de 20 ms. O sea: la app se
// veía a saltos, con un frame perdido de cada dos, y el monitor no bajaba
// nada porque "en promedio" llegaba. Por eso también cuentan el percentil 90
// (un frame perdido de cada diez ya se ve) y la PROPORCIÓN de frames que se
// pasan del presupuesto, que es lo que de verdad percibe quien desplaza.
//
// Se conecta con: efectos_app (el interruptor que leen los widgets) y main
// (arranque). Parte del flujo: rendimiento (adaptación al equipo).
// ─────────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../../../app/debug/depuracion.dart';

import '../../../../shared/utilidades/plataforma/pantalla/efectos_app.dart';

class MonitorFrames {
  MonitorFrames._();

  static final MonitorFrames instancia = MonitorFrames._();

  /// Frames que se acumulan antes de juzgar. Con 60 Hz son ~1,5 s: suficiente
  /// para que la mediana represente la pantalla y no un cambio de vista.
  static const int _ventanaFrames = 90;

  /// Último escalón: más allá no queda nada que apagar sin quitar diseño.
  static const int _nivelMaximo = 3;

  /// Frecuencia mínima del aviso de ventana lenta, para no inundar el log.
  static const Duration _avisoMinimo = Duration(seconds: 10);

  /// Presupuesto de frame (ms) tolerado. Se calcula de la tasa de refresco;
  /// con 60 Hz son 16,7 ms y se degrada cuando la mediana pasa de ~1,6× eso
  /// (≈ 26 ms, o sea por debajo de 40 fps sostenidos).
  static const double _factorTolerancia = 1.6;

  /// Umbral del percentil 90: más de 2× el presupuesto (≈ 33 ms con 60 Hz)
  /// significa que se pierde un frame entero de cada diez.
  static const double _factorP90 = 2.0;

  /// Proporción de frames que pueden pasarse del presupuesto sin concluir que
  /// el equipo no llega. Con 60 Hz un frame suelto de más es normal (una
  /// notificación, el recolector de basura, el gobernador de la CPU); que se
  /// pase CASI LA MITAD de forma sostenida, no: eso es un desplazamiento a
  /// tirones, aunque la mediana quede justa.
  static const double _fraccionTardeMaxima = 0.40;

  /// Tiempo de gracia desde el arranque: el primer pintado, la apertura de
  /// base de datos y la primera carga de red siempre cuestan más.
  static const Duration _graciaArranque = Duration(seconds: 4);

  /// Enfriamiento entre rebajas: no se baja dos niveles de golpe porque una
  /// pantalla pesada (una lista enorme) coincida con otra cosa.
  static const Duration _enfriamiento = Duration(seconds: 6);

  /// Ventanas seguidas por debajo del ritmo que hacen falta para bajar un
  /// nivel. Una sola no alcanza: un hipo (abrir una pantalla pesada, el primer
  /// desplazamiento, una ráfaga de red) apagaba efectos para toda la sesión.
  static const int _ventanasMalasParaBajar = 2;

  /// Ventanas seguidas con holgura que hacen falta para DEVOLVER un nivel.
  static const int _ventanasBuenasParaSubir = 3;

  /// Después de una rebaja se espera esto antes de volver a subir: con los
  /// efectos ya apagados el equipo va a medir mejor por ese mismo motivo, así
  /// que devolverlos de inmediato haría parpadear el diseño.
  static const Duration _esperaTrasRebaja = Duration(seconds: 20);

  /// Una ventana cuenta como "holgada" (candidata a devolver efectos) si la
  /// mediana queda con margen REAL, no al filo del umbral: sin ese margen el
  /// nivel subiría y bajaría en cada ventana.
  static const double _factorHolgura = 0.8;

  /// Un frame que costó menos que esto no habla del equipo: es un frame sin
  /// trabajo (la pantalla quieta). En reposo la app dibuja ~1 fps, así que una
  /// ventana puede llenarse de estos y no representar lo que pasa al desplazar.
  static const double _msFrameConTrabajo = 4.0;

  /// Frames con trabajo real que necesita una ventana para poder juzgarse.
  static const int _minFramesConTrabajo = 24;

  bool _activo = false;
  int _nivel = 0;
  int _framesAcumulados = 0;
  int _ventanasMalas = 0;
  int _ventanasBuenas = 0;

  /// Valores del perfil ANTES de que el monitor tocara nada, para poder
  /// devolverlos al subir de nivel. Se capturan en la primera rebaja (y no al
  /// arrancar) para no depender del orden en que el arranque aplica el perfil.
  bool _perfilCapturado = false;
  bool _perfilEfectosPesados = true;
  double _perfilSigma = 26;

  final List<double> _muestras = <double>[];

  /// Tiempo de Dart (build + layout) y de GPU (raster) por frame, en paralelo a
  /// [_muestras]. El total dice QUE va lento; estos dos dicen DÓNDE, que es lo
  /// que decide qué se puede optimizar. Medido en un Unisoc con PowerVR: el
  /// desplazamiento va a ~20 fps y apagar TODOS los efectos apenas mejora un
  /// 16%, o sea que el costo no estaba donde se creía.
  final List<double> _muestrasBuild = <double>[];
  final List<double> _muestrasRaster = <double>[];
  DateTime? _arranque;
  DateTime? _ultimoAviso;
  DateTime? _ultimaRebaja;

  /// Nivel de degradación aplicado (0 = efectos completos). Expuesto para
  /// diagnóstico y tests.
  int get nivel => _nivel;

  /// Empieza a medir. Idempotente: llamarlo dos veces no duplica el listener.
  void iniciar() {
    if (_activo) return;
    _activo = true;
    _arranque = DateTime.now();
    try {
      SchedulerBinding.instance.addTimingsCallback(_alTerminarFrame);
    } catch (e) {
      // Sin planificador no hay medición: la app sigue con el perfil estático.
      debugPrint('[MonitorFrames] no se pudo iniciar: $e');
    }
  }

  /// Detiene la medición (tests).
  @visibleForTesting
  void detener() {
    if (!_activo) return;
    _activo = false;
    try {
      SchedulerBinding.instance.removeTimingsCallback(_alTerminarFrame);
    } catch (_) {}
  }

  @visibleForTesting
  void reiniciarNivel() {
    _nivel = 0;
    _framesAcumulados = 0;
    _ventanasMalas = 0;
    _ventanasBuenas = 0;
    _perfilCapturado = false;
    _muestras.clear();
    _muestrasBuild.clear();
    _muestrasRaster.clear();
    _ultimaRebaja = null;
    _ultimoAviso = null;
    _arranque = DateTime.now();
  }

  void _alTerminarFrame(List<FrameTiming> tiempos) {
    if (!_activo) return;

    final ahora = DateTime.now();
    final inicio = _arranque;
    if (inicio == null || ahora.difference(inicio) < _graciaArranque) return;

    for (final t in tiempos) {
      // `totalSpan` es el tiempo de pared del frame completo (build + raster +
      // espera). Es lo que percibe el usuario, que es lo que estamos midiendo.
      final ms = t.totalSpan.inMicroseconds / 1000.0;
      // Descartas frames absurdos (reanudar la app, cambio de orientación,
      // primer frame tras volver de segundo plano): no son coste sostenido.
      if (ms <= 0 || ms > 500) continue;
      _muestras.add(ms);
      _muestrasBuild.add(t.buildDuration.inMicroseconds / 1000.0);
      _muestrasRaster.add(t.rasterDuration.inMicroseconds / 1000.0);
    }
    _framesAcumulados += tiempos.length;
    if (_framesAcumulados < _ventanaFrames) return;
    _framesAcumulados = 0;

    // La ventana se copia y se vacía en un solo lugar, así ninguna salida
    // temprana de acá abajo puede dejar muestras viejas contaminando la próxima.
    final muestras = List<double>.of(_muestras);
    final build = List<double>.of(_muestrasBuild);
    final raster = List<double>.of(_muestrasRaster);
    _muestras.clear();
    _muestrasBuild.clear();
    _muestrasRaster.clear();

    _decidirVentana(muestras, build, raster, ahora);
  }

  /// Decide con una ventana YA completa y un reloj explícito.
  ///
  /// Separado del callback del motor para poder probar la SECUENCIA real
  /// (cuántas ventanas malas hacen falta, cuándo se recupera) sin depender del
  /// planificador ni de esperar segundos de verdad.
  void _decidirVentana(
    List<double> muestras,
    List<double> build,
    List<double> raster,
    DateTime ahora,
  ) {
    if (muestras.isEmpty) return;

    // ¿La ventana dice algo del equipo? En reposo la app dibuja ~1 fps: una
    // ventana llena de frames sin trabajo no es "va bien" ni "va mal", así que
    // no se juzga. Sin este filtro el veredicto dependía de cuánto tiempo pasó
    // la pantalla quieta — y la recuperación se dispararía sola con la app en
    // reposo.
    if (framesConTrabajo(muestras) < _minFramesConTrabajo) return;

    final presupuesto = _presupuestoMs();
    final lento = ritmoInsuficiente(muestras, presupuesto);

    if (lento) {
      _avisarVentanaLenta(muestras, build, raster, presupuesto, ahora);
      _ventanasBuenas = 0;
      _ventanasMalas++;
      // El mal ritmo tiene que SOSTENERSE: con una sola ventana mala, un hipo
      // puntual apagaba efectos para el resto de la sesión.
      if (_ventanasMalas < _ventanasMalasParaBajar) return;
      final ultima = _ultimaRebaja;
      if (ultima != null && ahora.difference(ultima) < _enfriamiento) return;
      _ventanasMalas = 0;
      _rebajar();
      _ultimaRebaja = ahora;
      return;
    }

    // Ventana con ritmo suficiente. Si no hay nada que devolver, listo.
    _ventanasMalas = 0;
    if (_nivel == 0) {
      _ventanasBuenas = 0;
      return;
    }

    // Devolver efectos exige holgura de verdad (mediana con margen y sin
    // picos): ir justo raspando el umbral no es motivo para volver a encender
    // lo que ya se apagó.
    if (!ritmoHolgado(muestras, presupuesto)) {
      _ventanasBuenas = 0;
      return;
    }
    _ventanasBuenas++;
    if (_ventanasBuenas < _ventanasBuenasParaSubir) return;
    final ultima = _ultimaRebaja;
    if (ultima != null && ahora.difference(ultima) < _esperaTrasRebaja) return;
    _ventanasBuenas = 0;
    _subir();
  }

  /// Igual que [_decidirVentana] pero con los tiempos de build/raster iguales al
  /// total: solo lo usan los tests, que juzgan el ritmo, no el desglose.
  @visibleForTesting
  void decidirVentanaParaPruebas(List<double> muestras, DateTime ahora) =>
      _decidirVentana(muestras, muestras, muestras, ahora);

  /// Presupuesto de frame en ms según la tasa de refresco real de la pantalla
  /// (90/120 Hz tienen menos margen por frame que 60 Hz).
  double _presupuestoMs() {
    var hz = 60.0;
    try {
      final vista = PlatformDispatcher.instance.implicitView;
      final tasa = vista?.display.refreshRate ?? 0;
      if (tasa.isFinite && tasa >= 30 && tasa <= 240) hz = tasa;
    } catch (_) {
      // Sin dato de pantalla se asume 60 Hz, el caso más común.
    }
    return 1000.0 / hz;
  }

  /// Cuántos frames de la ventana costaron trabajo real.
  ///
  /// Sirve para descartar ventanas de reposo: en la pantalla quieta el motor
  /// dibuja muy pocos frames por segundo y todos baratos, y esos frames no
  /// representan ni el costo de desplazar ni el de animar.
  @visibleForTesting
  static int framesConTrabajo(
    List<double> muestras, {
    double minMs = _msFrameConTrabajo,
  }) {
    var n = 0;
    for (final ms in muestras) {
      if (ms >= minMs) n++;
    }
    return n;
  }

  /// ¿Esta ventana dice que el equipo va HOLGADO (candidato a devolver efectos)?
  ///
  /// Más exigente que "no lento" a propósito: la mediana tiene que quedar con
  /// margen (no al filo del umbral) y el percentil 90 no puede pasar el
  /// presupuesto. Así el nivel no sube y baja en cada ventana.
  @visibleForTesting
  static bool ritmoHolgado(List<double> muestras, double presupuestoMs) {
    if (muestras.isEmpty || presupuestoMs <= 0) return false;
    final ordenadas = List<double>.of(muestras)..sort();
    final mediana = ordenadas[ordenadas.length ~/ 2];
    if (mediana >= presupuestoMs * _factorHolgura) return false;
    final p90 = ordenadas[((ordenadas.length - 1) * 0.9).floor()];
    return p90 <= presupuestoMs;
  }

  /// ¿Esta ventana de frames dice que el equipo no llega al ritmo?
  ///
  /// Es la regla COMPLETA y sin estado (ventana, gracia y enfriamiento viven en
  /// el llamador), expuesta para poder fijarla con tests.
  ///
  /// Las tres condiciones se suman en OR a propósito: cada una cubre una forma
  /// distinta de ir mal —lento parejo (mediana), con caídas grandes (p90) o con
  /// la mitad de los frames pasados (proporción)— y ninguna sola alcanza.
  @visibleForTesting
  static bool ritmoInsuficiente(List<double> muestras, double presupuestoMs) {
    if (muestras.isEmpty || presupuestoMs <= 0) return false;
    final ordenadas = List<double>.of(muestras)..sort();

    final mediana = ordenadas[ordenadas.length ~/ 2];
    if (mediana > presupuestoMs * _factorTolerancia) return true;

    final p90 = ordenadas[((ordenadas.length - 1) * 0.9).floor()];
    if (p90 > presupuestoMs * _factorP90) return true;

    var tarde = 0;
    for (final ms in ordenadas) {
      if (ms > presupuestoMs) tarde++;
    }
    return tarde / ordenadas.length >= _fraccionTardeMaxima;
  }

  /// Deja constancia, con los números, de una ventana que no llega al ritmo.
  ///
  /// Por qué existe: medir un equipo real fuera de la app (SurfaceFlinger,
  /// gfxinfo) no siempre refleja lo que midió el motor —en Android, la latencia
  /// por capa puede no seguir los frames de Flutter— así que la medición que
  /// vale es esta, la del propio motor. Es también lo que permite diagnosticar
  /// un reporte de "va lento" sin herramientas externas.
  ///
  /// Sale como MUCHO una vez cada [_avisoMinimo]: en un equipo que va bien no
  /// imprime nada, y en uno que va mal no inunda el log. Va por
  /// [avisoRendimiento] y no por `debugPrint`, porque en release `debugPrint`
  /// está anulado y este es justo el dato que hay que poder leer en el
  /// aparato.
  void _avisarVentanaLenta(
    List<double> muestras,
    List<double> build,
    List<double> raster,
    double presupuesto,
    DateTime ahora,
  ) {
    final ultimo = _ultimoAviso;
    if (ultimo != null && ahora.difference(ultimo) < _avisoMinimo) return;
    _ultimoAviso = ahora;

    final ordenadas = List<double>.of(muestras)..sort();
    final mediana = ordenadas[ordenadas.length ~/ 2];
    final p90 = ordenadas[((ordenadas.length - 1) * 0.9).floor()];
    var tarde = 0;
    for (final ms in ordenadas) {
      if (ms > presupuesto) tarde++;
    }
    final pctTarde = (100 * tarde / ordenadas.length).round();
    avisoRendimiento(
      'ventana lenta: n=${ordenadas.length} '
      'mediana=${mediana.toStringAsFixed(1)}ms '
      'p90=${p90.toStringAsFixed(1)}ms tarde=$pctTarde% '
      'presupuesto=${presupuesto.toStringAsFixed(1)}ms nivel=$_nivel '
      'dart=${_mediana(build).toStringAsFixed(1)}ms '
      'gpu=${_mediana(raster).toStringAsFixed(1)}ms',
    );
  }

  /// Mediana de una lista de tiempos, sin ordenar la original.
  static double _mediana(List<double> muestras) {
    if (muestras.isEmpty) return 0;
    final ordenadas = List<double>.of(muestras)..sort();
    return ordenadas[ordenadas.length ~/ 2];
  }

  /// Guarda los valores del perfil tal como estaban ANTES de que el monitor
  /// tocara nada.
  ///
  /// Se hace en la primera rebaja y no al arrancar a propósito: así no importa
  /// el orden en que el arranque aplique el perfil de rendimiento, y si alguien
  /// reaplica el perfil más tarde, el valor guardado sigue siendo el real.
  void _capturarPerfil() {
    if (_perfilCapturado) return;
    _perfilCapturado = true;
    _perfilEfectosPesados = EfectosApp.permitirDesenfoque.value;
    _perfilSigma = EfectosApp.sigmaMaximo.value;
  }

  /// Baja un nivel de efectos.
  void _rebajar() {
    if (_nivel >= _nivelMaximo) return;
    _capturarPerfil();
    _nivel++;

    avisoRendimiento(
      'ritmo insuficiente: nivel $_nivel de '
      '$_nivelMaximo — apagando efectos para recuperar el ritmo',
    );
    switch (_nivel) {
      case 1:
        // Sin desenfoques: es el peso de GPU más caro que queda.
        EfectosApp.aplicar(efectosPesados: false, sigmaMax: 0);
      case 2:
        // Además, sin trabajo de color por tarjeta (paleta de cada cover),
        // que es lo que más escala con la cantidad de items en pantalla.
        EfectosApp.efectosMinimos.value = true;
      default:
        // Y si todavía no llega, se suelta la capa más cara por frame: la foto
        // a pantalla completa de los fondos. Queda el color dominante del cover,
        // así que el diseño no cambia, solo deja de costar una textura enorme.
        EfectosApp.fotosApagadasPorMonitor.value = true;
    }
  }

  /// Devuelve UN nivel de efectos, porque el equipo demostró holgura sostenida.
  ///
  /// Por qué existe: la degradación no se deshacía nunca, así que un momento
  /// pesado apagaba la foto de los fondos para toda la sesión y el usuario lo
  /// veía como si el diseño (la intensidad del cover) se hubiera roto. Se
  /// devuelve de a un nivel y solo tras [_esperaTrasRebaja] con varias ventanas
  /// holgadas seguidas, así el diseño no parpadea.
  void _subir() {
    if (_nivel <= 0) return;
    _nivel--;

    avisoRendimiento(
      'ritmo recuperado: nivel $_nivel de '
      '$_nivelMaximo — devolviendo efectos',
    );
    switch (_nivel) {
      case 0:
        // Último escalón devuelto: se restauran los valores del PERFIL, que son
        // los que había antes de que el monitor tocara nada.
        EfectosApp.aplicar(
          efectosPesados: _perfilEfectosPesados,
          sigmaMax: _perfilSigma,
        );
      case 1:
        // Se vuelve a permitir el trabajo de color por tarjeta.
        EfectosApp.efectosMinimos.value = false;
      default:
        // Se vuelven a pintar las fotos a pantalla completa de los fondos.
        EfectosApp.fotosApagadasPorMonitor.value = false;
    }
  }

  /// Utilidad para pruebas: mediana de una lista de muestras.
  @visibleForTesting
  static double medianaDe(List<double> muestras) {
    if (muestras.isEmpty) return 0;
    final ordenadas = List<double>.of(muestras)..sort();
    return ordenadas[ordenadas.length ~/ 2];
  }

  /// Presupuesto efectivo para diagnóstico.
  @visibleForTesting
  double get presupuestoMs => _presupuestoMs();

  /// Compara contra el presupuesto con la tolerancia aplicada.
  @visibleForTesting
  bool superaPresupuesto(double medianaMs) =>
      medianaMs > _presupuestoMs() * _factorTolerancia;

  /// Media de una lista (para tests de sanidad).
  @visibleForTesting
  static double mediaDe(List<double> muestras) =>
      muestras.isEmpty
          ? 0
          : muestras.reduce((a, b) => a + b) / math.max(1, muestras.length);
}
