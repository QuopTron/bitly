// tutorial_pasos.dart — Los pasos del tutorial interactivo: a qué widget
// apunta cada uno y en qué sección se ve.
//
// El recorrido sigue cómo se usa la app de verdad:
//   1-8  la Home: feed, fuente, búsqueda, tarjeta, miniplayer, reproductor.
//   9-13 los AJUSTES: se abre la hoja y se explica cada pestaña (Apariencia,
//        Descargas, Rendimiento, Más) sin que el usuario tenga que adivinar
//        dónde está cada cosa ni cómo llegar.
//
// Los TEXTOS no viven acá: llegan de l10n en una lista, en el mismo orden.
// Los GlobalKeys son compartidos: el widget real los usa como key y este
// archivo los referencia en su paso. Un GlobalKey es ÚNICO, así que solo se
// cuelga de instancias estables (páginas, barras), nunca de algo repetido
// dentro de una lista.
//
// Se conecta con: modelo_tutorial + los widgets objetivo (feed, búsqueda,
// miniplayer, perfil, hoja de ajustes) + l10n (strings_tutorial_interactivo).
// Parte del flujo: tutorial interactivo (post-setup).
import 'package:flutter/material.dart';

import '../../../l10n/strings/strings_tutorial_interactivo.dart';
import 'modelo_tutorial.dart';

import 'tutorial_claves.dart';

// Las claves se exportan: quien importa los pasos (widgets, tests) las usa
export 'tutorial_claves.dart';

/// Definición sin textos de un paso.
class _Definicion {
  final String id;
  final GlobalKey? key;
  final int? pestana;
  final int? pestanaAjustes;
  final IconData icono;

  const _Definicion(
    this.id, {
    this.key,
    this.pestana,
    this.pestanaAjustes,
    required this.icono,
  });
}

/// El orden de esta tabla ES el orden del tutorial y el de los textos de l10n.
final List<_Definicion> _pasos = [
  _Definicion(
    'feed',
    key: keyTutorialFeed,
    pestana: PestanaHome.inicio,
    icono: Icons.explore_rounded,
  ),
  _Definicion(
    'fuente',
    key: keyTutorialFuente,
    pestana: PestanaHome.buscar,
    icono: Icons.album_rounded,
  ),
  _Definicion(
    'busqueda',
    key: keyTutorialBusqueda,
    pestana: PestanaHome.buscar,
    icono: Icons.search_rounded,
  ),
  _Definicion(
    'reproducir',
    key: keyTutorialFeed,
    pestana: PestanaHome.inicio,
    icono: Icons.play_circle_fill_rounded,
  ),
  _Definicion(
    'like',
    key: keyTutorialFeed,
    pestana: PestanaHome.inicio,
    icono: Icons.favorite_rounded,
  ),
  _Definicion(
    'descargar',
    key: keyTutorialFeed,
    pestana: PestanaHome.inicio,
    icono: Icons.download_rounded,
  ),
  // El miniplayer está al pie en todas las pestañas: no mueve ninguna.
  _Definicion(
    'miniplayer',
    key: keyTutorialMiniplayer,
    icono: Icons.music_note_rounded,
  ),
  // El reproductor completo y Premium viven en otras vistas: sin key, la
  // tarjeta se muestra centrada y avisa que se ven al abrirlas.
  _Definicion('controles', icono: Icons.graphic_eq_rounded),
  _Definicion(
    'ajustes',
    key: keyTutorialAjustes,
    pestana: PestanaHome.miEspacio,
    icono: Icons.person_rounded,
  ),
  // Con `pestanaAjustes` la hoja de ajustes se abre sola y el overlay queda
  // por encima para señalar cada pestaña.
  _Definicion(
    'ajustesApariencia',
    key: keyTutorialAjustesTabs,
    pestanaAjustes: PestanaAjustes.apariencia,
    icono: Icons.palette_rounded,
  ),
  _Definicion(
    'ajustesDescargas',
    key: keyTutorialAjustesContenido,
    pestanaAjustes: PestanaAjustes.descargas,
    icono: Icons.download_for_offline_rounded,
  ),
  _Definicion(
    'ajustesRendimiento',
    key: keyTutorialAjustesContenido,
    pestanaAjustes: PestanaAjustes.rendimiento,
    icono: Icons.speed_rounded,
  ),
  _Definicion(
    'ajustesMas',
    key: keyTutorialAjustesContenido,
    pestanaAjustes: PestanaAjustes.mas,
    icono: Icons.workspace_premium_rounded,
  ),
];

/// Arma la lista de pasos con los textos ya localizados.
///
/// [textos] viene de l10n y debe tener un elemento por paso, en orden.
List<TutorialPaso> crearPasosTutorial(List<TextoTutorial> textos) {
  return [
    for (var i = 0; i < _pasos.length; i++)
      TutorialPaso(
        id: _pasos[i].id,
        targetKey: _pasos[i].key,
        pestana: _pasos[i].pestana,
        pestanaAjustes: _pasos[i].pestanaAjustes,
        titulo: i < textos.length ? textos[i].titulo : '',
        descripcion: i < textos.length ? textos[i].descripcion : '',
        icono: _pasos[i].icono,
      ),
  ];
}
