# AI Toolbox — Arquitectura Base (Fase 1: Foundation)

Este repositorio contiene la base de arquitectura de **AI Toolbox**, diseñada de acuerdo con los principios del **Documento Maestro de Desarrollo**.

---

## 📁 Estructura del Proyecto

```
ai_toolbox/
├── mobile/                               # Aplicación Móvil (Flutter / Dart)
│   ├── assets/i18n/                      # Diccionarios de traducción
│   │   ├── es.json                       # Español
│   │   └── en.json                       # English
│   ├── lib/
│   │   ├── core/
│   │   │   ├── config/                   # Configuración Supabase (sin API keys de IA)
│   │   │   ├── i18n/                     # AppLocalizations dinámica
│   │   │   ├── network/                  # AIRouterClient (invoca Edge Functions)
│   │   │   └── theme/                    # AppTheme (Dark/Light, minimalista, botones grandes)
│   │   ├── features/
│   │   │   ├── auth/                     # Autenticación Supabase (Email, Google, Apple)
│   │   │   │   ├── domain/               # UserProfile con credit_balance y plan
│   │   │   │   ├── infrastructure/       # AuthService
│   │   │   │   └── presentation/         # LoginScreen
│   │   │   ├── credits/                  # Sistema de Créditos
│   │   │   │   └── domain/               # CreditTransaction (inmutable)
│   │   │   ├── home/                     # Pantalla Principal
│   │   │   │   └── presentation/         # HomeScreen (Categorías, buscador, credit badge)
│   │   │   └── tools/                    # Herramientas modulares dinámicas
│   │   │       ├── domain/               # ToolEntity (cargado desde Supabase)
│   │   │       └── infrastructure/       # ToolRepository
│   │   └── main.dart                     # Punto de entrada
│   ├── test/                             # Tests unitarios de modelos y balance
│   └── pubspec.yaml
│
└── supabase/                             # Backend y Base de Datos
    ├── config.toml                       # Configuración CLI Supabase
    ├── migrations/
    │   └── 20261005000000_phase1_foundation.sql # Schema PostgreSQL + RLS + RPC atómicas
    └── functions/
        ├── _shared/                      # CORS y tipos compartidos
        └── ai-router/                    # Enrutador Central de IA (Edge Function)
            ├── adapters/                 # GeminiAdapter, OpenAIAdapter (desacoplados)
            ├── engines/                  # TextEngine, ImageEngine, MarketingEngine
            ├── moderation.ts             # ModerationService con auto-reembolso
            └── index.ts                  # Endpoint seguro con deducción atómica de créditos
```

---

## 🔒 Cumplimiento de Principios del Documento Maestro

1. **Sin API Keys en la App Móvil**: Flutter solo se conecta a Supabase con su `anonKey`. Las credenciales de Google Gemini y OpenAI residen únicamente en los secrets de las Edge Functions de Supabase.
2. **AI Router Backend**: La app solo llama a la función `ai-router`. El backend evalúa la herramienta, valida los créditos, ejecuta moderación y selecciona el modelo más económico para la tarea.
3. **Cobro Atómico de Créditos**: Implementado mediante la función PL/pgSQL `deduct_credits(user_id, amount, tool, description)` con bloqueo de fila `FOR UPDATE` para evitar condiciones de carrera.
4. **Reembolso Automático**: Si el proveedor de IA falla o el contenido es rechazado en moderación, la función `refund_credits` devuelve los créditos de inmediato y registra el incidente en `generation_usage`.
5. **Catálogo Dinámico de Herramientas**: La tabla `public.tools` permite habilitar, deshabilitar (`enabled = false`), ajustar costos en créditos o marcar herramientas en `beta` sin tener que republicar la aplicación en Google Play ni App Store.
6. **Internacionalización**: Soportada desde el día uno mediante `es.json` y `en.json` cargados por `AppLocalizations`.
7. **Diseño**: Minimalista, moderno, con modo oscuro de alto contraste y tarjetas organizadas por categorías: CREAR, MEJORAR, VENDER, DOCUMENTOS, AUDIO y ASISTENTE.
