import 'package:flutter/material.dart';
import '../../domain/entities/home_section.dart';
import '../widgets/quick_action_button.dart';

class QuickActionsTab extends StatelessWidget {
  final List<SectionItem> items;

  const QuickActionsTab({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: items
            .map((item) => QuickActionButton(
                  icon: item.icon,
                  label: item.title,
                  onTap: () {},
                ))
            .toList(),
      ),
    );
  }
}
