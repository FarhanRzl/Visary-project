import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:visary/services/ai_provider_service.dart';

/// PRD-SPRINT-14 §4 — Test 14.1: Vision API (visionPrompt).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('visionPrompt — Gemini', () {
    test('parse response text dari Gemini inline_data', () async {
      final mockClient = MockClient((request) async {
        expect(
            request.url.toString().contains('generateContent'), isTrue);
        return http.Response(
          '{"candidates": [{"content": {"parts": [{"text": "A person walking on a beach at sunset"}]}}]}',
          200,
        );
      });

      final storage = SecureKeyStorage();
      await storage.saveGeminiKey('AIzaTestKey');
      await storage.setByokEnabled(true);
      await storage.setActiveProvider(AiProviderType.gemini);

      final service = AiProviderService(storage: storage, httpClient: mockClient);
      final desc = await service.visionPrompt(
        prompt: 'Describe this image.',
        imageBase64: 'dGVzdA==',
      );

      expect(desc, 'A person walking on a beach at sunset');
    });

    test('kirim inline_data dengan mime_type dan data base64', () async {
      String? capturedBody;
      final mockClient = MockClient((request) async {
        capturedBody = request.body;
        return http.Response(
          '{"candidates": [{"content": {"parts": [{"text": "desc"}]}}]}',
          200,
        );
      });

      final storage = SecureKeyStorage();
      await storage.saveGeminiKey('AIzaTestKey');
      await storage.setByokEnabled(true);
      await storage.setActiveProvider(AiProviderType.gemini);

      final service = AiProviderService(storage: storage, httpClient: mockClient);
      await service.visionPrompt(
        prompt: 'Describe.',
        imageBase64: 'dGVzdA==',
        mimeType: 'image/png',
      );

      expect(capturedBody, isNotNull);
      expect(capturedBody, contains('inline_data'));
      expect(capturedBody, contains('image/png'));
      expect(capturedBody, contains('dGVzdA=='));
    });

    test('HTTP error → throw Exception', () async {
      final mockClient = MockClient((_) async =>
          http.Response('{"error": "bad request"}', 400));

      final storage = SecureKeyStorage();
      await storage.saveGeminiKey('AIzaTestKey');
      await storage.setByokEnabled(true);
      await storage.setActiveProvider(AiProviderType.gemini);

      final service = AiProviderService(storage: storage, httpClient: mockClient);
      expect(
        () => service.visionPrompt(
          prompt: 'test',
          imageBase64: 'dGVzdA==',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('visionPrompt — OpenAI', () {
    test('parse response text dari OpenAI image_url', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(),
            'https://api.openai.com/v1/chat/completions');
        expect(request.headers['Authorization'], 'Bearer sk-test-key');
        return http.Response(
          '{"choices": [{"message": {"content": "Coffee being poured into a cup"}}]}',
          200,
        );
      });

      final storage = SecureKeyStorage();
      await storage.saveOpenAiKey('sk-test-key');
      await storage.setByokEnabled(true);
      await storage.setActiveProvider(AiProviderType.openai);

      final service = AiProviderService(storage: storage, httpClient: mockClient);
      final desc = await service.visionPrompt(
        prompt: 'Describe.',
        imageBase64: 'dGVzdA==',
      );

      expect(desc, 'Coffee being poured into a cup');
    });

    test('kirim image_url dengan data URI', () async {
      String? capturedBody;
      final mockClient = MockClient((request) async {
        capturedBody = request.body;
        return http.Response(
          '{"choices": [{"message": {"content": "desc"}}]}',
          200,
        );
      });

      final storage = SecureKeyStorage();
      await storage.saveOpenAiKey('sk-test-key');
      await storage.setByokEnabled(true);
      await storage.setActiveProvider(AiProviderType.openai);

      final service = AiProviderService(storage: storage, httpClient: mockClient);
      await service.visionPrompt(
        prompt: 'Describe.',
        imageBase64: 'dGVzdA==',
        mimeType: 'image/jpeg',
      );

      expect(capturedBody, isNotNull);
      expect(capturedBody, contains('image_url'));
      expect(capturedBody, contains('data:image/jpeg;base64,dGVzdA=='));
    });
  });

  group('visionPrompt — Groq', () {
    test('throws UnsupportedError', () async {
      final storage = SecureKeyStorage();
      await storage.saveGroqKey('gsk_test');
      await storage.setByokEnabled(true);
      await storage.setActiveProvider(AiProviderType.groq);

      final service = AiProviderService(
        storage: storage,
        httpClient: MockClient((_) async => http.Response('', 200)),
      );

      expect(
        () => service.visionPrompt(
          prompt: 'test',
          imageBase64: 'dGVzdA==',
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('visionPrompt — Custom', () {
    test('OpenAI-compatible format via custom baseUrl', () async {
      String? capturedUrl;
      final mockClient = MockClient((request) async {
        capturedUrl = request.url.toString();
        return http.Response(
          '{"choices": [{"message": {"content": "Mountain landscape"}}]}',
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
      final desc = await service.visionPrompt(
        prompt: 'Describe.',
        imageBase64: 'dGVzdA==',
      );

      expect(capturedUrl, 'https://tokonomix.ai/api/v1/chat/completions');
      expect(desc, 'Mountain landscape');
    });
  });

  group('visionPrompt — BYOK off', () {
    test('throws StateError bila BYOK nonaktif', () async {
      final service = AiProviderService(
        httpClient: MockClient((_) async => http.Response('', 200)),
      );
      expect(
        () => service.visionPrompt(
          prompt: 'test',
          imageBase64: 'dGVzdA==',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
