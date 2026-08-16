# DataCare - Documentación Técnica y Arquitectura (AI Handover)

Este documento está diseñado para proveer el contexto arquitectónico, técnico y estructural de **DataCare** a cualquier asistente de Inteligencia Artificial o desarrollador que necesite solucionar bugs, mantener o expandir la aplicación en el futuro.

## 1. Descripción General
**DataCare** es una aplicación de escritorio (actualmente compilada para Linux) diseñada para la gestión clínica. Permite registrar pacientes, gestionar sus tratamientos, llevar un historial de sesiones (con control de pagos y galería fotográfica comparativa de "Antes/Después"), visualizar métricas en un dashboard y generar reportes en PDF.

## 2. Stack Tecnológico
- **Frontend / UI**: [Flutter](https://flutter.dev/) (Dart). Usa Material Design 3.
- **Backend Core**: [Rust](https://www.rust-lang.org/). Maneja el procesamiento pesado, acceso a archivos y base de datos.
- **FFI / Bridge**: [`flutter_rust_bridge` (v2)](https://fzyzcjy.github.io/flutter_rust_bridge/). Conecta de manera asíncrona y segura el código Dart con las funciones en Rust.
- **Base de Datos**: SQLite (usando la librería `rusqlite` en Rust). La base de datos se guarda localmente en el equipo del usuario (generalmente en `~/.local/share/datacare/datacare.db` en Linux).
- **Gestión de Estado**: [`flutter_riverpod`](https://riverpod.dev/).
- **Enrutamiento**: [`go_router`](https://pub.dev/packages/go_router).

## 3. Estructura de Directorios

El proyecto es un monorepo que contiene tanto el proyecto de Flutter como el de Rust.

```text
DataCare/
├── lib/                             # Código fuente de Flutter (Frontend)
│   ├── main.dart                    # Punto de entrada. Inicializa DB y configuraciones.
│   └── src/
│       ├── core/                    # Utilidades globales (tema, enrutador go_router)
│       ├── features/                # Arquitectura basada en características (Feature-first)
│       │   ├── dashboard/           # Pantalla principal y métricas.
│       │   ├── patients/            # CRUD y perfil detallado de pacientes.
│       │   ├── photos/              # Lógica de la galería fotográfica y visualizador.
│       │   ├── reports/             # Generador de reportes PDF.
│       │   ├── sessions/            # Historial de citas, CRUD de sesiones y Calendario.
│       │   ├── settings/            # Configuración, cambio de tema (Claro/Oscuro).
│       │   └── treatments/          # Catálogo de tratamientos disponibles.
│       └── rust/                    # CÓDIGO GENERADO AUTOMÁTICAMENTE por flutter_rust_bridge. NO EDITAR DIRECTAMENTE.
├── rust/                            # Código fuente de Rust (Backend)
│   ├── Cargo.toml                   # Dependencias de Rust (rusqlite, image, printpdf, etc.)
│   └── src/
│       ├── api/                     # Archivos expuestos a Flutter. FRB lee esto para generar bindings.
│       │   ├── db_api.rs            # Endpoints de la base de datos (Pacientes, Sesiones, etc.)
│       │   ├── pdf_api.rs           # Generación de reportes PDF.
│       │   └── photos_api.rs        # Funciones para manipulación de fotos (guardar, redimensionar).
│       ├── db/                      # Lógica interna de SQLite
│       │   ├── migrations.rs        # Esquema de la base de datos y migraciones (V1).
│       │   ├── models.rs            # Structs de Rust (y derivados a Dart mediante serde/FRB).
│       │   └── repository.rs        # Consultas SQL (SELECT, INSERT, UPDATE).
│       ├── photos/                  # Lógica interna de procesamiento de imágenes.
│       ├── frb_generated.rs         # CÓDIGO GENERADO AUTOMÁTICAMENTE.
│       └── lib.rs                   # Declaración de módulos.
├── pubspec.yaml                     # Dependencias de Flutter.
└── build.rs                         # Script de construcción de Rust.
```

## 4. Patrones de Diseño y Flujo de Datos

### Flujo de Datos (Dart <-> Rust)
1. **UI (Flutter)**: Un widget (ej. `PatientDetailScreen`) necesita datos.
2. **State Management (Riverpod)**: Un `Provider` (ej. `patientDetailProvider`) hace una llamada asíncrona a la API.
3. **API (Dart generado)**: Llama a la función de Rust a través de `flutter_rust_bridge`.
4. **Backend (Rust)**: La función en `rust/src/api/*.rs` ejecuta la lógica, por ejemplo, consultando la base de datos mediante `repository.rs`.
5. **Retorno**: Rust devuelve un `Result<T, AppError>`. El Bridge lo convierte en un `Future<T>` en Dart (o lanza una Exception si es `Err`).
6. **UI Actualizada**: Riverpod actualiza su estado (`AsyncData`, `AsyncError`, o `AsyncLoading`) y la UI se reconstruye.

### Estructura de la Base de Datos (SQLite)
El esquema se define en `rust/src/db/migrations.rs`. Tablas principales:
- `pacientes`: Datos personales, contacto e historial médico.
- `tratamientos`: Catálogo base de tratamientos ofrecidos.
- `sesiones`: Relaciona un paciente con un tratamiento (opcional), incluyendo notas, precio y estado de pago.
- `fotos_sesion`: Relaciona fotos con una sesión específica (tipos: 'antes', 'despues', 'durante', 'otra').

### Procesamiento de Imágenes
Las fotos se manejan en `rust/src/photos/mod.rs`. Cuando un usuario elige una foto:
1. Se copia la imagen original a un directorio estructurado local (`~/.local/share/datacare/photos/<paciente_id>/<sesion_id>/`).
2. Se genera un **Thumbnail** (miniatura de 300x300) usando el crate `image` de Rust para que la carga en la grilla de Flutter sea súper rápida y no consuma toda la memoria RAM.
3. Las rutas absolutas se guardan en la DB.

## 5. Instrucciones Críticas para la IA

### A. Modificar la API de Rust
Si agregas, cambias o eliminas una función en `rust/src/api/*.rs` o un `struct` en `rust/src/db/models.rs`, **DEBES REGENERAR LOS BINDINGS** antes de ejecutar la aplicación, o de lo contrario ocurrirá un `PanicException (assertion left == right failed)` por desincronización de memoria (codec SSE).

Para generar el código usa:
```bash
flutter_rust_bridge_codegen generate
```
*(Si no tienes el binario global en tu PATH, busca en `~/.cargo/bin/flutter_rust_bridge_codegen generate`)*.

### B. Dependencias de Linux
El empaquetado y visualización de la app requiere dependencias base de GTK. Si la app arroja errores gráficos al iniciar en Linux, verifica Wayland/X11 o instala las librerías de desarrollo de GTK3.

### C. Estado en Riverpod
Se usa un enfoque robusto:
- `FutureProvider` o `StateNotifierProvider` inyectan dependencias.
- Las mutaciones (crear/editar) se hacen a través de un `sessionsActionProvider` o métodos dentro del `Notifier` que, al terminar con éxito (`await`), llaman a un método `ref.invalidate(...)` o actualizan el estado interno y obligan a la interfaz a redibujarse.

## 6. Funcionalidades Recientes Implementadas
Para tu contexto inmediato:
- **Calendario (`table_calendar`)**: Se agrupan todas las sesiones de los pacientes por día.
- **Galería Unificada**: El perfil del paciente tiene un query con `INNER JOIN` para mostrar las fotos de **todas** sus sesiones juntas.
- **Modo Oscuro/Claro**: Gestionado por `theme_provider.dart` y `shared_preferences`.

---
*Documento generado para contexto persistente. Usa este archivo como punto de partida arquitectónico para cualquier nueva feature.*
