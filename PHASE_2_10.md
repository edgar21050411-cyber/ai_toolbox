# PHASE 2.10 — PRIMER BUILD REAL EN LA NUBE Y VALIDACIÓN DEL APK

**Proyecto**: AI Toolbox  
**Fase**: 2.10  
**Objetivo**: Implementar el pipeline de compilación de Flutter y Android en la nube mediante GitHub Actions para generar el APK debug sin sobrecargar el PC local (4 GB RAM).

---

## 1. OBJETIVO Y ESTRATEGIA CLOUD

Debido a que el PC local cuenta con recursos de hardware limitados (~4 GB de RAM), la compilación pesada de Android (Gradle, Java JDK 17, Android SDK y Flutter Tools) se desacopla completamente del host físico y se delega a la infraestructura cloud de **GitHub Actions** (`ubuntu-latest` con 7 GB de RAM).

El flujo de trabajo es:
```text
PC Local (4 GB RAM)
       │
       ▼ git commit
  Git Local (main)
       │
       ▼ git push
  GitHub Repository
       │
       ▼ Trigger automático
 GitHub Actions Runner (Ubuntu / 7 GB RAM)
       │
       ├─► Setup Java JDK 17 (Temurin)
       ├─► Setup Flutter SDK (Stable con caché)
       ├─► Scaffolding de Android platform (`flutter create . --platforms=android`)
       ├─► flutter pub get
       ├─► flutter analyze
       ├─► flutter test
       ├─► flutter build apk --debug
       │
       ▼
 Artifact publicado: ai-toolbox-debug-apk (app-debug.apk)
```

---

## 2. CONFIGURACIÓN DEL WORKFLOW CI/CD

El archivo [.github/workflows/flutter_ci.yml](.github/workflows/flutter_ci.yml) define las siguientes etapas reproducibles:

```yaml
name: Flutter Cloud CI & APK Build

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]
  workflow_dispatch:

jobs:
  build-and-test:
    name: Flutter Analyze, Test & Build APK
    runs-on: ubuntu-latest
    timeout-minutes: 30

    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4

      - name: Setup Java JDK
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'

      - name: Setup Flutter SDK
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true
          cache-key: "flutter-:os:-:channel:-:version:-:arch:-:hash:"

      - name: Verify Flutter & Environment
        run: |
          flutter --version
          dart --version
          java -version

      - name: Scaffold Android Platform if Missing
        working-directory: mobile
        run: |
          if [ ! -d "android" ]; then
            echo "Scaffolding Android platform files..."
            flutter create . --platforms=android --org=com.aitoolbox
          fi

      - name: Install Dependencies
        working-directory: mobile
        run: flutter pub get

      - name: Analyze Flutter Code
        working-directory: mobile
        run: flutter analyze

      - name: Run Flutter Tests
        working-directory: mobile
        run: flutter test

      - name: Build Debug APK
        working-directory: mobile
        run: flutter build apk --debug

      - name: Upload Debug APK Artifact
        uses: actions/upload-artifact@v4
        with:
          name: ai-toolbox-debug-apk
          path: mobile/build/app/outputs/flutter-apk/app-debug.apk
          if-no-files-found: error
```

---

## 3. SEGURIDAD Y PREVENCIÓN DE FILTRACIONES

1. **`.gitignore` Exhaustivo**:
   - Bloquea `.env`, `.env.*`, `*.key`, `*.pem`, `*.p12`, `*.jks`, `google-services.json`, `GoogleService-Info.plist`, `key.properties` y `local.properties`.
   - Excluye `.dart_tool/`, `build/`, `.gradle/` y temporales de compilación.
2. **Escaneo de Secretos**:
   - Se auditó todo el repositorio con escáner regex.
   - Cero API keys o tokens privados expuestos en `mobile/lib/`, `mobile/assets/`, `supabase/` o `.github/`.
   - Cadenas simuladas en tests fueron saneadas para evitar falsos positivos con GitHub Secret Scanning.

---

## 4. INSTRUCCIONES PARA ACTIVAR EL BUILD (GITHUB_REMOTE_REQUIRED)

Para disparar el workflow y obtener el APK generado en la nube:

1. **Crear el repositorio en GitHub**:
   - Ingresar a [GitHub](https://github.com/new) y crear un nuevo repositorio vacío (público o privado), por ejemplo `ai_toolbox`.
2. **Conectar el repositorio local**:
   Ejecutar en la raíz del proyecto (`c:\Users\si\.gemini\antigravity\scratch\ai_toolbox`):
   ```bash
   git remote add origin https://github.com/<TU_USUARIO>/ai_toolbox.git
   git push -u origin main
   ```
3. **Monitorear la compilación**:
   - Ir a la pestaña **Actions** en el repositorio de GitHub.
   - Seleccionar la ejecución en curso `Flutter Analyze, Test & Build APK`.
   - Al finalizar, descargar el artefacto `ai-toolbox-debug-apk` que contiene `app-debug.apk`.
