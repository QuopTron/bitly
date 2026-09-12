// ─────────────────────────────────────────────────────────────
// registro_proveedores_sesiones.dart — Proveedores cuya credencial se
// puede apilar en un POOL (TIDAL y Qobuz), separados del registro
// principal para mantener cada archivo dentro del límite de líneas.
//
// Por qué tienen pool: una credencial sola se muere (se revoca, se
// banea), y el usuario tenía que volver a pegarla. Con un pool:
//   - se pegan VARIAS (una por línea),
//   - opcionalmente se agregan URLs de fuentes que se descargan solas,
//   - el backend descarta las muertas y la extensión rota a la viva.
//
// Se conecta con: registro_proveedores.dart (spread en `proveedoresTodos`)
// → config_proveedor.dart → ServicioCredencialesProveedor →
// setExtensionSettings("tidal-web" / "qobuz-web").
// Parte del flujo: Ajustes → Credenciales → Proveedores.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import 'config_proveedor.dart';

/// Proveedores con pool de credenciales (tokens/cuentas apilables).
const List<ConfigProveedor> proveedoresSesiones = [
  ConfigProveedor(
    id: 'tidal-web',
    nombreMostrado: 'TIDAL',
    icon: Icons.water_drop,
    campos: [
      CampoProveedor(
        key: 'tidalAccessToken',
        label: 'Access Token (uno por línea, opcional)',
        hint: 'Con tu token, las descargas salen DIRECTO de Tidal y ya no se pide '
            'verificación de humano. Sácalo de tidal.com: DevTools → Application '
            '→ Local Storage → access_token.\n'
            'Podés pegar VARIOS (uno por línea): si uno se revoca, se rota sola al '
            'siguiente sin que vuelvas a pegar nada.',
        multiline: true,
      ),
      CampoProveedor(
        key: 'tidalPoolUrls',
        label: 'Fuentes del pool (una URL por línea, opcional)',
        hint: 'URLs públicas que publiquen tokens de Tidal. La app las descarga, '
            'se queda solo con los que siguen sirviendo (probados contra la API '
            'de Tidal) y descarta los muertos. Tu token de arriba tiene prioridad.',
        multiline: true,
      ),
      CampoProveedor(
        key: 'tidalCookie',
        label: 'Session Cookie (opcional)',
        hint: 'Cookie de sesión completa de Tidal. Solo hace falta si tu token '
            'por sí solo no autoriza la descarga.',
        multiline: true,
      ),
    ],
  ),
  ConfigProveedor(
    id: 'qobuz-web',
    nombreMostrado: 'Qobuz',
    icon: Icons.album,
    campos: [
      CampoProveedor(
        key: 'email',
        label: 'Correo electrónico (descarga directa)',
        hint: 'Con tu cuenta, las descargas salen DIRECTO de Qobuz y ya no se pide '
            'verificación de humano. Tu correo de Qobuz, ej: tu@email.com',
      ),
      CampoProveedor(
        key: 'password',
        label: 'Contraseña',
        hint: 'Contraseña de tu cuenta Qobuz. Se guarda solo en este dispositivo y '
            'se usa para pedir el token de descarga a Qobuz.',
      ),
      CampoProveedor(
        key: 'qobuzPool',
        label: 'Cuentas del pool (email:contraseña, una por línea)',
        hint: 'Cuentas extra de Qobuz. Si la de arriba falla, se rota sola a la '
            'siguiente sin que vuelvas a configurar nada. Formato: '
            'correo@dominio.com:contraseña',
        multiline: true,
      ),
      CampoProveedor(
        key: 'qobuzPoolUrls',
        label: 'Fuentes del pool (una URL por línea, opcional)',
        hint: 'URLs públicas que publiquen cuentas o tokens de Qobuz. La app las '
            'descarga y solo conserva las que pueden iniciar sesión de verdad.',
        multiline: true,
      ),
    ],
  ),
];
