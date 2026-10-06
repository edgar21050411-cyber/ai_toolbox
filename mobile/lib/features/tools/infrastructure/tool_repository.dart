import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/tool_entity.dart';

class ToolRepository extends ChangeNotifier {
  final SupabaseClient _supabase;
  List<ToolEntity> _tools = [];
  bool _isLoading = false;

  ToolRepository({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client {
    fetchTools();
  }

  List<ToolEntity> get tools => _tools;
  bool get isLoading => _isLoading;

  List<ToolEntity> getToolsByCategory(String category) {
    return _tools.where((t) => t.category == category && t.enabled).toList();
  }

  List<ToolEntity> getMostUsedTools() {
    // Para el MVP ordenamos por sort_order inicial
    return _tools.where((t) => t.enabled).take(4).toList();
  }

  Future<void> fetchTools() async {
    _isLoading = true;
    notifyListeners();

    try {
      final List<dynamic> data = await _supabase
          .from('tools')
          .select()
          .eq('enabled', true)
          .order('sort_order', ascending: true);

      _tools = data.map((item) => ToolEntity.fromMap(item)).toList();
    } catch (e) {
      debugPrint("Error fetching tools catalog from Supabase: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
