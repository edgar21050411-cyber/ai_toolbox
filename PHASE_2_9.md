# PHASE 2.9 — MIGRACIÓN DEL ENTORNO DE DESARROLLO Y COMPILACIÓN A LA NUBE

**Proyecto**: AI Toolbox  
**Fase**: 2.9  
**Objetivo**: Desacoplar la compilación y desarrollo pesado de Flutter/Android del PC local (4 GB RAM) hacia un entorno remoto/cloud gratuito y reproducible.

---

## 1. OBJETIVO Y JUSTIFICACIÓN TÉCNICA

El PC local cuenta con aproximadamente 4 GB de memoria RAM. La toolchain de desarrollo móvil de Android y Flutter requiere simultáneamente:
* OpenJDK 17 (~500 MB - 1 GB RAM en picos de compilación).
* Gradle Daemon (~1 GB - 2 GB RAM).
* Android SDK build-tools y aapt2 (~500 MB - 1 GB RAM).
* Flutter Tool / Dart Analyzer (~500 MB RAM).

Intentar compilar localmente en Windows con 4 GB de RAM provocaría bloqueos de sistema operativo, swap/paging excesivo y congelamiento de la máquina.

Por tanto, la estrategia adoptada es **Cloud-First**:
* **PC Local**: Entorno ligero (navegador web, editor de código ligero, Git y control del proyecto).
* **Entorno Cloud**: Ejecución de `flutter pub get`, `flutter analyze`, `flutter test` y generación del APK debug (`flutter build apk --debug`).

---

## 2. ARQUITECTURA OBJETIVO

```text
                    USUARIO
                       │
                       ▼
                PC de 4 GB RAM
             (Editor ligero + Git)
                       │
                       ▼ git push
              ☁️ ENTORNO CLOUD
     ┌────────────────────────────────────┐
     │ Opción A: GitHub Codespaces / IDX  │  (Edición interactiva en navegador)
     │ Opción B: GitHub Actions (CI/CD)   │  (Compilación desatendida y test)
     ├────────────────────────────────────┤
     │ Linux Ubuntu (7-8 GB RAM)          │
     │ Flutter SDK 3.24.x Stable          │
     │ Dart SDK 3.5.x                     │
     │ Java JDK 17 (Eclipse Temurin)      │
     │ Android SDK & Command-line Tools   │
     │ Node.js & Supabase CLI             │
     ├────────────────────────────────────┤
     │ 1. flutter create . (Android)      │
     │ 2. flutter pub get                 │
     │ 3. flutter analyze                 │
     │ 4. flutter test                    │
     │ 5. flutter build apk --debug       │
     └─────────────────┬──────────────────┘
                       │
                       ▼
             Artefacto: app-debug.apk
                       │
                       ▼
                  AI TOOLBOX
                       │
            ┌──────────┴──────────┐
            ▼                     ▼
        Supabase             Providers IA
     (Edge Functions)     (Gemini/Replicate)
```

---

## 3. ESTRATEGIA ELEGIDA

### Estrategia Primaria: CI/CD en GitHub Actions
* **Costo**: 0 USD (2,000 minutos mensuales gratuitos en repositorios públicos/privados de GitHub).
* **Especificaciones del Runner**: Máquina virtual Ubuntu 22.04 / 24.04 con 2 vCPUs y 7 GB de RAM.
* **Archivos Preparados**:
  - `.github/workflows/flutter_ci.yml`: Pipeline declarativo con checkout, Setup Java 17, Setup Flutter, scaffolding de Android, `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build apk --debug` y subida del APK como artefacto de descarga.
* **Ventaja**: El PC local no ejecuta ningún comando pesado. Solo realiza `git push` y descarga el APK compilado directamente desde la web de GitHub.

### Estrategia Secundaria: Cloud IDE vía GitHub Codespaces / VS Code Dev Containers
* **Costo**: 0 USD (60 horas mensuales gratuitas en GitHub).
* **Archivos Preparados**:
  - `.devcontainer/devcontainer.json`: Contenedor basado en `ghcr.io/cirruslabs/flutter:stable` con Flutter, Dart, Java y Android SDK preinstalados.
* **Ventaja**: Permite programar con soporte completo de Flutter Analyzer y emulador web directamente en el navegador sin consumir recursos del PC local.

---

## 4. SEGURIDAD Y PROTECCIÓN DE SECRETOS

1. **`.gitignore` Estricto**:
   - Se ha configurado el archivo raíz `.gitignore` protegiendo:
     - `.env`, `.env.*` (excepto `.env.example`).
     - Archivos de certificados y llaves: `*.key`, `*.pem`, `key.properties`, `local.properties`.
     - Archivos de servicios de nube: `google-services.json`, `GoogleService-Info.plist`.
     - Artefactos y directorios de compilación: `.dart_tool/`, `build/`, `.gradle/`, `android/.gradle/`.
2. **Cero Secretos en el Código Cliente**:
   - `mobile/lib/` no contiene llaves ni tokens privados.
   - Las claves de proveedores de IA (`GEMINI_API_KEY`, `OPENAI_API_KEY`, etc.) residirán exclusivamente en los secretos de Supabase (`supabase secrets set`).

---

## 5. PASOS REQUERIDOS PARA EL USUARIO

Dado que la máquina local aún no tiene un repositorio Git remoto configurado (`GIT_REMOTE_REQUIRED`), el usuario debe seguir estos 3 pasos simples:

1. **Crear un Repositorio en GitHub**:
   - Entrar a GitHub y crear un nuevo repositorio (vacío, privado o público).
2. **Inicializar y Conectar Git Localmente**:
   ```bash
   git init
   git add .
   git commit -m "feat: phase 2.9 cloud development setup"
   git branch -M main
   git remote add origin <URL_DEL_REPOSITORIO_GITHUB>
   git push -u origin main
   ```
3. **Descargar el APK Compilado**:
   - Ir a la pestaña **Actions** en GitHub.
   - El workflow `Flutter Cloud CI & APK Build` se ejecutará automáticamente en la nube.
   - Al finalizar, descargar el archivo `ai-toolbox-debug-apk` desde la sección de **Artifacts**.
