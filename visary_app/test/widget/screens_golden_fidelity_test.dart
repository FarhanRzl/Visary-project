import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:visary/models/models.dart';
import 'package:visary/screens/clip_editor_screen.dart';
import 'package:visary/screens/dashboard_screen.dart';
import 'package:visary/screens/login_screen.dart';
import 'package:visary/screens/settings_screen.dart';
import 'package:visary/screens/upload_screen.dart';
import 'package:visary/state/app_state.dart';
import 'package:visary/theme/tokens.dart';

/// Screen Golden Fidelity Test (PRD-SPRINT-07 §4 Test 7.2).
/// Pump widget untuk masing-masing layar utama dan verifikasi:
/// - rendering sesuai spesifikasi pen.dev (elemen kunci ada)
/// - scaffold background = VC.bg (tidak ada hardcoded color)
void setDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
}

AppState _stateWithProject() {
  final state = AppState();
  state.user = AppUser(
    id: 'u1', name: 'Farhan', email: 'farhan@visary.ai',
    quota: QuotaInfo(usedMinutes: 10, totalMinutes: 60,
        resetAt: DateTime.now(), planName: 'Pro'),
  );
  state.projects.add(Project(
    id: 'p_test', name: 'test_video.mp4', filePath: 'assets/videos/sample.mp4',
    createdAt: DateTime.now(), stage: JobStage.done, progress: 1,
    probe: const VideoProbe(durationSec: 60, width: 1920, height: 1080,
        fps: 30, codec: 'h264', hasAudio: true),
    clips: [Clip(id: 'c0', title: 'Clip 1', parts: const [ClipPart(0, 35)],
        hook: const ClipPart(0, 4), score: 85, reason: 'test',
        type: ClipType.linear)],
  ));
  state.activeProjectId = 'p_test';
  return state;
}

Widget _wrap(Widget child, AppState state) => ChangeNotifierProvider.value(
      value: state, child: MaterialApp(home: child),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('1. Login Screen renders with VC tokens', (tester) async {
    setDesktopSurface(tester); addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(const LoginScreen(), AppState()));
    await tester.pumpAndSettle();
    expect(find.text('VISARY'), findsOneWidget);
    expect(find.textContaining('CLIP VIRAL'), findsOneWidget);
    expect(find.text('MASUK'), findsOneWidget);
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, VC.bg);
  });

  testWidgets('2. Dashboard renders project card + metadata', (tester) async {
    setDesktopSurface(tester); addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(const DashboardScreen(), _stateWithProject()));
    await tester.pumpAndSettle();
    expect(find.text('PROJECTS'), findsOneWidget);
    expect(find.text('test_video.mp4'), findsWidgets);
    expect(find.textContaining('1920'), findsWidgets);
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, VC.bg);
  });

  testWidgets('3. Upload Screen renders dropzone', (tester) async {
    setDesktopSurface(tester); addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(const UploadScreen(), _stateWithProject()));
    await tester.pumpAndSettle();
    expect(find.textContaining('DROP'), findsWidgets);
  });

  testWidgets('4. Clip Editor renders timeline + clips', (tester) async {
    setDesktopSurface(tester); addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(ClipEditorScreen(projectId: 'p_test'), _stateWithProject()));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('CLIPS'), findsWidgets);
    expect(find.textContaining('TIMELINE'), findsWidgets);
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, VC.bg);
  });

  testWidgets('5. Settings Screen renders BYOK panel', (tester) async {
    setDesktopSurface(tester); addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(const SettingsScreen(), _stateWithProject()));
    await tester.pumpAndSettle();
    final byokTab = find.text('API KEYS (BYOK)');
    expect(byokTab, findsOneWidget);
    await tester.tap(byokTab);
    await tester.pumpAndSettle();
    expect(find.text('BRING YOUR OWN KEY (BYOK)'), findsOneWidget);
  });

  testWidgets('6. Dashboard empty state renders', (tester) async {
    setDesktopSurface(tester); addTearDown(tester.view.reset);
    final state = AppState();
    state.user = AppUser(id: 'u1', name: 'F', email: 'f@v.ai',
        quota: QuotaInfo(usedMinutes: 0, totalMinutes: 60,
            resetAt: DateTime.now(), planName: 'Free'));
    await tester.pumpWidget(_wrap(const DashboardScreen(), state));
    await tester.pumpAndSettle();
    expect(find.text('Tidak ada project'), findsOneWidget);
  });

  testWidgets('7. Login scaffold bg != hardcoded 0xFFFFF8E7', (tester) async {
    setDesktopSurface(tester); addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(const LoginScreen(), AppState()));
    await tester.pumpAndSettle();
    final bg = tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor;
    expect(bg, VC.bg);
    expect(bg, isNot(const Color(0xFFFFF8E7)),
        reason: 'Harus pakai VC.bg (#FFF4E0), bukan hardcoded #FFF8E7');
  });
}
