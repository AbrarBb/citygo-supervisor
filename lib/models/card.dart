/// Registered Card model
class RegisteredCard {
  final String cardId;
  final String? passengerName;
  final double? balance;
  final String? status;
  final DateTime? registeredAt;
  final DateTime? lastUsed;

  RegisteredCard({
    required this.cardId,
    this.passengerName,
    this.balance,
    this.status,
    this.registeredAt,
    this.lastUsed,
  });

  factory RegisteredCard.fromJson(Map<String, dynamic> json) {
    return RegisteredCard(
      cardId: json['card_id'] as String? ?? 
              json['nfc_id'] as String? ?? 
              json['id'] as String? ??
              '',
      passengerName: json['passenger_name'] as String? ?? 
                     json['name'] as String? ??
                     json['full_name'] as String?,
      balance: (json['balance'] as num?)?.toDouble() ?? 
               (json['card_balance'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'active',
      registeredAt: json['registered_at'] != null
          ? DateTime.parse(json['registered_at'] as String)
          : (json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : null),
      lastUsed: json['last_used'] != null
          ? DateTime.parse(json['last_used'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'card_id': cardId,
      if (passengerName != null) 'passenger_name': passengerName,
      if (balance != null) 'balance': balance,
      if (status != null) 'status': status,
      if (registeredAt != null) 'registered_at': registeredAt!.toIso8601String(),
      if (lastUsed != null) 'last_used': lastUsed!.toIso8601String(),
    };
  }
}

