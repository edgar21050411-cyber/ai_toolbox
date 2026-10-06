# AI TOOLBOX — DOCUMENTO DE ARQUITECTURA

## 1. Principios de Diseño
La arquitectura de **AI Toolbox** sigue los principios de **Clean Architecture** desacoplando completamente la aplicación móvil Flutter de los proveedores de inteligencia artificial.

```
APP FLUTTER (Móvil)
  ├── Presentation (Screens: Home, ToolScreen, History, Projects, Profile)
  ├── Domain (Entities: ToolEntity, UserProfile, CreditTransaction, Generation, Project)
  ├── Data (Repositories: ToolRegistry, CreditService, HistoryRepository, ProjectsRepository)
  └── Services (AIRouterClient, StorageService, AnalyticsService, LoggerService)
        ↓ (HTTPS con Bearer JWT — Sin API keys en el dispositivo móvil)
SUPABASE EDGE FUNCTIONS (ai-router)
  ├── Validación de Usuario y Permisos
  ├── Determinación de Costo (public.tools)
  ├── Deducción Atómica de Créditos (RPC deduct_credits con FOR UPDATE)
  ├── ModerationService (Filtro preventivo de seguridad)
  ├── Enrutamiento por Motor
  │      ├── TextEngine (rewrite_text, translate_text, summarize_text, create_ad, social_post, product_description)
  │      └── ImageEngine (generate_image, improve_image, remove_background, change_background)
  ├── Adaptadores de Proveedor (GeminiAdapter con fallback selectivo a OpenAIAdapter / Imagen)
  └── Persistencia de Auditoría
         ↓ (Éxito: Registro en public.generations con tokens, tiempo y costo USD)
         ↓ (Fallo: Reembolso automático mediante RPC refund_credits)
SUPABASE POSTGRESQL & STORAGE
  ├── profiles (auth.users)
  ├── credit_balances (Saldo atómico seguro)
  ├── credit_transactions (Historial inmutable)
  ├── tools (Catálogo dinámico de herramientas)
  ├── generations (Historial de generaciones)
  ├── projects (Workspaces de usuario)
  └── Buckets de Storage (avatars, user-files, generated-files con RLS estricto)
```

## 2. Capas del Sistema
* **Core**: Configuraciones de entorno (`development`, `staging`, `production`), tokens de diseño (`AppTheme`, `AppColors`, `AppTypography`, `AppSpacing`, `AppRadius`), internacionalización reactiva (`es.json`, `en.json`) y jerarquía de errores tipados.
* **Features**: Módulos independientes desacoplados (`auth`, `home`, `credits`, `tools`, `history`, `projects`, `profile`).
* **Services**: Abstracción de enrutamiento de IA mediante `AIRouterClient`, storage seguro y telemetría analítica.
* **Seguridad (RLS)**: Row Level Security en el 100% de las tablas privadas y buckets de almacenamiento con protección de funciones RPC exclusivas para `service_role`.
