# DataCare

DataCare is a clinical management desktop application tailored for cosmetologists. It helps track patients, appointments, treatments, and inventory effectively.

## Tech Stack
- **Frontend**: Flutter Desktop (Material 3)
- **Backend/Core**: Rust (via flutter_rust_bridge v2)
- **Database**: SQLite (managed strictly on the Rust side via rusqlite)

## Development Requirements
To build and develop this project locally, you need:
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel, version 3.44.8 or compatible)
- [Rust Toolchain](https://rustup.rs/) (version 1.96.0 or compatible)
- For Windows: Visual Studio build tools with Desktop Development with C++
- LLVM/Clang (required by flutter_rust_bridge to generate bindings)

## Local Setup

1. Clone the repository:
   ```bash
   git clone <repo-url>
   cd DataCare
   ```

2. Fetch Flutter dependencies:
   ```bash
   flutter pub get
   ```

3. Generate flutter_rust_bridge bindings (if applicable):
   ```bash
   flutter_rust_bridge_codegen generate
   ```

4. Run the app:
   ```bash
   flutter run -d windows
   ```

## Compiling for Production

To build a release version manually:

```bash
flutter build windows --release
```
The compiled output will be available in `build/windows/x64/runner/Release/`.

## Releasing a New Version

The project includes an automated CI/CD pipeline using GitHub Actions.

To create a new release:
1. Create and push a new semantic version tag (e.g., `v1.0.0`):
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
2. GitHub Actions will automatically trigger the **Release Windows Desktop** workflow.
3. The workflow will build the Flutter app, package it using Inno Setup, create a portable ZIP file, generate SHA256 checksums, and publish a GitHub Release with the artifacts.

## Project Structure
- `lib/` - Flutter UI, routing (go_router), and state management (Riverpod).
- `rust/` - Rust core logic, including SQLite database management and business logic.
- `assets/` - Fonts, icons, and templates.
- `windows/` - Windows-specific Runner code and `installer.iss` script for Inno Setup.
- `.github/workflows/` - CI/CD pipelines.

## License
MIT License
