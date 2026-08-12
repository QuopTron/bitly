import 'package:flutter/material.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/constants/source_constants.dart';

const typeIcons = <String, IconData>{
  'tracks': Icons.music_note, 'artists': Icons.person,
  'albums': Icons.album, 'playlists': Icons.playlist_play,
};

const supportedTypes = <String, List<String>>{
  'tidal-web': ['tracks', 'artists', 'albums', 'playlists'],
  'qobuz-web': ['tracks', 'artists', 'albums'],
  'deezer': ['tracks', 'artists', 'albums', 'playlists'],
  'spotify-web': ['tracks', 'artists', 'albums', 'playlists'],
  'apple-music': ['tracks', 'artists', 'albums', 'playlists'],
  'soundcloud': ['tracks', 'artists', 'albums', 'playlists'],
  'amazon': ['tracks', 'artists', 'albums', 'playlists'],
  'pandora': ['tracks'],
  'ytmusic-spotiflac': ['tracks', 'artists', 'albums', 'playlists'],
};

class SourceBadge extends StatelessWidget {
  final String selectedSource;
  final Color onBg;
  final Color glowColor;

  const SourceBadge({super.key, required this.selectedSource, required this.onBg, required this.glowColor});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingS),
      child: Row(children: [
        Icon(sourceIcons[selectedSource] ?? Icons.search, size: r.footerSize, color: glowColor.withValues(alpha: 0.6)),
        SizedBox(width: 4),
        Text(sourceLabels[selectedSource] ?? formatId(selectedSource),
          style: TextStyle(fontSize: r.footerSize - 1, color: onBg.withValues(alpha: 0.4))),
      ]),
    );
  }
}

class TutorialUrlPaste extends StatelessWidget {
  final Color onBg;
  final Color glowColor;
  final String pasteHint;

  const TutorialUrlPaste({super.key, required this.onBg, required this.glowColor, required this.pasteHint});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(r.spacingL),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.link, size: r.titleSize * 1.5, color: onBg.withValues(alpha: 0.15)),
          SizedBox(height: r.spacingM),
          Text(pasteHint, style: TextStyle(fontSize: r.footerSize, color: onBg.withValues(alpha: 0.4)), textAlign: TextAlign.center),
          SizedBox(height: r.spacingM),
          Row(mainAxisSize: MainAxisSize.min, children: [
            _badge(Icons.play_circle_fill, 'YouTube', r, glowColor, onBg),
            SizedBox(width: r.spacingS),
            _badge(Icons.music_note, 'Spotify', r, glowColor, onBg),
          ]),
        ]),
      ),
    );
  }

  Widget _badge(IconData icon, String label, Responsive r, Color glowColor, Color onBg) {
    return GlassContainer(
      borderRadius: 20, borderColor: glowColor.withValues(alpha: 0.2),
      bgColor: glowColor.withValues(alpha: 0.06),
      padding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingXS),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: r.footerSize, color: glowColor),
        SizedBox(width: r.spacingXS),
        Text(label, style: TextStyle(fontSize: r.footerSize, color: glowColor, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}


