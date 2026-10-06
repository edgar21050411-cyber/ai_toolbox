# AUDITORÍA FASE 2.6: PROCESAMIENTO REAL DE IMÁGENES + SUPABASE STORAGE

**Proyecto**: AI Toolbox  
**Fecha**: 2026-10-05  
**Fase**: 2.6 — Procesamiento Real de Imágenes, Almacenamiento Persistente y Validación  
**Auditor**: Antigravity Core AI Engine  

---

## 1. RESUMEN EJECUTIVO

La Fase 2.6 tuvo como objetivo principal eliminar por completo todas las simulaciones mediante query params (`?enhanced=...`, `?processed=...`, `?bg_removed=...`, `?new_bg=...`, `?composed=...`) y convertir las herramientas de edición de imágenes (`improve_image`, `remove_background`, `change_background`) en flujos de **procesamiento real sobre píxeles**, integrando además la persistencia binaria en **Supabase Storage** (`generated-files`) para todas las generaciones visuales.

### Logros Principales:
1. **Erradicación Absoluta de Simulaciones**: Se removió el 100% del código que manipulaba parámetros de URLs como sustituto de procesamiento. Ninguna herramienta devuelve URLs originales con parámetros inventados.
2. **Proveedores Reales Conectados**:
   - `generate_image`: Google Imagen 3 (`imagen-3.0-generate-002:predict`), decodificando Base64 a bytes reales.
   - `remove_background`: Replicate (`bria/remove-background`) y Remove.bg (`v1.0`), devolviendo PNG con canal alfa y transparencia real verificada.
   - `improve_image`: Replicate (`nightmareai/real-esrgan`), ejecutando super-resolución / upscale real 2x con mejora facial.
   - `change_background`: Replicate (`bria/generate-background`), ejecutando inpainting fotográfico preservando el sujeto en primer plano.
3. **Persistencia en Supabase Storage (`generated-files`)**:
   - Se creó la migración `20261005000003_phase2_6_storage_and_image_processing.sql`.
   - Se configuró el bucket `generated-files` con límite de 15MB y tipos MIME `['image/png', 'image/jpeg', 'image/webp']`.
   - Todas las imágenes generadas se suben con ruta `${user_id}/${tool_id}_${timestamp}_${uuid}.${ext}` y se generan URLs firmadas de 1 año de vigencia.
   - Se vinculó `storage_path` y `result_url` en la tabla `generations` con políticas RLS para lectura y borrado exclusivos del usuario.
4. **Protección Anti-SSRF y Validación de Entrada**:
   - Validación binaria mediante Magic Bytes para PNG, JPEG y WebP.
   - Detección y rechazo estricto de intentos de SSRF hacia `localhost`, `127.0.0.1`, rangos privados RFC 1918 y servicios de metadatos de Cloud (`169.254.169.254`).
   - Soporte seguro de Data URLs Base64 mediante decodificación, validación y carga controlada a `user-files/{user_id}/inputs/`.
5. **Transparencia Total de Entorno y Configuración**:
   - Si falta `REPLICATE_API_TOKEN` o `GEMINI_API_KEY`, el backend no inventa respuestas: arroja un error descriptivo, ejecuta el reembolso atómico de créditos (`refund_credits`) y registra el fallo en `generations`.

---

## 2. ESTADO DEL ENTORNO DE DESARROLLO

| Herramienta / Runtime | Detección / Versión | Estado Real | Observaciones |
| :--- | :--- | :--- | :--- |
| **Node.js** | v24.19.0 (`C:\Program Files\nodejs\node.exe`) | **Disponible** | Ejecuta la suite de pruebas con `--experimental-strip-types` |
| **Git** | v2.56.0.1 | **Disponible** | Control de versiones operativo |
| **Flutter SDK** | Búsqueda exhaustiva en host | **NO DISPONIBLE** | Sin inventar salidas falsas de `flutter test` |
| **Dart SDK** | Búsqueda en PATH | **NO DISPONIBLE** | Documentado de forma estricta según directrices |
| **Supabase CLI** | Búsqueda en PATH | **No en local** | Migraciones SQL y Edge Functions en TypeScript completas |

---

## 3. AUDITORÍA DETALLADA DE LAS 10 HERRAMIENTAS DE AI TOOLBOX

| # | Herramienta | Categoría | Costo | UI Flutter | Enrutador Backend | Proveedor Real / Engine | Estado Fase 2.5 | Estado Fase 2.6 |
| :-: | :--- | :---: | :-: | :--- | :--- | :--- | :-: | :-: |
| **1** | `rewrite_text` | Texto | 1 | TextField, Tono, Acción | `TextEngine.rewriteText` | Google Gemini 1.5 Flash (Fallback: GPT-4o-mini) | IA Real | **IA REAL** |
| **2** | `translate_text` | Texto | 1 | TextField, Idiomas, Acción | `TextEngine.translateText` | Google Gemini 1.5 Flash (Fallback: GPT-4o-mini) | IA Real | **IA REAL** |
| **3** | `summarize_text` | Texto | 1 | TextField, Longitud, Acción | `TextEngine.summarizeText` | Google Gemini 1.5 Flash (Fallback: GPT-4o-mini) | IA Real | **IA REAL** |
| **4** | `create_ad` | Marketing | 4 | Inputs estructurados | `TextEngine.createAd` | Google Gemini 1.5 Flash (Fallback: GPT-4o-mini) | IA Real | **IA REAL** |
| **5** | `social_post` | Marketing | 3 | Inputs estructurados | `TextEngine.createSocialPost` | Google Gemini 1.5 Flash (Fallback: GPT-4o-mini) | IA Real | **IA REAL** |
| **6** | `product_description` | Marketing | 3 | Inputs estructurados | `TextEngine.createProductDescription` | Google Gemini 1.5 Flash (Fallback: GPT-4o-mini) | IA Real | **IA REAL** |
| **7** | `generate_image` | Imágenes | 5 | Prompt + Estilo, Visor | `ImageEngine.generateImage` | Google Imagen 3 (`imagen-3.0-generate-002`) + Storage | IA Real (Sin Storage) | **IA REAL + STORAGE** |
| **8** | `improve_image` | Imágenes | 5 | URL/Base64, Visor | `ImageEngine.improveImage` | Replicate (`nightmareai/real-esrgan`) 2x + Storage | Simulado (Query param) | **IA REAL + STORAGE** |
| **9** | `remove_background` | Imágenes | 3 | URL/Base64, Visor Alpha | `ImageEngine.removeBackground` | Replicate (`bria/remove-background`) / Remove.bg + Storage | Simulado (Query param) | **IA REAL + STORAGE** |
| **10**| `change_background` | Imágenes | 5 | URL/Base64 + Prompt Fondo | `ImageEngine.changeBackground` | Replicate (`bria/generate-background`) + Storage | Simulado (Query param) | **IA REAL + STORAGE** |

---

## 4. DETALLE TÉCNICO DE IMPLEMENTACIÓN DE IMÁGENES

### 4.1. `generate_image` (Crear imagen con IA)
* **Endpoint**: `POST https://generativelanguage.googleapis.com/v1beta/models/imagen-3.0-generate-002:predict?key=${GEMINI_API_KEY}`
* **Entrada**: `{ instances: [{ prompt: string }], parameters: { sampleCount: 1, aspectRatio: "1:1" } }`
* **Salida**: `predictions[0].bytesBase64Encoded` decodificado a `Uint8Array`.
* **Almacenamiento**: Subida directa al bucket `generated-files` como `png`.
* **Resultado**: URL firmada de Supabase Storage persistida en `generations(result_url, storage_path)`.

### 4.2. `remove_background` (Quitar fondo)
* **Proveedor Principal**: Replicate — Modelo oficial `bria/remove-background`.
* **Endpoint**: `POST https://api.replicate.com/v1/models/bria/remove-background/predictions`
* **Encabezados**: `Authorization: Bearer ${REPLICATE_API_TOKEN}`, `Prefer: wait`.
* **Entrada**: `{ input: { image: string } }`
* **Salida**: Imagen PNG con canal alfa real (`hasAlphaChannel = true`, `colorType = 6`).
* **Proveedor Alternativo**: Remove.bg (`https://api.remove.bg/v1.0/removebg`).
* **Almacenamiento**: Subida a `generated-files/{userId}/remove_background_{ts}_{id}.png`.

### 4.3. `improve_image` (Mejorar imagen)
* **Proveedor**: Replicate — Modelo oficial `nightmareai/real-esrgan`.
* **Endpoint**: `POST https://api.replicate.com/v1/models/nightmareai/real-esrgan/predictions`
* **Entrada**: `{ input: { image: string, scale: 2, face_enhance: true } }`
* **Salida**: Imagen con super-resolución y reducción de artefactos.
* **Almacenamiento**: Subida a `generated-files/{userId}/improve_image_{ts}_{id}.png`.

### 4.4. `change_background` (Cambiar fondo)
* **Proveedor**: Replicate — Modelo oficial `bria/generate-background`.
* **Endpoint**: `POST https://api.replicate.com/v1/models/bria/generate-background/predictions`
* **Entrada**: `{ input: { image: string, prompt: string } }`
* **Pipeline Real**: Detección y recorte del sujeto en primer plano + Síntesis fotográfica de escenario guiada por el prompt + Composición armónica.
* **Almacenamiento**: Subida a `generated-files/{userId}/change_background_{ts}_{id}.png`.

---

## 5. VALIDACIÓN Y SUITE DE PRUEBAS AUTOMATIZADAS

Se ejecutó la suite de pruebas unitarias y de integración `supabase/tests/image_processing_test.mjs` mediante Node.js v24 (`--experimental-strip-types`):

```text
================================================================================
AI TOOLBOX — FASE 2.6: SUITE DE PRUEBAS DE PROCESAMIENTO REAL DE IMÁGENES Y STORAGE
================================================================================

1. Pruebas de Validación de Magic Bytes y Tamaño de Imagen:
  ✓ [PASS] Detecta correctamente formato PNG con canal alfa
  ✓ [PASS] Detecta correctamente formato JPEG
  ✓ [PASS] Detecta correctamente formato WebP
  ✓ [PASS] Rechaza archivos vacíos (0 bytes)
  ✓ [PASS] Rechaza archivos que exceden 15MB
  ✓ [PASS] Rechaza JPEG para herramienta remove_background si se requiere canal alfa
  ✓ [PASS] Rechaza formatos desconocidos o scripts maliciosos disfrazados

2. Pruebas de Seguridad y Anti-SSRF en Input de Imágenes:
  ✓ [PASS] Bloquea intento de SSRF a localhost
  ✓ [PASS] Bloquea intento de SSRF a 127.0.0.1
  ✓ [PASS] Bloquea intento de SSRF a IP privada 10.0.0.1
  ✓ [PASS] Bloquea intento de SSRF a metadata service de Cloud (169.254.169.254)
  ✓ [PASS] Acepta URL remota HTTPS legítima
  ✓ [PASS] Procesa Data URL Base64 válida

3. Pruebas de Persistencia en Supabase Storage (generated-files):
  ✓ [PASS] Genera ruta y URL de almacenamiento siguiendo convención {uid}/{tool}_{ts}_{id}.png

4. Pruebas de ImageEngine y Erradicación Total de Query Strings Simuladas:
  ✓ [PASS] Verificar ausencia de cualquier manipulación de query params (?enhanced=, ?processed=, etc.) en código fuente
  ✓ [PASS] ImageEngine.generateImage rechaza prompt vacío
  ✓ [PASS] ImageEngine.generateImage arroja error transparente si GEMINI_API_KEY no está configurada
  ✓ [PASS] ImageEngine.removeBackground arroja error transparente sin fingir procesamiento si falta REPLICATE_API_TOKEN
  ✓ [PASS] ImageEngine.improveImage arroja error transparente si falta REPLICATE_API_TOKEN
  ✓ [PASS] ImageEngine.changeBackground arroja error transparente si falta descripción de nuevo fondo

5. Pruebas de Flujo Completo de Inferencia y Persistencia en Storage:
  ✓ [PASS] Flujo completo: generate_image -> Google Imagen 3 -> bytes -> Supabase Storage
  ✓ [PASS] Flujo completo: remove_background -> Replicate (bria/remove-background) -> canal alfa -> Storage
  ✓ [PASS] Flujo completo: improve_image -> Replicate (nightmareai/real-esrgan) -> 2x upscale -> Storage
  ✓ [PASS] Flujo completo: change_background -> Replicate (bria/generate-background) -> Inpainting -> Storage

================================================================================
RESUMEN DE PRUEBAS: 24 de 24 pruebas superadas exitosamente (100%).
================================================================================
```

---

## 6. CONFIGURACIÓN DE SECRETOS REQUERIDA

Para la operación en producción sobre Supabase Edge Functions, configure los siguientes secretos:

```bash
supabase secrets set GEMINI_API_KEY="AIzaSy..."
supabase secrets set OPENAI_API_KEY="sk-..."
supabase secrets set REPLICATE_API_TOKEN="r8_..."
# Opcional si se utiliza Remove.bg para segmentación:
# supabase secrets set REMOVE_BG_API_KEY="..."
```
