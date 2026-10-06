import 'package:supabase_flutter/supabase_flutter.dart';

class AIRouterResponse {
  final bool success;
  final String tool;
  final dynamic result;
  final int creditsUsed;
  final int creditsRemaining;
  final int processingTimeMs;
  final String provider;
  final String model;
  final String? error;

  AIRouterResponse({
    required this.success,
    required this.tool,
    required this.result,
    required this.creditsUsed,
    required this.creditsRemaining,
    required this.processingTimeMs,
    required this.provider,
    required this.model,
    this.error,
  });

  factory AIRouterResponse.fromJson(Map<String, dynamic> json) {
    return AIRouterResponse(
      success: json['success'] ?? false,
      tool: json['tool'] ?? '',
      result: json['result'],
      creditsUsed: json['credits_used'] ?? 0,
      creditsRemaining: json['credits_remaining'] ?? 0,
      processingTimeMs: json['processing_time_ms'] ?? 0,
      provider: json['provider'] ?? '',
      model: json['model'] ?? '',
      error: json['error'],
    );
  }
}

class AIRouterClient {
  final SupabaseClient _supabase;

  AIRouterClient({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  /**
   * Invoca de manera segura la Edge Function del backend sin exponer API keys de IA.
   */
  Future<AIRouterResponse> executeTool({
    required String toolId,
    required Map<String, dynamic> input,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'ai-router',
        body: {
          'tool': toolId,
          'input': input,
          'parameters': parameters ?? {},
        },
      );

      final data = response.data;
      if (response.status != 200) {
        final errorMsg = data is Map ? (data['message'] ?? data['error'] ?? 'Error desconocido') : 'Error de servidor';
        throw Exception(errorMsg);
      }

      if (data is Map<String, dynamic>) {
        return AIRouterResponse.fromJson(data);
      } else {
        throw Exception('Respuesta inesperada del backend');
      }
    } catch (e) {
      rethrow;
    }
  }
}
