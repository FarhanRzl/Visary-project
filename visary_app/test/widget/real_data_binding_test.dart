import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:visary/models/models.dart';
import 'package:visary/screens/clip_editor_screen.dart';
import 'package:visary/state/app_state.dart';

void main() {
  group('Real Data Binding Tests (PRD-08)', () {
    testWidgets('ClipEditorScreen binds real project name and duration instead of dummy data', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final appState = AppState();
      
      final realProject = Project(
        id: 'p-real-101',
        name: 'my_real_video.mp4',
        filePath: '/tmp/my_real_video.mp4',
        createdAt: DateTime.now(),
        probe: const VideoProbe(
          durationSec: 45.0,
          width: 1920,
          height: 1080,
          fps: 30.0,
          codec: 'h264',
          hasAudio: true,
        ),
      );

      appState.projects.add(realProject);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: appState,
          child: const MaterialApp(
            home: ClipEditorScreen(projectId: 'p-real-101'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that UI renders real project name and not hardcoded review-kopi.mp4
      expect(find.text('MY_REAL_VIDEO.MP4'), findsOneWidget);
      expect(find.textContaining('MY_REAL_VIDEO.MP4'), findsWidgets);
      expect(find.text('REVIEW KOPI KEKINIAN.MP4'), findsNothing);
    });
  });
}
