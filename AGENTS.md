# AGENTS.md

Guía para agentes (humanos o IA) que trabajen en este repositorio.

## Fuente de verdad

La arquitectura objetivo está definida en [`dev/specs/arquitectura.md`](dev/specs/arquitectura.md), el modelo de datos en [`dev/specs/base-de-datos.md`](dev/specs/base-de-datos.md), el control de acceso en [`dev/specs/control-acceso.md`](dev/specs/control-acceso.md) y la interfaz/navegación en [`dev/specs/pantallas.md`](dev/specs/pantallas.md). **Léelos antes de implementar o cambiar el núcleo.** Si una decisión de diseño cambia, actualiza la especificación correspondiente en el mismo cambio.

El proyecto está en estado de esqueleto: varias clases del núcleo están vacías y la implementación todavía no existe. No asumas que el código actual refleja la arquitectura objetivo.

## Stack

- PHP 8.4 (runtime Docker; `composer.json` exige >=8.2)
- nginx + PHP-FPM
- MySQL 8.4 (objetivo: soportar también SQL Server / MSSQL)
- Redis 7
- Twig 3, PHPMailer, PhpSpreadsheet, phpdotenv
- Docker Compose + `Makefile`
- Front controllers: `public/index.php` (web) y `public/api/index.php` (API)
- Organización por módulos en `modules/`

## Comandos habituales

Todos los comandos se ejecutan desde la raíz del proyecto.

| Objetivo | Comando |
| --- | --- |
| Levantar el entorno | `make up` |
| Ver estado | `make ps` |
| Ver logs | `make logs` |
| Shell en PHP | `make shell` |
| URLs del proyecto | `make pma` |
| Aplicar esquemas SQL | `make sql-app` (crea/aplica `app_db`); `make sql` aplica sobre `pr_db` (heredado) |
| Aplicar procedimientos SQL | `make sql-procedures` (aplica `dev/sql/procedures/app_db/`) |
| Composer | `make composer ARGS="install"` |
| Instalar dependencias | `make install` |
| Actualizar dependencias | `make update` |
| Regenerar autoload | `make composer ARGS="dump-autoload"` |
| Verificar autoload | `make composer ARGS="check"` |
| Tests | `make test` (aún no hay script `test` definido) |
| Assets de terceros | `make assets` |

No ejecutes `make clean` ni borres `docker/mysql-data/` sin confirmación explícita: elimina los datos de todas las bases.

## Arquitectura en breve

1. `public/index.php` crea `core\App` y ejecuta `run()`.
2. `App` usa `core\Bootstrap` para cargar entorno/configuración y obtener el `system\Container` con instancias únicas.
3. `App` verifica `system\Auth` y delega en `system\Router`.
4. `Router` resuelve `/<modulo>/<opcion>` contra `modules/<modulo>/router.php` y ejecuta el controlador.
5. El controlador renderiza mediante `system\ScreenRenderer`: layout completo en carga directa o solo el fragmento si la petición trae `X-App-Navigation: fragment`.
6. La pantalla obtiene datos con `fetch('/api/<modulo>/<servicio>')`; la navegación entre opciones usa el mismo mecanismo de fragmentos y actualiza URL e historial sin recargar el shell.
7. `public/api/index.php` crea `core\Api`, que reutiliza el `Container`, valida `Auth`, resuelve `router_api.php` e invoca un servicio de `modules/<modulo>/wservices/`.
8. El `wservice` accede a su base de datos **solo mediante procedimientos almacenados** a través de `Db`. Si necesita datos de otro módulo, llama a su `wservice` por HTTP interno (`curl`).
9. La API responde siempre JSON con `{status, message, data}` y un código HTTP coherente.

## Reglas de trabajo

- **No pongas lógica de negocio en controladores ni routers.** Los controladores solo preparan la vista; los servicios API concentran la lógica.
- **No consultes la base de datos desde un controlador web.** Usa `fetch` contra la API.
- **Navegación sin recarga:** las opciones del menú cargan fragmentos HTML de `/<modulo>/<opcion>` con `X-App-Navigation: fragment`; `/api/...` sigue siendo exclusivamente JSON. Sigue el contrato de [`dev/specs/pantallas.md`](dev/specs/pantallas.md).
- **Usa el contenedor** para obtener `Db`, `Auth`, `Router`, Twig, `Cache`, `Logger`, etc. No instancies servicios compartidos con `new` dentro de controladores o servicios.
- **Seguro por defecto:** toda ruta y servicio requiere autenticación y autorización salvo que se declare `auth => false` explícitamente.
- **Control de acceso en base:** la estructura `app → módulo → carpeta → opción`, los roles y la relación usuario-rol viven en `app_db`. Los permisos se asignan a roles y se heredan hacia arriba (opción → carpeta → módulo). No mantengas listas paralelas de módulos, carpetas u opciones en el código. Ver [`dev/specs/control-acceso.md`](dev/specs/control-acceso.md).
- **Cuentas y contraseñas:** los usuarios se crean **sin contraseña**; la definen en el primer acceso mediante un token enviado por correo, y el mismo flujo sirve para recuperarla. Aplica las políticas de `seguridad_parametros` (largo, duración, historial, intentos). Nunca almacenes ni registres contraseñas o tokens en claro.
- **Token de acceso:** el login renueva un token de sesión único por usuario que autentica las llamadas a los `wservices`; iniciar sesión en otro dispositivo invalida el anterior (`401`).
- **Segundo factor:** el usuario puede activar/desactivar la autenticación por app (TOTP); el administrador puede volverla obligatoria. Con 2FA activo, el login no emite el token de acceso hasta validar el código. Guarda el secreto cifrado y los códigos de recuperación hasheados.
- **Auditoría:** registra eventos de acceso en `usuario_acceso_log` (incluye eventos de 2FA) y uso de opciones en `opcion_uso_log`. Ambos son de solo-anexado y no contienen secretos.
- **Contrato API:** toda respuesta usa `{status, message, data}`; nunca devuelvas HTML desde la API. Los errores también son JSON.
- **Solo procedimientos almacenados:** ningún archivo PHP ejecuta `SELECT`, `INSERT`, `UPDATE`, `DELETE` ni DDL. Los `wservices` invocan procedimientos a través de `Db` con parámetros enlazados.
- **Bases por módulo:** la principal es `app_db`; cada módulo usa `app_db_<modulo>` a través de su conexión lógica. No consultes tablas de otro módulo; usa su `wservice`.
- **Registro estándar:** toda tabla de negocio incluye `id`, `activo`, `eliminado`, `idusuario_actualizacion`, `fecha_hora_actualizacion`, `idusuario_eliminacion` y `fecha_hora_eliminacion`. No se ejecuta `DELETE`; las bajas son lógicas con `UPDATE` y solo se restauran mediante un procedimiento explícito.
- **Bitácora obligatoria:** cada `INSERT`, `UPDATE`, baja lógica o restauración deja un registro en `app_db.bitacora` con usuario, fecha/hora, tabla calificada, tipo de acción y snapshots antes/después. La bitácora se escribe en la misma transacción que el cambio y la aplicación no accede a la tabla directamente.
- **Nombres calificados:** en los procedimientos, toda tabla se referencia como `<schema>.<tabla>`, incluso dentro de la misma base. No dependas del esquema por defecto.
- **Nombres de procedimientos:** valida contra lista blanca/patrón; nunca construyas SQL ni nombres con datos del cliente. Nomenclatura propuesta: `usp_<modulo>_<accion>`.
- **Equipo de base de datos:** los procedimientos los diseña y entrega el encargado de BD. No los inventes en la aplicación; solicita el procedimiento y documenta su contrato.
- **Versionado SQL:** todo cambio de esquema o procedimiento debe reflejarse en `dev/sql/schemas/<basedatos>.sql` o `dev/sql/procedures/<basedatos>/<procedimiento>.sql` y versionarse en Git. No dejes cambios solo en la base.
- **Multi-motor:** el código de aplicación no debe contener sintaxis específica de MySQL o MSSQL; las diferencias viven en el adaptador de `Db` y en los procedimientos.
- **Llamadas entre módulos:** usa HTTP interno tipo `curl` contra el `wservice` del otro módulo, con autenticación, timeout y manejo de errores. No accedas a su base de datos.
- **Autenticación:** el acceso a datos de autenticación debe pasar por el `wservice` del módulo `system`; si `Auth` lo hace directamente, solo puede usar procedimientos de `app_db` y nunca consultar tablas.
- **Escapado:** deja el autoescape de Twig activo; evita `|raw` salvo necesidad justificada.
- **Validación de rutas:** módulo, opción y servicio deben cumplir `^[a-z][a-z0-9_-]*$`. No construyas rutas de archivo con segmentos sin validar.
- **Secretos:** no agregues credenciales, tokens ni claves al repositorio. Usa `.env` (ignorado) y documenta nuevas variables en `.env.example`.
- **Dependencias:** no edites `vendor/`; usa Composer. No agregues librerías nuevas sin necesidad clara.
- **Idioma:** documentación, mensajes de UI y comentarios existentes están en español; mantén esa consistencia.
- **Alcance:** evita refactorizaciones amplias no solicitadas. Prefiere cambios pequeños y verificables.
- **Git:** no hagas commit, push ni cambios de historial salvo pedido explícito.

## Cómo agregar un módulo

1. Crear `modules/<modulo>/` con `controllers/`, `wservices/`, `views/`, `router.php`, `router_api.php` y `module.php`.
2. Agregar los namespaces PSR-4 en `composer.json`:
   - `<Modulo>\` → `modules/<modulo>/`
   - `<Modulo>\Controllers\` → `modules/<modulo>/controllers/`
   - `<Modulo>\WServices\` → `modules/<modulo>/wservices/`
3. Ejecutar `make composer ARGS="dump-autoload"`.
4. Declarar las rutas web en `router.php` (con `title`, `permission` y metadatos `menu` cuando corresponda) y las rutas API en `router_api.php`.
5. Registrar el módulo y sus opciones en la estructura de acceso de `app_db` (`modulos`, `carpetas`, `opciones`) y asignarlos a los roles correspondientes. Los metadatos de `router.php`/`module.php` son transitorios hasta que el control de acceso en base esté implementado; ver [`dev/specs/control-acceso.md`](dev/specs/control-acceso.md).
6. Crear el controlador y su vista con el mismo nombre base (`UsuariosController` → `usuarios.html.twig`).
7. Definir con el encargado de BD la base `app_db_<modulo>`, su script en `dev/sql/schemas/` y los procedimientos en `dev/sql/procedures/app_db_<modulo>/`.
8. Crear el servicio API, invocar solo procedimientos a través de `Db` y devolver datos serializables; no escribir la respuesta HTTP desde el servicio.
9. Probar el flujo completo: pantalla → `fetch` → API → `wservice` → procedimiento → JSON → pantalla, y la navegación por fragmento → historial → restauración.
10. Actualizar `dev/specs/arquitectura.md`, `dev/specs/base-de-datos.md`, `dev/specs/control-acceso.md` y `dev/specs/pantallas.md` si el módulo introduce decisiones nuevas.

> Nota: el esqueleto actual usa `routes.php`/`routes_api.php` vacíos. La especificación propone renombrarlos a `router.php`/`router_api.php`. Confirma la decisión antes de mezclar ambos nombres.

## Cómo agregar o modificar datos

1. Documenta el requerimiento de datos para el encargado de BD (entradas, salidas, errores, reglas, activación/desactivación y si permite restauración).
2. Actualiza el esquema en `dev/sql/schemas/<basedatos>.sql` si cambian tablas o índices, incluyendo las columnas estándar y el borrado lógico.
3. Agrega o modifica **un archivo por procedimiento** en `dev/sql/procedures/<basedatos>/<procedimiento>.sql`; toda tabla debe estar calificada y toda escritura debe registrar bitácora.
4. Aplica el procedimiento a la base correspondiente y pruébalo con datos de desarrollo, incluyendo insert, update, baja lógica y restauración cuando aplique.
5. Invócalo desde el `wservice` usando `Db` y parámetros enlazados. No escribas SQL en PHP.
6. Comprueba que el cambio y su bitácora se confirmen o reviertan juntos.
7. Versiona los archivos en Git; nunca dejes el cambio solo en la base de datos.
8. Si el procedimiento necesita otra base, que lo defina el encargado de BD o resuélvelo con una llamada al `wservice` del otro módulo.

## Cómo agregar una pantalla y su servicio API

- Pantalla: ruta en `router.php` → controlador en `controllers/` → vista Twig en `views/`.
- Menú: se construye en servidor con el árbol autorizado del usuario (módulos, carpetas y opciones concedidos por sus roles en `app_db`); no construyas el menú solo en JS. Hasta que el control de acceso en base esté implementado, la ruta puede declarar `menu`/`permission` como referencia transitoria. Ver [`dev/specs/control-acceso.md`](dev/specs/control-acceso.md).
- Toda opción debe existir en `app_db` (`opciones` dentro de una `carpeta` de un `modulo`) y estar concedida a algún rol del usuario para ser accesible.
- La vista es un fragmento con un único raíz `<section class="app-screen" data-screen-id="<modulo>/<opcion>">`; no incluyas `<html>`, `<body>`, scripts ni estilos inline.
- La misma URL debe funcionar en carga completa y con `X-App-Navigation: fragment`; `system\ScreenRenderer` decide el modo.
- Datos: ruta en `router_api.php` → servicio en `wservices/` → respuesta envuelta por `Api`.
- La ruta API es `/<modulo>/<servicio>` precedida por `/api` en la URL final: `/api/<modulo>/<servicio>`.
- Si la pantalla usa DataTables, el servicio debe respetar el contrato de paginación/búsqueda que se defina en la especificación.
- Si la pantalla guarda estado o inicializa componentes, registra su ciclo de vida (`mount`, `unmount`, `serialize`, `restore`, `canLeave`) según [`dev/specs/pantallas.md`](dev/specs/pantallas.md).
- No dupliques la lógica de autorización en la vista; `App`/`Api` la aplican antes de ejecutar.

## Convenciones

| Elemento | Convención | Ejemplo |
| --- | --- | --- |
| Módulo | minúsculas | `dashboard` |
| Namespace | PascalCase | `Dashboard\` |
| Controlador | PascalCase + `Controller` | `UsuariosController` |
| Servicio API | PascalCase + `Service` | `UsuariosService` |
| Vista | snake_case + `.html.twig` | `usuarios.html.twig` |
| Pantalla | `<section class="app-screen">` | `data-screen-id="dashboard/usuarios"` |
| Layout compartido | `@app` → `app/views/` | `@app/layouts/app.html.twig` |
| Metadatos de módulo | `module.php` | `modules/dashboard/module.php` |
| Ruta web | `/<modulo>/<opcion>` | `/dashboard/usuarios` |
| Ruta API | `/api/<modulo>/<servicio>` | `/api/dashboard/usuarios` |
| Base principal | `app_db` | — |
| Base de módulo | `app_db_<modulo>` | `app_db_ventas` |
| Procedimiento | `usp_<modulo>_<accion>` | `usp_ventas_documento_crear` |
| Clave primaria | `id` autogenerado | `documento.id` |
| Estado activo | `activo` | — |
| Borrado lógico | `eliminado` | — |
| Auditoría de actualización | `idusuario_actualizacion`, `fecha_hora_actualizacion` | — |
| Auditoría de eliminación | `idusuario_eliminacion`, `fecha_hora_eliminacion` | — |
| Bitácora | `app_db.bitacora` | — |
| Tablas de acceso | `app`, `modulos`, `carpetas`, `opciones`, `roles`, `usuarios` | en `app_db` |
| Módulo (acceso) | `modulo_nombre` = carpeta + segmento URL | `dashboard` |
| Carpeta (acceso) | `carpeta_nombre`, `carpeta_orden` (varchar) | — |
| Opción (acceso) | `opcion_nombre`, `opcion_call`, `opcion_orden` | — |

Usa `declare(strict_types=1);` en archivos PHP nuevos y sigue PSR-12.

## Estado actual y trampas conocidas

- `app/core/*` y `app/system/*` están vacíos.
- `app/views/` (layout y parciales compartidos) todavía no existe.
- `public/index.php` es una página de diagnóstico con PDO directo; no es la implementación objetivo.
- `public/api/index.php` está vacío.
- Los archivos de rutas de módulos están vacíos y con el nombre `routes*.php`; no existen `module.php` ni metadatos de menú.
- `public/assets/js/app.js` está vacío; no hay cliente de navegación, historial ni ciclo de vida de pantallas.
- No existe la estructura de control de acceso en el código ni la aplicación apunta a `app_db`; el esquema ya existe en `dev/sql/schemas/app_db.sql`.
- La configuración actual usa una sola base (`pr_db`); el objetivo es `app_db` + `app_db_<modulo>`.
- `dev/sql/schemas/app_db.sql` ya define las tablas de `app_db` (acceso, seguridad, 2FA, logs y bitácora) con columnas estándar; `make sql-app` lo aplica. Los procedimientos de `dev/sql/procedures/app_db/` aún no existen.
- `dev/sql/procedures/` está vacío; todavía no hay procedimientos versionados.
- `app_db.bitacora` ya está definida en el esquema; falta el procedimiento central de registro y los procedimientos de escritura.
- `Db` aún no existe como administrador de conexiones múltiples.
- La imagen PHP incluye `pdo_mysql`, `curl`, `pdo_sqlsrv` 5.13.3 y Microsoft ODBC Driver 18 for SQL Server; no incluye la extensión no-PDO `sqlsrv`.
- nginx **no** enruta `/api/...` a `public/api/index.php` todavía. Antes de implementar la API hay que agregar la regla indicada en la especificación (§12).
- `public/demo/` es material de ejemplo; no lo tomes como patrón de arquitectura.
- No hay suite de tests ni script `composer test`; `make test` fallará hasta que se implemente.
- El directorio no está inicializado como repositorio git en este entorno.

## Verificación antes de terminar

1. Revisar que el cambio respeta la especificación.
2. Si cambió el modelo o un procedimiento, verificar que el archivo en `dev/sql/` esté actualizado y aplicado a la base correspondiente.
3. Verificar que las tablas incluyan las columnas estándar, que la baja sea lógica y que toda escritura deje bitácora con los snapshots correctos.
4. Verificar que todos los procedimientos referencien las tablas como `<schema>.<tabla>`.
5. Ejecutar `make composer ARGS="check"` (autoload) y, si existe, el comando de tests/lint correspondiente.
6. Probar el flujo afectado en `http://localhost:<HTTP_PORT>` (`make pma` muestra las URLs).
7. Probar carga completa, fragmento (`X-App-Navigation: fragment`), URL directa con filtros, atrás/adelante y restauración de estado.
8. Revisar logs si hay errores: `make logs`.
7. No dejar archivos temporales, credenciales ni datos de prueba en el repositorio.
