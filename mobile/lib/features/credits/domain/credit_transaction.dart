class CreditTransaction {
  final String id;
  final String userId;
  final int amount; // Positivo (abono) o Negativo (consumo)
  final String transactionType; // purchase, subscription, usage, refund, bonus, adjustment
  final String? tool;
  final String? generationId;
  final String? description;
  final DateTime createdAt;

  CreditTransaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.transactionType,
    this.tool,
    this.generationId,
    this.description,
    required this.createdAt,
  });

  factory CreditTransaction.fromMap(Map<String, dynamic> map) {
    return CreditTransaction(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      amount: map['amount'] ?? 0,
      transactionType: map['transaction_type'] ?? 'usage',
      tool: map['tool'],
      generationId: map['generation_id'],
      description: map['description'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }
}
