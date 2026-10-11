import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:visary/main.dart';
import 'package:visary/state/app_state.dart';

void main() {
  testWidgets('VisaryApp launches with empty AppState (no login)',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const VisaryApp(),
      ),
    );

    // Verify Visary texts dan LoginScreen adalah route pertama
    expect(find.text('VISARY'), findsWidgets);
    expect(find.text('MASUK'), findsOneWidget);
  });
}
