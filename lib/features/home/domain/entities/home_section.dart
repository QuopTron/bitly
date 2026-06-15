import 'package:flutter/material.dart';

enum SectionType { recent, quickActions, discover }

class SectionItem {
  final String title;
  final String subtitle;
  final IconData icon;

  const SectionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class HomeSection {
  final String title;
  final SectionType type;
  final List<SectionItem> items;

  const HomeSection({
    required this.title,
    required this.type,
    required this.items,
  });
}
