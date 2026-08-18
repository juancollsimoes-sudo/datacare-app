# DataCare — Guía Completa de Arquitectura para IA (AI_GUIDE.md)

> **Propósito**: Este documento es la referencia maestra para cualquier asistente de IA que trabaje en DataCare. Léelo PRIMERO para ahorrar tokens y evitar leer archivos innecesarios.
> **Última actualización**: Agosto 2026.

---

## 1. ¿Qué es DataCare?

DataCare es una aplicación de gestión de historias clínicas para **Beauty Sweet Care Spa — Susana Simoes**, un spa de estética y tratamientos faciales/corporales. La app permite registrar pacientes, sesiones, tratamientos, fotografías comparativas (antes/después), generar reportes PDF y realizar backups.

**Stack tecnológico:**
| Capa | Tecnología |
|:---|:---|
| Frontend | Flutter (Desktop + Web PWA) |
| Backend local | Rust (via `flutter_rust_bridge` + `cargokit`) |
| Base de datos | SQLite (vía `rusqlite` en Rust) |
| Servidor web local | Axum (Rust), puerto `8080` |
| Estado | Riverpod (`flutter_riverpod`) |
| Navegación | GoRouter (`go_router`) con `ShellRoute` |
| Tipografía | Google Fonts (Playfair Display + Inter) |

---

## 2. Estructura de Carpetas Clave

```
DataCare/
├── lib/
│   ├── main.dart                        # Punto de entrada
│   ├── app.dart                         # MaterialApp.router + temas
│   └── src/
│       ├── core/
│       │   ├── api/
│       │   │   └── web_api_client.dart  # Cliente HTTP para versión Web (PWA)
│       │   ├── constants/
│       │   │   └── app_constants.dart   # Nombre, versión, colores de marca
│       │   ├── router/
│       │   │   └── app_router.dart      # Todas las rutas GoRouter
│       │   ├── services/
│       │   │   └── auto_updater_service.dart  # Auto-actualización Windows
│       │   └── theme/
│       │       ├── app_theme.dart        # ⭐ SISTEMA DE DISEÑO COMPLETO
│       │       └── theme_provider.dart   # Provider de ThemeMode
│       ├── features/
│       │   ├── home/                    # Dashboard
│       │   ├── patients/               # CRUD pacientes + detalle
│       │   ├── sessions/               # CRUD sesiones
│       │   ├── treatments/             # CRUD tratamientos
│       │   ├── photos/                 # Galería de fotos comparativas
│       │   ├── reports/                # Generación de reportes PDF
│       │   ├── backup/                 # Backup/restore de DB
│       │   ├── import/                 # Importación de datos
│       │   └── settings/              # Configuración (tema, etc.)
│       ├── shared/
│       │   └── widgets/
│       │       └── app_shell.dart      # ⭐ SHELL RESPONSIVO (NavRail + Drawer)
│       └── rust/                       # Código auto-generado por flutter_rust_bridge
├── rust/
│   └── src/
│       ├── api/
│       │   ├── db_api.rs               # API de base de datos
│       │   ├── photos_api.rs           # API de fotos
│       │   ├── pdf_api.rs              # API de PDFs
│       │   └── server_api.rs           # Wrapper para iniciar servidor
│       ├── db/
│       │   └── models.rs               # Modelos de datos (Paciente, Sesion, etc.)
│       └── server.rs                   # Servidor Axum (rutas REST)
├── .github/workflows/
│   └── release.yml                     # GitHub Actions: compilar .exe Windows
└── AI_GUIDE.md                         # ← ESTE ARCHIVO
```

---

## 3. Almacenamiento Local

| Dato | Ruta (Linux) | Ruta (Windows) |
|:---|:---|:---|
| Base de datos | `~/.local/share/datacare/datacare.db` | `%APPDATA%/datacare/datacare.db` |
| Fotos | `~/.local/share/datacare/photos/` | `%APPDATA%/datacare/photos/` |

---

## 4. Plataforma Dual: Desktop vs Web

| Aspecto | Desktop (Windows/Linux) | Web (PWA en celular) |
|:---|:---|:---|
| Acceso a datos | `flutter_rust_bridge` directo | HTTP vía `WebApiClient` |
| Detección | `!kIsWeb` | `kIsWeb` |
| Imágenes | `Image.file(File(...))` | `Image.network(Uri.base.resolve('/photos/...'))` |
| Fotos visor | `FileImage(File(...))` | `NetworkImage(url)` |
| JSON del backend | N/A (bindings directos) | **SIEMPRE `snake_case`** (`paciente_id`, `fecha_registro`) |

> **⚠️ REGLA CRÍTICA:** Si agregas un nuevo campo al modelo Rust, el `WebApiClient` debe parsearlo con la clave `snake_case` exacta del backend.

---

## 5. Navegación Responsiva (AppShell)

**Archivo:** `lib/src/shared/widgets/app_shell.dart`

El `ShellRoute` de GoRouter envuelve todas las pantallas en un `AppShell` que detecta el ancho de pantalla:

| Ancho | Navegación |
|:---|:---|
| `>= 800px` (Desktop) | `NavigationRail` lateral dentro de un `Container` con fondo navy (`0xFF1A1B3A`). Íconos rosa/blanco. Se expande/colapsa con botón hamburguesa. |
| `< 800px` (Móvil) | `Drawer` con header navy, título "Sweet Care Spa" en dorado champagne (`0xFFD4B896`), subtítulo "by Susana Simoes". |

**Destinos de navegación (8 secciones):**
Dashboard, Pacientes, Sesiones, Tratamientos, Importar, Reportes, Backups, Configuración.

---

## 6. ⭐ SISTEMA DE DISEÑO — Guía Completa

**Archivo principal:** `lib/src/core/theme/app_theme.dart`
**Constantes de marca:** `lib/src/core/constants/app_constants.dart`

### 6.1 Identidad Visual

La app refleja la marca **"Beauty Sweet Care Spa"** de Instagram. Estética: lujo accesible, femenino, profesional médico, limpio y sofisticado.

### 6.2 Paleta de Colores

Los `ColorScheme` están definidos **manualmente** (NO usan `ColorScheme.fromSeed`).

**MODO CLARO:**
```
Rol                    Hex        Uso
─────────────────────  ─────────  ──────────────────────────────────
surface                #FFF8F6    Fondo principal (crema rosado)
surfaceContainer       #FFF0ED    Fondo de cards, SearchBar
primary                #C77D9C    Botones, acentos (rosa mauve)
onPrimary              #FFFFFF    Texto sobre botones primarios
primaryContainer       #FCDEE8    Fondo de íconos del dashboard
secondary              #1A1B3A    Sidebar navy, títulos fuertes
onSecondary            #FFFFFF    Texto sobre navy
tertiary               #D4B896    Badges, precios (dorado champagne)
tertiaryContainer      #F5E6D0    Fondo de íconos dorados
error                  #BA1A1A    Errores
outline                #BEB0AD    Bordes principales
outlineVariant         #E0D4D1    Bordes suaves, divisores
onSurface              #1A1B3A    Texto principal (navy)
onSurfaceVariant       #6B5D5A    Texto secundario
```

**MODO OSCURO:**
```
Rol                    Hex        Uso
─────────────────────  ─────────  ──────────────────────────────────
surface                #1A1B3A    Fondo principal (navy profundo)
surfaceContainer       #252745    Fondo de cards (navy más claro)
primary                #E8A4C0    Botones, acentos (rosa claro)
onPrimary              #1A1B3A    Texto sobre botones
primaryContainer       #4A2D3C    Fondo de íconos
secondary              #F2E0DC    Texto secundario (blush)
tertiary               #D4B896    Badges, precios (dorado)
tertiaryContainer      #4A3D2E    Fondo de íconos dorados
error                  #FFB4AB    Errores
outline                #4A4C6E    Bordes principales
outlineVariant         #353757    Bordes suaves, divisores
onSurface              #F2E0DC    Texto principal (blush claro)
onSurfaceVariant       #C4B8B5    Texto secundario
```

### 6.3 Tipografía

| Nivel | Fuente | Uso |
|:---|:---|:---|
| `displayLarge/Medium/Small` | **Playfair Display** (serif) | Títulos hero, números grandes |
| `headlineLarge/Medium/Small` | **Playfair Display** (serif) | Encabezados de sección |
| `titleLarge` | **Playfair Display** (serif) | Títulos de cards |
| `titleMedium/Small` | **Inter** (sans-serif) | Subtítulos, etiquetas |
| `bodyLarge/Medium/Small` | **Inter** (sans-serif) | Texto de cuerpo, formularios |
| `labelLarge/Medium/Small` | **Inter** (sans-serif) | Botones, chips, badges |

La mezcla se realiza en `_buildTextTheme()` creando un `TextTheme` que combina estilos de ambas fuentes (de `GoogleFonts.playfairDisplayTextTheme` y `GoogleFonts.interTextTheme`).

### 6.4 Componentes Personalizados

| Componente | Forma | Detalles |
|:---|:---|:---|
| **Cards** | 20px radius | Elevation 0, surfaceTintColor transparent, clipBehavior antiAlias |
| **Botones (Elevated/Filled/Outlined)** | 24px radius (pill) | Min height 48px |
| **FAB** | 20px radius | Fondo = primary, texto = onPrimary |
| **SearchBar** | 28px radius (full pill) | Elevation 0, fondo surfaceContainer |
| **Inputs** | 12px radius | Filled, borde outlineVariant, focus = primary |
| **Dialogs** | 20px radius | — |
| **SnackBars** | 12px radius | Floating behavior |
| **Chips** | 20px radius | — |
| **Dividers** | — | Color outlineVariant, thickness 0.5 |
| **AppBar** | — | Sin elevación, fondo = surface |
| **Transiciones** | — | CupertinoPageTransitionsBuilder en todas las plataformas |

### 6.5 Colores Hardcodeados en AppShell

Estos colores NO provienen del tema porque el NavigationRail y Drawer necesitan contrastar independientemente del modo claro/oscuro:

```dart
// Sidebar / NavRail container
Container(color: Color(0xFF1A1B3A))           // Navy fijo

// NavRail icons
selectedIconTheme:   Color(0xFFC77D9C)        // Rosa mauve
unselectedIconTheme: Colors.white70

// NavRail indicator
indicatorColor:      Color(0xFF252745)        // Navy más claro

// Drawer header
decoration: BoxDecoration(color: Color(0xFF1A1B3A))  // Navy fijo
title:     TextStyle(color: Color(0xFFD4B896))        // Dorado champagne
subtitle:  TextStyle(color: Colors.white70)

// Drawer ListTile selected
selectedColor:     Color(0xFFC77D9C)
selectedTileColor: Color(0xFFC77D9C).withOpacity(0.08)
```

### 6.6 Cómo Cambiar el Diseño en el Futuro

**Para cambiar colores:**
1. Edita los `ColorScheme` en `app_theme.dart` (líneas ~13-95). Cada campo tiene un comentario descriptivo.
2. Actualiza los colores hardcodeados del `AppShell` en `app_shell.dart`.
3. Actualiza `brandColor` en `app_constants.dart`.

**Para cambiar tipografía:**
1. Edita `_buildTextTheme()` en `app_theme.dart` (líneas ~113-139).
2. Cambia `GoogleFonts.playfairDisplayTextTheme` por la nueva fuente serif.
3. Cambia `GoogleFonts.interTextTheme` por la nueva fuente sans-serif.
4. La fuente debe existir en `google_fonts` (dependencia ya incluida en `pubspec.yaml`).

**Para cambiar formas de componentes:**
1. Busca el `ComponentTheme` correspondiente dentro de `_buildTheme()` en `app_theme.dart`.
2. Modifica el `BorderRadius.circular(XX)` al valor deseado.

**Para agregar un nuevo componente al tema:**
1. Agrega el `ThemeData` correspondiente dentro de `_buildTheme()` usando las variables `colorScheme` y `textTheme` ya disponibles.

---

## 7. API REST del Servidor Axum

**Archivo:** `rust/src/server.rs`

| Método | Ruta | Función |
|:---|:---|:---|
| GET | `/api/stats` | Dashboard stats |
| GET/POST | `/api/pacientes` | Listar/crear pacientes |
| GET/PUT/DELETE | `/api/pacientes/{id}` | Obtener/editar/desactivar paciente |
| GET | `/api/pacientes/{id}/sesiones` | Sesiones de un paciente |
| GET | `/api/pacientes/{id}/fotos` | Fotos de un paciente |
| POST | `/api/sesiones` | Crear sesión |
| GET/PUT | `/api/sesiones/{id}` | Obtener/editar sesión |
| GET | `/api/sesiones/{id}/fotos` | Fotos de una sesión |
| GET/POST | `/api/tratamientos` | Listar/crear tratamientos |
| GET/PUT/DELETE | `/api/tratamientos/{id}` | Obtener/editar/eliminar tratamiento |
| POST | `/api/fotos` | Subir foto (multipart) |
| DELETE | `/api/fotos/{id}` | Eliminar foto |
| GET | `/photos/*` | Servir archivos de fotos estáticos |
| GET | `/*` (fallback) | Servir la app web (`build/web/`) |

---

## 8. Auto-Actualización (Windows)

**Archivo:** `lib/src/core/services/auto_updater_service.dart`
**Versión actual:** Definida en `AppConstants.appVersion` (`app_constants.dart`)

Flujo:
1. Al abrir la app → consulta `api.github.com/repos/.../releases/latest`
2. Compara `tag_name` del release con `AppConstants.appVersion`
3. Si hay versión mayor → muestra diálogo al usuario
4. Si acepta → descarga `datacare-windows.zip` → extrae con PowerShell → crea `update.bat` → cierra app → bat reemplaza archivos → reabre app

---

## 9. 🛑 INSTRUCCIONES: CÓMO PUBLICAR UNA ACTUALIZACIÓN 🛑

1. **Modifica el código fuente** según lo solicitado.
2. **Sube la versión** en `lib/src/core/constants/app_constants.dart` → `appVersion` (ej: `'v1.0.1'` → `'v1.0.2'`).
3. (Si modificaste Rust) Ejecuta: `flutter_rust_bridge_codegen generate`
4. **Compila la versión web** (para que el celular vea los cambios): `flutter build web`
5. Commit y push:
   ```bash
   git add .
   git commit -m "descripción del cambio"
   git push origin main
   ```
6. **Crea y sube el tag de versión:**
   ```bash
   git tag v1.0.2
   git push origin v1.0.2
   ```

Al subir el tag, GitHub Actions (`.github/workflows/release.yml`) compilará el `.exe` de Windows automáticamente y lo publicará como Release. El Auto-Updater lo detectará en los dispositivos de los clientes.

---

## 10. Notas Técnicas Importantes

- **`kIsWeb`**: Usada en TODO el código para bifurcar entre Desktop y Web. Si agregas una nueva feature que use archivos locales (File, Process, etc.), SIEMPRE guárdala detrás de `if (!kIsWeb)`.
- **`PlatformInt64`**: Los IDs en Rust son `i64`. En Flutter se representan como `PlatformInt64`. En Web, se parsean manualmente desde JSON usando `int.parse()` o `.toInt()`.
- **`Uri.base.origin`**: En la versión Web, el `WebApiClient` usa `Uri.base.origin` para construir la URL base de la API. Esto permite que el celular conecte al servidor correcto (la IP de la laptop, no `localhost`).
- **Fotos en Web**: El servidor Axum sirve la carpeta de fotos en `/photos/`. Las rutas almacenadas en la DB son absolutas (ej: `/home/user/.../photos/img.jpg`). Para construir la URL web se usa `.split('photos/').last` para extraer solo la ruta relativa.
