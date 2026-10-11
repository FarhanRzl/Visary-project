import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:visary/screens/clip_editor_screen.dart';
import 'package:visary/screens/hook_finder_screen.dart';
import 'package:visary/state/app_state.dart';

void main() {
  group('Empty State Safety Tests (PRD-08)', () {
    testWidgets('ClipEditorScreen handles empty project list without crash', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final appState = AppState();
      
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: appState,
          child: const MaterialApp(
            home: ClipEditorScreen(projectId: 'non-existent-id'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('PROJECT TIDAK DITEMUKAN'), findsOneWidget);
      expect(find.text('KEMBALI KE DASHBOARD'), findsOneWidget);
    });

    testWidgets('HookFinderScreen handles empty project list without crash', (WidgetTester tester) async {
      final appState = AppState();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: appState,
          child: const MaterialApp(
            home: HookFinderScreen(projectId: 'non-existent-id'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('PROJECT TIDAK DITEMUKAN'), findsOneWidget);
      expect(find.text('KEMBALI KE DASHBOARD'), findsOneWidget);
    });
  });
}
