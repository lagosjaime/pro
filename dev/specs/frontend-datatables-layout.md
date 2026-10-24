# Especificación Frontend: Layout de trabajo, DataTables, búsqueda, exportación — Aplicación `pr`

| Campo | Valor |
| --- | --- |
| Versión | 0.1 (borrador) |
| Fecha | 2026-10-24 |
| Estado | Para revisión e implementación |
| Alcance | Layout de área de trabajo (work-head/work-detail/work-foot), DataTables con Bootstrap 5.3, búsqueda, exportación PDF/Excel, sin paginación por defecto, cálculo automático de altura, función general reutilizable |
| Documentos relacionados | [`pantallas.md`](pantallas.md), [`arquitectura.md`](arquitectura.md), [`logs-desarrollo-auditoria.md`](logs-desarrollo-auditoria.md), [`AGENTS.md`](../../AGENTS.md) |

> El objetivo es estandarizar cómo se muestran listados en la aplicación. Se prioriza coherencia visual con Bootstrap 5.3 y reutilización mediante una función general para DataTables.

---

## 1. Objetivo

- Definir la estructura del área de trabajo en tres zonas: `work-head`, `work-detail`, `work-foot`
- Estandarizar el uso de DataTables con Bootstrap 5.3 para listados
- Incluir búsqueda y exportación a PDF y Excel
- **Sin paginación** por defecto (cuando hay muchos datos se solicitarán filtros antes de cargar)
- Calcular automáticamente la altura del `work-detail` según el espacio disponible
- Centralizar configuración en una función general reutilizable
- Permitir configuración por pantalla (columnas, formatos, opciones particulares)

---

## 2. Estructura del área de trabajo

El `workspace` se divide en tres áreas principales:

```html
<main id="app-workspace" class="app-workspace">
  <div class="work-area">
    <div id="work-head" class="work-head">
      <!-- Título, filtros, botones, acciones -->
    </div>
    <div id="work-detail" class="work-detail">
      <!-- DataTable o contenido principal -->
    </div>
    <div id="work-foot" class="work-foot">
      <!-- Totales, información, acciones secundarias -->
    </div>
  </div>
</main>
```

### 2.1 Zonas

| Zona | Propósito | Comportamiento |
| --- | --- | --- |
| `work-head` | Encabezado de la pantalla. Título, filtros obligatorios, botones de acción (Nuevo, Buscar, Limpiar). | Altura variable según contenido. Siempre visible. |
| `work-detail` | Contenido principal. Principalmente DataTables. Puede contener otros elementos pero **los listados van aquí**. | Ocupa el espacio restante. Debe redimensionarse automáticamente. |
| `work-foot` | Pie de pantalla. Totales, resúmenes, información complementaria. | Altura variable según contenido. Siempre visible. |

### 2.2 Reglas
- El contenedor `work-area` usa Flexbox vertical con `height: 100%`
- `work-head` y `work-foot` tienen altura según su contenido (`flex: 0 0 auto`)
- `work-detail` ocupa el espacio restante (`flex: 1 1 auto`) con `overflow: hidden` o `overflow: auto` según necesidad
- El cálculo de altura debe considerar header/sidebar/footer del shell y márgenes
- Debe recalcularse en `resize` de ventana y al montar/desmontar pantalla

---

## 3. DataTables con Bootstrap 5.3

### 3.1 Librerías requeridas
Se usarán las librerías estándar con integración Bootstrap 5:

| Librería | Uso |
| --- | --- |
| `jquery` | Requerido por DataTables |
| `datatables.net` | Core |
| `datatables.net-bs5` | Integración Bootstrap 5 |
| `datatables.net-buttons-bs5` | Botones con estilo Bootstrap 5 |
| `datatables.net-buttons/js/buttons.html5.min.js` | Exportación HTML5 |
| `datatables.net-buttons/js/buttons.print.min.js` | Impresión (opcional) |
| `jszip` | Requerido para exportación Excel |
| `pdfmake` | Requerido para exportación PDF |
| `datatables.net-responsive-bs5` | Responsive (opcional, evaluar según caso) |

### 3.2 Configuración general
Todas las pantallas con listado usarán una función central: `App.DataTable.init(config)`

#### Configuración base por defecto
```js
{
  dom: 'Bfrtip',
  buttons: [
    {
      extend: 'excelHtml5',
      text: '<i class="bi bi-file-earmark-excel"></i> Excel',
      className: 'btn btn-success btn-sm'
    },
    {
      extend: 'pdfHtml5',
      text: '<i class="bi bi-file-earmark-pdf"></i> PDF',
      className: 'btn btn-danger btn-sm'
    }
  ],
  paging: false,        // SIN PAGINACIÓN por defecto
  searching: true,      // Búsqueda habilitada
  ordering: true,       // Ordenamiento habilitado
  info: true,           // Información "Mostrando X registros"
  scrollY: null,        // Se calcula dinámicamente
  scrollCollapse: true,
  autoWidth: false,
  language: {
    url: '/assets/js/datatables/es-ES.json'
  },
  responsive: false,    // Según necesidad
}
```

### 3.3 Sin paginación
- `paging: false` por defecto
- Si la cantidad de datos puede ser muy grande, **se debe solicitar filtros en `work-head` antes de cargar**
- El API debe aceptar filtros obligatorios cuando aplique
- No se implementará paginación cliente/servidor salvo justificación explícita documentada

### 3.4 Búsqueda
- Búsqueda global habilitada (`searching: true`)
- Puede deshabilitarse por columna o configurarse por pantalla
- Se integra con el estilo Bootstrap 5

### 3.5 Exportación PDF y Excel
- **Excel**: usando `buttons.html5` con `JSZip`
- **PDF**: usando `buttons.html5` con `pdfmake`
- Botones siempre visibles en la barra de herramientas cuando aplique
- Se exportarán **todos los datos cargados** (sin paginación)
- Se puede personalizar título, orientación, columnas a exportar por pantalla
- Se recomienda omitir columnas de acciones en exportación cuando sea necesario

---

## 4. Función general para DataTables

### 4.1 API
```js
/**
 * Inicializa DataTable con configuración estándar
 * @param {Object} config
 * @param {string} config.selector - Selector CSS del table
 * @param {Array} config.columns - Definición de columnas DataTables
 * @param {Array} config.data - Datos o URL para AJAX
 * @param {string} [config.ajaxUrl] - URL para cargar datos vía AJAX
 * @param {Object} [config.ajaxData] - Parámetros adicionales para AJAX
 * @param {Object} [config.buttons] - Botones personalizados (se fusionan con defaults)
 * @param {Object} [config.columnDefs] - Definiciones adicionales
 * @param {Function} [config.onDraw] - Callback al dibujar
 * @param {Function} [config.onInit] - Callback al inicializar
 * @param {boolean} [config.autoHeight=true] - Calcular altura automáticamente
 */
App.DataTable.init(config)
```

### 4.2 Implementación base
```js
App.DataTable.init = function(config) {
  const defaults = {
    dom: 'Bfrtip',
    paging: false,
    searching: true,
    ordering: true,
    info: true,
    scrollY: this.calculateHeight(),
    scrollCollapse: true,
    autoWidth: false,
    language: App.DataTable.langEs,
    buttons: App.DataTable.defaultButtons
  };
  
  const options = $.extend(true, {}, defaults, config);
  const table = $(config.selector).DataTable(options);
  
  if (config.autoHeight !== false) {
    App.DataTable.bindResize(table);
  }
  
  return table;
};
```

### 4.3 Cálculo automático de altura
```js
App.DataTable.calculateHeight = function() {
  const $workspace = $('#app-workspace');
  const $workHead = $('#work-head');
  const $workFoot = $('#work-foot');
  const $workDetail = $('#work-detail');
  
  const workspaceHeight = $workspace.innerHeight();
  const headHeight = $workHead.outerHeight(true) || 0;
  const footHeight = $workFoot.outerHeight(true) || 0;
  const padding = 20; // margen/padding del detalle
  
  const detailHeight = workspaceHeight - headHeight - footHeight - padding;
  return Math.max(200, detailHeight) + 'px';
};
```

### 4.4 Redimensionamiento
- Escuchar `resize` del window con debounce
- Al cambiar de pantalla, destruir DataTable correctamente con `.destroy()`
- Recalcular al mostrar/ocultar elementos en `work-head` o `work-foot`
- Usar `table.columns.adjust().draw()` tras redimensionar

---

## 5. Configuración por pantalla

Cada pantalla define sus particularidades:

### 5.1 Estructura de pantalla con listado
```twig
<section class="app-screen" data-screen-id="ventas/pedidos" data-screen-title="Pedidos">
  <div class="work-area">
    <div id="work-head" class="work-head">
      <div class="row g-2 align-items-end">
        <div class="col-auto">
          <label class="form-label">Fecha desde</label>
          <input type="date" class="form-control form-control-sm" id="f-desde">
        </div>
        <div class="col-auto">
          <label class="form-label">Fecha hasta</label>
          <input type="date" class="form-control form-control-sm" id="f-hasta">
        </div>
        <div class="col-auto">
          <button class="btn btn-primary btn-sm" id="btn-buscar">Buscar</button>
          <button class="btn btn-secondary btn-sm" id="btn-limpiar">Limpiar</button>
        </div>
      </div>
    </div>
    
    <div id="work-detail" class="work-detail">
      <table id="tbl-pedidos" class="table table-striped table-hover table-sm w-100">
        <thead>
          <tr>
            <th>Folio</th>
            <th>Cliente</th>
            <th>Fecha</th>
            <th>Total</th>
            <th>Estado</th>
            <th>Acciones</th>
          </tr>
        </thead>
        <tbody></tbody>
      </table>
    </div>
    
    <div id="work-foot" class="work-foot">
      <div class="d-flex justify-content-between">
        <span>Total de registros: <strong id="total-reg">0</strong></span>
        <span>Total importe: <strong id="total-imp">$0.00</strong></span>
      </div>
    </div>
  </div>
</section>
```

### 5.2 JS de la pantalla
```js
App.screens.register('ventas/pedidos', {
  table: null,
  
  mount(root, context) {
    this.initFilters();
    this.loadData();
  },
  
  initFilters() {
    $('#btn-buscar').on('click', () => this.loadData());
    $('#btn-limpiar').on('click', () => {
      $('#f-desde, #f-hasta').val('');
      this.loadData();
    });
  },
  
  async loadData() {
    const filters = {
      desde: $('#f-desde').val(),
      hasta: $('#f-hasta').val()
    };
    
    const resp = await App.api('/api/ventas/pedidos/listar', {
      method: 'POST',
      body: JSON.stringify(filters)
    });
    
    if (this.table) {
      this.table.destroy();
      $('#tbl-pedidos tbody').empty();
    }
    
    this.table = App.DataTable.init({
      selector: '#tbl-pedidos',
      data: resp.data.items,
      columns: [
        { data: 'folio' },
        { data: 'cliente_nombre' },
        { data: 'fecha' },
        { data: 'total', className: 'text-end' },
        { data: 'estado' },
        { data: 'acciones', orderable: false, searchable: false }
      ],
      columnDefs: [
        {
          targets: 3,
          render: App.DataTable.formatCurrency
        }
      ],
      buttons: [
        {
          extend: 'excelHtml5',
          text: '<i class="bi bi-file-earmark-excel"></i> Excel',
          title: 'Pedidos',
          exportOptions: {
            columns: [0,1,2,3,4] // excluir acciones
          }
        },
        {
          extend: 'pdfHtml5',
          text: '<i class="bi bi-file-earmark-pdf"></i> PDF',
          title: 'Pedidos',
          orientation: 'landscape',
          exportOptions: {
            columns: [0,1,2,3,4]
          }
        }
      ],
      onDraw: () => {
        $('#total-reg').text(resp.data.total || resp.data.items.length);
        // calcular totales
      }
    });
  },
  
  unmount() {
    if (this.table) {
      this.table.destroy();
      this.table = null;
    }
    $('#btn-buscar, #btn-limpiar').off();
  }
});
```

---

## 6. Estilos CSS

### 6.1 Layout
```css
.app-workspace {
  height: calc(100vh - var(--header-height) - var(--footer-height));
  overflow: hidden;
}

.work-area {
  display: flex;
  flex-direction: column;
  height: 100%;
  padding: 0.5rem;
}

.work-head {
  flex: 0 0 auto;
  padding: 0.5rem;
  background: var(--bs-light);
  border: 1px solid var(--bs-border-color);
  border-radius: 0.25rem;
  margin-bottom: 0.5rem;
}

.work-detail {
  flex: 1 1 auto;
  min-height: 200px;
  overflow: hidden;
  border: 1px solid var(--bs-border-color);
  border-radius: 0.25rem;
}

.work-foot {
  flex: 0 0 auto;
  padding: 0.25rem 0.5rem;
  background: var(--bs-light);
  border: 1px solid var(--bs-border-color);
  border-radius: 0.25rem;
  margin-top: 0.5rem;
}
```

### 6.2 DataTables Bootstrap 5
```css
.work-detail .dataTables_wrapper {
  height: 100%;
  display: flex;
  flex-direction: column;
}

.work-detail .dt-buttons {
  padding: 0.5rem;
}

.work-detail .dataTables_filter {
  padding: 0.5rem;
}

.work-detail .dataTables_scroll {
  flex: 1 1 auto;
  overflow: hidden;
}

.work-detail .dataTables_scrollBody {
  overflow: auto !important;
}

.work-detail table.dataTable {
  margin-top: 0 !important;
}
```

---

## 7. Helpers y utilidades
```js
App.DataTable.formatCurrency = function(data) {
  return new Intl.NumberFormat('es-MX', {
    style: 'currency',
    currency: 'MXN'
  }).format(data || 0);
};

App.DataTable.langEs = {
  url: '/assets/js/datatables/es-ES.json'
};

App.DataTable.defaultButtons = [
  {
    extend: 'excelHtml5',
    text: '<i class="bi bi-file-earmark-excel"></i> Excel',
    className: 'btn btn-success btn-sm'
  },
  {
    extend: 'pdfHtml5',
    text: '<i class="bi bi-file-earmark-pdf"></i> PDF',
    className: 'btn btn-danger btn-sm'
  }
];
```

---

## 8. Reglas importantes

- **Sin paginación**: Siempre `paging: false` a menos que exista justificación documentada y aprobada
- **Filtros antes de cargar**: Si se espera gran cantidad de datos, obligar filtros en `work-head`
- **Altura automática**: Siempre usar cálculo dinámico para `scrollY`
- **Bootstrap 5.3**: Usar clases y estilos de Bootstrap 5.3
- **Reutilizable**: Toda configuración común va en `App.DataTable`
- **Limpieza**: Destruir DataTable en `unmount()` para evitar memory leaks
- **Exportación**: Excluir columnas de acciones en PDF/Excel
- **Búsqueda global**: Habilitada por defecto
- **Responsive**: Evaluar por pantalla, no forzar global

---

## 9. Checklist
- [ ] Estructura HTML con work-head/work-detail/work-foot
- [ ] CSS para layout flex
- [ ] Función `App.DataTable.init()` con defaults
- [ ] Cálculo automático de altura con resize
- [ ] Botones Excel/PDF con JSZip/pdfmake
- [ ] Traducción español
- [ ] Ejemplo de pantalla piloto
- [ ] Limpieza en unmount
