import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/settings_bloc/settings_bloc.dart';
import '../bloc/settings_bloc/settings_event.dart';
import '../bloc/settings_bloc/settings_state.dart';
import '../widgets/settings_switch.dart';

class LyricsSettingsSection extends StatelessWidget {
  const LyricsSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Letras', style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                )),
                const SizedBox(height: 12),
                SettingsSwitch(
                  icon: Icons.lyrics_outlined,
                  title: 'Obtener letras automáticamente',
                  value: state.settings.autoFetchLyrics,
                  onChanged: (v) => context.read<SettingsBloc>().add(
                    UpdateSettingsField('autoFetchLyrics', v),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
