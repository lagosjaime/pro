# Especificación de logs de desarrollo, auditoría y trazabilidad — Aplicación `pr`

| Campo | Valor |
| --- | --- |
| Versión | 0.1 (borrador) |
| Fecha | 2026-10-24 |
| Estado | Para revisión e implementación |
| Alcance | Ambiente, log de acciones de usuario (auditoría), consola del navegador (solo desarrollo), `app_ctrl.log` (solo desarrollo), señal App→Backend para trazabilidad de pantallas |
| Documentos relacionados | [`arquitectura.md`](arquitectura.md), [`base-de-datos.md`](base-de-datos.md), [`control-acceso.md`](control-acceso.md), [`pantallas.md`](pantallas.md), [`AGENTS.md`](../../AGENTS.md) |

> Estos logs son **ayudas al desarrollador** y, en el caso del log por usuario, **complemento de auditoría** junto a `app_db.bitacora`. Nunca deben registrar contraseñas, tokens, secretos, hashes sensibles ni datos completos de documentos con información crítica.

---

## 1. Objetivo

Definir tres mecanismos de trazabilidad complementarios:

1. **Log de acciones del usuario (siempre)**: archivo por usuario/fecha en `files/logs/<usuario>_<fecha>.log` con todas las acciones relevantes (carga de pantallas/opciones y llamadas a base de datos).
2. **Log en consola del navegador (solo desarrollo)**: trazado en tiempo real de las llamadas `fetch` a `wservices` (`/api/...`), sus parámetros y respuesta, además de las navegaciones a pantallas con sus parámetros.
3. **`app_ctrl.log` (solo desarrollo)**: archivo único que se reinicia con cada carga de pantalla y concentra toda la traza de esa carga: datos de la pantalla, parámetros, llamadas internas a `wservices` realizadas desde el backend durante el render/carga y sus resultados.

---

## 2. Ambiente de la aplicación

### 2.1 Variable `APP_ENV`

El archivo `.env` **obligatoriamente** debe indicar el ambiente:

| Valor | Uso | Comportamiento |
| --- | --- | --- |
| `development` | Local/desarrollo | Habilita consola del navegador, `app_ctrl.log` y verbosidad extra. Genera logs completos para depuración. |
| `production` | Producción | **Solo** genera el log de acciones del usuario por archivo. Se deshabilitan los logs exclusivos de desarrollo. |

Reglas:

- `APP_ENV` se lee vía `Config`. Nunca se infiere por `APP_DEBUG` únicamente.
- `APP_DEBUG` puede seguir usándose para trazas de errores, pero **los logs de desarrollador descritos aquí dependen exclusivamente de `APP_ENV=development`**.
- `.env.example` debe incluir `APP_ENV=development` con comentario explicativo.
- El `Logger` compartido debe conocer `APP_ENV` para decidir qué destinos habilita.

---

## 3. Log de acciones del usuario (siempre, desarrollo y producción)

### 3.1 Ubicación y nombre

```text
files/logs/<usuario>_<YYYY-MM-DD>.log
```

- `<usuario>`: identificador estable del usuario autenticado (preferentemente `usuario_login`). Si no hay usuario autenticado (rutas públicas/login) se usará `anonimo` o se omite el registro según corresponda.
- `<YYYY-MM-DD>`: fecha en **UTC**.
- Directorio: `files/logs/` (ya existente según estructura). Debe tener permisos de escritura para PHP-FPM.
- Un archivo por usuario y por día. Se crea automáticamente al primer registro del día.

### 3.2 Cuándo registrar

Debe quedar constancia de:

| Evento | Cuándo | Origen |
| --- | --- | --- |
| **Carga/navegación de pantalla** | Al entrar a una opción vía carga completa o fragmento (`GET /<modulo>/<opcion>`) | Señal enviada por la **App** (JS) al backend al montar la pantalla. |
| **Llamadas a base de datos** | Toda invocación a procedimiento vía `Db::exec()` | Wrapper de `Db` (único punto). Debe registrar procedimiento, base de datos, parámetros (sanitizados) y duración. |
| **Acciones relevantes de API** | Llamadas que ejecuten lógica de negocio vía `wservices` (POST/PUT/PATCH/DELETE) | `Api`/`wservices` o middleware de auditoría. |
| **Uso de opción** | Cada acceso autorizado a una opción | Integrado con `opcion_uso_log` pero con mayor detalle en este archivo. |

### 3.3 Integración con la App (señal al backend)

Como las navegaciones/cargas de pantalla ocurren principalmente desde las **clases JS de la App**:

1. Cuando la App monte una pantalla (tras insertar fragmento o tras carga completa), enviará una señal al backend.
2. Endpoint propuesto: `POST /api/system/trace/screen`. Debe requerir autenticación.
3. Payload mínimo:

```json
{
  "screenId": "ventas/pedido",
  "url": "/ventas/pedido?estado=abierto",
  "module": "ventas",
  "option": "pedido",
  "params": {"estado": "abierto"},
  "navId": "01J..."
}
```

4. El backend validará sesión/token, obtendrá usuario y escribirá la entrada `type:SCREEN` en `<usuario>_<fecha>.log`.

### 3.4 Reglas de sanitización

- **Nunca** loguear: `password`, `usuario_password`, `token`, `usuario_token_acceso`, `secreto`, `codigo`, `codigo_hash`, `authorization`, `cookie`, `csrf_token`, `X-Token`.
- En `params`: enmascarar o truncar valores sensibles.
- Truncar cadenas muy largas (> 2000 caracteres) con `"[TRUNCATED]"`.
- No registrar cuerpos completos de archivos.

### 3.5 Relación con bitácora

- `app_db.bitacora`: cambios estructurales/negocio (INSERT/UPDATE/baja lógica/restauración) con snapshots antes/después.
- `files/logs/<usuario>_<fecha>.log`: trazabilidad operativa (quién hizo qué, por dónde navegó, qué procedimientos invocó).
