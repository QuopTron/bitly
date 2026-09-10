// ─────────────────────────────────────────────────────────────
// config_proveedor.dart — Describe cada proveedor que acepta
// credenciales del usuario (TIDAL, Apple, YouTube, Qobuz, Spotify...)
// con sus campos y acciones de botón (SpotiFLAC "button" settings).
// Se conecta con: backend_go (extensiones — credenciales y acciones JS).
// Parte del flujo: Ajustes → Credenciales → Proveedores.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import 'registro_proveedores.dart';

/// Un campo de credencial/texto para un proveedor.
class CampoProveedor {
  final String key;
  final String label;
  final String hint;
  final bool multiline;

  const CampoProveedor({
    required this.key,
    required this.label,
    required this.hint,
    this.multiline = false,
  });
}

/// Acción de efecto secundario (botón "SpotiFLAC") mostrada bajo los campos
/// de un proveedor. Al tocarla invoca el método JS llamado [action] en la
/// extensión (p.ej. 'clearCachedTokens').
class AccionProveedor {
  final String action; // Nombre del export JS, p.ej. 'clearCachedTokens'
  final String label;
  final IconData icon;

  /// Mensaje de confirmación opcional antes de ejecutar (null = sin confirmar).
  final String? mensajeConfirmacion;

  const AccionProveedor({
    required this.action,
    required this.label,
    this.icon = Icons.tune,
    this.mensajeConfirmacion,
  });
}

/// Describe un proveedor que acepta credenciales ingresadas por el usuario.
class ConfigProveedor {
  final String id; // ID de extensión, p.ej. 'tidal-web'
  final String nombreMostrado;
  final IconData icon;
  final List<CampoProveedor> campos;
  final List<AccionProveedor> acciones;

  /// Claves de ajuste adicionales (más allá de [campos]) que se envían a la
  /// extensión al arrancar — p.ej. tokens OAuth que la app guarda pero no
  /// tienen campo visible. Se almacenan con el prefijo `<id>_<key>`.
  final List<String> clavesAjusteExtra;

  const ConfigProveedor({
    required this.id,
    required this.nombreMostrado,
    required this.icon,
    required this.campos,
    this.acciones = const [],
    this.clavesAjusteExtra = const [],
  });

  /// Todos los proveedores que requieren credenciales (definidos en
  /// [registro_proveedores.dart] para mantener este archivo compacto).
  static const List<ConfigProveedor> todos = proveedoresTodos;

  /// Si este proveedor tiene campos de credencial que el usuario puede llenar.
  bool get tieneCamposCredencial => campos.isNotEmpty;
}