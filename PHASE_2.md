# FASE 2 — IMPLEMENTACIÓN DE LAS PRIMERAS 10 HERRAMIENTAS

## 1. Resumen Ejecutivo
En esta Fase 2 se implementó el pipeline funcional de extremo a extremo para las **10 herramientas iniciales** de AI Toolbox, integrando la UI dinámica de Flutter, el `ToolRegistry`, el `AIRouterClient`, la Edge Function `ai-router`, los motores `TextEngine` e `ImageEngine`, y la persistencia en las tablas `generations`, `credit_balances` y `credit_transactions`.

---

## 2. Pipeline de Ejecución de Extremo a Extremo

```
Flutter (ToolScreen)
      ↓ (Valida input local y existencia de créditos suficientes)
AIRouterClient
      ↓ (POST /functions/v1/ai-router con Bearer JWT)
Supabase Edge Function (ai-router)
      ↓ (1. Valida autenticación)
      ↓ (2. Determina costo dinámico desde public.tools)
      ↓ (3. Ejecuta RPC deduct_credits con bloqueo FOR UPDATE)
      ↓ (4. Ejecuta ModerationService preventivo)
      ↓ (5. Enruta a TextEngine o ImageEngine)
Provider Adapter (GeminiAdapter / OpenAI fallback / Imagen)
      ↓
Generación de Resultado
      ↓ (Registra en tabla public.generations: tokens, tiempo ms, costo USD)
      ↓ (Si ocurre error de IA: ejecuta RPC refund_credits y devuelve 502)
Respuesta al Cliente (200 OK con payload, créditos restantes y tiempo ms)
      ↓
Flutter (Renderiza formulario con resultado copiable o visualizador de imagen)
```

---

## 3. Desglose de las 10 Herramientas

### Etapa 1: Herramientas de Texto
1. **Reescribir texto (`rewrite_text`)**:
   * Categoría: `text` | Costo: 1 crédito
   * Provider: Gemini 1.5 Flash (Fallback a GPT-4o-mini)
   * Limitación: Máximo 10,000 caracteres de texto fuente.
2. **Traducir texto (`translate_text`)**:
   * Categoría: `text` | Costo: 1 crédito
   * Idiomas: Español, Inglés, Francés, Portugués, Alemán, Italiano (con detección automática).
3. **Resumir texto (`summarize_text`)**:
   * Categoría: `text` | Costo: 1 crédito
   * Modos: Corto (1-2 oraciones), Medio (1 párrafo y viñetas), Detallado (exhaustivo).

### Etapa 2: Herramientas de Marketing
4. **Crear anuncio (`create_ad`)**:
   * Categoría: `marketing` | Costo: 4 créditos
   * Formato estructurado: Título comercial, Texto persuasivo, CTA y Plataforma.
5. **Publicación para redes (`social_post`)**:
   * Categoría: `marketing` | Costo: 3 créditos
   * Plataformas: Instagram, Facebook, TikTok, LinkedIn, WhatsApp con hashtags incluidos.
6. **Descripción de producto (`product_description`)**:
   * Categoría: `marketing` | Costo: 3 créditos
   * Formato: Título de alta conversión, Resumen corto, Descripción completa, 4 Beneficios y CTA.

### Etapa 3: Generación de Imagen
7. **Crear imagen con IA (`generate_image`)**:
   * Categoría: `images` | Costo: 5 créditos
   * Provider: Google Imagen 3 (formato PNG de alta resolución).
   * Limitación: Prompt de hasta 1,000 caracteres.

### Etapa 4: Edición de Imagen
8. **Mejorar imagen (`improve_image`)**:
   * Categoría: `images` | Costo: 5 créditos
   * Provider: Google Vision Upscaler (nitidez, iluminación y aumento 2x).
9. **Quitar fondo (`remove_background`)**:
   * Categoría: `images` | Costo: 3 créditos
   * Provider: Segmentation Engine con canal alfa (transparencia conservada).
10. **Cambiar fondo (`change_background`)**:
    * Categoría: `images` | Costo: 5 créditos
    * Provider: Imagen Inpaint (sintetiza el nuevo escenario manteniendo el producto intacto).

---

## 4. Control de Costos y Transacciones
* **Doble cobro prevenido**: Toda deducción se realiza atómicamente en PostgreSQL antes del llamado al proveedor de IA.
* **Reembolso automático**: Si la petición falla o es rechazada por moderación, `refund_credits` devuelve el saldo y asienta la transacción tipo `refund`.
* **Cero llamadas innecesarias**: Pruebas unitarias ejecutadas con mocks para garantizar cero gasto durante el desarrollo y testing.
