// ─────────────────────────────────────────────────────────────
// especificaciones_plataforma.dart — Medidas y comportamiento de
// un aparato, en UN solo lugar: botones, tarjetas, tiles, filas,
// indicadores y esqueletos.
//
// Por qué existe: cada componente de la app tiene que comportarse
// distinto en TV, PC y celular (un botón de tele se toca con el
// puntero a tres metros; el de PC con mouse; el del celular con el
// dedo). Sin esta capa, cada botón repetía sus números y quedaban
// iguales en las tres plataformas —que es justo lo que no se quiere—.
//
// Acá NO se duplica cada widget tres veces: se duplica solo lo que
// cambia (las medidas y el foco), y cada componente lee su aparato.
// Las tres tablas de valores viven en archivos aparte:
//   especificaciones_celular.dart · especificaciones_pc.dart ·
//   especificaciones_tv.dart
//
// Se conecta con: deteccion_plataforma (quién es quién), responsive
// (escala de cada aparato) y todos los componentes de shared/widgets
// y features (cada uno lee SU aparato).
// Parte del flujo: presentación (medidas por plataforma).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/widgets.dart';

import '../../utilidades/plataforma/deteccion_plataforma.dart';
import 'especificaciones_celular.dart';
import 'especificaciones_pc.dart';
import 'especificaciones_tv.dart';

/// Medidas y comportamiento de los componentes en un aparato concreto.
class EspecificacionesPlataforma {
  /// Alto de un botón de ancho completo.
  final double altoBoton;

  /// Alto de un botón que es la acción principal de la pantalla.
  final double altoBotonGrande;

  /// Radio de las esquinas del botón.
  final double radioBoton;

  /// Lado del spinner de carga y de los íconos chicos del botón.
  final double iconoBoton;

  /// Tamaño del texto del botón.
  final double textoBoton;

  /// Lado de un botón circular de acción (like, descargar, reproducir).
  final double altoBotonIcono;

  /// Lado del ícono dentro del botón circular.
  final double iconoAccion;

  /// Radio de las esquinas de tarjetas y portadas.
  final double radioTarjeta;

  /// Alto de una fila/tile de lista (ajustes, biblioteca, opciones).
  final double altoTile;

  /// Lado del ícono de un tile.
  final double iconoTile;

  /// Alto de una fila de canción (las de la cola y las listas).
  final double altoFila;

  /// Lado de un indicador chico (descarga, red).
  final double altoIndicador;

  /// Radio de un bloque de esqueleto de carga.
  final double radioEsqueleto;

  /// Radio de las esquinas de arriba de una hoja modal (Ajustes, cola,
  /// opciones): en la tele se redondea más porque la hoja es más grande.
  final double radioHoja;

  /// Tamaño de una etiqueta chica (chips, badges, contadores).
  final double textoEtiqueta;

  /// Si el aparato marca el FOCO (la TV: sin mouse, hay que ver dónde estás).
  final bool focoVisible;

  /// Grosor del contorno de foco.
  final double grosorFoco;

  /// Cuánto se agrandan TODAS las medidas de `Responsive` en este aparato.
  ///
  /// Es la palanca que hace que cada componente —y no sólo las pantallas—
  /// tenga su versión: en la TV los textos, íconos y espacios crecen de una,
  /// en PC y celular quedan como están (1.0).
  final double factorEscala;

  const EspecificacionesPlataforma({
    required this.altoBoton,
    required this.altoBotonGrande,
    required this.radioBoton,
    required this.iconoBoton,
    required this.textoBoton,
    required this.altoBotonIcono,
    required this.iconoAccion,
    required this.radioTarjeta,
    required this.altoTile,
    required this.iconoTile,
    required this.altoFila,
    required this.altoIndicador,
    required this.radioEsqueleto,
    required this.radioHoja,
    required this.textoEtiqueta,
    required this.focoVisible,
    required this.grosorFoco,
    this.factorEscala = 1.0,
  });

  /// Las del aparato en el que se está dibujando.
  ///
  /// La TV se pregunta PRIMERO: una tele ancha también entra en el layout de
  /// escritorio, así que si se preguntara después usaría las medidas de PC.
  static EspecificacionesPlataforma de(BuildContext context) {
    if (usarLayoutTv(context)) return especificacionesTv;
    if (usarLayoutEscritorio(context)) return especificacionesPc;
    return especificacionesCelular;
  }
}
