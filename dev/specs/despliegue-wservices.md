# Especificación de despliegue, wservices y modo proxy — Aplicación `pr`

| Campo | Valor |
| --- | --- |
| Versión | 0.1 (borrador) |
| Fecha | 2026-10-24 |
| Estado | Para revisión e implementación |
| Alcance | Topologías de despliegue (co-localizado, separado interno, DMZ con proxy), URLs de wservices, llamadas backend/frontend, seguridad entre redes |
| Documentos relacionados | [`arquitectura.md`](arquitectura.md), [`base-de-datos.md`](base-de-datos.md), [`control-acceso.md`](control-acceso.md), [`pantallas.md`](pantallas.md), [`logs-desarrollo-auditoria.md`](logs-desarrollo-auditoria.md), [`AGENTS.md`](../../AGENTS.md) |

> Los `wservices` son el único punto de acceso a datos de negocio. El backend (App) y el frontend (JS) pueden tener rutas de acceso distintas a ellos dependiendo de la red en la que se encuentren.

---

## 1. Objetivo

Definir cómo se comunican la aplicación, el backend y los `wservices` en distintos entornos:

- **Mismo servidor**: App + Backend + WServices en el mismo host (monolítico lógico).
- **Separados internamente**: App/Backend en un servidor, WServices en otro servidor interno con acceso a BD.
- **DMZ con proxy**: App en servidor con salida a internet (DMZ), sin acceso a BD; WServices en red interna con acceso a BD. El backend y el frontend se comunican con los WServices a través de la App actuando como proxy.

---

## 2. Terminología

| Término | Definición |
| --- | --- |
| **App / Frontend** | Código JavaScript ejecutado en el navegador. Hace llamadas `fetch` hacia la API. |
| **Backend** | PHP (`core/App`, `core/Api`, controladores web, lógica de servidor). Orquesta la petición y puede llamar a los `wservices` por HTTP interno. |
| **WServices** | Servicios HTTP que exponen las rutas `/<modulo>/<servicio>` de `router_api.php`. Únicos con acceso directo a la base de datos vía procedimientos. |
| **WSERVICES_INTERNAL_URL** | URL utilizada exclusivamente por el **backend PHP** para llamar a los `wservices`. Nunca expuesta al navegador. |
| **WSERVICES_PUBLIC_BASE** | Ruta/base que el **navegador** utiliza para llamar a la API. Puede ser `/api` (mismo origen) o una URL absoluta si es directo. |
| **Modo proxy** | Cuando el frontend llama al mismo origen (`/api/...`) y la App reenvía esas peticiones al `WSERVICES_INTERNAL_URL`. |

---

## 3. Topologías soportadas

### 3.1 Topología A: Co-localizado (desarrollo / intranet simple)
```text
[Navegador] -> http://app.local/api/... -> App (nginx + PHP) -> módulos/wservices (mismo proceso/ruta)
```

```env
WSERVICES_MODE=direct
WSERVICES_INTERNAL_URL=http://app.local
WSERVICES_PUBLIC_BASE=/api
```

### 3.2 Topología B: Separado interno (Backend != WServices)
```text
[Navegador] -> http://app-interno:8080/api/... -> App Backend -> curl -> http://wservices-interno:9090/<modulo>/<servicio>
```

```env
WSERVICES_MODE=direct
WSERVICES_INTERNAL_URL=http://wservices-interno:9090
WSERVICES_PUBLIC_BASE=/api
```

### 3.3 Topología C: DMZ con proxy (recomendado para exposición a internet)
```text
[Internet/Navegador] -> https://app.dmz.org/api/... 
                            -> App (DMZ) [REVERSE PROXY]
                                -> curl/http -> http://wservices-interno.corp:9090/...
                                    -> WServices -> BD (solo red interna)
```

```env
WSERVICES_MODE=proxy
WSERVICES_INTERNAL_URL=http://wservices-interno.corp:9090
WSERVICES_PUBLIC_BASE=/api
WSERVICES_PROXY_TIMEOUT=30
WSERVICES_PROXY_PASSTHROUGH_HEADERS=Authorization,X-Request-Id,X-Correlation-Id,X-Real-IP
WSERVICES_PROXY_STRIP_HEADERS=Host
WSERVICES_PROXY_TRUST_CLIENT_IP=true
WSERVICES_PROXY_FORWARD_COOKIES=false
```

---

## 4. Configuración en `.env`

```env
# === WServices / API Routing ===
WSERVICES_MODE=proxy
WSERVICES_INTERNAL_URL=http://wservices-interno:9090
WSERVICES_PUBLIC_BASE=/api
WSERVICES_PROXY_TIMEOUT=30
WSERVICES_PROXY_PASSTHROUGH_HEADERS=Authorization,X-Request-Id,X-Correlation-Id,X-Real-IP
WSERVICES_PROXY_STRIP_HEADERS=Host
WSERVICES_PROXY_TRUST_CLIENT_IP=true
WSERVICES_PROXY_FORWARD_COOKIES=false
```

Reglas:
- `WSERVICES_INTERNAL_URL` **nunca** debe ser enviada al navegador.
- Si `WSERVICES_MODE=proxy`, `public/api/index.php` debe actuar como **reverse proxy**.
- Si `WSERVICES_MODE=direct`, el routing sigue el comportamiento actual pero las llamadas desde backend deben construirse con `WSERVICES_INTERNAL_URL` cuando se haga HTTP interno.

---

## 5. Autenticación entre App/Backend y WServices

### 5.1 Cabeceras obligatorias

| Cabecera | Obligatoria | Descripción |
| --- | --- | --- |
| `X-User-Id` | Sí | Identificador del usuario autenticado (`idusuario`). |
| `X-Token` | Sí | Token de acceso vigente del usuario (`usuario_token_acceso`). |
| `X-Idempotency-Key` | Condicional | Obligatoria para `POST`, `PUT`, `PATCH`, `DELETE`. |
| `X-Request-Id` | Recomendado | Identificador de correlación para cruzar logs. |

### 5.2 Validación en los WServices

Los `wservices` deben validar:

- Usuario existente, `activo = true`, no `eliminado`, `bloqueado = false`
- Token coincide con `usuarios.usuario_token_acceso` (comparación con hash)
- Vigencia: `fecha_token_acceso` + `sesion_vigencia_minutos` > ahora (UTC)
- Consistencia entre `X-User-Id` y `X-Token`
- Autorización por opción/servicio según control de acceso

### 5.3 Inyección de cabeceras

El Backend de la App es el **único** responsable de inyectar `X-User-Id` y `X-Token`. Nunca debe reenviar valores provenientes directamente del cliente.

---

## 6. Idempotencia

Para operaciones mutables (`POST`, `PUT`, `PATCH`, `DELETE`):
- El cliente/App genera `X-Idempotency-Key` (UUID v4). En reintentos del mismo request se debe reutilizar la misma clave.
- Los WServices deben buscar la clave en Redis/almacén. Si existe y está completada, devolver **exactamente** la misma respuesta.
- Si está en proceso, responder `409` o `425`.
- Almacenar respuesta completa con TTL (recomendado 600 segundos).
- Verificar hash del request para evitar reutilización con body distinto.

---

## 7. Caché en WServices

### 7.1 Cuándo usar caché

| Tipo de dato | ¿Usar caché? | Justificación |
| --- | --- | --- |
| Opciones de menú por usuario/rol | Sí | Poco variable |
| Información del usuario autenticado | Sí | Cambia con mantenedores |
| Catálogos maestros | Sí | Poco variable |
| Parámetros del sistema | Sí | Poco variable |
| Datos operativos/transaccionales | No | Requieren información actualizada |
| Listados con filtros complejos | No | Varían mucho por filtro |

### 7.2 Drivers

- `redis`: Recomendado para múltiples instancias
- `file`: Válido para única instancia/co-localizado

### 7.3 Estrategia

Cache-first: buscar en caché → si miss, consultar procedimiento → almacenar con TTL → retornar. Solo respuestas `status: "ok"`. Nunca cachear errores.

### 7.4 Claves

Formato: `ws:<modulo>:<contexto>:<clave>`
Ejemplos: `ws:system:menu:user:123`, `ws:ventas:catalog:formas_pago`, `ws:system:params:seguridad`

### 7.5 Invalidación

Desde mantenedores que modifiquen datos cacheables, invalidar claves afectadas **tras COMMIT** de la transacción. Usar `CacheManager` centralizado. Nunca `FLUSHALL`.

---

## 8. Recomendación: mTLS + Listas de IP (Obligatorio en DMZ)

### 8.1 ¿Por qué mTLS?
- Autenticación mutua con CA interna
- Protege ante spoofing de cabeceras
- Defensa en profundidad
- Identifica al servidor que llama vía certificado

### 8.2 ¿Por qué listas de IP?
- Primer filtro a nivel de firewall
- Doble validación en aplicación
- Restringe únicamente al servidor App

### 8.3 Reglas

**Nivel red:**
- Permitir solo `IP_App -> IP_WServices:PUERTO` 
- WServices no expuestos a internet
- Segmentación adecuada

**Nivel mTLS:**
- CA interna propia
- Certificado cliente para App, certificado servidor para WServices
- Requerir verificación cliente (`ssl_verify_client = on`)
- Validar CN/SAN del certificado cliente
- `WSERVICES_MTLS_REQUIRED=true` en producción con DMZ

**Nivel aplicación:**
- Validar IP contra `WSERVICES_TRUSTED_IPS` (no confiar en `X-Forwarded-For`)
- Validar `$_SERVER['SSL_CLIENT_VERIFY'] === 'SUCCESS'` si mTLS requerido
- Rechazar si IP no confiable o certificado inválido
- Siempre validar `X-User-Id`/`X-Token` contra `app_db`

### 8.4 Variables

```env
WSERVICES_MTLS_REQUIRED=true
WSERVICES_MTLS_CA=/etc/ssl/wservices/ca-interna.crt
WSERVICES_MTLS_CLIENT_CERT=/etc/ssl/wservices/app-client.crt
WSERVICES_MTLS_CLIENT_KEY=/etc/ssl/wservices/app-client.key
WSERVICES_MTLS_VERIFY_HOST=true
WSERVICES_REQUIRE_USER_HEADERS=true
WSERVICES_TRUSTED_IPS=10.10.50.10,10.10.50.11
WSERVICES_IDEMPOTENCY_TTL=600
```

**Regla de oro:** mTLS + IP allowlist identifican **QUÉ SERVIDOR** llama (App). `X-User-Id` + `X-Token` identifican **QUIÉN** llama (usuario). Ambas cosas son necesarias.
