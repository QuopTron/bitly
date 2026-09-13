// ─────────────────────────────────────────────────────────────
// slide_google_tarjeta.dart — PART de slide_google.dart: tarjeta
// de información del slide de Google con las 4 razones para
// conectar (streams sin 403, solo música, privado en el
// dispositivo, se puede cerrar). Recibe el State del slide para
// usar su helper _t de ES/EN.
// Se conecta con: slide_google.dart (misma library) + shared.
// Parte del flujo: setup (paso 4: conexión con Google).
// ─────────────────────────────────────────────────────────────

part of 'slide_google.dart';

Widget _tarjetaInfo(_SlideGoogleState st, Color onBg, Color glowColor) {
  final filas = [
    (
      Icons.bolt,
      st._t('Streams más rápidos y sin errores 403', 'Faster streams and no 403 errors'),
      st._t(
        'Con sesión, YouTube trata tu app como cuenta autenticada y deja de '
            'bloquear los streams anónimos.',
        'Signed-in playback avoids the anonymous rate limits that make '
            'streams slow or fail.',
      ),
    ),
    (
      Icons.music_note_outlined,
      st._t('Solo se usa para música', 'Used only for music'),
      st._t(
        'Tu cuenta se usa únicamente para resolver y reproducir canciones.',
        'Your account is only used to resolve and play songs.',
      ),
    ),
    (
      Icons.lock_outline,
      st._t('Privado y en tu dispositivo', 'Private, on your device'),
      st._t(
        'Los tokens se guardan solo aquí. Nada sale de tu teléfono excepto '
            'a los servidores oficiales de Google.',
        "Tokens are stored only on this device. Nothing leaves your phone "
            "except to Google's official servers.",
      ),
    ),
    (
      Icons.logout,
      st._t('Puedes cerrarla cuando quieras', 'You can sign out anytime'),
      st._t(
        'Cierra la sesión desde Ajustes y se eliminan los tokens.',
        'Sign out from Settings and the tokens are removed.',
      ),
    ),
  ];

  return ContenedorVidrio(
    borderRadius: 14,
    borderColor: onBg.withValues(alpha: 0.08),
    bgColor: onBg.withValues(alpha: 0.03),
    margin: EdgeInsets.symmetric(horizontal: st.widget.r.spacingL),
    padding: EdgeInsets.all(st.widget.r.spacingM),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final fila in filas) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                fila.$1,
                size: st.widget.r.subtitleSize + 2,
                color: glowColor,
              ),
              SizedBox(width: st.widget.r.spacingS),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fila.$2,
                      style: TextStyle(
                        fontSize: st.widget.r.footerSize + 2,
                        fontWeight: FontWeight.w600,
                        color: onBg,
                      ),
                    ),
                    Text(
                      fila.$3,
                      style: TextStyle(
                        fontSize: st.widget.r.footerSize,
                        color: onBg.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (fila != filas.last) SizedBox(height: st.widget.r.spacingM),
        ],
      ],
    ),
  );
}