import 'package:flutter/material.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/glass_button.dart';
import 'profile_tutorial_data.dart';

/// Header icon, title, and description for the profile tutorial slide.
class ProfileHeader extends StatelessWidget {
  final Color onBg;
  final Responsive r;
  final String title;
  final String description;

  const ProfileHeader({
    super.key,
    required this.onBg,
    required this.r,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: EdgeInsets.all(r.spacingS),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onBg.withValues(alpha: 0.04),
          border: Border.all(color: onBg.withValues(alpha: 0.08), width: 0.8),
        ),
        child: Icon(Icons.grid_view_rounded, size: r.titleSize * 1.1, color: onBg.withValues(alpha: 0.55)),
      ),
      SizedBox(height: r.spacingS),
      Text(title,
        style: TextStyle(fontSize: r.titleSize, fontWeight: FontWeight.bold, color: onBg, letterSpacing: 1)),
      SizedBox(height: 2),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
        child: Text(description,
          style: TextStyle(fontSize: r.footerSize, color: onBg.withValues(alpha: 0.5)),
          textAlign: TextAlign.center),
      ),
    ]);
  }
}

/// Profile section with avatar, name, stats, and listening time badge.
/// Accepts an optional [pulseAnim] to drive a subtle scale animation on the avatar.
class ProfileSection extends StatelessWidget {
  final Color onBg;
  final Color glowColor;
  final Responsive r;
  final Animation<double>? pulseAnim;
  final int songCount;
  final int playlistCount;

  const ProfileSection({
    super.key,
    required this.onBg,
    required this.glowColor,
    required this.r,
    this.pulseAnim,
    this.songCount = 8,
    this.playlistCount = 3,
  });

  Widget _avatar(double avatarSize) {
    final avatar = Container(
      width: avatarSize, height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [glowColor.withValues(alpha: 0.35), glowColor.withValues(alpha: 0.1)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        border: Border.all(color: glowColor.withValues(alpha: 0.45), width: 2),
        boxShadow: [BoxShadow(color: glowColor.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 2))],
      ),
      child: Icon(Icons.person, size: avatarSize * 0.45, color: onBg.withValues(alpha: 0.5)),
    );
    if (pulseAnim != null) {
      return AnimatedBuilder(
        animation: pulseAnim!,
        builder: (context, _) => Transform.scale(scale: pulseAnim!.value, child: avatar),
      );
    }
    return avatar;
  }

  @override
  Widget build(BuildContext context) {
    final avatarSize = r.titleSize * 2.2;
    return Padding(
      padding: EdgeInsets.fromLTRB(r.spacingL, r.spacingM, r.spacingL, 0),
      child: Row(children: [
        _avatar(avatarSize),
        SizedBox(width: r.spacingM),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Bad Bunny Fan',
            style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w600, color: onBg)),
          SizedBox(height: 2),
          Text('$songCount canciones  •  $playlistCount playlists',
            style: TextStyle(fontSize: r.footerSize - 1, color: onBg.withValues(alpha: 0.4))),
        ])),
        Container(
          padding: EdgeInsets.symmetric(horizontal: r.spacingS, vertical: 4),
          decoration: BoxDecoration(color: glowColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.headphones, size: r.footerSize, color: glowColor),
            SizedBox(width: 4),
            Text('42 min',
              style: TextStyle(fontSize: r.footerSize - 1, fontWeight: FontWeight.w600, color: glowColor)),
          ]),
        ),
      ]),
    );
  }
}

/// Row of tab chips for switching between content types.
class ProfileTabChips extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Color onBg;
  final Color glowColor;
  final Responsive r;

  const ProfileTabChips({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.onBg,
    required this.glowColor,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingS),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: List.generate(demoTabs.length, (i) {
          final t = demoTabs[i];
          final sel = selectedIndex == i;
          return Padding(
            padding: EdgeInsets.only(right: r.spacingXS),
            child: GestureDetector(
              onTap: () => onSelected(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: sel ? glowColor.withValues(alpha: 0.15) : Colors.transparent,
                  border: Border.all(
                    color: sel ? glowColor.withValues(alpha: 0.5) : onBg.withValues(alpha: 0.1),
                    width: sel ? 1.0 : 0.6,
                  ),
                ),
                padding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingXS),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(t.icon, size: r.footerSize + 1, color: sel ? glowColor : onBg.withValues(alpha: 0.45)),
                  SizedBox(width: r.spacingXS),
                  Text(t.label, style: TextStyle(fontSize: r.footerSize,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                    color: sel ? glowColor : onBg.withValues(alpha: 0.45))),
                ]),
              ),
            ),
          );
        })),
      ),
    );
  }
}

/// Inactive mini search bar for the demo.
class ProfileMiniSearch extends StatelessWidget {
  final Color onBg;
  final Color glowColor;
  final Responsive r;
  final String tabLabel;

  const ProfileMiniSearch({
    super.key,
    required this.onBg,
    required this.glowColor,
    required this.r,
    required this.tabLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingS),
      child: GlassContainer(
        borderRadius: 10, borderColor: onBg.withValues(alpha: 0.08),
        padding: EdgeInsets.symmetric(horizontal: r.spacingM),
        child: Row(children: [
          Icon(Icons.search_rounded, size: r.footerSize + 2, color: onBg.withValues(alpha: 0.3)),
          SizedBox(width: r.spacingXS),
          Expanded(child: TextField(
            enabled: false,
            style: TextStyle(fontSize: r.footerSize, color: onBg),
            decoration: InputDecoration(
              hintText: 'Buscar en $tabLabel...',
              hintStyle: TextStyle(fontSize: r.footerSize, color: onBg.withValues(alpha: 0.25)),
              border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
          )),
          Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(color: glowColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Icon(Icons.tune, size: r.footerSize - 2, color: glowColor.withValues(alpha: 0.6)),
          ),
        ]),
      ),
    );
  }
}

/// Row of filter chips.
class ProfileFilterChips extends StatelessWidget {
  final int selectedIndex;
  final List<String> filters;
  final ValueChanged<int> onSelected;
  final Color onBg;
  final Color glowColor;
  final Responsive r;

  const ProfileFilterChips({
    super.key,
    required this.selectedIndex,
    required this.filters,
    required this.onSelected,
    required this.onBg,
    required this.glowColor,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingS),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: List.generate(filters.length, (i) {
          final f = filters[i];
          final sel = selectedIndex == i;
          return Padding(
            padding: EdgeInsets.only(right: r.spacingXS),
            child: GestureDetector(
              onTap: () => onSelected(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: sel ? glowColor.withValues(alpha: 0.12) : onBg.withValues(alpha: 0.04),
                  border: Border.all(color: sel ? glowColor.withValues(alpha: 0.3) : onBg.withValues(alpha: 0.06)),
                ),
                padding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: 4),
                child: Text(f, style: TextStyle(fontSize: r.footerSize - 1,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                  color: sel ? glowColor : onBg.withValues(alpha: 0.4))),
              ),
            ),
          );
        })),
      ),
    );
  }
}

/// Bottom navigation buttons (back / continue).
class ProfileNavButtons extends StatelessWidget {
  final Color glowColor;
  final String backLabel;
  final String continueLabel;
  final VoidCallback onBack;
  final VoidCallback onContinue;
  final Responsive r;

  const ProfileNavButtons({
    super.key,
    required this.glowColor,
    required this.backLabel,
    required this.continueLabel,
    required this.onBack,
    required this.onContinue,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
      child: SizedBox(
        height: r.continueButtonHeight,
        child: Row(children: [
          Expanded(child: GlassButton(
            label: backLabel, onPressed: onBack,
            height: r.continueButtonHeight, accent: glowColor)),
          SizedBox(width: r.spacingM),
          Expanded(child: GlassButton(
            label: continueLabel, onPressed: onContinue,
            height: r.continueButtonHeight, accent: glowColor)),
        ]),
      ),
    );
  }
}


