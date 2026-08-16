# 📋 DataCare — Plan de Acción Integral

**Aplicación de gestión clínica y estética para cosmetóloga independiente**
**Fecha:** 15 de Agosto de 2026
**Estado:** ⏳ Pendiente de aprobación

---

## 1. Resumen Ejecutivo

DataCare es una aplicación de escritorio local que centraliza la gestión de pacientes, sesiones, tratamientos, fotos comparativas y reportes clínicos. Reemplaza un flujo fragmentado basado en archivos Excel individuales por paciente.

### Stack Tecnológico Validado

| Componente | Tecnología | Versión/Estado |
|---|---|---|
| **Frontend** | Flutter Desktop (Material 3) | Stable channel |
| **Bridge Flutter↔Rust** | `flutter_rust_bridge` v2 | v2.12.0 (estable, madura) |
| **Backend / Lógica pesada** | Rust | Edición 2024 |
| **Base de datos** | SQLite embebido vía `rusqlite` | Gestionado desde Rust |
| **Parseo Excel** | `calamine` | v0.36.1 |
| **Generación PDF** | `typst` (como librería) + `printpdf` (fallback) | Evaluado |
| **Compresión de fotos** | `image` crate | Estable |
| **Tema dinámico Windows** | `dynamic_color` + `system_theme` | Soportado en Windows |
| **CI/CD** | GitHub Actions (`windows-latest`) | Runner nativo Windows |
| **Instalador** | Inno Setup (`.exe`) | Via GitHub Actions |

---

## 2. Hallazgos Clave de la Investigación

### 2.1 Integración Flutter + Rust

> [!IMPORTANT]
> **Decisión: `flutter_rust_bridge` v2 (v2.12.0)** como puente principal.

**¿Por qué `flutter_rust_bridge` sobre `rinf`?**

| Criterio | `flutter_rust_bridge` v2 | `rinf` v8.10.0 |
|---|---|---|
| Madurez | Alta — amplia adopción, documentación exhaustiva | Media — en crecimiento activo |
| Codegen | Genera bindings Dart automáticamente desde Rust | Usa mensajería con Serde |
| Patrón de comunicación | FFI directo con tipos complejos, async nativo | Mensajes serializados (anteriormente Protobuf) |
| Soporte desktop Windows | ✅ Completo | ✅ Completo |
| Complejidad de setup | Media (requiere codegen) | Baja (sin codegen manual) |
| Idóneo para lógica compleja | ✅ Superior — llamadas directas a funciones Rust con tipos ricos | Aceptable pero menos ergonómico |

**Arquitectura recomendada:**
- **Flutter**: Exclusivamente UI, navegación, estado (Riverpod/BLoC) y presentación Material 3.
- **Rust**: Toda la lógica de negocio, acceso a datos (SQLite via `rusqlite`), parseo de Excel, generación de PDFs, compresión de imágenes, backups.
- **Comunicación**: FFI asíncrono generado por `flutter_rust_bridge`. Flutter invoca funciones Rust como si fueran funciones Dart nativas.

```
┌─────────────────────────────────────────┐
│              Flutter (UI)               │
│  Material 3 · Riverpod · Navegación    │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │   flutter_rust_bridge (FFI)     │    │
│  └──────────────┬──────────────────┘    │
└─────────────────┼───────────────────────┘
                  │ Llamadas async FFI
┌─────────────────┼───────────────────────┐
│              Rust (Core)                │
│                                         │
│  ┌──────────┐ ┌──────────┐ ┌─────────┐ │
│  │ rusqlite │ │ calamine │ │  typst  │ │
│  │ (SQLite) │ │  (XLSX)  │ │  (PDF)  │ │
│  └──────────┘ └──────────┘ └─────────┘ │
│  ┌──────────┐ ┌───────────────────────┐ │
│  │  image   │ │    backup engine      │ │
│  │ (fotos)  │ │    (zip + SQLite)     │ │
│  └──────────┘ └───────────────────────┘ │
└─────────────────────────────────────────┘
```

### 2.2 SQLite: Gestionado desde Rust (no desde Flutter)

> [!TIP]
> SQLite se maneja exclusivamente desde el lado Rust con `rusqlite`. Esto centraliza toda la lógica de datos, evita dependencias duplicadas y garantiza que las migraciones, validaciones y consultas complejas se ejecuten en un solo lugar.

**Ventajas de este enfoque:**
- Un único punto de acceso a la DB → consistencia garantizada.
- `rusqlite` expone el SQLite Backup API directamente → backups automáticos sin dependencias extra.
- Migraciones controladas por versión en Rust.
- WAL mode habilitado para lecturas concurrentes mientras Rust escribe.

### 2.3 Tema Dinámico Material 3 en Windows

**Paquetes validados:**

| Paquete | Función | Soporte Windows |
|---|---|---|
| `dynamic_color` | Obtiene `ColorScheme` M3 del color de acento del SO | ✅ Sí (accent/glass color) |
| `system_theme` | Detecta modo claro/oscuro y color de acento | ✅ Sí (Windows, macOS, Linux) |

> [!NOTE]
> El paquete oficial `dynamic_color` de `material-foundation` fue archivado en 2023, pero existe un fork mantenido: **`dynamic_system_colors`**. La estrategia será usar `dynamic_color` con fallback a `ColorScheme.fromSeed()` y `system_theme` para detección de modo oscuro/claro en tiempo real.

**Patrón de implementación:**
```
DynamicColorBuilder → ColorScheme del SO → ThemeData Material 3
     ↓ (fallback si no hay color del SO)
ColorScheme.fromSeed(seedColor: defaultBrand)
     ↓
MediaQuery.platformBrightnessOf → Light/Dark mode reactivo
```

### 2.4 Parseo de Excel (.xlsx) con Rust

**`calamine` v0.36.1** — Crate de lectura de Excel madura y probada:

- ✅ Soporta `.xls`, `.xlsx`, `.xlsm`, `.xlsb`, `.ods`
- ✅ Manejo de múltiples hojas (`worksheet_range`, `sheet_names()`)
- ✅ Soporte para celdas combinadas (merged cells) — devuelve valor en celda superior-izquierda
- ✅ Enum `Data` con variantes: `Int`, `Float`, `String`, `Bool`, `DateTime`, `Empty`
- ✅ Deserialización con Serde via `RangeDeserializerBuilder`
- ✅ Streaming API (v0.36.0+) para archivos grandes

**Estrategia de parseo tolerante a fallos:**
1. Iterar todas las hojas del workbook.
2. Para cada fila, intentar mapear a un esquema conocido mediante heurísticas (buscar columnas con nombres como "Nombre", "Fecha", "Tratamiento", etc.).
3. Usar `match` exhaustivo sobre el enum `Data` para coerción flexible de tipos.
4. Registrar en un log de importación cada fila que no pudo parsearse, sin abortar la operación.
5. Presentar al usuario un reporte post-importación: X filas importadas, Y filas con advertencias, Z filas omitidas.

### 2.5 Generación de PDFs Clínicos

**Evaluación de opciones:**

| Crate | Capacidad | Tablas | Imágenes | Madurez | Recomendación |
|---|---|---|---|---|---|
| `typst` (librería) | Motor tipográfico completo, genera PDF programáticamente | ✅ Nativo | ✅ Nativo | Alta (motor de Typst) | ⭐ **Principal** |
| `printpdf` | API de bajo nivel para construir PDFs | Manual | ✅ | Alta | Fallback |
| `genpdf` | API de alto nivel sobre `printpdf` | ✅ Básico | ✅ | Media | Alternativa |

> [!TIP]
> **Decisión: Usar `typst` como librería Rust.** Permite definir plantillas `.typ` con sintaxis legible (similar a Markdown) que se renderizan a PDF programáticamente. Ideal para reportes clínicos con tablas, headers, footers, logo del consultorio y fotos embebidas.

### 2.6 Almacenamiento y Compresión de Fotos

**Estrategia con el crate `image`:**
- Fotos originales: almacenadas como **JPEG al 85% de calidad** (equilibrio calidad/tamaño).
- Thumbnails: generados automáticamente a 300px de ancho para previsualizaciones rápidas en la UI.
- Almacenamiento: directorio local organizado por `paciente_id/sesion_id/`.
- La DB SQLite almacena solo **rutas relativas** a las fotos, no los bytes.
- Metadatos EXIF relevantes (fecha, dimensiones) extraídos y almacenados en SQLite.

### 2.7 Backups Automáticos

**Estrategia de tres niveles:**

1. **Backup SQLite nativo**: Usando el SQLite Backup API desde `rusqlite` → copia atómica de la DB a un archivo `.db.bak` sin interrumpir operaciones.
2. **Backup completo comprimido**: Archivo `.zip` que incluye la DB + directorio de fotos. Programado cada N horas (configurable).
3. **Retención rotativa**: Conservar los últimos N backups (configurable, default 7) y eliminar los más antiguos automáticamente.

### 2.8 CI/CD para Windows (.exe)

> [!WARNING]
> **No es posible cross-compilar Flutter para Windows desde Linux.** Flutter requiere MSVC y el Windows SDK nativamente. Se debe usar un runner `windows-latest` en GitHub Actions.

**Pipeline validado:**

```
┌─ GitHub Actions (windows-latest) ─────────────────────┐
│                                                        │
│  1. Checkout código                                    │
│  2. Setup Flutter (stable)                             │
│  3. Setup Rust toolchain (stable)                      │
│  4. Install LLVM (requerido por flutter_rust_bridge)   │
│  5. flutter pub get                                    │
│  6. flutter build windows --release                    │
│  7. Compilar instalador con Inno Setup                 │
│  8. Upload artefacto a GitHub Releases                 │
│                                                        │
└────────────────────────────────────────────────────────┘
```

**Consideraciones de costos:**
- GitHub Actions free tier: 2,000 min/mes para repos privados.
- **Windows runners cuestan 2x** → equivalente a 1,000 minutos reales.
- Un build típico Flutter+Rust tarda ~8-15 min → ~65-125 builds/mes en free tier.

**Instalador:** Inno Setup generando un `.exe` instalador profesional con:
- Wizard de instalación.
- Acceso directo en escritorio y menú inicio.
- Desinstalador incluido.

---

## 3. Esquema de Base de Datos (Diseño Inicial)

```sql
-- Core
CREATE TABLE pacientes (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre          TEXT NOT NULL,
    apellido        TEXT NOT NULL,
    fecha_nacimiento DATE,
    telefono        TEXT,
    email           TEXT,
    direccion       TEXT,
    notas_generales TEXT,
    alergias        TEXT,
    condiciones_medicas TEXT,
    fecha_registro  DATETIME DEFAULT CURRENT_TIMESTAMP,
    activo          BOOLEAN DEFAULT 1
);

CREATE TABLE tratamientos (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre      TEXT NOT NULL UNIQUE,
    descripcion TEXT,
    duracion_min INTEGER,
    precio      REAL,
    activo      BOOLEAN DEFAULT 1
);

CREATE TABLE sesiones (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    paciente_id     INTEGER NOT NULL REFERENCES pacientes(id),
    tratamiento_id  INTEGER REFERENCES tratamientos(id),
    fecha           DATETIME NOT NULL,
    notas_sesion    TEXT,
    observaciones   TEXT,
    productos_usados TEXT,
    precio_cobrado  REAL,
    pagado          BOOLEAN DEFAULT 0,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Fotos comparativas
CREATE TABLE fotos_sesion (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    sesion_id   INTEGER NOT NULL REFERENCES sesiones(id),
    ruta_foto   TEXT NOT NULL,          -- Ruta relativa al directorio de fotos
    ruta_thumb  TEXT,                   -- Ruta al thumbnail
    tipo        TEXT CHECK(tipo IN ('antes', 'despues', 'durante', 'otra')),
    descripcion TEXT,
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Importación de Excel
CREATE TABLE importaciones (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    archivo_origen  TEXT NOT NULL,
    fecha_import    DATETIME DEFAULT CURRENT_TIMESTAMP,
    filas_ok        INTEGER DEFAULT 0,
    filas_warning   INTEGER DEFAULT 0,
    filas_error     INTEGER DEFAULT 0,
    log_detalle     TEXT                -- JSON con detalles de cada fila problemática
);

-- Configuración de la app
CREATE TABLE configuracion (
    clave   TEXT PRIMARY KEY,
    valor   TEXT NOT NULL
);

-- Migraciones
CREATE TABLE schema_version (
    version     INTEGER PRIMARY KEY,
    applied_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    description TEXT
);
```

---

## 4. Plan de Etapas Secuenciales

### Etapa 1 — Scaffolding y Arquitectura Base
**Objetivo:** Crear la estructura del proyecto con Flutter + Rust integrados y compilación funcional.

**Entregables:**
- [ ] Proyecto Flutter desktop inicializado con soporte Windows/Linux.
- [ ] Workspace Rust (Cargo) integrado via `flutter_rust_bridge` v2.
- [ ] Estructura de directorios definida:
  ```
  datacare/
  ├── lib/                    # Flutter (Dart)
  │   ├── main.dart
  │   ├── app.dart
  │   ├── src/
  │   │   ├── core/           # Theme, routing, constantes
  │   │   ├── features/       # Módulos por feature
  │   │   ├── shared/         # Widgets compartidos
  │   │   └── rust_bridge/    # Bindings generados
  ├── rust/                   # Código Rust
  │   ├── src/
  │   │   ├── api/            # Funciones expuestas a Flutter
  │   │   ├── db/             # SQLite, migraciones, queries
  │   │   ├── parser/         # Parseo de Excel
  │   │   ├── pdf/            # Generación de PDFs
  │   │   ├── photos/         # Compresión y gestión de fotos
  │   │   └── backup/         # Motor de backups
  │   └── Cargo.toml
  ├── assets/                 # Fuentes, íconos, plantillas
  ├── windows/                # Configuración Windows nativa
  └── pubspec.yaml
  ```
- [ ] Verificar que `flutter run -d linux` y la compilación Rust funcionan correctamente.
- [ ] "Hello World" funcional: un botón en Flutter que invoque una función Rust y muestre el resultado.

**Criterio de éxito:** La app compila en Linux, el puente FFI Flutter↔Rust funciona, y se puede invocar una función Rust desde Dart.

---

### Etapa 2 — Sistema de Temas Material 3 + Diseño Base UI
**Objetivo:** Implementar el sistema de diseño completo con Material 3 y detección dinámica de tema del SO.

**Entregables:**
- [ ] Configuración de `dynamic_color` / `dynamic_system_colors` para capturar el color de acento del SO.
- [ ] Implementación de `system_theme` para detectar modo claro/oscuro en tiempo real.
- [ ] `ThemeData` de Material 3 con fallback a `ColorScheme.fromSeed()`.
- [ ] Tipografía con Google Fonts (selección profesional para contexto clínico).
- [ ] Sistema de navegación principal (NavigationRail para desktop).
- [ ] Shell de la aplicación: AppBar, NavigationRail, área de contenido responsiva.
- [ ] Componentes base estilizados: botones, cards, inputs, dialogs, data tables.

**Criterio de éxito:** La app se adapta automáticamente al tema de Windows (claro/oscuro + color de acento), con una UI limpia, sobria y profesional.

---

### Etapa 3 — Base de Datos SQLite + Migraciones
**Objetivo:** Implementar la capa de persistencia completa en Rust con `rusqlite`.

**Entregables:**
- [ ] Conexión a SQLite con WAL mode habilitado.
- [ ] Sistema de migraciones versionadas (tabla `schema_version`).
- [ ] Creación del esquema completo (pacientes, tratamientos, sesiones, fotos, config).
- [ ] CRUD completo expuesto via `flutter_rust_bridge`:
  - Pacientes: crear, listar, buscar, editar, desactivar.
  - Tratamientos: crear, listar, editar.
  - Sesiones: crear, listar por paciente, editar.
- [ ] Paginación y búsqueda eficiente con índices.
- [ ] Tests unitarios en Rust para cada operación de DB.

**Criterio de éxito:** Las operaciones CRUD funcionan end-to-end (Flutter → Rust → SQLite → Rust → Flutter).

---

### Etapa 4 — Módulo de Gestión de Pacientes (UI + Lógica)
**Objetivo:** Primer módulo funcional completo de la aplicación.

**Entregables:**
- [ ] **Listado de pacientes**: búsqueda, filtros, paginación, ordenamiento.
- [ ] **Ficha de paciente**: formulario completo con validaciones.
- [ ] **Detalle de paciente**: vista con historial de sesiones, fotos y datos clínicos.
- [ ] **Crear/Editar paciente**: formulario con campos validados.
- [ ] **Desactivar paciente** (soft delete).
- [ ] State management con Riverpod (o BLoC, a definir).
- [ ] Feedback visual: loading states, mensajes de éxito/error, confirmaciones.

**Criterio de éxito:** Se puede gestionar el ciclo de vida completo de un paciente con una UX fluida.

---

### Etapa 5 — Módulo de Sesiones y Tratamientos
**Objetivo:** Gestión de sesiones clínicas vinculadas a pacientes y catálogo de tratamientos.

**Entregables:**
- [ ] **Catálogo de tratamientos**: CRUD con nombre, descripción, duración, precio.
- [ ] **Registro de sesión**: formulario vinculado a paciente y tratamiento, con notas, observaciones, productos usados y precio.
- [ ] **Historial de sesiones por paciente**: vista cronológica con filtros.
- [ ] **Calendario/agenda simple**: vista de sesiones programadas (opcional en esta etapa).
- [ ] **Indicador de pago**: marcar sesiones como pagadas/pendientes.

**Criterio de éxito:** Se puede registrar una sesión completa para un paciente, vinculada a un tratamiento del catálogo.

---

### Etapa 6 — Gestión de Fotos Comparativas
**Objetivo:** Captura, almacenamiento, compresión y visualización de fotos por sesión.

**Entregables:**
- [ ] **Selector de archivos** para importar fotos desde el sistema de archivos.
- [ ] **Compresión automática** en Rust: JPEG 85%, thumbnail 300px.
- [ ] **Almacenamiento organizado**: `data/fotos/{paciente_id}/{sesion_id}/`.
- [ ] **Galería de fotos por sesión**: grid con thumbnails, click para ampliar.
- [ ] **Comparador antes/después**: vista lado a lado (slider o split view).
- [ ] **Metadatos**: tipo de foto (antes/después/durante), descripción.
- [ ] Eliminación de fotos con confirmación.

**Criterio de éxito:** Se pueden adjuntar, visualizar y comparar fotos en las sesiones de un paciente.

---

### Etapa 7 — Importador de Excel (.xlsx)
**Objetivo:** Migrar los datos existentes desde archivos Excel heterogéneos al sistema centralizado.

**Entregables:**
- [ ] **Asistente de importación** (wizard multi-paso en la UI):
  1. Seleccionar archivo(s) `.xlsx`.
  2. Vista previa de las hojas detectadas y sus columnas.
  3. Mapeo manual/automático de columnas del Excel → campos de DataCare.
  4. Ejecución de la importación con barra de progreso.
  5. Reporte de resultados: filas importadas, advertencias, errores.
- [ ] **Motor de parseo en Rust** con `calamine`:
  - Detección automática de estructura por heurísticas.
  - Coerción flexible de tipos de datos.
  - Log detallado de errores por fila.
- [ ] **Registro de importaciones** en la tabla `importaciones`.
- [ ] **Importación idempotente**: detección de duplicados por nombre+fecha.

**Criterio de éxito:** Se pueden importar archivos Excel reales del flujo actual de la cosmetóloga, con un reporte claro de lo importado vs. lo omitido.

---

### Etapa 8 — Generación de PDFs Clínicos
**Objetivo:** Generar reportes PDF profesionales para imprimir o entregar al paciente.

**Entregables:**
- [ ] **Plantilla base** en Typst (`.typ`) para ficha de paciente.
- [ ] **Plantilla de resumen de sesiones** con tabla de historial.
- [ ] **Reporte con fotos embebidas**: antes/después por sesión.
- [ ] **Generación desde Rust** vía `typst` como librería.
- [ ] **Diálogo de exportación** en Flutter: seleccionar tipo de reporte, rango de fechas, y directorio de destino.
- [ ] **Previsualización** del PDF antes de guardar (si es factible).

**Criterio de éxito:** Se puede generar un PDF clínico profesional desde la ficha de un paciente con un click.

---

### Etapa 9 — Sistema de Backups Automáticos
**Objetivo:** Proteger los datos contra pérdida con backups automáticos en segundo plano.

**Entregables:**
- [ ] **Backup SQLite** usando el Backup API de `rusqlite`.
- [ ] **Backup completo** (.zip) con DB + directorio de fotos.
- [ ] **Ejecución en segundo plano** sin bloquear la UI (thread Rust separado).
- [ ] **Programación configurable**: intervalo de horas (default: cada 6h).
- [ ] **Retención rotativa**: conservar últimos N backups (default: 7).
- [ ] **Pantalla de configuración** en la UI: directorio de destino, frecuencia, retención.
- [ ] **Restauración manual**: seleccionar un backup y restaurar.
- [ ] **Notificación en la UI** cuando se completa un backup.

**Criterio de éxito:** Los backups se ejecutan automáticamente, se pueden restaurar, y el usuario tiene control sobre la configuración.

---

### Etapa 10 — CI/CD y Distribución Windows
**Objetivo:** Automatizar la compilación y empaquetado del `.exe` instalador para Windows.

**Entregables:**
- [ ] **Workflow de GitHub Actions** (`.github/workflows/build-windows.yml`):
  - Runner: `windows-latest`.
  - Steps: checkout → Flutter → Rust → LLVM → build → Inno Setup → upload.
- [ ] **Script Inno Setup** (`.iss`) para generar instalador profesional.
- [ ] **Caché de dependencias** (Flutter, Cargo, pub) para builds rápidos.
- [ ] **Release automation**: tag semántico → build → upload a GitHub Releases.
- [ ] **Ícono y branding** del instalador y ejecutable.
- [ ] **README** con instrucciones de desarrollo local y proceso de release.

**Criterio de éxito:** Al hacer push de un tag `v*`, se genera automáticamente un `.exe` instalador en GitHub Releases.

---

### Etapa 11 — Pulido, Testing y Hardening
**Objetivo:** Refinamiento final, manejo de errores robusto, y testing completo.

**Entregables:**
- [ ] **Error handling global** en Flutter (ErrorWidget, zone errors).
- [ ] **Logging estructurado** tanto en Dart como en Rust.
- [ ] **Tests unitarios** en Rust: DB, parser, PDF, backup.
- [ ] **Tests de widget** en Flutter para flujos críticos.
- [ ] **Accesibilidad** (a11y): navegación por teclado, tamaños de fuente escalables.
- [ ] **Performance**: profiling de queries SQLite, lazy loading de fotos.
- [ ] **Documentación técnica**: arquitectura, setup de desarrollo, guía de contribución.
- [ ] **Splash screen y onboarding** de primer uso.

**Criterio de éxito:** La aplicación es robusta, no crashea ante datos inesperados, y la experiencia de usuario es pulida.

---

## 5. Dependencias Críticas por Ecosistema

### Flutter (pubspec.yaml)
| Paquete | Propósito |
|---|---|
| `flutter_rust_bridge` | Puente FFI Flutter↔Rust |
| `dynamic_color` / `dynamic_system_colors` | Color de acento del SO |
| `system_theme` | Detección modo claro/oscuro |
| `google_fonts` | Tipografía profesional |
| `flutter_riverpod` | State management |
| `go_router` | Navegación declarativa |
| `file_picker` | Selección de archivos (Excel, fotos) |
| `photo_view` | Visor de imágenes con zoom |

### Rust (Cargo.toml)
| Crate | Propósito |
|---|---|
| `flutter_rust_bridge` | Bindings FFI |
| `rusqlite` (+ `bundled`) | SQLite embebido |
| `calamine` | Lectura de archivos Excel |
| `typst` / `typst-library` | Generación de PDFs |
| `image` | Compresión/redimensionado de fotos |
| `zip` | Compresión de backups |
| `serde` + `serde_json` | Serialización |
| `chrono` | Manejo de fechas |
| `log` + `env_logger` | Logging |
| `thiserror` / `anyhow` | Manejo de errores |

---

## 6. Riesgos y Mitigaciones

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Excel con formatos muy heterogéneos | Importación parcial o fallida | Wizard de mapeo manual + log de errores detallado |
| `dynamic_color` archivado/sin mantenimiento | Tema no se sincroniza con Windows | Fallback a `ColorScheme.fromSeed` + fork `dynamic_system_colors` |
| Build time largo en CI/CD (Windows runner) | Consumo rápido de minutos gratuitos | Caché agresivo de Flutter/Rust/pub + builds solo en tags |
| `typst` como librería aún experimental | Generación de PDF puede fallar | `printpdf` como fallback documentado |
| Fotos ocupan mucho espacio en disco | Backups muy pesados | Compresión JPEG 85% + exclusión opcional de fotos en backups |

---

## 7. Preguntas Abiertas para el Cliente

> [!IMPORTANT]
> Necesito tu feedback sobre los siguientes puntos antes de comenzar la ejecución:

1. **State Management**: ¿Preferencia por **Riverpod** o **BLoC**? (Recomiendo Riverpod por su simplicidad y flexibilidad).

2. **Prioridad de etapas**: ¿El orden propuesto es correcto? ¿Algún módulo debería adelantarse? (Ej: ¿Importador de Excel debería ir antes que Gestión de Fotos?).

3. **Estructura de los Excel actuales**: ¿Puedes compartir un ejemplo (anonimizado) de un archivo Excel real? Esto definirá las heurísticas del parser.

4. **Calendario/Agenda**: ¿Es un requisito para v1 o puede dejarse para una futura iteración?

5. **Reportes financieros**: ¿Se necesita un resumen de ingresos por periodo (diario/semanal/mensual) en v1?

6. **Branding**: ¿Tienes logo, nombre comercial del consultorio, o colores de marca que debería integrar como fallback del tema?

7. **Directorio de datos**: ¿Preferencia sobre dónde almacenar la DB y fotos? (Recomiendo `%APPDATA%/DataCare/` en Windows).

---

> **⏸️ PAUSA — Esperando tu confirmación y retroalimentación antes de proceder con la Etapa 1.**
