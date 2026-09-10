// ─────────────────────────────────────────────────────────────
// slide_notificaciones_widgets.dart — PART de
// slide_notificaciones.dart: sub-widgets del slide (icono, tarjeta
// con el estado del permiso y fila de permiso con iconos de
// concedido/denegado, más las acciones continuar/omitir). Las
// funciones reciben el State del slide para acceder a sus campos.
// Se conecta con: slide_notificaciones.dart (misma library) +
// shared (vidrio, botón) + permission_handler.
// Parte del flujo: setup (paso 9: notificaciones).
// ─────────────────────────────────────────────────────────────

part of 'slide_notificaciones.dart';

Widget _icono(_SlideNotificacionesState st, Color onBg) => Container(
  padding: EdgeInsets.all(st.widget.r.spacingS),
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: onBg.withValues(alpha: 0.04),
    border: Border.all(color: onBg.withValues(alpha: 0.08), width: 0.8),
  ),
  child: Icon(
    Icons.notifications_outlined,
    size: st.widget.r.titleSize * 1.1,
    color: onBg.withValues(alpha: 0.55),
  ),
);

Widget _tarjetasPermiso(
  _SlideNotificacionesState st,
  Color onBg,
  Color glowColor,
) {
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: st.widget.r.spacingXL),
    child: ContenedorVidrio(
      borderRadius: 14,
      borderColor: glowColor.withValues(alpha: 0.15),
      bgColor: onBg.withValues(alpha: 0.02),
      padding: EdgeInsets.all(st.widget.r.spacingM),
      child: _filaPermiso(
        st,
        Icons.notifications_active,
        st.widget.loc.setup.notificationDesc,
        st._notificacionHecha,
        st._notificacionConcedida,
        glowColor,
        onBg,
      ),
    ),
  );
}

Widget _filaPermiso(
  _SlideNotificacionesState st,
  IconData icon,
  String desc,
  bool hecha,
  bool concedida,
  Color glowColor,
  Color onBg,
) {
  return Row(
    children: [
      Icon(
        icon,
        size: st.widget.r.subtitleSize + 2,
        color: concedida ? glowColor : onBg.withValues(alpha: 0.4),
      ),
      SizedBox(width: st.widget.r.spacingS),
      Expanded(
        child: Text(
          desc,
          style: TextStyle(
            fontSize: st.widget.r.footerSize,
            color: hecha && !concedida
                ? Colors.redAccent.withValues(alpha: 0.7)
                : onBg.withValues(alpha: 0.65),
          ),
        ),
      ),
      if (hecha)
        Icon(
          concedida ? Icons.check_circle : Icons.cancel,
          size: st.widget.r.footerSize + 2,
          color: concedida
              ? glowColor
              : Colors.redAccent.withValues(alpha: 0.6),
        ),
    ],
  );
}

Widget _acciones(
  _SlideNotificacionesState st,
  Color onBg,
  Color glowColor,
  bool guardando,
) {
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: st.widget.r.spacingXL),
    child: Column(
      children: [
        BotonVidrio(
          label: st._todoHecho
              ? st.widget.loc.setup.continueText
              : st.widget.loc.setup.notificationActivate,
          onPressed: guardando
              ? null
              : () async {
                  if (!st._todoHecho) await st._solicitarTodo();
                  if (st.mounted) st._continuar();
                },
          isLoading: st._solicitando || guardando,
          height: st.widget.r.continueButtonHeight,
          accent: glowColor,
        ),
        if (!st._todoHecho) ...[
          SizedBox(height: st.widget.r.spacingM),
          BotonVidrio(
            label: st.widget.loc.setup.notificationSkip,
            onPressed: guardando ? null : st._continuar,
            height: st.widget.r.continueButtonHeight,
            accent: glowColor,
          ),
        ],
      ],
    ),
  );
}