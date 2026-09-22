import 'dart:math';

/// Deterministic local intelligence for MY HOME FOOD OS.
/// No network or AI key is required for calculations.
class HouseholdEngine {
  static List<Map<String, dynamic>> generateWeek({
    required List<List<dynamic>> meals,
    required List<Map<String, dynamic>> pantry,
    required double budgetRemaining,
  }) {
    if (meals.isEmpty) return [];
    final candidates = meals
        .where((m) => m.length >= 3)
        .map((m) => {
              'name': m[0].toString(),
              'region': m[1].toString(),
              'cost': (m[2] as num).toDouble(),
            })
        .where((m) => m['cost'] as double <= max(budgetRemaining, 0))
        .toList();

    final source = candidates.isEmpty
        ? meals.map((m) => {
              'name': m[0].toString(),
              'region': m[1].toString(),
              'cost': (m[2] as num).toDouble(),
            }).toList()
        : candidates;

    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < 7; i++) {
      final meal = source[i % source.length];
      result.add({
        'day': days[i],
        'meal': meal['name'],
        'region': meal['region'],
        'estimatedCost': meal['cost'],
        'leftoverPlan': i < 6 ? 'Reserve a portion for next meal.' : 'Finish or freeze leftovers.',
        'reason': _reason(i, meal['name'].toString(), pantry),
      });
    }
    return result;
  }

  static String _reason(int index, String meal, List<Map<String, dynamic>> pantry) {
    final low = pantry.where((x) => (x['qty'] as num? ?? 0) <= (x['min'] as num? ?? 0));
    if (low.isNotEmpty && index.isEven) {
      return 'Use available stock before buying more.';
    }
    if (index == 5 || index == 6) return 'Weekend batch-cook / leftover opportunity.';
    return 'Balanced rotation from your local meal library.';
  }

  static List<Map<String, dynamic>> shoppingList(
      List<Map<String, dynamic>> pantry) {
    return pantry
        .where((x) => (x['qty'] as num? ?? 0) <= (x['min'] as num? ?? 0))
        .map((x) => {
              'name': x['name'].toString(),
              'suggestedQty': max(
                1,
                ((x['min'] as num? ?? 0) * 2 - (x['qty'] as num? ?? 0)).ceil(),
              ),
              'unit': x['unit'].toString(),
              'priority': (x['qty'] as num? ?? 0) == 0 ? 'urgent' : 'normal',
            })
        .toList();
  }

  static Map<String, dynamic> budgetInsight(
      double budget, double spent, double daysRemaining) {
    final remaining = budget - spent;
    final safeDays = max(daysRemaining, 1);
    final dailyLimit = remaining / safeDays;
    return {
      'remaining': remaining,
      'dailyLimit': dailyLimit,
      'status': remaining < 0
          ? 'over'
          : dailyLimit < 2500
              ? 'tight'
              : 'healthy',
    };
  }
}
