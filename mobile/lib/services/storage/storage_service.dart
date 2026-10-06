import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/app_errors.dart';
import '../logging/logger_service.dart';

class StorageService {
  final SupabaseClient? _client;
  SupabaseClient get _supabase => _client ?? Supabase.instance.client;
  final LoggerService _logger = LoggerService();

  StorageService({SupabaseClient? client})
      : _client = client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  Future<String> uploadAvatar(Uint8List bytes, String fileExtension) async {
    final uid = _currentUserId;
    if (uid == null) throw const AuthenticationError();

    final path = '$uid/avatar.$fileExtension';
    try {
      await _supabase.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      final publicUrl = _supabase.storage.from('avatars').getPublicUrl(path);
      return publicUrl;
    } catch (e, stack) {
      _logger.error('Failed to upload avatar', error: e, stackTrace: stack);
      throw StorageError(technicalDetails: e.toString());
    }
  }

  Future<String> uploadUserFile({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw const AuthenticationError();

    final path = '$uid/$fileName';
    try {
      await _supabase.storage.from('user-files').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      return path;
    } catch (e, stack) {
      _logger.error('Failed to upload user file', error: e, stackTrace: stack);
      throw StorageError(technicalDetails: e.toString());
    }
  }

  Future<String> getSignedUrl(String bucket, String path, {int expiresIn = 3600}) async {
    try {
      return await _supabase.storage.from(bucket).createSignedUrl(path, expiresIn);
    } catch (e, stack) {
      _logger.error('Failed to generate signed url', error: e, stackTrace: stack);
      throw StorageError(technicalDetails: e.toString());
    }
  }
}
