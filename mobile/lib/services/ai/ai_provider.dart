import '../../core/errors/app_errors.dart';

class AIRequest {
  final String toolId;
  final Map<String, dynamic> input;
  final Map<String, dynamic> parameters;
  final String? preferredProvider;
  final String? preferredModel;

  const AIRequest({
    required this.toolId,
    required this.input,
    this.parameters = const {},
    this.preferredProvider,
    this.preferredModel,
  });
}

class AIResponse {
  final bool success;
  final String toolId;
  final dynamic result;
  final String provider;
  final String model;
  final int processingTimeMs;
  final double estimatedCostUsd;

  const AIResponse({
    required this.success,
    required this.toolId,
    required this.result,
    required this.provider,
    required this.model,
    required this.processingTimeMs,
    this.estimatedCostUsd = 0.0,
  });
}

abstract class AIProvider {
  String get providerName;
  bool isAvailable();
  Future<AIResponse> execute(AIRequest request);
}
