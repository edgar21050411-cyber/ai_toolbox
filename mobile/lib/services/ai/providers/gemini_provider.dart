import '../ai_provider.dart';
import '../../../core/errors/app_errors.dart';

class GeminiProvider implements AIProvider {
  @override
  String get providerName => 'google_gemini';

  @override
  bool isAvailable() => true;

  @override
  Future<AIResponse> execute(AIRequest request) async {
    // FASE 1: Preparación de interfaz sin llamadas reales ni API keys
    throw const AIProviderError(
      provider: 'google_gemini',
      message: 'GeminiProvider: En Fase 1 las llamadas reales de IA están delegadas a la infraestructura del backend.',
    );
  }
}
