# AI TOOLBOX — CONFIGURACIÓN DE ENTORNOS

## 1. Entornos Soportados
1. **Development (`development`)**: Conectado a la instancia de desarrollo de Supabase con logging activo en consola.
2. **Staging (`staging`)**: Entorno de homologación y QA para pruebas previas a producción.
3. **Production (`production`)**: Entorno productivo con logging estricto y telemetría de producción.

## 2. Variables del Cliente (Flutter Móvil)
Archivo plantilla: `mobile/.env.example`
* `SUPABASE_URL`: URL pública del proyecto Supabase.
* `SUPABASE_ANON_KEY`: Anon / public key de Supabase (restringida por RLS).
* `ENVIRONMENT`: `development` | `staging` | `production`.

Inyección en Flutter:
```bash
flutter run \
  --dart-define=ENVIRONMENT=development \
  --dart-define=SUPABASE_URL=https://xyzcompany.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
```

## 3. Secretos del Backend (Supabase Edge Functions)
Archivo plantilla: `supabase/.env.example`
Residen **exclusivamente** en los secrets de Supabase:
* `SUPABASE_SERVICE_ROLE_KEY`: Clave de servicio para operaciones administrativas (RPCs de créditos, subida de archivos generados).
* `GEMINI_API_KEY`: Clave de Google Gemini.
* `OPENAI_API_KEY`: Clave de OpenAI.

Configuración mediante Supabase CLI:
```bash
supabase secrets set GEMINI_API_KEY=AIzaSy... OPENAI_API_KEY=sk-...
```

> **REGLA DE SEGURIDAD ABSOLUTA**: Ningún secreto de backend (`SERVICE_ROLE_KEY`, `GEMINI_API_KEY`, `OPENAI_API_KEY`) debe ser incluido o referenciado en el código de Flutter ni en archivos `.env` distribuidos con el binario de la app móvil.
