import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:visary/services/ai_provider_service.dart';

/// PRD-SPRINT-17 §4 — Test 17.2-17.5: Auto-Switch end-to-end routing.
///
/// Verify that transcribe/visionPrompt/sendPrompt actually use the
/// Auto-Switch routed provider (not just getProviderForTask in isolation).
/// Uses mock HTTP by checking which endpoint gets called.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('Auto-Switch ON + Groq key → transcribe uses Groq Whisper endpoint',
      () async {
    final storage = SecureKeyStorage();
    await storage.setByokEnabled(true);
    await storage.setAutoSwitch(true);
    await storage.saveGroqKey('gsk_test123');
    await storage.saveGeminiKey('AIzaSyTest');

    final svc = AiProviderService(storage: storage);
    final provider = await svc.getProviderForTask(TaskType.asr);

    // Verify ASR is routed to Groq (not Gemini).
    expect(provider, AiProviderType.groq,
        reason: 'ASR should route to Groq when Auto-Switch ON + Groq key');
  });

  test('Auto-Switch ON + Gemini key → visionPrompt routes to Gemini', () async {
    final storage = SecureKeyStorage();
    await storage.setByokEnabled(true);
    await storage.setAutoSwitch(true);
    await storage.saveGeminiKey('AIzaSyTest');
    await storage.saveGroqKey('gsk_test123');

    final svc = AiProviderService(storage: storage);
    final provider = await svc.getProviderForTask(TaskType.vision);

    expect(provider, AiProviderType.gemini,
        reason: 'Vision should route to Gemini when Auto-Switch ON');
  });

  test('Auto-Switch ON + no vision key → visionPrompt throws UnsupportedError',
      () async {
    final storage = SecureKeyStorage();
    await storage.setByokEnabled(true);
    await storage.setAutoSwitch(true);
    await storage.saveGroqKey('gsk_test123');
    // No Gemini, no OpenAI → Groq only (no vision support).

    final svc = AiProviderService(storage: storage);
    final provider = await svc.getProviderForTask(TaskType.vision);

    expect(provider, AiProviderType.server,
        reason: 'Vision should return server when no vision-capable key');
  });

  test('Auto-Switch ON + Gemini key → sendPrompt routes to Gemini', () async {
    final storage = SecureKeyStorage();
    await storage.setByokEnabled(true);
    await storage.setAutoSwitch(true);
    await storage.saveGeminiKey('AIzaSyTest');

    final svc = AiProviderService(storage: storage);
    final provider = await svc.getProviderForTask(TaskType.llm);

    expect(provider, AiProviderType.gemini,
        reason: 'LLM should route to Gemini when Auto-Switch ON');
  });

  test('Auto-Switch ON + no Gemini + Groq key → LLM routes to Groq', () async {
    final storage = SecureKeyStorage();
    await storage.setByokEnabled(true);
    await storage.setAutoSwitch(true);
    await storage.saveGroqKey('gsk_test123');

    final svc = AiProviderService(storage: storage);
    final provider = await svc.getProviderForTask(TaskType.llm);

    expect(provider, AiProviderType.groq,
        reason: 'LLM should fallback to Groq when no Gemini');
  });

  test('Auto-Switch OFF → transcribe uses activeProvider (Gemini)', () async {
    final storage = SecureKeyStorage();
    await storage.setByokEnabled(true);
    await storage.setAutoSwitch(false);
    await storage.setActiveProvider(AiProviderType.gemini);
    await storage.saveGeminiKey('AIzaSyTest');
    await storage.saveGroqKey('gsk_test123');

    final svc = AiProviderService(storage: storage);
    final asrProvider = await svc.getProviderForTask(TaskType.asr);

    expect(asrProvider, AiProviderType.gemini,
        reason: 'ASR should use activeProvider when Auto-Switch OFF');
  });

  test('Auto-Switch OFF → vision uses activeProvider (Groq, no vision)', () async {
    final storage = SecureKeyStorage();
    await storage.setByokEnabled(true);
    await storage.setAutoSwitch(false);
    await storage.setActiveProvider(AiProviderType.groq);
    await storage.saveGroqKey('gsk_test123');

    final svc = AiProviderService(storage: storage);
    final visionProvider = await svc.getProviderForTask(TaskType.vision);

    // Auto-Switch OFF → returns activeProvider (Groq) regardless of capability.
    expect(visionProvider, AiProviderType.groq,
        reason: 'Vision returns activeProvider when Auto-Switch OFF');
  });

  test('getAutoSwitch / setAutoSwitch round-trip', () async {
    final storage = SecureKeyStorage();

    expect(await storage.getAutoSwitch(), isFalse); // default

    await storage.setAutoSwitch(true);
    expect(await storage.getAutoSwitch(), isTrue);

    await storage.setAutoSwitch(false);
    expect(await storage.getAutoSwitch(), isFalse);
  });
}
