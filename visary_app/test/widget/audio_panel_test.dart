import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:visary/models/models.dart';
import 'package:visary/state/app_state.dart';
import 'package:visary/widgets/audio_panel.dart';

/// PRD-SPRINT-10 §4 — Test 10.4: AudioPanel widget.
Future<void> _noop() async {}

void main() {
  late AppState state;
  const audioAsset = AssetItem(
    id: 'a_au1',
    type: AssetType.audio,
    title: 'music.mp3',
    sourceFile: '/tmp/music.mp3',
    start: 0,
    end: 30,
    durationSec: 30,
    audioFormat: 'mp3',
  );

  setUp(() {
    state = AppState();
    state.projects.add(Project(
      id: 'p1',
      name: 'test.mp4',
      filePath: '/videos/test.mp4',
      createdAt: DateTime(2026),
      probe: const VideoProbe(
        durationSec: 60,
        width: 1920,
        height: 1080,
        fps: 30,
        codec: 'h264',
        hasAudio: true,
      ),
      stage: JobStage.done,
      progress: 1,
      assets: const [audioAsset],
    ));
  });

  Future<void> pumpPanel(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(
          home: Scaffold(
            body: AudioPanel(
              projectId: 'p1',
              onAudioChange: _noop,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('render: mode chip AUDIO ASLI + aset audio terlisting dengan PAKAI',
      (tester) async {
    await pumpPanel(tester);
    expect(find.text('AUDIO TRACK'), findsOneWidget);
    expect(find.text('AUDIO ASLI'), findsOneWidget);
    expect(find.text('music.mp3'), findsOneWidget);
    expect(find.text('PAKAI'), findsOneWidget);
  });

  testWidgets('mute toggle → mode MUTED', (tester) async {
    await pumpPanel(tester);
    expect(find.text('MUTE AUDIO'), findsOneWidget);
    await tester.tap(find.text('MUTE AUDIO'));
    await tester.pumpAndSettle();
    expect(state.byId('p1')!.audioMode, AudioMode.muted);
    expect(find.text('MUTED'), findsOneWidget);
  });

  testWidgets('PAKAI aset → mode REPLACEMENT + activeAudioAssetId', (tester) async {
    await pumpPanel(tester);
    await tester.tap(find.text('PAKAI'));
    await tester.pumpAndSettle();
    expect(state.byId('p1')!.audioMode, AudioMode.replacement);
    expect(state.byId('p1')!.activeAudioAssetId, 'a_au1');
    expect(find.text('REPLACEMENT'), findsOneWidget);
  });
}
