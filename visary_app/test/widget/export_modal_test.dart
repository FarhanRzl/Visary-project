import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:visary/models/models.dart';
import 'package:visary/state/app_state.dart';
import 'package:visary/widgets/brutal.dart';
import 'package:visary/widgets/export_dialog.dart';

/// Helper: membuat AppState dengan project + clip dummy untuk test.
AppState _stateWithClip() {
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
    clips: [
      Clip(
        id: 'c_test',
        title: 'Clip Test',
        parts: const [ClipPart(0, 10)],
        hook: const ClipPart(0, 4),
        score: 85,
        reason: 'test',
        type: ClipType.linear,
      ),
    ],
  );
  state.projects.add(project);
  state.activeProjectId = 'p_test';
  return state;
}

Widget _wrap(Widget child, AppState state) => ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(home: Scaffold(body: child)),
    );

/// Desktop surface 1440x900 sesuai design spec (DESIGN-SPEC.md Layout Grid).
void _setDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
}

void main() {
  testWidgets('ExportModal menampilkan judul clip, durasi, dan skor',
      (tester) async {
    _setDesktopSurface(tester);
    addTearDown(tester.view.reset);

    final state = _stateWithClip();
    await tester.pumpWidget(_wrap(
      const ExportModal(projectId: 'p_test', clipId: 'c_test'),
      state,
    ));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('EXPORT CLIP'), findsOneWidget);
    expect(find.text('Clip Test'), findsOneWidget);
    expect(find.textContaining('10.0 detik'), findsOneWidget);
    expect(find.textContaining('skor 85'), findsOneWidget);
  });

  testWidgets('ExportModal toggle format 9:16 dan 1:1 bekerja',
      (tester) async {
    _setDesktopSurface(tester);
    addTearDown(tester.view.reset);

    final state = _stateWithClip();
    await tester.pumpWidget(_wrap(
      const ExportModal(projectId: 'p_test', clipId: 'c_test'),
      state,
    ));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.textContaining('1 FILE'), findsOneWidget);

    await tester.tap(find.textContaining('PERSEGI'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 FILE'), findsOneWidget);

    await tester.tap(find.textContaining('VERTIKAL'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 FILE'), findsOneWidget);
  });

  testWidgets('ExportModal menampilkan opsi disabled dengan label "segera"',
      (tester) async {
    _setDesktopSurface(tester);
    addTearDown(tester.view.reset);

    final state = _stateWithClip();
    await tester.pumpWidget(_wrap(
      const ExportModal(projectId: 'p_test', clipId: 'c_test'),
      state,
    ));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.textContaining('segera'), findsNWidgets(3));
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('ExportModal menampilkan folder tujuan dari path_provider',
      (tester) async {
    _setDesktopSurface(tester);
    addTearDown(tester.view.reset);

    final state = _stateWithClip();
    await tester.pumpWidget(_wrap(
      const ExportModal(projectId: 'p_test', clipId: 'c_test'),
      state,
    ));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.textContaining('UBAH'), findsOneWidget);
  });

  testWidgets('ExportModal menampilkan error bila clip tidak ditemukan',
      (tester) async {
    _setDesktopSurface(tester);
    addTearDown(tester.view.reset);

    final state = _stateWithClip();
    await tester.pumpWidget(_wrap(
      const ExportModal(projectId: 'p_test', clipId: 'clip_tidak_ada'),
      state,
    ));
    await tester.pumpAndSettle();

    expect(find.text('CLIP TIDAK DITEMUKAN'), findsOneWidget);
  });

  testWidgets('ExportModal tombol export disable saat tidak ada format dipilih',
      (tester) async {
    _setDesktopSurface(tester);
    addTearDown(tester.view.reset);

    final state = _stateWithClip();
    await tester.pumpWidget(_wrap(
      const ExportModal(projectId: 'p_test', clipId: 'c_test'),
      state,
    ));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.textContaining('VERTIKAL'));
    await tester.pumpAndSettle();

    expect(find.textContaining('0 FILE'), findsOneWidget);

    final btnFinder = find.ancestor(
      of: find.textContaining('MULAI EXPORT'),
      matching: find.byType(BButton),
    );
    final BButton widget = tester.widget(btnFinder);
    expect(widget.onTap, isNull);
  });
}
