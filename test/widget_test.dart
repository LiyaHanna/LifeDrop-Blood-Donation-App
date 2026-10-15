import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifedrop_public/screens/welcome_screen.dart';


void main() {
  testWidgets('Register screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: WelcomeScreen()),
    );

    expect(find.text('Create LifeDrop Account'), findsOneWidget);
    expect(find.text('Complete Registration'), findsOneWidget);
  });
}
