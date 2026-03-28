enum LoyaltyTier { bronze, silver, gold, platinum }

class LoyaltyAccount {
  final String id;
  final String qrCode;
  final LoyaltyTier tier;
  final int points;
  final double totalSpent;
  final List<LoyaltyTransaction> transactions;

  LoyaltyAccount({
    required this.id,
    required this.qrCode,
    required this.tier,
    required this.points,
    required this.totalSpent,
    this.transactions = const [],
  });

  /// Create a LoyaltyAccount from the FastAPI backend JSON response.
  /// Transactions are fetched separately, so they default to empty.
  factory LoyaltyAccount.fromJson(Map<String, dynamic> json) {
    return LoyaltyAccount(
      id: json['id'] as String? ?? '',
      qrCode: json['qr_code'] as String? ?? '',
      tier: _parseTier(json['tier'] as String? ?? 'bronze'),
      points: (json['points'] as num?)?.toInt() ?? 0,
      totalSpent: (json['total_spent'] as num?)?.toDouble() ?? 0,
    );
  }

  static LoyaltyTier _parseTier(String value) {
    switch (value.toLowerCase()) {
      case 'silver':
        return LoyaltyTier.silver;
      case 'gold':
        return LoyaltyTier.gold;
      case 'platinum':
        return LoyaltyTier.platinum;
      case 'bronze':
      default:
        return LoyaltyTier.bronze;
    }
  }

  String get tierName {
    switch (tier) {
      case LoyaltyTier.bronze:
        return 'Bronze';
      case LoyaltyTier.silver:
        return 'Silver';
      case LoyaltyTier.gold:
        return 'Gold';
      case LoyaltyTier.platinum:
        return 'Platinum';
    }
  }

  int get cashbackPercent {
    switch (tier) {
      case LoyaltyTier.bronze:
        return 3;
      case LoyaltyTier.silver:
        return 5;
      case LoyaltyTier.gold:
        return 8;
      case LoyaltyTier.platinum:
        return 12;
    }
  }

  double get nextTierThreshold {
    switch (tier) {
      case LoyaltyTier.bronze:
        return 50000;
      case LoyaltyTier.silver:
        return 150000;
      case LoyaltyTier.gold:
        return 300000;
      case LoyaltyTier.platinum:
        return double.infinity;
    }
  }

  double get progressToNextTier {
    if (tier == LoyaltyTier.platinum) return 1.0;
    double prevThreshold = 0;
    switch (tier) {
      case LoyaltyTier.silver:
        prevThreshold = 50000;
        break;
      case LoyaltyTier.gold:
        prevThreshold = 150000;
        break;
      default:
        prevThreshold = 0;
    }
    return (totalSpent - prevThreshold) / (nextTierThreshold - prevThreshold);
  }
}

class LoyaltyTransaction {
  final String id;
  final DateTime date;
  final double amount;
  final int pointsEarned;
  final String description;
  final TransactionType type;

  LoyaltyTransaction({
    required this.id,
    required this.date,
    required this.amount,
    required this.pointsEarned,
    required this.description,
    required this.type,
  });

  /// Create a LoyaltyTransaction from the FastAPI backend JSON response.
  factory LoyaltyTransaction.fromJson(Map<String, dynamic> json) {
    return LoyaltyTransaction(
      id: json['id'] as String? ?? '',
      date: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      pointsEarned: (json['points_change'] as num?)?.toInt() ?? 0,
      description: json['description'] as String? ?? '',
      type: _parseTransactionType(json['type'] as String? ?? 'purchase'),
    );
  }

  static TransactionType _parseTransactionType(String value) {
    switch (value.toLowerCase()) {
      case 'points_redeemed':
        return TransactionType.pointsRedeemed;
      case 'bonus':
        return TransactionType.bonus;
      case 'referral':
        return TransactionType.referral;
      case 'purchase':
      default:
        return TransactionType.purchase;
    }
  }
}

enum TransactionType { purchase, pointsRedeemed, bonus, referral }
