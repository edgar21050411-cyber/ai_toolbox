enum AppEnvironment {
  development,
  staging,
  production,
}

class EnvConfig {
  final AppEnvironment environment;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String apiBaseUrl;
  final bool enableLogging;

  const EnvConfig({
    required this.environment,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.apiBaseUrl,
    this.enableLogging = true,
  });

  static late EnvConfig current;

  static void initialize({AppEnvironment? env}) {
    const envDefinedStr = String.fromEnvironment('ENVIRONMENT');
    final AppEnvironment effectiveEnv;
    if (envDefinedStr.isNotEmpty) {
      final normalized = envDefinedStr.toLowerCase();
      if (normalized == 'production' || normalized == 'prod') {
        effectiveEnv = AppEnvironment.production;
      } else if (normalized == 'staging' || normalized == 'stage') {
        effectiveEnv = AppEnvironment.staging;
      } else {
        effectiveEnv = AppEnvironment.development;
      }
    } else {
      effectiveEnv = env ?? AppEnvironment.development;
    }

    const envDefinedUrl = String.fromEnvironment('SUPABASE_URL');
    const envDefinedKey = String.fromEnvironment('SUPABASE_ANON_KEY');

    switch (effectiveEnv) {
      case AppEnvironment.production:
        if (envDefinedUrl.isEmpty || envDefinedKey.isEmpty) {
          throw StateError(
            'Produccion requiere configurar SUPABASE_URL y SUPABASE_ANON_KEY reales via --dart-define. Placeholders no permitidos.',
          );
        }
        current = EnvConfig(
          environment: AppEnvironment.production,
          supabaseUrl: envDefinedUrl,
          supabaseAnonKey: envDefinedKey,
          apiBaseUrl: '$envDefinedUrl/functions/v1',
          enableLogging: false,
        );
        break;

      case AppEnvironment.staging:
        final url = envDefinedUrl.isNotEmpty ? envDefinedUrl : 'https://staging.supabase.co';
        final key = envDefinedKey.isNotEmpty ? envDefinedKey : 'staging-anon-key';
        current = EnvConfig(
          environment: AppEnvironment.staging,
          supabaseUrl: url,
          supabaseAnonKey: key,
          apiBaseUrl: '$url/functions/v1',
          enableLogging: true,
        );
        break;

      case AppEnvironment.development:
        final url = envDefinedUrl.isNotEmpty ? envDefinedUrl : 'https://dev.supabase.co';
        final key = envDefinedKey.isNotEmpty ? envDefinedKey : 'dev-anon-key';
        current = EnvConfig(
          environment: AppEnvironment.development,
          supabaseUrl: url,
          supabaseAnonKey: key,
          apiBaseUrl: '$url/functions/v1',
          enableLogging: true,
        );
        break;
    }
  }
}
