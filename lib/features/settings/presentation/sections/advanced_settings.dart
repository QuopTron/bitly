import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/settings_bloc/settings_bloc.dart';
import '../bloc/settings_bloc/settings_event.dart';
import '../bloc/settings_bloc/settings_state.dart';
import '../widgets/settings_switch.dart';

class AdvancedSettingsSection extends StatelessWidget {
  const AdvancedSettingsSection({super.key});

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
                Text('Avanzado', style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                )),
                const SizedBox(height: 12),
                SettingsSwitch(
                  icon: Icons.warning_amber_outlined,
                  title: 'Restablecer configuración',
                  value: false,
                  onChanged: (_) => _confirmReset(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restablecer configuración'),
        content: const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              context.read<SettingsBloc>().add(ResetSettingsEvent());
              Navigator.pop(ctx);
            },
            child: const Text('Restablecer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
