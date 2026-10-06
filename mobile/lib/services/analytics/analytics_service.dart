import 'package:flutter/foundation.dart';
import '../logging/logger_service.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final LoggerService _logger = LoggerService();

  Future<void> logEvent(String name, [Map<String, dynamic>? parameters]) async {
    _logger.info('Analytics Event: $name', tool: parameters?['tool_id']);
    if (kDebugMode) {
      debugPrint('[ANALYTICS] Event: $name | Params: $parameters');
    }
  }

  Future<void> logAppOpened() => logEvent('app_opened');
  Future<void> logLoginCompleted({required String method}) => logEvent('login_completed', {'method': method});
  Future<void> logSignUpCompleted({required String method}) => logEvent('signup_completed', {'method': method});
  Future<void> logToolViewed({required String toolId, required String category}) =>
      logEvent('tool_viewed', {'tool_id': toolId, 'category': category});
  Future<void> logToolStarted({required String toolId, required int creditCost}) =>
      logEvent('tool_started', {'tool_id': toolId, 'credit_cost': creditCost});
  Future<void> logToolCompleted({required String toolId, required int processingTimeMs}) =>
      logEvent('tool_completed', {'tool_id': toolId, 'duration_ms': processingTimeMs});
  Future<void> logToolFailed({required String toolId, required String error}) =>
      logEvent('tool_failed', {'tool_id': toolId, 'error': error});
  Future<void> logCreditsUsed({required int amount, required String toolId}) =>
      logEvent('credits_used', {'amount': amount, 'tool_id': toolId});
  Future<void> logProjectCreated({required String projectId}) =>
      logEvent('project_created', {'project_id': projectId});
  Future<void> logGenerationSaved({required String generationId}) =>
      logEvent('generation_saved', {'generation_id': generationId});
  Future<void> logSubscriptionStarted({required String planId}) =>
      logEvent('subscription_started', {'plan_id': planId});
}
