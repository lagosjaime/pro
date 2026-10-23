# Especificación de control de acceso — Aplicación `pr`

| Campo | Valor |
| --- | --- |
| Versión | 0.1 (borrador) |
| Fecha | 2026-10-22 |
| Estado | Para revisión y refinamiento |
| Alcance | Modelo de datos de acceso, estructura app/módulos/carpetas/opciones, roles, usuarios y evaluación de permisos |
| Documentos relacionados | [`arquitectura.md`](arquitectura.md), [`base-de-datos.md`](base-de-datos.md), [`pantallas.md`](pantallas.md), [`README.md`](../../README.md), [`AGENTS.md`](../../AGENTS.md) |

> Este documento define cómo se modela el control de acceso. La estructura de navegación del sistema (módulos, carpetas y opciones) vive en la **base principal** `app_db` y es la misma que alimenta el menú y la validación de permisos. Complementa [`base-de-datos.md`](base-de-datos.md) y sustituye la construcción del menú descrita en [`pantallas.md`](pantallas.md) §5.

---

## 1. Objetivo

- Centralizar en `app_db` el control de acceso: qué módulos, carpetas y opciones existen y quién puede usarlos.
- Definir una jerarquía única que sirva simultáneamente como **estructura de navegación** y como **modelo de autorización**.
- Permitir que los **roles** concentren los permisos y que los **usuarios** hereden el acceso a través de sus roles.
- Mantener la autorización en servidor: la base define el acceso, la aplicación lo aplica en cada ruta y fragmento.
- Administrar el ciclo de vida de la cuenta: alta sin contraseña, definición en el primer acceso, recuperación, segundo factor opcional y políticas de seguridad.
- Sostener una **orientación fuerte a la auditoría**: registrar accesos, uso de opciones y todo cambio relevante.

---

## 2. Principios

1. **La base principal manda.** `app_db` es la fuente de verdad de app, módulos, carpetas, opciones, roles, permisos y usuarios.
2. **Una sola jerarquía.** La misma estructura `módulo → carpeta → opción` organiza el menú y define el acceso.
3. **El rol es el sujeto del permiso.** Los permisos se asignan a roles, no a usuarios directamente.
4. **El acceso se hereda hacia arriba.** Conceder una opción da acceso a su carpeta y a su módulo; no al revés.
5. **Autorización siempre en servidor.** Ocultar una opción en el menú no sustituye la validación de la ruta ni del servicio API.
6. **Seguro por defecto.** Sin rol con la opción concedida, el acceso se deniega.
7. **El código no enumera el acceso.** La aplicación no mantiene listas paralelas de módulos, carpetas u opciones; las lee de la base.
8. **Registro estándar.** Todas las tablas siguen las columnas estándar, el borrado lógico y la bitácora de [`base-de-datos.md`](base-de-datos.md) §4.5–§4.7.
9. **Sin contraseñas por defecto.** Todo usuario crea su propia contraseña; nadie, ni el administrador, la conoce.
10. **Un solo token vigente por sesión.** El token de acceso identifica la sesión activa y se renueva al iniciar sesión; el acceso anterior queda invalidado.
11. **Políticas de seguridad administrables.** Largo, duración, historial de contraseñas e intentos viven en `seguridad_parametros`, no en el código.
12. **Auditoría integral.** Los accesos (`usuario_acceso_log`) y el uso de opciones (`opcion_uso_log`) se registran siempre; son de solo-anexado.
13. **Segundo factor opcional.** El usuario puede activar o desactivar la autenticación por app (TOTP); el administrador puede volverla obligatoria.

---

## 3. Jerarquía

```text
app
└── módulo
    └── carpeta
        └── opción
             └── (acceso) ← rol → usuario
```

- **app**: configuración general de la aplicación (una fila, o pocas). Ver §4.1.
- **módulo**: unidad funcional que agrupa carpetas. Corresponde a una carpeta de `modules/<modulo>/`.
- **carpeta**: agrupación de opciones dentro de un módulo. Equivale a un grupo del menú lateral.
- **opción**: pantalla o acción ejecutable. Pertenece siempre a una carpeta.
- **rol**: conjunto de opciones concedidas.
- **usuario**: persona autenticada, asociada a uno o varios roles.
- **token**: credencial de sesión de un solo valor vigente por usuario, base de la validación de llamadas a `wservices`.
- **parámetros de seguridad**: política administrable de contraseñas, tokens e intentos.
- **logs**: `usuario_acceso_log` (eventos de acceso) y `opcion_uso_log` (uso de opciones).
- **segundo factor**: configuración TOTP opcional por usuario (`usuario_2fa`) y sus códigos de recuperación.

---

## 4. Modelo de datos

Convenciones generales (ver [`base-de-datos.md`](base-de-datos.md) §4.5):

- `id` de tipo `BIGINT` autogenerado.
- Columnas estándar: `activo`, `eliminado`, `idusuario_actualizacion`, `fecha_hora_actualizacion`, `idusuario_eliminacion`, `fecha_hora_eliminacion`.
- No se ejecuta `DELETE`: la baja es lógica.
- Toda escritura deja bitácora en `app_db.bitacora`.

Los campos se listan sin repetir las columnas estándar, salvo que requieran aclaración.

### 4.1 `app`

Configuración de características de la aplicación. Una fila por aplicación o entorno lógico.

| Columna | Tipo | Nulidad | Descripción |
| --- | --- | --- | --- |
| `idapp` | `BIGINT` | No | Clave primaria. |
| `app_nombre` | `VARCHAR(150)` | No | Nombre visible de la aplicación. |

> Las características adicionales (tema, idioma, versión, parámetros) se agregarán cuando se definan. Este documento dejará explícito qué se guarda en `app` y qué en configuración de entorno.

### 4.2 `modulos`

| Columna | Tipo | Nulidad | Descripción |
| --- | --- | --- | --- |
| `idmodulo` | `BIGINT` | No | Clave primaria. |
| `modulo_nombre` | `VARCHAR(100)` | No | Nombre del módulo. |

- `modulo_nombre` corresponde al nombre de la carpeta en `modules/<modulo>/` y al segmento `/<modulo>` de la URL. Se valida con `^[a-z][a-z0-9_-]*$`.
- El módulo debe existir también como código en `modules/<modulo>/`; la base no crea código.

### 4.3 `carpetas`

| Columna | Tipo | Nulidad | Descripción |
| --- | --- | --- | --- |
| `idcarpeta` | `BIGINT` | No | Clave primaria. |
| `idmodulo` | `BIGINT` | No | Módulo al que pertenece. |
| `carpeta_nombre` | `VARCHAR(100)` | No | Nombre visible de la carpeta. |
| `carpeta_orden` | `VARCHAR(10)` | No | Orden de la carpeta dentro del módulo. |

- `idmodulo` referencia `modulos.idmodulo` (integridad dentro de `app_db`).
- `carpeta_orden` es `varchar` a propósito para permitir órdenes tipo `10`, `20`, `10.5`, `A`, `A1` sin renumerar el resto. Se compara como texto con orden estable; el equipo de base de datos define el criterio exacto.
- Una carpeta no puede quedar sin módulo.

### 4.4 `opciones`

| Columna | Tipo | Nulidad | Descripción |
| --- | --- | --- | --- |
| `idopcion` | `BIGINT` | No | Clave primaria. |
| `idcarpeta` | `BIGINT` | No | Carpeta a la que pertenece. |
| `opcion_nombre` | `VARCHAR(100)` | No | Nombre visible de la opción. |
| `opcion_orden` | `VARCHAR(10)` | No | Orden de la opción dentro de la carpeta. |
| `opcion_call` | `VARCHAR(150)` | No | Ruta a invocar, en formato `<modulo>/<opcion>`. |
| `opcion_parametros` | `VARCHAR(500)` | Sí | Query string con parámetros de carga de la opción. |
| `opcion_grupo_accion` | `VARCHAR(50)` | Sí | Grupo de acción, para análisis y matrices de riesgo. |
| `opcion_accion` | `VARCHAR(50)` | Sí | Acción concreta, para análisis y matrices de riesgo. |

- `idcarpeta` referencia `carpetas.idcarpeta`.
- **Toda opción pertenece a una carpeta.** No existen opciones sueltas a nivel de módulo.
- `opcion_call` es la ruta que permite **enrutar** la opción. Formato `"<modulo>/<opcion>"`, por ejemplo `dashboard/usuarios` o `ventas/pedido`. Corresponde a la ruta `/<modulo>/<opcion>` y a la clave resuelta en `router.php`.
  - `modulo` y `opcion` deben cumplir `^[a-z][a-z0-9_-]*$`.
  - Se valida contra una lista blanca o contra las rutas declaradas; nunca se usa para construir rutas de archivo sin validar ni para concatenar SQL.
  - No incluye el segmento `/api`; las opciones que invocan servicios API se resuelven en `router_api.php` con la misma clave.
- `opcion_parametros` es un **query string** con el formato `<variable>=<valor>&<variable>=<valor>`, sin el signo `?` inicial, por ejemplo `vista=resumen&filtrar=activo`. Se usa para enviar parámetros en la **carga** de la opción.
  - Permite que una **misma `opcion_call`** sirva a varias opciones enviando distintos parámetros. Cada `opciones` es una fila con su propio `opcion_nombre` y `opcion_parametros`, pero comparten `opcion_call`.
  - Los pares se codifican como en una URL (`urlencode`); la aplicación los decodifica y los trata como datos no confiables. Nunca se concatenan en SQL ni en rutas de archivo.
  - No sustituye al estado de la pantalla: los filtros que cambia el usuario viven en la URL de navegación, no en `opcion_parametros` (ver [`pantallas.md`](pantallas.md) §8).
  - Cuando una opción no necesita parámetros, el campo queda `NULL` o vacío.
- `opcion_grupo_accion` y `opcion_accion` no definen el enrutamiento: se usan para **análisis de riesgo y matrices de riesgo** (clasificar y cruzar opciones por tipo de acción). Se mantienen como catálogo abierto salvo que el equipo de seguridad los cierre (§11).

### 4.5 Relación de roles con opciones

Los permisos se asignan a roles. Se propone una tabla de asociación:

| Columna | Tipo | Nulidad | Descripción |
| --- | --- | --- | --- |
| `idrol_opcion` | `BIGINT` | No | Clave primaria. |
| `idrol` | `BIGINT` | No | Rol que recibe el permiso. |
| `idopcion` | `BIGINT` | No | Opción concedida. |

- La clave lógica es `(idrol, idopcion)`; se define como restricción única entre filas vigentes.
- La ausencia de fila equivale a denegar.
- Un rol con una opción concedida obtiene acceso a esa opción y, por herencia, a su carpeta y su módulo (§5).
- El modelo admite una jerarquía de roles si se define una tabla `roles_roles` (rol padre/hijo); queda como decisión abierta (§11).

### 4.6 `roles`

| Columna | Tipo | Nulidad | Descripción |
| --- | --- | --- | --- |
| `idrol` | `BIGINT` | No | Clave primaria. |
| `rol_nombre` | `VARCHAR(100)` | No | Nombre del rol. |
| `rol_descripcion` | `VARCHAR(255)` | Sí | Descripción opcional. |

### 4.7 Relación de usuarios con roles

| Columna | Tipo | Nulidad | Descripción |
| --- | --- | --- | --- |
| `idusuario_rol` | `BIGINT` | No | Clave primaria. |
| `idusuario` | `BIGINT` | No | Usuario. |
| `idrol` | `BIGINT` | No | Rol asignado. |

- Clave lógica `(idusuario, idrol)`.
- Un usuario puede tener uno o varios roles. El acceso efectivo es la **unión** de las opciones de todos sus roles activos.

### 4.8 `usuarios`

| Columna | Tipo | Nulidad | Descripción |
| --- | --- | --- | --- |
| `idusuario` | `BIGINT` | No | Clave primaria. |
| `usuario_nombre` | `VARCHAR(150)` | No | Nombre completo o visible. |
| `usuario_correo` | `VARCHAR(180)` | No | Correo electrónico. |
| `usuario_login` | `VARCHAR(80)` | No | Nombre de inicio de sesión. |
| `usuario_password` | `VARCHAR(255)` | **Sí** | Contraseña **codificada** (hash). `NULL` mientras el usuario no la define (ver §7.2). |
| `usuario_token_acceso` | `VARCHAR(255)` | Sí | Token de sesión vigente, almacenado codificado. `NULL` sin sesión activa. |
| `fecha_ultimo_cambio_password` | fecha y hora | Sí | Fecha/hora del último cambio de contraseña (base para la duración). |
| `fecha_token_acceso` | fecha y hora | Sí | Fecha/hora de emisión del token de sesión vigente. |
| `intentos_fallidos` | entero | No | Intentos de login fallidos consecutivos. `0` al iniciar sesión con éxito. |
| `fecha_ultimo_intento` | fecha y hora | Sí | Fecha/hora del último intento de login. |
| `bloqueado` | booleano | No | Indica si el usuario está bloqueado para iniciar sesión. |
| `fecha_bloqueo` | fecha y hora | Sí | Fecha/hora en que se bloqueó por intentos fallidos. |
| `doble_factor_habilitado` | booleano | No | Indica si el usuario tiene activo el segundo factor (app de autenticación). |
| `fecha_dado_baja` | fecha y hora | Sí | Fecha/hora de baja del usuario. |
| `motivo_baja` | `VARCHAR(255)` | Sí | Motivo de la baja. |

Reglas:

- `usuario_login` y `usuario_correo` son claves de negocio únicas (entre registros no eliminados).
- `usuario_password` es `NULL` para usuarios recién creados y hasta que definan su contraseña en el primer acceso (§7.2).
- `usuario_password` guarda el hash producido por la aplicación (`password_hash` de PHP o el algoritmo que defina el equipo). El procedimiento nunca compara en SQL; devuelve el hash y la verificación ocurre en PHP.
- `usuario_token_acceso` se almacena codificado/hasheado. Se regenera en cada inicio de sesión y se anula al cerrar sesión (§7.4).
- `bloqueado` corta el inicio de sesión sin eliminar la cuenta; es independiente de `activo` y de `eliminado`. Se activa al superar los intentos permitidos y se libera al recuperar la contraseña (§7.6).
- `intentos_fallidos` y `fecha_bloqueo` implementan la política de intentos (§7.6).
- `doble_factor_habilitado` refleja si el usuario tiene activo el segundo factor mediante app de autenticación; es opcional y lo controla el propio usuario (§7.9).
- La baja de un usuario usa `fecha_dado_baja` y `motivo_baja` **además** del borrado lógico estándar (`eliminado`, `idusuario_eliminacion`, `fecha_hora_eliminacion`). `fecha_dado_baja` expresa la baja funcional; el borrado lógico expresa la baja del registro.
- Las columnas de contraseña y token **nunca** se incluyen en los snapshots de bitácora ni en respuestas de la API; se excluyen o enmascaran (ver §8).

### 4.9 `password_historial`

Guarda los hashes de contraseñas anteriores para impedir la reutilización.

| Columna | Tipo | Nulidad | Descripción |
| --- | --- | --- | --- |
| `idpassword_historial` | `BIGINT` | No | Clave primaria. |
| `idusuario` | `BIGINT` | No | Usuario al que pertenece el historial. |
| `password_hash` | `VARCHAR(255)` | No | Hash de una contraseña anterior. |
| `fecha_cambio` | fecha y hora | No | Fecha/hora en que esa contraseña fue reemplazada. |

- Se conservan las últimas N contraseñas vigentes (N = `password_historial` de §4.10). Las más antiguas se retiran con **baja lógica** (`eliminado = 1`) mediante el procedimiento correspondiente; nunca con `DELETE`.
- El historial nunca se devuelve a la interfaz ni se registra en bitácora.

### 4.10 `seguridad_parametros`

Parámetros de política de seguridad. Una fila por parámetro, o una fila única con todas las columnas.

| Columna | Tipo | Nulidad | Descripción |
| --- | --- | --- | --- |
| `idseguridad_parametro` | `BIGINT` | No | Clave primaria. |
| `password_largo_minimo` | entero | No | Largo mínimo de la contraseña. |
| `password_largo_maximo` | entero | Sí | Largo máximo admitido. |
| `password_duracion_dias` | entero | No | Vigencia de la contraseña en días; `0` = sin caducidad. |
| `password_historial` | entero | No | Cantidad de contraseñas anteriores que no pueden repetirse. |
| `intentos_maximos` | entero | No | Intentos fallidos antes de bloquear. |
| `token_vigencia_minutos` | entero | Sí | Vigencia del token de definición/recuperación de contraseña. |
| `sesion_vigencia_minutos` | entero | Sí | Vigencia de la sesión/token de acceso. |
| `doble_factor_exigido` | booleano | No | Si es `true`, el segundo factor es obligatorio para todos los usuarios; si es `false`, cada usuario decide (§7.9). |
| `doble_factor_codigo_vigencia_segundos` | entero | Sí | Ventana de validez aceptada para cada código TOTP (tolerancia de reloj). |
| `doble_factor_codigos_recuperacion` | entero | Sí | Cantidad de códigos de recuperación generados al activar el 2FA. |

- Los valores se administran con la opción correspondiente y cada cambio queda en bitácora.
- Los valores por defecto y la calendarización quedan como decisión abierta (§11).

### 4.11 `usuario_token`

Tokens de un solo uso para definir o recuperar contraseña. Un usuario puede tener a lo sumo un token vigente.

| Columna | Tipo | Nulidad | Descripción |
| --- | --- | --- | --- |
| `idusuario_token` | `BIGINT` | No | Clave primaria. |
| `idusuario` | `BIGINT` | No | Usuario destinatario. |
| `token_hash` | `VARCHAR(255)` | No | Hash del token enviado por correo. Nunca en texto plano. |
| `proposito` | `VARCHAR(30)` | No | `activacion` (primer acceso) o `recuperacion`. |
| `fecha_emision` | fecha y hora | No | Fecha/hora de emisión. |
| `fecha_expiracion` | fecha y hora | No | Fecha/hora de expiración. |
| `usado` | booleano | No | Marca de token consumido. |
| `fecha_uso` | fecha y hora | Sí | Fecha/hora en que se usó. |

- Solo se almacena el hash; el token en claro viaja únicamente en el enlace del correo.
- Es de un solo uso: al consumirse se marca `usado = true`. Emitir uno nuevo invalida los anteriores vigentes del mismo propósito.
- La vigencia se toma de `seguridad_parametros.token_vigencia_minutos`.

### 4.12 `usuario_2fa`

Configuración del segundo factor (app de autenticación, TOTP) por usuario. Una fila por usuario.

| Columna | Tipo | Nulidad | Descripción |
| --- | --- | --- | --- |
| `idusuario_2fa` | `BIGINT` | No | Clave primaria. |
| `idusuario` | `BIGINT` | No | Usuario al que pertenece la configuración. |
| `secreto` | `VARCHAR(255)` | No | Secreto TOTP, almacenado **cifrado** (no en claro). |
| `habilitado` | booleano | No | Si el segundo factor está activo; refleja `usuarios.doble_factor_habilitado`. |
| `fecha_activacion` | fecha y hora | Sí | Fecha/hora de alta del segundo factor. |
| `fecha_desactivacion` | fecha y hora | Sí | Fecha/hora de la última desactivación. |
| `ultimo_contador` | `BIGINT` | Sí | Último intervalo TOTP aceptado, para impedir reutilizar un código. |

Reglas:

- El `secreto` TOTP se guarda cifrado con la clave de aplicación y **nunca** se devuelve a la interfaz ni se registra en bitácora; solo se muestra una vez al activar (QR).
- Solo existe una fila vigente por usuario; desactivar y reactivar actualiza la fila.
- `habilitado` y `usuarios.doble_factor_habilitado` deben coincidir; el procedimiento los mantiene sincronizados.

### 4.13 `usuario_2fa_codigo_recuperacion`

Códigos de recuperación de un solo uso, generados al activar el 2FA.

| Columna | Tipo | Nulidad | Descripción |
| --- | --- | --- | --- |
| `idusuario_2fa_codigo_recuperacion` | `BIGINT` | No | Clave primaria. |
| `idusuario` | `BIGINT` | No | Usuario propietario. |
| `codigo_hash` | `VARCHAR(255)` | No | Hash del código de recuperación. Nunca en claro. |
| `usado` | booleano | No | Marca de código consumido. |
| `fecha_uso` | fecha y hora | Sí | Fecha/hora en que se usó. |

- Se generan al activar el 2FA (cantidad = `seguridad_parametros.doble_factor_codigos_recuperacion`).
- Cada código es de un solo uso; al usarse se marca `usado = true`.
- Regenerar los códigos invalida los anteriores.

### 4.14 `usuario_acceso_log`

Registro de eventos de acceso (auditoría).

| Columna | Tipo | Nulidad | Descripción |
| --- | --- | --- | --- |
| `idusuario_acceso_log` | `BIGINT` | No | Clave primaria. |
| `idusuario` | `BIGINT` | Sí | Usuario involucrado; `NULL` si el login no identificó usuario. |
| `usuario_login_intento` | `VARCHAR(80)` | Sí | Login ingresado en el intento. |
| `evento` | `VARCHAR(40)` | No | `login_ok`, `login_fallido`, `bloqueo`, `logout`, `password_definida`, `password_cambiada`, `password_recuperada`, `token_emitido`, `token_invalido`, `sesion_invalidada`, `2fa_activado`, `2fa_desactivado`, `2fa_ok`, `2fa_fallido`, `2fa_codigo_recuperacion_usado`. |
| `motivo` | `VARCHAR(255)` | Sí | Detalle del evento (por ejemplo, causa del fallo). |
| `ip` | `VARCHAR(45)` | Sí | Dirección IP de origen (soporta IPv6). |
| `agente` | `VARCHAR(255)` | Sí | `User-Agent`. |
| `fecha_hora` | fecha y hora | No | Momento del evento, en UTC. |

- Es de solo-anexado: no se actualiza ni se elimina desde la aplicación.
- Es una tabla técnica de solo-anexado: no lleva las columnas estándar de auditoría (`activo`, `eliminado`, etc.), igual que `app_db.bitacora`.
- No guarda contraseñas ni tokens; solo referencias y metadatos.
- `usuario_acceso_log` es distinto de `app_db.bitacora`: la bitácora registra cambios de datos; este log registra eventos de acceso.

### 4.15 `opcion_uso_log`

Registro de uso de opciones (auditoría funcional).

| Columna | Tipo | Nulidad | Descripción |
| --- | --- | --- | --- |
| `idopcion_uso_log` | `BIGINT` | No | Clave primaria. |
| `idusuario` | `BIGINT` | No | Usuario que ejecutó la opción. |
| `idopcion` | `BIGINT` | No | Opción ejecutada. |
| `metodo` | `VARCHAR(10)` | No | Método HTTP (`GET`, `POST`, ...). |
| `ruta` | `VARCHAR(255)` | No | Ruta invocada. |
| `parametros` | `VARCHAR(1000)` | Sí | Parámetros relevantes de la invocación, ya filtrados. |
| `resultado` | `VARCHAR(20)` | No | Resultado (`ok`, `error`, `denegado`). |
| `codigo_http` | entero | Sí | Código HTTP devuelto. |
| `duracion_ms` | entero | Sí | Duración de la operación en milisegundos. |
| `fecha_hora` | fecha y hora | No | Momento de la invocación, en UTC. |

- Es de solo-anexado.
- Es una tabla técnica de solo-anexado: no lleva las columnas estándar de auditoría (`activo`, `eliminado`, etc.), igual que `app_db.bitacora`.
- No incluye datos sensibles ni cuerpos completos de petición; los parámetros se registran filtrados.
- Sirve para auditar uso, frecuencias y patrones por usuario y opción.

---

## 5. Herencia y evaluación del acceso

### 5.1 Herencia

El acceso se concede a nivel de **opción**. A partir de ahí:

- Tener una opción concede acceso a la **carpeta** que la contiene (la carpeta se muestra si tiene al menos una opción accesible).
- Tener al menos una opción en un módulo concede acceso al **módulo** (aparece en el selector).
- No existe herencia hacia abajo: tener acceso al módulo **no** concede todas sus opciones.

### 5.2 Acceso efectivo de un usuario

```text
opciones(usuario) = unión de opciones de todos sus roles activos
carpetas(usuario) = carpetas que contienen al menos una opción de opciones(usuario)
modulos(usuario)  = módulos que contienen al menos una carpeta de carpetas(usuario)
```

- Solo se consideran roles activos y no eliminados, y opciones/carpetas/módulos activos y no eliminados.
- Si un usuario no tiene ningún rol activo con opciones, no tiene acceso a ninguna pantalla.

### 5.3 Reglas de autorización

- **Ruta web**: se resuelve el módulo y la opción; si el usuario no tiene la opción concedida, responde `403`.
- **Fragmento** (`X-App-Navigation: fragment`): mismas validaciones que la carga completa; sin permiso responde `403` como fragmento de error.
- **Servicio API**: el `wservice` verifica que el usuario tenga la opción asociada a la acción solicitada; si no, responde `403` JSON.
- **Menú**: se construye solo con opciones/carpetas/módulos autorizados.
- La autorización se evalúa en servidor en cada petición; no se confía en el menú ya renderizado ni en el estado del cliente.

### 5.4 Correspondencia con el código

- `modulos.modulo_nombre` ↔ carpeta `modules/<modulo>/`.
- `opciones.opcion_call` (`"<modulo>/<opcion>"`) ↔ opción declarada en `modules/<modulo>/router.php` (o en `router_api.php` para servicios). La clave `opcion` de `opcion_call` es la misma que resuelve el router.
- El código declara **qué** rutas existen; la base declara **quién** puede usarlas y con qué `opcion_parametros` se cargan.
- Una misma `opcion_call` puede repetirse en varias filas de `opciones` con distinto `opcion_nombre` y `opcion_parametros`; el router resuelve una sola ruta y la base distingue la variante por los parámetros de carga.
- Una ruta de código sin fila de opción en la base no es accesible a usuarios normales (salvo rutas públicas declaradas `auth => false`, como login).
- Una opción en base sin ruta de código es un error de datos; se detecta al construir el menú y se registra en el log.

### 5.5 Enrutamiento y parámetros de carga

- El enrutamiento usa exclusivamente `opcion_call` (`"<modulo>/<opcion>"`); `opcion_grupo_accion`, `opcion_accion` y `opcion_parametros` no intervienen en la resolución de la ruta.
- Al cargar una opción, la aplicación compone la navegación con `opcion_call` y adjunta `opcion_parametros` como query string de carga, por ejemplo `opcion_call = "ventas/pedido"` y `opcion_parametros = "vista=resumen&filtrar=activo"` producen la navegación a `/ventas/pedido?vista=resumen&filtrar=activo`.
- Los parámetros de carga son **valores por defecto de apertura**; el usuario puede modificarlos navegando (los filtros vivos viven en la URL de navegación, no en la base).
- `opcion_parametros` se valida y decodifica antes de usarse; sus valores nunca se concatenan en SQL ni en rutas de archivo.
- `opcion_grupo_accion` y `opcion_accion` alimentan el análisis de riesgo y las matrices de riesgo; no alteran el enrutamiento ni la autorización de la opción.

---

## 6. Integración con la navegación

Este modelo **reemplaza** la construcción del menú a partir de `module.php` y de metadatos `menu` en `router.php` descrita en [`pantallas.md`](pantallas.md) §5.

- El árbol de navegación (módulos → carpetas → opciones) proviene de `app_db`.
- `system\Menu` deja de leer manifiestos de archivo y consulta el acceso del usuario a través de un `wservice` del módulo `system` (por ejemplo, `System\WServices\AccesoService`).
- El JSON de bootstrap y el menú renderizado en servidor se construyen con el árbol autorizado; el contrato de [`pantallas.md`](pantallas.md) §5.3 se mantiene, cambiando solo su origen.
- Los metadatos de presentación que eran de archivo (`label`, `order`, `icon`) pasan a columnas de la base: `carpeta_nombre`/`carpeta_orden`, `opcion_nombre`/`opcion_orden`. El icono y otros atributos visuales pueden agregarse a `opciones` cuando se definan (§11).
- La selección de módulo, la opción por defecto y el orden se derivan de la base y no de `module.php`.

> Nota: mientras no se implemente el acceso en base, `pantallas.md` §5 sigue vigente como referencia transitoria. Al implementar este documento, esa sección debe actualizarse o retirarse.

---

## 7. Ciclo de vida de la cuenta y autenticación

La aplicación está orientada a la **auditoría y la revisión**: cada evento de acceso y cada uso de opción se registra, y las credenciales siguen políticas de seguridad administrables.

### 7.1 Alta de usuario

- Al crear un usuario, el administrador define nombre, correo, login y roles. **No define contraseña.**
- El sistema crea el usuario con `usuario_password = NULL`, `activo` según corresponda y `bloqueado = false`.
- Se emite un **token de activación** (`usuario_token`, `proposito = activacion`) y se envía por correo un enlace para que el usuario defina su contraseña en el primer acceso.
- Hasta que el usuario define su contraseña, no puede iniciar sesión; el intento devuelve un mensaje genérico orientándolo a activar la cuenta.
- El token se envía solo por correo, con vigencia limitada (`token_vigencia_minutos`). Se guarda únicamente su hash.
- El alta y la emisión del token quedan en `usuario_acceso_log` (`token_emitido`) y en bitácora (alta del usuario).

### 7.2 Primer acceso: definición de contraseña

1. El usuario abre el enlace `GET /system/password/definir?token=<token>`.
2. La aplicación valida el token: existe, `usado = false`, no expirado y del propósito correcto. Un token inválido o vencido responde con un error genérico y sugiere solicitar un nuevo enlace.
3. El usuario ingresa la nueva contraseña; se validan las reglas de §7.7.
4. Al aceptar: se guarda `usuario_password` (hash), `fecha_ultimo_cambio_password`, se registra el hash en `password_historial`, se marca el token como `usado = true` y se registra `password_definida` en `usuario_acceso_log`.
5. El usuario ya puede iniciar sesión.

### 7.3 Recuperación de contraseña

- Si el usuario olvida su contraseña o está bloqueado, solicita un enlace en `POST /system/password/solicitar`. La respuesta es **siempre genérica**, exista o no la cuenta, para no revelar usuarios.
- Si la cuenta existe, se emite un token (`proposito = recuperacion`), se envía por correo y se invalida cualquier token vigente anterior del mismo usuario.
- El enlace `GET /system/password/recuperar?token=<token>` usa el mismo flujo de validación y las mismas reglas que §7.2.
- Al completar la recuperación: se guarda la nueva contraseña, se limpia el bloqueo (`bloqueado = false`, `intentos_fallidos = 0`, `fecha_bloqueo = NULL`) y se registra `password_recuperada`.
- Recuperar la contraseña **desbloquea** al usuario bloqueado por intentos fallidos.

### 7.4 Inicio de sesión y token de acceso

1. El usuario envía login y contraseña a `POST /system/login`.
2. Se validan las condiciones de la cuenta: `activo`, no eliminado, no vencida, `bloqueado = false` y con contraseña definida.
3. Se verifica el hash en PHP (`password_verify`).
4. Si la cuenta tiene el segundo factor habilitado, **no se emite todavía el token de acceso**: se pasa al estado "pendiente de 2FA" y se resuelve según §7.9 antes de continuar.
5. En caso favorable:
   - Se **regenera** `usuario_token_acceso` (nuevo valor aleatorio), se guarda su hash y `fecha_token_acceso`.
   - Se reinician `intentos_fallidos = 0` y `fecha_bloqueo = NULL`.
   - Se regenera el identificador de sesión PHP.
   - Se registra `login_ok` en `usuario_acceso_log`.
6. En caso desfavorable:
   - Se incrementa `intentos_fallidos` y se actualiza `fecha_ultimo_intento`.
   - Se registra `login_fallido`.
   - Se responde con mensaje genérico, sin revelar si el usuario existe.

**El token como validación de las llamadas a los `wservices`:**

- El `usuario_token_acceso` vigente es el valor que autentica las llamadas a la API/`wservices` (en cabecera, no en la cookie de sesión). `Auth::validateRequest()` lo compara contra el token almacenado (hash) del usuario.
- **Un solo token vigente por usuario.** Si el usuario inicia sesión en otro dispositivo, se genera un token nuevo y el anterior queda inválido de inmediato: las llamadas del primer acceso pasan a recibir `401`.
- Al cerrar sesión se anula `usuario_token_acceso` y se registra `logout`.
- Si la sesión/token supera `sesion_vigencia_minutos`, se considera expirada y se exige reautenticación.

### 7.5 Cierre de sesión

- `POST /system/logout` (con CSRF) anula `usuario_token_acceso`, destruye la sesión PHP y registra `logout`.
- El cierre de sesión nunca es un `GET` que cambie estado.

### 7.6 Intentos fallidos y bloqueo

- Cada login fallido incrementa `intentos_fallidos`.
- Al alcanzar `intentos_maximos` (de `seguridad_parametros`), se marca `bloqueado = true` y `fecha_bloqueo`.
- Mientras esté bloqueado, el usuario no puede iniciar sesión aunque use la contraseña correcta; se registra `bloqueo`.
- El bloqueo se libera únicamente mediante la **recuperación de contraseña** (§7.3) o por acción administrativa con la opción correspondiente (que también queda en bitácora).
- Un inicio de sesión exitoso reinicia el contador.

### 7.7 Políticas de seguridad de contraseñas

Los parámetros viven en `seguridad_parametros` (§4.10) y se aplican en la definición, el cambio y la recuperación:

| Parámetro | Regla |
| --- | --- |
| `password_largo_minimo` / `password_largo_maximo` | Longitud permitida de la contraseña. |
| `password_duracion_dias` | Vigencia; al vencer, el login exige cambiarla. `0` = sin caducidad. |
| `password_historial` | No se permite repetir ninguna de las últimas N contraseñas (se comparan contra `password_historial`). |
| `token_vigencia_minutos` | Vigencia de los tokens de activación/recuperación. |
| `sesion_vigencia_minutos` | Vigencia del token de acceso/sesión. |

- La comparación de reutilización se hace en PHP con `password_verify` contra los hashes del historial.
- Si la contraseña está vencida, el login es exitoso pero fuerza el cambio antes de permitir el uso de la app.
- Las reglas de composición (mayúsculas, números, símbolos) se agregan cuando se definan; quedan como decisión abierta (§11).

### 7.8 Auditoría de acceso y de uso

La app prioriza la auditoría:

- **Acceso:** todo evento de autenticación se registra en `usuario_acceso_log` (§4.14): login correcto/fallido, bloqueo, logout, definición/cambio/recuperación de contraseña, emisión y rechazo de tokens, activación/uso del segundo factor e invalidación de sesión.
- **Uso:** cada invocación de una opción o servicio se registra en `opcion_uso_log` (§4.15) con usuario, opción, método, ruta, resultado y duración.
- Ambos logs son de solo-anexado, sin actualización ni borrado desde la aplicación, y no contienen contraseñas ni tokens.
- El registro de uso no debe filtrar datos sensibles; los parámetros se guardan filtrados.
- La consulta de estos logs se expone con permisos restringidos mediante procedimientos y opciones dedicadas.

### 7.9 Segundo factor (app de autenticación)

El segundo factor es **opcional por defecto**: cada usuario puede activarlo o desactivarlo desde su perfil. El administrador puede volverlo **obligatorio** con `seguridad_parametros.doble_factor_exigido`.

**Alcance**

- El segundo factor usa **TOTP** (app de autenticación: Google Authenticator, Authy, etc.), compatible con `otpauth://`.
- Afecta al **inicio de sesión**; las llamadas a `wservices` siguen autenticándose con el token de acceso (§7.4).
- Se apoya en `usuario_2fa` (§4.12) y `usuario_2fa_codigo_recuperacion` (§4.13).

**Activación (opt-in por el usuario)**

1. El usuario abre la pantalla de seguridad de su perfil y elige activar el segundo factor.
2. El sistema genera un secreto TOTP, lo guarda cifrado y muestra el `otpauth://` (QR y clave manual) **solo en ese momento**.
3. El usuario ingresa un código para confirmar; al validarlo, se marca `habilitado = true`, se sincroniza `usuarios.doble_factor_habilitado`, se registra `fecha_activacion` y se generan los códigos de recuperación (una sola vez, para que los guarde).
4. Se registra `2fa_activado` en `usuario_acceso_log`.

**Desactivación**

- El usuario puede desactivar el segundo factor desde su perfil; para hacerlo debe confirmar su contraseña (y un código TOTP vigente si ya está activo).
- Al desactivar: `habilitado = false`, se sincroniza `usuarios.doble_factor_habilitado`, se registra `fecha_desactivacion`, se invalidan el secreto y los códigos de recuperación, y se registra `2fa_desactivado`.
- Si `doble_factor_exigido = true`, un usuario no puede desactivarlo; solo un administrador puede liberarlo con la opción correspondiente (queda en bitácora).

**Inicio de sesión con segundo factor**

1. Tras validar login y contraseña (§7.4), si el usuario tiene el 2FA habilitado, **no se emite aún el token de acceso**: la sesión queda en estado intermedio "pendiente de 2FA".
2. El usuario ingresa el código TOTP (o un código de recuperación). El servidor lo valida contra el secreto de `usuario_2fa` (o contra `usuario_2fa_codigo_recuperacion`); el `ultimo_contador` evita reutilizar un mismo código.
3. Si es válido: se emite el token de acceso (§7.4), se marca `usado = true`/`fecha_uso` según corresponda y se registra `2fa_ok`.
4. Si es inválido: se cuenta como intento fallido (§7.6) y se registra `2fa_fallido`; tras `intentos_maximos` la cuenta se bloquea.
5. Un código de recuperación usado se marca como consumido y se registra `2fa_codigo_recuperacion_usado`.

**Códigos de recuperación**

- Se entregan una sola vez al activar y se guardan **hasheados**.
- Sirven para iniciar sesión cuando el usuario pierde el dispositivo, y son de un solo uso.
- El usuario puede regenerarlos desde su perfil (previo confirmar contraseña); regenerar invalida los anteriores.
- Se generan `seguridad_parametros.doble_factor_codigos_recuperacion` códigos.

**Recuperación de acceso**

- Si el usuario pierde el dispositivo y los códigos, un administrador, con la opción correspondiente y validación reforzada, puede **desactivar el 2FA** del usuario para permitirle reconfigurarlo, dejando constancia en bitácora y en `usuario_acceso_log`.
- El secreto TOTP, los códigos de recuperación y `ultimo_contador` **nunca** se devuelven a la interfaz ni se incluyen en bitácora (§8).

### 7.10 Reglas generales

- Toda consulta de autenticación pasa por procedimientos de `app_db`; nunca se consultan tablas directamente desde PHP (ver [`base-de-datos.md`](base-de-datos.md) §5.3).
- La verificación de hashes ocurre en PHP; los procedimientos solo entregan datos de estado y hashes.
- Los correos se envían a través del servicio `Mail`; el enlace nunca incluye la contraseña, solo el token.
- Un administrador no puede ver ni definir la contraseña de otro usuario; solo emitir tokens de recuperación.

---

## 8. Seguridad

- La estructura de acceso se consulta mediante procedimientos de `app_db`; la aplicación no consulta tablas directamente.
- `opcion_call` y `opcion_parametros` se validan contra lista blanca/patrón. `opcion_parametros` se trata como cadena no confiable.
- `usuario_password`, `usuario_token_acceso`, `token_hash` y los hashes de `password_historial` no se devuelven a la interfaz ni se registran en bitácora; se excluyen o enmascaran en los snapshots.
- Los tokens de acceso, activación y recuperación se guardan **hasheados**; el valor en claro solo existe en memoria o en el enlace del correo.
- El secreto TOTP (`usuario_2fa.secreto`) se guarda **cifrado**; los códigos de recuperación, hasheados. Ninguno se expone ni se registra en bitácora.
- El estado "pendiente de 2FA" no otorga acceso a ninguna opción ni permite emitir token de acceso hasta completar el segundo factor.
- Un solo token de acceso vigente por usuario: iniciar sesión en otro dispositivo invalida el anterior.
- Las contraseñas se verifican siempre en PHP con `password_verify`; nunca se comparan en SQL.
- Las políticas de §7.7 (largo, duración, historial, intentos) se aplican en servidor; el cliente no decide.
- Las respuestas de login y de solicitud de recuperación son genéricas para no revelar la existencia de cuentas.
- Un usuario no puede modificar sus propios roles ni los de otros desde la aplicación sin la opción correspondiente.
- La autorización se evalúa en servidor en cada petición, fragmento y llamada API.
- Los errores de permiso no revelan si la opción existe: responde `403` de forma uniforme.
- Los logs de acceso y uso (`usuario_acceso_log`, `opcion_uso_log`) son de solo-anexado y no contienen secretos.
- Los cambios en la estructura de acceso y en los parámetros de seguridad quedan en bitácora.

---

## 9. Procedimientos previstos

Nombres propuestos (nomenclatura `usp_<modulo>_<accion>` de [`base-de-datos.md`](base-de-datos.md) §8.3). El módulo dueño de estas tablas es `system` sobre `app_db`.

| Procedimiento | Propósito |
| --- | --- |
| `usp_system_usuario_autenticar` | Devuelve usuario y hash para validar credenciales. |
| `usp_system_usuario_por_id` | Datos base de un usuario. |
| `usp_system_usuario_listar` | Listado paginado de usuarios. |
| `usp_system_usuario_crear` | Alta de usuario **sin contraseña**. |
| `usp_system_usuario_actualizar` | Modificación de usuario. |
| `usp_system_usuario_baja` | Baja lógica con `fecha_dado_baja` y `motivo_baja`. |
| `usp_system_usuario_restaurar` | Restauración de una baja. |
| `usp_system_usuario_password_definir` | Primer acceso: define contraseña y fecha. |
| `usp_system_usuario_password_cambiar` | Cambio de contraseña por el usuario. |
| `usp_system_usuario_password_recuperar` | Recuperación de contraseña y desbloqueo. |
| `usp_system_usuario_password_historial_verificar` | Devuelve los hashes recientes para impedir repetición. |
| `usp_system_usuario_password_historial_registrar` | Agrega el hash al historial y poda los antiguos. |
| `usp_system_usuario_intento_registrar` | Incrementa `intentos_fallidos` y aplica bloqueo. |
| `usp_system_usuario_bloqueo_limpiar` | Reinicia intentos y libera el bloqueo. |
| `usp_system_usuario_token_acceso_renovar` | Emite un nuevo token de sesión e invalida el anterior. |
| `usp_system_usuario_token_acceso_anular` | Anula el token de sesión (logout/invalidación). |
| `usp_system_usuario_token_emitir` | Emite un token de activación/recuperación. |
| `usp_system_usuario_token_validar` | Valida y consume un token de un solo uso. |
| `usp_system_2fa_activar` | Genera/registra secreto cifrado y habilita el 2FA. |
| `usp_system_2fa_desactivar` | Deshabilita el 2FA e invalida secreto y códigos. |
| `usp_system_2fa_obtener` | Devuelve el secreto cifrado y el estado del 2FA de un usuario. |
| `usp_system_2fa_ultimo_contador_actualizar` | Registra el último intervalo TOTP aceptado. |
| `usp_system_2fa_codigos_recuperacion_generar` | Regenera los códigos (hashes) de recuperación. |
| `usp_system_2fa_codigo_recuperacion_validar` | Valida y consume un código de recuperación. |
| `usp_system_usuario_roles_listar` | Roles de un usuario. |
| `usp_system_usuario_roles_asignar` | Asignación de roles. |
| `usp_system_acceso_usuario` | Árbol autorizado (módulos/carpetas/opciones) de un usuario. |
| `usp_system_acceso_opcion_verificar` | Verifica si un usuario tiene una opción. |
| `usp_system_seguridad_parametros_obtener` | Lee la política de seguridad vigente. |
| `usp_system_seguridad_parametros_actualizar` | Modifica la política de seguridad. |
| `usp_system_acceso_log_registrar` | Registra un evento en `usuario_acceso_log`. |
| `usp_system_acceso_log_consultar` | Consulta paginada del log de acceso. |
| `usp_system_opcion_uso_log_registrar` | Registra el uso de una opción. |
| `usp_system_opcion_uso_log_consultar` | Consulta paginada del uso de opciones. |
| `usp_system_modulo_listar`/`crear`/`actualizar`/`baja` | Gestión de módulos. |
| `usp_system_carpeta_listar`/`crear`/`actualizar`/`baja` | Gestión de carpetas. |
| `usp_system_opcion_listar`/`crear`/`actualizar`/`baja` | Gestión de opciones. |
| `usp_system_rol_listar`/`crear`/`actualizar`/`baja` | Gestión de roles. |
| `usp_system_rol_opciones_listar`/`asignar`/`quitar` | Permisos de un rol. |

- Los procedimientos los diseña y entrega el encargado de base de datos.
- Todo procedimiento de escritura registra bitácora y usa transacción.
- Los procedimientos de log son de solo-anexado y no actualizan ni eliminan filas.

---

## 10. Criterios de aceptación

- [ ] `app_db` contiene las tablas `app`, `modulos`, `carpetas`, `opciones`, `roles`, `usuarios` y sus tablas de asociación.
- [ ] Toda opción está asociada a una carpeta; toda carpeta, a un módulo.
- [ ] Un usuario sin rol con la opción concedida recibe `403` en ruta, fragmento y API.
- [ ] El menú y el selector de módulos se construyen solo con módulos/carpetas/opciones autorizados.
- [ ] Conceder una opción concede acceso a su carpeta y a su módulo, pero no a las demás opciones.
- [ ] Las contraseñas, tokens e historial se almacenan hasheados y nunca se exponen ni se registran en bitácora.
- [ ] Un usuario creado sin contraseña la define en el primer acceso mediante un token enviado por correo.
- [ ] La recuperación de contraseña emite un token nuevo, invalida el anterior y desbloquea al usuario.
- [ ] Se aplican las políticas de largo, duración, historial e intentos definidas en `seguridad_parametros`.
- [ ] El login renueva `usuario_token_acceso`; iniciar sesión en otro dispositivo invalida el token anterior (`401`).
- [ ] El token de acceso es el valor que autentica las llamadas a los `wservices`.
- [ ] El usuario puede activar y desactivar el segundo factor TOTP; el administrador puede exigirlo para todos.
- [ ] Con 2FA activo, el login no emite token de acceso hasta validar el código TOTP o un código de recuperación.
- [ ] El secreto TOTP se guarda cifrado y los códigos de recuperación, hasheados; ninguno se expone ni se registra en bitácora.
- [ ] Todo evento de acceso queda en `usuario_acceso_log` y todo uso de opción en `opcion_uso_log`.
- [ ] La aplicación no mantiene listas paralelas de módulos, carpetas u opciones.
- [ ] El enrutamiento usa `opcion_call` en formato `"<modulo>/<opcion>"` y no depende de los demás campos de la opción.
- [ ] Varias opciones pueden compartir `opcion_call` diferenciándose por `opcion_parametros`, y la navegación respeta esos parámetros de carga.
- [ ] `opcion_grupo_accion` y `opcion_accion` se usan para análisis de riesgo y no alteran el enrutamiento.
- [ ] Los cambios en la estructura de acceso y en los parámetros de seguridad quedan en bitácora.
- [ ] Las consultas de acceso se hacen por procedimientos de `app_db`, sin SQL directo en PHP.

---

## 11. Decisiones abiertas

1. **Jerarquía de roles**: roles planos (propuesto) vs. roles que heredan de otros roles.
2. **`opcion_call`** (decidido): formato `"<modulo>/<opcion>"`, validado con `^[a-z][a-z0-9_-]*$`; queda por definir si además se contrasta contra las rutas declaradas en `router.php`/`router_api.php`.
3. **`opcion_parametros`** (decidido): query string `<variable>=<valor>&...`. Queda por definir la validación y el enmascarado de variables sensibles.
4. **`opcion_grupo_accion` / `opcion_accion`**: catálogo abierto para análisis de riesgo. Se definirá **después** de crear los módulos y opciones principales, cuando existan datos reales que clasificar; hasta entonces estos campos quedan como texto libre y no bloquean altas.
5. **Metadatos visuales**: dónde guardar icono, color y visibilidad de cada opción.
6. **Configuración en `app`**: qué características se administran desde la base y cuáles desde `.env`.
7. **Multiplicidad de `app`**: una fila única vs. varias instancias/entornos en la misma base.
8. **Opción por defecto del módulo**: columna en `modulos` o primera opción por `opcion_orden`.
9. **Permisos por acción**: si `opcion_accion` define permisos más finos que la opción completa.
10. **Roles de sistema**: rol administrador, rol de solo lectura, etc. y cómo se protegen.
11. **Auditoría de accesos denegados**: si además de bitácora de cambios se registran intentos rechazados (propuesto: sí, vía `usuario_acceso_log`/`opcion_uso_log`).
12. **Cache del árbol de acceso**: en Redis y con qué invalidación.
13. **Reglas de composición de contraseña** (mayúsculas, números, símbolos) además del largo, duración e historial.
14. **Algoritmo de hash** de contraseñas y de tokens.
15. **Vigencia de sesión/token**: valor por defecto de `sesion_vigencia_minutos` y su renovación deslizante.
16. **Verificación de correo** en la activación y recuperación, y plantilla de correo.
17. **Modelo de parámetros de seguridad**: una fila con columnas vs. clave/valor.
18. **Retención y purga de `usuario_acceso_log` y `opcion_uso_log`**.
19. **Confirmación de 'un solo token por usuario'** frente a escenarios multidispositivo legítimos.
20. **Segundo factor**: TOTP propuesto (decidido); queda por definir la longitud/formato de los códigos de recuperación, si se admiten varios dispositivos 2FA por usuario y el mecanismo de cifrado del secreto.
21. **Obligatoriedad del 2FA**: por defecto opcional por usuario (`doble_factor_exigido = false`); confirmar si algún rol de sistema lo exige siempre.
22. **Recordar dispositivo**: si se ofrece "confiar en este navegador" para no pedir TOTP cada vez.

---

## 12. Referencias

- [`arquitectura.md`](arquitectura.md): arquitectura general, rutas, API y autenticación.
- [`base-de-datos.md`](base-de-datos.md): columnas estándar, borrado lógico, bitácora y procedimientos.
- [`pantallas.md`](pantallas.md): shell, menú y navegación (su §5 queda sujeto a este documento).
- [`AGENTS.md`](../../AGENTS.md): reglas de trabajo y convenciones.
- [`README.md`](../../README.md): inicio rápido y estado del proyecto.
