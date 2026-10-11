import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visary/models/models.dart';
import 'package:visary/state/app_state.dart';

AppUser _user() => AppUser(
      id: 'u-test',
      name: 'Tester',
      email: 'tester@visary.io',
      quota: QuotaInfo(
        usedMinutes: 7,
        totalMinutes: 60,
        resetAt: DateTime.now().add(const Duration(days: 30)),
        planName: 'Pro Creator',
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('restoreSession tanpa sesi tersimpan -> user tetap null', () async {
    final state = AppState();
    await state.restoreSession();
    expect(state.user, isNull);
  });

  test('persistSession lalu restore di instance baru -> user kembali', () async {
    await AppState().persistSession(_user());

    final fresh = AppState();
    await fresh.restoreSession();
    expect(fresh.user, isNotNull);
    expect(fresh.user!.id, 'u-test');
    expect(fresh.user!.email, 'tester@visary.io');
    expect(fresh.user!.quota.usedMinutes, 7);
    expect(fresh.user!.quota.totalMinutes, 60);
    expect(fresh.user!.quota.planName, 'Pro Creator');
  });

  test('clearSession menghapus sesi tersimpan', () async {
    final state = AppState();
    await state.persistSession(_user());
    await state.clearSession();
    expect(state.user, isNull);

    final fresh = AppState();
    await fresh.restoreSession();
    expect(fresh.user, isNull);
  });
}
