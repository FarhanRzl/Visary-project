import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:visary/services/ai_provider_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('SecureKeyStorage menyimpan, membaca, dan menghapus API keys', () async {
    final storage = SecureKeyStorage();

    expect(await storage.getGeminiKey(), isNull);
    expect(await storage.getOpenAiKey(), isNull);
    expect(await storage.getByokEnabled(), isFalse);
    expect(await storage.getActiveProvider(), AiProviderType.server);

    await storage.saveGeminiKey('AIzaSyTest123');
    await storage.saveOpenAiKey('sk-proj-test456');
    await storage.setByokEnabled(true);
    await storage.setActiveProvider(AiProviderType.gemini);

    expect(await storage.getGeminiKey(), 'AIzaSyTest123');
    expect(await storage.getOpenAiKey(), 'sk-proj-test456');
    expect(await storage.getByokEnabled(), isTrue);
    expect(await storage.getActiveProvider(), AiProviderType.gemini);

    await storage.delete(SecureKeyStorage.keyGemini);
    expect(await storage.getGeminiKey(), isNull);

    await storage.deleteAll();
    expect(await storage.getOpenAiKey(), isNull);
    expect(await storage.getByokEnabled(), isFalse);
  });
}
