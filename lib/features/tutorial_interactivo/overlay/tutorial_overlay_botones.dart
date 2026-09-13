// tutorial_overlay_botones.dart — PART de tutorial_overlay.dart: los botones del
// tutorial (saltar paso, atrás, siguiente / entendido y salir del tutorial).
//
// Se conecta con: tutorial_overlay_tarjeta (los coloca) y l10n (textos ES/EN).
// Parte del flujo: tutorial interactivo (acciones de la capa 2).
part of 'tutorial_overlay.dart';

/// Botón redondo de solo icono (la flecha de "atrás"). Redondo para que sea
/// un blanco fácil de tocar también en celular.
class _BotonFlecha extends StatelessWidget {
  final IconData icono;
  final String tooltip;
  final bool esOscuro;
  final VoidCallback onTap;

  const _BotonFlecha({
    required this.icono,
    required this.tooltip,
    required this.esOscuro,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: ColoresApp.splash(esOscuro),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          // Foco visible: con el control remoto (TV) o el Tab (PC) se tiene
          // que ver cuál botón está seleccionado.
          focusColor: _verdeTutorial.withValues(alpha: 0.35),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(
              icono,
              size: 17,
              color: ColoresApp.enSuperficie(esOscuro),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón principal (siguiente / entendido).
class _BotonPrincipal extends StatelessWidget {
  final String etiqueta;
  final bool esOscuro;
  final bool esUltimo;
  final VoidCallback onTap;

  const _BotonPrincipal({
    required this.etiqueta,
    required this.esOscuro,
    required this.esUltimo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fondo = esUltimo ? _verdeTutorial : ColoresApp.enSuperficie(esOscuro);
    final texto = esUltimo ? Colors.white : ColoresApp.superficie(esOscuro);
    return Material(
      color: fondo,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        // Foco visible en la tarjeta: es el botón que avanza el tutorial.
        focusColor: _verdeTutorial.withValues(alpha: esUltimo ? 0.5 : 0.35),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                etiqueta,
                style: TextStyle(
                  color: texto,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!esUltimo) ...[
                const SizedBox(width: 5),
                Icon(Icons.arrow_forward_rounded, size: 15, color: texto),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón secundario de texto (saltar paso).
class _BotonTexto extends StatelessWidget {
  final String etiqueta;
  final bool esOscuro;
  final VoidCallback onTap;

  const _BotonTexto({
    required this.etiqueta,
    required this.esOscuro,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: ColoresApp.enSuperficieApagado(esOscuro),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        etiqueta,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}
