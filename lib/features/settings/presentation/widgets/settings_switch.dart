import 'package:flutter/material.dart';

class SettingsSwitch extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingsSwitch({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title, style: theme.textTheme.bodyLarge),
      trailing: Switch(
        value: value,
        activeThumbColor: theme.colorScheme.primary,
        onChanged: onChanged,
      ),
      contentPadding: EdgeInsets.zero,
    );
  }
}
