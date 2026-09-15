// ─────────────────────────────────────────────────────────────
// settings_sheet_soulseek_form_build.dart — PART de
// settings_sheet_new.dart: el `build` del formulario de Soulseek —
// campo de nombre (con propuesta de la app), textos de ayuda, botón
// "Siguiente"/"Reconectar" con spinner y bloque para revelar la
// contraseña guardada.
// Se conecta con: settings_sheet_new.dart (misma library).
// Parte del flujo: Ajustes → Más (formulario Soulseek).
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

Widget _construirFormularioSoulseek(BuildContext context, TextEditingController nombreCtrl, bool cargando, bool conectada, bool propuestaDeLaApp, bool revelada, String password, String? mensaje, Color glow, Color onBg, Responsive r, VoidCallback onSiguiente, VoidCallback onToggleRevelada) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: nombreCtrl,
            enabled: !cargando,
            // Abre el teclado solo si no hay un nombre guardado: si ya lo hay,
            // el gesto útil es el botón.
            autofocus: nombreCtrl.text.isEmpty,
            maxLength: 30,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => cargando ? null : onSiguiente(),
            decoration: InputDecoration(
              labelText: 'Tu nombre en Soulseek',
              hintText: 'p. ej. pablo_bz',
              isDense: true,
              counterText: '',
              prefixIcon: Icon(
                Icons.alternate_email_rounded,
                size: 18,
                color: onBg.withValues(alpha: 0.4),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            style: TextStyle(color: onBg, fontSize: r.subtitleSize - 1),
          ),
          if (propuestaDeLaApp && !conectada) ...[
            SizedBox(height: r.spacingS),
            Text(
              'Es el nombre de tu cuenta de la app. Si no te sirve, '
              'cambiá lo que quieras antes de continuar.',
              style: TextStyle(
                fontSize: r.footerSize - 1,
                color: glow.withValues(alpha: 0.8),
                height: 1.3,
              ),
            ),
          ],
          SizedBox(height: r.spacingS),
          Text(
            'Al tocar Siguiente se crea tu cuenta con ese nombre. '
            'La contraseña la genera la app.',
            style: TextStyle(
              fontSize: r.footerSize - 1,
              color: onBg.withValues(alpha: 0.45),
              height: 1.3,
            ),
          ),
          SizedBox(height: r.spacingM),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: cargando ? null : onSiguiente,
              style: FilledButton.styleFrom(
                backgroundColor: glow,
                minimumSize: Size.fromHeight(r.continueButtonHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: cargando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      conectada ? 'Reconectar' : 'Siguiente',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
          if (mensaje != null) ...[
            SizedBox(height: r.spacingS),
            Text(
              mensaje,
              style: TextStyle(
                fontSize: r.footerSize - 1,
                color: Colors.red.shade600,
                height: 1.3,
              ),
            ),
          ],
          if (password.isNotEmpty) ...[
            SizedBox(height: r.spacingS),
            Divider(color: onBg.withValues(alpha: 0.08)),
            _SoulseekPasswordRow(
              revelada: revelada,
              password: password,
              glow: glow,
              onBg: onBg,
              r: r,
              onToggle: onToggleRevelada,
            ),
          ],
        ],
      ),
    );
  
}
