import 'package:flutter_test/flutter_test.dart';
import 'package:visary/models/models.dart';
import 'package:visary/services/local_analyzer.dart';
import 'package:visary/state/app_state.dart';

void main() {
  group('Prompt Filter Execution Tests (PRD-08)', () {
    test('AppState.regenerateClips filters clips within requested duration target', () {
      final appState = AppState();

      final mockProject = Project(
        id: 'p-prompt-1',
        name: 'prompt_test.mp4',
        filePath: '/tmp/prompt_test.mp4',
        createdAt: DateTime.now(),
        probe: const VideoProbe(
          durationSec: 180.0,
          width: 1920,
          height: 1080,
          fps: 30.0,
          codec: 'h264',
          hasAudio: true,
        ),
      );

      appState.projects.add(mockProject);
      
      // Inject signals cache
      appState.setSignalsForTest(
        'p-prompt-1',
        VideoSignals(
          shots: [0.0, 10.0, 25.0, 45.0, 80.0, 120.0, 180.0],
          energy: [],
          duration: 180.0,
        ),
      );

      appState.regenerateClips('p-prompt-1', targetMin: 30, targetMax: 40);

      final updated = appState.byId('p-prompt-1');
      expect(updated, isNotNull);
      expect(updated!.clips, isNotEmpty);
    });
  });
}
