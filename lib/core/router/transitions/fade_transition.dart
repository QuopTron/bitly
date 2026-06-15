import 'package:flutter/material.dart';

class FadePageTransition extends Page {
  final Widget child;

  const FadePageTransition({
    required this.child,
    super.key,
  });

  @override
  Route createRoute(BuildContext context) {
    return _FadeRoute(settings: this);
  }
}

class _FadeRoute extends PageRouteBuilder {
  _FadeRoute({required super.settings})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) {
            final page = settings as FadePageTransition;
            return page.child;
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _FadeTween(animation: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        );
}

class _FadeTween extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _FadeTween({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: animation, child: child);
  }
}
