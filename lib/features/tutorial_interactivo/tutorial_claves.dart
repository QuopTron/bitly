// tutorial_claves.dart — GlobalKeys de los widgets que explica el tutorial, y
// los índices de las pestañas que puede abrir.
//
// Por qué un GlobalKey y no un finder: el overlay necesita la POSICIÓN real en
// pantalla del widget, y eso solo se obtiene desde su RenderBox. Un GlobalKey
// es único: solo se cuelga de instancias estables (la página, la barra), nunca
// de algo que se repita dentro de una lista.
//
// Se conecta con: tutorial_pasos (los usa en cada paso) y los widgets objetivo
// (les pone la key).
// Parte del flujo: tutorial interactivo (objetivos).
import 'package:flutter/material.dart';

/// Índices de las pestañas de la Home que el tutorial puede abrir.
/// Coinciden con el orden de las secciones de los dos shells.
class PestanaHome {
  /// Pestaña de búsqueda (0).
  static const int buscar = 0;

  /// Pestaña de inicio / feed (1).
  static const int inicio = 1;

  /// Pestaña de biblioteca personal (2).
  static const int miEspacio = 2;
}

// ─── GlobalKeys de los widgets explicados ─────────────────────
// Solo existen los que de verdad están montados cuando se explica el paso.

/// Contenido del feed (lo primero que ve el usuario en Inicio).
final keyTutorialFeed = GlobalKey();

/// Selector de fuente, dentro de la barra de búsqueda.
final keyTutorialFuente = GlobalKey();

/// Barra de búsqueda completa.
final keyTutorialBusqueda = GlobalKey();

/// Miniplayer (siempre visible al pie, en todas las pestañas).
final keyTutorialMiniplayer = GlobalKey();

/// Cabecera del perfil en Mi Espacio (desde ahí se abren los ajustes).
final keyTutorialAjustes = GlobalKey();

/// Fila de burbujas de la hoja de ajustes (las 4 pestañas).
final keyTutorialAjustesTabs = GlobalKey();

/// Área de contenido de la hoja de ajustes (cambia con cada pestaña).
final keyTutorialAjustesContenido = GlobalKey();

/// Índices de las pestañas de la hoja de ajustes, para no escribir números
/// sueltos en los pasos (el orden es el de `_bubbleTabs`).
class PestanaAjustes {
  static const int apariencia = 0;
  static const int descargas = 1;
  static const int rendimiento = 2;
  static const int mas = 3;
}
