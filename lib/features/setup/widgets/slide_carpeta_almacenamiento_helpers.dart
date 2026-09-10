// ─────────────────────────────────────────────────────────────
// slide_carpeta_almacenamiento_helpers.dart — PART de
// slide_carpeta_almacenamiento.dart: sub-widgets del slide
// (encabezado con icono y título, tarjetas de opción de carpeta y
// botón continuar) más el helper de la ruta por defecto
// (Documentos/Bitly, creándola si no existe). Las funciones reciben
// el State del slide para acceder a sus campos privados.
// Se conecta con: slide_carpeta_almacenamiento.dart (misma library)
// + shared (vidrio, botón, tarjetas) + path_provider.
// Parte del flujo: setup (paso 8: carpeta de descargas).
// ─────────────────────────────────────────────────────────────

part of 'slide_carpeta_almacenamiento.dart';

/// Devuelve la ruta por defecto (Documentos/Bitly) creándola si falta.
Future<String?> rutaCarpetaPorDefecto() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final bitlyDir = Directory('${dir.path}/Bitly');
    if (!bitlyDir.existsSync()) bitlyDir.createSync(recursive: true);
    return bitlyDir.path;
  } catch (_) {
    return null;
  }
}

Widget _encabezado(
  _SlideCarpetaAlmacenamientoState st,
  Color onBg,
  AppLocalizations loc,
  Responsive r,
) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: EdgeInsets.all(r.spacingS),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onBg.withValues(alpha: 0.04),
          border: Border.all(color: onBg.withValues(alpha: 0.08), width: 0.8),
        ),
        child: Icon(
          Icons.folder_outlined,
          size: r.titleSize * 1.1,
          color: onBg.withValues(alpha: 0.55),
        ),
      ),
      SizedBox(height: r.spacingS),
      Text(
        loc.setup.storageTitle,
        style: TextStyle(
          fontSize: r.titleSize,
          fontWeight: FontWeight.bold,
          color: onBg,
          letterSpacing: 1,
        ),
      ),
      SizedBox(height: 2),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
        child: Text(
          loc.setup.storageDesc,
          style: TextStyle(
            fontSize: r.footerSize,
            color: onBg.withValues(alpha: 0.5),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    ],
  );
}

Widget _tarjetasOpcion(
  _SlideCarpetaAlmacenamientoState st,
  Color onBg,
  Color glowColor,
  AppLocalizations loc,
  Responsive r,
) {
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: r.spacingL),
    child: Column(
      children: [
        TarjetaOpcionCarpeta(
          icon: Icons.create_new_folder,
          title: loc.setup.storageChoose,
          subtitle: loc.setup.storageChooseDesc,
          selected: !st._usandoPorDefecto && st._rutaSeleccionada != null,
          onTap: () => _elegirCarpetaSt(st),
          disabled: st._eligiendo,
          onBg: onBg,
          glowColor: glowColor,
        ),
        SizedBox(height: r.spacingS),
        TarjetaOpcionCarpeta(
          icon: Icons.home_outlined,
          title: loc.setup.storageDefault,
          subtitle: loc.setup.storageDefaultDesc,
          selected: st._usandoPorDefecto,
          onTap: () => _usarPorDefectoSt(st),
          disabled: st._eligiendo,
          onBg: onBg,
          glowColor: glowColor,
        ),
      ],
    ),
  );
}

Widget _botonContinuar(
  _SlideCarpetaAlmacenamientoState st,
  Color onBg,
  Color glowColor,
  bool guardando,
  AppLocalizations loc,
  Responsive r,
) {
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
    child: SizedBox(
      width: double.infinity,
      height: r.continueButtonHeight,
      child: BotonVidrio(
        label: loc.setup.continueText,
        onPressed: st._rutaSeleccionada != null && !guardando
            ? () => _finalizarSetupSt(st)
            : null,
        isLoading: guardando,
        height: r.continueButtonHeight,
        accent: glowColor,
      ),
    ),
  );
}