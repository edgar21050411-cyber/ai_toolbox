class ToolEntity {
  final String id;
  final String slug;
  final Map<String, dynamic> name;
  final Map<String, dynamic> description;
  final String category; // 'create', 'improve', 'marketing', 'documents', 'audio', 'assistant'
  final String icon;
  final bool enabled;
  final bool beta;
  final String minimumPlan; // 'free', 'pro', 'business'
  final int creditCost;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ToolEntity({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    required this.enabled,
    required this.beta,
    required this.minimumPlan,
    required this.creditCost,
    required this.sortOrder,
    this.createdAt,
    this.updatedAt,
  });

  String getLocalizedName(String languageCode) {
    return name[languageCode] ?? name['es'] ?? id;
  }

  String getLocalizedDescription(String languageCode) {
    return description[languageCode] ?? description['es'] ?? '';
  }

  factory ToolEntity.fromMap(Map<String, dynamic> map) {
    return ToolEntity(
      id: map['id'] ?? '',
      slug: map['slug'] ?? map['id'] ?? '',
      name: map['name'] is Map ? Map<String, dynamic>.from(map['name']) : {},
      description: map['description'] is Map ? Map<String, dynamic>.from(map['description']) : {},
      category: map['category'] ?? 'create',
      icon: map['icon'] ?? 'auto_awesome',
      enabled: map['enabled'] ?? true,
      beta: map['beta'] ?? false,
      minimumPlan: map['minimum_plan'] ?? 'free',
      creditCost: map['credit_cost'] ?? 1,
      sortOrder: map['sort_order'] ?? 0,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at']) : null,
    );
  }
}
