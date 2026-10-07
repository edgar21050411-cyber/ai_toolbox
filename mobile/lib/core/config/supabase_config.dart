import 'package:supabase_flutter/supabase_flutter.dart';
import 'environment.dart';

class SupabaseConfig {
  static Future<void> initialize() async {
    final String url = EnvConfig.current.supabaseUrl;
    final String anonKey = EnvConfig.current.supabaseAnonKey;

    if (url.isEmpty || anonKey.isEmpty) {
      throw StateError(
        'SupabaseConfig: SUPABASE_URL y SUPABASE_ANON_KEY deben estar definidos y no pueden ser nulos ni vacios.',
      );
    }

    await Supabase.initialize(
      url: url,
      publishableKey: anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
