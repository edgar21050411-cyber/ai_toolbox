import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../credits/data/credit_service.dart';
import '../../../tools/data/tool_registry.dart';
import '../../../tools/domain/tool_entity.dart';
import '../../../tools/presentation/screens/tool_screen.dart';
import '../widgets/credit_badge.dart';
import '../widgets/tool_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = 'all';
  String _searchQuery = '';

  final List<Map<String, dynamic>> _categories = [
    {'id': 'all', 'labelKey': 'home.categories.all', 'icon': Icons.grid_view},
    {'id': 'text', 'labelKey': 'home.categories.text', 'icon': Icons.article_outlined},
    {'id': 'marketing', 'labelKey': 'home.categories.marketing', 'icon': Icons.campaign_outlined},
    {'id': 'images', 'labelKey': 'home.categories.images', 'icon': Icons.image_outlined},
    {'id': 'documents', 'labelKey': 'home.categories.documents', 'icon': Icons.description_outlined},
    {'id': 'audio', 'labelKey': 'home.categories.audio', 'icon': Icons.mic_none},
    {'id': 'assistant', 'labelKey': 'home.categories.assistant', 'icon': Icons.smart_toy_outlined},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ToolRegistry>().fetchTools();
      context.read<CreditService>().getBalance();
    });
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context);
    final creditService = context.watch<CreditService>();
    final toolRegistry = context.watch<ToolRegistry>();

    List<ToolEntity> displayedTools;
    if (_selectedCategory == 'all') {
      displayedTools = toolRegistry.getEnabledTools();
    } else {
      displayedTools = toolRegistry.getToolsByCategory(_selectedCategory);
    }

    if (_searchQuery.isNotEmpty) {
      final lang = Localizations.localeOf(context).languageCode;
      displayedTools = displayedTools.where((t) {
        final name = t.getLocalizedName(lang).toLowerCase();
        final desc = t.getLocalizedDescription(lang).toLowerCase();
        return name.contains(_searchQuery.toLowerCase()) || desc.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.psychology, color: Colors.white, size: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              i18n?.translate('app.name') ?? 'AI Toolbox',
              style: AppTypography.heading2.copyWith(color: Colors.white),
            ),
          ],
        ),
        actions: [
          CreditBadge(
            balance: creditService.balance,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(i18n?.translate('credits.top_up') ?? 'Recargar créditos')),
              );
            },
          ),
          const SizedBox(width: AppSpacing.md),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await toolRegistry.fetchTools();
          await creditService.getBalance();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // Header: ¿Qué quieres hacer?
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i18n?.translate('home.title') ?? '¿Qué quieres hacer?',
                      style: AppTypography.displayLarge.copyWith(fontSize: 26, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      i18n?.translate('home.subtitle') ?? 'Selecciona una categoría o busca una herramienta',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextSecondary),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, color: AppColors.darkTextSecondary),
                        hintText: i18n?.translate('home.search_placeholder') ?? 'Buscar herramientas de IA...',
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => setState(() => _searchQuery = ''),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Selector horizontal de Categorías
            SliverToBoxAdapter(
              child: Container(
                height: 50,
                margin: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat['id'];
                    final label = i18n?.translate(cat['labelKey']) ?? cat['id'];

                    return ChoiceChip(
                      selected: isSelected,
                      label: Row(
                        children: [
                          Icon(
                            cat['icon'],
                            size: 16,
                            color: isSelected ? Colors.white : AppColors.darkTextSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(label),
                        ],
                      ),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.darkTextSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.darkSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : AppColors.darkBorder,
                        ),
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedCategory = cat['id'];
                          });
                        }
                      },
                    );
                  },
                ),
              ),
            ),

            // Grid de herramientas dinámicas
            toolRegistry.isLoading
                ? const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                : displayedTools.isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: Text(
                            'No se encontraron herramientas en esta selección',
                            style: const TextStyle(color: AppColors.darkTextSecondary),
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: AppSpacing.md,
                            crossAxisSpacing: AppSpacing.md,
                            childAspectRatio: 0.95,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final tool = displayedTools[index];
                              return ToolCard(
                                tool: tool,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => ToolScreen(tool: tool)),
                                  );
                                },
                              );
                            },
                            childCount: displayedTools.length,
                          ),
                        ),
                      ),
          ],
        ),
      ),
    );
  }
}
