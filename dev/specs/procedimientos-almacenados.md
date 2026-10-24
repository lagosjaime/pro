# Especificación de procedimientos almacenados — Aplicación `pr`

| Campo | Valor |
| --- | --- |
| Versión | 0.1 (borrador) |
| Fecha | 2026-10-24 |
| Estado | Para revisión e implementación |
| Alcance | Nomenclatura, contrato de respuesta, parámetros, transacciones, bitácora y uso desde `wservices` |
| Documentos relacionados | [`arquitectura.md`](arquitectura.md), [`base-de-datos.md`](base-de-datos.md), [`control-acceso.md`](control-acceso.md), [`despliegue-wservices.md`](despliegue-wservices.md), [`catalogo-procedimientos.md`](catalogo-procedimientos.md), [`AGENTS.md`](../../AGENTS.md) |

> Todos los procedimientos almacenados que se creen para esta aplicación deberán seguir obligatoriamente esta especificación. El acceso a datos desde PHP **únicamente** se realizará mediante la invocación de estos procedimientos a través de `Db::exec()` con nombre calificado.

---

## 1. Objetivo

Estandarizar la forma en que se nombran, estructuran y devuelven resultados los procedimientos almacenados.

---

## 2. Nomenclatura

Todo procedimiento almacenado deberá seguir la siguiente estructura:

```text
ps_<accion>_<tabla_principal_afectada_o_proceso_afectado>[_<nombre_complementario>]
```

### 2.1 Acciones permitidas

| Acción | Significado | Uso |
| --- | --- | --- |
| `sel` | `SELECT` / Consulta | Procedimientos **únicamente** de lectura. Devuelven el conjunto de datos solicitado. |
| `ins` | `INSERT` | Procedimientos de inserción. |
| `upd` | `UPDATE` | Procedimientos de actualización. |
| `del` | `DELETE` / Baja lógica | Procedimientos de eliminación. Siempre deberá usarse para **baja lógica** (`eliminado = true`) salvo justificación documentada. **Nunca** para `DELETE` físico. |

### 2.2 Reglas para el nombre

- Todo en **minúsculas**, con guiones bajos `_`.
- Se debe evitar el prefijo `sp_`.
- El nombre debe ser corto, descriptivo y autoexplicativo.

### 2.3 Ejemplos

| Procedimiento | Descripción |
| --- | --- |
| `ps_sel_usuario_por_id` | Consulta un usuario por su `id`. |
| `ps_sel_menu_por_usuario` | Consulta el árbol de menú autorizado para un usuario. |
| `ps_ins_opcion` | Inserta una nueva opción. |
| `ps_upd_opcion` | Actualiza una opción. |
| `ps_del_opcion` | Baja lógica de una opción. |

---

## 3. Contrato de respuesta

### 3.1 Procedimientos con acción `sel` (Consultas)

- **Obligatorio:** Deben retornar **únicamente el conjunto de datos solicitado** en forma de *result set*.
- **Sin `status`/`message` obligatorios** en el listado.
- **Un solo result set** siempre que sea posible.
- **Sin datos sensibles:** No deben devolver columnas sensibles como `usuario_password`, `usuario_token_acceso`, `secreto`, `codigo_hash`, `token_hash`, etc.

### 3.2 Procedimientos con acciones `ins`, `upd`, `del` (Escritura)

- **Obligatorio:** Deben retornar **al menos un *result set*** que contenga:

| Columna | Tipo | Requerido | Descripción |
| --- | --- | --- | --- |
| `status` | `VARCHAR/CHAR` | Sí | Valor `ok` o `error`. |
| `message` | `VARCHAR` | Sí | Mensaje claro y legible. |

- **Recomendado fuertemente:** Adicionalmente se recomienda retornar:
  - `id`: Para `ps_ins_*` con clave primaria autogenerada.
  - `idregistro_afectado`: Para `ps_upd_*` o `ps_del_*` sobre un registro específico.
  - `affected_rows`: Para operaciones que afecten uno o varios registros.

- **Transaccional:** Deben ejecutar dentro de transacción con `COMMIT`/`ROLLBACK`.
- **Bitácora obligatoria:** Para `ins`, `upd`, `del` debe registrarse en `app_db.bitacora` con snapshots antes/después según corresponda.
- **Mensajes amigables:** Nunca exponer errores crudos del motor al cliente.

---

## 4. Reglas generales

| Regla | Descripción |
| --- | --- |
| **Calificación de tablas** | **Obligatorio:** Toda tabla debe referenciarse como `<base_datos>.<tabla>`, **incluso si procedimiento y tabla están en la misma base de datos**. |
| **Parámetros** | Usar prefijo `p_` para entrada. |
| **Baja lógica** | Para `ps_del_*`, usar `UPDATE` con `eliminado = true`, `idusuario_eliminacion`, `fecha_hora_eliminacion`. |
| **Un solo result set** | Preferir un único result set. |
| **SET NOCOUNT ON** | Incluir en SQL Server. |
| **Mínimo privilegio** | Usuario solo con `EXECUTE` sobre procedimientos. |

---

## 5. Invocación desde PHP y calificación de tablas

### 5.1 Forma de llamada

Desde los `wservices` la invocación **únicamente** se realizará con una **única conexión** gestionada por `Db`:

```php
$result = DB::exec("app_db_ventas.ps_ins_pedido(?, ?, ?, ?, ?)", [
  $idcliente,
  $fecha_pedido,
  $observaciones,
  $idusuario_actualizacion,
  $aplicar_descuento_automatico
]);
```

**Incorrecto:**
```php
$db->connection('ventas')->call('ps_ins_pedido', [...]);
```

La clase `Db` parseará `<base_datos>.<procedimiento>`, validará contra el catálogo y aplicará auto-relleno con `NULL` si faltan parámetros posicionales.

### 5.2 Calificación obligatoria de tablas

Dentro de **todos** los procedimientos almacenados:

- Toda referencia a tabla debe ser `<base_datos>.<tabla>`
- Incluso si procedimiento y tabla están en la misma base
- Aplicar en `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `JOIN`, subconsultas, etc.
- No depender del esquema/base por defecto

**Ejemplo:**

```sql
CREATE PROCEDURE app_db_ventas.ps_ins_pedido(
  IN p_idcliente BIGINT,
  IN p_idusuario_actualizacion BIGINT,
  OUT o_idpedido BIGINT
)
BEGIN
  INSERT INTO app_db_ventas.pedido (idcliente, idusuario_actualizacion, activo, eliminado, fecha_hora_actualizacion)
  VALUES (p_idcliente, p_idusuario_actualizacion, 1, 0, NOW());

  SET o_idpedido = LAST_INSERT_ID();
END
```

---

## 6. Integración con `wservices`

- **Consumo directo**: Los `wservices` invocarán mediante `DB::exec()`
- **Interpretación**: Para `ps_sel_*` tomar filas. Para `ps_ins_*`, `ps_upd_*`, `ps_del_*` validar `status` y `message`
- **Propagación de usuario**: Pasar `p_idusuario` cuando el procedimiento lo requiera para auditoría
- **Transparente con caché**: Solo `ps_sel_*` cacheables. Escrituras nunca se cachean
