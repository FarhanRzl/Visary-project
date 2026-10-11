import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visary/models/models.dart';
import 'package:visary/screens/settings_screen.dart';
import 'package:visary/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('SettingsScreen BYOK UI menampilkan toggle provider dan tombol tes koneksi',
      (tester) async {
    final appState = AppState();
    appState.user = AppUser(
      id: 'u1',
      name: 'Farhan',
      email: 'farhan@visary.ai',
      quota: QuotaInfo(
        usedMinutes: 10,
        totalMinutes: 60,
        resetAt: DateTime.now(),
        planName: 'Pro',
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: appState,
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );

    // Buka panel BYOK di sidebar
    final byokTab = find.text('API KEYS (BYOK)');
    expect(byokTab, findsOneWidget);
    await tester.tap(byokTab);
    await tester.pumpAndSettle();

    // Verifikasi judul & elemen kunci
    expect(find.text('BRING YOUR OWN KEY (BYOK)'), findsOneWidget);
    expect(find.text('MODE AI PROVIDER'), findsOneWidget);
    expect(find.text('GEMINI API'), findsOneWidget);
    expect(find.text('OPENAI API'), findsOneWidget);

    // Verifikasi tombol TES KONEKSI (3 provider fixed + 1 custom = 4)
    expect(find.text('TES KONEKSI'), findsNWidgets(4));

    // Verifikasi tombol SIMPAN KONFIGURASI API
    expect(find.text('SIMPAN KONFIGURASI API'), findsOneWidget);
  });
}
