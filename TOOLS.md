# AI TOOLBOX — CATÁLOGO DE LAS 10 HERRAMIENTAS OFICIALES (FASE 2)

Las 10 herramientas iniciales de **AI Toolbox** están registradas dinámicamente en el backend (`public.tools`) y gobernadas por el `AI Router`.

---

## 📋 Matriz de Herramientas Implementadas

| Herramienta | ID Oficial | Categoría | Costo (Créditos) | Motor / Proveedor |
|---|---|---|---|---|
| **Reescribir texto** | `rewrite_text` | `text` | 1 | `TextEngine` (Gemini 1.5 Flash / OpenAI fallback) |
| **Traducir texto** | `translate_text` | `text` | 1 | `TextEngine` (Gemini 1.5 Flash / OpenAI fallback) |
| **Resumir texto** | `summarize_text` | `text` | 1 | `TextEngine` (Gemini 1.5 Flash / OpenAI fallback) |
| **Crear anuncio** | `create_ad` | `marketing` | 4 | `TextEngine` (Structured JSON - Gemini Flash) |
| **Publicación para redes** | `social_post` | `marketing` | 3 | `TextEngine` (Structured JSON - Gemini Flash) |
| **Descripción de producto** | `product_description` | `marketing` | 3 | `TextEngine` (Structured JSON - Gemini Flash) |
| **Crear imagen con IA** | `generate_image` | `images` | 5 | `ImageEngine` (Google Imagen 3) |
| **Mejorar imagen** | `improve_image` | `images` | 5 | `ImageEngine` (Vision Upscaler) |
| **Quitar fondo** | `remove_background` | `images` | 3 | `ImageEngine` (Segmentation Alpha PNG) |
| **Cambiar fondo** | `change_background` | `images` | 5 | `ImageEngine` (Imagen Inpaint) |

---

## 🛠️ Especificación Detallada de Entradas y Salidas

### 1. Reescribir texto (`rewrite_text`)
* **Entrada**: `text` (String), `tone` (`Profesional`, `Casual`, `Amigable`, `Persuasivo`, `Formal`, `Corto`).
* **Salida**: `{"text": "Texto reescrito..."}`.
* **Acciones**: Copiar al portapapeles.

### 2. Traducir texto (`translate_text`)
* **Entrada**: `text` (String), `source_language` (`Auto`, `Español`, `Inglés`, etc.), `target_language` (`Español`, `Inglés`, `Francés`, `Portugués`, `Alemán`, `Italiano`).
* **Salida**: `{"text": "Texto traducido..."}`.
* **Acciones**: Copiar al portapapeles.

### 3. Resumir texto (`summarize_text`)
* **Entrada**: `text` (String), `length` (`Corto`, `Medio`, `Detallado`).
* **Salida**: `{"text": "Resumen estructurado..."}`.
* **Acciones**: Copiar al portapapeles.

### 4. Crear anuncio (`create_ad`)
* **Entrada**: `product_service`, `target_audience`, `main_benefit`, `tone`, `platform` (`Facebook`, `Instagram`, `TikTok`, `LinkedIn`, `WhatsApp`).
* **Salida**: `{"title": "...", "main_text": "...", "cta": "...", "platform": "..."}`.
* **Acciones**: Copiar bloque completo formateado.

### 5. Publicación para redes (`social_post`)
* **Entrada**: `topic_product`, `platform`, `tone`, `goal`.
* **Salida**: `{"post": "...", "cta": "...", "hashtags": ["#tag1", "#tag2"], "platform": "..."}`.
* **Acciones**: Copiar publicación completa con hashtags.

### 6. Descripción de producto (`product_description`)
* **Entrada**: `name`, `features`, `benefits`, `audience`, `tone`.
* **Salida**: `{"title": "...", "short_description": "...", "full_description": "...", "benefits": [...], "cta": "..."}`.
* **Acciones**: Copiar ficha comercial completa.

### 7. Crear imagen con IA (`generate_image`)
* **Entrada**: `prompt` (String descriptivo no vacío, máx. 1000 caracteres).
* **Salida**: `{"image_url": "https://...", "prompt": "...", "format": "png"}`.
* **Acciones**: Visualizar en alta calidad, Guardar en Mis Creaciones, Copiar enlace.

### 8. Mejorar imagen (`improve_image`)
* **Entrada**: `image_url` (URL de imagen válida).
* **Salida**: `{"enhanced_image_url": "https://...", "factor": "2x"}`.
* **Acciones**: Comparar y guardar.

### 9. Quitar fondo (`remove_background`)
* **Entrada**: `image_url` (URL de imagen válida).
* **Salida**: `{"image_url": "https://...", "transparency": true, "format": "png"}`.
* **Acciones**: Descargar PNG transparente, guardar.

### 10. Cambiar fondo (`change_background`)
* **Entrada**: `image_url`, `background_description` (Descripción textual del nuevo entorno).
* **Salida**: `{"image_url": "https://...", "background_description": "..."}`.
* **Acciones**: Visualizar composición final, guardar.

---

## 🔒 Control de Costos en Backend
El cliente **nunca** define el costo de la operación. El costo se valida y deduce atómicamente en PostgreSQL dentro de la Edge Function antes de enviar la petición a los adaptadores de IA. En caso de fallo del motor o rechazo de moderación, los créditos son reembolsados automáticamente.
