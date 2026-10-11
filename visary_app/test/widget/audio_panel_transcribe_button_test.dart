import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:visary/models/models.dart';
import 'package:visary/state/app_state.dart';
import 'package:visary/widgets/audio_panel.dart';

/// PRD-SPRINT-13 §4 — Test 13.3: AudioPanel transcribe button visibility.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  AppState _state({AudioMode audioMode = AudioMode.replacement}) {
    final state = AppState();
    final project = Project(
      id: 'p_test',
      name: 'test_video.mp4',
      filePath: 'assets/videos/sample.mp4',
      createdAt: DateTime.now(),
      stage: JobStage.done,
      probe: const VideoProbe(
        durationSec: 20.0, width: 1080, height: 1920, fps: 30,
        codec: 'h264', hasAudio: true,
      ),
      clips: [],
      assets: [
        AssetItem(
          id: 'a_audio',
          type: AssetType.audio,
          title: 'replacement.mp3',
          sourceFile: 'test_audio.mp3',
          start: 0, end: 15,
          durationSec: 15, audioFormat: 'mp3',
        ),
      ],
      audioMode: audioMode,
      activeAudioAssetId: audioMode == AudioMode.replacement ? 'a_audio' : null,
    );
    state.projects.add(project);
    state.activeProjectId = 'p_test';
    return state;
  }

  Widget _wrap(Widget child, AppState state) => ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(home: Scaffold(body: child)),
      );

  void _setDesktopSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
  }

  testWidgets(
      'AudioPanel replacement mode: tombol TRANSCRIBE AUDIO visible',
      (tester) async {
    _setDesktopSurface(tester);
    addTearDown(tester.view.reset);

    final state = _state(audioMode: AudioMode.replacement);
    await tester.pumpWidget(_wrap(
      AudioPanel(
        projectId: 'p_test',
        onAudioChange: () async {},
      ),
      state,
    ));
    await tester.pumpAndSettle();

    expect(find.text('TRANSCRIBE AUDIO'), findsOneWidget);
    expect(find.text('TRANSKRIPSI AUDIO PENGGANTI'), findsOneWidget);
  });

  testWidgets(
      'AudioPanel original mode: tombol TRANSCRIBE AUDIO hidden',
      (tester) async {
    _setDesktopSurface(tester);
    addTearDown(tester.view.reset);

    final state = _state(audioMode: AudioMode.original);
    await tester.pumpWidget(_wrap(
      AudioPanel(
        projectId: 'p_test',
        onAudioChange: () async {},
      ),
      state,
    ));
    await tester.pumpAndSettle();

    expect(find.text('TRANSCRIBE AUDIO'), findsNothing);
    expect(find.text('TRANSKRIPSI AUDIO PENGGANTI'), findsNothing);
  });

  testWidgets(
      'AudioPanel muted mode: tombol TRANSCRIBE AUDIO hidden',
      (tester) async {
    _setDesktopSurface(tester);
    addTearDown(tester.view.reset);

    final state = _state(audioMode: AudioMode.muted);
    await tester.pumpWidget(_wrap(
      AudioPanel(
        projectId: 'p_test',
        onAudioChange: () async {},
      ),
      state,
    ));
    await tester.pumpAndSettle();

    expect(find.text('TRANSCRIBE AUDIO'), findsNothing);
  });
}
