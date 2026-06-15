import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/settings_bloc/settings_bloc.dart';
import '../bloc/settings_bloc/settings_event.dart';
import '../bloc/settings_bloc/settings_state.dart';
import '../widgets/settings_tile.dart';
import '../widgets/settings_switch.dart';

class GeneralSettingsSection extends StatelessWidget {
  const GeneralSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        final s = state.settings;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('General', style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                )),
                const SizedBox(height: 12),
                SettingsTile(
                  icon: Icons.person_outline,
                  title: 'Nombre de usuario',
                  subtitle: s.username ?? 'No establecido',
                  onTap: () => _showEditDialog(context, 'username', s.username ?? ''),
                ),
                const Divider(),
                SettingsTile(
                  icon: Icons.language,
                  title: 'Idioma',
                  subtitle: s.language == 'es' ? 'Español' : 'English',
                  onTap: () => _showLanguagePicker(context, s.language),
                ),
                const Divider(),
                SettingsSwitch(
                  icon: Icons.bug_report,
                  title: 'Registro de depuración',
                  value: s.loggingEnabled,
                  onChanged: (v) => context.read<SettingsBloc>().add(
                    UpdateSettingsField('loggingEnabled', v),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, String key, String current) {
    final controller = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Valor'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              context.read<SettingsBloc>().add(UpdateSettingsField(key, controller.text));
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, String current) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Idioma'),
        children: [
          RadioGroup<String>(
            groupValue: current,
            onChanged: (v) {
              if (v != null) {
                context.read<SettingsBloc>().add(UpdateSettingsField('language', v));
                Navigator.pop(ctx);
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: const Text('Español'),
                  value: 'es',
                ),
                RadioListTile<String>(
                  title: const Text('English'),
                  value: 'en',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
