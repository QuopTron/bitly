import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TutorialPage extends StatefulWidget {
  const TutorialPage({super.key});
  @override
  State<TutorialPage> createState() => _TutorialPageState();
}

class _TutorialPageState extends State<TutorialPage> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _steps = [
    _TutorialStep(
      icon: Icons.music_note,
      title: 'Bienvenido a Bitly',
      desc: 'Descarga musica en calidad FLAC desde multiples fuentes.',
    ),
    _TutorialStep(
      icon: Icons.search,
      title: 'Busca tu musica',
      desc: 'Busca por nombre, artista o pega un enlace de Spotify, Deezer, Tidal y mas.',
    ),
    _TutorialStep(
      icon: Icons.download,
      title: 'Descarga offline',
      desc: 'Descarga tracks o discos enteros con un toque. Elige la calidad que prefieras.',
    ),
    _TutorialStep(
      icon: Icons.extension,
      title: 'Extensiones',
      desc: 'Instala extensiones desde la tienda para agregar nuevas fuentes de musica.',
    ),
  ];

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_tutorial', true);
    if (mounted) context.go('/');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _steps.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final s = _steps[i];
                  return Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(s.icon, size: 80, color: const Color(0xFF1DB954)),
                        const SizedBox(height: 32),
                        Text(s.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        Text(s.desc, style: const TextStyle(fontSize: 16, color: Colors.grey), textAlign: TextAlign.center),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_steps.length, (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _page == i ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _page == i ? const Color(0xFF1DB954) : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1DB954), foregroundColor: Colors.white),
                  onPressed: _page == _steps.length - 1 ? _complete : () {
                    _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  },
                  child: Text(_page == _steps.length - 1 ? 'Empezar' : 'Siguiente'),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _TutorialStep {
  final IconData icon;
  final String title;
  final String desc;
  const _TutorialStep({required this.icon, required this.title, required this.desc});
}
