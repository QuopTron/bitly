import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../l10n/app_localizations.dart';
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
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? loc.setup.feedGoodMorning
        : hour < 18
            ? loc.setup.feedGoodAfternoon
            : loc.setup.feedGoodEvening;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
      child: Row(
        children: [
          Expanded(
            child: Text('$greeting${state.username.isNotEmpty ? ', ${state.username}' : ''}',
              style: TextStyle(fontSize: r.titleSize, fontWeight: FontWeight.bold, color: onBg),
              overflow: TextOverflow.ellipsis),
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
