// ─────────────────────────────────────────────────────────────
// config_proveedor.dart — Describe cada proveedor cuyas credenciales
// guardadas hay que empujar a su extensión de Go al arrancar.
//
// Qué guarda y qué NO: solo el `id` de la extensión, un `nombreMostrado`
// para los logs y la lista de `claves` de ajuste (se leen de la caché con
// el prefijo `<id>_<clave>`). El copy visual (labels, hints, botones)
// vivía acá cuando existía la pantalla de Credenciales; esa pantalla ya no
// está, así que ese texto se eliminó: era copy muerto que nadie renderiza.
//
// Se conecta con: registro_proveedores.dart (lista `todos`) y
// ServicioCredencialesProveedor (empuje de credenciales a Go).
// Parte del flujo: arranque de la app.
// ─────────────────────────────────────────────────────────────

import 'registro_proveedores.dart';

/// Proveedor con credenciales que la app guarda y reenvía a Go.
class ConfigProveedor {
  final String id; // ID de extensión, p.ej. 'tidal-web'
  final String nombreMostrado; // Solo para logs; igual en ambos idiomas.

  /// Claves de ajuste que se envían a la extensión: cada una se lee de la
  /// caché como `<id>_<clave>`. Incluye tanto credenciales que el usuario
  /// pegaba en Ajustes como tokens OAuth que genera la propia app (esos no
  /// tienen campo visible, pero deben sobrevivir a los reinicios).
  final List<String> claves;

  const ConfigProveedor({
    required this.id,
    required this.nombreMostrado,
    required this.claves,
  });

  /// Todos los proveedores con credenciales (definidos en
  /// [registro_proveedores.dart] para mantener este archivo compacto).
  static const List<ConfigProveedor> todos = proveedoresTodos;
}
