class PrizeTier {
  final int rank;
  final int total;
  final int claimed;
  final int remaining;
  final int prizeAmount;
  final String prizeText;

  const PrizeTier({
    required this.rank,
    required this.total,
    required this.claimed,
    required this.remaining,
    required this.prizeAmount,
    required this.prizeText,
  });

  double probability(double totalTickets) =>
      totalTickets > 0 ? remaining / totalTickets : 0;

  Map<String, dynamic> toJson() => {
    'rank': rank,
    'total': total,
    'claimed': claimed,
    'remaining': remaining,
    'prizeAmount': prizeAmount,
    'prizeText': prizeText,
  };

  factory PrizeTier.fromJson(Map<String, dynamic> j) => PrizeTier(
    rank: j['rank'] as int? ?? 0,
    total: j['total'] as int? ?? 0,
    claimed: j['claimed'] as int? ?? 0,
    remaining: j['remaining'] as int? ?? 0,
    prizeAmount: j['prizeAmount'] as int? ?? 0,
    prizeText: j['prizeText'] as String? ?? '',
  );
}

class ScratchGame {
  final String typeCode;
  final String typeName;
  final int round;
  final int price;
  final String saleStart;
  final String saleEnd;
  final double stockRate;
  final int totalIssued;
  final List<PrizeTier> tiers;
  final String updateDate;
  final String originalOdds;
  final double originalReturnRate;

  const ScratchGame({
    required this.typeCode,
    required this.typeName,
    required this.round,
    required this.price,
    required this.saleStart,
    required this.saleEnd,
    required this.stockRate,
    required this.totalIssued,
    required this.tiers,
    required this.updateDate,
    required this.originalOdds,
    required this.originalReturnRate,
  });

  int get totalRemainingPrizes => tiers.fold(0, (s, t) => s + t.remaining);
  int get totalPrizes => tiers.fold(0, (s, t) => s + t.total);

  /// 잔여 티켓 추정 (재고율 기반)
  double get estimatedRemainingTickets {
    if (stockRate <= 0) return totalIssued.toDouble();
    return totalIssued * (stockRate / 100.0);
  }

  /// 전체 당첨 확률 (잔여 기준)
  double get currentWinProbability {
    final tickets = estimatedRemainingTickets;
    if (tickets <= 0) return 0;
    return totalRemainingPrizes / tickets;
  }

  /// 기대값 (원)
  double get expectedValue {
    final tickets = estimatedRemainingTickets;
    if (tickets <= 0) return -price.toDouble();
    double ev = 0;
    for (final t in tiers) {
      ev += t.probability(tickets) * t.prizeAmount;
    }
    return ev - price;
  }

  /// 환급률 (%)
  double get returnRate {
    final tickets = estimatedRemainingTickets;
    if (tickets <= 0 || price <= 0) return 0;
    double ev = 0;
    for (final t in tiers) {
      ev += t.probability(tickets) * t.prizeAmount;
    }
    return (ev / price) * 100;
  }

  Map<String, dynamic> toJson() => {
    'typeCode': typeCode,
    'typeName': typeName,
    'round': round,
    'price': price,
    'saleStart': saleStart,
    'saleEnd': saleEnd,
    'stockRate': stockRate,
    'totalIssued': totalIssued,
    'tiers': tiers.map((t) => t.toJson()).toList(),
    'updateDate': updateDate,
    'originalOdds': originalOdds,
    'originalReturnRate': originalReturnRate,
  };

  factory ScratchGame.fromJson(Map<String, dynamic> j) => ScratchGame(
    typeCode: j['typeCode'] as String? ?? '',
    typeName: j['typeName'] as String? ?? '',
    round: j['round'] as int? ?? 0,
    price: j['price'] as int? ?? 0,
    saleStart: j['saleStart'] as String? ?? '',
    saleEnd: j['saleEnd'] as String? ?? '',
    stockRate: (j['stockRate'] as num?)?.toDouble() ?? 0,
    totalIssued: j['totalIssued'] as int? ?? 0,
    tiers: ((j['tiers'] as List?) ?? [])
        .map((t) => PrizeTier.fromJson(t as Map<String, dynamic>))
        .toList(),
    updateDate: j['updateDate'] as String? ?? '',
    originalOdds: j['originalOdds'] as String? ?? '',
    originalReturnRate: (j['originalReturnRate'] as num?)?.toDouble() ?? 0,
  );
}

class LotterySnapshot {
  final List<ScratchGame> games;
  final DateTime fetchTime;

  const LotterySnapshot({required this.games, required this.fetchTime});

  Map<String, dynamic> toJson() => {
    'games': games.map((g) => g.toJson()).toList(),
    'fetchTime': fetchTime.millisecondsSinceEpoch,
  };

  factory LotterySnapshot.fromJson(Map<String, dynamic> j) => LotterySnapshot(
    games: ((j['games'] as List?) ?? [])
        .map((g) => ScratchGame.fromJson(g as Map<String, dynamic>))
        .toList(),
    fetchTime: DateTime.fromMillisecondsSinceEpoch(j['fetchTime'] as int? ?? 0),
  );
}
