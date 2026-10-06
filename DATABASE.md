# AI TOOLBOX — ESQUEMA DE BASE DE DATOS Y RLS

## 1. Tablas Principales

| Tabla | Descripción | RLS |
|---|---|---|
| `profiles` | Perfil de usuario vinculado a `auth.users`, idioma y plan | Lectura/Escritura propia (Trigger protege `plan` e `id`) |
| `credit_balances` | Saldo atómico de créditos | Solo lectura (Modificación exclusiva vía RPC `service_role`) |
| `credit_transactions` | Historial inmutable de compras, consumo y reembolsos | Solo lectura propia |
| `tools` | Catálogo de herramientas configurable desde backend | Lectura pública si `enabled=true` |
| `generations` | Registro de ejecuciones, costos de API, URLs y `storage_path` | Lectura propia (`auth.uid() = user_id`) |
| `generation_usage` | Métricas de uso y telemetría de backend | Lectura propia (`auth.uid() = user_id`) |
| `projects` | Workspaces de proyectos creados por el usuario | CRUD completo propio |

## 2. Funciones RPC Transaccionales Atómicas (Protegidas)
Todas las funciones RPC de modificación de saldo tienen `REVOKE EXECUTE FROM PUBLIC, anon, authenticated` y son invocables **únicamente** por el backend (`service_role`):
* **`deduct_credits(p_user_id, p_amount, p_tool_id, p_description)`**: Descuenta créditos bloqueando la fila del usuario (`FOR UPDATE`) para evitar condiciones de carrera en ejecuciones concurrentes.
* **`refund_credits(p_user_id, p_amount, p_tool_id, p_reason)`**: Reembolsa saldo inmediatamente si la IA o la moderación fallan.
* **`add_credits(p_user_id, p_amount, p_type, p_description)`**: Añade créditos por compras de paquetes o suscripciones.

## 3. Storage Buckets y Políticas de Acceso
* `avatars`: Fotos de perfil públicas de usuarios.
* `user-files`: Archivos privados subidos por el usuario (`user-files/{user_id}/...`) con políticas `SELECT`, `INSERT`, `DELETE` para `auth.uid()`. Tamaño máximo: 15MB.
* `generated-files`: Archivos privados generados por los motores de IA (`generated-files/{user_id}/...`).
  - Escritura: Exclusiva del backend (`service_role` en Supabase Edge Functions).
  - Lectura: Directa con URL firmada (`createSignedUrl`) o con política RLS `SELECT` restringida a `(storage.foldername(name))[1] = auth.uid()::text`.
  - Eliminación: El usuario puede eliminar sus propios archivos generados.
  - Límite de archivo: 15MB. Tipos permitidos: `image/png`, `image/jpeg`, `image/webp`.

## 4. Migraciones
1. `20261005000000_phase1_foundation.sql`: Estructura inicial, tablas, triggers y seed data.
2. `20261005000001_phase1_5_security_hardening.sql`: Endurecimiento de seguridad en RPCs, trigger contra escalada de privilegios en `profiles`, políticas de Storage e índices de base de datos.
3. `20261005000002_phase2_tools_seed.sql`: Semillero definitivo con las 10 herramientas oficiales de la Fase 2, categorías (text, marketing, images) y costos de créditos en backend.
4. `20261005000003_phase2_6_storage_and_image_processing.sql`: Creación formal de la tabla `generations` con columnas `storage_path`, `result_url` y `metadata`, configuración de los buckets `generated-files` y `user-files` con límites de 15MB y políticas RLS completas.
