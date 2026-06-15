import 'package:flutter/foundation.dart';

class SetupGuard {
  final ValueNotifier<bool> isSetupCompleted;

  SetupGuard({required this.isSetupCompleted});

  String? redirect(String uri) {
    if (uri == '/setup' && isSetupCompleted.value) {
      return '/home';
    }
    return null;
  }
}
