-- ==============================================================================
-- AI TOOLBOX — FASE 1.5: AUDITORÍA Y CORRECCIÓN DE SEGURIDAD
-- ==============================================================================

-- 1. PROTECCIÓN DE FUNCIONES RPC DE CRÉDITOS CONTRA MANIPULACIÓN DESDE EL CLIENTE
-- Ningún usuario autenticado o anónimo puede ejecutar add_credits, refund_credits o deduct_credits directamente.
-- La única entidad autorizada para invocar estas funciones es el backend (service_role) en las Edge Functions.

REVOKE EXECUTE ON FUNCTION public.add_credits(UUID, INTEGER, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.add_credits(UUID, INTEGER, TEXT, TEXT) TO service_role;

REVOKE EXECUTE ON FUNCTION public.refund_credits(UUID, INTEGER, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.refund_credits(UUID, INTEGER, TEXT, TEXT) TO service_role;

REVOKE EXECUTE ON FUNCTION public.deduct_credits(UUID, INTEGER, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.deduct_credits(UUID, INTEGER, TEXT, TEXT) TO service_role;

-- 2. PROTECCIÓN DEL CAMPO 'plan' EN PROFILES CONTRA ESCALADA DE PRIVILEGIOS
CREATE OR REPLACE FUNCTION public.protect_profile_fields()
RETURNS TRIGGER AS $$
BEGIN
    -- Si el rol no es service_role, no se permite cambiar de plan directamente
    IF (OLD.plan IS DISTINCT FROM NEW.plan) AND (current_user <> 'service_role') THEN
        RAISE EXCEPTION 'El plan solo puede ser actualizado por el sistema de pagos y suscripciones.';
    END IF;
    -- Impedir modificación del ID
    IF (OLD.id IS DISTINCT FROM NEW.id) THEN
        RAISE EXCEPTION 'El ID de usuario no puede ser modificado.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_protect_profile_fields ON public.profiles;
CREATE TRIGGER trg_protect_profile_fields
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.protect_profile_fields();

-- 3. ENDURECIMIENTO DE POLÍTICAS DE ROW LEVEL SECURITY EN STORAGE
DROP POLICY IF EXISTS "Users manage own files" ON storage.objects;

CREATE POLICY "Users view own files" ON storage.objects
FOR SELECT USING (
    bucket_id = 'user-files' AND 
    (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Users upload own files" ON storage.objects
FOR INSERT WITH CHECK (
    bucket_id = 'user-files' AND 
    (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Users delete own files" ON storage.objects
FOR DELETE USING (
    bucket_id = 'user-files' AND 
    (storage.foldername(name))[1] = auth.uid()::text
);

-- 4. ÍNDICES DE RENDIMIENTO Y CONCURRENCIA
CREATE INDEX IF NOT EXISTS idx_credit_balances_user_id ON public.credit_balances(user_id);
CREATE INDEX IF NOT EXISTS idx_credit_transactions_user_id ON public.credit_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_generations_user_id ON public.generations(user_id);
CREATE INDEX IF NOT EXISTS idx_projects_user_id ON public.projects(user_id);
CREATE INDEX IF NOT EXISTS idx_tools_category ON public.tools(category) WHERE enabled = true;
CREATE INDEX IF NOT EXISTS idx_tools_slug ON public.tools(slug);
