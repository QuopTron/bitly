import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ViewMode { cover, visualizer }

class ViewModeNotifier extends Notifier<ViewMode> {
  @override
  ViewMode build() => ViewMode.cover;

  void toggle() {
    state = state == ViewMode.cover ? ViewMode.visualizer : ViewMode.cover;
  }
}

final viewModeProvider = NotifierProvider<ViewModeNotifier, ViewMode>(
  ViewModeNotifier.new,
);
