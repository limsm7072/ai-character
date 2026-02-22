import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'coin_service.dart';

class PurchaseService {
  static const _purchasedKey = 'purchased_model_ids';

  final SharedPreferences _prefs;
  final CoinService _coinService;

  PurchaseService({
    required SharedPreferences prefs,
    required CoinService coinService,
  })  : _prefs = prefs,
        _coinService = coinService;

  Set<String> get purchasedIds {
    final raw = _prefs.getStringList(_purchasedKey);
    return raw?.toSet() ?? {};
  }

  bool isPurchased(String modelId) => purchasedIds.contains(modelId);

  /// Purchase a model. Returns true if successful, false if insufficient coins.
  Future<bool> purchase(String modelId, int price) async {
    if (isPurchased(modelId)) return true; // already owned
    final spent = await _coinService.spendCoins(price, 'purchase:$modelId');
    if (!spent) return false;
    final ids = purchasedIds.toList()..add(modelId);
    await _prefs.setStringList(_purchasedKey, ids);
    return true;
  }

  int get purchasedCount => purchasedIds.length;
}
