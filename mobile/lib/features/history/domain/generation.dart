class Generation {
  final String id;
  final String userId;
  final String? toolId;
  final String? provider;
  final String? model;
  final int creditsUsed;
  final double estimatedApiCost;
  final String status; // 'processing', 'completed', 'failed'
  final String? inputType;
  final String? resultUrl;
  final String? storagePath;
  final int? processingTimeMs;
  final String? errorCode;
  final DateTime createdAt;
  final DateTime? completedAt;

  const Generation({
    required this.id,
    required this.userId,
    this.toolId,
    this.provider,
    this.model,
    required this.creditsUsed,
    required this.estimatedApiCost,
    required this.status,
    this.inputType,
    this.resultUrl,
    this.storagePath,
    this.processingTimeMs,
    this.errorCode,
    required this.createdAt,
    this.completedAt,
  });

  factory Generation.fromMap(Map<String, dynamic> map) {
    return Generation(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      toolId: map['tool_id'],
      provider: map['provider'],
      model: map['model'],
      creditsUsed: map['credits_used'] ?? 0,
      estimatedApiCost: (map['estimated_api_cost'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'completed',
      inputType: map['input_type'],
      resultUrl: map['result_url'],
      storagePath: map['storage_path'],
      processingTimeMs: map['processing_time_ms'],
      errorCode: map['error_code'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
      completedAt: map['completed_at'] != null ? DateTime.parse(map['completed_at']) : null,
    );
  }
}
