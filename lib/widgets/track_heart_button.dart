import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/models/track.dart';
import 'package:bitly/providers/library_collections_provider.dart';

class TrackHeartButton extends ConsumerWidget {
  final Track track;
  const TrackHeartButton({super.key, required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoved = ref.watch(
      libraryCollectionsProvider.select((s) => s.isLoved(track)),
    );
    return IconButton(
      icon: Icon(
        isLoved ? Icons.favorite : Icons.favorite_border,
        size: 18,
        color: isLoved ? Colors.redAccent : null,
      ),
      onPressed: () {
        ref.read(libraryCollectionsProvider.notifier).toggleLoved(track);
      },
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}
