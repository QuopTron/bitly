import 'package:flutter/foundation.dart';

class AuthGuard {
  final ValueNotifier<bool> isSetupCompleted;

  AuthGuard({required this.isSetupCompleted});

  String? redirect(String uri) {
    if (uri == '/home' && !isSetupCompleted.value) {
      return '/setup';
    }
    return null;
  }
}
