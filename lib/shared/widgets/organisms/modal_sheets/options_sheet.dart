import 'package:flutter/material.dart';
import 'base_bottom_sheet.dart';

class OptionItem {
  final String label;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;
  final bool destructive;

  OptionItem({
    required this.label,
    this.icon,
    this.color,
    this.onTap,
    this.destructive = false,
  });
}

class OptionsSheet extends StatelessWidget {
  final String title;
  final List<OptionItem> options;

  const OptionsSheet({
    super.key,
    required this.title,
    required this.options,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required List<OptionItem> options,
  }) {
    return BaseBottomSheet.show<void>(
      context,
      child: OptionsSheet(title: title, options: options),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 16),
        ...options.map((option) => ListTile(
          leading: option.icon != null
              ? Icon(option.icon, color: option.destructive ? Colors.red : option.color)
              : null,
          title: Text(
            option.label,
            style: TextStyle(
              color: option.destructive ? Colors.red : null,
            ),
          ),
          onTap: () {
            Navigator.pop(context);
            option.onTap?.call();
          },
        )),
      ],
    );
  }
}
