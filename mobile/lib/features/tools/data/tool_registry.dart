import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/tool_entity.dart';
import '../../../services/logging/logger_service.dart';

class ToolRegistry extends ChangeNotifier {
  final SupabaseClient _supabase;
  final LoggerService _logger = LoggerService();

  final Map<String, ToolEntity> _toolsBySlug = {};
  final List<ToolEntity> _toolsList = [];
  bool _isLoading = false;

  ToolRegistry({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  List<ToolEntity> get allTools => List.unmodifiable(_toolsList);
  bool get isLoading => _isLoading;

  Future<void> fetchTools() async {
    _isLoading = true;
    notifyListeners();

    try {
      final List<dynamic> response = await _supabase
          .from('tools')
          .select()
          .order('sort_order', ascending: true);

      _toolsList.clear();
      _toolsBySlug.clear();

      for (final item in response) {
        final tool = ToolEntity.fromMap(Map<String, dynamic>.from(item));
        _toolsList.add(tool);
        _toolsBySlug[tool.slug] = tool;
        _toolsBySlug[tool.id] = tool; // Soporte tanto por slug como por id
      }

      _logger.info('Loaded ${_toolsList.length} tools into ToolRegistry');
    } catch (e, stack) {
      _logger.error('Failed to load tools catalog from backend', error: e, stackTrace: stack);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  ToolEntity? getTool(String slugOrId) {
    return _toolsBySlug[slugOrId];
  }

  List<ToolEntity> getEnabledTools() {
    return _toolsList.where((t) => t.enabled).toList();
  }

  List<ToolEntity> getToolsByCategory(String category) {
    return _toolsList.where((t) => t.category == category && t.enabled).toList();
  }

  bool isToolAvailable(String slugOrId) {
    final tool = getTool(slugOrId);
    return tool != null && tool.enabled;
  }

  int getCreditCost(String slugOrId) {
    final tool = getTool(slugOrId);
    return tool?.creditCost ?? 1;
  }
}
