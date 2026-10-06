import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../data/projects_repository.dart';
import '../../domain/project.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProjectsRepository>().fetchProjects();
    });
  }

  void _showCreateDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final i18n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: Text(i18n?.translate('projects.create') ?? 'Nuevo Proyecto', style: AppTypography.heading2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: i18n?.translate('projects.name_label') ?? 'Nombre del proyecto',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: descCtrl,
              decoration: InputDecoration(
                labelText: i18n?.translate('projects.desc_label') ?? 'Descripción opcional',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(i18n?.translate('common.cancel') ?? 'Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                context.read<ProjectsRepository>().createProject(nameCtrl.text.trim(), descCtrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: Text(i18n?.translate('common.save') ?? 'Guardar'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, Project project) {
    final nameCtrl = TextEditingController(text: project.name);
    final i18n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: Text(i18n?.translate('projects.edit') ?? 'Editar nombre', style: AppTypography.heading2),
        content: TextField(
          controller: nameCtrl,
          decoration: InputDecoration(
            labelText: i18n?.translate('projects.name_label') ?? 'Nombre del proyecto',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(i18n?.translate('common.cancel') ?? 'Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                context.read<ProjectsRepository>().updateProjectName(project.id, nameCtrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: Text(i18n?.translate('common.save') ?? 'Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context);
    final projectsRepo = context.watch<ProjectsRepository>();

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n?.translate('projects.title') ?? 'Mis Proyectos', style: AppTypography.heading2),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: AppColors.primary),
            onPressed: () => _showCreateDialog(context),
          ),
        ],
      ),
      body: projectsRepo.isLoading
          ? const Center(child: CircularProgressIndicator())
          : projectsRepo.projects.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open, size: 64, color: AppColors.darkTextSecondary.withValues(alpha: 0.5)),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        i18n?.translate('projects.empty') ?? 'No hay proyectos creados aún.',
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextSecondary),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add),
                        label: Text(i18n?.translate('projects.create') ?? 'Crear Proyecto'),
                        onPressed: () => _showCreateDialog(context),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: projectsRepo.projects.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final project = projectsRepo.projects[index];

                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.darkSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.darkBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.folder, color: AppColors.primary),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  project.name,
                                  style: AppTypography.heading2.copyWith(fontSize: 16, color: Colors.white),
                                ),
                                if (project.description != null && project.description!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    project.description!,
                                    style: AppTypography.caption.copyWith(color: AppColors.darkTextSecondary),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: AppColors.darkTextSecondary),
                            color: AppColors.darkSurface,
                            onSelected: (action) {
                              if (action == 'edit') {
                                _showEditDialog(context, project);
                              } else if (action == 'delete') {
                                projectsRepo.deleteProject(project.id);
                              } else if (action == 'open') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Abriendo proyecto: ${project.name}')),
                                );
                              }
                            },
                            itemBuilder: (ctx) => [
                              PopupMenuItem(
                                value: 'open',
                                child: Text(i18n?.translate('projects.open') ?? 'Abrir'),
                              ),
                              PopupMenuItem(
                                value: 'edit',
                                child: Text(i18n?.translate('projects.edit') ?? 'Editar nombre'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  i18n?.translate('projects.delete') ?? 'Eliminar',
                                  style: const TextStyle(color: AppColors.accentRose),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
