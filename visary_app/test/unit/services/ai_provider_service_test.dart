import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:visary/models/models.dart';
import 'package:visary/services/ai_provider_service.dart';
import 'package:visary/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('AiProviderService connection tests', () {
    test('Gemini testConnection success (HTTP 200)', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('models?key=AIzaValidKey')) {
          return http.Response('{"models": []}', 200);
        }
        return http.Response('{"error": "Unauthorized"}', 400);
      });

      final service = AiProviderService(httpClient: mockClient);
      final res = await service.testConnection(AiProviderType.gemini, 'AIzaValidKey');

      expect(res.success, isTrue);
      expect(res.statusCode, 200);
    });

    test('Gemini testConnection invalid key (HTTP 400)', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": "API key not valid"}', 400);
      });

      final service = AiProviderService(httpClient: mockClient);
      final res = await service.testConnection(AiProviderType.gemini, 'bad-key');

      expect(res.success, isFalse);
      expect(res.statusCode, 400);
      expect(res.message, contains('tidak valid'));
    });

    test('OpenAI testConnection invalid key (HTTP 401)', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": {"message": "Invalid API key"}}', 401);
      });

      final service = AiProviderService(httpClient: mockClient);
      final res = await service.testConnection(AiProviderType.openai, 'sk-invalid');

      expect(res.success, isFalse);
      expect(res.statusCode, 401);
      expect(res.message, contains('HTTP 401'));
    });

    test('OpenAI testConnection rate limit (HTTP 429)', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": {"message": "Rate limit exceeded"}}', 429);
      });

      final service = AiProviderService(httpClient: mockClient);
      final res = await service.testConnection(AiProviderType.openai, 'sk-ratelimit');

      expect(res.success, isFalse);
      expect(res.statusCode, 429);
      expect(res.message, contains('HTTP 429'));
    });
  });

  group('AiProviderService routing & prompt inference', () {
    test('Direct HTTP prompt call saat BYOK aktif dengan Gemini', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('gemini-1.5-flash:generateContent')) {
          return http.Response(
            '{"candidates": [{"content": {"parts": [{"text": "Saran B-roll: Bunga mekar"}]}}]}',
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final storage = SecureKeyStorage();
      await storage.saveGeminiKey('AIzaTestKey');
      await storage.setByokEnabled(true);
      await storage.setActiveProvider(AiProviderType.gemini);

      final service = AiProviderService(storage: storage, httpClient: mockClient);
      expect(await service.isByokActive(), isTrue);

      final output = await service.sendPrompt(prompt: 'Buat prompt B-roll');
      expect(output, 'Saran B-roll: Bunga mekar');
    });

    test('AppState.useQuota memotong kuota saat BYOK nonaktif, dan bypass saat BYOK aktif', () async {
      final appState = AppState();
      appState.user = AppUser(
        id: 'u1',
        name: 'Test',
        email: 't@v.ai',
        quota: QuotaInfo(
          usedMinutes: 50,
          totalMinutes: 60,
          resetAt: DateTime.now(),
          planName: 'Free',
        ),
      );

      // Skenario 1: BYOK nonaktif -> potong kuota (50 + 5 = 55)
      expect(appState.useQuota(5), isTrue);
      expect(appState.user!.quota.usedMinutes, 55);

      // Skenario 2: Kuota habis (55 + 10 > 60) -> returns false
      expect(appState.useQuota(10), isFalse);

      // Skenario 3: BYOK aktif -> bypass potong kuota (tetap true walau melebihi 60)
      appState.byokEnabled = true;
      appState.activeAiProvider = AiProviderType.gemini;
      expect(appState.useQuota(20), isTrue);
      expect(appState.user!.quota.usedMinutes, 55, reason: 'Kuota server tidak terpotong saat BYOK');
    });
  });
}
