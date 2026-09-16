// ─────────────────────────────────────────────────────────────
// slide_carpeta_almacenamiento_ruta.dart — PART de
// slide_carpeta_almacenamiento.dart: lógica de selección de ruta —
// abre el picker de carpeta, vuelve a la por defecto y guarda la
// ruta elegida (cache + sync a Go) avanzando al siguiente paso.
// Las funciones reciben el State del slide para acceder a sus
// campos privados y a su wrapper _aplicar (setState).
// Se conecta con: slide_carpeta_almacenamiento.dart (misma library)
// + cache_ajustes + backend_go (syncDownloadDir) + setup_bloc.
// Parte del flujo: setup (paso 8: carpeta de descargas).
// ─────────────────────────────────────────────────────────────

part of 'slide_carpeta_almacenamiento.dart';

/// Pide el permiso de almacenamiento en Android (y lee-audio en 13+).
/// No bloquea el flujo: si el usuario lo niega, la carpeta por defecto
/// de la app (documentos privados) sigue funcionando sin permisos.
Future<void> _solicitarPermisoAlmacenamientoSt(
  _SlideCarpetaAlmacenamientoState st,
) async {
  if (esEscritorio()) return;
  try {
    final estado = await Permission.storage.status;
    if (!estado.isGranted && !estado.isLimited) {
      await Permission.storage.request();
    }
    // Android 13+ separa el permiso en READ_MEDIA_AUDIO.
    final audio = await Permission.audio.status;
    if (!audio.isGranted && !audio.isLimited) {
      await Permission.audio.request();
    }
  } catch (e) {
    debugPrint("[StoragePermission] $e");
  }
}

/// Abre el picker de carpeta y aplica la selección al State.
Future<void> _elegirCarpetaSt(_SlideCarpetaAlmacenamientoState st) async {
  st._aplicar(() => st._eligiendo = true);
  // Asegura el permiso antes de abrir el explorador de archivos.
  await _solicitarPermisoAlmacenamientoSt(st);
  try {
    final result = await FilePicker.getDirectoryPath(
      dialogTitle: st.widget.loc.setup.storageTitle,
    );
    if (result != null && st.mounted) {
      st._aplicar(() {
        st._rutaSeleccionada = result;
        st._usandoPorDefecto = false;
      });
    }
  } catch (e) {
    if (st.mounted) {
      ScaffoldMessenger.of(st.context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al seleccionar carpeta: $e',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red.withValues(alpha: 0.8),
        ),
      );
    }
  } finally {
    if (st.mounted) st._aplicar(() => st._eligiendo = false);
  }
}

/// Vuelve a la carpeta por defecto y la aplica al State.
Future<void> _usarPorDefectoSt(_SlideCarpetaAlmacenamientoState st) async {
  st._aplicar(() => st._eligiendo = true);
  final ruta = await rutaCarpetaPorDefecto();
  if (ruta != null && st.mounted) {
    st._aplicar(() {
      st._rutaSeleccionada = ruta;
      st._usandoPorDefecto = true;
    });
  }
  if (st.mounted) st._aplicar(() => st._eligiendo = false);
}

/// Guarda la ruta (cache + sync a Go) y avanza al siguiente paso.
Future<void> _finalizarSetupSt(_SlideCarpetaAlmacenamientoState st) async {
  if (st._rutaSeleccionada == null) return;
  try {
    await di.sl<CacheAjustes>().guardarRutaDescargas(st._rutaSeleccionada!);
    // Sincroniza la ruta con la config en memoria de Go.
    try {
      await di.sl<BackendService>().syncDownloadDir(st._rutaSeleccionada!);
    } catch (e) {
      debugPrint("[Feature] $e");
    }
    // Si el usuario eligió una carpeta que ya tiene descargas (p.ej. reinstaló
    // la app), sus archivos se re-vinculan para que la biblioteca los vea en la
    // ubicación nueva en vez de darlos por perdidos.
    try {
      final movidos = await di.sl<CacheDescargas>().reubicarArchivosEnCarpeta(
        st._rutaSeleccionada!,
      );
      if (movidos > 0) await di.sl<CacheBiblioteca>().invalidarTodo();
    } catch (e) {
      debugPrint("[Feature] relink: $e");
    }
    if (st.mounted) {
      st.context.read<SetupBloc>().add(const SiguientePaso());
    }
  } catch (e) {
    debugPrint("[Feature] $e");
  }
}
