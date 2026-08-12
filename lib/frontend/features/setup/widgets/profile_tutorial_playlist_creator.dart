import 'package:flutter/material.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/theme/app_colors.dart';
import 'profile_tutorial_data.dart';

class PlaylistCreator extends StatelessWidget {
  final Set<int> selectedForPlaylist;
  final ValueChanged<int> onToggle;
  final Color onBg;
  final Color glowColor;

  const PlaylistCreator({
    super.key,
    required this.selectedForPlaylist,
    required this.onToggle,
    required this.onBg,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);

    return ListView(
      key: const ValueKey('playlistCreator'),
      padding: EdgeInsets.all(r.spacingS),
      children: [
        Row(children: [
          Icon(Icons.playlist_add_check, size: r.footerSize, color: glowColor),
          SizedBox(width: r.spacingXS),
          Text('Selecciona canciones',
            style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w600, color: onBg)),
          const Spacer(),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: EdgeInsets.symmetric(horizontal: r.spacingS, vertical: 2),
            decoration: BoxDecoration(
              color: selectedForPlaylist.isNotEmpty ? glowColor.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${selectedForPlaylist.length} seleccionadas',
              style: TextStyle(
                fontSize: r.footerSize - 1,
                color: selectedForPlaylist.isNotEmpty ? glowColor : onBg.withValues(alpha: 0.35),
                fontWeight: selectedForPlaylist.isNotEmpty ? FontWeight.w600 : FontWeight.normal),
            ),
          ),
        ]),
        SizedBox(height: r.spacingS),
        ...demoSongs.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          final sel = selectedForPlaylist.contains(i);
          return Padding(
            padding: EdgeInsets.only(bottom: r.spacingXS),
            child: GestureDetector(
              onTap: () => onToggle(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: sel ? glowColor.withValues(alpha: 0.4) : onBg.withValues(alpha: 0.08), width: sel ? 1.2 : 0.6),
                  color: sel ? glowColor.withValues(alpha: 0.08) : Colors.transparent,
                ),
                padding: EdgeInsets.all(r.spacingS),
                child: Row(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250), curve: Curves.easeOutBack,
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: sel ? glowColor : Colors.transparent,
                      border: Border.all(color: sel ? glowColor : onBg.withValues(alpha: 0.25), width: sel ? 0 : 1.5),
                    ),
                    child: sel ? Icon(Icons.check, size: 14, color: Colors.black) : null,
                  ),
                  SizedBox(width: r.spacingM),
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: glowColor.withValues(alpha: 0.1)),
                    child: Center(child: Text('${i + 1}',
                      style: TextStyle(fontSize: r.footerSize, fontWeight: FontWeight.w700, color: glowColor.withValues(alpha: 0.7)))),
                  ),
                  SizedBox(width: r.spacingM),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.title,
                      style: TextStyle(fontSize: r.footerSize + 1, fontWeight: FontWeight.w600, color: onBg),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(s.artist,
                      style: TextStyle(fontSize: r.footerSize - 2, color: onBg.withValues(alpha: 0.4)),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: glowColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                    child: Text(s.tag,
                      style: TextStyle(fontSize: r.footerSize - 3, fontWeight: FontWeight.w500, color: glowColor.withValues(alpha: 0.6))),
                  ),
                ]),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class CreatePlaylistButton extends StatelessWidget {
  final bool showCreator;
  final VoidCallback onToggle;

  const CreatePlaylistButton({super.key, required this.showCreator, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = isDark ? Colors.white : Colors.black;
    final glowColor = isDark ? AppColors.greenBright : AppColors.greenMedium;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingS),
      child: GestureDetector(
        onTap: onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: showCreator ? glowColor.withValues(alpha: 0.1) : onBg.withValues(alpha: 0.03),
            border: Border.all(
              color: showCreator ? glowColor.withValues(alpha: 0.4) : onBg.withValues(alpha: 0.1),
              width: showCreator ? 1.0 : 0.6,
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingS),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                showCreator ? Icons.check_circle_outline : Icons.playlist_add,
                key: ValueKey(showCreator),
                size: r.footerSize + 2,
                color: showCreator ? glowColor : onBg.withValues(alpha: 0.55)),
            ),
            SizedBox(width: r.spacingS),
            Text(showCreator ? 'Confirmar playlist' : 'Crear playlist',
              style: TextStyle(fontSize: r.footerSize, fontWeight: FontWeight.w600,
                color: showCreator ? glowColor : onBg.withValues(alpha: 0.6))),
          ]),
        ),
      ),
    );
  }
}


