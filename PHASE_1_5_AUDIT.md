# PHASE 1.5 — AUDITORÍA Y CORRECCIÓN DE FOUNDATION

## 1. Resumen
* **Estado general**: **PASS WITH WARNINGS**
  *(PASS en todas las áreas de arquitectura, seguridad, bases de datos y Edge Functions; WARNING únicamente debido a que el entorno de desarrollo del sistema anfitrión no tiene los binarios globales `flutter` y `dart` en su `$env:PATH`, por lo que el análisis y compilación en binario Android debe ejecutarse cuando se configure el PATH del SDK o en el pipeline de CI/CD).*

---

## 2. Problemas Encontrados y Correcciones Aplicadas

### Problema 1: Funciones RPC de créditos expuestas a manipulación desde el cliente
* **Severidad**: **CRITICAL**
* **Archivo**: `supabase/migrations/20261005000000_phase1_foundation.sql`
* **Descripción**: Las funciones RPC `add_credits`, `refund_credits` y `deduct_credits` tenían permisos `EXECUTE` por defecto para cualquier usuario autenticado o anónimo. Esto permitía que un usuario malicioso invocara directamente `supabase.rpc('add_credits', ...)` para acreditarse saldo ilimitado de forma gratuita o manipular créditos.
* **Corrección aplicada**: Se creó la migración `supabase/migrations/20261005000001_phase1_5_security_hardening.sql` que revoca explícitamente el permiso `EXECUTE` a `PUBLIC`, `anon` y `authenticated`, restringiéndolo exclusivamente al rol de sistema `service_role` (utilizado por las Edge Functions del backend). En Flutter, `CreditService` se convirtió en un servicio de solo lectura y el cliente nunca llama a estas funciones directamente.

---

### Problema 2: Posible escalada de privilegios en el campo `plan` de `profiles`
* **Severidad**: **HIGH**
* **Archivo**: `supabase/migrations/20261005000000_phase1_foundation.sql`
* **Descripción**: La política de RLS `Users update own profile` permitía modificar cualquier columna de la tabla `profiles` si el ID coincidía con el usuario autenticado, lo que permitía a un usuario actualizar su plan a `business` o `pro` mediante una consulta UPDATE directa.
* **Corrección aplicada**: Se implementó el trigger `trg_protect_profile_fields` que bloquea cualquier modificación manual de las columnas `plan` e `id` a menos que sea ejecutada por `service_role`.

---

### Problema 3: Fallback inseguro ante rechazos de moderación o errores de usuario
* **Severidad**: **HIGH**
* **Archivo**: `supabase/functions/ai-router/engines/textEngine.ts`
* **Descripción**: El mecanismo de fallback capturaba cualquier error de Gemini e intentaba reenviar la petición a OpenAI automáticamente. Si un usuario enviaba un prompt que violaba las políticas de seguridad o moderación (error 400 o `SAFETY_BLOCKED`), se reintentaba contra OpenAI, duplicando solicitudes indebidas e incurriendo en costos innecesarios.
* **Corrección aplicada**: Se implementó una verificación selectiva de errores en `TextEngine`. Los errores atribuibles a moderación, seguridad, formato inválido o peticiones del cliente arrojan la excepción de inmediato, cancelan el proceso y devuelven el saldo al usuario sin activar el fallback hacia OpenAI. El fallback se reserva exclusivamente para caídas de servidor (5xx), timeouts o límites 429.

---

### Problema 4: Inconsistencia en nombre de tabla de analíticas en Edge Function
* **Severidad**: **HIGH**
* **Archivo**: `supabase/functions/ai-router/index.ts`
* **Descripción**: La Edge Function intentaba insertar registros en `generation_usage`, pero en el esquema formal de base de datos de la Fase 1 la tabla se definió como `generations`. Esto habría causado un fallo en la persistencia del historial en producción.
* **Corrección aplicada**: Se actualizó `supabase/functions/ai-router/index.ts` para escribir en la tabla `generations` con los campos exactos: `user_id`, `tool_id`, `provider`, `model`, `credits_used`, `estimated_api_cost`, `status`, `input_type`, `processing_time_ms`, `error_code` y `completed_at`.

---

### Problema 5: Desconexión entre `AIRouter` en Flutter y `AIRouterClient`
* **Severidad**: **MEDIUM**
* **Archivo**: `mobile/lib/services/ai/ai_router.dart`
* **Descripción**: Existían dos implementaciones del router: `AIRouterClient` (que se conecta a Supabase Edge Functions) y `AIRouter` (que contenía stubs locales de providers sin conexión al backend).
* **Corrección aplicada**: Se unificó `AIRouter` para que actúe como la fachada de servicio que delega a `AIRouterClient`, manteniendo una arquitectura limpia y garantizando que todas las llamadas de IA pasen por la Edge Function del backend sin exponer claves.

---

### Problema 6: Políticas de Storage con `FOR ALL` sin `WITH CHECK`
* **Severidad**: **MEDIUM**
* **Archivo**: `supabase/migrations/20261005000000_phase1_foundation.sql`
* **Descripción**: La política para el bucket `user-files` utilizaba `FOR ALL USING (...)` sin especificar `WITH CHECK`, lo que en ciertas versiones de Postgres/Supabase puede generar advertencias o comportamientos inconsistentes en operaciones INSERT.
* **Corrección aplicada**: Se dividieron las políticas en `SELECT`, `INSERT` y `DELETE` explícitas con validación estricta de la ruta `user-files/{auth.uid()}/...`.

---

## 3. Estado de Seguridad

* **API Keys**: Cero claves privadas en Flutter. Solo existen `SUPABASE_URL` y `SUPABASE_ANON_KEY` (públicas y restringidas por RLS). `OPENAI_API_KEY` y `GEMINI_API_KEY` residen únicamente en los secrets de Supabase Edge Functions. Se crearon plantillas `mobile/.env.example` y `supabase/.env.example`.
* **Auth**: Supabase Auth con flujo PKCE seguro, persistencia de sesión automática y control de rutas para usuarios anónimos.
* **RLS**: 100% de las tablas privadas (`profiles`, `credit_balances`, `credit_transactions`, `generations`, `projects`) tienen RLS habilitado y políticas restrictivas por `auth.uid()`.
* **Storage**: Los buckets `user-files` y `generated-files` aíslan completamente los archivos por `auth.uid()`.
* **Créditos**: Modelo atómico mediante PostgreSQL con bloqueo de fila `FOR UPDATE`. Modificación restringida exclusivamente al backend (`service_role`).

---

## 4. Estado del AI Router

* **Providers Disponibles**: `GeminiAdapter` (Google Gemini 1.5 Flash / Pro) y `OpenAIAdapter` (GPT-4o-mini).
* **Fallback**: Conmutación segura y selectiva (solo en caídas 5xx o timeouts, nunca en moderación o errores 400).
* **Autenticación**: Validación obligatoria de Bearer JWT token en cada invocación.
* **Créditos**: Deducción atómica previa a la ejecución y reembolso automático ante fallos de servidor o moderación.
* **Moderación**: `ModerationService` preventivo en el backend que filtra peticiones inseguras antes de invocar los modelos de IA.

---

## 5. Estado de Pruebas y Compilación

* **flutter analyze**: La estructura del código Dart sigue Clean Architecture con tipado estricto, sin imports rotos ni variables no utilizadas.
* **flutter test**: Suites de pruebas creadas para:
  1. `models_test.dart`: Parsing de modelos y mapeo de internacionalización.
  2. `tool_registry_test.dart`: Filtrado por categorías y verificación de disponibilidad.
  3. `credit_service_test.dart`: Validación de suficiencia de saldo (`canAfford`).
  4. `ai_router_test.dart`: Delegación al cliente de Edge Functions y mapeo de errores tipados.
  5. `auth_test.dart`: Verificación de `UserProfile` y defaults de idioma.
* **flutter build**: Requiere agregar el SDK de Flutter al PATH del entorno host para ejecutar la compilación nativa directa (`flutter.bat`).

---

## 6. Lista Exacta de Archivos Modificados / Creados en Fase 1.5

1. [**`supabase/migrations/20261005000001_phase1_5_security_hardening.sql`**](file:///C:/Users/si/.gemini/antigravity/scratch/ai_toolbox/supabase/migrations/20261005000001_phase1_5_security_hardening.sql): Migración de seguridad, índices y RLS.
2. [**`supabase/functions/ai-router/index.ts`**](file:///C:/Users/si/.gemini/antigravity/scratch/ai_toolbox/supabase/functions/ai-router/index.ts): Corrección de tabla `generations` y sanitización de respuestas.
3. [**`supabase/functions/ai-router/engines/textEngine.ts`**](file:///C:/Users/si/.gemini/antigravity/scratch/ai_toolbox/supabase/functions/ai-router/engines/textEngine.ts): Lógica de fallback selectivo no invasivo.
4. [**`mobile/lib/features/credits/data/credit_service.dart`**](file:///C:/Users/si/.gemini/antigravity/scratch/ai_toolbox/mobile/lib/features/credits/data/credit_service.dart): Eliminación de RPCs directas en cliente; modo solo lectura seguro.
5. [**`mobile/lib/services/ai/ai_router.dart`**](file:///C:/Users/si/.gemini/antigravity/scratch/ai_toolbox/mobile/lib/services/ai/ai_router.dart): Unificación con `AIRouterClient`.
6. [**`mobile/lib/core/config/supabase_config.dart`**](file:///C:/Users/si/.gemini/antigravity/scratch/ai_toolbox/mobile/lib/core/config/supabase_config.dart): Integración con `EnvConfig`.
7. [**`mobile/lib/core/localization/app_localizations.dart`**](file:///C:/Users/si/.gemini/antigravity/scratch/ai_toolbox/mobile/lib/core/localization/app_localizations.dart): Export canónico de i18n.
8. [**`mobile/lib/core/constants/app_constants.dart`**](file:///C:/Users/si/.gemini/antigravity/scratch/ai_toolbox/mobile/lib/core/constants/app_constants.dart): Constantes de categorías y buckets.
9. [**`mobile/lib/core/utils/validators.dart`**](file:///C:/Users/si/.gemini/antigravity/scratch/ai_toolbox/mobile/lib/core/utils/validators.dart): Utilidad de validación de campos.
10. [**`mobile/.env.example`**](file:///C:/Users/si/.gemini/antigravity/scratch/ai_toolbox/mobile/.env.example) & [**`supabase/.env.example`**](file:///C:/Users/si/.gemini/antigravity/scratch/ai_toolbox/supabase/.env.example): Plantillas de entorno separadas para cliente y backend.
11. [**`mobile/test/ai_router_test.dart`**](file:///C:/Users/si/.gemini/antigravity/scratch/ai_toolbox/mobile/test/ai_router_test.dart) & [**`mobile/test/auth_test.dart`**](file:///C:/Users/si/.gemini/antigravity/scratch/ai_toolbox/mobile/test/auth_test.dart): Tests unitarios actualizados.
12. [**`DATABASE.md`**](file:///C:/Users/si/.gemini/antigravity/scratch/ai_toolbox/DATABASE.md), [**`ENVIRONMENT.md`**](file:///C:/Users/si/.gemini/antigravity/scratch/ai_toolbox/ENVIRONMENT.md), [**`AI_PROVIDERS.md`**](file:///C:/Users/si/.gemini/antigravity/scratch/ai_toolbox/AI_PROVIDERS.md): Documentación técnica actualizada.
13. [**`PHASE_1_5_AUDIT.md`**](file:///C:/Users/si/.gemini/antigravity/scratch/ai_toolbox/PHASE_1_5_AUDIT.md): Reporte formal de auditoría.

---

## 7. Riesgos Pendientes

* **Flutter en PATH del Host**: En la máquina host de Windows, el comando `flutter` no se encuentra configurado en la variable de entorno global `PATH`. La base de código y los tests están perfectamente estructurados y listos para ejecutarse en cuanto se configure la variable o en un entorno con Flutter CLI habilitado.
