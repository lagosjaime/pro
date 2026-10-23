# pr

Aplicación web modular en PHP con pantallas Twig y una API interna en JSON.

El proyecto está **en construcción**: la arquitectura objetivo está definida en [`dev/specs/arquitectura.md`](dev/specs/arquitectura.md), el modelo de datos en [`dev/specs/base-de-datos.md`](dev/specs/base-de-datos.md), el control de acceso en [`dev/specs/control-acceso.md`](dev/specs/control-acceso.md) y la interfaz/navegación en [`dev/specs/pantallas.md`](dev/specs/pantallas.md), pero varias clases del núcleo todavía están vacías. El `public/index.php` actual es una página de diagnóstico, no la aplicación final.

## Stack

| Componente | Versión / tecnología |
| --- | --- |
| PHP | 8.4 en Docker (`composer.json` exige >=8.2) |
| Servidor web | nginx + PHP-FPM |
| Base de datos | MySQL 8.4 (objetivo: soportar también SQL Server / MSSQL) |
| Caché | Redis 7 |
| Plantillas | Twig 3 |
| Correo | PHPMailer |
| Hojas de cálculo | PhpSpreadsheet |
| Entorno | Docker Compose |
| Autoload | Composer PSR-4 |

## Requisitos

- Docker
- Docker Compose
- GNU Make

## Inicio rápido

```bash
cp .env.example .env
# Edita .env y cambia las claves por defecto si corresponde

make up
make install
make sql        # opcional: hoy aplica dev/sql/schemas sobre una sola base
make pma        # muestra las URLs del proyecto
```

Aplicación: <http://localhost:8080>

phpMyAdmin: <http://localhost:8081>

Los puertos se configuran con `HTTP_PORT`, `PHPMYADMIN_PORT` y `MYSQL_PORT` en `.env`.

Para detener el entorno:

```bash
make down
```

> `make clean` elimina los contenedores y **borra los datos de MySQL** (`docker/mysql-data/`). Úsalo solo si estás seguro.

## Arquitectura

La aplicación tiene dos puntos de entrada:

- **Web:** `public/index.php` crea `core\App`.
- **API:** `public/api/index.php` crea `core\Api`.

Flujo resumido:

```text
Navegador
   │
   ├── GET /<modulo>/<opcion>
   │       └── public/index.php → App → Bootstrap → Container
   │               → Auth → Router → modules/<modulo>/router.php
   │               → Controller → ScreenRenderer → Twig
   │                   → carga completa: @app/layouts/app.html.twig + fragmento
   │                   → navegación: solo modules/<modulo>/views/<vista>
   │
   └── fetch('/api/<modulo>/<servicio>')
           └── public/api/index.php → Api → Bootstrap → Container
                   → Auth → Router → modules/<modulo>/router_api.php
                   → WService (modules/<modulo>/wservices)
                   → Db → procedimiento almacenado (app_db_<modulo>)
                   → JSON {status, message, data}
```

Si un `wservice` necesita datos de otro módulo, lo consulta por HTTP interno tipo `curl` contra el `wservice` de ese módulo; nunca accede directamente a su base de datos.

Principios:

- `Bootstrap` carga el entorno, la configuración y el `Container` con instancias únicas.
- Los módulos viven en `modules/<modulo>/` y agrupan controladores, servicios API, vistas y rutas.
- Los controladores web no consultan la base de datos; las pantallas obtienen datos con `fetch` contra la API.
- El shell se renderiza una vez; las opciones cargan fragmentos HTML con `X-App-Navigation: fragment` y actualizan URL e historial sin recargar la página.
- La API siempre responde JSON con `{status, message, data}` y un código HTTP coherente; nunca devuelve HTML.
- Toda ruta y servicio requiere autenticación y autorización por defecto, salvo declaración explícita.
- El control de acceso vive en `app_db`: la estructura `app → módulo → carpeta → opción`, los roles y la relación usuario-rol. El menú y los permisos se derivan de ella.
- Los servicios API concentran la lógica de negocio; los controladores solo preparan la vista.
- Los `wservices` acceden a datos únicamente mediante procedimientos almacenados; no ejecutan SQL directo.
- La aplicación se diseña para funcionar sobre MySQL o MSSQL; las diferencias se aíslan en `Db` y en los procedimientos.

## Bases de datos

- La base principal es `app_db`.
- Cada módulo usa su propia base: `app_db_dashboard`, `app_db_ventas`, `app_db_existencias`, etc.
- Toda tabla de negocio tiene `id`, `activo`, `eliminado` y los campos de usuario/fecha de actualización y eliminación.
- No hay borrado físico: las bajas son lógicas y solo se restauran mediante un procedimiento explícito.
- Cada `INSERT`, `UPDATE`, baja lógica o restauración registra usuario, fecha/hora, tabla, acción y datos antes/después en `app_db.bitacora`, dentro de la misma transacción.
- En los procedimientos, toda tabla se referencia como `<schema>.<tabla>`, incluso dentro de la misma base.
- Los `wservices` son la única capa de negocio que accede a datos, y lo hacen solo mediante procedimientos almacenados.
- El encargado de base de datos diseña y entrega los procedimientos a partir de los requerimientos de la aplicación.
- Las llamadas entre módulos se hacen por HTTP interno (`curl`), no consultando la base de otro módulo.
- Los esquemas se versionan en `dev/sql/schemas/<basedatos>.sql`.
- Los procedimientos se versionan uno por archivo en `dev/sql/procedures/<basedatos>/<procedimiento>.sql`.

> Estado actual: el entorno local todavía usa una sola base (`pr_db`) y no hay procedimientos implementados. La migración a `app_db` + `app_db_<modulo>` está pendiente.

## Estructura

```text
app/
├── core/       # App, Api y Bootstrap
├── system/     # Container, Config, Db, Auth, Router, ScreenRenderer, Menu, Cache, Logger, Mail, Spread
└── views/      # Layout y parciales compartidos (@app)
modules/
├── admin/
├── dashboard/
└── system/
    ├── controllers/
    ├── wservices/
    ├── views/
    ├── module.php
    ├── router.php
    └── router_api.php
public/
├── index.php   # Front controller web
├── api/        # Front controller API
├── assets/
└── demo/       # Material de ejemplo, no forma parte del núcleo
dev/
├── specs/      # Especificaciones de arquitectura, pantallas y datos
├── sql/
│   ├── schemas/     # Un script de generación por base de datos
│   └── procedures/  # Un archivo por procedimiento, agrupado por base
└── scripts/
files/
├── cache/
└── logs/
```

## Comandos

| Objetivo | Comando |
| --- | --- |
| Levantar el entorno | `make up` |
| Detener el entorno | `make down` |
| Ver estado | `make ps` |
| Ver logs | `make logs` |
| Shell en PHP | `make shell` |
| URLs del proyecto | `make pma` |
| Instalar dependencias | `make install` |
| Actualizar dependencias | `make update` |
| Ejecutar Composer | `make composer ARGS="dump-autoload"` |
| Aplicar esquemas SQL | `make sql-app` (crea/aplica `app_db`) |
| Aplicar procedimientos SQL | `make sql-procedures` |
| Consola MySQL | `make db` |
| Consola Redis | `make redis` |
| Actualizar assets de terceros | `make assets` |
| Tests | `make test` (pendiente: aún no hay suite) |

## Documentación

- [`dev/specs/arquitectura.md`](dev/specs/arquitectura.md): arquitectura, rutas, API y autenticación.
- [`dev/specs/control-acceso.md`](dev/specs/control-acceso.md): estructura app/módulos/carpetas/opciones, roles, usuarios y evaluación de permisos.
- [`dev/specs/pantallas.md`](dev/specs/pantallas.md): shell, layout Twig, menú, navegación por fragmentos, historial y ciclo de vida de pantallas.
- [`dev/specs/base-de-datos.md`](dev/specs/base-de-datos.md): bases por módulo, procedimientos, multi-motor y versionado SQL.
- [`AGENTS.md`](AGENTS.md): convenciones y reglas de trabajo para agentes que modifiquen el repositorio.
- [`dev/sql/schemas/`](dev/sql/schemas/): scripts de generación de cada base.
- `dev/sql/procedures/<basedatos>/`: procedimientos almacenados versionados.

## Estado actual

- [x] Entorno Docker (nginx, PHP-FPM, MySQL, Redis, phpMyAdmin).
- [x] Autoload PSR-4 para el núcleo y los módulos.
- [x] Estructura de módulos y assets base.
- [ ] `App`, `Api`, `Bootstrap`, `Container`, `Router`, `Auth` y demás servicios del núcleo.
- [ ] `ScreenRenderer`, layout Twig, menú lateral y selector de módulos.
- [ ] Cliente de navegación por fragmentos, historial y ciclo de vida de pantallas.
- [ ] `Db` como administrador de conexiones múltiples.
- [x] Base `app_db` con esquema en `dev/sql/schemas/app_db.sql` (`make sql-app`).
- [ ] Bases `app_db_<modulo>` con scripts en `dev/sql/schemas/`.
- [x] Columnas estándar de registro, borrado lógico y bitácora central `app_db.bitacora` en el esquema.
- [ ] Procedimientos almacenados versionados en `dev/sql/procedures/<basedatos>/`.
- [ ] Pantallas y servicios del módulo `dashboard`.
- [ ] Login y control de acceso (estructura `app`, `modulos`, `carpetas`, `opciones`, `roles`, `usuarios` en `app_db`).
- [ ] Cuentas sin contraseña inicial, definición/recuperación por token de correo y segundo factor (TOTP) opcional.
- [ ] Enrutamiento de `/api/...` en nginx hacia `public/api/index.php`.
- [x] Extensiones `curl` y `pdo_sqlsrv` con Microsoft ODBC Driver 18 for SQL Server.
- [ ] Adaptador `Db` y configuración de conexión MSSQL.
- [ ] Suite de pruebas y comando único de verificación.

## Seguridad

- No subas `.env` al repositorio; usa `.env.example` como plantilla.
- Cambia las contraseñas por defecto antes de exponer la aplicación fuera de local.
- Protege el secreto TOTP y los códigos de recuperación del 2FA; nunca los registres ni los expongas.
- En producción usa `APP_DEBUG=false`, cookies seguras y HTTPS.
- Los usuarios de base de datos deben tener permisos mínimos de ejecución sobre procedimientos, sin acceso directo a tablas.
- No ejecutes SQL directo desde PHP; todo acceso a datos pasa por procedimientos almacenados.
- No edites `vendor/`; gestiona las dependencias con Composer.

## Licencia

MIT (ver `composer.json`).
