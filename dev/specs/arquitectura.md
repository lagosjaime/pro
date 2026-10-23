# Especificación de arquitectura — Aplicación `pr`

| Campo | Valor |
| --- | --- |
| Versión | 0.3 (borrador) |
| Fecha | 2026-10-22 |
| Estado | Para revisión y refinamiento |
| Alcance | Arquitectura de arranque, enrutamiento web, API, autenticación, control de acceso, organización por módulos, acceso a datos y navegación de pantallas |
| Documentos relacionados | [`pantallas.md`](pantallas.md), [`base-de-datos.md`](base-de-datos.md), [`control-acceso.md`](control-acceso.md), [`README.md`](../../README.md), [`AGENTS.md`](../../AGENTS.md) |

> Este documento describe **cómo debe funcionar** la aplicación. No describe el estado actual del código: eso se detalla al final, en «Estado del esqueleto y pendientes». La idea es iterar esta especificación antes de implementar.

---

## 1. Objetivo

La aplicación es un sistema PHP modular, servido por nginx + PHP-FPM, que separa claramente:

- **Pantallas web** (HTML renderizado con Twig).
- **API interna** (JSON consumida por las pantallas mediante `fetch`).
- **Lógica de negocio** encapsulada en servicios por módulo.
- **Infraestructura compartida** (contenedor, configuración, base de datos, caché, logs, autenticación, correo, hojas de cálculo).

El principio rector es: **un único punto de entrada web**, **un único punto de entrada API**, **módulos autocontenidos** y **un contenedor con instancias únicas** para los servicios compartidos.

---

## 2. Principios de diseño

1. **Front controller**: todo el tráfico web pasa por `public/index.php`; todo el tráfico API pasa por `public/api/index.php`.
2. **Bootstrap como composition root**: la carga de entorno, configuración y servicios vive en `Bootstrap`, no en los controladores.
3. **Contenedor de instancias únicas**: `Db`, `Cache`, `Logger`, `Auth`, `Router`, Twig, etc. se construyen una sola vez por petición.
4. **Módulos como unidad funcional**: cada módulo agrupa controladores, servicios API (`wservices`), vistas y sus tablas de rutas.
5. **Separación de responsabilidades**:
   - El controlador web **no consulta la base de datos**; arma la pantalla y delega datos a la API.
   - El servicio API (`wservices`) **no renderiza HTML**; devuelve datos o lanza errores de dominio. Es la única capa de negocio autorizada a acceder a datos.
   - El router **no contiene lógica de negocio**; solo resuelve y autoriza.
6. **Seguro por defecto**: toda ruta web y todo servicio API requieren autenticación salvo que se declare explícitamente lo contrario.
7. **Contrato JSON uniforme**: toda respuesta de la API usa `{status, message, data}` y un código HTTP coherente.
8. **Sin rutas mágicas**: los segmentos de URL se validan contra un patrón estricto y contra archivos de rutas existentes; nunca se usan para construir rutas de archivos sin validación.
9. **Datos por módulo, acceso por procedimientos**: cada módulo tiene su propia base de datos y los `wservices` acceden a ella exclusivamente mediante procedimientos almacenados, para mantener portabilidad entre MySQL y MSSQL. Ver [`base-de-datos.md`](base-de-datos.md).
10. **Comunicación entre módulos por servicio**: cuando un módulo necesita datos de otro, lo hace a través de su `wservice` mediante una llamada HTTP interna tipo `curl`, no consultando directamente su base de datos.
11. **Navegación progresiva**: el shell se renderiza una vez con Twig; las opciones cargan fragmentos HTML en el área de trabajo mediante `fetch`, mantienen URLs profundas y conservan un historial restaurable. La API de datos sigue siendo exclusivamente JSON. Ver [`pantallas.md`](pantallas.md).
12. **Registro estándar y auditoría**: toda tabla de negocio incluye `id`, estado activo, baja lógica y campos de usuario/fecha; las bajas son lógicas y toda modificación deja un registro en `app_db.bitacora` con datos antes/después. Los procedimientos califican siempre sus tablas como `<schema>.<tabla>`. Ver [`base-de-datos.md`](base-de-datos.md) §4.5–§4.8.

---

## 3. Estructura de directorios objetivo

```text
pr/
├── public/                     # Document root de nginx
│   ├── index.php               # Front controller web
│   ├── api/
│   │   └── index.php           # Front controller API
│   ├── assets/                 # CSS/JS estáticos
│   └── demo/                   # Material de ejemplo (no forma parte del núcleo)
├── app/
│   ├── core/
│   │   ├── App.php             # Orquesta una petición web
│   │   ├── Api.php             # Orquesta una petición API
│   │   └── Bootstrap.php       # Carga entorno, configuración y contenedor
│   ├── system/
│   │   ├── Auth.php            # Autenticación y autorización
│   │   ├── Cache.php           # Redis
│   │   ├── Config.php          # Acceso centralizado a configuración
│   │   ├── Container.php       # Registro de instancias únicas
│   │   ├── Db.php              # Administrador de conexiones PDO
│   │   ├── Logger.php          # Logs de aplicación
│   │   ├── Mail.php            # PHPMailer
│   │   ├── Menu.php            # Menú autorizado por módulo
│   │   ├── Router.php          # Resolución de rutas web/API
│   │   ├── ScreenRenderer.php  # Layout completo o fragmento de pantalla
│   │   └── Spread.php          # PhpSpreadsheet
│   └── views/                  # Layout y parciales compartidos (@app)
│       ├── layouts/
│       ├── partials/
│       └── errors/
├── modules/
│   ├── admin/
│   │   ├── controllers/
│   │   ├── wservices/
│   │   ├── views/
│   │   ├── module.php          # Metadatos del módulo y menú
│   │   ├── router.php          # Rutas web del módulo
│   │   └── router_api.php      # Rutas API del módulo
│   ├── dashboard/
│   └── system/
├── files/
│   ├── cache/                  # Caché de Twig y otros archivos temporales
│   └── logs/                   # Logs de aplicación
├── dev/
│   ├── specs/                  # Especificaciones (arquitectura, pantallas y base de datos)
│   ├── docs/
│   ├── sql/
│   │   ├── schemas/            # Script de generación por base de datos
│   │   └── procedures/         # Un archivo por procedimiento, agrupado por base
│   └── scripts/
├── docker/
├── vendor/
├── composer.json
├── docker-compose.yml
├── Makefile
├── .env.example
└── README.md
```

> **Nota de nomenclatura:** la definición original usa `router.php` y `router_api.php`. El esqueleto actual contiene `routes.php` y `routes_api.php`. Se propone adoptar los nombres `router.php` y `router_api.php` como canónicos y renombrar los archivos existentes al implementar. Queda como decisión abierta (§14).

---

## 4. Arranque de la aplicación

### 4.1 Punto de entrada web

`public/index.php` debe ser mínimo:

```php
<?php

declare(strict_types=1);

use core\App;

require dirname(__DIR__) . '/vendor/autoload.php';

$app = new App(dirname(__DIR__));
$app->run();
```

Responsabilidades de `App`:

1. Crear/ejecutar `Bootstrap` para obtener el `Container`.
2. Iniciar la sesión web.
3. Aplicar el control de acceso con `Auth`.
4. Delegar la petición a `Router`.
5. Renderizar la respuesta o redirigir.

### 4.2 Punto de entrada API

`public/api/index.php` debe ser mínimo:

```php
<?php

declare(strict_types=1);

use core\Api;

require dirname(__DIR__, 2) . '/vendor/autoload.php';

$api = new Api(dirname(__DIR__, 2));
$api->run();
```

Responsabilidades de `Api`:

1. Obtener el `Container` mediante `Bootstrap`.
2. Resolver la ruta API con `router_api.php` del módulo.
3. Validar credenciales de la petición con `Auth`.
4. Invocar el servicio de `wservices`.
5. Serializar la respuesta como JSON con el contrato común.
6. Convertir cualquier excepción en una respuesta JSON, nunca en HTML.

### 4.3 Secuencia de `Bootstrap`

`Bootstrap` es el único lugar que conoce el orden de inicialización:

1. Cargar `.env` con `vlucas/phpdotenv` (solo si existe; en producción pueden usarse variables del entorno).
2. Construir `Config` y validar configuración mínima (`APP_ENV`, credenciales de BD, etc.).
3. Crear el `Container`.
4. Registrar servicios compartidos como **singletons**:
   - `Config`
   - `Db` (administrador de conexiones PDO perezosas)
   - `Cache` (Redis)
   - `Logger`
   - `Auth`
   - `Router`
   - `Twig\Environment`
   - `Mail`
   - `Spread`
5. Configurar zona horaria, manejo de errores y nivel de depuración según `APP_ENV`/`APP_DEBUG`.
6. Devolver el `Container` ya listo.

El orden exacto de sesión y manejo de errores puede variar entre web y API; `Bootstrap` debe recibir o exponer el contexto (`web` o `api`) para no compartir comportamientos incompatibles.

### 4.4 Contenedor

- Implementa un registro de servicios con `set()`, `get()` y `has()`.
- Cada servicio se resuelve una sola vez por petición (patrón singleton).
- Las dependencias se pasan por constructor; los controladores y servicios no deben instanciar `Db`, `Auth`, etc. directamente.
- Los identificadores recomendados son nombres de clase o interfaces (`system\Db::class`), no cadenas arbitrarias.
- En una primera versión no se exige autowiring completo: pueden registrarse factories explícitas.

---

## 5. Enrutamiento web

### 5.1 Formato de URL

| URL | Comportamiento |
| --- | --- |
| `/` | Pantalla inicial del sistema. |
| `/<modulo>/<opcion>` | Busca `modules/<modulo>/router.php` y resuelve `<opcion>`. |
| Cualquier otra ruta | 404. |

Para el MVP no se admiten parámetros de ruta adicionales (`/<modulo>/<opcion>/<param>`); los datos variables viajan por query string o por la API. Si más adelante se necesitan, se incorporarán como decisión explícita.

### 5.2 Resolución

`Router` (o `App` usando `Router`) debe:

1. Obtener la ruta desde `REQUEST_URI`, descartar el query string y normalizar barras.
2. Si la ruta es `/` (o vacía), resolver la **ruta inicial** configurada. Propuesta: `dashboard/index`, configurable mediante `APP_HOME`.
3. Separar en módulo y opción.
4. Validar ambos segmentos con un patrón estricto, por ejemplo `^[a-z][a-z0-9_-]*$`.
5. Verificar que exista `modules/<modulo>/router.php`.
6. Verificar que `<opcion>` exista como clave en el arreglo devuelto por ese archivo.
7. Verificar el método HTTP declarado; si no coincide, responder `405` con cabecera `Allow`.
8. Aplicar autenticación si la ruta está protegida (`auth` distinto de `false`).
9. Instanciar el controlador a través del contenedor e invocar la acción declarada.
10. Si algo no existe, responder `404` (HTML en web, JSON en API).

Nunca se debe construir una ruta de archivo concatenando segmentos sin validarlos; esto evita *path traversal* y carga de archivos arbitrarios.

### 5.3 Archivo `router.php`

Cada módulo expone sus opciones web mediante un arreglo:

```php
<?php

declare(strict_types=1);

use Dashboard\Controllers\IndexController;
use Dashboard\Controllers\UsuariosController;

return [
    'index' => [
        'controller' => IndexController::class,
        'action' => 'index',
        'method' => 'GET',
        'auth' => true,
    ],
    'usuarios' => [
        'controller' => UsuariosController::class,
        'action' => 'index',
        'method' => 'GET',
        'auth' => true,
    ],
];
```

Campos:

| Campo | Obligatorio | Descripción |
| --- | --- | --- |
| `controller` | Sí | Clase FQCN del controlador. |
| `action` | No | Método a invocar. Por defecto `index`. |
| `method` | No | Verbo HTTP permitido. Por defecto `GET`. |
| `auth` | No | `true` por defecto. `false` para rutas públicas (login, logout, health). |
| `permission` | No | Permiso adicional requerido para ejecutar la ruta. |
| `title` | No | Título de la pantalla. |
| `view` | No | Permite sobrescribir la vista derivada del controlador. |
| `menu` | No | Metadatos para el menú lateral; si falta o es `false`, la opción no se muestra. |

### 5.4 Controladores y vistas

- Ubicación: `modules/<modulo>/controllers/<Nombre>Controller.php`.
- Namespace: `<Modulo>\Controllers`, por ejemplo `Dashboard\Controllers\UsuariosController`.
- El controlador recibe del contenedor las dependencias que necesita (Twig, Auth, Config, etc.).
- El controlador solo prepara datos de presentación y renderiza; no ejecuta consultas SQL.
- La vista por defecto se deriva del nombre del controlador:
  - quitar el sufijo `Controller`;
  - convertir `PascalCase` a `snake_case`;
  - agregar `.html.twig`.
  - Ejemplos: `IndexController` → `index.html.twig`; `UsuariosController` → `usuarios.html.twig`; `ListaUsuariosController` → `lista_usuarios.html.twig`.
- Ubicación de la vista: `modules/<modulo>/views/<vista>`.
- Twig se configura con un namespace por módulo (`@dashboard`, `@admin`, `@system`) y un espacio compartido (`@app` → `app/views/`) para layout, partials y páginas de error.
- Las vistas de módulo son fragmentos de pantalla reutilizables; el layout completo vive en `@app/layouts/app.html.twig`.
- El controlador renderiza mediante `system\ScreenRenderer`, que decide entre layout completo y fragmento según la petición (ver [`pantallas.md`](pantallas.md) §4 y §6).

Ejemplo conceptual:

```php
final class UsuariosController
{
    public function __construct(private system\ScreenRenderer $screen)
    {
    }

    public function index(): void
    {
        $this->screen->render('@dashboard/usuarios.html.twig', [
            'titulo' => 'Usuarios',
        ]);
    }
}
```

### 5.5 Acceso web

- `App` inicia la sesión antes de resolver la ruta.
- Si la ruta requiere autenticación y `Auth::check()` es falso:
  - guardar la URL solicitada como destino posterior;
  - responder `302` hacia `/system/login?redirect=<ruta-interna>`.
- La ruta de login debe ser pública (`auth => false`).
- El destino de redirección debe validarse como ruta interna (empezar con `/`, sin host ni esquema) para evitar *open redirects*.
- Tras autenticarse, redirigir al destino guardado o a `/`.

### 5.6 Render de pantallas y navegación sin recarga

- La misma URL `/<modulo>/<opcion>` sirve para dos representaciones:
  - **carga completa**: layout Twig + fragmento inicial;
  - **fragmento**: solo la plantilla de la pantalla, solicitada con `X-App-Navigation: fragment`.
- Ambas representaciones aplican las mismas validaciones de autenticación, método y permisos.
- En modo fragmento no se devuelven redirecciones `302`; una sesión expirada responde `401`.
- El cliente usa `History API` (`pushState`, `replaceState`, `popstate`) para conservar URLs, filtros y estado de pantalla.
- La navegación devuelve HTML; los datos se solicitan a `/api/...` como JSON.
- El historial guarda la llamada de navegación (`GET`), el estado serializable, el título y la posición de scroll.
- La especificación detallada, el contrato de fragmentos, el ciclo de vida de pantallas y los criterios de aceptación están en [`pantallas.md`](pantallas.md).

---

## 6. Enrutamiento API

### 6.1 Formato de URL

| URL | Comportamiento |
| --- | --- |
| `/api/<modulo>/<servicio>` | Busca `modules/<modulo>/router_api.php` y resuelve `<servicio>`. |
| Cualquier otra ruta API | Error JSON `404`. |

`Api` descarta el prefijo `api` antes de interpretar módulo y servicio.

### 6.2 Resolución

1. Validar módulo y servicio con el mismo patrón estricto que en web.
2. Verificar `modules/<modulo>/router_api.php`.
3. Verificar que `<servicio>` exista.
4. Verificar método HTTP.
5. Validar autenticación con `Auth::validateRequest()`.
6. Construir la entrada del servicio (query string y cuerpo JSON/form).
7. Instanciar el servicio vía contenedor e invocar la acción.
8. Envolver el resultado en el contrato JSON.
9. Traducir excepciones a códigos HTTP y mensajes seguros.

### 6.3 Archivo `router_api.php`

```php
<?php

declare(strict_types=1);

use Dashboard\WServices\UsuariosService;

return [
    'usuarios' => [
        'service' => UsuariosService::class,
        'action' => 'handle',
        'method' => 'POST',
        'auth' => true,
    ],
];
```

Campos:

| Campo | Obligatorio | Descripción |
| --- | --- | --- |
| `service` | Sí | Clase FQCN del servicio en `wservices`. |
| `action` | No | Método a invocar. Por defecto `handle`. |
| `method` | No | Verbo HTTP permitido. Por defecto `POST`. |
| `auth` | No | `true` por defecto. `false` solo para servicios públicos explícitos. |

### 6.4 Servicios (`wservices`)

- Ubicación: `modules/<modulo>/wservices/<Nombre>Service.php`.
- Namespace: `<Modulo>\WServices`.
- Reciben dependencias por constructor (`Db`, `Cache`, `Auth`, `Logger`, etc.).
- Devuelven datos serializables (`array`, `object` simple, escalares). No escriben la respuesta HTTP ni renderizan HTML.
- Las reglas de validación de negocio viven aquí o en clases de dominio del módulo, no en el enrutador.
- Acceden a datos **solo mediante procedimientos almacenados** invocados a través de `Db`; no ejecutan SQL directo ni usan ORM.
- Declaran la conexión lógica de su módulo (`main`, `dashboard`, `ventas`, etc.).
- Si necesitan datos de otro módulo, llaman a su `wservice` por HTTP interno (`curl`), no a su base de datos.
- Detalle completo en [`base-de-datos.md`](base-de-datos.md).

---

## 7. Autenticación y autorización

### 7.1 Servicio `Auth`

`Auth` debe centralizar:

- `attempt(identificador, password): bool` — valida credenciales y crea la sesión.
- `check(): bool` — indica si hay usuario autenticado.
- `user(): ?array` — datos mínimos del usuario actual.
- `logout(): void` — destruye la sesión y regenera el identificador.
- `validateRequest(): bool` — valida las credenciales enviadas en una petición API.
- Emisión/validación de tokens si se adopta autenticación por token.

Reglas:

- Contraseñas almacenadas con `password_hash()` y verificadas con `password_verify()`.
- Los usuarios se crean sin contraseña: la definen en el primer acceso mediante un token enviado por correo; el mismo mecanismo sirve para recuperarla. Ver [`control-acceso.md`](control-acceso.md) §7.
- Además de la cookie de sesión, se emite un **token de acceso** por usuario que autentica las llamadas a los `wservices`. Un solo token vigente: iniciar sesión en otro dispositivo invalida el anterior.
- Se aplican políticas de largo, duración, historial de contraseñas e intentos fallidos definidas en `seguridad_parametros`; al superar los intentos, la cuenta se bloquea y se libera al recuperar la contraseña.
- El usuario puede activar/desactivar un **segundo factor (TOTP, app de autenticación)**; el administrador puede volverlo obligatorio. Con 2FA activo, el login no emite token de acceso hasta validar el código. Ver [`control-acceso.md`](control-acceso.md) §7.9.
- Regenerar el ID de sesión al iniciar sesión (`session_regenerate_id(true)`).
- Cookie de sesión con `HttpOnly`, `SameSite=Lax` y `Secure` en producción.
- No registrar contraseñas ni tokens en logs; los eventos de acceso van a `usuario_acceso_log`.
- La app es de orientación fuerte a auditoría: se registran accesos (`usuario_acceso_log`) y uso de opciones (`opcion_uso_log`).

### 7.2 Acceso en pantallas web

- Control por defecto en `App` antes de despachar la ruta.
- Sin sesión válida: `302` a `/system/login`, nunca un `401` HTML.
- Rutas públicas declaradas explícitamente en `router.php`.
- Login: `GET /system/login` muestra el formulario; `POST /system/login` procesa credenciales.
- Logout: `POST /system/logout` (con protección CSRF) destruye la sesión.
- Credenciales inválidas: volver a mostrar el formulario con mensaje genérico, sin revelar si el usuario existe.
- Autorización por roles: la estructura `app → módulo → carpeta → opción`, los roles y la relación usuario-rol viven en `app_db`. El acceso a cada opción se resuelve por los roles del usuario. Ver [`control-acceso.md`](control-acceso.md).
- El menú y el selector de módulos se construyen solo con el árbol autorizado del usuario.

### 7.3 Acceso en API

- Sin credenciales válidas: responder `401` con el contrato JSON. **Nunca redirigir al login.**
- Credenciales inválidas o expiradas: `401`.
- Usuario autenticado sin permiso para el recurso: `403`.
- El `wservice` verifica que el usuario tenga la opción asociada a la acción solicitada antes de ejecutar el procedimiento. Ver [`control-acceso.md`](control-acceso.md) §5.
- Propuesta inicial de transporte:
  - **Sesión web**: las llamadas `fetch` del mismo origen envían automáticamente la cookie de sesión. Para peticiones que modifican estado se exige token CSRF.
  - **Token de acceso**: el token vigente del usuario (`usuario_token_acceso`) autentica las llamadas a los `wservices`. Iniciar sesión en otro dispositivo lo renueva e invalida el anterior (`401`).
  - **Clientes externos**: envían `Authorization: Bearer <token>`.
- El formato del token (opaco almacenado en base de datos/Redis vs. JWT) queda como **decisión abierta** (§14). En cualquier caso, `Auth` es el único responsable de emitirlo y validarlo.
- No se habilita CORS abierto. Si se necesita, se configura una lista explícita de orígenes; nunca `*` junto con credenciales.

### 7.4 CSRF

- Formularios web: token CSRF en sesión y campo oculto.
- API con cookie de sesión: token CSRF en cabecera (`X-CSRF-Token`) para `POST`, `PUT`, `PATCH` y `DELETE`.
- API con `Authorization: Bearer`: no requiere CSRF, porque no depende de cookies.

---

## 8. Contrato de la API

### 8.1 Estructura

Toda respuesta, exitosa o no, usa exactamente tres claves:

```json
{
  "status": "ok",
  "message": "OK",
  "data": {}
}
```

- `status`: `"ok"` o `"error"`.
- `message`: texto legible para el cliente (en español).
- `data`: carga útil. En errores puede ser `null` o contener detalles estructurados (por ejemplo, errores de validación).

Encabezado obligatorio: `Content-Type: application/json; charset=utf-8`.

### 8.2 Ejemplos

Éxito:

```json
{
  "status": "ok",
  "message": "Usuarios obtenidos",
  "data": {
    "items": [],
    "total": 0
  }
}
```

Error de autenticación:

```json
{
  "status": "error",
  "message": "No autenticado",
  "data": null
}
```

Error de validación:

```json
{
  "status": "error",
  "message": "Datos inválidos",
  "data": {
    "errors": {
      "email": ["El correo es obligatorio"]
    }
  }
}
```

### 8.3 Códigos HTTP

| Código | Uso |
| --- | --- |
| `200` | Operación exitosa. |
| `201` | Recurso creado. |
| `400` | Petición mal formada. |
| `401` | No autenticado o credenciales inválidas. |
| `403` | Autenticado sin permiso. |
| `404` | Módulo, servicio o recurso inexistente. |
| `405` | Método HTTP no permitido. |
| `409` | Conflicto (por ejemplo, duplicado). |
| `422` | Datos inválidos. |
| `429` | Demasiadas peticiones (si se implementa límite). |
| `500` | Error interno no controlado. |

El código HTTP debe ser coherente con `status`; no se devuelve `200` con `status: "error"`.

### 8.4 Depuración

- `APP_DEBUG=true`: el mensaje y `data` pueden incluir detalles técnicos.
- `APP_DEBUG=false`: mensaje genérico y sin trazas, rutas internas ni credenciales.
- Los detalles completos siempre van al log, nunca a la respuesta en producción.

---

## 9. Datos, caché, logs y servicios de infraestructura

### 9.1 Base de datos (`Db`)

- `Db` es un **administrador de conexiones con nombre**, no una conexión única: `main` → `app_db`, `dashboard` → `app_db_dashboard`, etc.
- Cada conexión se crea de forma perezosa y se reutiliza durante la petición.
- `PDO::ATTR_ERRMODE = EXCEPTION` y `PDO::ATTR_EMULATE_PREPARES = false`.
- El acceso a datos se realiza **exclusivamente mediante procedimientos almacenados**; `Db` ejecuta la invocación y enlaza parámetros, pero no contiene lógica de negocio ni SQL de tablas.
- Los `wservices` son la única capa de negocio que invoca `Db` para datos. La autenticación se encapsula preferentemente en un `wservice` del módulo `system`; si `Auth` accede directamente a datos, solo puede usar procedimientos de autenticación de `app_db` (ver [`base-de-datos.md`](base-de-datos.md) §5.3).
- Toda tabla de negocio incluye `id`, `activo`, `eliminado`, `idusuario_actualizacion`, `fecha_hora_actualizacion`, `idusuario_eliminacion` y `fecha_hora_eliminacion`. No se ejecuta `DELETE`; las bajas son lógicas.
- Toda escritura registra `app_db.bitacora` en la misma transacción, con usuario, fecha/hora, tabla calificada, acción y snapshots antes/después.
- En los procedimientos, las tablas se referencian siempre como `<schema>.<tabla>`.
- Métodos de ayuda para transacciones cuando el procedimiento no las gestione.
- Los esquemas viven en `dev/sql/schemas/<basedatos>.sql` y los procedimientos en `dev/sql/procedures/<basedatos>/<procedimiento>.sql`.
- La aplicación debe funcionar sobre MySQL y MSSQL; las diferencias de sintaxis se aíslan en el adaptador de conexión y en los procedimientos.
- `make sql` actualmente aplica todos los esquemas sobre una sola base; debe adaptarse al modelo multi-base.

### 9.2 Caché (`Cache`)

- Redis como backend.
- Uso previsto: caché de datos, sesiones (a definir), rate limiting y datos temporales.
- Prefijo de claves por aplicación/entorno para evitar colisiones.

### 9.3 Logs (`Logger`)

- Destino: `files/logs/`.
- Niveles estándar (`debug`, `info`, `warning`, `error`, `critical`).
- Registrar errores no controlados, accesos denegados y eventos relevantes.
- No registrar secretos, contraseñas ni tokens.

### 9.4 Twig

- Instancia única en el contenedor.
- Autoescape activado.
- Caché en `files/cache/twig` en producción; desactivada o revalidada en desarrollo.
- Namespaces por módulo (`@admin`, `@dashboard`, `@system`) y espacio compartido (`@app` → `app/views/`).
- Layout compartido en `@app/layouts/app.html.twig`; parciales de shell y errores en `@app/partials/` y `@app/errors/`.
- Las vistas de módulo se renderizan como fragmentos o dentro del layout mediante `system\ScreenRenderer`.
- Variables globales mínimas: nombre de la app, usuario actual, ruta base y mensajes flash.

### 9.5 Otros servicios

- `Mail`: wrapper de PHPMailer.
- `Spread`: wrapper de PhpSpreadsheet para importación/exportación.
- `Config`: acceso centralizado; los controladores y servicios no deben llamar `getenv()` directamente.

---

## 10. Seguridad

- Validar y normalizar todos los segmentos de URL.
- No interpolar nombres de tabla, columna o procedimiento provenientes del cliente; usar listas blancas.
- Escapar toda salida HTML mediante Twig; no usar `|raw` sin justificación.
- No ejecutar SQL directo desde PHP: todo acceso a datos pasa por procedimientos almacenados con parámetros enlazados.
- Las bajas de negocio son lógicas (`eliminado`); la aplicación no ejecuta `DELETE`. Toda escritura deja bitácora con el usuario autenticado, nunca con un usuario informado por el cliente.
- Los snapshots de bitácora no incluyen contraseñas, tokens ni claves.
- Cada usuario de base de datos tiene permisos mínimos de ejecución sobre sus procedimientos; sin acceso directo a tablas.
- Regenerar sesión al autenticar y destruirla al cerrar sesión.
- Cookies `HttpOnly`, `SameSite=Lax`, `Secure` en producción.
- Protección CSRF en formularios y en API basada en cookies.
- Validar destinos de redirección internos.
- No exponer trazas ni configuración en producción.
- Limitar tamaño y tipo de archivos subidos; almacenar fuera del document root o con acceso controlado.
- Aplicar rate limiting a login y endpoints sensibles (deseable).
- Mantener `.env` fuera del repositorio; usar `.env.example` como plantilla.

---

## 11. Convenciones de nombres

| Elemento | Convención | Ejemplo |
| --- | --- | --- |
| Módulo (carpeta) | minúsculas | `modules/dashboard/` |
| Namespace de módulo | PascalCase | `Dashboard\` |
| Controlador | PascalCase + `Controller` | `UsuariosController` |
| Acción de controlador | camelCase | `index`, `detalle` |
| Servicio API | PascalCase + `Service` | `UsuariosService` |
| Vista | snake_case + `.html.twig` | `usuarios.html.twig` |
| Opción web | minúsculas, `[a-z0-9_-]` | `usuarios`, `lista-usuarios` |
| Servicio API | minúsculas, `[a-z0-9_-]` | `usuarios`, `reporte-ventas` |
| Base principal | `app_db` | — |
| Base de módulo | `app_db_<modulo>` | `app_db_ventas` |
| Procedimiento | `usp_<modulo>_<accion>` | `usp_ventas_documento_crear` |
| Tabla | snake_case | `documento` |
| Columna | snake_case | `fecha_hora_actualizacion` |
| Clave primaria | `id` autogenerado | `documento.id` |
| Estado activo | `activo` | — |
| Borrado lógico | `eliminado` | — |
| Auditoría de actualización | `idusuario_actualizacion`, `fecha_hora_actualizacion` | — |
| Auditoría de eliminación | `idusuario_eliminacion`, `fecha_hora_eliminacion` | — |
| Bitácora | `app_db.bitacora` | — |
| Tablas de acceso | `app`, `modulos`, `carpetas`, `opciones`, `roles`, `usuarios` | en `app_db` |

Los controladores y servicios deben declarar `strict_types=1` y seguir PSR-12 en la medida de lo posible.

---

## 12. Infraestructura y enrutamiento de nginx

- Document root: `public/`.
- `/` y rutas inexistentes se enrutan a `public/index.php` (comportamiento actual).
- **Ajuste requerido:** `/api/...` debe enrutarse a `public/api/index.php`; con la configuración actual, nginx lo envía a `/index.php`. Se propone:

```nginx
location /api/ {
    try_files $uri /api/index.php?$query_string;
}
```

- Los assets viven en `public/assets/` y se sirven directamente.
- No se debe permitir listado de directorios ni acceso a archivos ocultos (ya contemplado).
- El contenedor PHP debe tener permisos de escritura sobre `files/cache` y `files/logs` con el UID/GID del host.

---

## 13. Flujo completo de una pantalla con datos

1. El usuario navega a `/dashboard/usuarios`.
2. nginx envía la petición a `public/index.php`.
3. `App` ejecuta `Bootstrap` y obtiene el `Container`.
4. `App` verifica `Auth::check()`; si no hay sesión, redirige a `/system/login`.
5. `Router` resuelve `dashboard` + `usuarios` desde `modules/dashboard/router.php`.
6. Se instancia `Dashboard\Controllers\UsuariosController` y se ejecuta `index()`.
7. El controlador delega en `system\ScreenRenderer`, que renderiza `@app/layouts/app.html.twig` con `@dashboard/usuarios.html.twig` como fragmento inicial.
8. El navegador recibe el HTML completo del shell y ejecuta el JS de la aplicación. El cliente registra la URL actual en el historial y monta la pantalla.
9. La pantalla hace `fetch('/api/dashboard/usuarios', { method: 'POST', ... })`, enviando cookie de sesión y, si corresponde, token CSRF.
10. nginx envía `/api/...` a `public/api/index.php`.
11. `Api` ejecuta `Bootstrap`, resuelve `dashboard` + `usuarios` desde `router_api.php`, valida `Auth::validateRequest()` y llama a `UsuariosService`.
12. `UsuariosService` invoca el procedimiento correspondiente en `app_db_dashboard` a través de `Db`. Si necesita datos de otro módulo, llama a su `wservice` por HTTP interno, no a su base de datos.
13. El servicio devuelve los datos; `Api` responde con `{status, message, data}`.
14. El JS actualiza la pantalla. Si recibe `401`, redirige al login; si recibe error, muestra el mensaje.
15. Si el usuario elige otra opción del menú, el cliente solicita la misma URL con `X-App-Navigation: fragment`; el servidor devuelve solo la plantilla de la nueva pantalla, el cliente la inserta en el workspace y actualiza el historial. No se recarga el shell.

El detalle de conexiones, procedimientos y versionado SQL está en [`base-de-datos.md`](base-de-datos.md). El detalle del shell, fragmentos, historial y ciclo de vida de pantallas está en [`pantallas.md`](pantallas.md).

---

## 14. Decisiones abiertas

Estas decisiones deben resolverse antes o durante la implementación:

1. **Formato y transporte del token API**: token opaco en BD/Redis vs. JWT; aceptar cookie de sesión, Bearer o ambos.
2. **Nombre canónico de los archivos de rutas**: `router.php`/`router_api.php` (definición original) vs. `routes.php`/`routes_api.php` (esqueleto actual).
3. **Ruta inicial**: `dashboard/index` u otra; si se configura por `APP_HOME`.
4. **Almacenamiento de sesiones**: archivos locales vs. Redis.
5. **Ubicación del layout compartido**: se propone `app/views/` en [`pantallas.md`](pantallas.md); falta confirmarlo.
6. **Plantillas de error**: dónde viven `404`, `403` y `500`, y cómo se seleccionan.
7. **Parámetros de ruta**: si se admitirán en el futuro (`/<modulo>/<opcion>/<id>`) o solo query string.
8. **Contrato de paginación y filtros** para DataTables y listados.
9. **CSRF en API**: mecanismo exacto (token en sesión, doble cookie, etc.).
10. **Autowiring del contenedor**: factories explícitas vs. resolución automática por tipos.
11. **Pruebas y calidad**: PHPUnit, análisis estático, estilo de código y comando único de verificación.
12. **Rate limiting**: dónde se implementa (Redis/nginx) y con qué políticas.
13. **Navegación de pantallas**: comportamiento del selector de módulo, origen del menú, almacenamiento del estado e historial, y carga de JS por pantalla; ver [`pantallas.md`](pantallas.md) §15.

Las decisiones específicas de topología de bases, procedimientos y soporte multi-motor están en [`base-de-datos.md`](base-de-datos.md) §12.

---

## 15. Criterios de aceptación iniciales

- [ ] `/` muestra la pantalla inicial cuando hay sesión y redirige al login cuando no la hay.
- [ ] `/<modulo>/<opcion>` resuelve el controlador definido en `router.php` y renderiza la vista derivada.
- [ ] `/<modulo>/<opcion>` con `X-App-Navigation: fragment` devuelve solo la pantalla, sin layout.
- [ ] El menú carga pantallas en el workspace sin recargar el shell y actualiza la URL y el historial.
- [ ] Una URL directa con filtros abre el shell en la opción correcta y reconstruye la pantalla.
- [ ] Atrás/adelante restaura pantalla, filtros y posición de scroll.
- [ ] Un módulo u opción inexistente responde `404` (HTML en web).
- [ ] El contenedor devuelve la misma instancia para un servicio solicitado dos veces.
- [ ] El login crea sesión, regenera el ID y permite volver a la ruta solicitada.
- [ ] El logout destruye la sesión.
- [ ] `/api/<modulo>/<servicio>` resuelve el servicio definido en `router_api.php`.
- [ ] Toda respuesta API usa `{status, message, data}` y `Content-Type: application/json`.
- [ ] Sin credenciales válidas, la API responde `401` JSON y no redirige.
- [ ] Un error no controlado en API responde JSON sin HTML ni trazas en producción.
- [ ] Las rutas no permiten *path traversal* ni carga de archivos arbitrarios.
- [ ] nginx enruta `/api/...` a `public/api/index.php`.
- [ ] Cada módulo usa su conexión de base de datos y sus `wservices` solo invocan procedimientos almacenados.
- [ ] Ningún controlador, router o vista ejecuta SQL directo.
- [ ] Los esquemas y procedimientos están versionados en `dev/sql/schemas/` y `dev/sql/procedures/<basedatos>/`.
- [ ] El control de acceso (`app`, `modulos`, `carpetas`, `opciones`, `roles`, `usuarios`) vive en `app_db` y el menú/permisos se derivan de él.
- [ ] Los usuarios se crean sin contraseña y la definen en el primer acceso con un token enviado por correo; la recuperación usa el mismo mecanismo.
- [ ] El login renueva el token de acceso; iniciar sesión en otro dispositivo invalida el anterior con `401`.
- [ ] Se registran accesos (`usuario_acceso_log`) y uso de opciones (`opcion_uso_log`).
- [ ] El usuario puede activar/desactivar el segundo factor TOTP; el administrador puede exigirlo, y con 2FA activo el login valida el código antes de emitir el token.

---

## 16. Estado del esqueleto y pendientes

Análisis del repositorio al 2026-10-22:

- `app/core/App.php`, `app/core/Api.php`, `app/core/Bootstrap.php` están vacíos.
- `app/system/Auth.php`, `Cache.php`, `Config.php`, `Container.php`, `Db.php`, `Logger.php`, `Mail.php`, `Menu.php`, `Router.php`, `ScreenRenderer.php`, `Spread.php` están vacíos o no existen.
- `app/views/` (layout y parciales compartidos) todavía no existe.
- `public/index.php` actualmente es una página de diagnóstico que abre PDO directamente; no usa `App`.
- `public/api/index.php` está vacío.
- `modules/*/router.php`, `router_api.php` y `module.php` no existen; hay archivos vacíos `routes.php` y `routes_api.php`.
- Los directorios `modules/*/controllers`, `wservices` y `views` existen pero están vacíos.
- `public/assets/js/app.js` está vacío; no existe el cliente de navegación, historial ni ciclo de vida de pantallas.
- `composer.json` ya define PSR-4 para `App\`, `core\`, `system\` y los módulos `System`, `Admin` y `Dashboard`.
- `docker-compose.yml` levanta nginx, PHP-FPM 8.4, MySQL 8.4, Redis y phpMyAdmin.
- La configuración actual usa una sola base (`pr_db`); el modelo objetivo (`app_db` + bases por módulo) todavía no está implementado.
- `dev/sql/schemas/` solo contiene el fixture `demo_usuarios.sql`; no hay un script por base.
- `dev/sql/procedures/` existe vacío; no hay procedimientos versionados.
- `Db` será un administrador de conexiones múltiples; hoy no existe implementación.
- La imagen PHP incluye `pdo_mysql`, `curl`, `pdo_sqlsrv` 5.13.3 y Microsoft ODBC Driver 18 for SQL Server.
- La extensión no-PDO `sqlsrv` no está instalada; el acceso a MSSQL se hará por PDO.
- La configuración de nginx **no** enruta `/api/...` al front controller API; requiere el ajuste de §12.
- Existe material de ejemplo en `public/demo/` (DataTables con PDO directo) que no forma parte de la arquitectura objetivo.
- No hay suite de pruebas ni script `composer test` definido, aunque el `Makefile` expone `make test`.
- `.env` existe localmente y está ignorado por git; `.env.example` es la plantilla.
- El repositorio aún no está inicializado como repositorio git.

---

## 17. Próximos pasos sugeridos

1. Revisar y cerrar las decisiones abiertas de §14, de [`pantallas.md`](pantallas.md) §15 y de [`base-de-datos.md`](base-de-datos.md) §12.
2. Implementar `Container`, `Bootstrap`, `Config` y `Db` como administrador de conexiones múltiples.
3. Implementar `App`, `Router`, `ScreenRenderer` y el contrato de controladores/vistas.
4. Implementar el layout Twig, el menú lateral, el selector de módulos y el área de trabajo.
5. Implementar el cliente de navegación: fragmentos, `History API`, `popstate`, historial y ciclo de vida de pantallas.
6. Implementar `Api`, el contrato JSON y el ajuste de nginx.
7. Implementar `Auth` y las pantallas de login/logout.
8. Implementar el control de acceso en `app_db` (app, módulos, carpetas, opciones, roles, usuarios) según [`control-acceso.md`](control-acceso.md).
9. Definir `app_db` y las bases de módulo, sus scripts de esquema y sus primeros procedimientos.
10. Migrar el módulo `dashboard` como caso piloto (pantalla + servicio API + procedimiento).
11. Verificar en el build que `ext-curl`, `pdo_sqlsrv` y el driver ODBC 18 estén disponibles.
12. Incorporar pruebas y un comando único de verificación.
