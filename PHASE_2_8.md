# PHASE 2.8 — PLAN Y ALCANCE DE VALIDACIÓN

**Proyecto**: AI Toolbox  
**Fecha**: 2026-10-05  
**Estado General**: BLOCKED (FLUTTER SDK & TOOLCHAIN) / PASS WITH WARNINGS (BACKEND & LOGIC)  

---

## 1. OBJETIVO DE LA FASE 2.8
Determinar la viabilidad de ejecución y compilación nativa en el host para las 10 herramientas del catálogo, auditar la disponibilidad de runtimes móviles y evaluar el estado de los proveedores reales y el backend sin alterar la arquitectura ni simular resultados.

---

## 2. ESTADO DE LOS COMPONENTES PRINCIPALES

### 2.1. Entorno de Ejecución Móvil
* **Flutter SDK**: `FLUTTER_BLOCKED: Flutter SDK no disponible en el entorno actual.`
* **Dart SDK**: `DART_BLOCKED: Dart SDK no disponible en PATH ni en directorios comunes.`
* **Android SDK / JDK**: `ANDROID_BLOCKED: Android SDK y Java JDK no instalados en el host.`
* **ADB**: `ADB_BLOCKED: platform-tools no disponible.`

### 2.2. Backend y Enrutador de IA (Supabase Edge Functions)
* **Arquitectura**: Desacoplada e implementada en TypeScript.
* **Seguridad y Cero Filtraciones**: Confirmado que ningún secreto de API reside en el cliente móvil.
* **Storage**: Configurado bucket `generated-files` (límite 15MB, PNG/JPEG/WebP) con RLS por usuario.
* **Créditos y Refunds**: Atomicidad protegida con `SELECT ... FOR UPDATE` y reembolsos automáticos ante cualquier excepción.

### 2.3. Proveedores de IA
* **GEMINI_API_KEY**: `MISSING`
* **OPENAI_API_KEY**: `MISSING`
* **REPLICATE_API_TOKEN**: `MISSING`
* **REMOVE_BG_API_KEY**: `MISSING`
* **Comportamiento**: En ausencia de claves, el backend arroja un error controlado descriptivo, rechaza la solicitud sin simulación y ejecuta `refund_credits` de forma atómica.

---

## 3. CHECKLIST DE EJECUCIÓN

- [x] Cancelación segura de procesos en segundo plano de instalación pesada.
- [x] Verificación de ausencia de Flutter, Dart y Android SDK en el sistema.
- [x] Auditoría estática de consistencia en 49 archivos Dart (0 errores de importación).
- [x] Verificación de seguridad de código y ausencia de claves privadas en Flutter.
- [x] Auditoría de erradicación de query params simulados (0 ocurrencias).
- [x] Ejecución de suite de pruebas binarias y de storage (24/24 PASS).
- [x] Ejecución de suite de validación end-to-end de lógica y créditos (17/17 PASS).
- [ ] Ejecución de `flutter analyze` nativo (BLOQUEADO).
- [ ] Ejecución de `flutter test` nativo (BLOQUEADO).
- [ ] Compilación de `flutter build apk --debug` (BLOQUEADO).
- [ ] Llamadas HTTP LIVE a proveedores de producción (BLOQUEADO por ausencia de API keys).
