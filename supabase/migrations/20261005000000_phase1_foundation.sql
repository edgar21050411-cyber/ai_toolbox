-- ==============================================================================
-- AI TOOLBOX — FASE 1: FOUNDATION DATABASE MIGRATION
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ------------------------------------------------------------------------------
-- 1. PROFILES (Extensión de auth.users con balance de créditos y plan)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    display_name TEXT,
    avatar_url TEXT,
    language TEXT DEFAULT 'es' CHECK (language IN ('es', 'en')),
    country TEXT,
    plan TEXT DEFAULT 'free' CHECK (plan IN ('free', 'pro', 'business')),
    credit_balance INTEGER NOT NULL DEFAULT 15 CHECK (credit_balance >= 0),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Trigger para aprovisionar perfil automáticamente en Supabase Auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, display_name, avatar_url, credit_balance)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
        NEW.raw_user_meta_data->>'avatar_url',
        15 -- 15 créditos de bienvenida para validar el MVP
    );

    INSERT INTO public.credit_transactions (user_id, amount, transaction_type, description)
    VALUES (NEW.id, 15, 'bonus', 'Bono de bienvenida inicial');

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ------------------------------------------------------------------------------
-- 2. TOOLS (Catálogo dinámico de herramientas administrable sin desplegar app)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.tools (
    id TEXT PRIMARY KEY,
    name JSONB NOT NULL,             -- {"es": "Quitar fondo", "en": "Remove Background"}
    description JSONB NOT NULL,      -- {"es": "...", "en": "..."}
    category TEXT NOT NULL,          -- 'create', 'improve', 'sell', 'documents', 'audio', 'assistant'
    icon TEXT NOT NULL,
    enabled BOOLEAN DEFAULT true,
    beta BOOLEAN DEFAULT false,
    minimum_plan TEXT DEFAULT 'free',
    credit_cost INTEGER NOT NULL DEFAULT 1,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- 3. CREDIT COSTS (Matriz de precios por operación de IA)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.credit_costs (
    operation_key TEXT PRIMARY KEY,
    credits INTEGER NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- 4. CREDIT TRANSACTIONS (Historial inmutable y auditable)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.credit_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    amount INTEGER NOT NULL,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('purchase', 'subscription', 'usage', 'refund', 'bonus', 'adjustment')),
    tool TEXT,
    generation_id UUID,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- 5. GENERATION USAGE (Métricas de negocio, costos reales de API y latencia)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.generation_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    tool TEXT NOT NULL,
    provider TEXT NOT NULL,
    model TEXT NOT NULL,
    credits_used INTEGER NOT NULL,
    estimated_api_cost NUMERIC(10, 6) DEFAULT 0,
    processing_time_ms INTEGER,
    status TEXT NOT NULL CHECK (status IN ('success', 'failed', 'moderation_rejected')),
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- 6. FEATURE FLAGS & SUBSCRIPTION CONFIGURATIONS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.feature_flags (
    key TEXT PRIMARY KEY,
    enabled BOOLEAN DEFAULT false,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.subscription_plans (
    id TEXT PRIMARY KEY,
    name JSONB NOT NULL,
    credits_per_month INTEGER NOT NULL,
    price_usd NUMERIC(10, 2) NOT NULL,
    features JSONB NOT NULL,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.credit_packages (
    id TEXT PRIMARY KEY,
    credits INTEGER NOT NULL,
    price_usd NUMERIC(10, 2) NOT NULL,
    popular BOOLEAN DEFAULT false,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- 7. FUNCIONES TRANSACCIONALES RPC (Deducción y Reembolso Atómico)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.deduct_credits(
    p_user_id UUID,
    p_amount INTEGER,
    p_tool TEXT,
    p_description TEXT
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_current_balance INTEGER;
    v_tx_id UUID;
BEGIN
    -- Bloqueo exclusivo de fila para evitar race conditions
    SELECT credit_balance INTO v_current_balance
    FROM public.profiles
    WHERE id = p_user_id FOR UPDATE;

    IF v_current_balance IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'user_not_found');
    END IF;

    IF v_current_balance < p_amount THEN
        RETURN jsonb_build_object(
            'success', false, 
            'error', 'insufficient_credits', 
            'balance', v_current_balance,
            'required', p_amount
        );
    END IF;

    UPDATE public.profiles
    SET credit_balance = credit_balance - p_amount,
        updated_at = NOW()
    WHERE id = p_user_id;

    INSERT INTO public.credit_transactions (user_id, amount, transaction_type, tool, description)
    VALUES (p_user_id, -p_amount, 'usage', p_tool, p_description)
    RETURNING id INTO v_tx_id;

    RETURN jsonb_build_object(
        'success', true, 
        'transaction_id', v_tx_id, 
        'new_balance', v_current_balance - p_amount
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.refund_credits(
    p_user_id UUID,
    p_amount INTEGER,
    p_tool TEXT,
    p_reason TEXT
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_new_balance INTEGER;
    v_tx_id UUID;
BEGIN
    UPDATE public.profiles
    SET credit_balance = credit_balance + p_amount,
        updated_at = NOW()
    WHERE id = p_user_id
    RETURNING credit_balance INTO v_new_balance;

    INSERT INTO public.credit_transactions (user_id, amount, transaction_type, tool, description)
    VALUES (p_user_id, p_amount, 'refund', p_tool, p_reason)
    RETURNING id INTO v_tx_id;

    RETURN jsonb_build_object(
        'success', true, 
        'transaction_id', v_tx_id, 
        'new_balance', v_new_balance
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 8. ROW LEVEL SECURITY (RLS) POLICIES
-- ------------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.credit_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.generation_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tools ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.credit_costs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feature_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.credit_packages ENABLE ROW LEVEL SECURITY;

-- Catálogos y configuración: lectura pública para clientes autenticados o anónimos
CREATE POLICY "Public read tools" ON public.tools FOR SELECT USING (enabled = true);
CREATE POLICY "Public read credit costs" ON public.credit_costs FOR SELECT USING (true);
CREATE POLICY "Public read feature flags" ON public.feature_flags FOR SELECT USING (true);
CREATE POLICY "Public read subscription plans" ON public.subscription_plans FOR SELECT USING (true);
CREATE POLICY "Public read credit packages" ON public.credit_packages FOR SELECT USING (true);

-- Información privada de usuario: solo el propio usuario puede leer/modificar
CREATE POLICY "Users view own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users view own transactions" ON public.credit_transactions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users view own generation usage" ON public.generation_usage FOR SELECT USING (auth.uid() = user_id);

-- ------------------------------------------------------------------------------
-- 9. CONFIGURACIÓN DE STORAGE Y POLÍTICAS DE ACCESO
-- ------------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public) 
VALUES ('user_assets', 'user_assets', false)
ON CONFLICT (id) DO NOTHING;

-- Políticas de Storage: Cada usuario solo puede ver, subir y borrar sus propios archivos en users/{user_id}/...
CREATE POLICY "Users can upload their own files" ON storage.objects
FOR INSERT WITH CHECK (
    bucket_id = 'user_assets' AND 
    (storage.foldername(name))[1] = 'users' AND 
    (storage.foldername(name))[2] = auth.uid()::text
);

CREATE POLICY "Users can view their own files" ON storage.objects
FOR SELECT USING (
    bucket_id = 'user_assets' AND 
    (storage.foldername(name))[1] = 'users' AND 
    (storage.foldername(name))[2] = auth.uid()::text
);

CREATE POLICY "Users can delete their own files" ON storage.objects
FOR DELETE USING (
    bucket_id = 'user_assets' AND 
    (storage.foldername(name))[1] = 'users' AND 
    (storage.foldername(name))[2] = auth.uid()::text
);

-- ------------------------------------------------------------------------------
-- 10. DATOS INICIALES (SEED DATA)
-- ------------------------------------------------------------------------------
INSERT INTO public.credit_costs (operation_key, credits, description) VALUES
('TEXT_GENERATION', 1, 'Generación o reescritura de texto estándar'),
('TRANSLATION', 1, 'Traducción multilenguaje'),
('SUMMARY', 1, 'Resumen de texto y extracción de ideas clave'),
('IMAGE_ANALYSIS', 2, 'Comprensión y análisis multimodal de imagen'),
('PDF_ANALYSIS', 2, 'Extracción y análisis de documentos'),
('BACKGROUND_REMOVE', 3, 'Segmentación y eliminación de fondo'),
('IMAGE_GENERATION', 5, 'Generación de imagen mediante modelo visual'),
('IMAGE_EDIT', 5, 'Edición asistida o reemplazo de fondo'),
('ADVERTISEMENT', 5, 'Creación de anuncio publicitario completo'),
('CAMPAIGN', 8, 'Campaña integral multicanal con variantes')
ON CONFLICT (operation_key) DO UPDATE SET credits = EXCLUDED.credits;

INSERT INTO public.tools (id, name, description, category, icon, credit_cost, sort_order) VALUES
('remove_bg', '{"es": "Quitar fondo", "en": "Remove Background"}', '{"es": "Elimina el fondo de fotos y productos en segundos", "en": "Remove background from photos and products in seconds"}', 'improve', 'layers_clear', 3, 1),
('improve_img', '{"es": "Mejorar imagen", "en": "Improve Image"}', '{"es": "Aumenta la nitidez, iluminación y detalle visual", "en": "Upscale sharpness, lighting, and detail"}', 'improve', 'auto_fix_high', 3, 2),
('change_bg', '{"es": "Cambiar fondo", "en": "Change Background"}', '{"es": "Sitúa tu producto en un entorno profesional realista", "en": "Place your product in a realistic professional setting"}', 'improve', 'wallpaper', 5, 3),
('create_ad', '{"es": "Crear anuncio", "en": "Create Ad"}', '{"es": "Genera copias persuasivas y creatividades para redes", "en": "Generate persuasive copy and visuals for ads"}', 'sell', 'campaign', 5, 4),
('social_post', '{"es": "Publicación social", "en": "Social Post"}', '{"es": "Posts de alto impacto para Instagram, TikTok o LinkedIn", "en": "High impact social posts for Instagram, TikTok, LinkedIn"}', 'sell', 'share', 2, 5),
('product_desc', '{"es": "Descripción de producto", "en": "Product Description"}', '{"es": "Títulos y fichas de venta optimizadas para conversión", "en": "Conversion-optimized product titles and descriptions"}', 'sell', 'shopping_bag', 2, 6),
('create_campaign', '{"es": "Crear campaña", "en": "Create Campaign"}', '{"es": "Concepto, 3 copias, 3 creatividades y variantes", "en": "Complete campaign concept, 3 copies, and variants"}', 'sell', 'rocket_launch', 8, 7),
('rewrite_text', '{"es": "Reescribir texto", "en": "Rewrite Text"}', '{"es": "Mejora el tono, vocabulario y claridad del texto", "en": "Enhance tone, vocabulary, and clarity"}', 'create', 'edit_note', 1, 8),
('translate_text', '{"es": "Traducir", "en": "Translate"}', '{"es": "Traducción natural adaptada al contexto cultural", "en": "Natural translation tailored to context"}', 'create', 'translate', 1, 9),
('summarize_text', '{"es": "Resumir", "en": "Summarize"}', '{"es": "Condensa textos largos en puntos claros y concisos", "en": "Condense long articles into clear key points"}', 'create', 'summarize', 1, 10)
ON CONFLICT (id) DO UPDATE SET 
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    credit_cost = EXCLUDED.credit_cost;

INSERT INTO public.subscription_plans (id, name, credits_per_month, price_usd, features, sort_order) VALUES
('free', '{"es": "Gratuito", "en": "Free"}', 15, 0.00, '["15 créditos iniciales", "Acceso a herramientas básicas", "Anuncios ocasionales"]', 1),
('pro', '{"es": "Pro", "en": "Pro"}', 300, 9.99, '["300 créditos mensuales", "Sin anuncios", "Prioridad alta", "Herramientas de imagen y anuncios"]', 2),
('business', '{"es": "Business", "en": "Business"}', 1000, 29.99, '["1000 créditos mensuales", "Máxima prioridad", "Campañas y modo comercial", "Soporte dedicado"]', 3)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.credit_packages (id, credits, price_usd, popular, sort_order) VALUES
('pack_100', 100, 3.99, false, 1),
('pack_500', 500, 14.99, true, 2),
('pack_1000', 1000, 24.99, false, 3),
('pack_3000', 3000, 59.99, false, 4)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.feature_flags (key, enabled, description) VALUES
('new_image_engine', true, 'Motor visual Imagen 3 y remoción de fondo'),
('advanced_ads', true, 'Generación de campañas con múltiples variantes'),
('audio_tools', false, 'Fase 5: Transcripción y síntesis de voz'),
('pdf_chat', false, 'Fase 4: Análisis de documentos PDF')
ON CONFLICT (key) DO NOTHING;
