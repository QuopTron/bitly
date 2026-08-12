import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/widgets/glass_container.dart';
import '../bloc/setup_state.dart';
import '../bloc/setup_bloc.dart';
import '../bloc/setup_event.dart';

class UsernameField extends StatelessWidget {
  final SetupState state;
  final AppLocalizations loc;
  final Responsive r;
  final Color onBg;
  final Color glowColor;
  final TextEditingController controller;

  const UsernameField({
    super.key,
    required this.state,
    required this.loc,
    required this.r,
    required this.onBg,
    required this.glowColor,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
      child: Column(
        children: [
          _input(context),
          if (state.username.trim().isNotEmpty) _badge(),
        ],
      ),
    );
  }

  Widget _input(BuildContext context) {
    return GlassContainer(
      borderRadius: 12,
      borderColor: onBg.withValues(alpha: 0.08),
      bgColor: onBg.withValues(alpha: 0.03),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: loc.setup.usernameHint,
                hintStyle: TextStyle(color: onBg.withValues(alpha: 0.35), fontSize: r.footerSize),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingS + 2),
              ),
              style: TextStyle(color: onBg, fontSize: r.subtitleSize),
              textCapitalization: TextCapitalization.words,
              onChanged: (val) => context.read<SetupBloc>().add(UsernameChanged(val)),
            ),
          ),
          _dice(context),
        ],
      ),
    );
  }

  Widget _dice(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<SetupBloc>().add(const GenerateRandomName()),
      child: Container(
        margin: EdgeInsets.all(4),
        padding: EdgeInsets.all(r.spacingS),
        decoration: BoxDecoration(
          color: glowColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.casino, color: glowColor, size: r.languageCardIconSize * 0.75),
      ),
    );
  }

  Widget _badge() {
    return Padding(
      padding: EdgeInsets.only(top: r.spacingS),
      child: GlassContainer(
        borderRadius: 8,
        borderColor: glowColor.withValues(alpha: 0.2),
        bgColor: glowColor.withValues(alpha: 0.06),
        padding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingXS),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, color: glowColor, size: r.footerSize),
            SizedBox(width: r.spacingXS),
            Flexible(child: Text(state.username,
                style: TextStyle(color: glowColor, fontSize: r.footerSize, fontWeight: FontWeight.w600))),
          ],
        ),
      ),
    );
  }
}


