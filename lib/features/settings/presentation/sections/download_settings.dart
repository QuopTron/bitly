import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/settings_bloc/settings_bloc.dart';
import '../bloc/settings_bloc/settings_event.dart';
import '../bloc/settings_bloc/settings_state.dart';
import '../widgets/settings_tile.dart';
import '../widgets/settings_slider.dart';

class DownloadSettingsSection extends StatelessWidget {
  const DownloadSettingsSection({super.key});

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
                Text('Descargas', style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                )),
                const SizedBox(height: 12),
                SettingsTile(
                  icon: Icons.folder,
                  title: 'Directorio de descargas',
                  subtitle: s.downloadDirectory ?? 'Por defecto',
                  onTap: () => _pickDirectory(context),
                ),
                const Divider(),
                SettingsSlider(
                  icon: Icons.speed,
                  title: 'Descargas simultáneas',
                  value: s.maxConcurrentDownloads.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  displayValue: '${s.maxConcurrentDownloads}',
                  onChanged: (v) => context.read<SettingsBloc>().add(
                    UpdateSettingsField('maxConcurrentDownloads', v.round()),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickDirectory(BuildContext context) async {
    final settingsBloc = context.read<SettingsBloc>();
    final initialDir = settingsBloc.state.settings.downloadDirectory ?? '';
    final controller = TextEditingController(text: initialDir);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Directorio de descargas'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Ruta del directorio',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      settingsBloc.add(UpdateSettingsField('downloadDirectory', result));
    }
  }
}
