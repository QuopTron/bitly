// tutorial_target.dart — Widget wrapper que asigna un GlobalKey al
// widget hijo para que el tutorial interactivo pueda localizarlo y
// posicionar el spotlight sobre él. Se usa para marcar los widgets
// objetivo del tutorial.

import 'package:flutter/material.dart';

/// Wrapper que asigna un GlobalKey al widget hijo.
///
/// Uso:
/// ```dart
/// TutorialTarget(
///   key: mi GlobalKey,  // se pasa desde afuera
///   child: MiWidget(),
/// )
/// ```
///
/// O directamente con un GlobalKey constante:
/// ```dart
/// TutorialTarget(
///   child: MiWidget(),
/// )
/// ```
///
/// El GlobalKey se asigna al widget wrapper, no al child.
class TutorialTarget extends StatelessWidget {
  final Widget child;

  const TutorialTarget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
