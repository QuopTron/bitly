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
        label: 'Espejos (opcional: ya vienen configurados)',
        hint: 'Servicios que convierten un ISRC en audio. Se prueban EN PARALELO '
            'y gana el más rápido (un espejo caído ya no retrasa al que sí '
            'tiene la canción). Ejemplo: https://dzr.tabs-vs-spaces.wtf\n'
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
      CampoProveedor(
        key: 'qobuz_keys_url',
        label: 'Origen de claves Qobuz (opcional: la app ya trae uno)',
        hint: 'URL (o varias separadas por coma) que publican app_id y '
            'app_secret de Qobuz. Se prueban EN PARALELO y gana la primera que '
            'responda. Si las claves rotan, la app las refresca sola: no tenés '
            'que volver a pegarlas. Si lo dejás vacío, se usa el origen que la '
            'app trae de fábrica; si pegás algo, lo tuyo manda.',
      ),
      CampoProveedor(
        key: 'qobuz_app_id',
        label: 'Qobuz app_id (opcional)',
        hint: 'Canal Qobuz firmado: con estas credenciales el rescate devuelve '
            'una URL de FLAC DIRECTA de Qobuz, así que la canción suena al '
            'instante (sin descargarla antes). Son las credenciales de la app '
            'web de Qobuz; si las dejas vacías, el canal queda apagado y se usan '
            'solo los espejos.',
      ),
      CampoProveedor(
        key: 'qobuz_app_secret',
        label: 'Qobuz app_secret (opcional)',
        hint: 'Se usa para firmar la petición (junto con app_id). Necesario para '
            'activar el canal Qobuz firmado.',
      ),
      CampoProveedor(
        key: 'qobuz_user_token',
        label: 'Qobuz token de usuario (opcional)',
        hint: 'Solo si tu cuenta de Qobuz lo necesita para servir FLAC. Va por '
            'cabecera, nunca dentro de la URL.',
      ),
    ],
    acciones: [
      AccionProveedor(
        action: 'probarCanal',
        label: 'Probar canal Qobuz',
        icon: Icons.science_outlined,
      ),
    ],
  ),
];
