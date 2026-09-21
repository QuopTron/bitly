// ─────────────────────────────────────────────────────────────
// servicio_lan.dart — El vínculo entre aparatos en la MISMA RED, sin
// servidor de nadie: cada app anuncia quién es por difusión y levanta su
// propio mini-servidor para prestar su biblioteca descargada.
//
// Una canción que bajaste en el celular se puede traer a la PC sin pasar por
// internet: se pide el catálogo del otro aparato, se compara con el tuyo y se
// copian los archivos que te faltan (audio, carátula y letra). Dos aparatos
// solo se prestan cosas si se ACEPTARON (el token autoriza). Acá va el estado
// y el arranque; el resto, en parts. Se conecta con: lan_modelos, lan_protocolo
// y lan_almacen. Flujo: Ajustes → Conexión → biblioteca en tu red.
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../base_datos/app_database.dart';
import '../../cache/almacenes/cache_ajustes.dart';
import '../../cache/almacenes/cache_descargas.dart';
import 'lan_almacen.dart';
import 'lan_modelos.dart';
import 'lan_protocolo.dart';

part 'servicio_lan_descubrimiento.dart';
part 'servicio_lan_http.dart';
part 'servicio_lan_indice.dart';
part 'servicio_lan_cliente.dart';
part 'servicio_lan_http_cliente.dart';
part 'servicio_lan_http_recursos.dart';
part 'servicio_lan_pares.dart';
part 'servicio_lan_sidecars.dart';

/// El vínculo con los otros aparatos de la red local.
class ServicioLan {
  final CacheAjustes _cache;
  final CacheDescargas _descargas;
  final AppDatabase _db;

  /// Cómo se llama este aparato y qué id tiene (se lo da Conexión).
  final Future<(String id, String nombre)> Function() _identidad;

  /// Otros aparatos vistos ahora mismo (y los vinculados, aunque no estén).
  final ValueNotifier<List<ParLan>> pares = ValueNotifier(const []);

  /// Un aparato pidió vincularse y todavía nadie decidió. La pestaña Conexión
  /// lo escucha para preguntarle al usuario.
  final ValueNotifier<ParLan?> solicitudVinculo = ValueNotifier(null);

  /// Avance del traspaso en curso: (copiadas, total). (0, 0) = nada en curso.
  final ValueNotifier<(int hechas, int total)> traspaso = ValueNotifier((0, 0));

  /// Se avisa al vincular para que la pestaña Conexión marque el aparato como
  /// vinculado (es el mismo aparato, con el id de Conexión).
  void Function(String id, String nombre)? alVincular;

  String _token = '';
  String _idPropio = '';
  String _nombre = '';
  int _puerto = 0;
  List<ParLan> _lista = const [];
  bool _activo = false;

  /// Mini-servidor de este aparato (los sockets de la difusión viven en
  /// _descubrimiento).
  io.HttpServer? _server;
  io.RawDatagramSocket? _difusion;
  Timer? _latido;

  /// Espera de la decisión del usuario cuando alguien pide vincularse.
  Completer<bool>? _decision;

  /// El usuario cortó el traspaso en curso: se frena al terminar la canción
  /// que está bajando (lo que ya llegó se queda).
  bool _cancelado = false;

  ServicioLan({
    required CacheAjustes cache,
    required CacheDescargas descargas,
    required AppDatabase db,
    required Future<(String id, String nombre)> Function() identidad,
  }) : _cache = cache,
       _descargas = descargas,
       _db = db,
       _identidad = identidad;

  /// ¿Está andando el vínculo?
  bool get activo => _activo;

  /// Token propio (lo necesitan los aparatos que ya me aceptaron).
  String get token => _token;

  String get idPropio => _idPropio;

  /// El puerto del mini-servidor (0 mientras no arrancó).
  int get puerto => _puerto;

  /// Los pares descubiertos o vinculados.
  List<ParLan> get lista => _lista;

  /// Arranca el mini-servidor y la difusión. Es idempotente y nunca tira: si
  /// la red no está disponible, la app sigue andando sin vínculo.
  Future<void> iniciar() async {
    if (_activo) return;
    // En el navegador no hay sockets: el vínculo es entre apps instaladas.
    if (kIsWeb) return;
    try {
      _token = await asegurarTokenLan(_cache);
      _lista = await leerParesLan(_cache);
      final (id, nombre) = await _identidad();
      _idPropio = id;
      _nombre = nombre;
      _server = await io.HttpServer.bind(io.InternetAddress.anyIPv4, 0);
      _puerto = _server!.port;
      _server!.listen(_manejarPedido, onError: _ignorarErrorDeRed);
      // El mini-servidor ya sirve: si la difusión falla (red rara, puerto
      // ocupado por otro programa), el vínculo por IP directa sigue andando.
      _activo = true;
      pares.value = _lista;
      try {
        await _abrirDifusion();
      } catch (e) {
        debugPrint('[Lan] sin difusión (el servidor sí quedó): $e');
      }
    } catch (e) {
      debugPrint('[Lan] no se pudo arrancar el vínculo: $e');
    }
  }

  /// Apaga el vínculo y libera el puerto. Se llama al cerrar la app.
  Future<void> detener() async {
    _cerrarDifusion();
    try {
      await _server?.close(force: true);
    } catch (e) {
      debugPrint('[Lan] no se pudo cerrar el servidor: $e');
    }
    _server = null;
    _puerto = 0;
    _activo = false;
  }

  /// Deja el anuncio y el servidor como estaban si algo de un aparato ajeno
  /// sale mal: un pedido roto no puede voltear el vínculo.
  void _ignorarErrorDeRed(Object e, StackTrace _) =>
      debugPrint('[Lan] error de red ignorado: $e');
}
