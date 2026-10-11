import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visary/models/models.dart';
import 'package:visary/services/ai_provider_service.dart';
import 'package:visary/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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

  group('Custom OpenAI-compatible provider (PRD-SPRINT-11)', () {
    test('testConnection custom success (GET {baseUrl}/models, 200)', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString().endsWith('/models')) {
          return http.Response('{"data": []}', 200);
        }
        return http.Response('err', 404);
      });
      final service = AiProviderService(httpClient: mockClient);
      final res = await service.testConnection(
        AiProviderType.custom,
        'tok_live_key',
        baseUrl: 'https://tokonomix.ai/api/v1',
      );
      expect(res.success, isTrue);
      expect(res.statusCode, 200);
    });

    test('testConnection custom tanpa baseUrl gagal', () async {
      final service = AiProviderService(
        httpClient: MockClient((_) async => http.Response('', 200)),
      );
      final res =
          await service.testConnection(AiProviderType.custom, 'tok_live_key');
      expect(res.success, isFalse);
      expect(res.message, contains('Base URL wajib'));
    });

    test('testConnection custom invalid key (HTTP 401)', () async {
      final mockClient =
          MockClient((_) async => http.Response('{"error":"unauthorized"}', 401));
      final service = AiProviderService(httpClient: mockClient);
      final res = await service.testConnection(
        AiProviderType.custom,
        'bad',
        baseUrl: 'https://tokonomix.ai/api/v1',
      );
      expect(res.success, isFalse);
      expect(res.statusCode, 401);
    });

    test('sendPrompt custom POST {baseUrl}/chat/completions', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(),
            'https://tokonomix.ai/api/v1/chat/completions');
        expect(request.headers['Authorization'], 'Bearer tok_live_key');
        return http.Response(
          '{"choices":[{"message":{"content":"Saran B-roll custom"}}]}',
          200,
        );
      });
      final storage = SecureKeyStorage();
      await storage.saveCustomKey('tok_live_key');
      await storage.saveCustomBaseUrl('https://tokonomix.ai/api/v1');
      await storage.saveCustomModel('gpt-4o-mini');
      await storage.setByokEnabled(true);
      await storage.setActiveProvider(AiProviderType.custom);

      final service = AiProviderService(storage: storage, httpClient: mockClient);
      expect(await service.isByokActive(), isTrue);
      final out = await service.sendPrompt(prompt: 'Buat B-roll');
      expect(out, 'Saran B-roll custom');
    });

    test('isByokActive custom false bila base URL kosong', () async {
      final storage = SecureKeyStorage();
      await storage.saveCustomKey('tok_live_key');
      await storage.setByokEnabled(true);
      await storage.setActiveProvider(AiProviderType.custom);
      final service = AiProviderService(storage: storage);
      expect(await service.isByokActive(), isFalse);
    });
  });

  group('ASR transcribe (PRD-SPRINT-11)', () {
    test('transcribe verbose_json dengan word timestamps', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(),
            'https://tokonomix.ai/api/v1/audio/transcriptions');
        expect(request.headers['Authorization'], 'Bearer tok_live_key');
        return http.Response(
          '{"text":"hello world","language":"en",'
          '"words":[{"word":"hello","start":0.0,"end":0.5},'
          '{"word":"world","start":0.5,"end":1.0}]}',
          200,
        );
      });
      final storage = SecureKeyStorage();
      await storage.saveCustomKey('tok_live_key');
      await storage.saveCustomBaseUrl('https://tokonomix.ai/api/v1');
      await storage.setByokEnabled(true);
      await storage.setActiveProvider(AiProviderType.custom);
      final service = AiProviderService(storage: storage, httpClient: mockClient);

      final tmpDir = await Directory.systemTemp.createTemp('visary_asr_');
      final audioFile = File('${tmpDir.path}/a.mp3');
      await audioFile.writeAsString('fake-audio');
      try {
        final t = await service.transcribe(audioFilePath: audioFile.path);
        expect(t.fullText, 'hello world');
        expect(t.words.length, 2);
        expect(t.words.first.word, 'hello');
        expect(t.words.first.start, 0.0);
        expect(t.words.last.end, 1.0);
        expect(t.language, 'en');
        expect(t.provider, 'custom');
      } finally {
        await tmpDir.delete(recursive: true);
      }
    });

    test('transcribe response text-only (words kosong)', () async {
      final mockClient = MockClient((_) async =>
          http.Response('{"text":"hanya teks","language":"id"}', 200));
      final storage = SecureKeyStorage();
      await storage.saveCustomKey('tok_live_key');
      await storage.saveCustomBaseUrl('https://tokonomix.ai/api/v1');
      await storage.setByokEnabled(true);
      await storage.setActiveProvider(AiProviderType.custom);
      final service = AiProviderService(storage: storage, httpClient: mockClient);

      final tmpDir = await Directory.systemTemp.createTemp('visary_asr_txt_');
      final audioFile = File('${tmpDir.path}/a.mp3');
      await audioFile.writeAsString('fake');
      try {
        final t = await service.transcribe(audioFilePath: audioFile.path);
        expect(t.fullText, 'hanya teks');
        expect(t.words, isEmpty);
        expect(t.language, 'id');
      } finally {
        await tmpDir.delete(recursive: true);
      }
    });

    test('transcribe fallback empty bila BYOK off', () async {
      final service = AiProviderService(
        httpClient: MockClient((_) async => http.Response('', 200)),
      );
      final tmpDir = await Directory.systemTemp.createTemp('visary_asr_off_');
      final audioFile = File('${tmpDir.path}/a.mp3');
      await audioFile.writeAsString('fake');
      try {
        final t = await service.transcribe(audioFilePath: audioFile.path);
        expect(t.isEmpty, isTrue);
        expect(t.provider, 'server');
      } finally {
        await tmpDir.delete(recursive: true);
      }
    });
  });
}
