"""
============================================
GENERADOR FIRMADO DE CÓDIGOS - V2
============================================

Sistema donde:
- Python FIRMA códigos con HMAC-SHA256
- Flutter/Go solo VERIFICAN firmas (secret key hardcodeada una vez)
- NUNCA necesitan actualizarse

Formato: BASE64(DATOS).FIRMA
- DATOS: palabra.expiry.nonce (JSON encodeado + base64)
- FIRMA: HMAC-SHA256 de los datos (base64 URL-safe)

============================================
"""

import base64
import hashlib
import hmac
import json
import os
import random
import time
from datetime import datetime
from pathlib import Path

SCRIPTS_DIR = Path(__file__).parent

SECRET_KEY = b'Bitly_secret_key_v1'

PATRONES_VALIDOS = ['pablo', 'pabol', 'flox']
DIAS_EXPIRACION = 30

def generar_nonce():
    return os.urandom(16).hex()

def _firmar(mensaje):
    """Firma el mensaje con HMAC-SHA256"""
    h = hmac.new(SECRET_KEY, mensaje.encode(), hashlib.sha256)
    firma = base64.b64encode(h.digest()).decode()
    firma = firma.replace('+', '-').replace('/', '_').rstrip('=')
    return firma

def generar_codigo_firmado(palabra):
    """
    Genera código firmado.
    
    Formato: DATOS_BASE64.FIRMA
    
    Donde DATOS = base64(palabra.expiry.nonce)
    """
    palabra = palabra.lower()
    
    if palabra not in PATRONES_VALIDOS:
        raise ValueError(f"Palabra inválida: {palabra}")
    
    expiry = int(time.time()) + (DIAS_EXPIRACION * 86400)
    nonce = generar_nonce()
    
    datos = {
        'p': palabra,
        'e': expiry,
        'n': nonce,
    }
    
    datos_json = json.dumps(datos, separators=(',', ':'))
    datos_b64 = base64.urlsafe_b64encode(datos_json.encode()).decode().rstrip('=')
    
    mensaje = f"{datos_b64}.{palabra}"
    firma = _firmar(mensaje)
    
    return f"{datos_b64}.{firma}"

def validar_codigo_firmado(codigo):
    """
    Valida código firmado (para testing).
    """
    try:
        partes = codigo.split('.')
        if len(partes) != 2:
            return {'valido': False, 'error': 'Formato inválido'}
        
        datos_b64, firma_b64 = partes
        
        datos_json = base64.urlsafe_b64decode(datos_b64 + '==')
        datos = json.loads(datos_json.decode())
        
        palabra = datos.get('p')
        expiry = datos.get('e')
        
        if not palabra or not expiry:
            return {'valido': False, 'error': 'Datos incompletos'}
        
        ahora = int(time.time())
        if ahora > expiry:
            return {'valido': False, 'error': 'Expirado', 'expiracion': datetime.fromtimestamp(expiry)}
        
        if palabra not in PATRONES_VALIDOS:
            return {'valido': False, 'error': 'Palabra no autorizada'}
        
        mensaje = f"{datos_b64}.{palabra}"
        expected_firma = _firmar(mensaje)
        
        if firma_b64 != expected_firma:
            return {'valido': False, 'error': 'Firma inválida'}
        
        return {
            'valido': True,
            'palabra': palabra,
            'expiracion': datetime.fromtimestamp(expiry),
            'tipo': 'firmado'
        }
    except Exception as e:
        return {'valido': False, 'error': str(e)}

def menu():
    print("\n" + "="*60)
    print("  GENERADOR DE CÓDIGOS FIRMADOS V2")
    print("  Python firma -> Flutter/Go solo verifica")
    print("="*60)
    
    while True:
        print("\n[1] Generar código para 'pablo'")
        print("[2] Generar código para 'pabol'")
        print("[3] Generar código para 'flox'")
        print("[4] Generar lote de 10 códigos")
        print("[5] Validar código")
        print("[6] Salir")
        
        op = input("\nOpción: ").strip()
        
        if op in ['1', '2', '3']:
            palabra = ['pablo', 'pabol', 'flox'][int(op)-1]
            
            codigo = generar_codigo_firmado(palabra)
            
            print(f"\n  Código generado ({palabra}):")
            print(f"    {codigo}")
            
            datos_b64 = codigo.split('.')[0]
            datos = json.loads(base64.urlsafe_b64decode(datos_b64 + '==').decode())
            print(f"    Expira: {datetime.fromtimestamp(datos['e'])}")
            print(f"    Nonce: {datos['n'][:16]}...")
        
        elif op == '4':
            patron = input("  Patrón (pablo/pabol/flox): ").strip().lower()
            if patron not in PATRONES_VALIDOS:
                print("  [!] Patrón inválido")
                continue
            
            print(f"\n  Generando 10 códigos para {patron}:")
            for i in range(10):
                codigo = generar_codigo_firmado(patron)
                datos_b64 = codigo.split('.')[0]
                datos = json.loads(base64.urlsafe_b64decode(datos_b64 + '==').decode())
                print(f"    [{i+1:02d}] {codigo[:25]}... (exp: {datetime.fromtimestamp(datos['e']).strftime('%Y-%m-%d')})")
        
        elif op == '5':
            cod = input("  Código: ").strip()
            result = validar_codigo_firmado(cod)
            if result['valido']:
                print(f"\n  [OK] VÁLIDO: {result['palabra']}")
                print(f"       Expira: {result['expiracion']}")
            else:
                print(f"\n  [X] INVÁLIDO: {result['error']}")
        
        elif op == '6':
            print("\n  Chau!\n")
            break

if __name__ == '__main__':
    try:
        menu()
    except KeyboardInterrupt:
        print("\n")