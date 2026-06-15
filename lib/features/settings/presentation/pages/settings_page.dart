import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../bloc/settings_bloc/settings_bloc.dart';
import '../bloc/settings_bloc/settings_event.dart';
import '../bloc/settings_bloc/settings_state.dart';
import '../sections/general_settings.dart';
import '../sections/download_settings.dart';
import '../sections/appearance_settings.dart';
import '../sections/lyrics_settings.dart';
import '../sections/scrobbling_settings.dart';
import '../sections/advanced_settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sl = GetIt.instance;
    return BlocProvider<SettingsBloc>(
      create: (_) => sl<SettingsBloc>()..add(LoadSettingsEvent()),
      child: _SettingsView(),
    );
  }
}

class _SettingsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        centerTitle: true,
      ),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      color: theme.colorScheme.error, size: 48),
                  const SizedBox(height: 8),
                  Text(state.error!, style: theme.textTheme.bodyMedium),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: const [
              GeneralSettingsSection(),
              SizedBox(height: 8),
              DownloadSettingsSection(),
              SizedBox(height: 8),
              AppearanceSettingsSection(),
              SizedBox(height: 8),
              LyricsSettingsSection(),
              SizedBox(height: 8),
              ScrobblingSettingsSection(),
              SizedBox(height: 8),
              AdvancedSettingsSection(),
              SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}
