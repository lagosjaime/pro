# Especificación: Input con Búsqueda / Autocomplete General — Aplicación `pr`

| Campo | Valor |
| --- | --- |
| Versión | 0.1 (borrador) |
| Fecha | 2026-10-24 |
| Estado | Para revisión e implementación |
| Alcance | Componente reutilizable para inputs con búsqueda, filtrado, selección, limpieza y callbacks |
| Documentos relacionados | [`frontend-datatables-layout.md`](frontend-datatables-layout.md), [`layout-pantallas-detallado.md`](layout-pantallas-detallado.md), [`pantallas.md`](pantallas.md), [`AGENTS.md`](../../AGENTS.md) |

> Se requiere un componente único y reutilizable para campos tipo "buscar y seleccionar" (usuarios, clientes, productos, etc.). Cada pantalla solo deberá llamar a la función general pasando su configuración particular.

---

## 1. Objetivo

Crear una función general `App.InputSearch.init(config)` que:
- Genere el input con botón de búsqueda/limpieza
- Muestre un dropdown con resultados filtrados
- Permita seleccionar un elemento
- Guarde el valor seleccionado (id + texto)
- Sea reutilizable por cualquier pantalla
- Soporte búsqueda remota vía API o datos locales
- Sea compatible con Bootstrap 5.3

---

## 2. Comportamiento

### 2.1 Flujo
1. Usuario escribe mínimo N caracteres (configurable, default 2)
2. Se realiza búsqueda (debounce) contra API o arreglo local
3. Se muestran resultados en dropdown
4. Al seleccionar, se llena el input con el texto visible, se guarda el valor (id) en un input oculto
5. Se puede limpiar con botón "X"
6. Al limpiar, se dispara callback `onClear`

### 2.2 Características
- Debounce para evitar muchas peticiones
- Mínimo de caracteres para buscar
- Dropdown con scroll si hay muchos resultados
- Resaltar coincidencias (opcional)
- Soporte teclado (flechas, Enter, Escape)
- Botón limpiar integrado
- Muestra "Sin resultados"
- Loading state
- Validación opcional

---

## 3. HTML Generado

```html
<div class="input-search-wrapper" data-input-search="usuario">
  <div class="input-group">
    <input type="text" class="form-control form-control-sm input-search-text" 
           placeholder="Buscar..." autocomplete="off">
    <input type="hidden" class="input-search-value" name="idusuario" value="">
    <button class="btn btn-outline-secondary btn-sm btn-search-clear" type="button" title="Limpiar">
      <i class="bi bi-x"></i>
    </button>
    <button class="btn btn-outline-primary btn-sm btn-search-do" type="button" title="Buscar">
      <i class="bi bi-search"></i>
    </button>
  </div>
  <div class="input-search-dropdown" style="display:none">
    <div class="input-search-results"></div>
  </div>
</div>
```

---

## 4. API de la Función General

### 4.1 Firma
```js
/**
 * Inicializa input con búsqueda
 * @param {Object} config
 * @param {string} config.container - Selector del contenedor donde se generará
 * @param {string} [config.name] - Nombre para el input hidden
 * @param {string} [config.placeholder] - Placeholder
 * @param {number} [config.minChars=2] - Mínimo caracteres para buscar
 * @param {number} [config.debounce=300] - Debounce en ms
 * @param {string} [config.url] - URL API para búsqueda remota
 * @param {Object} [config.urlParams] - Parámetros extra
 * @param {Array} [config.data] - Datos locales (alternativa a url)
 * @param {string} [config.valueField='id'] - Campo clave
 * @param {string} [config.textField='nombre'] - Campo texto visible
 * @param {string} [config.searchField] - Campo para filtrar (default textField)
 * @param {Function} [config.mapItem] - Mapear item personalizado
 * @param {Function} [config.onSelect] - Callback al seleccionar (item)
 * @param {Function} [config.onClear] - Callback al limpiar
 * @param {Function} [config.onSearch] - Callback al buscar
 * @param {Object} [config.renderItem] - Función para renderizar item
 * @param {boolean} [config.allowClear=true] - Permitir limpiar
 * @param {boolean} [config.showButton=true] - Mostrar botón buscar
 */
App.InputSearch.init(config)
```

### 4.2 Implementación base
```js
App.InputSearch.init = function(config) {
  const defaults = {
    minChars: 2,
    debounce: 300,
    valueField: 'id',
    textField: 'nombre',
    allowClear: true,
    showButton: true,
    urlParams: {}
  };
  
  const opts = $.extend(true, {}, defaults, config);
  const $container = $(opts.container);
  
  // Generar HTML
  const html = App.InputSearch.renderTemplate(opts);
  $container.html(html);
  
  const $text = $container.find('.input-search-text');
  const $value = $container.find('.input-search-value');
  const $dropdown = $container.find('.input-search-dropdown');
  const $results = $container.find('.input-search-results');
  const $btnClear = $container.find('.btn-search-clear');
  const $btnSearch = $container.find('.btn-search-do');
  
  let timer = null;
  let items = [];
  
  function search(term) {
    if (term.length < opts.minChars) {
      $dropdown.hide();
      return;
    }
    
    $results.html('<div class="input-search-loading">Buscando...</div>');
    $dropdown.show();
    
    if (opts.url) {
      // Búsqueda remota
      const params = $.extend({}, opts.urlParams, { q: term });
      App.api(opts.url, { method: 'POST', body: JSON.stringify(params) })
        .then(resp => {
          items = resp.data.items || resp.data || [];
          renderResults(items, term);
        })
        .catch(() => {
          $results.html('<div class="input-search-empty">Error al buscar</div>');
        });
    } else if (opts.data) {
      // Búsqueda local
      const searchField = opts.searchField || opts.textField;
      items = opts.data.filter(item => {
        const val = (item[searchField] || '').toString().toLowerCase();
        return val.includes(term.toLowerCase());
      });
      renderResults(items, term);
    }
  }
  
  function renderResults(list, term) {
    if (list.length === 0) {
      $results.html('<div class="input-search-empty">Sin resultados</div>');
      return;
    }
    
    let html = '';
    list.forEach(item => {
      const text = opts.mapItem ? opts.mapItem(item) : item[opts.textField];
      const value = item[opts.valueField];
      html += `<div class="input-search-item" data-value="${value}" data-text="${text}">${text}</div>`;
    });
    $results.html(html);
    
    $results.find('.input-search-item').on('click', function() {
      const val = $(this).data('value');
      const txt = $(this).data('text');
      selectItem({ [opts.valueField]: val, [opts.textField]: txt }, txt, val);
    });
  }
  
  function selectItem(item, text, value) {
    $text.val(text);
    $value.val(value);
    $dropdown.hide();
    if (opts.onSelect) opts.onSelect(item);
  }
  
  function clear() {
    $text.val('');
    $value.val('');
    $dropdown.hide();
    if (opts.onClear) opts.onClear();
  }
  
  // Eventos
  $text.on('input', function() {
    clearTimeout(timer);
    const term = $(this).val();
    timer = setTimeout(() => search(term), opts.debounce);
  });
  
  $text.on('keydown', function(e) {
    if (e.key === 'Escape') $dropdown.hide();
  });
  
  $btnClear.on('click', clear);
  $btnSearch.on('click', function() {
    search($text.val());
  });
  
  // Cerrar dropdown al click fuera
  $(document).on('click.inputsearch', function(e) {
    if (!$container[0].contains(e.target)) {
      $dropdown.hide();
    }
  });
  
  return {
    getValue: () => $value.val(),
    getText: () => $text.val(),
    setValue: (val, text) => selectItem({ [opts.valueField]: val, [opts.textField]: text }, text, val),
    clear: clear,
    destroy: () => {
      $(document).off('click.inputsearch');
      $container.empty();
    }
  };
};
```

---

## 5. Uso desde pantallas (funciones particulares)

### 5.1 Buscar Usuario
```js
// En la pantalla
function buscarUsuario() {
  const search = App.InputSearch.init({
    container: '#buscar-usuario',
    name: 'idusuario',
    placeholder: 'Buscar usuario...',
    url: '/api/system/usuarios/buscar',
    valueField: 'idusuario',
    textField: 'usuario_nombre',
    searchField: 'usuario_nombre',
    minChars: 2,
    onSelect: function(item) {
      console.log('Usuario seleccionado:', item);
      $('#idusuario').val(item.idusuario);
      // cargar datos relacionados
    },
    onClear: function() {
      $('#idusuario').val('');
    }
  });
  
  return search;
}
```

### 5.2 Buscar Cliente
```js
function buscarCliente() {
  return App.InputSearch.init({
    container: '#buscar-cliente',
    placeholder: 'Buscar cliente...',
    url: '/api/ventas/clientes/buscar',
    valueField: 'idcliente',
    textField: 'cliente_razon_social',
    mapItem: function(item) {
      return item.cliente_razon_social + ' (' + item.cliente_rfc + ')';
    },
    onSelect: function(item) {
      cargarDatosCliente(item.idcliente);
    }
  });
}
```

### 5.3 Con datos locales
```js
function buscarProducto() {
  const productos = [...]; // desde API o cargados
  return App.InputSearch.init({
    container: '#buscar-producto',
    data: productos,
    valueField: 'idproducto',
    textField: 'producto_descripcion',
    onSelect: function(item) {
      agregarProducto(item);
    }
  });
}
```

---

## 6. Estilos CSS

```css
.input-search-wrapper {
  position: relative;
  width: 100%;
}

.input-search-dropdown {
  position: absolute;
  top: 100%;
  left: 0;
  right: 0;
  z-index: 1050;
  background: #fff;
  border: 1px solid var(--bs-border-color);
  border-top: none;
  border-radius: 0 0 0.25rem 0.25rem;
  max-height: 250px;
  overflow-y: auto;
  box-shadow: 0 4px 6px rgba(0,0,0,0.1);
}

.input-search-results {
  padding: 0.25rem 0;
}

.input-search-item {
  padding: 0.375rem 0.75rem;
  cursor: pointer;
  font-size: 0.875rem;
}

.input-search-item:hover {
  background-color: var(--bs-primary-bg-subtle);
}

.input-search-loading,
.input-search-empty {
  padding: 0.5rem 0.75rem;
  font-size: 0.875rem;
  color: var(--bs-secondary);
  text-align: center;
}
```

---

## 7. Integración con pantallas

### 7.1 HTML
```html
<div class="col-md-6">
  <label class="form-label">Usuario</label>
  <div id="buscar-usuario"></div>
</div>
```

### 7.2 En mount()
```js
App.screens.register('ventas/pedido', {
  usuarioSearch: null,
  
  mount(root, context) {
    this.usuarioSearch = buscarUsuario();
  },
  
  unmount() {
    if (this.usuarioSearch) {
      this.usuarioSearch.destroy();
      this.usuarioSearch = null;
    }
  }
});
```

---

## 8. API del Backend para búsqueda

Los endpoints de búsqueda deben seguir el contrato:
```json
POST /api/<modulo>/<servicio>/buscar
{
  "q": "texto a buscar"
}

Respuesta:
{
  "status": "ok",
  "message": "OK",
  "data": {
    "items": [
      { "idusuario": 1, "usuario_nombre": "Juan Pérez" }
    ]
  }
}
```

- Límite razonable (ej: 20-50 resultados)
- Búsqueda con LIKE/ILIKE o fulltext
- Filtrar solo activos
- No paginar para este componente

---

## 9. Reglas importantes

- **Función única**: Toda búsqueda con autocomplete usa `App.InputSearch.init()`
- **Funciones particulares**: Cada pantalla crea su propia función wrapper con configuración específica
- **Debounce**: Siempre usar para búsquedas remotas
- **Mínimo caracteres**: Por defecto 2
- **Limpieza**: Siempre permitir limpiar si `allowClear` true
- **Bootstrap 5.3**: Usar clases del framework
- **Destruir**: Llamar `destroy()` en `unmount()` para evitar eventos duplicados
- **Hidden input**: Guardar siempre el ID/clave en input oculto
- **Sin paginación**: Mostrar resultados limitados directamente
- **Keyboard**: Soportar Escape para cerrar
- **Click fuera**: Cerrar dropdown al hacer click fuera

---

## 10. Checklist
- [ ] Función `App.InputSearch.init()` implementada
- [ ] Template HTML generado dinámicamente
- [ ] Soporte búsqueda remota y local
- [ ] Debounce y mínimo de caracteres
- [ ] Selección, limpieza, callbacks
- [ ] Estilos Bootstrap 5.3
- [ ] Funciones wrapper por tipo (usuario, cliente, etc.)
- [ ] Integración con sistema de pantallas
- [ ] Eventos con limpieza en unmount
