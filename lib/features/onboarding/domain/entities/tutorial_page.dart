import 'package:flutter/material.dart';

class TutorialPage {
  final IconData icon;
  final String title;
  final String description;
  final String? image;

  const TutorialPage({
    required this.icon,
    required this.title,
    required this.description,
    this.image,
  });

  static List<TutorialPage> get defaultPages => const [
    TutorialPage(
      icon: Icons.music_note,
      title: 'Bienvenido a Bitly',
      description: 'Tu gestor de música inteligente. Descarga, organiza y disfruta tu música favorita.',
    ),
    TutorialPage(
      icon: Icons.download,
      title: 'Descargas Inteligentes',
      description: 'Descarga música desde múltiples fuentes con un solo clic. Calidad de audio superior.',
    ),
    TutorialPage(
      icon: Icons.library_music,
      title: 'Organiza tu Biblioteca',
      description: 'Administra tu colección con metadatos automáticos, playlists y etiquetado inteligente.',
    ),
    TutorialPage(
      icon: Icons.person,
      title: 'Perfil Personalizado',
      description: 'Crea tu perfil, sincroniza entre dispositivos y descubre nueva música.',
    ),
    TutorialPage(
      icon: Icons.verified,
      title: 'Listo para Empezar',
      description: 'Configura tu experiencia en los siguientes pasos. ¡Vamos allá!',
    ),
  ];
}
