# Self-host de las piezas del rescate

Estas carpetas **no son de Bitly**: son guías y parches para levantar **vos** los
servicios de los que dependen los canales del rescate. La app ya trae un canal
por defecto para cada uno, pero todos viven de *pools de cuentas pagas
compartidas* — y esos pools se banean (ARLs de Deezer, cuentas Tidal, tokens de
Qobuz). Tener tu propia instancia es lo único que no vuelve a caerse.

El porqué completo y las mediciones están en
[`docs/canales_rescate_alternativas.md`](../docs/canales_rescate_alternativas.md).

| Carpeta | Qué levanta | Resuelve | Necesitás |
|---|---|---|---|
| [`arcod/`](arcod/README.md) | Instancia propia de arcod (catálogo + stream de Qobuz) | El canal `arcod` muerto en el origen | `Docker` + sesiones de Qobuz |
| [`qobuz-pool/`](qobuz-pool/README.md) | El `/pool` del Worker propio (sesiones de Qobuz) | Descarga directa sin pegar tokens a mano | Cuenta Cloudflare + sesiones de Qobuz |
| [`hifi-api/`](hifi-api/README.md) | Fuente Tidal propia (hifi-api) | Un espejo/API que sea TUYO | Cuenta Tidal + máquina para correrlo |

## El atajo: un solo token de Qobuz cubre dos canales

El mismo `user_auth_token` de una cuenta **con suscripción** Qobuz sirve en tres
lugares:

| Dónde | Variable | Arregla |
|---|---|---|
| Worker propio (`deeplinks/proxy-qobuz`) | `QOBUZ_USER_TOKEN` | `qobuz-firmado` deja de devolver muestra y entrega FLAC |
| Worker propio | `QOBUZ_AUTH_TOKENS` | el pool de sesiones (descarga directa) |
| Instancia arcod (`selfhost/arcod`) | `QOBUZ_AUTH_TOKENS` | el canal `arcod` |

Con un plan **Dúo/Familia** sacás hasta 6 sesiones y llenás el pool. Sin
suscripción, Qobuz solo entrega MP3 320 o una muestra de 30 s: no hay forma de
rodearlo (Qobuz no tiene endpoint de emisión anónima de tokens).
