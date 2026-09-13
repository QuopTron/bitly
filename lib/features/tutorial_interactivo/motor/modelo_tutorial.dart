// modelo_tutorial.dart — Modelo de datos de un paso del tutorial
// interactivo. Cada paso puede apuntar a un widget concreto (targetKey)
// y declarar en qué pestaña de la Home vive (pestana), para que el shell
// lleve al usuario hasta ahí antes de explicarlo. Así el tutorial no se
// limita a describir: mueve al usuario por la app.
//
// targetKey puede ser null: hay funciones que viven en otra vista (el
// reproductor completo, las descargas, Premium) y el paso se explica
// igual, centrado, en vez de quedar invisible y trabar el tutorial.
//
// Se conecta con: tutorial_pasos (definición de los 10 pasos) y
// tutorial_overlay (lo pinta).
// Parte del flujo: tutorial interactivo (una sola vez, post-setup).
import 'package:flutter/material.dart';

/// Un paso del tutorial interactivo.
class TutorialPaso {
  /// Identificador único del paso (también útil para tests y analytics).
  final String id;

  /// GlobalKey del widget explicado, o null si vive en otra vista.
  final GlobalKey? targetKey;

  /// Pestaña de la Home que hay que abrir para ver el objetivo
  /// (ver [PestanaHome]). null = no cambia de pestaña.
  final int? pestana;

  /// Pestaña de la hoja de AJUSTES que explica este paso (0 Apariencia,
  /// 1 Descargas, 2 Rendimiento, 3 Más). Que no sea null significa: abrir la
  /// hoja de ajustes y pararse en esa pestaña antes de mostrar la tarjeta.
  final int? pestanaAjustes;

  /// Título del tooltip.
  final String titulo;

  /// Descripción de la función que explica el paso.
  final String descripcion;

  /// Icono que acompaña al título.
  final IconData? icono;

  const TutorialPaso({
    required this.id,
    this.targetKey,
    this.pestana,
    this.pestanaAjustes,
    required this.titulo,
    required this.descripcion,
    this.icono,
  });

  /// Si el paso se explica dentro de la hoja de ajustes.
  bool get enAjustes => pestanaAjustes != null;
}
