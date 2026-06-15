import 'package:flutter/material.dart';

class SettingsDropdown extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const SettingsDropdown({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title, style: theme.textTheme.bodyLarge),
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        dropdownColor: theme.colorScheme.surface,
        items: items.map((item) => DropdownMenuItem(
          value: item,
          child: Text(item),
        )).toList(),
        onChanged: onChanged,
      ),
      contentPadding: EdgeInsets.zero,
    );
  }
}
