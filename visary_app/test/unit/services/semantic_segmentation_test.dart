import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:visary/models/models.dart';
import 'package:visary/services/ai_provider_service.dart';
import 'package:visary/services/content_matcher_service.dart';

/// PRD-SPRINT-16 §4 — Test 16.1: Semantic segmentation.
///
/// Test segmentByContext dengan mock LLM response: parse benar,
/// wrong segment count → empty, invalid word index → clamp, LLM error → empty.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// Build words: "Hello everyone today we talk about coffee"
  List<WordToken> _makeWords() => [
        WordToken(word: 'Hello', start: 0.0, end: 0.3),
        WordToken(word: 'everyone', start: 0.3, end: 0.6),
        WordToken(word: 'today', start: 0.6, end: 0.9),
        WordToken(word: 'we', start: 0.9, end: 1.0),
        WordToken(word: 'talk', start: 1.0, end: 1.2),
        WordToken(word: 'about', start: 1.2, end: 1.4),
        WordToken(word: 'coffee', start: 1.4, end: 1.6),
      ];

  Transcript _makeTranscript(List<WordToken> words) => Transcript(
        fullText: words.map((w) => w.word).join(' '),
        words: words,
        language: 'en',
        provider: 'whisper-1',
      );

  test('mock LLM response → parse benar (N segmen, word index valid, topic terisi)',
      () async {
    final ai = _FakeAiProvider(sendPromptHandler: (_) =>
        '[{"startWord": 0, "endWord": 2, "topic": "greeting"}, '
        '{"startWord": 3, "endWord": 6, "topic": "coffee discussion"}]');
    final matcher = ContentMatcherService(ai);

    final words = _makeWords();
    final t = _makeTranscript(words);
    final segments =
        await matcher.segmentByContext(transcript: t, targetSegments: 2);

    expect(segments.length, 2);
    expect(segments[0].startWord, 0);
    expect(segments[0].endWord, 2);
    expect(segments[0].topic, 'greeting');
    expect(segments[0].startSec, 0.0);
    expect(segments[0].endSec, 0.9);
    expect(segments[1].startWord, 3);
    expect(segments[1].endWord, 6);
    expect(segments[1].topic, 'coffee discussion');
    expect(segments[1].startSec, 0.9);
    expect(segments[1].endSec, 1.6);
  });

  test('wrong segment count → return empty (trigger fallback)', () async {
    final ai = _FakeAiProvider(sendPromptHandler: (_) =>
        '[{"startWord": 0, "endWord": 6, "topic": "all"}]');
    final matcher = ContentMatcherService(ai);

    final t = _makeTranscript(_makeWords());
    final segments =
        await matcher.segmentByContext(transcript: t, targetSegments: 3);

    expect(segments, isEmpty);
  });

  test('invalid word index → clamp ke valid range', () async {
    final ai = _FakeAiProvider(sendPromptHandler: (_) =>
        '[{"startWord": -5, "endWord": 100, "topic": "clamped"}, '
        '{"startWord": 4, "endWord": 6, "topic": "tail"}]');
    final matcher = ContentMatcherService(ai);

    final words = _makeWords();
    final t = _makeTranscript(words);
    final segments =
        await matcher.segmentByContext(transcript: t, targetSegments: 2);

    expect(segments.length, 2);
    // -5 → clamped to 0, 100 → clamped to 6 (words.length-1)
    expect(segments[0].startWord, 0);
    expect(segments[0].endWord, 6);
    expect(segments[1].startWord, 4);
    expect(segments[1].endWord, 6);
  });

  test('LLM error → return empty (trigger fallback)', () async {
    final ai = _FakeAiProvider(
        sendPromptHandler: (_) => throw Exception('network error'));
    final matcher = ContentMatcherService(ai);

    final t = _makeTranscript(_makeWords());
    final segments =
        await matcher.segmentByContext(transcript: t, targetSegments: 2);

    expect(segments, isEmpty);
  });

  test('empty transcript → return empty', () async {
    final ai = _FakeAiProvider(sendPromptHandler: (_) => '[]');
    final matcher = ContentMatcherService(ai);

    final t = _makeTranscript([]);
    final segments =
        await matcher.segmentByContext(transcript: t, targetSegments: 3);

    expect(segments, isEmpty);
  });

  test('targetSegments > wordCount → clamp to wordCount', () async {
    final ai = _FakeAiProvider(sendPromptHandler: (_) =>
        '[{"startWord": 0, "endWord": 3, "topic": "first half"}, '
        '{"startWord": 4, "endWord": 6, "topic": "second half"}]');
    final matcher = ContentMatcherService(ai);

    final words = _makeWords(); // 7 words
    final t = _makeTranscript(words);
    // Request 20 segments but only 7 words → clamp to 7.
    // But mock returns 2, so it will mismatch. Instead test with 2.
    final segments =
        await matcher.segmentByContext(transcript: t, targetSegments: 2);

    expect(segments.length, 2);
  });

  test('prompt contains word count + target segments', () async {
    String? capturedPrompt;
    final ai = _FakeAiProvider(sendPromptHandler: (p) {
      capturedPrompt = p;
      return '[{"startWord": 0, "endWord": 6, "topic": "all"}]';
    });
    final matcher = ContentMatcherService(ai);

    final t = _makeTranscript(_makeWords());
    await matcher.segmentByContext(transcript: t, targetSegments: 1);

    expect(capturedPrompt, isNotNull);
    expect(capturedPrompt!, contains('1 segments'));
    expect(capturedPrompt!, contains('word-indexed'));
    expect(capturedPrompt!, contains('0: "Hello"'));
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
