// ─────────────────────────────────────────────────────────────
// pagina_busqueda_enlaces.dart — PART de pagina_busqueda.dart:
// envío explícito desde el campo (Enter/acción del teclado) y
// resolución de enlaces de música pegados o compartidos — Go elige
// la extensión según su manifest, se encola el ítem y suena de
// inmediato; si no se puede resolver, se avisa al usuario.
// Se conecta con: pagina_busqueda.dart (misma library) + servicio de
// enlaces + cubit de cola + l10n.
// Parte del flujo: búsqueda (enlaces pegados y compartidos).
// ─────────────────────────────────────────────────────────────

part of 'pagina_busqueda.dart';

/// Envío explícito (Enter / acción del teclado): un enlace de música se
/// resuelve y se reproduce; cualquier otro texto se busca normalmente.
Future<void> _enviarBusqueda(_PaginaBusquedaState st, String texto) async {
  final q = texto.trim();
  if (q.isEmpty) return;
  st._debounce?.cancel();
  if (ServicioEnlaces.enlaceEnTexto(q) != null) {
    await _resolverEnlace(st, q);
    return;
  }
  _despacharBusqueda(st, q);
}

/// Resuelve un enlace pegado/compartido: Go elige la extensión según su
/// manifest y devuelve el ítem, que se encola y suena de inmediato.
///
/// Nunca busca la URL como texto: buscar "https://open.spotify.com/track/..."
/// devolvía resultados que no tenían nada que ver con la canción del enlace.
/// Si la fuente no puede resolverlo, se avisa al usuario.
Future<void> _resolverEnlace(_PaginaBusquedaState st, String texto) async {
  final enlace = ServicioEnlaces.enlaceEnTexto(texto);
  if (enlace == null) return;
  if (st.mounted) st._aplicar(() => st._buscando = true);
  final resuelto = await ServicioEnlaces.instance.resolver(enlace);
  if (!st.mounted) return;
  st._aplicar(() => st._buscando = false);
  if (resuelto == null) {
    st.context.read<BlocBusqueda>().add(const LimpiarBusqueda());
    _mostrarAviso(st, AppLocalizations.of(st.context).setup.linkResolveFailed);
    return;
  }
  sl<CubitCola>().reproducirConContexto(resuelto.paraReproducir, resuelto.item);
  _limpiarBusqueda(st);
}

/// Aviso breve sin bloquear la vista (el enlace no se pudo resolver).
void _mostrarAviso(_PaginaBusquedaState st, String mensaje) {
  ScaffoldMessenger.maybeOf(st.context)?.showSnackBar(
    SnackBar(content: Text(mensaje), duration: const Duration(seconds: 5)),
  );
}
