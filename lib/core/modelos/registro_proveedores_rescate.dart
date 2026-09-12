// ─────────────────────────────────────────────────────────────
// registro_proveedores_rescate.dart — Configuración del proveedor
// NATIVO de rescate de audio (flac-rescue), separada del registro
// principal para mantener cada archivo dentro del límite de líneas.
//
// Qué es: un proveedor sin catálogo propio que convierte un ISRC en
// la URL de audio (FLAC o MP3) consultando una lista de espejos
// públicos configurables. Es el "último recurso exacto" cuando la
// fuente original no puede entregar audio.
//
// Por qué los espejos son configurables: todos los servicios públicos
// gratuitos dependen de cuentas ajenas que se banean (DAB, squid.wtf).
// Teniéndolos en Ajustes, cuando uno cae el usuario pega otro y todo
// sigue funcionando SIN actualizar la app.
//
// Se conecta con: registro_proveedores.dart (spread en `proveedoresTodos`)
// → config_proveedor.dart → ServicioCredencialesProveedor →
// setExtensionSettings("flac-rescue").
// Parte del flujo: Ajustes → Credenciales → Rescate de audio.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import 'config_proveedor.dart';

/// Proveedores de rescate de audio (nativos, no extensiones JS).
const List<ConfigProveedor> proveedoresRescate = [
  ConfigProveedor(
    id: 'flac-rescue',
    nombreMostrado: 'Rescate de audio (FLAC/MP3)',
    icon: Icons.health_and_safety,
    campos: [
      CampoProveedor(
        key: 'mirrors',
        label: 'Espejos (uno por línea o separados por coma)',
        hint: 'Servicios que convierten un ISRC en audio. Se prueban en orden y '
            'se usa el primero que responda. Ejemplo: '
            'https://dzr.tabs-vs-spaces.wtf\n'
            'Si uno deja de funcionar, pega otro aquí: no hace falta actualizar '
            'la app.',
        multiline: true,
      ),
      CampoProveedor(
        key: 'format',
        label: 'Formato preferido',
        hint: 'FLAC (mejor calidad), MP3_320 o MP3_128. Si el espejo ya no tiene '
            'el formato pedido, se baja automáticamente al siguiente.',
      ),
      CampoProveedor(
        key: 'origin',
        label: 'Origen permitido (opcional)',
        hint: 'Algunos espejos solo responden si la petición viene de su propia '
            'web. Déjalo vacío salvo que un espejo pida otro origen.',
      ),
    ],
  ),
];
