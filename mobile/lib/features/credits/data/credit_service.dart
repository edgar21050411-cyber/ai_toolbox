import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_errors.dart';
import '../../../services/logging/logger_service.dart';

class CreditService extends ChangeNotifier {
  final SupabaseClient _supabase;
  final LoggerService _logger = LoggerService();

  int _cachedBalance = 0;
  bool _isLoading = false;

  CreditService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  int get balance => _cachedBalance;
  bool get isLoading => _isLoading;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /**
   * Obtiene el saldo actual del usuario desde credit_balances gobernado por RLS.
   */
  Future<int> getBalance() async {
    final uid = _currentUserId;
    if (uid == null) throw const AuthenticationError();

    _isLoading = true;
    notifyListeners();

    try {
      final data = await _supabase
          .from('credit_balances')
          .select('balance')
          .eq('user_id', uid)
          .maybeSingle();

      _cachedBalance = data != null ? (data['balance'] as int? ?? 0) : 0;
      return _cachedBalance;
    } catch (e, stack) {
      _logger.error('Error fetching credit balance', error: e, stackTrace: stack);
      throw NetworkError(technicalDetails: e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /**
   * Verifica en la UI si el usuario cuenta con saldo suficiente antes de iniciar.
   * La deducciÃ³n real y atÃ³mica la ejecuta el backend en el AI Router.
   */
  bool canAfford(int cost) {
    return _cachedBalance >= cost;
  }

  /**
   * Actualiza el saldo en memoria cuando el backend responde con un nuevo balance.
   */
  void updateBalance(int newBalance) {
    _cachedBalance = newBalance;
    _logger.info('Credit balance updated in client: $_cachedBalance');
    notifyListeners();
  }
}
