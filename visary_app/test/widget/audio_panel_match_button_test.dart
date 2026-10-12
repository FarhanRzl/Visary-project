import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:visary/models/models.dart';
import 'package:visary/services/local_analyzer.dart';
import 'package:visary/state/app_state.dart';
import 'package:visary/widgets/audio_panel.dart';

/// PRD-SPRINT-14 §4 — Test 14.5: AudioPanel MATCH CONTENT button visibility.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  AppState _state({
    AudioMode audioMode = AudioMode.replacement,
    bool withTranscript = true,
  }) {
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

    // Set signals with transcript if needed.
    if (withTranscript) {
      final signals = VideoSignals(
        shots: const [0, 5, 10, 15, 20],
        energy: const [],
        duration: 20,
      );
      signals.transcript = Transcript(
        fullText: 'hello world this is a test transcript',
        words: const [
          WordToken(word: 'hello', start: 0.0, end: 0.5),
          WordToken(word: 'world', start: 0.6, end: 1.0),
          WordToken(word: 'this', start: 1.1, end: 1.3),
          WordToken(word: 'is', start: 1.4, end: 1.5),
          WordToken(word: 'a', start: 1.6, end: 1.7),
          WordToken(word: 'test', start: 1.8, end: 2.0),
          WordToken(word: 'transcript', start: 2.1, end: 2.5),
        ],
        provider: 'custom',
      );
      state.setSignalsForTest('p_test', signals);
    } else {
      final signals = VideoSignals(
        shots: const [0, 5, 10, 15, 20],
        energy: const [],
        duration: 20,
      );
      state.setSignalsForTest('p_test', signals);
    }

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
      'MATCH CONTENT button visible saat transcript + replacement aktif',
      (tester) async {
    _setDesktopSurface(tester);
    addTearDown(tester.view.reset);

    final state = _state(audioMode: AudioMode.replacement, withTranscript: true);
    await tester.pumpWidget(_wrap(
      AudioPanel(
        projectId: 'p_test',
        onAudioChange: () async {},
      ),
      state,
    ));
    await tester.pumpAndSettle();

    expect(find.text('MATCH CONTENT'), findsOneWidget);
    expect(find.text('CONTENT-AWARE MATCHING'), findsOneWidget);
  });

  testWidgets(
      'MATCH CONTENT button hidden bila transcript kosong',
      (tester) async {
    _setDesktopSurface(tester);
    addTearDown(tester.view.reset);

    final state =
        _state(audioMode: AudioMode.replacement, withTranscript: false);
    await tester.pumpWidget(_wrap(
      AudioPanel(
        projectId: 'p_test',
        onAudioChange: () async {},
      ),
      state,
    ));
    await tester.pumpAndSettle();

    expect(find.text('MATCH CONTENT'), findsNothing);
    expect(find.text('CONTENT-AWARE MATCHING'), findsNothing);
  });

  testWidgets(
      'MATCH CONTENT button hidden bila mode original (bukan replacement)',
      (tester) async {
    _setDesktopSurface(tester);
    addTearDown(tester.view.reset);

    final state = _state(audioMode: AudioMode.original, withTranscript: true);
    await tester.pumpWidget(_wrap(
      AudioPanel(
        projectId: 'p_test',
        onAudioChange: () async {},
      ),
      state,
    ));
    await tester.pumpAndSettle();

    expect(find.text('MATCH CONTENT'), findsNothing);
    expect(find.text('CONTENT-AWARE MATCHING'), findsNothing);
  });

  testWidgets(
      'MATCH CONTENT button hidden bila mode muted',
      (tester) async {
    _setDesktopSurface(tester);
    addTearDown(tester.view.reset);

    final state = _state(audioMode: AudioMode.muted, withTranscript: true);
    await tester.pumpWidget(_wrap(
      AudioPanel(
        projectId: 'p_test',
        onAudioChange: () async {},
      ),
      state,
    ));
    await tester.pumpAndSettle();

    expect(find.text('MATCH CONTENT'), findsNothing);
  });

  testWidgets(
      'MATCH CONTENT button has Icons.compare icon',
      (tester) async {
    _setDesktopSurface(tester);
    addTearDown(tester.view.reset);

    final state = _state(audioMode: AudioMode.replacement, withTranscript: true);
    await tester.pumpWidget(_wrap(
      AudioPanel(
        projectId: 'p_test',
        onAudioChange: () async {},
      ),
      state,
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.compare), findsOneWidget);
  });
}
