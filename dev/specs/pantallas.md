# Especificación de pantallas, layout y navegación — Aplicación `pr`

| Campo | Valor |
| --- | --- |
| Versión | 0.1 (borrador) |
| Fecha | 2026-10-22 |
| Estado | Para revisión y refinamiento |
| Alcance | Shell de la aplicación, layout Twig, menú, área de trabajo, navegación sin recarga, historial y estado de pantalla |
| Documentos relacionados | [`arquitectura.md`](arquitectura.md), [`base-de-datos.md`](base-de-datos.md), [`control-acceso.md`](control-acceso.md), [`README.md`](../../README.md), [`AGENTS.md`](../../AGENTS.md) |

> Este documento describe **cómo debe funcionar la interfaz de usuario**. No describe el estado actual del código. La implementación todavía no existe; las decisiones marcadas como propuestas deben confirmarse antes de convertir este documento en código.

---

## 1. Objetivo

Definir una interfaz web con:

- Un **shell persistente** con título, menú lateral, área de trabajo y pie.
- Pantallas renderizadas con **Twig** en el servidor.
- Navegación entre opciones **sin recargar la página**, mediante `fetch` que devuelve fragmentos HTML.
- URLs profundas y recargables: `http://<app>/<modulo>/<opcion>` debe abrir directamente esa pantalla.
- Historial de navegación con posibilidad de volver a la pantalla anterior.
- Persistencia del estado de pantalla, incluidos filtros y criterios de búsqueda, para reconstruir la pantalla al volver o recargar.
- Separación estricta entre **navegación HTML** y **API de datos JSON**.

---

## 2. Principios

1. **El shell nunca se reemplaza durante la navegación normal.** Solo cambia el contenido del área de trabajo.
2. **La URL es la fuente de verdad de la pantalla.** Toda pantalla debe poder abrirse, recargarse y compartirse mediante su URL.
3. **Twig renderiza HTML en el servidor.** No se construyen pantallas completas con JavaScript ni se duplica el HTML en plantillas JS.
4. **La navegación devuelve fragmentos HTML, no JSON.** Los datos de negocio se obtienen aparte mediante la API.
5. **La API solo devuelve JSON.** Nunca se usa `/api/...` para entregar HTML de pantallas.
6. **El servidor autoriza siempre.** La autenticación y los permisos se validan tanto en la carga completa como en cada fragmento y en cada llamada API.
7. **Progressive enhancement.** Los enlaces del menú son URLs reales; sin JavaScript la aplicación sigue funcionando con recargas completas.
8. **El estado del historial es pequeño, serializable y no sensible.** No se guardan contraseñas, tokens ni datos personales innecesarios.
9. **Accesibilidad por defecto.** Navegación por teclado, foco predecible, landmarks y anuncios de cambio de pantalla.
10. **Sin lógica de negocio en Twig ni en JavaScript de navegación.** Las plantillas presentan; los `wservices` deciden y acceden a datos.

---

## 3. Estructura visual del shell

```text
┌──────────────────────────────────────────────────────────────────────┐
│ HEADER                                                               │
│ Título de la aplicación                                              │
├───────────────────┬──────────────────────────────────────────────────┤
│ SIDEBAR           │ WORKSPACE                                        │
│                   │                                                  │
│ [Select módulo]   │  <main id="app-workspace">                       │
│                   │                                                  │
│ ▸ Carpeta 1       │      Pantalla de la opción seleccionada          │
│   • Opción A      │      (fragmento Twig)                            │
│   • Opción B      │                                                  │
│ ▸ Carpeta 2       │                                                  │
│   • Opción C      │                                                  │
│                   │                                                  │
│ ─────────────     │                                                  │
│ Usuario           │                                                  │
│ [Menú desplegable]│                                                  │
├───────────────────┴──────────────────────────────────────────────────┤
│ FOOTER: copyright                                                    │
└──────────────────────────────────────────────────────────────────────┘
```

### 3.1 Regiones

| Región | Contenido | Comportamiento |
| --- | --- | --- |
| Header | Título de la aplicación, nombre corto o logo | Persistente. Puede incluir botón para abrir/cerrar el menú en móvil. |
| Selector de módulo | Lista de módulos autorizados | Al cambiar, actualiza las carpetas/opciones y navega a la opción por defecto del módulo. |
| Menú lateral | Carpetas y opciones del módulo actual | Las carpetas se pueden expandir/contraer. La opción activa se marca con `aria-current="page"`. |
| Usuario | Nombre, rol o iniciales y menú desplegable | Opciones propuestas: perfil, cambiar contraseña, configuración y cerrar sesión. |
| Workspace | Contenido de la pantalla actual | Es la única región que se reemplaza en una navegación sin recarga. |
| Footer | Copyright y, opcionalmente, versión | Persistente. Año calculado en servidor. |

### 3.2 Comportamiento responsive

- Escritorio: sidebar visible a la izquierda, workspace a la derecha.
- Tablet/móvil: sidebar como panel deslizante u offcanvas; el workspace ocupa todo el ancho.
- El header y el footer permanecen visibles; el scroll principal ocurre en el workspace o en la página, según se defina en CSS.
- Los menús deben poder operarse con teclado y cerrarse con `Escape`.
- El layout debe usar CSS Grid o Flexbox y evitar anchos fijos en píxeles para el workspace.

### 3.3 Reglas de presentación

- El título de la app se define en configuración (`APP_NAME` o equivalente), no se hardcodea en cada plantilla.
- El select de módulos muestra solo módulos autorizados para el usuario.
- Las carpetas y opciones se generan desde metadatos del servidor, no desde una lista duplicada en JavaScript.
- El copyright se renderiza en servidor con el año actual: `© {{ "now"|date("Y") }} {{ app_name }}`.
- El usuario y sus opciones se renderizan en la misma plantilla compartida; no se consulta la base de datos desde Twig.

---

## 4. Estructura de plantillas Twig

### 4.1 Ubicación propuesta

```text
app/
└── views/
    ├── layouts/
    │   └── app.html.twig             # Shell completo
    ├── partials/
    │   ├── header.html.twig
    │   ├── sidebar.html.twig
    │   ├── module-select.html.twig
    │   ├── menu.html.twig
    │   ├── user-menu.html.twig
    │   ├── footer.html.twig
    │   ├── workspace.html.twig
    │   ├── loading.html.twig
    │   └── error.html.twig
    └── errors/
        ├── 403.html.twig
        ├── 404.html.twig
        └── 500.html.twig

modules/<modulo>/views/
├── <pantalla>.html.twig              # Fragmento de pantalla
└── partials/                         # Opcional, parciales del módulo
```

Namespaces de Twig:

| Namespace | Ruta | Uso |
| --- | --- | --- |
| `@app` | `app/views/` | Layout, parciales compartidos y páginas de error. |
| `@<modulo>` | `modules/<modulo>/views/` | Pantallas y parciales del módulo. Ejemplo: `@ventas`. |

> Esta ubicación resuelve la decisión abierta §14.5 de [`arquitectura.md`](arquitectura.md) a favor de `app/views/`. Debe confirmarse al implementar el `Bootstrap`.

### 4.2 Contrato de una pantalla

Cada pantalla es un **fragmento HTML** con un único elemento raíz:

```html
<section
    class="app-screen"
    data-screen-id="ventas/pedido"
    data-screen-title="Pedido"
>
    <header class="app-screen__header">
        <h1>Pedido</h1>
    </header>

    <div class="app-screen__body">
        <!-- Contenido de la pantalla -->
    </div>
</section>
```

Reglas:

- No incluye `<!DOCTYPE>`, `<html>`, `<head>`, `<body>`, header global, sidebar ni footer.
- No incluye `<script>` ni `<style>` inline. El JS y CSS específicos se cargan desde assets versionados.
- El atributo `data-screen-id` debe coincidir con `<modulo>/<opcion>`.
- `data-screen-title` es el título legible para el documento y el historial.
- Los IDs internos deben llevar prefijo del módulo/pantalla para evitar colisiones al insertar fragmentos.
- Los formularios incluyen token CSRF cuando modifican estado.
- No usa `|raw` salvo para el JSON de bootstrap, generado de forma segura.
- Todo dato de usuario se escapa con autoescape de Twig.

### 4.3 Layout completo

El layout `@app/layouts/app.html.twig` recibe, como mínimo:

| Variable | Descripción |
| --- | --- |
| `app_name` | Nombre visible de la aplicación. |
| `title` | Título del documento. |
| `current_module` | Módulo activo. |
| `current_option` | Opción activa. |
| `menu` | Módulos, carpetas y opciones autorizados. |
| `user` | Datos mínimos del usuario actual. |
| `screen_template` | Plantilla Twig del fragmento inicial. |
| `screen_data` | Datos de presentación del fragmento inicial. |
| `bootstrap` | Datos serializables para el cliente (menú, ruta actual, usuario). |
| `csrf_token` | Token para formularios y mutaciones. |

Ejemplo conceptual:

```twig
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ title }} — {{ app_name }}</title>
    <link rel="stylesheet" href="/assets/css/bootstrap.min.css">
    <link rel="stylesheet" href="/assets/css/app.css">
</head>
<body class="app-shell">
    <a class="skip-link" href="#app-workspace">Ir al contenido</a>

    {% include '@app/partials/header.html.twig' %}
    {% include '@app/partials/sidebar.html.twig' %}

    <main id="app-workspace" class="app-workspace" tabindex="-1">
        {% include screen_template with screen_data only %}
    </main>

    {% include '@app/partials/footer.html.twig' %}

    <script type="application/json" id="app-bootstrap">{{ bootstrap|json_encode|raw }}</script>
    <script src="/assets/js/app.js"></script>
</body>
</html>
```

El valor de `screen_template` lo determina el servidor a partir de la ruta y del controlador; nunca proviene del cliente.

### 4.4 Render completo frente a fragmento

El controlador no debe duplicar la lógica de layout. Se propone un servicio compartido `system\ScreenRenderer` (o equivalente) que:

1. Reciba la plantilla de pantalla y sus datos.
2. Detecte si la petición es una navegación por fragmento.
3. Si es carga completa, renderice `@app/layouts/app.html.twig` con el fragmento incluido.
4. Si es fragmento, renderice solo la plantilla de la pantalla.
5. Añada las cabeceras de respuesta correspondientes.

El controlador solo declara la pantalla y sus datos:

```php
final class PedidoController
{
    public function __construct(private system\ScreenRenderer $screen)
    {
    }

    public function index(): void
    {
        $this->screen->render('@ventas/pedido.html.twig', [
            'titulo' => 'Pedido',
        ]);
    }
}
```

---

## 5. Módulos, rutas y menú

> **Cambio de modelo:** el origen de la estructura de navegación (módulos → carpetas → opciones) pasa a ser la base principal `app_db`, según [`control-acceso.md`](control-acceso.md). Esta sección describe la construcción del menú. Los manifiestos `module.php` y los metadatos `menu` de `router.php` quedan como referencia transitoria; al implementar el control de acceso en base, el menú y los permisos se derivan del árbol autorizado de `app_db`. Ver [`control-acceso.md`](control-acceso.md) §6.

### 5.1 Manifiesto del módulo

Cada módulo puede declarar metadatos en `modules/<modulo>/module.php`:

```php
<?php

declare(strict_types=1);

return [
    'label' => 'Ventas',
    'default' => 'pedido',
    'order' => 20,
    'permission' => 'ventas.access',
    'groups' => [
        'operaciones' => [
            'label' => 'Operaciones',
            'order' => 10,
        ],
        'reportes' => [
            'label' => 'Reportes',
            'order' => 20,
        ],
    ],
];
```

| Campo | Obligatorio | Descripción |
| --- | --- | --- |
| `label` | Sí | Nombre visible del módulo en el select. |
| `default` | Sí | Opción que se abre al seleccionar el módulo. |
| `order` | No | Orden del módulo en el select. |
| `permission` | No | Permiso necesario para ver el módulo. |
| `groups` | No | Catálogo de carpetas del menú con etiqueta y orden. |

Si el módulo no declara manifiesto, se puede usar el nombre de la carpeta como etiqueta y la primera opción como `default`, pero se recomienda declararlo explícitamente.

### 5.2 Metadatos de las opciones

Las entradas de `modules/<modulo>/router.php` se amplían con metadatos de menú y permisos:

```php
'pedido' => [
    'controller' => PedidoController::class,
    'action' => 'index',
    'method' => 'GET',
    'auth' => true,
    'permission' => 'ventas.pedido.ver',
    'title' => 'Pedido',
    'menu' => [
        'group' => 'operaciones',
        'label' => 'Pedido',
        'order' => 10,
        'icon' => 'bi-cart',
    ],
],
```

| Campo | Obligatorio | Descripción |
| --- | --- | --- |
| `permission` | No | Permiso adicional para acceder a la opción. |
| `title` | No | Título de la pantalla. Por defecto, la etiqueta del menú o el nombre de la opción. |
| `menu` | No | Metadatos para mostrar la opción. Si falta o es `false`, la opción no aparece en el menú. |
| `menu.group` | Sí si hay `menu` | ID de la carpeta declarada en `module.php`. |
| `menu.label` | Sí si hay `menu` | Texto visible de la opción. |
| `menu.order` | No | Orden dentro de la carpeta. |
| `menu.icon` | No | Icono de la librería visual adoptada. |

Reglas:

- Las rutas ocultas (login, logout, health, detalle interno) deben usar `menu => false` o no declarar `menu`.
- El menú se genera en servidor; no se mantiene una lista paralela en JS.
- Los permisos se evalúan en servidor. Ocultar una opción no sustituye la autorización de la ruta.

### 5.3 Construcción del menú

Se propone un servicio `system\Menu` que:

1. Obtenga el árbol autorizado del usuario desde `app_db` (módulos, carpetas y opciones concedidos vía roles), según [`control-acceso.md`](control-acceso.md).
2. Descarte opciones sin acceso.
3. Agrupe por carpeta y aplique el orden.
4. Devuelva una estructura serializable para el servidor y para el bootstrap del cliente.

> Transitoriamente (mientras el acceso no esté en base), el menú puede construirse a partir de `module.php` y de los metadatos `menu` de `router.php` como se describe a continuación. Este modo es provisional y debe retirarse al implementar [`control-acceso.md`](control-acceso.md).

Contrato propuesto:

```json
{
  "modules": [
    {
      "id": "ventas",
      "label": "Ventas",
      "default": "pedido",
      "groups": [
        {
          "id": "operaciones",
          "label": "Operaciones",
          "options": [
            {
              "id": "pedido",
              "label": "Pedido",
              "url": "/ventas/pedido?vista=resumen"
            }
          ]
        }
      ]
    }
  ]
}
```

- El servidor renderiza el menú del módulo actual para que funcione sin JavaScript.
- La `url` de cada opción se compone con `opciones.opcion_call` (`"<modulo>/<opcion>"` prefijado con `/`) más `opciones.opcion_parametros` como query string de carga. Ver [`control-acceso.md`](control-acceso.md) §4.4 y §5.5.
- El layout incluye además el menú completo autorizado en el JSON de bootstrap para que el select pueda cambiar de módulo sin recargar.
- El JSON no debe incluir datos que el usuario no pueda ver.
- Si el menú se vuelve dinámico o muy grande, se puede reemplazar el JSON embebido por un endpoint de menú cacheado; queda como decisión de implementación.

### 5.4 Selector de módulo

- Se renderiza con los módulos autorizados y el módulo actual seleccionado.
- Al cambiar con JavaScript:
  1. Se actualizan las carpetas/opciones del sidebar desde el bootstrap.
  2. Se navega a la opción `default` del módulo mediante `App.navigate()`.
- Sin JavaScript, los enlaces de las opciones del módulo actual siguen funcionando como URLs completas. El select es una mejora progresiva.
- La opción activa se sincroniza con la URL después de cada navegación y en `popstate`.

### 5.5 Menú de usuario

Propuesta de opciones y rutas:

| Opción | Ruta / acción |
| --- | --- |
| Perfil | `GET /system/perfil` |
| Cambiar contraseña | `GET /system/password` (formulario) y `POST /api/system/password` |
| Configuración | `GET /system/configuracion` |
| Cerrar sesión | `POST /system/logout` con CSRF |

- El cierre de sesión no debe ser un `GET` que cambie estado.
- Al cerrar sesión se destruye la sesión, se limpian datos temporales del cliente y se redirige al login.
- El menú debe cerrarse con `Escape` y al hacer clic fuera.

---

## 6. Modos de renderizado web

### 6.1 Carga completa

Petición:

```http
GET /ventas/pedido?estado=abierto
Accept: text/html
```

Comportamiento:

1. `App` ejecuta `Bootstrap`, inicia sesión y valida autenticación.
2. `Router` resuelve `ventas` + `pedido`.
3. Se valida el permiso de la ruta.
4. El controlador prepara los datos de presentación.
5. `ScreenRenderer` devuelve el layout completo con el fragmento inicial incluido.
6. Sin sesión: `302` a `/system/login?redirect=/ventas/pedido?estado=abierto` (URL codificada).
7. Error de permiso: página completa `403`. Ruta inexistente: página completa `404`.

La carga completa es la que garantiza que una URL funcione al abrirse directamente, al recargar y sin JavaScript.

### 6.2 Navegación por fragmento

Petición:

```http
GET /ventas/pedido?estado=abierto
Accept: text/html
X-App-Navigation: fragment
```

Comportamiento:

1. Se aplican exactamente las mismas validaciones de autenticación, ruta, método y permiso.
2. `ScreenRenderer` devuelve **solo** la plantilla de la pantalla, sin layout.
3. No se permiten redirecciones `302` en este modo; una sesión expirada debe devolver `401`.
4. La respuesta incluye:

```http
Content-Type: text/html; charset=utf-8
Cache-Control: private, no-store
Vary: X-App-Navigation
X-Screen-Id: ventas/pedido
```

5. El cuerpo tiene un único elemento raíz con `data-screen-id` y `data-screen-title`.
6. El cliente lee el título del atributo `data-screen-title`; no se envía texto no ASCII por cabeceras.

Errores en modo fragmento:

| Situación | Respuesta |
| --- | --- |
| Sin sesión o sesión expirada | `401` con contrato JSON `{status, message, data}`; el cliente redirige al login. |
| Sin permiso | `403` con fragmento HTML de error insertable en el workspace. |
| Ruta inexistente | `404` con fragmento HTML de error. |
| Error interno | `500` con fragmento HTML genérico, sin trazas. |
| Método no permitido | `405` con cabecera `Allow`. |

Reglas:

- El encabezado `X-App-Navigation` solo cambia la representación; **nunca** autoriza ni desactiva controles de seguridad.
- Debe compararse con el valor exacto `fragment`; cualquier otro valor se trata como carga completa.
- Las respuestas HTML de pantallas no se cachean como públicas.
- El modo fragmento no se usa para llamadas API ni para devolver JSON de negocio.
- `GET` es el método por defecto de navegación y no requiere CSRF. Si en el futuro se navega con otro método, debe existir una decisión explícita y protección CSRF.

### 6.3 Carga de datos de la pantalla

La navegación entrega la estructura HTML y el esqueleto de la pantalla. Los datos se obtienen después con la API:

```http
GET /api/ventas/pedidos?estado=abierto&page=2
Accept: application/json
```

Reglas:

- Usar `fetch` con `credentials: 'same-origin'`.
- Las mutaciones (`POST`, `PUT`, `PATCH`, `DELETE`) envían `X-CSRF-Token`.
- La API mantiene el contrato `{status, message, data}` y `Content-Type: application/json`.
- Los controladores web no consultan la base de datos; el fragmento no se renderiza con datos de negocio del servidor.
- Los filtros y la paginación se envían a la API como parámetros validados.
- El cliente debe cancelar peticiones anteriores y descartar respuestas obsoletas al cambiar de pantalla.

---

## 7. Flujos de navegación

### 7.1 Arranque inicial

1. El usuario abre `/ventas/pedido?estado=abierto`.
2. El servidor devuelve el shell completo con el menú, el usuario y el fragmento inicial de `pedido`.
3. El cliente lee la URL y el `history.state`.
4. Si no hay estado previo, crea una entrada con `history.replaceState()` usando la URL actual.
5. El cliente registra la pantalla, ejecuta su `mount()` y realiza la carga de datos por API.
6. Se actualiza `document.title` y se marca la opción activa del menú.
7. El foco se coloca en el workspace o en el título de la pantalla, no en el inicio del documento.

### 7.2 Clic en una opción del menú

1. El enlace tiene una URL real (`href="/ventas/pedido"`).
2. JavaScript intercepta el clic con `preventDefault()`.
3. Se consulta la pantalla actual con `canLeave()`; si hay cambios sin guardar, se pide confirmación.
4. Se serializa el estado actual con `serialize()`.
5. Se llama a `App.navigate(url, { state })`.
6. Se cancela cualquier navegación anterior con `AbortController`.
7. Se marca el workspace con `aria-busy="true"` y se muestra un indicador de carga.
8. Se hace `fetch(url, { headers: { 'X-App-Navigation': 'fragment' }, credentials: 'same-origin' })`.
9. Si la respuesta es `200`:
   - se reemplaza el contenido de `#app-workspace`;
   - se leen `data-screen-id` y `data-screen-title`;
   - se actualiza el menú, el select de módulo y la opción activa;
   - se ejecuta `unmount()` de la pantalla anterior y `mount()` de la nueva;
   - se hace `history.pushState()` con la nueva entrada;
   - se actualiza `document.title`;
   - se mueve el foco al workspace o al `h1`;
   - se ejecuta la carga de datos de la pantalla.
10. Si la respuesta es `401`, se redirige al login guardando la URL de retorno.
11. Si es `403`, `404` o `500`, se inserta el fragmento de error y **no** se hace `pushState`; la URL permanece en la pantalla anterior.
12. Si hay error de red, se muestra un panel con opción de reintentar.

### 7.3 URL directa o recarga completa

- La URL `/ventas/pedido` siempre debe renderizar el shell completo y posicionar el área de trabajo en la opción `pedido` del módulo `ventas`.
- El servidor no depende de que el cliente haya navegado antes.
- El estado de filtros debe poder reconstruirse desde la query string.
- Si el usuario recarga, se pierde el estado JavaScript no reflejado en la URL; por eso los filtros relevantes deben vivir en la URL.
- Si `history.state` sigue disponible tras la recarga, el cliente puede usarlo como estado inicial; si no, se usa la URL.

### 7.4 Una pantalla llama a otra

- La pantalla debe usar `App.navigate('/ventas/pedido-detalle?id=123', { state: { id: 123 } })`.
- No debe usar `window.location.href` salvo que quiera forzar una recarga completa.
- Antes de salir, la pantalla actual serializa su estado; la entrada anterior del historial conserva su URL, estado, filtros y posición de scroll.
- La nueva pantalla se apila en el historial.
- Para volver, se usa `App.back()` o el botón atrás del navegador.
- Si una pantalla necesita volver a un punto concreto, puede guardar una URL de retorno en su estado, pero no debe crear historiales paralelos.

### 7.5 Atrás y adelante del navegador

1. El cliente escucha `popstate`.
2. Obtiene `event.state` y la URL actual.
3. Si hay estado, lo usa; si no, reconstruye el estado mínimo desde la URL.
4. Ejecuta `unmount()` de la pantalla actual.
5. Hace `fetch` del fragmento de la URL objetivo.
6. Reemplaza el workspace y ejecuta `mount()` con el estado restaurado.
7. Restaura la posición de scroll guardada después de insertar el contenido.
8. No hace `pushState` durante `popstate`.
9. Si la petición falla, muestra el error correspondiente sin perder la posibilidad de volver.

### 7.6 Refrescar la pantalla actual

- `App.reload()` vuelve a solicitar el fragmento de la URL actual, conserva el estado y no crea una nueva entrada de historial.
- La recarga del navegador (`F5`) sigue siendo una carga completa y la resuelve el servidor.
- Las pantallas que necesiten recargar solo datos pueden volver a llamar a su API sin recargar el fragmento.

---

## 8. Historial y estado de pantalla

### 8.1 La URL primero

- La URL canónica de una pantalla es `/<modulo>/<opcion>`.
- Los filtros, la paginación y el elemento seleccionado viajan por query string:
  - `/ventas/pedido?estado=abierto&page=2`
  - `/ventas/pedido-detalle?id=123`
- No se usa navegación por hash (`#/...`).
- Para el MVP no se agregan segmentos de ruta adicionales; si se necesitan en el futuro, se define una decisión explícita.
- La URL debe ser compartible y recargable. No debe contener contraseñas, tokens, datos sensibles ni información personal innecesaria.
- Si un filtro no debe quedar en la URL por privacidad, se guarda solo en `history.state` o `sessionStorage` y se documenta la excepción.

### 8.2 Estructura de `history.state`

```json
{
  "v": 1,
  "navId": "01J...",
  "screenId": "ventas/pedido",
  "request": {
    "method": "GET",
    "url": "/ventas/pedido?estado=abierto&page=2"
  },
  "title": "Pedido",
  "state": {
    "estado": "abierto",
    "page": 2,
    "clienteId": 123
  },
  "scroll": {
    "windowY": 0,
    "workspaceY": 120
  },
  "ts": 1760000000
}
```

Reglas:

- `v` permite migrar el formato del historial.
- `navId` identifica la navegación y ayuda a descartar respuestas de peticiones antiguas.
- `request.url` es la llamada que debe repetirse al volver a la entrada.
- `state` solo contiene datos serializables y pequeños.
- `title` se usa para restaurar `document.title` mientras se carga el fragmento.
- `scroll` se restaura de forma manual; se propone `history.scrollRestoration = 'manual'`.
- No se guardan contraseñas, tokens, contenido completo de formularios ni datos de negocio voluminosos.
- El estado debe poder descartarse sin romper la pantalla: la URL es la fuente de verdad.

### 8.3 Estado grande o temporal

- Si una pantalla necesita conservar un estado mayor que el recomendado para `history.state`, se guarda en `sessionStorage` bajo una clave asociada a `navId`.
- Ese estado debe tener una versión, un tiempo de expiración y limpieza al cerrar sesión.
- Nunca se guarda información sensible en `sessionStorage`.
- Si el estado temporal no existe al restaurar, la pantalla debe poder reconstruirse desde la URL o mostrar un estado vacío seguro.

### 8.4 Actualización de filtros

- Cambiar un filtro no debe crear una entrada de historial por cada pulsación.
- La pantalla llama a `App.updateScreenState(patch, { replaceUrl: true })`.
- El cliente actualiza `history.state` con `replaceState` y reconstruye la query string canónica.
- Solo se crea una entrada nueva (`pushState`) cuando se navega a otra pantalla o cuando el cambio de vista es significativo y el usuario espera poder volver atrás.
- Al restaurar una entrada, la pantalla recibe `state` en `mount()` y debe aplicar los filtros antes de cargar datos.

### 8.5 Formularios con cambios sin guardar

- La pantalla puede implementar `canLeave()` para detectar cambios pendientes.
- Antes de una navegación interna, se pide confirmación.
- El botón atrás del navegador no se puede bloquear de forma fiable; para evitar pérdidas, la pantalla debe guardar borradores o usar `beforeunload` solo para recargas y cierre de pestaña.
- Los formularios que modifican estado usan CSRF y confirman el resultado antes de actualizar el historial.

### 8.6 Cierre de sesión

- Al cerrar sesión se eliminan las claves de `sessionStorage` de la aplicación y se limpian caches en memoria.
- No se intenta borrar el historial del navegador; por eso el historial no debe contener datos sensibles.
- Tras el logout se redirige al login y se elimina cualquier estado de pantalla que pueda reutilizarse.

---

## 9. Arquitectura del cliente

### 9.1 Archivos propuestos

```text
public/assets/js/
├── app.js                    # Arranque, bootstrap y API pública
├── navigation.js             # History API, fetch de fragmentos y ciclo de vida
├── api.js                    # Cliente fetch para la API JSON
└── screens/
    ├── dashboard/
    │   └── index.js
    └── ventas/
        ├── pedido.js
        └── pedido-detalle.js
```

- `app.js` se carga en el layout y arranca una sola vez.
- `navigation.js` gestiona el shell, el historial y el workspace.
- `api.js` centraliza `fetch`, cabeceras, CSRF, JSON y manejo de `401`.
- Cada pantalla registra su ciclo de vida en un registro global; no se usan scripts inline en los fragmentos.

### 9.2 API pública del cliente

```js
App.navigate(url, { state = {}, replace = false });
App.back();
App.reload();
App.updateScreenState(patch, { replaceUrl = true });
App.api(url, options);
App.screens.register(screenId, lifecycle);
```

Comportamiento:

| Método | Uso |
| --- | --- |
| `navigate` | Carga un fragmento, actualiza el workspace y apila una entrada de historial. Valida que la URL sea interna. |
| `back` | Llama a `history.back()`; la restauración la maneja `popstate`. |
| `reload` | Vuelve a cargar el fragmento actual sin crear una entrada nueva. |
| `updateScreenState` | Actualiza el estado y la query string sin recargar. |
| `api` | Ejecuta una llamada JSON a la API con credenciales y CSRF. |
| `screens.register` | Asocia un `screenId` con sus hooks de ciclo de vida. |

### 9.3 Ciclo de vida de una pantalla

```js
App.screens.register('ventas/pedido', {
    mount(root, context) {
        // root: elemento raíz del fragmento
        // context: { screenId, url, state, signal }
    },

    unmount() {
        // Cancelar timers, listeners y peticiones
    },

    serialize() {
        // Devolver estado serializable para el historial
        return {};
    },

    restore(state) {
        // Aplicar filtros o selección guardados
    },

    canLeave() {
        // Devolver false si hay cambios sin guardar
        return true;
    }
});
```

Reglas:

- `mount()` se ejecuta después de insertar el fragmento y antes de cargar datos.
- `unmount()` se ejecuta antes de reemplazar el workspace y al descargar la pantalla.
- `serialize()` debe devolver solo datos pequeños, serializables y no sensibles.
- `restore()` debe ser idempotente y tolerar estados antiguos o incompletos.
- Si se usa DataTables, jQuery u otro plugin, se inicializa en `mount()` y se destruye en `unmount()`.
- Las peticiones usan el `AbortSignal` de `context` para cancelarse al navegar.

### 9.4 JSON de bootstrap

El layout incluye un bloque seguro con los datos mínimos para arrancar:

```html
<script type="application/json" id="app-bootstrap">
{
  "current": {
    "module": "ventas",
    "option": "pedido",
    "url": "/ventas/pedido"
  },
  "modules": [],
  "user": {},
  "csrfToken": "..."
}
</script>
```

Reglas:

- El JSON se genera en servidor con `json_encode` y flags que escapan `<`, `>`, `&`, `'` y `"` para evitar cerrar el `<script>`.
- No se incluye información que el usuario no pueda ver.
- No se incluyen contraseñas ni secretos.
- El token CSRF puede vivir en un `<meta name="csrf-token">` si se prefiere no incluirlo en el JSON.

### 9.5 Uso de `fetch`

- Navegación: `fetch(url, { headers: { 'X-App-Navigation': 'fragment' }, credentials: 'same-origin' })`.
- API: `fetch('/api/...', { headers: { 'Accept': 'application/json', 'X-CSRF-Token': token }, credentials: 'same-origin' })`.
- Comprobar `response.ok` y el `Content-Type` antes de interpretar el cuerpo.
- No usar `innerHTML` con mensajes de error provenientes de datos del usuario; construir el panel de error con DOM o con plantillas controladas.
- Descartar respuestas si `navId` ya no es la navegación activa.

---

## 10. Carga, errores y concurrencia

### 10.1 Estados de carga

- Mostrar una barra de progreso o un indicador discreto en el header.
- El workspace puede mostrar un esqueleto de la pantalla mientras carga.
- Marcar `#app-workspace` con `aria-busy="true"` y retirarlo al terminar.
- Evitar bloquear el menú completo; el usuario puede cancelar o cambiar de pantalla.

### 10.2 Errores

| Código | Comportamiento en navegación |
| --- | --- |
| `401` | Guardar URL actual, redirigir a `/system/login?redirect=...`. |
| `403` | Insertar fragmento de error de permiso; no cambiar la URL. |
| `404` | Insertar fragmento de error de pantalla no encontrada; no cambiar la URL. |
| `500` | Insertar error genérico con opción de reintentar; no mostrar trazas. |
| Red | Panel de error con botón de reintento. |

- En carga completa, `401` redirige, `403`/`404`/`500` renderizan páginas completas de error.
- Los errores de API se muestran dentro de la pantalla afectada, no reemplazan el shell.
- Si la sesión expira, no se debe insertar el formulario de login dentro del workspace; se redirige.

### 10.3 Concurrencia

- Cada navegación recibe un `navId` y un `AbortController`.
- Al iniciar una nueva navegación, se aborta la anterior.
- Si llega una respuesta de una navegación antigua, se descarta.
- Si el usuario hace clic rápido en varias opciones, solo la última debe quedar activa.
- El estado del menú y la URL deben actualizarse solo cuando la navegación gane.

---

## 11. Seguridad

- Autenticación y autorización en **toda** petición: carga completa, fragmento y API.
- El encabezado `X-App-Navigation` no otorga permisos ni evita CSRF.
- El fragmento se obtiene solo de rutas internas y confiables; nunca se inserta HTML de terceros.
- Twig mantiene autoescape activado. El único `|raw` permitido es el JSON de bootstrap generado con flags seguros.
- No se guardan datos sensibles en `history.state`, `sessionStorage`, `localStorage` ni en la URL.
- Los filtros con datos personales deben minimizarse o mantenerse fuera de la URL; si se usan IDs, validar su formato.
- `App.navigate()` solo acepta rutas internas que empiecen con `/`, sin esquema, sin host y sin `//`; rechaza `javascript:`, `data:` y URLs externas.
- Las mutaciones usan CSRF; la navegación `GET` es idempotente y no modifica estado.
- Las respuestas HTML de pantallas usan `Cache-Control: private, no-store` para evitar fugas entre usuarios.
- El logout es `POST` con CSRF y limpia la sesión y los datos temporales del cliente.
- No se registran tokens, contraseñas ni contenido sensible en logs.
- Los errores en producción no exponen rutas internas, trazas ni SQL.

---

## 12. Accesibilidad y usabilidad

- Usar landmarks: `<header>`, `<nav>`, `<main>`, `<footer>`.
- Añadir un enlace «Saltar al contenido» que apunte a `#app-workspace`.
- Marcar la opción activa con `aria-current="page"`.
- El select de módulos debe tener etiqueta asociada.
- Los menús desplegables deben abrirse con teclado, cerrarse con `Escape` y devolver el foco al botón.
- Tras una navegación, mover el foco al `h1` de la pantalla o al workspace y anunciar el cambio con una región `aria-live="polite"`.
- Mantener el foco dentro del offcanvas o modal cuando esté abierto.
- Respetar `prefers-reduced-motion` para animaciones.
- Los objetivos táctiles deben tener un tamaño mínimo de 44×44 px.
- El contraste debe cumplir WCAG 2.1 AA.
- Sin JavaScript, los enlaces deben navegar a URLs completas y el formulario de login debe funcionar.

---

## 13. Rendimiento y caché

- El shell, CSS y JS se cachean como assets versionados; el HTML de pantalla no se cachea públicamente.
- El menú se calcula en servidor y se puede cachear por usuario/rol si el costo lo justifica.
- Los fragmentos no se solicitan de nuevo si la pantalla ya está montada, salvo `App.reload()` o una navegación explícita.
- Las pantallas cargan datos con paginación y filtros; no se descargan listados completos.
- Las pantallas que usan DataTables deben respetar el contrato de paginación de la API.
- Evitar cargar JS de todas las pantallas en el arranque; se puede hacer carga diferida por módulo/pantalla.
- Medir el tamaño del JSON de bootstrap; si crece demasiado, mover el menú a un endpoint cacheado.

---

## 14. Criterios de aceptación

- [ ] `GET /<modulo>/<opcion>` devuelve el shell completo con la opción correcta seleccionada.
- [ ] Una opción inexistente devuelve `404` completo en carga normal.
- [ ] Un usuario sin sesión es redirigido al login y vuelve a la URL solicitada tras autenticarse.
- [ ] Un usuario sin permiso recibe `403` aunque la opción esté oculta en el menú.
- [ ] El clic en una opción del menú actualiza el workspace sin recargar la página.
- [ ] La URL cambia con `pushState` al navegar y el botón atrás restaura la pantalla anterior.
- [ ] La recarga de una URL con filtros reconstruye la pantalla y los filtros.
- [ ] Una pantalla puede navegar a otra y volver conservando sus filtros y su scroll.
- [ ] Las peticiones de navegación usan `X-App-Navigation: fragment` y devuelven solo el fragmento.
- [ ] La API sigue devolviendo JSON y nunca HTML.
- [ ] Una sesión expirada devuelve `401` en modo fragmento y el cliente redirige al login.
- [ ] Los errores de navegación no cambian la URL ni dejan el workspace bloqueado.
- [ ] El historial no contiene contraseñas, tokens ni datos sensibles.
- [ ] El layout es usable con teclado y con lector de pantalla.
- [ ] La aplicación funciona sin JavaScript mediante URLs completas.
- [ ] El select de módulos solo muestra módulos autorizados y no permite saltarse permisos.
- [ ] El menú de usuario permite cambiar contraseña, configuración y cerrar sesión de forma segura.

---

## 15. Decisiones abiertas

1. **Ubicación de `@app`**: se propone `app/views/`; confirmar antes de implementar `Bootstrap`.
2. **Comportamiento del select de módulo**: se propone cambiar el menú y navegar automáticamente a la opción `default`. Alternativa: solo filtrar el menú hasta que el usuario elija una opción.
3. **Origen del menú**: se propone generarlo desde manifiestos y metadatos de rutas. Si debe ser dinámico por base de datos, definir el `wservice` y la caché.
4. **Ubicación del estado grande**: `history.state` para datos pequeños y `sessionStorage` para el resto. Confirmar límites y política de expiración.
5. **Carga de JS por pantalla**: módulos ES, bundles por módulo o un único bundle. Debe respetar el ciclo de vida y la carga diferida.
6. **Parámetros de ruta**: el MVP usa query string; evaluar `/<modulo>/<opcion>/<id>` en el futuro.
7. **Contrato exacto de paginación y filtros**: debe alinearse con [`base-de-datos.md`](base-de-datos.md) y la API.
8. **Uso de Bootstrap**: se asume Bootstrap para layout y componentes; confirmar si se usa el JS de Bootstrap o componentes propios.
9. **Estrategia de pruebas de navegación**: definir pruebas de integración del shell, historial y fragmentos.

---

## 16. Fases de implementación sugeridas

1. Layout Twig, CSS del shell y menú renderizado en servidor.
2. Manifiestos de módulo, metadatos de rutas y servicio de menú.
3. `ScreenRenderer` con detección de fragmento y página completa.
4. Cliente de navegación: `App.navigate`, `history`, `popstate`, ciclo de vida y errores.
5. Cliente de API y manejo de CSRF.
6. Pantalla piloto `dashboard/index` y una pantalla con filtros.
7. Pruebas de navegación directa, atrás/adelante, permisos, sesión expirada y accesibilidad.
