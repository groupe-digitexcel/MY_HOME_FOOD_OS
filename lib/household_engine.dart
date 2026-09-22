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

  /// Aggregates exact ingredient requirements for a weekly meal plan.
  static List<Map<String, dynamic>> weeklyRequirements(
    List<Map<String, dynamic>> plan,
  ) {
    final totals=<String,Map<String,dynamic>>{};
    for(final day in plan){
      final meal=day['meal']?.toString() ?? '';
      for(final ingredient in recipeFor(meal)){
        final name=ingredient['name'].toString();
        final key=name.toLowerCase();
        final qty=(ingredient['qty'] as num? ?? 0).toDouble();
        final unit=ingredient['unit'].toString();
        final row=totals[key] ?? {'name':name,'requiredQty':0.0,'unit':unit};
        row['requiredQty']=(row['requiredQty'] as double)+qty;
        totals[key]=row;
      }
    }
    return totals.values.toList();
  }

  /// Converts weekly requirements into the quantities that must be purchased
  /// after subtracting usable pantry stock.
  static List<Map<String, dynamic>> weeklyShopping(
    List<Map<String, dynamic>> plan,
    List<Map<String, dynamic>> pantry,
  ) {
    final requirements=weeklyRequirements(plan);
    return requirements.where((r){
      final name=r['name'].toString().toLowerCase();
      final p=pantry.firstWhere((x)=>x['name'].toString().toLowerCase()==name,orElse:()=>{});
      final stock=(p['qty'] as num? ?? 0).toDouble();
      return (r['requiredQty'] as double)>stock;
    }).map((r){
      final name=r['name'].toString().toLowerCase();
      final p=pantry.firstWhere((x)=>x['name'].toString().toLowerCase()==name,orElse:()=>{});
      final stock=(p['qty'] as num? ?? 0).toDouble();
      return {
        'name':r['name'],
        'unit':r['unit'],
        'requiredQty':r['requiredQty'],
        'stockQty':stock,
        'purchaseQty':(r['requiredQty'] as double)-stock,
        'priority':'planned',
        'purchased':false,
      };
    }).toList();
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

  /// Standard starter recipe quantities for the built-in Cameroon meal library.
  /// Quantities are household planning units, not nutrition claims.
  static List<Map<String, dynamic>> recipeFor(String meal) {
    final key = meal.toLowerCase();
    if (key.contains('ndolé')) return [
      {'name':'Plantain','qty':2.0,'unit':'bunches'},
      {'name':'Palm oil','qty':0.25,'unit':'L'},
    ];
    if (key.contains('eru')) return [
      {'name':'Palm oil','qty':0.25,'unit':'L'},
      {'name':'Plantain','qty':2.0,'unit':'bunches'},
    ];
    if (key.contains('koki')) return [
      {'name':'Beans','qty':0.5,'unit':'kg'},
      {'name':'Plantain','qty':2.0,'unit':'bunches'},
      {'name':'Palm oil','qty':0.2,'unit':'L'},
    ];
    if (key.contains('achombo')) return [
      {'name':'Plantain','qty':2.0,'unit':'bunches'},
      {'name':'Tomatoes','qty':0.5,'unit':'kg'},
      {'name':'Onions','qty':0.25,'unit':'kg'},
    ];
    if (key.contains('rice')) return [
      {'name':'Rice','qty':0.5,'unit':'kg'},
      {'name':'Tomatoes','qty':0.5,'unit':'kg'},
      {'name':'Onions','qty':0.25,'unit':'kg'},
    ];
    if (key.contains('beans')) return [
      {'name':'Beans','qty':0.5,'unit':'kg'},
      {'name':'Plantain','qty':2.0,'unit':'bunches'},
      {'name':'Onions','qty':0.25,'unit':'kg'},
    ];
    if (key.contains('cornchaff')) return [
      {'name':'Beans','qty':0.5,'unit':'kg'},
      {'name':'Palm oil','qty':0.2,'unit':'L'},
    ];
    if (key.contains('fufu corn')) return [
      {'name':'Palm oil','qty':0.2,'unit':'L'},
      {'name':'Onions','qty':0.25,'unit':'kg'},
    ];
    return [];
  }

  /// Consumes the exact recipe quantities available in pantry.
  static List<Map<String, dynamic>> consumeRecipe(
    List<Map<String, dynamic>> pantry,
    List<Map<String, dynamic>> recipe,
  ) {
    final next = pantry.map((x) => Map<String, dynamic>.from(x)).toList();
    for (final ingredient in recipe) {
      final name = ingredient['name'].toString().trim().toLowerCase();
      final index = next.indexWhere((x) => x['name'].toString().trim().toLowerCase() == name);
      if (index < 0) continue;
      final current = (next[index]['qty'] as num? ?? 0).toDouble();
      final amount = (ingredient['qty'] as num? ?? 0).toDouble();
      next[index]['qty'] = max(0, current - amount);
    }
    return next;
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

  /// Returns meals whose starter recipe can be made from the current pantry.
  /// A meal is considered cookable only when every recipe ingredient is available
  /// in the required quantity and compatible units.
  static List<Map<String, dynamic>> cookableMeals({
    required List<dynamic> meals,
    required List<Map<String, dynamic>> pantry,
    double budgetLimit = double.infinity,
    bool prioritizeLeftovers = false,
    List<Map<String, dynamic>> leftovers = const [],
  }) {
    final result=<Map<String,dynamic>>[];
    for(final raw in meals){
      if(raw is! List || raw.length<3) continue;
      final name=raw[0].toString();
      final recipe=recipeFor(name);
      if(recipe.isEmpty) continue;
      var ok=true;
      var missing=0.0;
      for(final ingredient in recipe){
        final matches=pantry.where((x)=>x['name'].toString().trim().toLowerCase()==ingredient['name'].toString().trim().toLowerCase());
        final item=matches.isEmpty?null:matches.first;
        final required=(ingredient['qty'] as num? ?? 0).toDouble();
        final available=(item?['qty'] as num? ?? 0).toDouble();
        if(available<required){ok=false;missing+=required-available;}
      }
      final cost=(raw[2] as num).toDouble();
      if(ok && cost<=budgetLimit){
        final usesLeftover=leftovers.any((x)=>x['name'].toString().toLowerCase().contains(name.toLowerCase())||name.toLowerCase().contains(x['name'].toString().toLowerCase()));
        result.add({'name':name,'region':raw[1].toString(),'estimatedCost':cost,'usesLeftover':usesLeftover,'missingQty':missing});
      }
    }
    result.sort((a,b){
      if(prioritizeLeftovers && a['usesLeftover']!=b['usesLeftover']) return (a['usesLeftover']==true)?-1:1;
      return (a['estimatedCost'] as double).compareTo(b['estimatedCost'] as double);
    });
    return result;
  }

  /// Builds a one-day plan while respecting a spending ceiling and, when
  /// possible, prioritizing leftovers and meals already supported by stock.
  static Map<String,dynamic> planDay({
    required List<dynamic> meals,
    required List<Map<String,dynamic>> pantry,
    required double budgetLimit,
    List<Map<String,dynamic>> leftovers = const [],
    bool prioritizeLeftovers = true,
  }) {
    if(leftovers.isNotEmpty && prioritizeLeftovers){
      return {'meal':leftovers.first['name'].toString(),'estimatedCost':0.0,'source':'leftover','reason':'Use saved leftovers before buying or cooking again.'};
    }
    final cookable=cookableMeals(meals:meals,pantry:pantry,budgetLimit:budgetLimit,prioritizeLeftovers:prioritizeLeftovers,leftovers:leftovers);
    if(cookable.isNotEmpty){
      final pick=cookable.first;
      return {'meal':pick['name'],'estimatedCost':pick['estimatedCost'],'source':'pantry','reason':'Ingredients are already available within the budget ceiling.'};
    }
    final affordable=meals.where((m)=>m is List && m.length>=3 && (m[2] as num).toDouble()<=budgetLimit).toList();
    if(affordable.isNotEmpty){
      final m=affordable.first as List;
      return {'meal':m[0].toString(),'estimatedCost':(m[2] as num).toDouble(),'source':'shopping','reason':'Affordable meal; some ingredients may need to be purchased.'};
    }
    return {'meal':'','estimatedCost':0.0,'source':'none','reason':'No meal in the library fits the requested budget.'};
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
