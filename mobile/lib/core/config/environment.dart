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

    const rawUrl = String.fromEnvironment('SUPABASE_URL');
    const rawKey = String.fromEnvironment('SUPABASE_ANON_KEY');

    final cleanUrl = rawUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final cleanKey = rawKey.trim();

    if (cleanUrl.isEmpty || cleanKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL y SUPABASE_ANON_KEY deben ser provistos via --dart-define. '
        'El uso de placeholders ha sido eliminado por completo.',
      );
    }

    // Construccion dinamica de apiBaseUrl a partir de la URL real de Supabase
    final dynamicApiBaseUrl = '$cleanUrl/functions/v1';

    switch (effectiveEnv) {
      case AppEnvironment.production:
        current = EnvConfig(
          environment: AppEnvironment.production,
          supabaseUrl: cleanUrl,
          supabaseAnonKey: cleanKey,
          apiBaseUrl: dynamicApiBaseUrl,
          enableLogging: false,
        );
        break;

      case AppEnvironment.staging:
        current = EnvConfig(
          environment: AppEnvironment.staging,
          supabaseUrl: cleanUrl,
          supabaseAnonKey: cleanKey,
          apiBaseUrl: dynamicApiBaseUrl,
          enableLogging: true,
        );
        break;

      case AppEnvironment.development:
        current = EnvConfig(
          environment: AppEnvironment.development,
          supabaseUrl: cleanUrl,
          supabaseAnonKey: cleanKey,
          apiBaseUrl: dynamicApiBaseUrl,
          enableLogging: true,
        );
        break;
    }
  }
}
