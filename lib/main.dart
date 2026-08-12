import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'app.dart';
import 'injection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializar media_kit ANTES de crear cualquier Player (PlayerCubit).
  MediaKit.ensureInitialized();
  await configureDependencies();
  await loadPerformanceProfile();
  runApp(const BitlyApp());
}
