import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../bloc/appearance_bloc/appearance_bloc.dart';
import '../bloc/appearance_bloc/appearance_event.dart';
import '../bloc/appearance_bloc/appearance_state.dart';
import '../widgets/settings_tile.dart';
import '../widgets/settings_switch.dart';
import '../../data/repositories/settings_repository.dart';

class AppearanceSettingsSection extends StatelessWidget {
  const AppearanceSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = GetIt.instance<SettingsRepository>();
    return BlocProvider<AppearanceBloc>(
      create: (_) => AppearanceBloc(repo)..add(LoadAppearance()),
      child: BlocBuilder<AppearanceBloc, AppearanceState>(
        builder: (context, state) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Apariencia', style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  )),
                  const SizedBox(height: 12),
                  SettingsTile(
                    icon: Icons.dark_mode_outlined,
                    title: 'Modo oscuro',
                    subtitle: state.settings.themeMode == 'dark' ? 'Activado' : 'Desactivado',
                    onTap: () => context.read<AppearanceBloc>().add(
                      UpdateThemeMode(state.settings.themeMode == 'dark' ? 'light' : 'dark'),
                    ),
                  ),
                  const Divider(),
                  SettingsSwitch(
                    icon: Icons.blur_on,
                    title: 'Efectos de cristal',
                    value: state.settings.useGlassEffects,
                    onChanged: (v) => context.read<AppearanceBloc>().add(ToggleGlassEffects(v)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
