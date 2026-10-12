import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:visary/models/models.dart';
import 'package:visary/services/ai_provider_service.dart';
import 'package:visary/services/content_matcher_service.dart';

/// PRD-SPRINT-18 — Test: matchContentRanges, _parseRangeResponse, fallbackRanges.
///
/// Coverage:
/// - Valid JSON ranges from LLM
/// - Invalid JSON (text only, malformed)
/// - Indices out of bounds (clamped)
/// - Segment count mismatch → fallback
/// - Empty inputs
/// - fallbackRanges even distribution + remainder
/// - fallbackRanges can produce visually-wrong-but-valid output
/// - LLM throw → fallback
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  _FakeAiProvider _fake({
    String Function(String prompt)? sendPromptHandler,
  }) {
    return _FakeAiProvider(sendPromptHandler: sendPromptHandler);
  }

  List<TranscriptSegment> _makeSegments(int count, double durEach) {
    return List.generate(count, (i) => TranscriptSegment(
      startWord: i * 5,
      endWord: (i + 1) * 5 - 1,
      topic: 'topic $i',
      startSec: i * durEach,
      endSec: (i + 1) * durEach,
    ));
  }

  group('matchContentRanges', () {
    test('valid JSON ranges → parsed correctly', () async {
      final ai = _fake(sendPromptHandler: (_) => '[[0,2],[3,5],[6,9]]');
      final matcher = ContentMatcherService(ai);

      final segments = _makeSegments(3, 5.0);
      final descs = ['hot pot', 'LED screen', 'street view', 'hot pot', 'person', 'restaurant', 'food', 'cooking', 'steam', 'plate'];

      final ranges = await matcher.matchContentRanges(
        visualDescriptions: descs,
        segments: segments,
      );

      expect(ranges.length, 3);
      expect(ranges[0], (0, 2));
      expect(ranges[1], (3, 5));
      expect(ranges[2], (6, 9));
    });

    test('LLM response with extra text → regex extracts JSON array', () async {
      final ai = _fake(sendPromptHandler: (_) =>
          'Here are the ranges:\n[[0,1],[2,4]]\nNote: frames are 0-indexed.');
      final matcher = ContentMatcherService(ai);

      final segments = _makeSegments(2, 5.0);
      final descs = ['A', 'B', 'C', 'D', 'E'];

      final ranges = await matcher.matchContentRanges(
        visualDescriptions: descs,
        segments: segments,
      );

      expect(ranges.length, 2);
      expect(ranges[0], (0, 1));
      expect(ranges[1], (2, 4));
    });

    test('invalid JSON (plain text) → fallback even split', () async {
      final ai = _fake(sendPromptHandler: (_) => 'I cannot match these segments.');
      final matcher = ContentMatcherService(ai);

      final segments = _makeSegments(3, 5.0);
      final descs = ['A', 'B', 'C', 'D', 'E', 'F'];

      final ranges = await matcher.matchContentRanges(
        visualDescriptions: descs,
        segments: segments,
      );

      // fallbackRanges(6, 3): perSeg=2 → [(0,1), (2,3), (4,5)]
      expect(ranges.length, 3);
      expect(ranges[0], (0, 1));
      expect(ranges[1], (2, 3));
      expect(ranges[2], (4, 5));
    });

    test('malformed JSON array → fallback', () async {
      final ai = _fake(sendPromptHandler: (_) => '[[0,2],[3,]');
      final matcher = ContentMatcherService(ai);

      final segments = _makeSegments(2, 5.0);
      final descs = ['A', 'B', 'C', 'D', 'E'];

      final ranges = await matcher.matchContentRanges(
        visualDescriptions: descs,
        segments: segments,
      );

      expect(ranges.length, 2);
      // fallbackRanges(5, 2): perSeg=2 → [(0,1), (2,4)]
      expect(ranges[0], (0, 1));
      expect(ranges[1], (2, 4));
    });

    test('indices out of bounds → clamped to frameCount-1', () async {
      // 5 frames (0-4), LLM returns index 10 and 99
      final ai = _fake(sendPromptHandler: (_) => '[[0,10],[99,99]]');
      final matcher = ContentMatcherService(ai);

      final segments = _makeSegments(2, 5.0);
      final descs = ['A', 'B', 'C', 'D', 'E'];

      final ranges = await matcher.matchContentRanges(
        visualDescriptions: descs,
        segments: segments,
      );

      expect(ranges.length, 2);
      // 10 clamped to 4, 99 clamped to 4
      expect(ranges[0], (0, 4));
      expect(ranges[1], (4, 4));
    });

    test('start > end in LLM response → end clamped to start', () async {
      // LLM returns [5, 2] — start > end. Code does end.clamp(start, frameCount-1)
      final ai = _fake(sendPromptHandler: (_) => '[[5,2],[3,4]]');
      final matcher = ContentMatcherService(ai);

      final segments = _makeSegments(2, 5.0);
      final descs = ['A', 'B', 'C', 'D', 'E'];

      final ranges = await matcher.matchContentRanges(
        visualDescriptions: descs,
        segments: segments,
      );

      expect(ranges.length, 2);
      // start=5 clamped to 4 (frameCount-1), then end=2 clamped to start=4
      expect(ranges[0], (4, 4));
      expect(ranges[1], (3, 4));
    });

    test('segment count mismatch → fallback', () async {
      // 3 segments expected, LLM returns only 2 ranges
      final ai = _fake(sendPromptHandler: (_) => '[[0,2],[3,5]]');
      final matcher = ContentMatcherService(ai);

      final segments = _makeSegments(3, 5.0);
      final descs = ['A', 'B', 'C', 'D', 'E', 'F'];

      final ranges = await matcher.matchContentRanges(
        visualDescriptions: descs,
        segments: segments,
      );

      expect(ranges.length, 3);
      // fallbackRanges(6, 3): [(0,1), (2,3), (4,5)]
      expect(ranges[0], (0, 1));
      expect(ranges[1], (2, 3));
      expect(ranges[2], (4, 5));
    });

    test('LLM throw → fallback even split', () async {
      final ai = _FakeAiProvider(
        sendPromptHandler: (_) => throw Exception('network error'),
      );
      final matcher = ContentMatcherService(ai);

      final segments = _makeSegments(2, 5.0);
      final descs = ['A', 'B', 'C', 'D'];

      final ranges = await matcher.matchContentRanges(
        visualDescriptions: descs,
        segments: segments,
      );

      expect(ranges.length, 2);
      expect(ranges[0], (0, 1));
      expect(ranges[1], (2, 3));
    });

    test('empty segments → returns degenerate ranges', () async {
      final ai = _fake(sendPromptHandler: (_) => '[[0,0]]');
      final matcher = ContentMatcherService(ai);

      final ranges = await matcher.matchContentRanges(
        visualDescriptions: ['A', 'B'],
        segments: [],
      );

      // segments.isEmpty → returns List.generate(0, ...) = []
      expect(ranges, isEmpty);
    });

    test('empty visual descriptions → returns degenerate ranges', () async {
      final ai = _fake(sendPromptHandler: (_) => '[[0,0]]');
      final matcher = ContentMatcherService(ai);

      final segments = _makeSegments(2, 5.0);

      final ranges = await matcher.matchContentRanges(
        visualDescriptions: [],
        segments: segments,
      );

      // visualDescriptions.isEmpty → returns List.generate(2, (_) => (0, 0))
      expect(ranges.length, 2);
      expect(ranges[0], (0, 0));
      expect(ranges[1], (0, 0));
    });

    test('nested empty arrays in LLM response → fallback', () async {
      final ai = _fake(sendPromptHandler: (_) => '[[],[]]');
      final matcher = ContentMatcherService(ai);

      final segments = _makeSegments(2, 5.0);
      final descs = ['A', 'B', 'C', 'D'];

      final ranges = await matcher.matchContentRanges(
        visualDescriptions: descs,
        segments: segments,
      );

      // Each element fails `e is List && e.length >= 2` → ranges stays empty
      // → length mismatch → fallback
      expect(ranges.length, 2);
      expect(ranges[0], (0, 1));
      expect(ranges[1], (2, 3));
    });
  });

  group('fallbackRanges', () {
    test('even split: 6 frames, 3 segments → [(0,1),(2,3),(4,5)]', () {
      final matcher = ContentMatcherService(_fake());
      final ranges = matcher.fallbackRanges(6, 3);

      expect(ranges.length, 3);
      expect(ranges[0], (0, 1));
      expect(ranges[1], (2, 3));
      expect(ranges[2], (4, 5));
    });

    test('remainder goes to last segment: 7 frames, 3 segs → [(0,1),(2,3),(4,6)]', () {
      final matcher = ContentMatcherService(_fake());
      final ranges = matcher.fallbackRanges(7, 3);

      expect(ranges.length, 3);
      expect(ranges[0], (0, 1));
      expect(ranges[1], (2, 3));
      // Last segment gets remainder: 7/3=2 per seg, last gets 4,5,6
      expect(ranges[2], (4, 6));
    });

    test('frame count equals segment count: 3 frames, 3 segs → [(0,0),(1,1),(2,2)]', () {
      final matcher = ContentMatcherService(_fake());
      final ranges = matcher.fallbackRanges(3, 3);

      expect(ranges.length, 3);
      expect(ranges[0], (0, 0));
      expect(ranges[1], (1, 1));
      expect(ranges[2], (2, 2));
    });

    test('more segments than frames: 2 frames, 4 segs', () {
      final matcher = ContentMatcherService(_fake());
      final ranges = matcher.fallbackRanges(2, 4);

      // perSeg = 2 ~/ 4 = 0 → each segment gets end=start-1
      // start clamped to frameCount-1=1, end clamped to start=1
      // seg 0: start=0 → (0,0), start becomes 1
      // seg 1: start=1 → (1,1), start becomes 2
      // seg 2: start=2 clamped to 1 → (1,1), start becomes 2
      // seg 3: start=2 clamped to 1 → (1,1) [last, end=frameCount-1=1]
      expect(ranges.length, 4);
      for (final (s, e) in ranges) {
        expect(s, lessThanOrEqualTo(1));
        expect(e, lessThanOrEqualTo(1));
      }
    });

    test('zero frame count → empty', () {
      final matcher = ContentMatcherService(_fake());
      expect(matcher.fallbackRanges(0, 3), isEmpty);
    });

    test('zero segment count → empty', () {
      final matcher = ContentMatcherService(_fake());
      expect(matcher.fallbackRanges(6, 0), isEmpty);
    });

    test('single segment → covers all frames', () {
      final matcher = ContentMatcherService(_fake());
      final ranges = matcher.fallbackRanges(10, 1);

      expect(ranges.length, 1);
      expect(ranges[0], (0, 9));
    });

    test('frames not evenly divisible: 10 frames, 3 segs → last gets remainder', () {
      final matcher = ContentMatcherService(_fake());
      final ranges = matcher.fallbackRanges(10, 3);

      // perSeg = 10 ~/ 3 = 3
      // seg 0: (0, 2), seg 1: (3, 5), seg 2: (6, 9) — last gets 4 frames
      expect(ranges.length, 3);
      expect(ranges[0], (0, 2));
      expect(ranges[1], (3, 5));
      expect(ranges[2], (6, 9));
    });

    test('fallback can produce visually-wrong-but-valid output', () {
      // Scenario: 6 frames, 3 segments.
      // Visual descriptions: [hot_pot, hot_pot, hot_pot, LED_screen, LED_screen, LED_screen]
      // Audio topics: [hot_pot, LED_screen, hot_pot] (non-sequential)
      //
      // fallbackRanges always assigns frames 0-1 to seg 0, 2-3 to seg 1, 4-5 to seg 2.
      // seg 0 (hot_pot) gets frames 0-1 (hot_pot) — correct!
      // seg 1 (LED_screen) gets frames 2-3 (hot_pot, LED_screen) — partially wrong
      // seg 2 (hot_pot) gets frames 4-5 (LED_screen) — WRONG
      //
      // This test documents that fallback produces ranges that are syntactically valid
      // (contiguous, no gaps, no overlaps) but semantically incorrect.
      final matcher = ContentMatcherService(_fake());
      final ranges = matcher.fallbackRanges(6, 3);

      // Verify syntactic validity: contiguous, no gaps
      expect(ranges[0].$2 + 1, ranges[1].$1); // 0-1 → 2
      expect(ranges[1].$2 + 1, ranges[2].$1); // 2-3 → 4
      expect(ranges[0].$1, 0); // starts at 0
      expect(ranges[2].$2, 5); // ends at last frame

      // But semantically wrong for non-sequential topics:
      // seg 2 topic=hot_pot but frames 4-5 are LED_screen
      // This is the documented false-positive risk of fallback.
    });
  });
}

/// Subclass AiProviderService untuk mock tanpa HTTP.
class _FakeAiProvider extends AiProviderService {
  _FakeAiProvider({
    this.sendPromptHandler,
  }) : super();

  final String Function(String prompt)? sendPromptHandler;

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
    return 'mock-vision-response';
  }

  @override
  Future<List<String>> visionBatchPrompt({
    required List<String> imageBase64List,
    String mimeType = 'image/jpeg',
    String? promptText,
  }) async {
    return imageBase64List.map((_) => 'mock-batch-desc').toList();
  }
}
