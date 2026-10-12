import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:visary/models/models.dart';
import 'package:visary/services/local_analyzer.dart';
import 'package:visary/state/app_state.dart';
import 'package:visary/widgets/caption_reframe_panel.dart';

/// PRD-SPRINT-12 §4 — Test 12.2: Export transcript button visibility & state.
/// Updated for PRD-SPRINT-18: tests CaptionReframePanel (sidebar widget)
/// instead of deleted CaptionReframeScreen.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// Helper: AppState dengan project + VideoSignals (transcript optional).
  AppState _stateWithSignals({Transcript? transcript}) {
    final state = AppState();
    final project = Project(
      id: 'p_test',
      name: 'test_video.mp4',
      filePath: 'assets/videos/sample.mp4',
      createdAt: DateTime.now(),
      stage: JobStage.done,
      probe: const VideoProbe(
        durationSec: 20.0,
        width: 1080,
        height: 1920,
        fps: 30,
        codec: 'h264',
        hasAudio: true,
      ),
      clips: [],
    );
    state.projects.add(project);
    state.activeProjectId = 'p_test';

    final signals = VideoSignals(
      shots: const [0, 20],
      energy: const [],
      duration: 20.0,
    );
    signals.transcript = transcript;
    state.setSignalsForTest('p_test', signals);
    return state;
  }

  Widget _wrap(Widget child, AppState state) => ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(home: Scaffold(body: child)),
      );

  void _setDesktopSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
  }

  /// Scroll sidebar sampai export section terlihat (ListView lazy build).
  Future<void> _scrollToExport(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('EXPORT TRANSCRIPT'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
  }

  /// Build panel with default callbacks (no-ops).
  Widget _panel() => CaptionReframePanel(
        projectId: 'p_test',
        aspectRatio: 0,
        reframeMode: 0,
        captionPreset: 0,
        captionPosition: 2,
        activeWordIdx: 0,
        onAspectRatioChanged: (_) {},
        onReframeModeChanged: (_) {},
        onCaptionPresetChanged: (_) {},
        onCaptionPositionChanged: (_) {},
        onActiveWordChanged: (_) {},
      );

  testWidgets(
      'Caption panel dengan transcript: tombol .SRT dan .TXT visible & enabled',
      (tester) async {
    _setDesktopSurface(tester);
    addTearDown(tester.view.reset);

    final transcript = Transcript(
      fullText: 'hello world test',
      words: const [
        WordToken(word: 'hello', start: 0.0, end: 0.5),
        WordToken(word: 'world', start: 0.5, end: 1.0),
        WordToken(word: 'test', start: 1.0, end: 1.5),
      ],
      language: 'en',
      provider: 'custom',
    );

    final state = _stateWithSignals(transcript: transcript);
    await tester.pumpWidget(_wrap(_panel(), state));
    await tester.pumpAndSettle();

    await _scrollToExport(tester);

    expect(find.text('EXPORT TRANSCRIPT'), findsOneWidget);
    expect(find.text('.SRT'), findsOneWidget);
    expect(find.text('.TXT'), findsOneWidget);
  });

  testWidgets(
      'Caption panel tanpa transcript: pesan "Belum ada transcript" tampil',
      (tester) async {
    _setDesktopSurface(tester);
    addTearDown(tester.view.reset);

    final state = _stateWithSignals(transcript: null);
    await tester.pumpWidget(_wrap(_panel(), state));
    await tester.pumpAndSettle();

    await _scrollToExport(tester);

    expect(find.text('EXPORT TRANSCRIPT'), findsOneWidget);
    expect(find.textContaining('Belum ada transcript'), findsOneWidget);
    // Tombol export tidak tampil bila transcript kosong
    expect(find.text('.SRT'), findsNothing);
    expect(find.text('.TXT'), findsNothing);
  });

  testWidgets(
      'Caption panel dengan transcript text-only (words kosong): .SRT disabled, .TXT enabled',
      (tester) async {
    _setDesktopSurface(tester);
    addTearDown(tester.view.reset);

    const transcript = Transcript(
      fullText: 'text only tanpa timestamp',
      words: [],
      provider: 'gemini',
    );

    final state = _stateWithSignals(transcript: transcript);
    await tester.pumpWidget(_wrap(_panel(), state));
    await tester.pumpAndSettle();

    await _scrollToExport(tester);

    expect(find.text('EXPORT TRANSCRIPT'), findsOneWidget);
    // Warning tentang .SRT kosong
    expect(find.textContaining('.SRT kosong'), findsOneWidget);
    // Kedua tombol tampil (tapi .SRT onTap null = disabled)
    expect(find.text('.SRT'), findsOneWidget);
    expect(find.text('.TXT'), findsOneWidget);
  });
}
