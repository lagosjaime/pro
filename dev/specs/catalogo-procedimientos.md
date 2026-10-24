# Especificación: Catálogo de procedimientos y auto-relleno de parámetros — Aplicación `pr`

| Campo | Valor |
| --- | --- |
| Versión | 0.1 (borrador) |
| Fecha | 2026-10-24 |
| Estado | Para revisión e implementación |
| Alcance | Catastro de procedimientos, validación de parámetros desde `Db`, auto-relleno con `NULL`, generación vía CLI |
| Documentos relacionados | [`arquitectura.md`](arquitectura.md), [`base-de-datos.md`](base-de-datos.md), [`procedimientos-almacenados.md`](procedimientos-almacenados.md), [`despliegue-wservices.md`](despliegue-wservices.md), [`AGENTS.md`](../../AGENTS.md) |

> Esta medida es puramente preventiva. El objetivo es evitar caídas en producción cuando, tras modificar un procedimiento añadiendo nuevos parámetros al final, existan llamadas ya en uso desde algún `wservice` que aún no hayan sido actualizadas.

---

## 1. Objetivo

- Mantener un **catastro único** con la cantidad exacta de parámetros esperados por cada procedimiento almacenado, su orden y metadatos.
- En la clase `Db`, al invocar `DB->exec()`, parsear el nombre calificado `<base_datos>.<procedimiento>` recibido desde el `wservice`.
- Comparar la cantidad enviada con la esperada por el catálogo.
- Si faltan parámetros, **rellenarlos automáticamente con `NULL`** hasta completar la cantidad esperada.
- Permitir la evolución controlada añadiendo parámetros **únicamente al final**.

---

## 2. Ubicación del catálogo

```text
dev/catalog/
└── procedimientos.json
```

- Obligatorio versionarlo en Git
- Generado, no editado a mano preferentemente
- Generado vía CLI

---

## 3. Estructura del archivo

El catálogo debe indexarse por el **nombre calificado completo** `<base_datos>.<procedimiento>`.

```json
{
  "version": 1,
  "generated_at": "2026-10-24T14:45:18Z",
  "generated_by": "cli:proc-catalog",
  "procedimientos": {
    "app_db.ps_ins_usuario": {
      "base": "app_db",
      "procedimiento": "ps_ins_usuario",
      "accion": "ins",
      "tabla": "usuario",
      "count": 4,
      "allow_null_fill": true,
      "params": [
        { "orden": 1, "nombre": "p_usuario_login", "nullable": true },
        { "orden": 2, "nombre": "p_usuario_correo", "nullable": true },
        { "orden": 3, "nombre": "p_usuario_nombre", "nullable": true },
        { "orden": 4, "nombre": "p_idusuario_creador", "nullable": true }
      ]
    },
    "app_db_ventas.ps_ins_pedido": {
      "base": "app_db_ventas",
      "procedimiento": "ps_ins_pedido",
      "accion": "ins",
      "tabla": "pedido",
      "count": 5,
      "allow_null_fill": true,
      "params": [
        { "orden": 1, "nombre": "p_idcliente", "nullable": true },
        { "orden": 2, "nombre": "p_fecha_pedido", "nullable": true },
        { "orden": 3, "nombre": "p_observaciones", "nullable": true },
        { "orden": 4, "nombre": "p_idusuario_actualizacion", "nullable": true },
        { "orden": 5, "nombre": "p_aplicar_descuento_automatico", "nullable": true }
      ]
    }
  }
}
```

| Campo | Descripción |
| --- | --- |
| `procedimientos` | Listado indexado por `<base_datos>.<procedimiento>` |
| `base` | Base de datos a la que pertenece el procedimiento |
| `procedimiento` | Nombre corto del procedimiento |
| `count` | Cantidad total de parámetros esperados |
| `allow_null_fill` | Permite auto-relleno con `NULL` si faltan parámetros |
| `params` | Solo para trazabilidad/documentación. El criterio es `count` |

---

## 4. Generación del catálogo

```bash
php bin/cli proc:catalog
# o
make proc-catalog
```

El generador escanea `dev/sql/procedures/<basedatos>/*.sql`, parsea `CREATE PROCEDURE`, extrae parámetros en orden, construye la clave `<basedatos>.<nombre>` y actualiza `dev/catalog/procedimientos.json`.

---

## 5. Comportamiento en la clase `Db`

**Forma de llamada desde los `wservices`:**

```php
$result = DB::exec("app_db_ventas.ps_ins_pedido(?, ?, ?, ?, ?)", [
  $idcliente,
  $fecha_pedido,
  $observaciones,
  $idusuario_actualizacion,
  // Falta p_aplicar_descuento_automatico si se agregó recientemente
]);
```

**Flujo:**

1. **Parsear**: Extraer `<base_datos>.<procedimiento>` de la cadena
2. **Normalizar**: Convertir parámetros a array posicional
3. **Buscar**: Localizar en `dev/catalog/procedimientos.json`
4. **Comparar**: `count(recibido)` vs `count(esperado)`
5. **Auto-relleno**: Si faltan y `allow_null_fill === true`, **añadir `NULL` ÚNICAMENTE al final** hasta igualar
6. **Advertir**: Si hay exceso, registrar advertencia
7. **Ejecutar**: `CALL <base_datos>.<procedimiento>(?, ..., ?)` con parámetros enlazados
8. **Trazar**: En desarrollo registrar `[DB][PARAMS_PADDED]` si hubo auto-relleno

**Reglas estrictas:**
- **Conexión única** - Un solo `PDO` para toda la aplicación
- **Nombre calificado obligatorio** - Siempre `"<base_datos>.<procedimiento>"`
- **Solo posicional**
- **Rellenar ÚNICAMENTE al final**
- **Solo con `NULL`**
- **Parámetros enlazados con PDO**
- **Agregar nuevos parámetros siempre al final**

---

## 6. Reglas para modificar procedimientos

| Regla | Explicación |
| --- | --- |
| **Agregar SIEMPRE al final** | Todo nuevo parámetro opcional debe ir como último en `CREATE PROCEDURE` |
| **Soportar `NULL`** | Usar `COALESCE`/`IFNULL` o lógica condicional |
| **No reordenar** | Prohibido reordenar parámetros existentes |
| **No eliminar parámetros** | Conservar en misma posición aunque no se use |
| **Calificar tablas siempre** | Toda tabla como `<base_datos>.<tabla>`, incluso misma base |
| **Actualizar catálogo** | Regenerar `dev/catalog/procedimientos.json` con `make proc-catalog` |
| **Documentar cambio** | Actualizar cabecera del archivo SQL |

---

## 7. Integración con logs

- **Desarrollo:** `[CTRL] [DB][PARAMS_PADDED] call:<base>.<proc> | expected:X | received:Y | filled:Z | values:[NULL]`
- **Producción:** Sin bloqueo, log discreto
- **Correlación:** Incluir `X-Request-Id` cuando esté disponible
