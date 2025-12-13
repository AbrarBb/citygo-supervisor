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
    // Try multiple field names for card ID
    String? cardIdValue = json['card_id'] as String? ?? 
                         json['nfc_id'] as String? ?? 
                         json['nfc_card_id'] as String? ??
                         json['id'] as String?;
    
    // If card ID is still null, try to extract from nested objects
    if (cardIdValue == null || cardIdValue.isEmpty) {
      if (json['card'] is Map) {
        final cardObj = json['card'] as Map<String, dynamic>;
        cardIdValue = cardObj['card_id'] as String? ?? 
                     cardObj['nfc_id'] as String? ??
                     cardObj['id'] as String?;
      }
    }
    
    // Try multiple field names for passenger name
    String? passengerNameValue = json['passenger_name'] as String? ?? 
                                  json['name'] as String? ??
                                  json['full_name'] as String? ??
                                  json['user_name'] as String?;
    
    // If passenger name is in nested object
    if (passengerNameValue == null || passengerNameValue.isEmpty) {
      if (json['passenger'] is Map) {
        final passengerObj = json['passenger'] as Map<String, dynamic>;
        passengerNameValue = passengerObj['name'] as String? ?? 
                            passengerObj['full_name'] as String?;
      }
      if (passengerNameValue == null && json['user'] is Map) {
        final userObj = json['user'] as Map<String, dynamic>;
        passengerNameValue = userObj['name'] as String? ?? 
                            userObj['full_name'] as String?;
      }
    }
    
    // Try multiple field names for balance
    double? balanceValue = (json['balance'] as num?)?.toDouble() ?? 
                          (json['card_balance'] as num?)?.toDouble() ??
                          (json['wallet_balance'] as num?)?.toDouble();
    
    // If balance is in nested object
    if (balanceValue == null) {
      if (json['card'] is Map) {
        final cardObj = json['card'] as Map<String, dynamic>;
        balanceValue = (cardObj['balance'] as num?)?.toDouble();
      }
    }
    
    return RegisteredCard(
      cardId: cardIdValue ?? '',
      passengerName: passengerNameValue,
      balance: balanceValue,
      status: json['status'] as String? ?? 
              json['card_status'] as String? ?? 
              'active',
      registeredAt: json['registered_at'] != null
          ? DateTime.parse(json['registered_at'] as String)
          : (json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : null),
      lastUsed: json['last_used'] != null
          ? DateTime.parse(json['last_used'] as String)
          : (json['last_used_at'] != null
              ? DateTime.parse(json['last_used_at'] as String)
              : null),
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

