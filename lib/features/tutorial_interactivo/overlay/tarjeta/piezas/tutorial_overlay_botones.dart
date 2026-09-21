// tutorial_overlay_botones.dart — PART de tutorial_overlay.dart: los botones del
// tutorial (saltar paso, atrás, siguiente / entendido y salir del tutorial).
//
// Se conecta con: tutorial_overlay_tarjeta (los coloca) y l10n (textos ES/EN).
// Parte del flujo: tutorial interactivo (acciones de la capa 2).
part of '../../tutorial_overlay.dart';

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
    // El botón mide por aparato: en la tele tiene que ser un blanco grande.
    final r = Responsive(context);
    final esp = EspecificacionesPlataforma.de(context);
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
            padding: EdgeInsets.all(r.spacingS),
            child: Icon(
              icono,
              size: esp.iconoBoton,
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
    // Botón principal del tutorial: alto, radio y texto del aparato (en la tele
    // es el que más se usa con el puntero).
    final r = Responsive(context);
    final esp = EspecificacionesPlataforma.de(context);
    final radius = BorderRadius.circular(esp.radioBoton);
    return Material(
      color: fondo,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        // Foco visible en la tarjeta: es el botón que avanza el tutorial.
        focusColor: _verdeTutorial.withValues(alpha: esUltimo ? 0.5 : 0.35),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: r.spacingL,
            vertical: r.spacingM,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                etiqueta,
                style: TextStyle(
                  color: texto,
                  fontSize: esp.textoBoton,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!esUltimo) ...[
                SizedBox(width: r.spacingS),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: esp.iconoBoton,
                  color: texto,
                ),
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
    // El texto secundario también crece con el aparato (en la tele un 12.5 no
    // se lee): `sobre` deja el valor de celular como piso.
    final r = Responsive(context);
    final esp = EspecificacionesPlataforma.de(context);
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: ColoresApp.enSuperficieApagado(esOscuro),
        padding: EdgeInsets.symmetric(
          horizontal: r.spacingM,
          vertical: r.spacingS,
        ),
        minimumSize: Size(0, esp.altoBoton),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        etiqueta,
        style: TextStyle(
          fontSize: r.sobre(12.5, 18),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
