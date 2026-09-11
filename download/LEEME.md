# Botón de descarga para iPhone — qué decir y por qué

## El problema

En Android/Windows/macOS hay **un solo botón** = descarga directa y listo.

En iPhone **NO se puede**: Apple no permite instalar apps fuera de la App Store sin una
de estas dos vías:

| Vía | Qué necesita el usuario | Resultado |
|---|---|---|
| **TrollStore** | Nada (si su iOS es compatible) | Permanente, sin PC |
| **AltStore** | PC/Mac una vez | 7 días, renovación automática |

Por eso el botón de iPhone **no puede descargar directo**. Tiene que **explicar** y
ofrecer las dos opciones.

---

## Cómo debe funcionar el botón

### Paso 1 — Botón principal (en la home)

Texto recomendado:

```
📱 Descargar para iPhone
```

Al tocarlo **NO descarga nada** — hace scroll o abre una sección que dice:

> **Elige cómo instalar Bitly**
> Las dos formas son gratis y no necesitan la App Store.

### Paso 2 — Las dos tarjetas

**Tarjeta 1 — TrollStore (recomendado):**

- Título: `TrollStore` + etiqueta verde **Recomendado**
- Descripción:
  > Instalación **permanente y directa** — sin PC, sin expiración, sin renovaciones.
- Botón: `Instalar con TrollStore`
- Nota al pie (importante, evita frustración):
  > Requiere **iOS 14.0 – 16.6.1, 16.7 RC o 17.0**. En 16.7.x o 17.0.1+ usa AltStore.

**Tarjeta 2 — AltStore:**

- Título: `AltStore`
- Descripción:
  > Funciona en **cualquier versión de iOS**. Necesitas una PC o Mac una vez.
- Botón: `Descargar Bitly.ipa`
- Pasos numerados (instalar AltServer, conectar por USB, etc.)

### Paso 3 — La versión

Debajo:
> Última versión: 0.9.10 · 34.4 MB

---

## Textos exactos que conviene usar

### ❌ NO uses
- `Descargar para iPhone` (solo, sin explicar) → el usuario toca, no pasa nada, se frustra.
- `Instalar en iPhone` → promete algo que Apple no permite hacer en un tap.
- Cualquier texto que diga "descarga e instala" para iPhone.

### ✅ SÍ usa

| Dónde | Texto |
|---|---|
| Botón en la home | `Descargar para iPhone` |
| Encabezado de la sección | `Elige cómo instalar Bitly` |
| Subtexto | `Las dos formas son gratis y no necesitan la App Store.` |
| Botón TrollStore | `Instalar con TrollStore` |
| Botón AltStore | `Descargar Bitly.ipa` |

---

## Qué hace cada botón por dentro

### Botón TrollStore

Usa un **URL scheme** que TrollStore entiende:

```
apple-magnifier://install?url=<URL_del_IPA>
```

- Si el usuario **tiene TrollStore** → abre TrollStore y ofrece instalar Bitly. Un tap.
- Si **no lo tiene** → abre la app "Lupa" de iOS (inofensivo). Por eso SIEMPRE debes
  mostrar el paso "¿No tienes TrollStore? Descárgalo aquí" **antes** del botón.

### Botón AltStore

Es una **descarga normal del .ipa**. Después el usuario lo abre con AltStore
(AltStore se registra para abrir archivos .ipa).

---

## Consejo final

En iPhone, **la transparencia convierte mejor que un botón directo**. Si explicas
"esto necesita un paso extra porque Apple lo bloquea", la gente lo entiende y lo hace.
Si prometes descarga directa y no pasa nada, se va.

También sirve poner una nota:

> **¿Por qué no hay un botón directo?**
> Apple no permite instalar apps fuera de la App Store. Estas son las dos formas
> que sí funcionan, y las dos son gratis.
