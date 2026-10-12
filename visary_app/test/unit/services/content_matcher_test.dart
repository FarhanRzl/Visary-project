import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:visary/models/models.dart';
import 'package:visary/services/ai_provider_service.dart';
import 'package:visary/services/content_matcher_service.dart';

/// PRD-SPRINT-14 §4 — Test 14.3: ContentMatcherService.
///
/// Mock AiProviderService dengan subclass yang override visionPrompt/sendPrompt.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  _FakeAiProvider _fake({
    String Function(String prompt)? sendPromptHandler,
    String Function(String prompt, String imageBase64)? visionHandler,
  }) {
    return _FakeAiProvider(
      sendPromptHandler: sendPromptHandler,
      visionHandler: visionHandler,
    );
  }

  group('describeFrames', () {
    test('mock visionPrompt → list descriptions', () async {
      final ai = _fake(visionHandler: (prompt, b64) {
        if (b64 == 'AAAA') return 'Person talking on stage';
        if (b64 == 'BBBB') return 'Coffee being poured';
        return 'Unknown';
      });

      final tmpDir = await Directory.systemTemp.createTemp('visary_frames_');
      try {
        // Write fake files whose bytes base64-encode to known values.
        // base64Encode([0x00, 0x00, 0x00]) = 'AAAA'
        // base64Encode([0x04, 0x10, 0x00]) != 'BBBB', so just check by order.
        await File('${tmpDir.path}/f0.jpg').writeAsBytes([0x00, 0x00, 0x00]);
        await File('${tmpDir.path}/f1.jpg').writeAsBytes([0x04, 0x10, 0x00]);

        final matcher = ContentMatcherService(ai);
        final descs = await matcher.describeFrames(
          framePaths: ['${tmpDir.path}/f0.jpg', '${tmpDir.path}/f1.jpg'],
        );

        expect(descs.length, 2);
        // Each frame gets a description (may vary, but not empty since VLM mock returns text).
        expect(descs[0], isNotEmpty);
        expect(descs[1], isNotEmpty);
      } finally {
        await tmpDir.delete(recursive: true);
      }
    });

    test('frame tidak ada → deskripsi kosong (error ditangkap)', () async {
      final ai = _fake(visionHandler: (_, __) => 'desc');
      final matcher = ContentMatcherService(ai);
      final descs = await matcher.describeFrames(
        framePaths: ['/nonexistent/path/frame.jpg'],
      );
      expect(descs.length, 1);
      expect(descs[0], '');
    });

    test('empty frame list → empty descriptions', () async {
      final ai = _fake(visionHandler: (_, __) => 'desc');
      final matcher = ContentMatcherService(ai);
      final descs = await matcher.describeFrames(framePaths: []);
      expect(descs, isEmpty);
    });
  });

  group('extractTopics', () {
    test('mock sendPrompt → list topics per segment', () async {
      final ai = _fake(sendPromptHandler: (prompt) {
        if (prompt.contains('hello world')) return 'greeting';
        if (prompt.contains('coffee shop')) return 'coffee';
        return 'unknown';
      });

      final words = const [
        WordToken(word: 'hello', start: 0.0, end: 0.5),
        WordToken(word: 'world', start: 0.6, end: 1.0),
        WordToken(word: 'coffee', start: 2.0, end: 2.5),
        WordToken(word: 'shop', start: 2.6, end: 3.0),
      ];
      final cutPoints = [0.0, 1.0, 3.0];

      final matcher = ContentMatcherService(ai);
      final topics = await matcher.extractTopics(
        words: words,
        cutPoints: cutPoints,
      );

      expect(topics.length, 2);
      expect(topics[0], 'greeting');
      expect(topics[1], 'coffee');
    });

    test('empty segment text → topic kosong', () async {
      final ai = _fake(sendPromptHandler: (_) => 'should-not-be-called');
      final matcher = ContentMatcherService(ai);
      // Words only in segment 0; segment 1 is empty.
      final words = const [
        WordToken(word: 'a', start: 0.0, end: 0.5),
      ];
      final cutPoints = [0.0, 0.6, 2.0];
      final topics = await matcher.extractTopics(
        words: words,
        cutPoints: cutPoints,
      );
      expect(topics.length, 2);
      // Segment 0 has word 'a' → sendPrompt called.
      expect(topics[0], 'should-not-be-called');
      // Segment 1 (0.6-2.0) has no words → empty topic.
      expect(topics[1], '');
    });
  });

  group('matchContent', () {
    test('mock sendPrompt JSON → parse List<int>', () async {
      final ai = _fake(sendPromptHandler: (_) => '[1, 0, 2]');
      final matcher = ContentMatcherService(ai);

      final order = await matcher.matchContent(
        visualDescriptions: ['Person talking', 'Coffee', 'Mountain'],
        audioTopics: ['greeting', 'coffee', 'scenery'],
      );

      expect(order, [1, 0, 2]);
    });

    test('LLM response dengan teks tambahan → parse JSON array', () async {
      final ai = _fake(sendPromptHandler: (_) =>
          'Here are the matches:\n[0, 2, 1]\nHope this helps!');
      final matcher = ContentMatcherService(ai);

      final order = await matcher.matchContent(
        visualDescriptions: ['A', 'B', 'C'],
        audioTopics: ['t1', 't2', 't3'],
      );

      expect(order, [0, 2, 1]);
    });

    test('parse gagal → fallback sequential [0, 1, 2]', () async {
      final ai = _fake(sendPromptHandler: (_) => 'I cannot parse this');
      final matcher = ContentMatcherService(ai);

      final order = await matcher.matchContent(
        visualDescriptions: ['A', 'B', 'C'],
        audioTopics: ['t1', 't2', 't3'],
      );

      expect(order, [0, 1, 2]);
    });

    test('JSON array length mismatch → fallback sequential', () async {
      final ai = _fake(sendPromptHandler: (_) => '[0, 1]');
      final matcher = ContentMatcherService(ai);

      final order = await matcher.matchContent(
        visualDescriptions: ['A', 'B', 'C'],
        audioTopics: ['t1', 't2', 't3'],
      );

      // Expected 3 but got 2 → fallback.
      expect(order, [0, 1, 2]);
    });

    test('indices di-clamp ke range visual segments', () async {
      final ai = _fake(sendPromptHandler: (_) => '[0, 5, 1]');
      final matcher = ContentMatcherService(ai);

      final order = await matcher.matchContent(
        visualDescriptions: ['A', 'B'],
        audioTopics: ['t1', 't2', 't3'],
      );

      // 5 → clamped to 1 (max visual index = 1).
      expect(order, [0, 1, 1]);
    });

    test('sendPrompt throw → fallback sequential', () async {
      final ai = _FakeAiProvider(
        sendPromptHandler: (_) => throw Exception('network error'),
      );
      final matcher = ContentMatcherService(ai);

      final order = await matcher.matchContent(
        visualDescriptions: ['A', 'B'],
        audioTopics: ['t1', 't2'],
      );

      expect(order, [0, 1]);
    });

    test('empty inputs → empty list', () async {
      final ai = _fake(sendPromptHandler: (_) => '[0]');
      final matcher = ContentMatcherService(ai);

      final order = await matcher.matchContent(
        visualDescriptions: [],
        audioTopics: [],
      );

      expect(order, isEmpty);
    });
  });
}

/// Subclass AiProviderService untuk mock tanpa HTTP.
class _FakeAiProvider extends AiProviderService {
  _FakeAiProvider({
    this.sendPromptHandler,
    this.visionHandler,
    this.visionBatchHandler,
  }) : super();

  final String Function(String prompt)? sendPromptHandler;
  final String Function(String prompt, String imageBase64)? visionHandler;
  final List<String> Function(List<String> imageBase64List)? visionBatchHandler;

  @override
  Future<String> sendPrompt({required String prompt, String? systemInstruction}) async {
    if (sendPromptHandler != null) return sendPromptHandler!(prompt);
    return 'mock-response';
  }

  @override
  Future<String> visionPrompt({
    required String prompt,
    required String imageBase64,
    String mimeType = 'image/jpeg',
  }) async {
    if (visionHandler != null) return visionHandler!(prompt, imageBase64);
    return 'mock-vision-response';
  }

  @override
  Future<List<String>> visionBatchPrompt({
    required List<String> imageBase64List,
    String mimeType = 'image/jpeg',
    String? promptText,
  }) async {
    if (visionBatchHandler != null) return visionBatchHandler!(imageBase64List);
    // Default: return per-frame descriptions via visionHandler.
    return imageBase64List.map((b64) {
      if (visionHandler != null) return visionHandler!('describe', b64).trim();
      return 'mock-batch-desc';
    }).toList();
  }
}
