// ─────────────────────────────────────────────────────────────
// tutorial_pagina.dart — Tutorial de bienvenida: 4 pasos en un
// PageView con indicadores y botón Siguiente/Empezar. Construye
// los widgets (pasos + indicadores + botón) con la lógica y
// delega el acomodo a la variante MÓVIL (tutorial_movil.dart,
// pantalla completa) o ESCRITORIO (tutorial_escritorio.dart,
// panel centrado) según usarLayoutEscritorio. Al terminar marca
// el tutorial como visto en SharedPreferences y navega a '/'.
// Se conecta con: cache de prefs + go_router + l10n + shared.
// Parte del flujo: arranque (primer uso → /tutorial → /home).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/tema/colores_app.dart';
import '../../shared/utilidades/deteccion_plataforma.dart';
import 'tutorial_escritorio.dart';
import 'tutorial_movil.dart';

part 'tutorial_pagina_piezas.dart';

/// Clave de prefs que marca el tutorial como visto.
const _claveTutorialCompletado = 'has_completed_tutorial';

/// Tutorial de bienvenida con doble variante móvil/escritorio.
class TutorialPagina extends StatefulWidget {
  const TutorialPagina({super.key});

  @override
  State<TutorialPagina> createState() => _TutorialPaginaState();
}

class _TutorialPaginaState extends State<TutorialPagina> {
  final PageController _controlador = PageController();
  int _pagina = 0;

  /// Construye los 4 pasos con los textos localizados.
  List<Paso> _pasos(AppLocalizations loc) => [
        Paso(Icons.music_note, loc.tutorial.paso1Titulo, loc.tutorial.paso1Desc),
        Paso(Icons.search, loc.tutorial.paso2Titulo, loc.tutorial.paso2Desc),
        Paso(Icons.download, loc.tutorial.paso3Titulo, loc.tutorial.paso3Desc),
        Paso(Icons.extension, loc.tutorial.paso4Titulo, loc.tutorial.paso4Desc),
      ];

  /// Marca el tutorial como visto y navega al flujo de arranque.
  Future<void> _completar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_claveTutorialCompletado, true);
    // La ruta '/' (splash) decide si va a /home o /setup.
    if (mounted) context.go('/');
  }

  /// Avanza al siguiente paso (o completa en el último).
  void _siguiente(int total) {
    if (_pagina < total - 1) {
      _controlador.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completar();
    }
  }

  /// Página actual del PageView (usada por los indicadores).
  int get paginaActual => _pagina;

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final pasos = _pasos(loc);

    // Cuerpo: PageView con los 4 pasos.
    final cuerpo = PageView.builder(
      controller: _controlador,
      itemCount: pasos.length,
      onPageChanged: (i) => setState(() => _pagina = i),
      itemBuilder: (_, i) => _construirPaso(context, pasos[i]),
    );

    // Controles: indicadores + botón Siguiente/Empezar.
    final controles = _construirControles(this, pasos.length);

    final usarEscritorio = usarLayoutEscritorio(context);
    return usarEscritorio
        ? TutorialEscritorio(cuerpo: cuerpo, controles: controles)
        : TutorialMovil(cuerpo: cuerpo, controles: controles);
  }
}

/// Un paso del tutorial: icono, título y descripción.
class Paso {
  final IconData icono;
  final String titulo;
  final String descripcion;

  const Paso(this.icono, this.titulo, this.descripcion);
}