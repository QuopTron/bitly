// ─────────────────────────────────────────────────────────────
// servicio_fiesta.dart — El MODO FIESTA: varios aparatos sonando a la vez
// como un solo parlante grande, sin servidor de nadie.
//
// El aparato que arma la fiesta (host) publica qué suena y en qué minuto, y
// sirve ESE audio por la red local. Los invitados preguntan cada segundo y
// medio cómo va, calculan el desfase contra el reloj del host y corrigen lo
// que haga falta: así suenan juntos.
//
// Acá viven el estado, el arranque y el corte, y el router de las rutas de
// fiesta. La publicación de la pista y el audio están en servicio_fiesta_host;
// el lado que sigue al host, en servicio_fiesta_invitado; los oyentes (el
// latido de la lista) en servicio_fiesta_oyentes.
//
// Se conecta con: servicio_lan (le presta las rutas) + fiesta_estado + el
// reproductor (la instantánea del player).
// Parte del flujo: reproductor → modo fiesta.
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../modelos/fiesta/fiesta_estado.dart';
import '../../../modelos/feed/item_feed.dart';
import '../../../audio/base/reproductor_audio.dart';
import '../../lan/modelos/lan_modelos.dart';
import '../audio/reproductor_fiesta.dart';

part 'servicio_fiesta_host.dart';
part 'servicio_fiesta_audio.dart';
part 'servicio_fiesta_oyentes.dart';
part '../invitado/servicio_fiesta_invitado.dart';
part '../invitado/servicio_fiesta_cliente.dart';

/// Lo que el modo fiesta necesita saber del reproductor de ESTE aparato.
typedef InstantaneaFiesta = ({
  ItemFeed? track,
  String? url,
  Duration posicion,
  bool sonando,
});

/// En qué está la fiesta acá.
enum ModoFiesta { apagado, host, invitado }

class ServicioFiesta {
  /// La foto del reproductor en este momento (la inyecta la app).
  final InstantaneaFiesta Function() _instantanea;

  /// Pausa el reproductor de la app: mientras este aparato es invitado, el
  /// audio que suena es el del host, no el suyo.
  final void Function() _pausarLocal;

  /// Id y nombre de ESTE aparato (los mismos que usa el vínculo de red).
  final Future<(String, String)> Function() _identidad;

  /// Modo actual (la UI muestra el icono encendido y la hoja).
  final ValueNotifier<ModoFiesta> modo = ValueNotifier(ModoFiesta.apagado);

  /// Nombres de los aparatos que están sonando con nosotros (host incluido).
  final ValueNotifier<List<String>> juntos = ValueNotifier(const []);

  /// true mientras el invitado está corrigiendo el tiempo.
  final ValueNotifier<bool> ajustando = ValueNotifier(false);

  /// Último problema (clave para la UI; null = ninguno).
  final ValueNotifier<String?> fallo = ValueNotifier(null);

  /// La última canción que publicó el host (lo que ve el invitado).
  final ValueNotifier<FiestaEstado> ultimoEstado = ValueNotifier(
    FiestaEstado.vacio,
  );

  String _nombre = '';
  String _idPropio = '';
  Timer? _latido;
  ParLan? _anfitrion;
  int _desfaseMs = 0;
  int _mejorIdaVueltaMs = 1 << 30;

  /// Motor de audio PROPIO del invitado (el de la app queda en pausa).
  ReproductorAudio? _player;

  /// Canción que está sonando en este invitado (para saber cuándo cambia).
  String _claveActual = '';

  /// Preguntas seguidas sin respuesta: el host se fue.
  int _fallos = 0;

  /// Oyentes del host: id → nombre + última vez que preguntaron.
  final Map<String, ({String nombre, int vistoMs})> _oyentes = {};

  ServicioFiesta({
    required InstantaneaFiesta Function() instantanea,
    required void Function() pausarLocal,
    required Future<(String, String)> Function() identidad,
  }) : _instantanea = instantanea,
       _pausarLocal = pausarLocal,
       _identidad = identidad;

  /// ¿Hay fiesta abierta en este aparato (de cualquier lado)?
  bool get activo => modo.value != ModoFiesta.apagado;

  /// ¿Este aparato es el que manda?
  bool get esHost => modo.value == ModoFiesta.host;

  /// El host que estoy siguiendo (null si mando yo o no hay fiesta).
  ParLan? get anfitrion => _anfitrion;

  /// Desfase estimado contra el reloj del host (ms). Para la UI de depuración.
  int get desfaseMs => _desfaseMs;

  /// Libera todo (se llama al cerrar la app).
  Future<void> cerrar() async {
    if (esHost) {
      await cortar();
    } else if (activo) {
      await salir();
    }
  }

  /// Atiende una ruta `/fiesta/...` del mini-servidor (ya con token válido).
  /// Devuelve false cuando no es cosa suya, para que el router siga.
  Future<bool> atenderPedido(io.HttpRequest pedido) async {
    if (!esHost) return false;
    final ruta = pedido.uri.path;
    if (pedido.method == 'GET' && ruta == '/fiesta/estado') {
      anotarOyenteFiesta(this, pedido);
      await responderJsonFiesta(pedido, estadoActualFiesta(this).aJson());
      return true;
    }
    if (pedido.method == 'POST' && ruta == '/fiesta/unirse') {
      await _recibirUnion(pedido);
      return true;
    }
    if (pedido.method == 'POST' && ruta == '/fiesta/salir') {
      await _recibirSalida(pedido);
      return true;
    }
    if (pedido.method == 'GET' && ruta == '/fiesta/audio') {
      await servirAudioFiesta(pedido, _instantanea);
      return true;
    }
    return false;
  }

}
