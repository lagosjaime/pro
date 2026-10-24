# Especificación Detallada del Layout de Pantallas — Aplicación `pr`

| Campo | Valor |
| --- | --- |
| Versión | 0.1 (borrador) |
| Fecha | 2026-10-24 |
| Estado | Para revisión e implementación |
| Alcance | Estructura completa de la interfaz: head, navbar, foot, work-area y subdivisiones work-header/work-center/work-footer con sus zonas internas |
| Documentos relacionados | [`pantallas.md`](pantallas.md), [`frontend-datatables-layout.md`](frontend-datatables-layout.md), [`arquitectura.md`](arquitectura.md), [`AGENTS.md`](../../AGENTS.md) |

> Esta especificación define la estructura visual definitiva del shell y del área de trabajo. Reemplaza las descripciones parciales anteriores con esta organización completa.

---

## 1. Objetivo

Definir la estructura jerárquica de la aplicación:
- Shell principal con `head`, `navbar`, `foot`
- `work-area` central-derecho para mostrar las pantallas
- Dentro de `work-area`: `work-header`, `work-center`, `work-footer`
- Dentro de `work-center`: `work-head`, `work-detail`, `work-foot` (opcionales)

---

## 2. Estructura General del Shell

```html
<body class="app-shell">
  <header id="app-head" class="app-head">
    <!-- Título de la aplicación -->
  </header>

  <nav id="app-navbar" class="app-navbar">
    <!-- Selector de módulos, menú del módulo, submenu usuario -->
  </nav>

  <main id="app-workarea" class="app-workarea">
    <!-- Aquí se carga la pantalla activa -->
  </main>

  <footer id="app-foot" class="app-foot">
    <!-- Copyright, versión, datos de la app -->
  </footer>
</body>
```

### 2.1 Zonas del Shell

| Zona | Ubicación | Propósito | Comportamiento |
| --- | --- | --- | --- |
| `head` | Superior | Título de la aplicación | Persistente, siempre visible |
| `navbar` | Izquierda lateral | Navegación principal | Persistente. Contiene: selector de módulos, opciones del módulo seleccionado, submenu del usuario |
| `foot` | Inferior | Información de la app | Persistente. Muestra copyright, versión, datos generales |
| `work-area` | Central-derecha | Área de trabajo donde se muestran las pantallas | Se reemplaza completamente al navegar entre pantallas. Única zona que cambia en navegación fragmento |

---

## 3. Navbar (Zona Lateral Izquierda)

```html
<nav id="app-navbar" class="app-navbar">
  <div class="navbar-module-select">
    <!-- Select con módulos autorizados -->
  </div>
  
  <div class="navbar-menu">
    <!-- Opciones y submenús del módulo seleccionado -->
  </div>
  
  <div class="navbar-user">
    <!-- Submenu del usuario (perfil, cambiar contraseña, cerrar sesión, etc.) -->
  </div>
</nav>
```

### 3.1 Elementos
| Elemento | Descripción |
| --- | --- |
| `navbar-module-select` | Selector desplegable con todos los módulos autorizados al usuario |
| `navbar-menu` | Árbol de carpetas/opciones del módulo actualmente seleccionado |
| `navbar-user` | Menú desplegable del usuario con opciones de cuenta y sistema |

---

## 4. Work-Area (Área Central-Derecha)

El `work-area` es el contenedor de cada pantalla. Se divide en 3 zonas principales:

```html
<div id="app-workarea" class="app-workarea">
  <div class="work-container">
    <header class="work-header">
      <!-- Título de pantalla y botonera -->
    </header>
    
    <main class="work-center">
      <!-- Contenido principal de la pantalla -->
    </main>
    
    <footer class="work-footer">
      <!-- Información inferior de la pantalla -->
    </footer>
  </div>
</div>
```

### 4.1 Zonas de Work-Area

| Zona | Ubicación | Propósito | Comportamiento |
| --- | --- | --- | --- |
| `work-header` | Superior del work-area | Título de la pantalla y botonera de operaciones | Altura fija/variable según contenido. Siempre presente. |
| `work-center` | Central | Contenido principal de la pantalla | Ocupa el espacio restante. Aquí se despliega la lógica de la pantalla. |
| `work-footer` | Inferior del work-area | Información de la pantalla | Altura variable. Siempre presente. |

---

## 5. Work-Header (Encabezado de la Pantalla)

```html
<header class="work-header">
  <div class="work-header-left">
    <!-- Botón "Volver" si viene de otra pantalla -->
    <button id="btn-volver" class="btn-volver" style="display:none">
      <i class="bi bi-arrow-left"></i> Volver
    </button>
    <h1 class="work-header-title">Título de la Pantalla</h1>
  </div>
  <div class="work-header-actions">
    <!-- Botonera de operaciones de la pantalla -->
    <button class="btn btn-primary">Guardar</button>
    <button class="btn btn-secondary">Cancelar</button>
  </div>
</header>
```

### 5.1 Reglas
- **Título**: Siempre visible en `work-header-title`
- **Botón Volver**: Solo se muestra cuando la pantalla fue llamada desde otra pantalla (navegación interna). Se coloca al lado izquierdo del título
- **Botonera**: Botones de operación propios de la pantalla (Guardar, Nuevo, Buscar, Eliminar, etc.)
- **Navegación hacia atrás**: El botón "Volver" debe regresar a la pantalla anterior usando `App.back()` o restaurando el estado del historial
- **Contexto**: Debe saber si viene de navegación interna vs navegación desde menú

---

## 6. Work-Footer (Pie de la Pantalla)

```html
<footer class="work-footer">
  <div class="work-footer-left">
    <span id="screen-load-info">
      Cargado: <span id="screen-load-datetime">2026-10-24 14:32:18</span>
      | Usuario: <span id="screen-user">jperez</span>
      <span id="screen-planta" style="display:none">| Planta: <span id="screen-planta-name"></span></span>
    </span>
  </div>
  <div class="work-footer-right">
    <!-- Solo en desarrollo -->
    <button id="btn-reload-screen" class="btn-reload" style="display:none" title="Recargar pantalla">
      <i class="bi bi-arrow-clockwise"></i> Recargar
    </button>
  </div>
</footer>
```

### 6.1 Elementos
| Elemento | Descripción |
| --- | --- |
| Fecha/hora de carga | Momento en que se cargó la pantalla. Se actualiza al montar |
| Usuario | Usuario actualmente autenticado |
| Planta de trabajo | Opcional. Solo si aplica al contexto de la aplicación |
| Botón recargar | **Solo visible en `APP_ENV === 'development'`**. Permite recargar la pantalla actual sin recargar todo el shell |

---

## 7. Work-Center y sus subdivisiones

El `work-center` es donde se desarrolla el contenido de la pantalla. Puede dividirse en hasta 3 zonas opcionales:

```html
<main class="work-center">
  <div class="work-center-container">
    <div id="wc-head" class="wc-head">
      <!-- Filtros, formulario de búsqueda/cabecera -->
    </div>
    
    <div id="wc-detail" class="wc-detail">
      <!-- Contenido principal: tablas, formularios, detalles -->
    </div>
    
    <div id="wc-foot" class="wc-foot">
      <!-- Información adicional: totales, resúmenes -->
    </div>
  </div>
</main>
```

### 7.1 Zonas internas del Work-Center

| Zona | Ubicación | Propósito | Obligatorio |
| --- | --- | ---tag |
| `wc-head` | Superior del work-center | Cabecera de la pantalla. Filtros, campos de búsqueda, formulario de cabecera | **No** |
| `wc-detail` | Central | Zona principal. Aquí van DataTables, formularios completos, detalles, grids | **No** (pero suele ser la más usada) |
| `wc-foot` | Inferior del work-center | Pie interno. Totales, sumatorias, información adicional | **No** |

### 7.2 Reglas
- **Todas opcionales**: Una pantalla puede usar solo `wc-detail`, o `wc-head` + `wc-detail`, o todas tres, o ninguna
- **Flexbox vertical**: Igual que antes, `wc-head` y `wc-foot` altura automática, `wc-detail` ocupa espacio restante
- **DataTables**: Cuando se use DataTable para listado, irá principalmente en `wc-detail`
- **Cálculo de altura**: Debe considerar todo el stack (shell + work-header + work-footer + wc-head + wc-foot)

---

## 8. Integración con DataTables

### 8.1 Ubicación
Los DataTables con listado van en `wc-detail` (dentro de `work-center`).

### 8.2 Cálculo de altura actualizado
La función debe calcular considerando:
- Altura de `app-head`, `app-navbar`, `app-foot`
- Altura de `work-header`, `work-footer`
- Altura de `wc-head`, `wc-foot` (si existen)
- Padding/márgenes

```js
App.DataTable.calculateHeight = function() {
  const shellH = $('#app-head').outerHeight(true) + 
                 $('#app-navbar').outerWidth ? 0 : 0; // navbar lateral
  const workHeaderH = $('.work-header').outerHeight(true) || 0;
  const workFooterH = $('.work-footer').outerHeight(true) || 0;
  const wcHeadH = $('#wc-head').outerHeight(true) || 0;
  const wcFootH = $('#wc-foot').outerHeight(true) || 0;
  const padding = 20;
  
  const available = window.innerHeight - 
                    $('#app-head').outerHeight(true) - 
                    $('#app-foot').outerHeight(true) - 
                    workHeaderH - 
                    workFooterH - 
                    wcHeadH - 
                    wcFootH - 
                    padding;
  
  return Math.max(200, available) + 'px';
};
```

---

## 9. Navegación y botón "Volver"

### 9.1 Detección
Cuando una pantalla navega a otra usando `App.navigate()`, se debe guardar en `history.state`:
```js
{
  "navId": "...",
  "screenId": "ventas/pedido-detalle",
  "fromScreenId": "ventas/pedidos",
  "canGoBack": true,
  "backUrl": "/ventas/pedidos"
}
```

### 9.2 Mostrar botón
En `work-header`, si `state.canGoBack` o hay entrada anterior en historial válida:
```js
$('#btn-volver').show().off('click').on('click', () => {
  App.back();
});
```

### 9.3 Comportamiento
- Al volver, restaurar pantalla, filtros, scroll y estado
- El título sigue mostrando el título de la pantalla actual
- Botón siempre al lado izquierdo del título

---

## 10. Información de pantalla en work-footer

### 10.1 Datos mostrados
```js
App.screens.registerScreenInfo = function(screenId, title) {
  $('#screen-load-datetime').text(new Date().toLocaleString('es-MX'));
  $('#screen-user').text(window.APP_USER.nombre || window.APP_USER.login);
  if (window.APP_USER.planta) {
    $('#screen-planta').show();
    $('#screen-planta-name').text(window.APP_USER.planta);
  }
  if (window.APP_ENV === 'development') {
    $('#btn-reload-screen').show().off('click').on('click', () => {
      App.reload();
    });
  }
};
```

### 10.2 Cuándo actualizar
Se llama en `mount()` de cada pantalla.

---

## 11. Clases CSS sugeridas

```css
.app-shell {
  display: grid;
  grid-template-areas:
    "head head"
    "navbar workarea"
    "foot foot";
  grid-template-columns: 250px 1fr;
  grid-template-rows: 50px 1fr 30px;
  height: 100vh;
}

.app-head { grid-area: head; }
.app-navbar { grid-area: navbar; overflow-y: auto; }
.app-workarea { grid-area: workarea; overflow: hidden; }
.app-foot { grid-area: foot; }

.work-container {
  display: flex;
  flex-direction: column;
  height: 100%;
  padding: 0.5rem;
}

.work-header {
  flex: 0 0 auto;
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.5rem;
  margin-bottom: 0.5rem;
}

.work-header-left {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.work-center {
  flex: 1 1 auto;
  overflow: hidden;
}

.work-center-container {
  display: flex;
  flex-direction: column;
  height: 100%;
}

.wc-head { flex: 0 0 auto; padding: 0.5rem; }
.wc-detail { flex: 1 1 auto; overflow: hidden; }
.wc-foot { flex: 0 0 auto; padding: 0.5rem; }

.work-footer {
  flex: 0 0 auto;
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.25rem 0.5rem;
  font-size: 0.875rem;
}
```

---

## 12. Reglas de implementación

- **Persistente**: `head`, `navbar`, `foot` nunca se reemplazan
- **Solo cambia**: `work-area` completo al navegar entre pantallas
- **Opcionales**: `wc-head`, `wc-detail`, `wc-foot` pueden no existir
- **Botón volver**: Solo visible cuando proviene de navegación interna
- **Footer info**: Siempre muestra carga/usuario, botón recargar solo en development
- **DataTables**: Van en `wc-detail` cuando aplique
- **Altura dinámica**: Recalcular en resize y al cambiar contenido
- **Limpieza**: Destruir componentes al salir de pantalla
- **Bootstrap 5.3**: Usar clases estándar

---

## 13. Checklist

- [ ] Estructura shell con head/navbar/foot
- [ ] work-area con work-header/work-center/work-footer
- [ ] work-center con wc-head/wc-detail/wc-foot opcionales
- [ ] Botón "Volver" con detección de navegación interna
- [ ] work-footer con info de carga/usuario/planta y botón recargar (dev)
- [ ] Integración con DataTables en wc-detail
- [ ] Cálculo dinámico de alturas
- [ ] CSS Grid para shell, Flexbox para áreas
