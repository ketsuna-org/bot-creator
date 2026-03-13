import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bot_creator/main.dart';
import 'package:bot_creator/utils/i18n.dart';
import 'package:bot_creator/utils/onboarding_manager.dart';

void main() {
  testWidgets('MyApp renders with required providers', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          Provider(create: (_) => OnboardingManager(prefs)),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MyApp), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
  });
}
