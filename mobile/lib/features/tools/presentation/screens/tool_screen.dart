import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../services/ai/ai_router.dart';
import '../../../../services/ai/ai_provider.dart';
import '../../../../services/analytics/analytics_service.dart';
import '../../../credits/data/credit_service.dart';
import '../../../history/data/history_repository.dart';
import '../../domain/tool_entity.dart';

class ToolScreen extends StatefulWidget {
  final ToolEntity tool;

  const ToolScreen({super.key, required this.tool});

  @override
  State<ToolScreen> createState() => _ToolScreenState();
}

class _ToolScreenState extends State<ToolScreen> {
  // Controladores de texto universales
  final _mainTextController = TextEditingController();
  final _extraTextController = TextEditingController();
  final _benefitController = TextEditingController();
  final _audienceController = TextEditingController();
  final _imageUrlController = TextEditingController();

  // Selectores
  String _selectedTone = 'Profesional';
  String _selectedLength = 'Medio';
  String _selectedSourceLang = 'Auto (detectar)';
  String _selectedTargetLang = 'Inglés';
  String _selectedPlatform = 'Instagram';

  bool _isProcessing = false;
  String? _errorMessage;
  dynamic _resultData;
  bool _copied = false;

  final List<String> _tones = [
    'Profesional',
    'Casual',
    'Amigable',
    'Persuasivo',
    'Formal',
    'Corto',
  ];

  final List<String> _lengths = ['Corto', 'Medio', 'Detallado'];

  final List<String> _languages = [
    'Español',
    'Inglés',
    'Francés',
    'Portugués',
    'Alemán',
    'Italiano',
  ];

  final List<String> _platforms = [
    'Instagram',
    'Facebook',
    'TikTok',
    'LinkedIn',
    'WhatsApp',
  ];

  @override
  void initState() {
    super.initState();
    AnalyticsService().logToolViewed(
      toolId: widget.tool.id,
      category: widget.tool.category,
    );
  }

  @override
  void dispose() {
    _mainTextController.dispose();
    _extraTextController.dispose();
    _benefitController.dispose();
    _audienceController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  IconData _mapIcon(String iconName) {
    switch (iconName) {
      case 'layers_clear':
        return Icons.layers_clear;
      case 'auto_fix_high':
        return Icons.auto_fix_high;
      case 'wallpaper':
        return Icons.wallpaper;
      case 'campaign':
        return Icons.campaign;
      case 'share':
        return Icons.share;
      case 'shopping_bag':
        return Icons.shopping_bag;
      case 'edit_note':
        return Icons.edit_note;
      case 'translate':
        return Icons.translate;
      case 'summarize':
        return Icons.summarize;
      default:
        return Icons.auto_awesome;
    }
  }

  Map<String, dynamic> _buildPayload() {
    final toolId = widget.tool.id;
    final Map<String, dynamic> payload = {};

    switch (toolId) {
      case 'rewrite_text':
        payload['text'] = _mainTextController.text.trim();
        payload['tone'] = _selectedTone;
        break;

      case 'translate_text':
        payload['text'] = _mainTextController.text.trim();
        payload['source_language'] = _selectedSourceLang;
        payload['target_language'] = _selectedTargetLang;
        break;

      case 'summarize_text':
        payload['text'] = _mainTextController.text.trim();
        payload['length'] = _selectedLength;
        break;

      case 'create_ad':
        payload['product_service'] = _mainTextController.text.trim();
        payload['target_audience'] = _audienceController.text.trim();
        payload['main_benefit'] = _benefitController.text.trim();
        payload['tone'] = _selectedTone;
        payload['platform'] = _selectedPlatform;
        break;

      case 'social_post':
        payload['topic_product'] = _mainTextController.text.trim();
        payload['platform'] = _selectedPlatform;
        payload['tone'] = _selectedTone;
        payload['goal'] = _extraTextController.text.trim();
        break;

      case 'product_description':
        payload['name'] = _mainTextController.text.trim();
        payload['features'] = _extraTextController.text.trim();
        payload['benefits'] = _benefitController.text.trim();
        payload['audience'] = _audienceController.text.trim();
        payload['tone'] = _selectedTone;
        break;

      case 'generate_image':
        payload['prompt'] = _mainTextController.text.trim();
        break;

      case 'improve_image':
      case 'remove_background':
        payload['image_url'] = _imageUrlController.text.trim();
        break;

      case 'change_background':
        payload['image_url'] = _imageUrlController.text.trim();
        payload['background_description'] = _mainTextController.text.trim();
        break;

      default:
        payload['text'] = _mainTextController.text.trim();
        break;
    }

    return payload;
  }

  void _validateInputs() {
    final toolId = widget.tool.id;
    if (toolId == 'generate_image') {
      if (_mainTextController.text.trim().isEmpty) {
        throw Exception('Por favor escribe un prompt para generar la imagen.');
      }
    } else if (toolId == 'improve_image' || toolId == 'remove_background') {
      if (_imageUrlController.text.trim().isEmpty) {
        throw Exception('Por favor ingresa la URL de la imagen.');
      }
    } else if (toolId == 'change_background') {
      if (_imageUrlController.text.trim().isEmpty) {
        throw Exception('Por favor ingresa la URL de la imagen base.');
      }
      if (_mainTextController.text.trim().isEmpty) {
        throw Exception('Por favor describe el nuevo fondo deseado.');
      }
    } else {
      if (_mainTextController.text.trim().isEmpty) {
        throw Exception('Por favor completa el campo de texto requerido.');
      }
    }
  }

  Future<void> _execute() async {
    setState(() {
      _errorMessage = null;
      _copied = false;
    });

    try {
      _validateInputs();
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
      return;
    }

    final creditService = context.read<CreditService>();
    if (!creditService.canAfford(widget.tool.creditCost)) {
      setState(() {
        _errorMessage = 'Saldo insuficiente. Esta herramienta requiere ${widget.tool.creditCost} créditos.';
      });
      return;
    }

    setState(() => _isProcessing = true);
    final stopwatch = Stopwatch()..start();
    AnalyticsService().logToolStarted(
      toolId: widget.tool.id,
      creditCost: widget.tool.creditCost,
    );

    try {
      final aiRouter = context.read<AIRouter>();
      final payload = _buildPayload();

      final response = await aiRouter.generate(AIRequest(
        toolId: widget.tool.id,
        input: payload,
      ));

      stopwatch.stop();
      setState(() {
        _resultData = response.result;
      });

      // Actualizar saldo reactivo en memoria
      await creditService.getBalance();
      // Refrescar historial
      context.read<HistoryRepository>().fetchHistory();

      AnalyticsService().logToolCompleted(
        toolId: widget.tool.id,
        processingTimeMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
      AnalyticsService().logToolFailed(
        toolId: widget.tool.id,
        error: e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Copiado al portapapeles'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final title = widget.tool.getLocalizedName(lang);
    final description = widget.tool.getLocalizedDescription(lang);
    final creditCost = widget.tool.creditCost;

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: AppTypography.heading2),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header con Icono, Descripción y Costo del Backend
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_mapIcon(widget.tool.icon), color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppTypography.heading2.copyWith(color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: AppTypography.caption.copyWith(color: AppColors.darkTextSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accentAmber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.accentAmber.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt, color: AppColors.accentAmber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '$creditCost',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentAmber),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.accentRose.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accentRose.withOpacity(0.4)),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),

            // Formulario Dinámico según la Herramienta
            _buildFormFields(),

            const SizedBox(height: AppSpacing.xl),

            // Botón de Ejecución con Estado Procesando
            ElevatedButton(
              onPressed: _isProcessing ? null : _execute,
              child: _isProcessing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 12),
                        Text('Procesando...', style: TextStyle(color: Colors.white)),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bolt, size: 20, color: AppColors.accentAmber),
                        const SizedBox(width: 8),
                        Text('Procesar ($creditCost créditos)'),
                      ],
                    ),
            ),

            // Visualizador de Resultados Dinámico
            if (_resultData != null) ...[
              const SizedBox(height: AppSpacing.xl),
              _buildResultView(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFormFields() {
    final toolId = widget.tool.id;

    // 1. Reescribir texto
    if (toolId == 'rewrite_text') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Texto original', style: AppTypography.heading2),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _mainTextController,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Introduce el texto que deseas reescribir...'),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('Tono de redacción', style: AppTypography.heading2),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            value: _selectedTone,
            items: _tones.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (val) => setState(() => _selectedTone = val ?? _selectedTone),
          ),
        ],
      );
    }

    // 2. Traducir texto
    if (toolId == 'translate_text') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Texto a traducir', style: AppTypography.heading2),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _mainTextController,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Introduce el texto para traducir...'),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Origen', style: AppTypography.caption),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _selectedSourceLang,
                      items: ['Auto (detectar)', ..._languages]
                          .map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedSourceLang = val ?? _selectedSourceLang),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Destino', style: AppTypography.caption),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _selectedTargetLang,
                      items: _languages
                          .map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedTargetLang = val ?? _selectedTargetLang),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }

    // 3. Resumir texto
    if (toolId == 'summarize_text') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Texto extenso', style: AppTypography.heading2),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _mainTextController,
            maxLines: 5,
            decoration: const InputDecoration(hintText: 'Pega el artículo o texto largo aquí...'),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('Longitud del resumen', style: AppTypography.heading2),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            value: _selectedLength,
            items: _lengths.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
            onChanged: (val) => setState(() => _selectedLength = val ?? _selectedLength),
          ),
        ],
      );
    }

    // 4. Crear anuncio
    if (toolId == 'create_ad') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Producto o servicio', style: AppTypography.heading2),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _mainTextController,
            decoration: const InputDecoration(hintText: 'Ej. Zapatillas deportivas ultraligeras'),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('Público objetivo', style: AppTypography.caption),
          const SizedBox(height: 4),
          TextField(
            controller: _audienceController,
            decoration: const InputDecoration(hintText: 'Ej. Corredores urbanos de 20 a 40 años'),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('Beneficio principal', style: AppTypography.caption),
          const SizedBox(height: 4),
          TextField(
            controller: _benefitController,
            decoration: const InputDecoration(hintText: 'Ej. Amortiguación que previene fatiga'),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Plataforma', style: AppTypography.caption),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _selectedPlatform,
                      items: _platforms
                          .map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedPlatform = val ?? _selectedPlatform),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tono', style: AppTypography.caption),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _selectedTone,
                      items: _tones
                          .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedTone = val ?? _selectedTone),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }

    // 5. Publicación para redes
    if (toolId == 'social_post') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tema o producto', style: AppTypography.heading2),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _mainTextController,
            decoration: const InputDecoration(hintText: 'Ej. Lanzamiento de nueva colección de verano'),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('Objetivo de la publicación', style: AppTypography.caption),
          const SizedBox(height: 4),
          TextField(
            controller: _extraTextController,
            decoration: const InputDecoration(hintText: 'Ej. Generar comentarios y clics al perfil'),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedPlatform,
                  items: _platforms.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                  onChanged: (val) => setState(() => _selectedPlatform = val ?? _selectedPlatform),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedTone,
                  items: _tones.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (val) => setState(() => _selectedTone = val ?? _selectedTone),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // 6. Descripción de producto
    if (toolId == 'product_description') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nombre del producto', style: AppTypography.heading2),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _mainTextController,
            decoration: const InputDecoration(hintText: 'Ej. Auriculares inalámbricos Pro X'),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('Características técnicas', style: AppTypography.caption),
          const SizedBox(height: 4),
          TextField(
            controller: _extraTextController,
            maxLines: 2,
            decoration: const InputDecoration(hintText: 'Ej. Bluetooth 5.3, batería 30h, cancelación activa de ruido'),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('Beneficios y público', style: AppTypography.caption),
          const SizedBox(height: 4),
          TextField(
            controller: _benefitController,
            decoration: const InputDecoration(hintText: 'Ej. Ideal para oficina y viajes'),
          ),
        ],
      );
    }

    // 7. Generar imagen
    if (toolId == 'generate_image') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Descripción detallada (Prompt)', style: AppTypography.heading2),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _mainTextController,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Un automóvil deportivo rojo frente a una ciudad futurista al atardecer'),
          ),
        ],
      );
    }

    // 8. Mejorar imagen o 9. Quitar fondo
    if (toolId == 'improve_image' || toolId == 'remove_background') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('URL de la imagen', style: AppTypography.heading2),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _imageUrlController,
            decoration: const InputDecoration(
              hintText: 'https://ejemplo.com/foto.jpg',
              prefixIcon: Icon(Icons.link),
            ),
          ),
        ],
      );
    }

    // 10. Cambiar fondo
    if (toolId == 'change_background') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('URL de la imagen del producto', style: AppTypography.heading2),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _imageUrlController,
            decoration: const InputDecoration(
              hintText: 'https://ejemplo.com/producto.jpg',
              prefixIcon: Icon(Icons.image),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('Descripción del nuevo fondo', style: AppTypography.heading2),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _mainTextController,
            maxLines: 2,
            decoration: const InputDecoration(hintText: 'Una oficina moderna con iluminación profesional y plantas verdes'),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildResultView() {
    final toolId = widget.tool.id;

    // Herramientas de Imagen
    if (toolId.contains('image') || toolId.contains('background')) {
      final imgUrl = _resultData is Map
          ? (_resultData['image_url'] ?? _resultData['enhanced_image_url'] ?? '')
          : '';

      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Resultado visual', style: AppTypography.heading2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('✓ Generado', style: TextStyle(color: AppColors.accentGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 220,
                color: Colors.black38,
                child: imgUrl.startsWith('data:image')
                    ? Image.memory(
                        base64Decode(imgUrl.split(',').last),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image, size: 48, color: AppColors.darkTextSecondary),
                        ),
                      )
                    : Image.network(
                        imgUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image, size: 48, color: AppColors.darkTextSecondary),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _copyToClipboard(imgUrl);
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: Text(_copied ? '✓ Copiado' : 'Copiar URL'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Guardado en Mis Creaciones')),
                      );
                    },
                    icon: const Icon(Icons.bookmark_border, size: 16),
                    label: const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Herramientas Estructuradas de Marketing
    if (toolId == 'create_ad' && _resultData is Map) {
      final title = _resultData['title'] ?? '';
      final mainText = _resultData['main_text'] ?? '';
      final cta = _resultData['cta'] ?? '';
      final fullAd = '$title\n\n$mainText\n\n👉 $cta';

      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Anuncio Publicitario', style: AppTypography.heading2),
                IconButton(
                  icon: Icon(_copied ? Icons.check : Icons.copy, color: AppColors.primary),
                  onPressed: () => _copyToClipboard(fullAd),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(title, style: AppTypography.heading2.copyWith(color: AppColors.primaryLight, fontSize: 17)),
            const SizedBox(height: AppSpacing.sm),
            Text(mainText, style: AppTypography.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('CTA: $cta', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (toolId == 'social_post' && _resultData is Map) {
      final post = _resultData['post'] ?? '';
      final cta = _resultData['cta'] ?? '';
      final hashtags = (_resultData['hashtags'] as List?)?.join(' ') ?? '';
      final fullPost = '$post\n\n$cta\n\n$hashtags';

      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Publicación Social', style: AppTypography.heading2),
                IconButton(
                  icon: Icon(_copied ? Icons.check : Icons.copy, color: AppColors.primary),
                  onPressed: () => _copyToClipboard(fullPost),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(post, style: AppTypography.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(cta, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
            const SizedBox(height: AppSpacing.sm),
            Text(hashtags, style: const TextStyle(color: AppColors.secondary)),
          ],
        ),
      );
    }

    if (toolId == 'product_description' && _resultData is Map) {
      final title = _resultData['title'] ?? '';
      final shortDesc = _resultData['short_description'] ?? '';
      final fullDesc = _resultData['full_description'] ?? '';
      final cta = _resultData['cta'] ?? '';
      final copyContent = '$title\n\n$shortDesc\n\n$fullDesc\n\n👉 $cta';

      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Ficha Comercial', style: AppTypography.heading2),
                IconButton(
                  icon: Icon(_copied ? Icons.check : Icons.copy, color: AppColors.primary),
                  onPressed: () => _copyToClipboard(copyContent),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(title, style: AppTypography.heading2.copyWith(color: AppColors.primaryLight, fontSize: 17)),
            const SizedBox(height: AppSpacing.sm),
            Text(shortDesc, style: const TextStyle(fontStyle: FontStyle.italic, color: AppColors.darkTextSecondary)),
            const SizedBox(height: AppSpacing.sm),
            Text(fullDesc, style: AppTypography.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            Text('CTA: $cta', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentGreen)),
          ],
        ),
      );
    }

    // Herramientas de Texto Simple (rewrite, translate, summarize)
    final textResult = _resultData is Map ? (_resultData['text'] ?? _resultData.toString()) : _resultData.toString();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Resultado', style: AppTypography.heading2),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(110, 36),
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  foregroundColor: AppColors.primaryLight,
                ),
                onPressed: () => _copyToClipboard(textResult),
                icon: Icon(_copied ? Icons.check : Icons.copy, size: 16),
                label: Text(_copied ? '✓ Copiado' : 'Copiar'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SelectableText(
            textResult,
            style: AppTypography.bodyLarge.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }
}
