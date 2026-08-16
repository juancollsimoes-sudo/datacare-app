# DataCare - Guía de Arquitectura para IA (AI_GUIDE.md)

Este documento contiene un resumen completo de la arquitectura del proyecto `DataCare` para ahorrar tokens y dar contexto rápido a cualquier asistente de IA que trabaje en el proyecto en el futuro.

## 1. Arquitectura General
DataCare es una aplicación médica de historias clínicas desarrollada en **Flutter** y **Rust**.
- **Frontend**: Flutter (para Windows como Desktop App y Web App PWA).
- **Backend / Lógica Local**: Rust (conectado mediante `flutter_rust_bridge` y `cargokit`).
- **Base de Datos**: SQLite (gestionada desde Rust con la librería `rusqlite`).
- **Servidor Web Local**: Un servidor en Rust (`axum`) se levanta en segundo plano en el puerto `8080` cuando la app se ejecuta en Windows. Este servidor hospeda la versión Web (PWA) para que pueda usarse en celulares en la misma red Wi-Fi, y sirve los recursos y la API REST.

## 2. Directorios y Almacenamiento
La información de la app en la computadora del usuario (Windows/Linux) se guarda en la carpeta local del sistema (`~/.local/share/datacare/` en el caso de Linux/macOS, o su equivalente en Windows).
- **Base de datos**: `~/.local/share/datacare/datacare.db`
- **Fotos e Imágenes**: `~/.local/share/datacare/photos/`

## 3. Comportamiento Multi-Plataforma (Desktop vs Web)
El frontend interactúa con Rust de dos maneras distintas dependiendo de la plataforma:
1. **Desktop (Windows/Linux)**:
   - La base de datos es accedida directamente invocando funciones Rust de `db_api.rs` o `photos_api.rs` usando el puente `flutter_rust_bridge`.
   - Las imágenes de los pacientes cargan desde disco usando `Image.file(File(...))`.
2. **Web (PWA en el celular)**:
   - El código en Web **no puede** usar `flutter_rust_bridge` directamente porque WebAssembly no puede tocar el sistema de archivos (SQLite).
   - La app Web detecta su entorno mediante la constante `kIsWeb`. Si es web, todas las peticiones a la base de datos se hacen a través de la red HTTP utilizando `WebApiClient` (`lib/src/core/api/web_api_client.dart`).
   - Las imágenes cargan mediante red usando `Image.network(Uri.base.resolve('/photos/xxx.jpg'))` ya que el servidor `axum` sirve la carpeta de fotos públicamente.
   - **IMPORTANTE:** El backend de Rust envía el JSON en `snake_case` (ej: `paciente_id`, `fecha_registro`). El parser JSON de Dart en WebApiClient SIEMPRE debe mapear desde `snake_case`.

## 4. Tecnologías y Paquetes de Interfaz
- **Riverpod**: Manejo de estado (`flutter_riverpod`).
- **GoRouter**: Sistema de navegación (`go_router`). Usa un `ShellRoute` responsivo (con `LayoutBuilder`) para cambiar entre Menú Lateral en Desktop y Drawer de Hamburguesa en Móviles.
- **System Theme**: Extrae el color de acento nativo del sistema operativo del usuario.

## 5. Proceso de Auto-Actualización (Windows)
La aplicación de escritorio incluye un sistema de auto-actualización invisible sin necesidad de instaladores clásicos.
- Al abrir la app en Windows, `AutoUpdaterService` hace ping a la API de `GitHub Releases`.
- Si existe una versión mayor a la versión local (ej: `v1.0.2` > `v1.0.1`), lanza un Diálogo.
- Si el usuario acepta, descarga el archivo `datacare-windows.zip` a la carpeta temporal, usa `PowerShell` para descomprimir el zip y crea un script temporal (`update.bat`).
- La aplicación se cierra. El archivo `.bat` reemplaza el archivo ejecutable, los `dll` y la carpeta `data/` con la nueva versión, e inicia nuevamente el programa.

---

## 🛑 INSTRUCCIONES PARA LA IA: CÓMO CREAR UNA ACTUALIZACIÓN (RELEASE) 🛑

Si el usuario te solicita realizar un cambio y **publicar una actualización** para que sus dispositivos la descarguen mediante el Auto-Updater, debes seguir EXÁCTAMENTE estos pasos:

1. **Modifica el código fuente** según la funcionalidad solicitada.
2. Abre `lib/src/core/constants/app_constants.dart` y **aumenta la versión** de la variable estática `appVersion` (por ejemplo, cambia `'v1.0.1'` a `'v1.0.2'`).
3. (Solo si modificaste código Rust) Ejecuta `flutter rust_bridge_codegen generate` para actualizar los vínculos (bindings) si es necesario.
4. Prepara el commit con todos los archivos modificados: `git add .`
5. Haz el commit: `git commit -m "Descripción clara del cambio"`
6. Sube el commit a main: `git push origin main`
7. **Crea la etiqueta de versión (Tag):**
   ```bash
   git tag v1.0.2  # REEMPLAZAR POR LA VERSIÓN CORRESPONDIENTE
   ```
8. **Sube la etiqueta a GitHub:**
   ```bash
   git push origin v1.0.2
   ```

¡Ya está! Al subir el `tag` que empieza con `v`, el archivo oculto `.github/workflows/release.yml` automáticamente creará una máquina Windows en la nube, descargará Flutter/Rust, compilará la versión Release de Windows, creará el paquete `datacare-windows.zip` y lo publicará. Cuando termine, el software instalado en las máquinas de los clientes detectará el nuevo parche y se actualizará a sí mismo. No necesitas compilar localmente ni adjuntar instaladores.
