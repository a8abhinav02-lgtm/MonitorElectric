# Regla: Diseño de Interfaz Responsiva, Adaptativa y Mejores Prácticas UI/UX (6" a 10")

### 1. Compatibilidad de Pantalla y Factor de Forma (6" a 10")
- La aplicación debe ser completamente operativa, ergonómica y visualmente impecable en smartphones (desde 360dp de ancho) y tabletas de inspección (hasta 10" / 900+dp).
- Todo layout debe probarse y soportar factores de escala de texto del sistema operativo (`textScaler >= 1.4` para accesibilidad) sin generar excepciones `RenderFlex overflow`.

### 2. Estructura y Manejo de Filas (`Row` vs `Wrap` / `LayoutBuilder`)
- **Prohibido:** Encadenar elementos de ancho variable (etiquetas de texto, chips de selección, dropdowns, botones con icono) dentro de un `Row` horizontal rígido sin restricción o sin tolerancia de salto de línea.
- **Obligatorio:**
  - Usar `Wrap(spacing: 8, runSpacing: 8, ...)` para grupos de chips, filtros o selectores de opciones.
  - Para formularios de dos o más columnas en teléfonos (`width < 600dp` o con fuentes aumentadas), permitir que los campos se apilen verticalmente o emplear `LayoutBuilder` / `Flex`.
  - Asegurar que textos largos dentro de filas siempre utilicen `Expanded` o `Flexible` con `TextOverflow.ellipsis`.

### 3. Posicionamiento Seguro y Barras del Sistema (Android Navigation Bar)
- Los botones de acción primaria ("Guardar", "Registrar", "Continuar") nunca deben ubicarse al final de un `SingleChildScrollView` sin margen inferior seguro.
- Preferir siempre alojar las acciones principales en el `bottomNavigationBar` del `Scaffold`, envueltas obligatoriamente en `SafeArea` con padding inferior para que jamás queden solapadas por los botones de navegación o la barra de gestos de MIUI/Android.

### 4. Adaptación Ergonómica en Tabletas (>= 600dp)
- En pantallas grandes (tablets 7" a 10"):
  - Delimitar el ancho máximo de formularios con `ConstrainedBox(constraints: BoxConstraints(maxWidth: ...))` para evitar campos excesivamente estirados.
  - Utilizar distribuciones de múltiples columnas (`GridView` o paneles maestro-detalle) donde aporte valor a la ergonomía de inspección.

### 5. Mejores Prácticas de UI/UX Industrial
- **Jerarquía Visual Clara:** Contraste tipográfico y cromático accesible (estándar WCAG AA), facilitando la lectura bajo luz solar directa o en subestaciones.
- **Zonas Táctiles Adecuadas:** Botones y elementos interactivos con área mínima táctil de 48x48dp, aptos para operación en campo incluso con guantes.
- **Retroalimentación Inmediata:** Indicadores de estado de carga (`CircularProgressIndicator`), deshabilitación preventiva de botones para evitar dobles envíos y banners/snackbars claros de confirmación o error.
- **Consistencia Visual y Espaciado:** Respetar la cuadrícula base de diseño (múltiplos de 4/8dp) y paleta de colores semántica para severidad térmica (Normal = verde, Alerta/Deficiencia = naranja/ámbar, Crítico/Emergencia = rojo).
