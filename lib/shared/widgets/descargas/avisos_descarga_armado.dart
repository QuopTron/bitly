// ─────────────────────────────────────────────────────────────
// avisos_descarga_armado.dart — PART de avisos_descarga.dart:
// decide QUÉ aviso corresponde al estado del cubit y arma sus
// acciones.
//
// Prioridad: carpeta (bloquea toda escritura) → fallo definitivo de
// una canción → gate del plan free → decrypt fallido → reinicio del
// backend con descargas en curso.
//
// Los textos salen de l10n y los DATOS del estado (título + motivo),
// nunca de frases ya escritas en el cubit: así el aviso sigue el
// idioma de la app.
//
// Se conecta con: avisos_descarga.dart (misma library) +
// tarjeta_aviso_descarga + servicio carpeta_descargas.
// Parte del flujo: descargas → avisos al usuario.
// ─────────────────────────────────────────────────────────────

part of 'avisos_descarga.dart';

/// Arma la tarjeta que corresponde al estado, o null si no hay nada que
/// avisar.
Widget? _armarAviso(_AvisosDescargaState st) {
  final loc = AppLocalizations.of(st.context);
  final d = loc.descargas;

  if (st._estado.carpetaPerdida) {
    return TarjetaAvisoDescarga(
      icono: Icons.folder_off_outlined,
      acento: ColoresApp.error,
      titulo: d.carpetaTitulo,
      mensaje: d.carpetaMensaje,
      onCerrar: st._cubit.confirmarCarpetaRestaurada,
      acciones: [_accionCarpeta(st, d)],
    );
  }

  final fallo = st._estado.falloDescarga;
  if (fallo != null) return _tarjetaFallo(st, d, fallo);

  if (st._estado.gateDescargaBloqueado != null) {
    return TarjetaAvisoDescarga(
      icono: Icons.lock_clock_outlined,
      acento: ColoresApp.advertencia,
      titulo: d.gateTitulo,
      mensaje: loc.setup.trialExpired,
      onCerrar: st._cubit.confirmarBloqueoDescarga,
    );
  }

  if (st._estado.errorDesencriptado != null) {
    return TarjetaAvisoDescarga(
      icono: Icons.lock_open_outlined,
      acento: ColoresApp.error,
      titulo: d.decryptTitulo,
      mensaje: loc.setup.downloadDecryptFailed,
      onCerrar: st._cubit.confirmarErrorDesencriptado,
    );
  }

  if (st._estado.backendReiniciado) {
    return TarjetaAvisoDescarga(
      icono: Icons.restart_alt,
      acento: ColoresApp.advertencia,
      titulo: d.reinicioTitulo,
      mensaje: d.reinicioMensaje,
      onCerrar: st._cubit.confirmarReinicio,
      acciones: [
        AccionAvisoDescarga(
          d.reintentar,
          destacada: true,
          onTap: () {
            st._cubit.reintentarTodosInterrumpidos();
            st._cubit.confirmarReinicio();
            st._cerrar();
          },
        ),
      ],
    );
  }
  return null;
}

/// Tarjeta del fallo definitivo de una canción.
Widget _tarjetaFallo(
  _AvisosDescargaState st,
  StringsDescargas d,
  FalloDescarga fallo,
) {
  final reintentable = !fallo.necesitaUsuario;
  return TarjetaAvisoDescarga(
    icono: Icons.error_outline,
    acento: reintentable ? ColoresApp.advertencia : ColoresApp.error,
    titulo: d.falloTitulo.replaceAll('{titulo}', fallo.titulo),
    mensaje: reintentable ? d.falloAyuda : d.falloAyudaUsuario,
    motivo: d.falloMotivo.replaceAll('{motivo}', fallo.motivo),
    onCerrar: st._cubit.confirmarFalloDescarga,
    acciones: reintentable ? [_accionReintentar(st, d, fallo.baseId)] : const [],
  );
}

/// Reintentar el fallo: vuelve a encolar ESA canción con los ajustes
/// actuales. Si el cubit no conserva sus datos (p. ej. la app se reinició),
/// igual se cierra el aviso y el usuario puede pedir la descarga otra vez.
AccionAvisoDescarga _accionReintentar(
  _AvisosDescargaState st,
  StringsDescargas d,
  String baseId,
) => AccionAvisoDescarga(
  d.reintentar,
  destacada: true,
  onTap: () async {
    if (baseId.isNotEmpty) await st._cubit.reintentarTrackFallido(baseId);
    st._cubit.confirmarFalloDescarga();
    st._cerrar();
  },
);

/// Elegir carpeta: abre el explorador (el mismo camino que Ajustes) y, si el
/// usuario elige una carpeta escribible, el aviso deja de aplicar.
AccionAvisoDescarga _accionCarpeta(
  _AvisosDescargaState st,
  StringsDescargas d,
) => AccionAvisoDescarga(
  d.carpetaAccion,
  destacada: true,
  onTap: () async {
    final loc = AppLocalizations.of(st.context);
    final ruta = await elegirCarpetaDescargas(
      tituloDialogo: loc.setup.storageTitle,
    );
    if (!st.mounted) return;
    if (ruta != null) {
      st._cubit.confirmarCarpetaRestaurada();
      st._cerrar();
    }
  },
);
