-- ==============================================================================
-- AI TOOLBOX — FASE 2: REGISTRO EXACTO DE LAS PRIMERAS 10 HERRAMIENTAS
-- ==============================================================================

-- Actualizar o insertar las 10 herramientas oficiales con sus IDs y costos definitivos
INSERT INTO public.tools (id, slug, name, description, category, icon, enabled, beta, minimum_plan, credit_cost, sort_order) VALUES
(
    'rewrite_text',
    'reescribir-texto',
    '{"es": "Reescribir texto", "en": "Rewrite Text"}',
    '{"es": "Mejora el tono, vocabulario y claridad de cualquier texto", "en": "Enhance tone, vocabulary, and clarity of any text"}',
    'text',
    'edit_note',
    true,
    false,
    'free',
    1,
    1
),
(
    'translate_text',
    'traducir-texto',
    '{"es": "Traducir texto", "en": "Translate Text"}',
    '{"es": "Traducción natural y contextual en múltiples idiomas", "en": "Natural, contextual translation across multiple languages"}',
    'text',
    'translate',
    true,
    false,
    'free',
    1,
    2
),
(
    'summarize_text',
    'resumir-texto',
    '{"es": "Resumir texto", "en": "Summarize Text"}',
    '{"es": "Condensa textos largos en puntos claros y concisos", "en": "Condense long articles into clear key points"}',
    'text',
    'summarize',
    true,
    false,
    'free',
    1,
    3
),
(
    'create_ad',
    'crear-anuncio',
    '{"es": "Crear anuncio", "en": "Create Ad"}',
    '{"es": "Genera copias persuasivas y creatividades para redes", "en": "Generate persuasive copy and visuals for ads"}',
    'marketing',
    'campaign',
    true,
    false,
    'free',
    4,
    4
),
(
    'social_post',
    'publicacion-social',
    '{"es": "Publicación para redes", "en": "Social Media Post"}',
    '{"es": "Posts de alto impacto para Instagram, TikTok, LinkedIn y más", "en": "High-impact social posts for Instagram, TikTok, LinkedIn"}',
    'marketing',
    'share',
    true,
    false,
    'free',
    3,
    5
),
(
    'product_description',
    'descripcion-producto',
    '{"es": "Descripción de producto", "en": "Product Description"}',
    '{"es": "Títulos y fichas de venta optimizadas para conversión", "en": "Conversion-optimized product titles and descriptions"}',
    'marketing',
    'shopping_bag',
    true,
    false,
    'free',
    3,
    6
),
(
    'generate_image',
    'generar-imagen',
    '{"es": "Crear imagen con IA", "en": "Generate Image with AI"}',
    '{"es": "Genera imágenes realistas y creativas a partir de texto", "en": "Generate realistic and creative images from text prompts"}',
    'images',
    'auto_awesome',
    true,
    false,
    'free',
    5,
    7
),
(
    'improve_image',
    'mejorar-imagen',
    '{"es": "Mejorar imagen", "en": "Improve Image"}',
    '{"es": "Aumenta la nitidez, iluminación y detalle visual de fotos", "en": "Upscale sharpness, lighting, and visual detail of photos"}',
    'images',
    'auto_fix_high',
    true,
    false,
    'free',
    5,
    8
),
(
    'remove_background',
    'quitar-fondo',
    '{"es": "Quitar fondo", "en": "Remove Background"}',
    '{"es": "Elimina el fondo de fotos y productos conservando transparencia", "en": "Remove background from photos and products with transparency"}',
    'images',
    'layers_clear',
    true,
    false,
    'free',
    3,
    9
),
(
    'change_background',
    'cambiar-fondo',
    '{"es": "Cambiar fondo", "en": "Change Background"}',
    '{"es": "Sitúa tu producto o foto en un escenario completamente nuevo", "en": "Place your product or photo in a realistic new scene"}',
    'images',
    'wallpaper',
    true,
    false,
    'free',
    5,
    10
)
ON CONFLICT (id) DO UPDATE SET
    slug = EXCLUDED.slug,
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    category = EXCLUDED.category,
    icon = EXCLUDED.icon,
    credit_cost = EXCLUDED.credit_cost,
    sort_order = EXCLUDED.sort_order,
    updated_at = NOW();

-- Actualizar tabla de credit_costs para sincronía perfecta
INSERT INTO public.credit_costs (operation_key, credits, description) VALUES
('rewrite_text', 1, 'Reescritura de texto con control de tono'),
('translate_text', 1, 'Traducción multilingüe contextual'),
('summarize_text', 1, 'Resumen de texto por longitud'),
('create_ad', 4, 'Creación de anuncios estructurados multicanal'),
('social_post', 3, 'Publicación para redes sociales con hashtags'),
('product_description', 3, 'Ficha y descripción comercial de producto'),
('generate_image', 5, 'Generación de imagen mediante modelo visual'),
('improve_image', 5, 'Mejora visual y reescalado de imagen'),
('remove_background', 3, 'Segmentación y eliminación de fondo'),
('change_background', 5, 'Cambio y síntesis de nuevo escenario en imagen')
ON CONFLICT (operation_key) DO UPDATE SET credits = EXCLUDED.credits, updated_at = NOW();
