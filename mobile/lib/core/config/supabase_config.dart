import 'package:supabase_flutter/supabase_flutter.dart';
import 'environment.dart';

class SupabaseConfig {
  static const String _defaultUrl = 'https://xyzcompany.supabase.co';
  static const String _defaultKey = 'public-anon-key-placeholder';

  static Future<void> initialize() async {
    final String url = EnvConfig.current.supabaseUrl.isNotEmpty 
        ? EnvConfig.current.supabaseUrl 
        : const String.fromEnvironment('SUPABASE_URL', defaultValue: _defaultUrl);

    final String anonKey = EnvConfig.current.supabaseAnonKey.isNotEmpty
        ? EnvConfig.current.supabaseAnonKey
        : const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: _defaultKey);

    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
