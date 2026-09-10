// ─────────────────────────────────────────────────────────────
// fila_controles_botones.dart — PART de fila_controles_reproductor.dart:
// botones laterales de la fila de controles — like (con animación
// de switch), shuffle, anterior, siguiente, repetición y letras
// (con spinner mientras busca). Despachan al cubit correspondiente
// con feedback háptico.
// Se conecta con: fila_controles_reproductor.dart (misma library)
// + cubits + haptico.
// Parte del flujo: reproductor (NowPlaying, botones).
// ─────────────────────────────────────────────────────────────

part of 'fila_controles_reproductor.dart';

Widget _botonLike(
  FilaControlesReproductor f,
  Color activo,
  Color apagado,
  double iconoM,
) {
  return BlocBuilder<CubitLikes, EstadoLikes>(
    builder: (context, _) {
      final amado = context.read<CubitLikes>().estaAmado(f.track);
      return GestureDetector(
        onTap: () {
          Haptico.medio();
          context.read<CubitLikes>().alternarLike(f.track);
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Icon(
            amado ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            key: ValueKey(amado),
            color: amado ? Colors.redAccent : apagado,
            size: iconoM,
          ),
        ),
      );
    },
  );
}

Widget _botonShuffle(
  FilaControlesReproductor f,
  Color activo,
  Color apagado,
  double iconoM,
) {
  return GestureDetector(
    onTap: () {
      Haptico.tap();
      sl<CubitCola>().alternarShuffle();
    },
    child: Icon(
      f.cola.shuffle ? Icons.shuffle_rounded : Icons.shuffle,
      color: f.cola.shuffle ? activo : apagado,
      size: iconoM,
    ),
  );
}

Widget _botonAnterior(Color activo, double iconoL) {
  return GestureDetector(
    onTap: () {
      Haptico.tap();
      sl<CubitCola>().anterior();
    },
    child: Icon(Icons.skip_previous_rounded, color: activo, size: iconoL),
  );
}

Widget _botonSiguiente(Color activo, double iconoL) {
  return GestureDetector(
    onTap: () {
      Haptico.tap();
      sl<CubitCola>().siguiente();
    },
    child: Icon(Icons.skip_next_rounded, color: activo, size: iconoL),
  );
}

Widget _botonRepeticion(
  FilaControlesReproductor f,
  Color activo,
  Color apagado,
  double iconoM,
) {
  return GestureDetector(
    onTap: () {
      Haptico.tap();
      sl<CubitCola>().ciclarModoRepeticion();
    },
    child: Icon(
      _iconoRepeticion(f.cola.modoRepeticion),
      color: f.cola.modoRepeticion != ModoRepeticion.ninguno ? activo : apagado,
      size: iconoM,
    ),
  );
}

Widget _botonLetras(FilaControlesReproductor f, Color apagado) {
  final r = f.r;
  return GestureDetector(
    onTap: f.letrasCargando ? null : f.onAlternarLetras,
    child: f.letrasCargando
        ? SizedBox(
            width: r.subtitleSize + 4,
            height: r.subtitleSize + 4,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: apagado.withValues(alpha: 0.6),
            ),
          )
        : Icon(Icons.lyrics_outlined, color: apagado, size: r.subtitleSize + 5),
  );
}

/// Icono según el modo de repetición actual.
IconData _iconoRepeticion(ModoRepeticion modo) {
  switch (modo) {
    case ModoRepeticion.ninguno:
      return Icons.repeat_rounded;
    case ModoRepeticion.uno:
      return Icons.repeat_one_rounded;
    case ModoRepeticion.todos:
      return Icons.repeat_rounded;
  }
}