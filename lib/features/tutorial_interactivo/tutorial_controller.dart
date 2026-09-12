// tutorial_controller.dart — ChangeNotifier que maneja el estado del
// tutorial interactivo: paso actual, visibilidad, progreso. Persiste
// en SharedPreferences y notifica a los listeners para re-renderizar
// el overlay.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'modelo_tutorial.dart';

/// Claves de SharedPreferences.
const _claveCompletado = 'tutorial_interactivo_completado';
const _clavePasoActual = 'tutorial_interactivo_paso_actual';

/// Controller del tutorial interactivo.
class TutorialController extends ChangeNotifier {
  List<TutorialPaso> _pasos = [];
  int _indiceActual = 0;
  bool _visible = false;
  bool _inicializado = false;

  /// Todos los pasos del tutorial.
  List<TutorialPaso> get pasos => _pasos;

  /// Paso actual.
  TutorialPaso? get pasoActual =>
      _pasos.isNotEmpty && _indiceActual < _pasos.length
          ? _pasos[_indiceActual]
          : null;

  /// Pestaña de la Home que pide el paso actual, o null si el paso no
  /// necesita cambiar de sección. Los shells la leen para llevar al
  /// usuario hasta lo que se le está explicando.
  int? get pestanaActual => visible ? pasoActual?.pestana : null;

  /// Pestaña de la hoja de ajustes que pide el paso actual, o null cuando el
  /// paso no vive en ajustes (y entonces la hoja debe estar cerrada).
  int? get pestanaAjustesActual => visible ? pasoActual?.pestanaAjustes : null;

  /// Si el paso actual se explica adentro de la hoja de ajustes.
  bool get enAjustesActual => pestanaAjustesActual != null;

  /// Infraestructura de la capa visual: la monta el host del overlay para
  /// que quien abra la hoja de ajustes pueda volver a traerla al frente (si
  /// no, la hoja taparía al tutorial). No es estado del tutorial.
  VoidCallback? alFrente;

  /// Deja la capa del tutorial arriba de todo lo que haya abierto.
  void traerCapaAlFrente() => alFrente?.call();

  /// Índice del paso actual (0-based).
  int get indiceActual => _indiceActual;

  /// Total de pasos.
  int get totalPasos => _pasos.length;

  /// Si el overlay está visible.
  bool get visible => _visible;

  /// Si el tutorial ya fue completado.
  bool get completado => _completado;

  bool _completado = false;

  /// Inicializa el controller: carga estado de SharedPreferences y
  /// asigna los pasos con sus GlobalKeys.
  Future<void> inicializar(List<TutorialPaso> pasos) async {
    _pasos = pasos;
    final prefs = await SharedPreferences.getInstance();
    _completado = prefs.getBool(_claveCompletado) ?? false;
    _indiceActual = prefs.getInt(_clavePasoActual) ?? 0;
    _inicializado = true;

    // Si no está completado y hay pasos, mostrar.
    if (!_completado && _pasos.isNotEmpty) {
      mostrar();
    }
  }

  /// Muestra el overlay del tutorial.
  void mostrar() {
    if (_completado || !_inicializado || _pasos.isEmpty) return;
    _visible = true;
    notifyListeners();
  }

  /// Oculta el overlay sin completar (para uso temporal).
  void ocultar() {
    _visible = false;
    notifyListeners();
  }

  /// Avanza al siguiente paso. Si era el último, completa el tutorial.
  void siguiente() {
    if (_indiceActual < _pasos.length - 1) {
      _indiceActual++;
      _guardarProgreso();
      notifyListeners();
    } else {
      completar();
    }
  }

  /// Retrocede al paso anterior.
  void anterior() {
    if (_indiceActual > 0) {
      _indiceActual--;
      _guardarProgreso();
      notifyListeners();
    }
  }

  /// Salta el paso actual y va al siguiente (o completa si es el último).
  void saltarPaso() {
    siguiente();
  }

  /// Salta todo el tutorial y lo marca como completado.
  Future<void> saltarTodo() async {
    _completado = true;
    _visible = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_claveCompletado, true);
    notifyListeners();
  }

  /// Marca el tutorial como completado.
  Future<void> completar() async {
    _completado = true;
    _visible = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_claveCompletado, true);
    await prefs.remove(_clavePasoActual);
    notifyListeners();
  }

  /// Guarda el progreso actual en SharedPreferences.
  Future<void> _guardarProgreso() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_clavePasoActual, _indiceActual);
  }
}
