#!/usr/bin/env python3
"""
Generador de claves Ed25519 para bitlyCodes.py
"""

import os
import base64
from pathlib import Path

try:
    from nacl.signing import SigningKey
    from nacl.encoding import RawEncoder
except ImportError:
    print("[!] PyNaCl no instalado. Instalá: pip install pynacl")
    exit(1)

# Directorio de claves
SCRIPTS_DIR = Path(__file__).parent
KEYS_DIR = SCRIPTS_DIR / 'keys'
PRIVATE_KEY_PATH = KEYS_DIR / 'private_key.pem'
PUBLIC_KEY_PATH = KEYS_DIR / 'public_key.pem'

# Crear directorio
KEYS_DIR.mkdir(exist_ok=True)

# Generar clave
print("="*60)
print("  GENERANDO CLAVES ED25519")
print("="*60)

signing_key = SigningKey.generate()
verify_key = signing_key.verify_key

# Claves en bytes
private_bytes = bytes(signing_key)
public_bytes = bytes(verify_key)

print(f"\n  Private Key (bytes): {private_bytes.hex()}")
print(f"  Public Key (bytes):  {public_bytes.hex()}")

# Guardar en formato PEM simple
private_b64 = base64.b64encode(private_bytes).decode()
public_b64 = base64.b64encode(public_bytes).decode()

private_pem = f"""-----BEGIN PRIVATE KEY-----
{private_b64}
-----END PRIVATE KEY-----
"""

public_pem = f"""-----BEGIN PUBLIC KEY-----
{public_b64}
-----END PUBLIC KEY-----
"""

# Guardar archivos
with open(PRIVATE_KEY_PATH, 'w') as f:
    f.write(private_pem)

with open(PUBLIC_KEY_PATH, 'w') as f:
    f.write(public_pem)

print(f"\n  Claves guardadas en:")
print(f"    Private: {PRIVATE_KEY_PATH}")
print(f"    Public:  {PUBLIC_KEY_PATH}")

# Generar archivo keys.dart para Flutter
dart_content = f'''/// ============================================
/// CLAVES PÚBLICAS PARA VALIDACIÓN DE CÓDIGOS
/// ============================================
///
/// Clave pública Ed25519 para verificar firmas generadas por bitlyCodes.py
///
/// Para regenerar las claves:
///   python scripts/generate_keys.py
///
/// Luego actualizar este archivo con la nueva clave pública.
/// ============================================

import 'dart:convert';

class CodeSigningKeys {{
  /// Clave pública en formato PEM
  static const String publicKeyPem = \'\'\'
-----BEGIN PUBLIC KEY-----
{public_b64}
-----END PUBLIC KEY-----
\'\'\';

  /// Clave pública en bytes crudos (32 bytes para Ed25519)
  static final List<int> publicKeyBytes = _extractPublicKeyFromPem(publicKeyPem);

  /// Extrae los bytes de la clave pública (32 bytes) desde un PEM Ed25519
  static List<int> _extractPublicKeyFromPem(String pem) {{
    final cleaned = pem
        .replaceAll(\'-----BEGIN PUBLIC KEY-----\', \'\')
        .replaceAll(\'-----END PUBLIC KEY-----\', \'\')
        .replaceAll(\'\\n\', \'\')
        .replaceAll(\' \', \'\')
        .trim();

    return base64Decode(cleaned);
  }}
}}
'''

keys_dart_path = SCRIPTS_DIR.parent / 'lib' / 'core' / 'shared' / 'security' / 'keys.dart'
with open(keys_dart_path, 'w', encoding='utf-8') as f:
    f.write(dart_content)

print(f"\n  Archivo keys.dart generado en:")
print(f"    {keys_dart_path}")

print("\n" + "="*60)
print("  ¡CLAVES GENERADAS EXITOSAMENTE!")
print("="*60)
print("\n  ⚠️  IMPORTANTE:")
print("  - NUNCA compartas private_key.pem")
print("  - public_key.pem puede estar en el repositorio")
print("  - Guardá private_key.pem en un lugar SEGURO")
print("="*60 + "\n")
