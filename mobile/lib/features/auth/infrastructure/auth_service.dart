import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/user_profile.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabase;
  UserProfile? _currentProfile;
  bool _isLoading = false;

  AuthService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client {
    _initAuthListener();
  }

  UserProfile? get currentProfile => _currentProfile;
  bool get isAuthenticated => _supabase.auth.currentUser != null;
  bool get isLoading => _isLoading;

  void _initAuthListener() {
    _supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.userUpdated) {
        fetchProfile();
      } else if (event == AuthChangeEvent.signedOut) {
        _currentProfile = null;
        notifyListeners();
      }
    });

    if (isAuthenticated) {
      fetchProfile();
    }
  }

  Future<void> fetchProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data != null) {
        _currentProfile = UserProfile.fromMap(data);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error fetching user profile: $e");
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    _setLoading(true);
    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
      await fetchProfile();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signUpWithEmail(String email, String password) async {
    _setLoading(true);
    try {
      await _supabase.auth.signUp(email: email, password: password);
      await fetchProfile();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signInWithGoogle() async {
    _setLoading(true);
    try {
      await _supabase.auth.signInWithOAuth(OAuthProvider.google);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signInWithApple() async {
    _setLoading(true);
    try {
      await _supabase.auth.signInWithOAuth(OAuthProvider.apple);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _supabase.auth.signOut();
      _currentProfile = null;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
