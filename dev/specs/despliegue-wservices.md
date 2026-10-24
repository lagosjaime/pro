# Especificación de despliegue, wservices y modo proxy — Aplicación `pr`

| Campo | Valor |
| --- | --- |
| Versión | 0.1 (borrador) |
| Fecha | 2026-10-24 |
| Estado | Para revisión e implementación |
| Alcance | Topologías de despliegue (co-localizado, separado interno, DMZ con proxy), URLs de wservices, llamadas backend/frontend, seguridad entre redes |
| Documentos relacionados | [`arquitectura.md`](arquitectura.md), [`base-de-datos.md`](base-de-datos.md), [`control-acceso.md`](control-acceso.md), [`pantallas.md`](pantallas.md), [`logs-desarrollo-auditoria.md`](logs-desarrollo-auditoria.md), [`AGENTS.md`](../../AGENTS.md) |

> Los `wservices` son el único punto de acceso a datos de negocio. El backend (App) y el frontend (JS) pueden tener rutas de acceso distintas a ellos dependiendo de la red en la que se encuentren. Esta especificación define cómo configurarlo sin romper la arquitectura.

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
| **WServices** | Servicios API modulares en `modules/<modulo>/wservices/` expuestos vía `/api/<modulo>/<servicio>`. Único acceso a datos de negocio mediante procedimientos almacenados. |
| **WSE_URL** | URL base para acceder a los `wservices` desde el backend. |
| **WSE_PUBLIC_URL** | URL base para que el frontend acceda a los `wservices`. En modo proxy, esta es la misma que la App. |
| **WSE_INTERNAL_URL** | URL base de los `wservices` internos (con acceso a BD), usada por el proxy de la App en modo DMZ. |
| **Proxy de App** | Cuando la App recibe una llamada `/api/...` desde el frontend en modo DMZ sin acceso directo a los `wservices` internos, redirige/reenvía esa petición al `WSE_INTERNAL_URL`. |

---

## 3. Topologías de despliegue

### 3.1 Topología A: Mismo servidor (co-localizado)
- **Ubicación**: App, Backend, WServices, BD en el mismo servidor/red interna.
- **Acceso**: Frontend → App (`/api/...`), Backend → WServices local.
- **Configuración**: `WSE_URL` apunta al propio servidor o a ruta relativa; `WSE_PUBLIC_URL` puede ser igual a la URL de la App.
- **Uso típico**: desarrollo, ambientes simples.

### 3.2 Topología B: Separados internamente
- **Ubicación**: Servidor A (App + Backend, sin BD directa o con BD limitada), Servidor B (WServices + acceso a BD). Ambos en red interna.
- **Acceso**: Frontend → App (`/api/...`), Backend → `WSE_URL = http://wservices-interno:9090`.
- **Sin proxy**: Ambos pueden acceder directamente al servidor de WServices por red interna.
- **Uso típico**: separación por capas en red interna.

### 3.3 Topología C: DMZ con proxy
- **Ubicación**: Servidor DMZ (App expuesto a internet, **sin acceso a BD**), Servidor interno (WServices con acceso a BD). Comunicación solo desde DMZ hacia interno por ruta autorizada.
- **Problema**: El frontend JS se ejecuta en el navegador del cliente (fuera de la red interna). Si se apunta directamente a `WSE_INTERNAL_URL`, no será accesible desde internet.
- **Solución**: 
  - `WSE_PUBLIC_URL` = URL de la App (misma origen o URL pública). El frontend llama a `/api/...` de la App.
  - La App detecta que debe actuar como **proxy**: cuando recibe una petición `/api/<modulo>/<servicio>` desde el frontend y no puede/ no debe enrutarla localmente a sus propios wservices, la reenvía a `WSE_INTERNAL_URL` con headers apropiados, preservando autenticación y contrato.
  - `WSE_INTERNAL_URL` solo es accesible desde el servidor de la App (DMZ) hacia la red interna.
- **Uso típico**: App expuesta a internet con BD aislada en red interna.

---

## 4. Configuración en `.env`

### 4.1 Variables obligatorias

| Variable | Requerido | Descripción | Ejemplo |
| --- | --- | --- | --- |
| `APP_URL` | Sí | URL base pública de la App | `https://app.example.com` o `http://localhost:8080` |
| `WSE_MODE` | Sí | Modo de comunicación con wservices | `local` \| `remote` \| `proxy` |
| `WSE_URL` | Sí | URL base para que el **backend** llame a los wservices | `http://localhost:9090` o `http://wservices-interno:9090` |
| `WSE_PUBLIC_URL` | Sí | URL base para que el **frontend** llame a los wservices | `http://localhost:8080` (mismo origen, proxy) o `http://wservices-publico:9090` |
| `WSE_INTERNAL_URL` | Condicional | URL base de wservices internos con acceso a BD (solo en modo `proxy`) | `http://wservices-interno:9090` |
| `WSE_TIMEOUT` | No | Timeout en segundos para llamadas HTTP internas | `30` |
| `WSE_AUTH_HEADER` | No | Header para autenticación entre App y WServices (modo separado) | `X-WSE-Token` |
| `WSE_AUTH_TOKEN` | No | Token compartido para autenticación entre servicios | (secreto) |

### 4.2 Configuraciones por topología

#### A) Mismo servidor
```env
APP_URL=http://localhost:8080
WSE_MODE=local
WSE_URL=http://localhost:8080
WSE_PUBLIC_URL=http://localhost:8080
```

#### B) Separados internamente
```env
APP_URL=http://app-interno:8080
WSE_MODE=remote
WSE_URL=http://wservices-interno:9090
WSE_PUBLIC_URL=http://wservices-interno:9090
WSE_AUTH_HEADER=X-WSE-Token
WSE_AUTH_TOKEN=<token-compartido>
```

#### C) DMZ con proxy
```env
APP_URL=https://app.example.com
WSE_MODE=proxy
WSE_URL=http://localhost:8080  # Backend llama vía App/proxy local o directo según implementación
WSE_PUBLIC_URL=https://app.example.com  # Frontend llama a la App
WSE_INTERNAL_URL=http://wservices-interno:9090  # App (DMZ) → WServices (interno)
WSE_AUTH_HEADER=X-WSE-Token
WSE_AUTH_TOKEN=<token-compartido-entre-app-dmz-y-wservices>
```

### 4.3 Reglas
- Las URLs nunca deben tener `/` al final.
- En modo `proxy`, el frontend **nunca** debe conocer `WSE_INTERNAL_URL`.
- En modo `proxy`, solo el servidor de la App conoce `WSE_INTERNAL_URL`.
- Los tokens compartidos entre servicios van en `.env` (nunca en repositorio).

---

## 5. Flujo de llamadas

### 5.1 Frontend → API
El JavaScript siempre usa `WSE_PUBLIC_URL` configurado en `#app-bootstrap`:
- **Modo local/remote directo**: `fetch(WSE_PUBLIC_URL + '/api/<modulo>/<servicio>')`
- **Modo proxy**: `fetch(WSE_PUBLIC_URL + '/api/<modulo>/<servicio>')` donde `WSE_PUBLIC_URL` es la URL de la App. La App enruta esas peticiones a sus `wservices` locales o las hace proxy a `WSE_INTERNAL_URL`.

### 5.2 Backend → WServices
El backend PHP usa `WSE_URL`:
- **Modo local**: puede llamar directamente a sus propios `wservices` o vía HTTP localhost.
- **Modo remote**: usa `curl` hacia `WSE_URL` con autenticación de servicio.
- **Modo proxy**: según arquitectura, puede llamar vía ruta interna o dejar que el flujo pase por el proxy. La decisión es configurable.

### 5.3 Modo proxy detallado
Cuando `WSE_MODE=proxy`:
1. Cliente (navegador) hace `fetch('https://app.example.com/api/ventas/pedido', ...)` 
2. nginx/routing de la App recibe `/api/...` en `public/api/index.php` o en un router de proxy
3. `Api`/`ProxyController` detecta modo proxy: en lugar de resolver localmente, reenvía la petición completa (método, headers, body, query) a `WSE_INTERNAL_URL/api/...`
4. Se añaden headers de confianza: `X-Forwarded-For`, `X-Real-IP`, `X-WSE-Token` (si aplica)
5. Se preserva autenticación del usuario: el token/sesión debe propagarse correctamente
6. Se devuelve la respuesta tal cual (JSON con contrato `{status,message,data}`) al cliente
7. Timeouts, reintentos controlados, logging

---

## 6. Implementación

### 6.1 Configuración
Añadir a `Config`:
```php
'wses' => [
    'mode' => env('WSE_MODE', 'local'),
    'url' => rtrim(env('WSE_URL'), '/'),
    'public_url' => rtrim(env('WSE_PUBLIC_URL'), '/'),
    'internal_url' => env('WSE_INTERNAL_URL') ? rtrim(env('WSE_INTERNAL_URL'), '/') : null,
    'timeout' => (int)env('WSE_TIMEOUT', 30),
    'auth_header' => env('WSE_AUTH_HEADER'),
    'auth_token' => env('WSE_AUTH_TOKEN'),
],
```

### 6.2 Cliente HTTP para WServices
Crear `system/WsClient`:
- `call(string $module, string $service, array $data = [], string $method = 'POST'): array`
- Usa `WSE_URL` en modo remote/local, maneja autenticación
- En modo proxy, el backend puede usarlo para llamadas internas o delegar
- Añade correlación `X-Request-Id`

### 6.3 Router/Proxy API
En `public/api/index.php` o `core/Api`:
```php
if (config('wses.mode') === 'proxy' && shouldProxy($uri)) {
    // reenviar a WSE_INTERNAL_URL
    $response = $httpClient->proxy($uri, $_SERVER, file_get_contents('php://input'));
    // emitir respuesta
    return;
}
// else routing normal a wservices locales
```

Reglas:
- Solo enrutar `/api/<modulo>/<servicio>` al proxy
- No hacer proxy de rutas internas de la App que no sean wservices
- Preservar headers relevantes (Content-Type, Authorization, X-CSRF-Token)
- Añadir headers internos de confianza
- Validar que `WSE_INTERNAL_URL` esté configurado

### 6.4 Bootstrap JS
Inyectar en `app/views/layouts/app.html.twig`:
```html
<script>
window.APP_CONFIG = {
  wsPublicUrl: '{{ ws_public_url|e('js') }}',
  wsMode: '{{ ws_mode|e('js') }}',
  env: '{{ app_env|e('js') }}'
};
</script>
```

El cliente JS usa `window.APP_CONFIG.wsPublicUrl` para todas las llamadas a `/api/...`.

---

## 7. Seguridad

| Aspecto | Medida |
| --- | --- |
| **Separación de redes** | En modo proxy, BD solo accesible desde red interna (WServices). DMZ sin acceso directo. |
| **Autenticación entre servicios** | Usar token compartido (`WSE_AUTH_TOKEN`) entre App (DMZ) y WServices (interno). Validar en wservices. |
| **Propagación de usuario** | Mantener sesión/token de usuario. El proxy debe reenviar credenciales de forma segura. |
| **Headers de confianza** | Añadir `X-Forwarded-For`, `X-Real-IP` solo desde App confiable. |
| **TLS** | Usar HTTPS entre App y WServices si atraviesan redes no confiables. |
| **No exponer interno** | `WSE_INTERNAL_URL` nunca en JS/bootstrap. |
| **Rate limiting** | Aplicar en App (proxy) y en WServices. |
| **Logs** | Registrar llamadas proxy con `navId` y correlación. |

---

## 8. Casos de uso y validación

- [ ] Modo `local`: funciona con App + WServices en mismo servidor
- [ ] Modo `remote`: backend llama por HTTP a WServices separados
- [ ] Modo `proxy`: frontend llama a App, App reenvía a WServices internos sin exponerlos
- [ ] Autenticación se mantiene en los 3 modos
- [ ] Contrato JSON `{status,message,data}` se preserva
- [ ] Logs funcionan correctamente con las 3 topologías
- [ ] Timeouts y errores se manejan correctamente
- [ ] En modo proxy, cliente nunca ve URL interna

---

## 9. Actualización de `.env.example`

```env
# URLs de WServices
APP_URL=http://localhost:8080
WSE_MODE=local
WSE_URL=http://localhost:8080
WSE_PUBLIC_URL=http://localhost:8080
# Solo para modo proxy:
# WSE_INTERNAL_URL=http://wservices-interno:9090
# WSE_AUTH_HEADER=X-WSE-Token
# WSE_AUTH_TOKEN=change-me
WSE_TIMEOUT=30
```

---

## 10. Notas

- **Compatibilidad**: La arquitectura actual con `/api/<modulo>/<servicio>` debe seguir funcionando. El modo proxy es transparente para los wservices.
- **Desarrollo**: Normalmente `local`. Producción interna `remote`. DMZ `proxy`.
- **Testing**: Poder simular las 3 topologías con docker-compose.
- **Correlación**: Mantener trazabilidad entre frontend, App proxy y WServices internos.
