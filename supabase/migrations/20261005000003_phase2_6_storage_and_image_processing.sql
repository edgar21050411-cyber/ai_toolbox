-- ==============================================================================
-- AI TOOLBOX — FASE 2.6: MIGRACIÓN DE STORAGE Y GENERACIONES
-- ==============================================================================

-- 1. TABLA PUBLIC.GENERATIONS
-- Tabla central para auditoría, métricas y persistencia de resultados de IA.
CREATE TABLE IF NOT EXISTS public.generations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    tool_id TEXT NOT NULL,
    provider TEXT NOT NULL,
    model TEXT NOT NULL,
    credits_used INTEGER NOT NULL DEFAULT 0,
    estimated_api_cost NUMERIC(10, 6) DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'completed',
    input_type TEXT DEFAULT 'text',
    result_url TEXT,
    storage_path TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    error_code TEXT,
    processing_time_ms INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

ALTER TABLE public.generations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users view own generations" ON public.generations;
CREATE POLICY "Users view own generations" ON public.generations
FOR SELECT USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_generations_user_created ON public.generations(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_generations_storage_path ON public.generations(storage_path) WHERE storage_path IS NOT NULL;

-- 2. CONFIGURACIÓN DE STORAGE BUCKETS (generated-files y user-files)
-- Registro en storage.buckets con límites de tamaño y tipos MIME permitidos.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) 
VALUES (
    'generated-files',
    'generated-files',
    false,
    15728640, -- 15MB
    ARRAY['image/png', 'image/jpeg', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) 
VALUES (
    'user-files',
    'user-files',
    false,
    15728640, -- 15MB
    ARRAY['image/png', 'image/jpeg', 'image/webp', 'text/plain', 'application/pdf']
)
ON CONFLICT (id) DO UPDATE SET
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- 3. POLÍTICAS DE RLS PARA BUCKET 'generated-files'
-- Lectura: cada usuario solo puede ver sus propios archivos generados
DROP POLICY IF EXISTS "Users view own generated files" ON storage.objects;
CREATE POLICY "Users view own generated files" ON storage.objects
FOR SELECT USING (
    bucket_id = 'generated-files' AND 
    (storage.foldername(name))[1] = auth.uid()::text
);

-- Eliminación: cada usuario puede borrar sus archivos generados si lo desea
DROP POLICY IF EXISTS "Users delete own generated files" ON storage.objects;
CREATE POLICY "Users delete own generated files" ON storage.objects
FOR DELETE USING (
    bucket_id = 'generated-files' AND 
    (storage.foldername(name))[1] = auth.uid()::text
);

-- Nota: La inserción en 'generated-files' se realiza de forma segura desde el backend
-- (Supabase Edge Function) utilizando el cliente con service_role (AdminClient).
