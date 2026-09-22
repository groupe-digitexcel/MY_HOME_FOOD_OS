import 'package:flutter_test/flutter_test.dart';
import 'package:my_home_food_os/household_engine.dart';

void main() {
  group('HouseholdEngine', () {
    final meals = <dynamic>[
      ['Ndolé + plantain', 'Littoral', 4500],
      ['Eru + water fufu', 'Southwest', 5000],
      ['Koki + plantain', 'Centre', 3500],
    ];

    test('generates seven dynamic days', () {
      final result = HouseholdEngine.generateWeek(
        meals: meals,
        pantry: [
          {'name': 'Rice', 'qty': 1.0, 'unit': 'kg', 'min': 2.0},
        ],
        budgetRemaining: 100000,
      );
      expect(result.length, 7);
      expect(result.first['meal'], isNotEmpty);
      expect(result.first.containsKey('leftoverPlan'), true);
    });

    test('low stock becomes a shopping item', () {
      final result = HouseholdEngine.shoppingList([
        {'name': 'Rice', 'qty': 1.0, 'unit': 'kg', 'min': 2.0},
        {'name': 'Beans', 'qty': 4.0, 'unit': 'kg', 'min': 1.0},
      ]);
      expect(result.length, 1);
      expect(result.first['name'], 'Rice');
      expect(result.first['purchased'], false);
      expect(result.first['suggestedQty'], greaterThan(0));
    });

    test('budget insight calculates daily limit', () {
      final result = HouseholdEngine.budgetInsight(250000, 100000, 10);
      expect(result['remaining'], 150000);
      expect(result['dailyLimit'], 15000);
      expect(result['status'], 'healthy');
    });

    test('ingredient consumption reduces matching stock without going negative', () {
      final result = HouseholdEngine.consumeIngredients([
        {'name': 'Rice', 'qty': 1.5, 'unit': 'kg', 'min': 1.0},
        {'name': 'Beans', 'qty': 0.5, 'unit': 'kg', 'min': 1.0},
      ], ['Rice', 'Beans']);
      expect(result[0]['qty'], 0.5);
      expect(result[1]['qty'], 0);
    });

    test('freezer percentage is clamped to capacity', () {
      expect(HouseholdEngine.freezerPercent(120, 100), 100);
      expect(HouseholdEngine.freezerPercent(-5, 100), 0);
    });

    test('household advice combines actionable conditions', () {
      expect(
        HouseholdEngine.householdAdvice(
          lowStock: 2,
          leftovers: 1,
          budgetRemaining: 50000,
        ),
        contains('leftovers'),
      );
    });
  });
}
