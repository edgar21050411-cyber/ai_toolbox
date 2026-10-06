# AI TOOLBOX — ARQUITECTURA DE PROVEEDORES DE IA

## 1. Desacoplamiento de Herramientas
Ninguna herramienta se comunica directamente con OpenAI, Google Gemini, Google Imagen o Replicate desde el dispositivo móvil. La aplicación Flutter invoca exclusivamente el endpoint del backend:

```
Flutter (AIRouterClient)
          │ (HTTPS con JWT de sesión)
Supabase Edge Function (ai-router)
  ├── Validación de Usuario y Saldo
  ├── Deducción Atómica de Créditos (RPC deduct_credits con SELECT FOR UPDATE)
  ├── ModerationService (Pre-filtro)
  │
  ├── TextEngine / MarketingEngine
  │     ├── GeminiAdapter (Google Gemini 1.5 Flash / Pro)
  │     └── OpenAIAdapter (Fallback transparente gpt-4o-mini)
  │
  └── ImageEngine (Fase 2.6: Procesamiento Real + Persistencia)
        ├── GoogleImagenProvider (Google Imagen 3: imagen-3.0-generate-002)
        ├── ReplicateImageProvider (Modelos oficiales)
        │     ├── remove_background: bria/remove-background (Canal alfa real)
        │     ├── improve_image: nightmareai/real-esrgan (Super-resolution 2x/4x)
        │     └── change_background: bria/generate-background (Inpainting / composición)
        └── ImageStorageService
              └── Supabase Storage ('generated-files' con RLS por user_id)
```

## 2. Catálogo Oficial de Herramientas y Proveedores Reales

| Herramienta | Operación | Proveedor Real | Modelo / Endpoint | Formato Entrada | Formato Salida | Persistencia Storage |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `generate_image` | Text-to-Image | Google Imagen 3 | `imagen-3.0-generate-002:predict` | Prompt (<=1000 char) + estilo | PNG Base64 decodificado | `generated-files/{uid}/generate_image_{ts}_{id}.png` |
| `improve_image` | Super-resolution / Upscale | Replicate | `nightmareai/real-esrgan` | Imagen URL/Base64, factor: 2x | PNG/JPEG alta resolución | `generated-files/{uid}/improve_image_{ts}_{id}.png` |
| `remove_background` | Segmentación de silueta | Replicate / Remove.bg | `bria/remove-background` | Imagen URL/Base64 | PNG transparente (RGBA) | `generated-files/{uid}/remove_background_{ts}_{id}.png` |
| `change_background` | Inpainting y composición | Replicate | `bria/generate-background` | Imagen URL/Base64 + Prompt fondo | PNG/JPEG compuesto | `generated-files/{uid}/change_background_{ts}_{id}.png` |

## 3. Eliminación de Simulaciones
* Se eliminó completamente la manipulación de query strings (`?enhanced=...`, `?processed=...`, `?bg_removed=...`, `?new_bg=...`, `?composed=...`).
* En ausencia de credenciales requeridas (`REPLICATE_API_TOKEN` o `GEMINI_API_KEY`), el backend **no simula la respuesta**: arroja un error controlado indicando la clave faltante, reembolsa los créditos atómicamente y registra la falla en `generations`.

## 4. Reglas de Fallback Seguro
1. **Cuándo Sí se ejecuta Fallback**:
   * Caída del servidor del proveedor principal (HTTP 500, 502, 503, 504).
   * Timeout de red en la infraestructura de la API.
   * Límite de tasa transitorio (HTTP 429).
2. **Cuándo NUNCA se ejecuta Fallback**:
   * Contenido rechazado por políticas de moderación o seguridad (`SAFETY`, `HARM_CATEGORY`, `BLOCKED`).
   * Petición malformada o error de validación de entrada (HTTP 400).
   * Saldo de créditos insuficiente (HTTP 402).
   * Sesión de usuario expirada o no autorizada (HTTP 401).

## 5. Seguridad de Entrada y Anti-SSRF
* Las URLs de entrada son inspeccionadas por `ImageStorageService.resolveInputImage`.
* Se bloquean peticiones hacia IPs privadas o de bucle local (`localhost`, `127.0.0.1`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `169.254.169.254`).
* Las imágenes en Base64 son decodificadas, validadas con Magic Bytes (PNG, JPEG, WebP) y cargadas temporalmente a `user-files/{uid}/inputs/` con URL firmada temporal de 1 hora para ser procesadas de manera segura por el proveedor.
