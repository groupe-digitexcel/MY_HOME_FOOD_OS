import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_home_food_os/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Budget editor opens from Reports', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const HomeFoodApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit budget').first);
    await tester.pumpAndSettle();
    expect(find.text('Your food budget companion'), findsOneWidget);
  });

  testWidgets('Storage Add stock opens the household item editor', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const HomeFoodApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Storage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add stock'));
    await tester.pumpAndSettle();
    expect(find.text('ADD HOUSEHOLD ITEM'), findsOneWidget);
  });
}
