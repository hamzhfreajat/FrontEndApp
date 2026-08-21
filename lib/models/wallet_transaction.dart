class WalletTransaction {
  final int id;
  final int userId;
  final double amount;
  final String transactionType;
  final String? description;
  final String? referenceId;
  final DateTime createdAt;

  WalletTransaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.transactionType,
    this.description,
    this.referenceId,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'],
      userId: json['user_id'],
      amount: double.tryParse(json['amount'].toString()) ?? 0.0,
      transactionType: json['transaction_type'] ?? 'UNKNOWN',
      description: json['description'],
      referenceId: json['reference_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
