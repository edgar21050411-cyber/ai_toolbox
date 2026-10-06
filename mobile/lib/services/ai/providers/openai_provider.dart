import '../ai_provider.dart';
import '../../../core/errors/app_errors.dart';

class OpenAIProvider implements AIProvider {
  @override
  String get providerName => 'openai';

  @override
  bool isAvailable() => true;

  @override
  Future<AIResponse> execute(AIRequest request) async {
    throw const AIProviderError(
      provider: 'openai',
      message: 'OpenAIProvider: En Fase 1 las llamadas reales de IA están delegadas a la infraestructura del backend.',
    );
  }
}

class AudioProvider implements AIProvider {
  @override
  String get providerName => 'audio_provider';

  @override
  bool isAvailable() => true;

  @override
  Future<AIResponse> execute(AIRequest request) async {
    throw const AIProviderError(
      provider: 'audio_provider',
      message: 'AudioProvider: Reservado para Fase 5.',
    );
  }
}
