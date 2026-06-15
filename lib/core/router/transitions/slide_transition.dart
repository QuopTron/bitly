import 'package:flutter/material.dart';

class SlidePageTransition extends Page {
  final Widget child;

  const SlidePageTransition({
    required this.child,
    super.key,
  });

  @override
  Route createRoute(BuildContext context) {
    return _SlideRoute(settings: this);
  }
}

class _SlideRoute extends PageRouteBuilder {
  _SlideRoute({required super.settings})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) {
            final page = settings as SlidePageTransition;
            return page.child;
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _SlideTween(animation: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        );
}

class _SlideTween extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _SlideTween({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(animation),
      child: child,
    );
  }
}
