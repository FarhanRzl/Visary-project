import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:visary/services/ai_provider_service.dart';

/// PRD-SPRINT-17 §4 — Test 17.1: Task provider routing.
///
/// Auto-Switch ON + Groq key → ASR routes to Groq.
/// Auto-Switch ON + no Groq + Gemini key → ASR routes to Gemini.
/// Auto-Switch ON + Gemini key → Vision routes to Gemini.
/// Auto-Switch ON + no Gemini + OpenAI key → Vision routes to OpenAI.
/// Auto-Switch ON + Gemini key → LLM routes to Gemini.
/// Auto-Switch OFF → all tasks route to activeAiProvider.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  SecureKeyStorage _storage() => SecureKeyStorage();
  AiProviderService _service() => AiProviderService(storage: _storage());

  group('Auto-Switch ON', () {
    test('ASR routes to Groq when Groq key available', () async {
      final svc = _service();
      await svc.storage.setByokEnabled(true);
      await svc.storage.setAutoSwitch(true);
      await svc.storage.saveGroqKey('gsk_test123');
      await svc.storage.saveGeminiKey('AIzaSyTest');

      final provider = await svc.getProviderForTask(TaskType.asr);
      expect(provider, AiProviderType.groq);
    });

    test('ASR routes to Gemini when no Groq key but Gemini key available',
        () async {
      final svc = _service();
      await svc.storage.setByokEnabled(true);
      await svc.storage.setAutoSwitch(true);
      await svc.storage.saveGeminiKey('AIzaSyTest');
      // No Groq key.

      final provider = await svc.getProviderForTask(TaskType.asr);
      expect(provider, AiProviderType.gemini);
    });

    test('ASR routes to OpenAI when no Groq + no Gemini but OpenAI available',
        () async {
      final svc = _service();
      await svc.storage.setByokEnabled(true);
      await svc.storage.setAutoSwitch(true);
      await svc.storage.saveOpenAiKey('sk-test');

      final provider = await svc.getProviderForTask(TaskType.asr);
      expect(provider, AiProviderType.openai);
    });

    test('Vision routes to Gemini when Gemini key available', () async {
      final svc = _service();
      await svc.storage.setByokEnabled(true);
      await svc.storage.setAutoSwitch(true);
      await svc.storage.saveGeminiKey('AIzaSyTest');
      await svc.storage.saveGroqKey('gsk_test');

      final provider = await svc.getProviderForTask(TaskType.vision);
      expect(provider, AiProviderType.gemini);
    });

    test('Vision routes to OpenAI when no Gemini but OpenAI available',
        () async {
      final svc = _service();
      await svc.storage.setByokEnabled(true);
      await svc.storage.setAutoSwitch(true);
      await svc.storage.saveOpenAiKey('sk-test');
      await svc.storage.saveGroqKey('gsk_test');

      final provider = await svc.getProviderForTask(TaskType.vision);
      expect(provider, AiProviderType.openai);
    });

    test('Vision returns server when no vision-capable key', () async {
      final svc = _service();
      await svc.storage.setByokEnabled(true);
      await svc.storage.setAutoSwitch(true);
      await svc.storage.saveGroqKey('gsk_test');
      // No Gemini, no OpenAI, no Custom → Groq only (no vision).

      final provider = await svc.getProviderForTask(TaskType.vision);
      expect(provider, AiProviderType.server);
    });

    test('LLM routes to Gemini when Gemini key available', () async {
      final svc = _service();
      await svc.storage.setByokEnabled(true);
      await svc.storage.setAutoSwitch(true);
      await svc.storage.saveGeminiKey('AIzaSyTest');
      await svc.storage.saveGroqKey('gsk_test');

      final provider = await svc.getProviderForTask(TaskType.llm);
      expect(provider, AiProviderType.gemini);
    });

    test('LLM routes to OpenAI when no Gemini but OpenAI available', () async {
      final svc = _service();
      await svc.storage.setByokEnabled(true);
      await svc.storage.setAutoSwitch(true);
      await svc.storage.saveOpenAiKey('sk-test');

      final provider = await svc.getProviderForTask(TaskType.llm);
      expect(provider, AiProviderType.openai);
    });

    test('LLM routes to Groq when no Gemini + no OpenAI but Groq available',
        () async {
      final svc = _service();
      await svc.storage.setByokEnabled(true);
      await svc.storage.setAutoSwitch(true);
      await svc.storage.saveGroqKey('gsk_test');

      final provider = await svc.getProviderForTask(TaskType.llm);
      expect(provider, AiProviderType.groq);
    });
  });

  group('Auto-Switch OFF', () {
    test('all tasks route to activeAiProvider', () async {
      final svc = _service();
      await svc.storage.setByokEnabled(true);
      await svc.storage.setAutoSwitch(false);
      await svc.storage.setActiveProvider(AiProviderType.gemini);
      await svc.storage.saveGeminiKey('AIzaSyTest');
      await svc.storage.saveGroqKey('gsk_test');

      // Even though Groq key is available, ASR should use activeProvider (Gemini).
      expect(await svc.getProviderForTask(TaskType.asr), AiProviderType.gemini);
      expect(await svc.getProviderForTask(TaskType.vision), AiProviderType.gemini);
      expect(await svc.getProviderForTask(TaskType.llm), AiProviderType.gemini);
    });

    test('all tasks route to activeProvider even if no key for it', () async {
      final svc = _service();
      await svc.storage.setByokEnabled(true);
      await svc.storage.setAutoSwitch(false);
      await svc.storage.setActiveProvider(AiProviderType.groq);
      await svc.storage.saveGeminiKey('AIzaSyTest');
      // No Groq key, but activeProvider is Groq.

      expect(await svc.getProviderForTask(TaskType.asr), AiProviderType.groq);
      expect(await svc.getProviderForTask(TaskType.vision), AiProviderType.groq);
    });
  });

  group('hasKeyFor', () {
    test('returns true when key exists', () async {
      final svc = _service();
      await svc.storage.saveGeminiKey('AIzaSyTest');
      expect(await svc.hasKeyFor(AiProviderType.gemini), isTrue);
    });

    test('returns false when key empty', () async {
      final svc = _service();
      expect(await svc.hasKeyFor(AiProviderType.gemini), isFalse);
    });

    test('returns false for server', () async {
      final svc = _service();
      expect(await svc.hasKeyFor(AiProviderType.server), isFalse);
    });
  });
}
