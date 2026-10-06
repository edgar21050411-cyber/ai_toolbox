import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/generation.dart';
import '../../../services/logging/logger_service.dart';

class HistoryRepository extends ChangeNotifier {
  final SupabaseClient? _client;
  SupabaseClient get _supabase => _client ?? Supabase.instance.client;
  final LoggerService _logger = LoggerService();

  List<Generation> _generations = [];
  bool _isLoading = false;

  HistoryRepository({SupabaseClient? client})
      : _client = client;

  List<Generation> get generations => List.unmodifiable(_generations);
  bool get isLoading => _isLoading;

  Future<void> fetchHistory() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final List<dynamic> data = await _supabase
          .from('generations')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false);

      _generations = data.map((item) => Generation.fromMap(item)).toList();
    } catch (e, stack) {
      _logger.error('Error fetching history', error: e, stackTrace: stack);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
