import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:visary/models/models.dart';
import 'package:visary/services/ai_provider_service.dart';
import 'package:visary/services/content_matcher_service.dart';

/// PRD-SPRINT-16 §4 — Test 16.3: Match prompt with segments.
///
/// Test _buildSegmentPrompt + _buildMatchPromptSegments (via matchContent
/// with segments overload). Prompt harus mengandung topic + visual descriptions.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('_buildSegmentPrompt mengandung word count + target segments',
      () async {
    String? capturedPrompt;
    final ai = _FakeAiProvider(sendPromptHandler: (p) {
      capturedPrompt = p;
      return '[{"startWord": 0, "endWord": 2, "topic": "intro"}]';
    });
    final matcher = ContentMatcherService(ai);

    final words = [
      WordToken(word: 'Hello', start: 0.0, end: 0.3),
      WordToken(word: 'world', start: 0.3, end: 0.6),
      WordToken(word: 'today', start: 0.6, end: 0.9),
    ];
    final t = Transcript(
      fullText: 'Hello world today',
      words: words,
      language: 'en',
      provider: 'whisper-1',
    );

    await matcher.segmentByContext(transcript: t, targetSegments: 1);

    expect(capturedPrompt, isNotNull);
    expect(capturedPrompt!, contains('1 segments'));
    expect(capturedPrompt!, contains('0: "Hello"'));
    expect(capturedPrompt!, contains('1: "world"'));
    expect(capturedPrompt!, contains('2: "today"'));
    expect(capturedPrompt!, contains('startWord'));
    expect(capturedPrompt!, contains('endWord'));
    expect(capturedPrompt!, contains('topic'));
  });

  test('_buildMatchPromptSegments dengan segments → prompt benar', () async {
    String? capturedPrompt;
    final ai = _FakeAiProvider(sendPromptHandler: (p) {
      capturedPrompt = p;
      return '[0, 1]';
    });
    final matcher = ContentMatcherService(ai);

    final segments = [
      TranscriptSegment(
          startWord: 0, endWord: 3, topic: 'greeting', startSec: 0.0, endSec: 1.0),
      TranscriptSegment(
          startWord: 4, endWord: 8, topic: 'product demo', startSec: 1.0, endSec: 3.0),
    ];

    await matcher.matchContent(
      visualDescriptions: ['Person waving', 'Product on table'],
      segments: segments,
    );

    expect(capturedPrompt, isNotNull);
    expect(capturedPrompt!, contains('greeting'));
    expect(capturedPrompt!, contains('product demo'));
    expect(capturedPrompt!, contains('Person waving'));
    expect(capturedPrompt!, contains('Product on table'));
    expect(capturedPrompt!, contains('JSON array'));
  });

  test('matchContent with segments → correct matchOrder', () async {
    final ai = _FakeAiProvider(sendPromptHandler: (_) => '[1, 0]');
    final matcher = ContentMatcherService(ai);

    final segments = [
      TranscriptSegment(
          startWord: 0, endWord: 3, topic: 'intro', startSec: 0.0, endSec: 1.0),
      TranscriptSegment(
          startWord: 4, endWord: 8, topic: 'demo', startSec: 1.0, endSec: 3.0),
    ];

    final order = await matcher.matchContent(
      visualDescriptions: ['Scene A', 'Scene B'],
      segments: segments,
    );

    expect(order, [1, 0]);
  });

  test('matchContent segments path fallback on LLM error → sequential', () async {
    final ai = _FakeAiProvider(
        sendPromptHandler: (_) => throw Exception('error'));
    final matcher = ContentMatcherService(ai);

    final segments = [
      TranscriptSegment(
          startWord: 0, endWord: 3, topic: 'a', startSec: 0.0, endSec: 1.0),
      TranscriptSegment(
          startWord: 4, endWord: 8, topic: 'b', startSec: 1.0, endSec: 3.0),
    ];

    final order = await matcher.matchContent(
      visualDescriptions: ['A', 'B'],
      segments: segments,
    );

    expect(order, [0, 1]); // sequential fallback
  });
}

class _FakeAiProvider extends AiProviderService {
  _FakeAiProvider({this.sendPromptHandler}) : super();

  final String Function(String prompt)? sendPromptHandler;

  @override
  Future<String> sendPrompt({required String prompt, String? systemInstruction}) async {
    if (sendPromptHandler != null) return sendPromptHandler!(prompt);
    return 'mock-response';
  }
}
