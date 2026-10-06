import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  static const List<String> _sensitiveKeys = [
    'password',
    'token',
    'secret',
    'api_key',
    'authorization',
    'bearer',
  ];

  void log({
    required LogLevel level,
    required String message,
    String? tool,
    String? provider,
    String? status,
    int? durationMs,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final sanitizedMsg = _sanitize(message);
    final timestamp = DateTime.now().toIso8601String();

    final buffer = StringBuffer('[$timestamp] [${level.name.toUpperCase()}] $sanitizedMsg');

    if (tool != null) buffer.write(' | Tool: $tool');
    if (provider != null) buffer.write(' | Provider: $provider');
    if (status != null) buffer.write(' | Status: $status');
    if (durationMs != null) buffer.write(' | Duration: ${durationMs}ms');

    if (kDebugMode) {
      debugPrint(buffer.toString());
      if (error != null) {
        debugPrint('  Error details: $error');
      }
    }
  }

  void info(String message, {String? tool, String? provider}) {
    log(level: LogLevel.info, message: message, tool: tool, provider: provider);
  }

  void warning(String message, {String? tool, String? provider}) {
    log(level: LogLevel.warning, message: message, tool: tool, provider: provider);
  }

  void error(String message, {String? tool, String? provider, Object? error, StackTrace? stackTrace}) {
    log(
      level: LogLevel.error,
      message: message,
      tool: tool,
      provider: provider,
      error: error,
      stackTrace: stackTrace,
    );
  }

  String _sanitize(String input) {
    var result = input;
    for (final sensitive in _sensitiveKeys) {
      final reg = RegExp('$sensitive\\s*[:=]\\s*[^,\\s}]+', caseSensitive: false);
      result = result.replaceAll(reg, '$sensitive=[REDACTED]');
    }
    return result;
  }
}
