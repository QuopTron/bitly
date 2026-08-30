import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/widgets/source_accordion.dart';
import '../bloc/feed_bloc.dart';
import '../bloc/feed_event.dart';

class FeedHeader extends StatelessWidget {
  final Color onBg;
  final Color glowColor;
  final Map<String, String> sources;

  const FeedHeader({
    super.key,
    required this.onBg,
    required this.glowColor,
    required this.sources,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final r = Responsive(context);
    final state = context.watch<FeedBloc>().state;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? loc.setup.feedGoodMorning
        : hour < 18
            ? loc.setup.feedGoodAfternoon
            : loc.setup.feedGoodEvening;

    final hasName = state.username.isNotEmpty;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Gradient greeting text
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: isDark
                        ? [Colors.white, AppColors.greenPale]
                        : [Colors.black, AppColors.greenDeep],
                  ).createShader(bounds),
                  child: Text(
                    greeting,
                    style: TextStyle(
                      fontSize: r.titleSize * 1.15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: Colors.white, // masked by shader
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasName) ...[
                  SizedBox(height: 2),
                  Text(
                    state.username,
                    style: TextStyle(
                      fontSize: r.footerSize,
                      fontWeight: FontWeight.w500,
                      color: onBg.withValues(alpha: 0.45),
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (sources.isNotEmpty) ...[
            SizedBox(width: r.spacingM),
            SourceAccordion(
              sources: sources,
              selectedSource: state.selectedSource,
              onBg: onBg,
              glowColor: glowColor,
              onChanged: (v) => context.read<FeedBloc>().add(FeedSourceChanged(v)),
            ),
          ],
        ],
      ),
    );
  }
}
