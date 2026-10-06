import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/project.dart';
import '../../../services/logging/logger_service.dart';

class ProjectsRepository extends ChangeNotifier {
  final SupabaseClient? _client;
  SupabaseClient get _supabase => _client ?? Supabase.instance.client;
  final LoggerService _logger = LoggerService();

  List<Project> _projects = [];
  bool _isLoading = false;

  ProjectsRepository({SupabaseClient? client})
      : _client = client;

  List<Project> get projects => List.unmodifiable(_projects);
  bool get isLoading => _isLoading;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  Future<void> fetchProjects() async {
    final uid = _currentUserId;
    if (uid == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final List<dynamic> data = await _supabase
          .from('projects')
          .select()
          .eq('user_id', uid)
          .order('updated_at', ascending: false);

      _projects = data.map((item) => Project.fromMap(item)).toList();
    } catch (e, stack) {
      _logger.error('Error fetching projects', error: e, stackTrace: stack);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createProject(String name, [String? description]) async {
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      await _supabase.from('projects').insert({
        'user_id': uid,
        'name': name,
        'description': description,
      });
      await fetchProjects();
    } catch (e, stack) {
      _logger.error('Error creating project', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> updateProjectName(String projectId, String newName) async {
    try {
      await _supabase.from('projects').update({
        'name': newName,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', projectId);
      await fetchProjects();
    } catch (e, stack) {
      _logger.error('Error updating project', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> deleteProject(String projectId) async {
    try {
      await _supabase.from('projects').delete().eq('id', projectId);
      _projects.removeWhere((p) => p.id == projectId);
      notifyListeners();
    } catch (e, stack) {
      _logger.error('Error deleting project', error: e, stackTrace: stack);
      rethrow;
    }
  }
}
