import 'dart:math';

/// Deterministic, offline household intelligence.
/// Business rules live here so the UI never needs a network or AI key.
class HouseholdEngine {
  static List<Map<String, dynamic>> generateWeek({
    required List<dynamic> meals,
    required List<Map<String, dynamic>> pantry,
    required double budgetRemaining,
  }) {
    if (meals.isEmpty) return [];
    final normalized = meals.where((m) => m is List && m.length >= 3).map((m) {
      final row = m as List;
      return <String, dynamic>{
        'name': row[0].toString(),
        'region': row[1].toString(),
        'cost': (row[2] as num).toDouble(),
      };
    }).toList();
    if (normalized.isEmpty) return [];
    final affordable = normalized.where((m) => (m['cost'] as double) <= max(0, budgetRemaining)).toList();
    final source = affordable.isEmpty ? normalized : affordable;
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return List.generate(7, (i) {
      final meal = source[i % source.length];
      return {
        'day': days[i],
        'meal': meal['name'],
        'region': meal['region'],
        'estimatedCost': meal['cost'],
        'leftoverPlan': i < 6 ? 'Reserve a portion for the next meal.' : 'Finish or freeze leftovers.',
        'reason': _reason(i, pantry),
      };
    });
  }

  static String _reason(int index, List<Map<String, dynamic>> pantry) {
    final low = pantry.where((x) => (x['qty'] as num? ?? 0) <= (x['min'] as num? ?? 0));
    if (low.isNotEmpty && index.isEven) return 'Use available stock before buying more.';
    if (index >= 5) return 'Weekend batch-cook / leftover opportunity.';
    return 'Balanced rotation from your local meal library.';
  }

  static List<Map<String, dynamic>> shoppingList(List<Map<String, dynamic>> pantry) {
    return pantry.where((x) => (x['qty'] as num? ?? 0) <= (x['min'] as num? ?? 0)).map((x) {
      final min = (x['min'] as num? ?? 0).toDouble();
      final qty = (x['qty'] as num? ?? 0).toDouble();
      return {
        'name': x['name'].toString(),
        'suggestedQty': max(1, (min * 2 - qty).ceil()),
        'unit': x['unit'].toString(),
        'priority': qty <= 0 ? 'urgent' : 'normal',
        'purchased': false,
      };
    }).toList();
  }

  /// Consumes stock by ingredient name and never lets a quantity become negative.
  static List<Map<String, dynamic>> consumeIngredients(
    List<Map<String, dynamic>> pantry,
    List<dynamic> ingredients, {
    double quantityPerIngredient = 1,
  }) {
    final next = pantry.map((x) => Map<String, dynamic>.from(x)).toList();
    for (final raw in ingredients) {
      final name = raw.toString().trim().toLowerCase();
      final index = next.indexWhere((x) => x['name'].toString().trim().toLowerCase() == name);
      if (index < 0) continue;
      final current = (next[index]['qty'] as num? ?? 0).toDouble();
      next[index]['qty'] = max(0, current - quantityPerIngredient);
    }
    return next;
  }

  /// Calculates the number of days the remaining budget should cover.
  static Map<String, dynamic> budgetInsight(
    double budget,
    double spent,
    double daysRemaining,
  ) {
    final remaining = budget - spent;
    final safeDays = max(daysRemaining, 1);
    final dailyLimit = remaining / safeDays;
    return {
      'remaining': remaining,
      'dailyLimit': dailyLimit,
      'status': remaining < 0 ? 'over' : dailyLimit < 2500 ? 'tight' : 'healthy',
    };
  }

  /// Freezer rule used by the UI: never allow capacity above its configured maximum.
  static double freezerPercent(double used, double capacity) {
    if (capacity <= 0) return 0;
    return used.clamp(0, capacity);
  }

  /// Returns a short deterministic recommendation for the household dashboard.
  static String householdAdvice({
    required int lowStock,
    required int leftovers,
    required double budgetRemaining,
  }) {
    if (lowStock > 0 && leftovers > 0) {
      return 'Use the leftovers first, then buy the low-stock items.';
    }
    if (lowStock > 0) return 'Several items are below their minimum stock level.';
    if (leftovers > 0) return 'Reuse the available leftovers before cooking a new meal.';
    if (budgetRemaining < 0) return 'The recorded budget has been exceeded.';
    return 'Stock and budget are currently under control.';
  }
}
