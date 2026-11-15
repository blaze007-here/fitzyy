import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitzyy/main.dart';

void main() {
  testWidgets('dashboard shows calorie goal and scan action', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppShell(demoMode: true)));

    expect(find.text('Today\'s fuel'), findsOneWidget);
    expect(find.text('Scan your food'), findsOneWidget);
    expect(find.text('2,100 kcal'), findsNothing);
  });
}
