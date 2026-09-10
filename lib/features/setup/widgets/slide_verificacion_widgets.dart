// ─────────────────────────────────────────────────────────────
// slide_verificacion_widgets.dart — PART de slide_verificacion.dart:
// sub-widgets del slide (icono, lista de proveedores con su estado,
// fila de proveedor y botón de acciones continuar/iniciar). El
// estado visual (pendiente/verificando/verificado/fallo) se traduce
// a iconos y colores aquí. Las funciones reciben el State del slide
// para acceder a sus campos privados.
// Se conecta con: slide_verificacion.dart (misma library) + shared.
// Parte del flujo: setup (paso 6: verificación de fuentes).
// ─────────────────────────────────────────────────────────────

part of 'slide_verificacion.dart';

Widget _icono(_SlideVerificacionState st, Color onBg) => Container(
  padding: EdgeInsets.all(st.widget.r.spacingS),
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: onBg.withValues(alpha: 0.04),
    border: Border.all(color: onBg.withValues(alpha: 0.08), width: 0.8),
  ),
  child: Icon(
    Icons.verified_user_outlined,
    size: st.widget.r.titleSize * 1.1,
    color: onBg.withValues(alpha: 0.55),
  ),
);

Widget _listaProveedores(_SlideVerificacionState st, Color onBg, Color glowColor) {
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: st.widget.r.spacingXL),
    child: ContenedorVidrio(
      borderRadius: 14,
      borderColor: glowColor.withValues(alpha: 0.15),
      bgColor: onBg.withValues(alpha: 0.02),
      padding: EdgeInsets.all(st.widget.r.spacingM),
      child: Column(
        children: [
          Text(
            st.widget.loc.setup.verificationDesc,
            style: TextStyle(
              fontSize: st.widget.r.footerSize,
              color: onBg.withValues(alpha: 0.65),
            ),
          ),
          SizedBox(height: st.widget.r.spacingM),
          ..._SlideVerificacionState._proveedores.map(
            (p) => _filaProveedor(st, p.$1, p.$2, onBg, glowColor),
          ),
        ],
      ),
    ),
  );
}

Widget _filaProveedor(
  _SlideVerificacionState st,
  String extId,
  String nombreMostrado,
  Color onBg,
  Color glowColor,
) {
  final estado = st._estados[extId] ?? _EstadoProveedor.pendiente;
  final icono = switch (estado) {
    _EstadoProveedor.pendiente => Icons.hourglass_empty,
    _EstadoProveedor.verificando => Icons.sync,
    _EstadoProveedor.verificado => Icons.check_circle,
    _EstadoProveedor.fallo => Icons.error_outline,
  };
  final color = switch (estado) {
    _EstadoProveedor.pendiente => onBg.withValues(alpha: 0.35),
    _EstadoProveedor.verificando => glowColor,
    _EstadoProveedor.verificado => glowColor,
    _EstadoProveedor.fallo => Colors.redAccent,
  };

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icono, size: st.widget.r.footerSize + 4, color: color),
        SizedBox(width: st.widget.r.spacingS),
        Expanded(
          child: Text(
            nombreMostrado,
            style: TextStyle(
              fontSize: st.widget.r.footerSize,
              color: estado == _EstadoProveedor.verificado
                  ? onBg.withValues(alpha: 0.8)
                  : onBg.withValues(alpha: 0.5),
            ),
          ),
        ),
        if (estado == _EstadoProveedor.verificando)
          SizedBox(
            width: st.widget.r.footerSize,
            height: st.widget.r.footerSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: glowColor,
            ),
          ),
      ],
    ),
  );
}

Widget _acciones(_SlideVerificacionState st, Color onBg, Color glowColor) {
  // La verificación corre en SEGUNDO PLANO y silenciosa (sin modals): el
  // primer toque la inicia, el segundo (o siguiente) continúa al home. Los
  // estados de cada proveedor se actualizan en vivo mientras tanto.
  final puedeContinuar = st._verificacionIniciada;
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: st.widget.r.spacingXL),
    child: BotonVidrio(
      label: puedeContinuar
          ? st.widget.loc.setup.continueText
          : st.widget.loc.setup.verificationStart,
      onPressed: () {
        if (!st._verificacionIniciada) {
          unawaited(_iniciarVerificacionSt(st));
        } else {
          st.context.read<SetupBloc>().add(const VerificacionCompletada());
        }
      },
      height: st.widget.r.continueButtonHeight,
      accent: glowColor,
    ),
  );
}