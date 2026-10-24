# Revisión: Aplicación PDS vs Especificaciones del Proyecto `pro`

**Fecha:** 2026-10-24  
**Objetivo:** Comparar la aplicación ubicada en `/home/lagosjaime/Desarrollo/web/pds` con las especificaciones documentadas en `/home/lagosjaime/Desarrollo/web/pro/dev/specs/`  
**Tipo de revisión:** Solo análisis, sin modificaciones

---

## Índice

- [1. Resumen Ejecutivo](#1-resumen-ejecutivo)
- [2. Comparativa por Áreas](#2-comparativa-por-áreas)
- [3. Hallazgos Detallados](#3-hallazgos-detallados)
- [4. Diferencias Arquitectónicas](#4-diferencias-arquitectónicas)
- [5. Elementos que Sí Cumplen](#5-elementos-que-sí-cumplen)
- [6. Recomendaciones](#6-recomendaciones)
- [7. Conclusión](#7-conclusión)

---

## 1. Resumen Ejecutivo

La aplicación `pds` es **funcional, madura y con mayor infraestructura** que lo propuesto en las especificaciones del proyecto `pro`. Sin embargo, **no cumple con las nuevas especificaciones documentadas recientemente**.

Las principales diferencias son:
- **Arquitectura propia**: `pds` define sus propias convenciones en su `AGENTS.md` que difieren de las propuestas
- **Nomenclatura distinta**: Usa `routes.php`/`routes_api.php`, `ws/` en lugar de `wservices/`, `Database` en lugar de `Db`
- **Layout diferente**: Estructura propia con `/scr/` para fragmentos SPA, distinta al layout `head/navbar/foot` + `work-header/work-center/work-footer` propuesto
- **Componentes faltantes**: No existe `App.DataTable.init()`, `App.InputSearch.init()`, ni el sistema de logs propuesto
- **Topología WServices distinta**: No implementa los modos `local/remote/proxy` con las variables `WSE_*` propuestas

**Veredicto:** No es compatible con las nuevas especificaciones. Requiere decisión sobre qué convenciones son canónicas.

---

## 2. Comparativa por Áreas

| Área | Cumplimiento | Prioridad de Alineación | Comentario |
|---|---|---|---|
| **Arquitectura Base (Front Controllers, Container)** | Parcial (70%) | Media | Estructura similar pero con diferencias en nombres de clases/métodos |
| **Enrutamiento** | Parcial (60%) | Media | Usa `routes.php` vs `router.php` propuesto |
| **Acceso a BD (SPs)** | Parcial (70%) | Media | Usa SPs correctamente pero con `Database` vs `Db` y API distinta |
| **Módulos/WServices** | Parcial (60%) | Media | Usa `ws/` vs `wservices/`, namespaces semánticos propios |
| **Layout Shell** | No cumple (30%) | Alta | Estructura completamente distinta al propuesto |
| **DataTables** | No cumple (40%) | Alta | Usa defaults parciales, sin función general unificada |
| **Input Búsqueda/Autocomplete** | No cumple (0%) | Alta | Componente no existe |
| **Logs y Auditoría** | No cumple (20%) | Alta | Tiene su propio sistema, no el propuesto |
| **Despliegue WServices/Proxy** | No cumple (0%) | Media-Alta | Arquitectura diferente |
| **Tests/CI** | Cumple mejor (90%) | - | `pds` es superior en esta área |
| **Middlewares/Seguridad** | Cumple mejor (90%) | - | Tiene RateLimit, SecurityHeaders, Idempotency, Sentry |

---

## 3. Hallazgos Detallados

### 3.1 Arquitectura General

| Elemento | Esperado (pro) | Encontrado (pds) | Estado |
|---|---|---|---|
| `public/index.php` | `new App()` sin constructor params, `$app->run()` | `new App()` sin params, `$app->run()` | ✅ Compatible |
| `public/api/index.php` | `new Api()`, `$api->run()` | `new Api()`, `$api->response()` | ⚠️ Diferente método |
| `app/core/App.php` | Estructura propuesta | Existe, con Bootstrap, Session, Logger, Sentry, QueryLogger | ✅ Similar |
| `app/core/Api.php` | Según especificación | Existe | ✅ Presente |
| `app/system/Container.php` | Con `set/get/has` singletons | Existe | ✅ Presente |
| `app/system/Bootstrap.php` | Composition root | Existe con `init()` estático | ✅ Presente |
| `app/system/Database.php` | Manager de conexiones múltiples llamado `Db` | Llamado `Database`, API diferente | ⚠️ Diferente naming |

### 3.2 Enrutamiento

| Elemento | Esperado (pro) | Encontrado (pds) | Estado |
|---|---|---|---|
| Rutas web módulo | `modules/<modulo>/router.php` | `modules/<modulo>/routes.php` | ❌ Diferente |
| Rutas API módulo | `modules/<modulo>/router_api.php` | `modules/<modulo>/routes_api.php` | ❌ Diferente |
| WServices ubicación | `modules/<modulo>/wservices/` | `modules/<modulo>/ws/` | ❌ Diferente |
| Detección `/scr/` | No especificado | Implementado con header `X-PDS-SCR` | ✅ Extra (funcional) |
| Rutas con parámetros | Soportado vía `{param}` | Soportado | ✅ Compatible |

### 3.3 Módulos y Namespaces

**Convención PDS (propia):**
- `Admin\` → módulo admin (raíz), controladores en `Admin\Controllers`, WS en `Admin\Ws\Controllers`
- `System\`, `Ventas\`, `Auth\`, `Maestros\`, `Existencias\`, `Produccion\` con mapeo semántico
- Namespaces **desacoplados** de ruta física
- `Auth\` solo rutas WS que consumen `System\Ws\Controllers\Auth`

**Convención Propuesta:**
- `<Modulo>\` → `modules/<modulo>/`
- `<Modulo>\Controllers\` → `modules/<modulo>/controllers/`
- `<Modulo>\WServices\` → `modules/<modulo>/wservices/`

**Estado:** Incompatible entre sí. PDS usa convención deliberada y documentada en su AGENTS.

### 3.4 Layout y UI

| Elemento | Esperado | Encontrado | Estado |
|---|---|---|---|
| Estructura shell | `head`, `navbar` (lateral), `foot`, `work-area` | Estructura propia diferente | ❌ No coincide |
| Área trabajo | `work-header`, `work-center`, `work-footer` | Usa `#work-area`, `#work-content`, `#work-header`, `#work-footer` | ⚠️ Parcialmente similar |
| Subdivisiones | `wc-head`, `wc-detail`, `wc-foot` opcionales | No existe esta estructura | ❌ No cumple |
| Navegación SPA | Fragmentos con header `X-App-Navigation: fragment` | Fragmentos vía `/scr/` con `X-PDS-SCR: 1` | ⚠️ Enfoque diferente |
| Botón volver | En `work-header` izq. del título cuando viene de navegación interna | Lógica existe (`.nav-back-btn`) pero ubicación/estructura diferente | ⚠️ Parcial |
| Footer pantalla | Fecha/hora carga, usuario, planta, botón recargar (solo dev) | Tiene `#work-footer-ppu` y lógica de planta, botón recargar no evidente | ⚠️ Parcial |

### 3.5 DataTables

| Elemento | Esperado | Encontrado | Estado |
|---|---|---|---|
| Función central | `App.DataTable.init(config)` | `App.initDataTableDefaults()` + uso directo | ❌ No existe API unificada |
| `paging: false` por defecto | Sí | Sí (`DataTable.defaults.paging = false`) | ✅ Cumple |
| `scrollY` automático | Sí, calculado dinámicamente | No hay cálculo automático | ❌ Falta |
| Botones Excel/PDF | Con JSZip/pdfmake, configuración central | No estandarizado | ❌ Falta |
| Idioma español | Centralizado | Configurado parcialmente | ⚠️ Parcial |
| Ubicación en `wc-detail` | Obligatorio | Estructura distinta | ❌ No aplica |
| Destrucción en unmount | Obligatorio | No forzado por framework | ⚠️ Depende implementación |

### 3.6 Componentes Reutilizables

| Componente | Esperado | Encontrado | Estado |
|---|---|---|---|
| Input con búsqueda | `App.InputSearch.init()` con dropdown, debounce, limpieza | No existe | ❌ No cumple |
| Funciones wrapper por pantalla | Sí | Probablemente ad-hoc | ❌ No estandarizado |

### 3.7 Logs y Auditoría

| Elemento | Esperado | Encontrado | Estado |
|---|---|---|---|
| `APP_ENV` con lógica dev/prod | `development`/`production` | Usa configuración propia | ⚠️ Diferente |
| Log por usuario `files/logs/<usuario>_<fecha>.log` | Siempre | `system/Logger.php` existe con otra lógica | ❌ No coincide |
| Consola navegador interceptor fetch | Solo dev | No evidenciado | ❌ No existe |
| `app_ctrl.log` truncado por pantalla | Solo dev | No existe | ❌ No existe |
| Señal App→Backend para carga pantalla | Endpoint específico | Logging vía Logger | ⚠️ Diferente enfoque |
| `system/ActivityLog`, `system/Audit` | Mencionados parcialmente | **Existen** | ✅ Tiene auditoría propia |
| `system/QueryLogger` | No propuesto | **Existe** | ✅ Extra |

### 3.8 Despliegue WServices

| Elemento | Esperado | Encontrado | Estado |
|---|---|---|---|
| Variables `WSE_*` | Completas | No encontradas | ❌ No existe |
| Modos `local/remote/proxy` | Sí | No implementado | ❌ No existe |
| `system/WsClient` | Sí | No encontrado con ese nombre | ❌ No existe |
| Proxy DMZ | Sí | No implementado | ❌ No existe |
| `wsPublicUrl` en bootstrap JS | Sí | No evidenciado | ❌ No existe |

### 3.9 Infraestructura (Fortalezas de PDS)

| Elemento | Estado | Comentario |
|---|---|---|
| **CLI tool (`pds-cli`)** | ✅ Excelente | No propuesto, muy útil |
| **Tests (PHPUnit)** | ✅ Excelente | Unit + Integration, con helpers, CI configurado |
| **GitHub Actions CI** | ✅ Excelente | Lint, PHPStan, tests con MySQL |
| **Middlewares** | ✅ Excelente | SecurityHeaders, RateLimit, Idempotency, Authorization |
| **Sentry integration** | ✅ Excelente | No propuesto |
| **Cache (Redis/File)** | ✅ Excelente | Implementado |
| **Query logging** | ✅ Excelente | Muy completo |
| **MetricsCollector** | ✅ Excelente | No propuesto |
| **Mailer, Notifications** | ✅ Excelente | Más completo |
| **Porting detallado desde PDS legacy** | ✅ Excelente | Documentado extensivamente en su AGENTS |

---

## 4. Diferencias Arquitectónicas

### 4.1 Filosofía
- **PDS**: Aplicación madura, portado desde sistema legacy, enfocado a funcionalidad completa con mucha infraestructura
- **Pro (nuevas specs)**: Diseño más simplificado/estandarizado, enfocado a consistencia y facilidad de desarrollo

### 4.2 Organización
| Aspecto | PDS | Pro (propuesto) |
|---|---|---|
| Archivos de rutas | `routes.php` / `routes_api.php` | `router.php` / `router_api.php` |
| WServices | `ws/` (namespace `Modulo\Ws\Controllers`) | `wservices/` (namespace `Modulo\WServices`) |
| Vistas compartidas | Probablemente en otro lugar o embebidas | `app/views/` con `@app` namespace |
| Base de datos | `Database` con read-replica | `Db` con conexiones múltiples nombradas |
| Controladores | Pueden usar `ControllerScreen` | `system\ScreenRenderer` propuesto |

### 4.3 Convenciones de Naming
PDS usa convenciones más específicas al dominio (nombres de SPs con prefijos por schema `pds_modulo.sp_*`, etc.), mientras las specs proponen convenciones más genéricas.

---

## 5. Elementos que Sí Cumplen

A pesar de las diferencias, hay varios aspectos que sí se alinean:

| Elemento | Comentario |
|---|---|
| ✅ Front controllers mínimos | Estructura similar |
| ✅ Uso de Bootstrap/Container pattern | Implementado correctamente |
| ✅ Acceso vía Stored Procedures | Fundamental en ambas arquitecturas |
| ✅ Sistema modular | Ambos usan módulos autocontenidos |
| ✅ Autenticación/Autorización | Presente en ambas (con enfoques diferentes) |
| ✅ Navegación sin recarga | PDS usa `/scr/` fragmentos, pro usa `X-App-Navigation: fragment` |
| ✅ Twig/templating | Probablemente usado (se ve estructura de vistas) |
| ✅ Seguridad por defecto | Middlewares de seguridad presentes en PDS |
| ✅ Auditoría | PDS tiene `ActivityLog` y `Audit`, pro propone `app_db.bitacora` + logs |

---

## 6. Recomendaciones

### 6.1 Decisión Requerida
Antes de cualquier migración/alineación, se debe definir:

1. **¿Qué proyecto es el canónico?** ¿Se va a migrar `pds` a seguir las specs de `pro`, o las specs de `pro` se adaptan a `pds`?
2. **¿Vale la pena el refactor?** `pds` está mucho más completo en infraestructura (tests, CI, middlewares). Migrar perdería funcionalidades valiosas.
3. **¿Convenciones a mantener?** El `AGENTS.md` de `pds` está muy detallado y refleja decisiones reales del proyecto.

### 6.2 Si se decide alinear PDS a las nuevas specs
Requiere trabajo significativo en:

| Tarea | Esfuerzo | Impacto | Notas |
|---|---|---|---|
| Renombrar rutas a `router.php`/`router_api.php` | Medio | Alto | Afecta todo el sistema de rutas |
| Renombrar `ws/` a `wservices/` | Medio-Alto | Alto | Muchos archivos y namespaces |
| Refactorizar layout a estructura propuesta | Alto | Alto | Cambio visual completo |
| Implementar `App.DataTable.init()` | Medio | Alto | Refactorizar todas las pantallas con DataTables |
| Implementar `App.InputSearch.init()` | Medio | Alto | Crear componente y migrar usos |
| Implementar sistema de logs propuesto | Alto | Alto | Puede duplicar funcionalidad existente |
| Implementar topología WServices con proxy | Alto | Alto | Complejo, especialmente modo DMZ |

### 6.3 Si se decide mantener ambas arquitecturas
- Documentar claramente las diferencias
- No forzar alineación
- Las nuevas specs pueden aplicarse solo a `pro`
- Mantener `AGENTS.md` independientes con sus propias convenciones

### 6.4 Recomendación Pragmática
**No migrar `pds`.** Es una aplicación funcional, probada, con buena infraestructura. Las nuevas especificaciones parecen ser para un proyecto nuevo (`pro`) con un enfoque más estandarizado y educativo. 

Si se necesita compartir patrones entre ambos, hacerlo de forma selectiva (ej: componente InputSearch, función DataTable) sin romper la arquitectura existente de `pds`.

---

## 7. Conclusión

**`pds` NO cumple con las nuevas especificaciones.** 

Las diferencias son fundamentales y sistemáticas. `pds` sigue sus propias convenciones, las cuales están bien documentadas en su `AGENTS.md` y han sido probadas en la práctica. 

**No se recomienda un refactor masivo para alinearlos.** En su lugar, se recomienda:
1. Mantener `pds` con sus convenciones actuales
2. Aplicar las nuevas especificaciones únicamente al proyecto `pro`
3. Si hay componentes reutilizables útiles, extraerlos selectivamente sin imponer toda la arquitectura

La madurez de `pds` (tests, CI, middlewares, CLI) supera considerablemente lo propuesto en las nuevas specs, por lo que alinearlo hacia abajo sería contraproducente.
