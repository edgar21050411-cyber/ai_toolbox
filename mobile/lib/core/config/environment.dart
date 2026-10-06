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

  static void initialize({AppEnvironment env = AppEnvironment.development}) {
    switch (env) {
      case AppEnvironment.development:
        current = const EnvConfig(
          environment: AppEnvironment.development,
          supabaseUrl: String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://dev.supabase.co'),
          supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'dev-anon-key-placeholder'),
          apiBaseUrl: 'https://dev.supabase.co/functions/v1',
          enableLogging: true,
        );
        break;
      case AppEnvironment.staging:
        current = const EnvConfig(
          environment: AppEnvironment.staging,
          supabaseUrl: String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://staging.supabase.co'),
          supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'staging-anon-key-placeholder'),
          apiBaseUrl: 'https://staging.supabase.co/functions/v1',
          enableLogging: true,
        );
        break;
      case AppEnvironment.production:
        current = const EnvConfig(
          environment: AppEnvironment.production,
          supabaseUrl: String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://app.supabase.co'),
          supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'prod-anon-key-placeholder'),
          apiBaseUrl: 'https://app.supabase.co/functions/v1',
          enableLogging: false,
        );
        break;
    }
  }
}
