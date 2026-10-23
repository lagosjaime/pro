# Especificación de datos, conexiones y procedimientos — Aplicación `pr`

| Campo | Valor |
| --- | --- |
| Versión | 0.2 (borrador) |
| Fecha | 2026-10-22 |
| Estado | Para revisión y refinamiento |
| Alcance | Topología de bases de datos, convenciones de tablas, borrado lógico, bitácora, acceso a datos, procedimientos almacenados, soporte multi-motor y versionado SQL |
| Documentos relacionados | [`arquitectura.md`](arquitectura.md), [`control-acceso.md`](control-acceso.md), [`README.md`](../../README.md), [`AGENTS.md`](../../AGENTS.md) |

> Este documento complementa [`arquitectura.md`](arquitectura.md). Define cómo se organizan las bases de datos y cómo accede la aplicación a los datos. Si una decisión cambia, ambos documentos deben actualizarse.

---

## 1. Objetivo

Establecer un esquema de trabajo de datos que permita:

- Separar los datos por módulo mediante **bases de datos independientes**.
- Mantener una base principal (`app_db`) para los datos transversales del sistema.
- Desacoplar la aplicación del motor de base de datos (**MySQL** y **MSSQL**).
- Concentrar el acceso a datos en los `wservices` y, dentro de ellos, **solo en procedimientos almacenados**.
- Permitir que el encargado de base de datos reciba requerimientos, diseñe procedimientos y los entregue versionados.
- Mantener el esquema y los procedimientos bajo control de versiones en Git.

---

## 2. Principios

1. **Una base de datos por módulo.** La base principal es `app_db`; cada módulo funcional tiene su propia base (`app_db_dashboard`, `app_db_ventas`, `app_db_existencias`, etc.).
2. **Cada base tiene su modelo.** Cada módulo es dueño de sus tablas y de las reglas de integridad de sus datos.
3. **Bases interconectadas lógicamente.** Los módulos se relacionan mediante identificadores estables y contratos de datos, no mediante acceso directo a tablas ajenas desde la aplicación.
4. **Solo los `wservices` acceden a datos de negocio.** Ni controladores, ni routers, ni vistas, ni Twig consultan la base de datos.
5. **Solo procedimientos almacenados.** Los `wservices` no ejecutan `SELECT`, `INSERT`, `UPDATE` ni `DELETE` directamente: invocan procedimientos existentes.
6. **El motor es un detalle de infraestructura.** La aplicación no debe depender de sintaxis específica de MySQL o MSSQL; los procedimientos y el adaptador de conexión absorben esas diferencias.
7. **El equipo de base de datos es dueño de los procedimientos.** La aplicación consume procedimientos; no los genera ni los modifica en tiempo de ejecución.
8. **Todo cambio de datos se versiona.** El esquema de cada base y cada procedimiento tienen un archivo fuente en el repositorio.
9. **Mínimo privilegio.** El usuario de base de datos de la aplicación solo puede ejecutar los procedimientos que necesita; no tiene permisos directos sobre tablas.
10. **Las llamadas entre módulos son por servicio.** Si un módulo necesita datos de otro, lo hace a través de su `wservice` (llamada HTTP interna tipo `curl`), no consultando su base de datos.
11. **Registro estándar y borrado lógico.** Toda tabla de negocio tiene `id`, estado activo, marca de eliminación y campos de auditoría de actualización/eliminación. No se eliminan filas físicamente desde la aplicación.
12. **Toda modificación deja bitácora.** Cada `INSERT`, `UPDATE` o eliminación lógica registra usuario, fecha y hora, tabla afectada, tipo de acción y los datos antes/después que correspondan.
13. **Nombres de tabla siempre calificados.** En los procedimientos, toda referencia a una tabla se escribe como `<schema>.<tabla>`, incluso si pertenece al mismo esquema que el procedimiento.

> **Terminología:** en este documento se usa «base de datos» para referirse a `app_db`, `app_db_dashboard`, etc. En MySQL, un *schema* equivale a una base de datos. En SQL Server, en cambio, una base de datos contiene varios *schemas*; la separación propuesta se implementará como bases de datos distintas.

---

## 3. Topología de bases de datos

### 3.1 Base principal

`app_db` concentra los datos transversales del sistema:

- Usuarios, credenciales, roles y permisos.
- Estructura de control de acceso: `app`, `modulos`, `carpetas`, `opciones`, `roles`, `usuarios` (ver [`control-acceso.md`](control-acceso.md)).
- Configuración global y parámetros del sistema.
- Catálogos compartidos.
- Auditoría transversal: bitácora central de cambios.
- Datos de autenticación y sesión que el equipo decida persistir.

### 3.2 Bases por módulo

| Base de datos | Módulo / propósito | Contenido esperado |
| --- | --- | --- |
| `app_db` | Núcleo / sistema | Usuarios, roles, permisos, estructura de acceso, configuración, catálogos compartidos y bitácora central |
| `app_db_dashboard` | `dashboard` | Datos y agregados propios del tablero |
| `app_db_ventas` | `ventas` | Ventas, documentos, clientes y datos comerciales |
| `app_db_existencias` | `existencias` | Inventario, bodegas, movimientos y stock |
| `app_db_<modulo>` | Cualquier módulo nuevo | Datos del módulo |

`system` usa `app_db` porque concentra autenticación, usuarios y configuración. `admin` puede usar `app_db` si solo administra usuarios/roles, o `app_db_admin` si tiene datos propios; se define al implementarlo.

Reglas de nomenclatura:

- Base principal: `app_db`.
- Base de módulo: `app_db_<modulo>`, con `<modulo>` en minúsculas y guiones bajos.
- Si un módulo necesita más de una base, se documenta explícitamente y se usa un sufijo descriptivo (`app_db_ventas_historico`, por ejemplo).
- El nombre lógico de la conexión puede ser más corto (`main`, `dashboard`, `ventas`, `existencias`) y se mapea a la base física en configuración.

### 3.3 Conexiones

La aplicación no usa una única conexión global. `Db` es un **administrador de conexiones con nombre**:

- `main` → `app_db`
- `dashboard` → `app_db_dashboard`
- `ventas` → `app_db_ventas`
- `existencias` → `app_db_existencias`

Cada `wservice` declara la conexión que necesita (por constructor o en la definición de su ruta). Las conexiones se crean de forma perezosa y se reutilizan durante la petición. La aplicación no deduce la conexión a partir de datos del cliente.

Propuesta de configuración por entorno:

```dotenv
DB_DRIVER=mysql
DB_HOST=mysql
DB_PORT=3306

DB_MAIN_DATABASE=app_db
DB_MAIN_USERNAME=app_main
DB_MAIN_PASSWORD=cambia-esta-clave

DB_DASHBOARD_DATABASE=app_db_dashboard
DB_DASHBOARD_USERNAME=app_dashboard
DB_DASHBOARD_PASSWORD=cambia-esta-clave

DB_VENTAS_DATABASE=app_db_ventas
DB_VENTAS_USERNAME=app_ventas
DB_VENTAS_PASSWORD=cambia-esta-clave

DB_EXISTENCIAS_DATABASE=app_db_existencias
DB_EXISTENCIAS_USERNAME=app_existencias
DB_EXISTENCIAS_PASSWORD=cambia-esta-clave
```

- Los nombres exactos de las variables quedan como **decisión abierta** (§12).
- No se deben hardcodear credenciales ni nombres de bases en el código.
- Cada conexión puede usar un usuario distinto con permisos limitados a su base.
- La configuración actual del proyecto usa una sola base (`pr_db`) y aún no implementa múltiples conexiones.

---

## 4. Modelo e interconexión entre bases

### 4.1 Propiedad del dato

- Cada base es dueña de sus tablas. Ningún módulo escribe directamente en tablas de otra base.
- Las relaciones entre módulos se expresan mediante identificadores (`usuario_id`, `venta_id`, `producto_id`, etc.) y contratos de datos.
- `app_db` es la fuente de verdad para usuarios, roles y permisos. Las bases de módulo pueden guardar referencias lógicas a esos identificadores.

### 4.2 Integridad referencial

- Se prefieren claves foráneas **dentro de la misma base**, donde el motor las soporte de forma estándar.
- Las referencias entre bases distintas se manejan como **integridad lógica**, validada por procedimientos o por servicios.
- No se deben crear claves foráneas entre bases distintas como regla general: MySQL y SQL Server no las tratan igual y reducen la portabilidad.
- Si el equipo decide usarlas en un motor específico, debe documentarlo y aislarlo del resto de la aplicación.

### 4.3 Acceso entre módulos

Hay dos mecanismos permitidos, según el caso:

1. **Llamada a otro `wservice`** (preferido para flujos de negocio): un servicio del módulo A llama por HTTP interno al servicio del módulo B usando el contrato JSON. No accede a la base de B.
2. **Procedimiento de integración diseñado por el equipo de base de datos**: un procedimiento puede leer datos de otra base del mismo motor, siempre que el equipo de base de datos lo haya definido, documentado y autorizado. La aplicación no arma estas consultas.

Regla: la aplicación **nunca** ejecuta un `JOIN` directo entre bases desde PHP. Si se requiere, vive dentro de un procedimiento o se resuelve con una llamada entre servicios.

### 4.4 Transacciones entre módulos

- Cada operación debe intentar resolverse dentro de una sola base y un solo procedimiento.
- Las operaciones que afectan varias bases requieren un diseño explícito:
  - transacción distribuida (si el motor y la infraestructura lo permiten), o
  - patrón de compensación / idempotencia coordinado por los servicios.
- No se implementarán transacciones cross-database improvisadas desde PHP.
- La estrategia queda como **decisión abierta** (§12).

### 4.5 Columnas obligatorias de las tablas de negocio

Toda tabla de negocio debe incluir, como mínimo, estas columnas:

| Columna | Tipo conceptual | Nulidad | Valor por defecto | Propósito |
| --- | --- | --- | --- | --- |
| `id` | entero grande autogenerado | No | generado por el motor | Clave primaria única. |
| `activo` | booleano | No | `true` | Permite activar o desactivar el registro. |
| `eliminado` | booleano | No | `false` | Marca de eliminación lógica. |
| `idusuario_actualizacion` | entero grande | No | — | Último usuario que insertó o modificó el registro. |
| `fecha_hora_actualizacion` | fecha y hora | No | generada por la base | Fecha y hora del último insert o update. |
| `idusuario_eliminacion` | entero grande | Sí | `NULL` | Usuario que realizó la eliminación lógica. |
| `fecha_hora_eliminacion` | fecha y hora | Sí | `NULL` | Fecha y hora de la eliminación lógica. |

Reglas:

- `id` es la clave primaria de todas las tablas. Es único, autogenerado y no se reutiliza.
- Las claves de negocio (correo, documento, código, etc.) se definen como restricciones únicas adicionales, no como reemplazo de `id`.
- Los nombres de las columnas son fijos y se escriben en `snake_case`, con el prefijo `idusuario_` para las claves de usuario de auditoría.
- `activo` y `eliminado` son estados independientes:
  - `activo` controla si el registro participa en la operación normal.
  - `eliminado` indica que el registro fue dado de baja lógica y no debe mostrarse por defecto.
- En un `INSERT`: `activo = true`, `eliminado = false`, se informa el usuario y la base genera la fecha/hora; los campos de eliminación quedan en `NULL`.
- En un `UPDATE`, activación o desactivación: se actualizan `idusuario_actualizacion` y `fecha_hora_actualizacion`; no se modifican los campos de eliminación.
- En una eliminación lógica: `eliminado = true`, se informan `idusuario_eliminacion` y `fecha_hora_eliminacion`, y también se actualizan los campos de última modificación.
- En una restauración: `eliminado = false`, los campos de eliminación vuelven a `NULL` y se actualizan los campos de última modificación. `activo` conserva su valor salvo que el procedimiento de restauración indique explícitamente lo contrario.
- El usuario y la fecha/hora no se toman del cliente: el procedimiento recibe el identificador de usuario autenticado y la base genera la fecha/hora. Para procesos automáticos se usa un usuario de sistema, nunca `NULL`.
- Las fechas se almacenan en UTC y se presentan en la zona horaria que corresponda en la interfaz.
- `eliminado = true` implica que `idusuario_eliminacion` y `fecha_hora_eliminacion` no sean `NULL`; `eliminado = false` implica que ambos sean `NULL`. Se recomienda expresarlo con una restricción `CHECK`.
- Las tablas técnicas de solo-anexado, en particular `app_db.bitacora`, son la excepción explícita a estas columnas: no se actualizan ni se eliminan.

Equivalencias de tipos:

| Concepto | MySQL 8.4 | SQL Server |
| --- | --- | --- |
| `id` | `BIGINT UNSIGNED AUTO_INCREMENT` | `BIGINT IDENTITY(1,1)` |
| `activo`, `eliminado` | `TINYINT(1)` | `BIT` |
| `idusuario_*` | `BIGINT` | `BIGINT` |
| `fecha_hora_*` | `DATETIME(3)` | `DATETIME2(3)` |

El uso de `BIGINT` es el valor por defecto para `id` y para las claves de usuario (`idusuario_*`). Usar `INT` requiere una justificación documentada.

### 4.6 Borrado lógico, activación y restauración

- La aplicación y los procedimientos **no ejecutan `DELETE`** sobre tablas de negocio. La baja se implementa con `UPDATE` sobre `eliminado`, `idusuario_eliminacion` y `fecha_hora_eliminacion`.
- Las consultas y listados excluyen por defecto los registros con `eliminado = true`. Solo los procedimientos destinados a papelera, administración o restauración pueden leerlos.
- El filtro por `activo` depende de la regla de negocio. Las pantallas de administración pueden mostrar inactivos; los catálogos operativos normalmente solo muestran activos.
- La restauración no es genérica: se habilita por tabla mediante un procedimiento explícito `usp_<modulo>_<entidad>_restaurar`, con validación de permisos y registro en bitácora.
- La purga física de datos queda fuera del flujo normal de la aplicación. Si el equipo de base de datos la autoriza como operación administrativa excepcional, debe documentarse, ejecutarse fuera de la API y quedar auditada.
- La unicidad de claves de negocio debe definirse considerando los registros eliminados. No se debe reutilizar `id`; para las claves naturales se decidirá entre índices parciales, columnas de vigencia o validación dentro del procedimiento, según el motor (ver §12).

### 4.7 Bitácora de cambios

La bitácora es una tabla central en `app_db`:

```text
app_db.bitacora
```

| Columna | Tipo conceptual | Nulidad | Descripción |
| --- | --- | --- | --- |
| `id` | entero grande autogenerado | No | Clave primaria de la bitácora. |
| `idusuario` | entero grande | No | Usuario autenticado que originó el cambio. |
| `fecha_hora` | fecha y hora | No | Momento del cambio, generado por la base en UTC. |
| `tabla_afectada` | texto | No | Nombre calificado `<schema>.<tabla>`. |
| `idregistro` | entero grande | Sí | `id` del registro afectado. |
| `tipo_accion` | texto corto | No | `INSERT`, `UPDATE`, `DELETE` o `RESTORE`. |
| `datos_antes` | JSON | Sí | Snapshot previo; `NULL` en un `INSERT`. |
| `datos_despues` | JSON | Sí | Snapshot posterior; `NULL` en un `DELETE`. |

Reglas:

- `DELETE` representa una eliminación lógica; no un borrado físico.
- `RESTORE` representa la restauración de una eliminación lógica.
- En un `INSERT`, `datos_antes` es `NULL` y `datos_despues` contiene la fila creada.
- En un `UPDATE`, se guardan ambos snapshots.
- En un `DELETE`, `datos_antes` contiene la fila antes de la baja y `datos_despues` es `NULL`.
- En un `RESTORE`, se guardan ambos snapshots.
- Los snapshots son de fila completa, en JSON canónico UTF-8 y con fechas en ISO 8601. Se excluyen o enmascaran columnas secretas (contraseñas, tokens, claves); las exclusiones se documentan por tabla.
- La bitácora es de solo-anexado: no se actualiza ni se elimina desde la aplicación. No lleva `activo`, `eliminado` ni campos de actualización.
- La escritura de la bitácora ocurre en la misma transacción que el cambio de datos. Si falla el registro de bitácora, se revierte el cambio completo.
- La bitácora la escribe explícitamente el procedimiento de escritura, o el procedimiento `app_db.usp_system_bitacora_registrar` invocado por él. No se depende de triggers para evitar diferencias entre motores y mantener explícita la trazabilidad.
- Los procedimientos de escritura de cada módulo pueden invocar el registro central de bitácora como integración autorizada por el equipo de base de datos. El usuario de la base de módulo solo recibe `EXECUTE` sobre ese procedimiento, no permisos de escritura directa sobre `app_db.bitacora`.
- La lectura de la bitácora se expone mediante procedimientos con permisos restringidos y nunca se devuelve a pantallas sin autorización.
- Se indexan al menos `idusuario`, `fecha_hora`, `(tabla_afectada, idregistro)` y `tipo_accion`.
- La bitácora está centralizada en `app_db.bitacora` para todo el sistema. El acceso se otorga por `EXECUTE` sobre los procedimientos de registro y consulta, nunca con permisos directos sobre la tabla.

### 4.8 Calificación explícita de tablas en procedimientos

En todos los procedimientos, toda referencia a una tabla se escribe de forma calificada:

- MySQL: `<base>.<tabla>`, por ejemplo `app_db_ventas.documento`.
- SQL Server, misma base: `<schema>.<tabla>`, por ejemplo `dbo.documento`.
- SQL Server, otra base: `<base>.<schema>.<tabla>`, por ejemplo `app_db.dbo.bitacora`.

Reglas:

- No se permite confiar en el esquema por defecto ni en el `search_path` de la sesión.
- La calificación se aplica en `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `MERGE`, subconsultas y referencias dentro de expresiones.
- Los alias pueden usarse después de calificar la tabla en el `FROM`, pero no sustituyen la calificación.
- La aplicación nunca construye ni envía nombres de tabla, columna o esquema; solo invoca procedimientos con parámetros enlazados.
- Si un procedimiento requiere SQL dinámico, los identificadores deben provenir de listas blancas internas y validarse antes de concatenarse.

---

## 5. Regla de acceso a datos

### 5.1 Capas autorizadas

| Capa | ¿Puede acceder a datos? | Condición |
| --- | --- | --- |
| Controlador web | No | Obtiene datos por `fetch` contra la API |
| Router | No | Solo resuelve rutas |
| Vista / Twig | No | Solo presenta datos recibidos |
| `wservice` | Sí | Solo mediante procedimientos almacenados |
| `Db` | Sí | Ejecuta la invocación del procedimiento; no contiene lógica de negocio |
| `Auth` (infraestructura) | Limitado | Solo a través del `wservice` de autenticación o de procedimientos de `app_db` (ver §5.3) |

### 5.2 Prohibiciones

En el código PHP de la aplicación queda prohibido:

- Ejecutar SQL directo (`SELECT`, `INSERT`, `UPDATE`, `DELETE`, DDL).
- Usar un ORM o *query builder* que genere SQL desde los servicios.
- Interpolar nombres de procedimientos, tablas, columnas o valores provenientes del cliente.
- Acceder a una base de módulo desde otro módulo sin pasar por su `wservice` o por un procedimiento de integración autorizado.

El único punto de acceso es una llamada a procedimiento a través de `Db`, con el nombre del procedimiento validado contra una lista blanca y los parámetros enlazados.

### 5.3 Autenticación

`Auth` necesita validar usuarios y credenciales en `app_db`. Para no romper la regla general:

- **Recomendación:** encapsular el acceso a datos de autenticación en un `wservice` del módulo `system` (por ejemplo, `System\WServices\AuthService`). `Auth` conserva la responsabilidad de sesión/token y llama a ese servicio en proceso, sin HTTP interno.
- Si por razones de arranque se mantiene el acceso en `Auth`, es una excepción documentada: solo puede invocar procedimientos de autenticación de `app_db`, nunca consultar tablas directamente.
- En cualquiera de los dos casos se aplican las mismas reglas: procedimiento + parámetros enlazados + usuario de base de datos con permisos mínimos.
- La decisión definitiva queda en §12.9.

---

## 6. Invocación de procedimientos desde PHP

### 6.1 Contrato del servicio `Db`

`Db` actúa como administrador de conexiones y ejecutor de procedimientos. Propuesta de interfaz conceptual:

```php
$db->connection('dashboard')->call('usp_dashboard_usuarios_listar', [
    'p_busqueda' => $busqueda,
    'p_limite' => 50,
]);
```

Responsabilidades:

- Resolver la conexión lógica (`main`, `dashboard`, etc.) a partir de la configuración.
- Crear y reutilizar la conexión PDO de forma perezosa.
- Validar el nombre del procedimiento contra una lista blanca o un patrón controlado.
- Enlazar parámetros de entrada y salida.
- Normalizar el resultado a un arreglo de filas o a un valor escalar.
- Traducir errores del motor a excepciones de la aplicación.
- No conocer reglas de negocio.

### 6.2 Invocación por motor

El adaptador de conexión encapsula la diferencia:

- **MySQL:** `CALL <procedimiento>(?, ?)` con `PDO`.
- **SQL Server:** `EXEC <procedimiento> @p_param = ?, ...` o la forma que soporte el driver `pdo_sqlsrv`.

Reglas para que los procedimientos sean consumibles desde ambos motores:

- Devolver **un único result set** por procedimiento, salvo excepción documentada.
- Evitar múltiples result sets y cursores específicos del motor.
- En SQL Server, usar `SET NOCOUNT ON` para no mezclar conteos de filas con el resultado.
- Usar parámetros de entrada con prefijo `p_` y, si se requieren, salida con prefijo `o_`.
- Calificar siempre las tablas como `<schema>.<tabla>` (ver §4.8), incluso dentro de la misma base.
- Toda escritura debe registrar la bitácora según §4.7.
- No exponer nombres de tablas ni SQL al cliente.
- Evitar SQL dinámico; si es imprescindible, validar contra listas blancas dentro del procedimiento.

### 6.3 Resultados y errores

- Los procedimientos de lectura devuelven filas; los de escritura devuelven el identificador, las filas afectadas o el estado definido por el equipo de base de datos.
- Los errores se propagan mediante el mecanismo del motor (SQLSTATE / error code) y `Db` los convierte en una excepción normalizada.
- `Api` traduce la excepción al contrato `{status, message, data}` y al código HTTP correspondiente.
- En producción no se devuelven mensajes internos del motor ni trazas.
- El equipo de base de datos debe documentar, para cada procedimiento, sus parámetros, resultado y posibles errores.

### 6.4 Transacciones

- La transacción debe vivir preferentemente dentro del procedimiento, para que el equipo de base de datos controle atomicidad y bloqueos.
- El cambio de datos y su registro en la bitácora deben confirmarse o revertirse juntos. Un fallo al escribir la bitácora revierte la operación.
- La eliminación lógica y su bitácora también forman una sola unidad transaccional.
- Si el `wservice` necesita coordinar varias llamadas, `Db` puede exponer un helper de transacción, pero no se deben anidar transacciones sin una regla explícita.
- Los procedimientos no deben dejar transacciones abiertas.

---

## 7. Llamadas internas con `curl`

El flujo de datos combina dos tipos de comunicación:

1. **Navegador → API**: la pantalla usa `fetch('/api/<modulo>/<servicio>')`.
2. **Aplicación → aplicación**: cuando un `wservice` necesita el resultado de otro módulo o de un servicio externo, la aplicación realiza una **llamada HTTP interna tipo `curl`**, no una consulta directa a la base del otro módulo.

> **Interpretación:** se asume que las llamadas internas con `curl` son entre `wservices`/módulos o hacia integraciones externas, no un mecanismo para conectarse a la base de datos. Si el alcance es distinto, ajustar esta sección y la decisión abierta §12.7.

Reglas propuestas:

- La llamada interna usa el mismo contrato JSON `{status, message, data}`.
- Se envía un mecanismo de autenticación de servicio (token interno, mTLS o el que se defina); no se reutilizan credenciales de usuario sin justificación.
- Se definen timeouts, reintentos solo para operaciones idempotentes y un identificador de correlación para trazabilidad.
- Se evitan ciclos entre servicios (A llama a B y B llama a A).
- Las URLs internas se configuran; no se construyen con datos sin validar.
- `curl` se usa para HTTP, **nunca** para conectarse a la base de datos.

Estado técnico: la imagen PHP incluye `ext-curl` y el build falla si la extensión no está disponible. Queda definir si los `wservices` usan `curl` nativo o un cliente HTTP en Composer.

---

## 8. Estructura y versionado de SQL

### 8.1 Esquemas

Cada base de datos tiene un script de generación en:

```text
dev/sql/schemas/
├── app_db.sql
├── app_db_dashboard.sql
├── app_db_ventas.sql
└── app_db_existencias.sql
```

Reglas:

- Un archivo por base de datos.
- El nombre del archivo debe coincidir con el nombre de la base.
- El script debe ser idempotente y reproducible según el motor: `CREATE TABLE IF NOT EXISTS` en MySQL; comprobaciones de catálogo (`IF OBJECT_ID(...) IS NULL`, etc.) en SQL Server.
- Debe contener la definición completa del modelo de esa base, no solo cambios incrementales.
- Toda tabla de negocio debe incluir las columnas estándar de §4.5 y las restricciones de estado de eliminación.
- El esquema no debe depender de borrados físicos para la operación normal.
- Los datos de prueba o *fixtures* deben ir separados de la definición del esquema.
- No se incluyen credenciales, datos productivos ni volcados completos con información sensible.
- Si se mantienen variantes para MySQL y MSSQL, se organizan según §9.3.

### 8.2 Procedimientos

Cada procedimiento tiene su propio archivo en:

```text
dev/sql/procedures/
├── app_db/
│   └── usp_auth_usuario_validar.sql
├── app_db_dashboard/
│   └── usp_dashboard_usuarios_listar.sql
├── app_db_ventas/
│   └── usp_ventas_documento_crear.sql
└── app_db_existencias/
    └── usp_existencias_stock_consultar.sql
```

Reglas:

- Un procedimiento por archivo.
- El nombre del archivo coincide con el nombre del procedimiento.
- El archivo debe ser idempotente: eliminar/crear la versión anterior de forma controlada.
- Debe incluir una cabecera con metadatos.
- Toda tabla referenciada debe aparecer calificada como `<schema>.<tabla>` en el cuerpo.
- Toda operación de escritura debe documentar si registra bitácora y con qué tipo de acción.
- Si el procedimiento cambia, se actualiza el archivo, se revisa, se aplica a la base correspondiente y se versiona en Git.

Cabecera propuesta:

```sql
-- Base de datos: app_db_dashboard
-- Motor: MySQL 8.4
-- Procedimiento: usp_dashboard_usuarios_listar
-- Versión: 1
-- Descripción: Lista usuarios del tablero con filtro opcional.
-- Parámetros:
--   p_busqueda VARCHAR(100)  Texto de búsqueda (opcional)
--   p_limite   INT           Cantidad máxima de filas
-- Resultado: id, nombre, email, rol, activo, fecha_hora_actualizacion
-- Bitácora: no aplica (procedimiento de lectura)
-- Autor: Equipo de Base de Datos
-- Fecha: 2026-10-22
```

El cuerpo es específico del motor. Si se mantienen variantes para MySQL y MSSQL, deben convivir de forma explícita (§9.3).

### 8.3 Nomenclatura propuesta

| Elemento | Convención | Ejemplo |
| --- | --- | --- |
| Procedimiento | `usp_<modulo>_<accion>` | `usp_ventas_documento_crear` |
| Parámetro de entrada | `p_<nombre>` | `p_idusuario` |
| Parámetro de salida | `o_<nombre>` | `o_documento_id` |
| Base principal | `app_db` | — |
| Base de módulo | `app_db_<modulo>` | `app_db_ventas` |
| Tabla | `snake_case` | `documento` |
| Columna | `snake_case` | `fecha_hora_actualizacion` |
| Clave primaria | `id` | `documento.id` |
| Estado activo | `activo` | — |
| Eliminación lógica | `eliminado` | — |
| Usuario de actualización | `idusuario_actualizacion` | — |
| Fecha de actualización | `fecha_hora_actualizacion` | — |
| Usuario de eliminación | `idusuario_eliminacion` | — |
| Fecha de eliminación | `fecha_hora_eliminacion` | — |
| Bitácora central | `app_db.bitacora` | — |
| Acciones de bitácora | `INSERT`, `UPDATE`, `DELETE`, `RESTORE` | — |

Se evita el prefijo `sp_`: en SQL Server está reservado para procedimientos del sistema y su uso en procedimientos de usuario puede generar búsquedas no deseadas. Queda como decisión abierta si se adopta exactamente `usp_` o variantes por motor.

### 8.4 Flujo de cambio

1. El equipo de aplicación detecta una necesidad de datos y la documenta.
2. El encargado de base de datos diseña o modifica el procedimiento, incluyendo calificación de tablas y bitácora cuando corresponda.
3. Se actualiza el archivo en `dev/sql/procedures/<basedatos>/`.
4. Si cambia el modelo, se actualiza también `dev/sql/schemas/<basedatos>.sql` respetando las columnas estándar y el borrado lógico.
5. Se revisa el cambio (pull request / revisión del equipo).
6. Se aplica en desarrollo y se prueban los casos de uso.
7. Se aplica en el entorno correspondiente (test, producción) con el procedimiento de despliegue definido.
8. Se versiona el archivo en Git. Ningún cambio queda solo en la base de datos.

Reglas de convivencia:

- La base de datos y el repositorio deben poder reconstruirse desde los scripts.
- No se edita un procedimiento en producción sin actualizar antes su archivo fuente.
- Los cambios incompatibles deben coordinarse con la aplicación y, si es necesario, mantener una versión anterior durante la transición.
- El historial de Git es el mecanismo de rollback: se vuelve a aplicar la versión anterior del archivo.

### 8.5 Aplicación de scripts

- `make sql-app` aplica `dev/sql/schemas/app_db*.sql` y crea/aplica la base `app_db`. El script `app_db.sql` es autocontenido (`CREATE DATABASE IF NOT EXISTS` + `USE app_db`).
- `make sql` sigue aplicando los esquemas sobre `pr_db` (entorno heredado) y debe migrarse a `make sql-app` cuando el código pase a `app_db`.
- `make sql-procedures` aplica los archivos de `dev/sql/procedures/app_db/` a la base `app_db`.
- La creación de bases, usuarios y permisos puede quedar a cargo del equipo de base de datos; el repositorio documenta lo necesario, pero no necesariamente ejecuta todas las operaciones administrativas.
- Para módulos, se propone un `make sql-module` que aplique `app_db_<modulo>` (pendiente de implementar).

---

## 9. Soporte MySQL y MSSQL

### 9.1 Situación actual

- La imagen Docker instala `pdo_mysql` y `mysqli`.
- También instala `pdo_sqlsrv` 5.13.3 y Microsoft ODBC Driver 18 for SQL Server (paquete Alpine `msodbcsql18`).
- La extensión no-PDO `sqlsrv` no está instalada; la aplicación debe usar PDO.
- El código actual no tiene un administrador de conexiones múltiples.

Para usar MSSQL en la aplicación falta:

- Configurar DSN y credenciales por entorno.
- Adaptar `Db` para seleccionar `pdo_mysql` o `pdo_sqlsrv` y traducir la invocación de procedimientos.

### 9.2 Diferencias que debe absorber el adaptador

| Aspecto | MySQL | SQL Server |
| --- | --- | --- |
| Invocación | `CALL proc(?, ?)` | `EXEC proc @p = ?` |
| Paginación | `LIMIT` / `OFFSET` | `OFFSET ... FETCH` |
| Errores | SQLSTATE / `SIGNAL` | `THROW` / códigos propios |
| Conteo de filas | Result set | `SET NOCOUNT ON` |
| Identificadores | Backticks | Corchetes |
| Tipos | Propios de MySQL | Propios de SQL Server |

Reglas:

- La aplicación no escribe estas diferencias: las absorben el adaptador de `Db` y los procedimientos.
- Los procedimientos se mantienen por motor cuando la sintaxis no sea portable.
- La lógica de negocio no debe depender de códigos de error específicos del motor; `Db` los normaliza.
- Los tipos de datos se eligen buscando equivalencia entre motores; los detalles se documentan por procedimiento.

### 9.3 Organización de variantes por motor

La estructura solicitada es `dev/sql/schemas/<basedatos>.sql` y `dev/sql/procedures/<basedatos>/<procedimiento>.sql`. Si se mantienen versiones para MySQL y MSSQL en paralelo, se propone extenderla a:

```text
dev/sql/
├── schemas/
│   ├── mysql/
│   │   ├── app_db.sql
│   │   └── app_db_dashboard.sql
│   └── mssql/
│       ├── app_db.sql
│       └── app_db_dashboard.sql
└── procedures/
    ├── mysql/
    │   ├── app_db/
    │   └── app_db_dashboard/
    └── mssql/
        ├── app_db/
        └── app_db_dashboard/
```

Esta extensión queda como **decisión abierta** (§12). Alternativas: una rama por motor, un repositorio de esquemas/procedimientos por motor o scripts escritos en un subconjunto portable cuando sea posible.

### 9.4 Pruebas

- Cada procedimiento debe probarse contra el motor o motores soportados.
- Se recomienda una matriz de pruebas (MySQL y MSSQL) para los flujos críticos.
- Las pruebas de contrato verifican parámetros, forma del resultado y errores esperados, no detalles internos del procedimiento.

---

## 10. Seguridad

- Cada usuario de base de datos tiene permisos mínimos: `EXECUTE` sobre sus procedimientos y, si es imprescindible, permisos de lectura acotados. Sin `SELECT`/`INSERT`/`UPDATE`/`DELETE` directos sobre tablas.
- Los procedimientos se ejecutan con nombres de una lista blanca; nunca con entrada libre del cliente.
- Todos los parámetros se enlazan; no se concatenan valores en SQL.
- La bitácora es de solo-anexado y de acceso restringido. Los usuarios de módulo solo reciben `EXECUTE` sobre el procedimiento de registro; no pueden leer, actualizar ni borrar la tabla directamente.
- Los snapshots de bitácora no incluyen contraseñas, tokens, claves ni otros secretos; esas columnas se excluyen o enmascaran.
- Las credenciales viven en `.env` o en el gestor de secretos del entorno; nunca en el repositorio.
- Las llamadas internas tipo `curl` se autentican y, si salen de la red interna, usan TLS.
- No se registran contraseñas, tokens ni datos sensibles en logs.
- Los scripts SQL no incluyen datos productivos ni credenciales.
- Se revisan los permisos de las cuentas de base de datos al crear una nueva base o un nuevo procedimiento.

---

## 11. Migración desde el estado actual

El proyecto todavía no implementa este modelo. Pasos sugeridos:

1. Definir y aprobar las decisiones abiertas de §12.
2. Renombrar la base principal de desarrollo de `pr_db` a `app_db` (o crear `app_db` y migrar los datos).
3. Crear las bases de módulo necesarias y sus scripts en `dev/sql/schemas/`, aplicando las columnas estándar y el borrado lógico.
4. Crear `app_db.bitacora` y el procedimiento central de registro de bitácora.
5. Crear la estructura `dev/sql/procedures/<basedatos>/` y los primeros procedimientos con referencias calificadas.
6. Implementar `Db` como administrador de conexiones múltiples y ejecutor de procedimientos.
7. Adaptar `make sql` y agregar el comando de aplicación de procedimientos.
8. Configurar usuarios de base de datos con permisos mínimos, incluido `EXECUTE` sobre el registro de bitácora.
9. Refactorizar los `wservices` para que solo llamen procedimientos.
10. Retirar el acceso directo a PDO de `public/index.php` y de `public/demo/` cuando corresponda.
11. Verificar en el build que `ext-curl`, `pdo_sqlsrv` y el driver ODBC 18 estén disponibles.
12. Probar el flujo completo: pantalla → `fetch` → API → `wservice` → procedimiento → JSON, incluyendo bitácora y borrado lógico.

> Mientras la migración no ocurra, el entorno local seguirá usando `pr_db` y el acceso directo a PDO del material de ejemplo. Eso no debe tomarse como el patrón objetivo.

---

## 12. Decisiones abiertas

1. **Mapeo definitivo de bases por módulo**: qué módulos tienen base propia y cuáles usan `app_db`.
2. **Nombres de variables de entorno y conexiones** (`DB_MAIN_*`, `DB_<MODULO>_*`).
3. **Nomenclatura definitiva de procedimientos** (`usp_`, `app_` u otra).
4. **Estructura de variantes por motor**: `dev/sql/schemas/<basedatos>.sql` y `dev/sql/procedures/<basedatos>/` vs. una organización con nivel `<motor>/` para ambos.
5. **Estrategia de transacciones entre bases**: transacción distribuida vs. compensación/idempotencia.
6. **Uso de claves foráneas entre bases**: prohibidas por defecto o permitidas con justificación.
7. **Alcance de las llamadas internas con `curl`**: entre módulos, hacia servicios externos o ambos.
8. **Autenticación de llamadas internas**: token de servicio, mTLS u otro mecanismo.
9. **Encapsulación de la autenticación**: `Auth` como infraestructura vs. `wservice` del módulo `system`.
10. **Automatización de aplicación de procedimientos**: comando `make procedures`, script de despliegue o proceso manual.
11. **Versionado de procedimientos incompatibles**: nueva versión con sufijo vs. reemplazo coordinado.
12. **Estrategia de pruebas multi-motor** y entorno de CI.
13. **Manejo de errores normalizado** entre MySQL y MSSQL.
14. **Nombres de las columnas estándar** (decidido): `idusuario_actualizacion`, `fecha_hora_actualizacion`, `idusuario_eliminacion` y `fecha_hora_eliminacion`. La bitácora usa `idusuario` e `idregistro`.
15. **Tipo de `id`** (decidido): `BIGINT` para `id` y claves de usuario; usar `INT` requiere justificación.
16. **Ubicación de la bitácora** (decidido): centralizada en `app_db.bitacora`.
17. **Nombres de las columnas de bitácora**: quedan fijos en `idusuario`, `idregistro`, `tabla_afectada`, `tipo_accion`, `datos_antes`, `datos_despues`.
18. **Unicidad con registros eliminados**: índices parciales, columnas de vigencia o validación en procedimiento.
19. **Alcance de la restauración y de la purga física**: qué tablas permiten restaurar y quién autoriza una purga administrativa.

---

## 13. Criterios de aceptación

- [ ] La base principal se llama `app_db` y existe al menos una base de módulo con su script en `dev/sql/schemas/`.
- [ ] Cada base tiene su script de generación reproducible.
- [ ] Toda tabla de negocio tiene `id`, `activo`, `eliminado` y los cuatro campos de auditoría de actualización/eliminación.
- [ ] Ninguna operación de la aplicación elimina filas físicamente; las bajas son lógicas.
- [ ] Las consultas normales excluyen registros con `eliminado = true`.
- [ ] Toda escritura registra una fila en `app_db.bitacora` con usuario, fecha/hora, tabla calificada, acción y snapshots antes/después según corresponda.
- [ ] La bitácora se escribe en la misma transacción que el cambio y no se actualiza ni elimina desde la aplicación.
- [ ] Las restauraciones permitidas usan un procedimiento explícito y quedan auditadas como `RESTORE`.
- [ ] Todos los procedimientos referencian sus tablas como `<schema>.<tabla>`.
- [ ] Cada procedimiento tiene un archivo propio en `dev/sql/procedures/<basedatos>/`.
- [ ] Ningún controlador, router, vista o `wservice` ejecuta SQL directo.
- [ ] Todos los accesos a datos de negocio pasan por procedimientos invocados desde `wservices`.
- [ ] `Db` administra conexiones con nombre y reutiliza la conexión dentro de la petición.
- [ ] Los usuarios de base de datos solo tienen permisos de ejecución sobre sus procedimientos.
- [ ] Un cambio de procedimiento se refleja en el archivo versionado y se aplica a la base correspondiente.
- [ ] El flujo `fetch` → API → `wservice` → procedimiento → JSON funciona de extremo a extremo.
- [ ] Las llamadas internas tipo `curl` tienen autenticación, timeout y manejo de errores.
- [ ] La aplicación no contiene sintaxis específica de MySQL o MSSQL fuera del adaptador y de los scripts de base de datos.
- [ ] La documentación de cada procedimiento permite al equipo de aplicación conocer parámetros, resultado y errores.

---

## 14. Referencias

- [`arquitectura.md`](arquitectura.md): arquitectura general, arranque, rutas, API y autenticación.
- [`control-acceso.md`](control-acceso.md): estructura app/módulos/carpetas/opciones, roles y usuarios.
- [`AGENTS.md`](../../AGENTS.md): reglas de trabajo y comandos.
- [`README.md`](../../README.md): inicio rápido y estado del proyecto.
