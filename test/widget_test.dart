import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cth_mobile/main.dart';

void main() {
  testWidgets('CTH Mobile app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(CTHMobileApp());

    // Verify that the splash screen appears
    expect(find.text('CTH Mobile'), findsOneWidget);
    expect(find.text('Cargando...'), findsOneWidget);
  });
}
