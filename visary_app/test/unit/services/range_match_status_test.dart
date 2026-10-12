import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:visary/models/models.dart';
import 'package:visary/services/ai_provider_service.dart';
import 'package:visary/services/content_matcher_service.dart';

/// S18 P3 — Test: matchContentRangesWithStatus, _parseRangeMatchResponse.
///
/// Coverage:
/// - LLM returns matched/uncertain/no_match statuses
/// - no_match segments get fallback ranges (not LLM range)
/// - matched + uncertain segments keep LLM range
/// - Mixed: some matched, some no_match → fallback only for no_match
/// - Invalid status string → treated as uncertain (keep range if valid)
/// - All no_match → all fallback
/// - JSON with status but invalid range → no_match
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

  group('matchContentRangesWithStatus', () {
    test('all matched → all LLM ranges kept', () async {
      final ai = _fake(sendPromptHandler: (_) =>
          '[["matched",0,2],["matched",3,5],["matched",6,9]]');
      final matcher = ContentMatcherService(ai);

      final segments = _makeSegments(3, 5.0);
      final descs = ['hot pot', 'LED screen', 'street', 'hot pot', 'person', 'restaurant', 'food', 'cooking', 'steam', 'plate'];

      final result = await matcher.matchContentRangesWithStatus(
        visualDescriptions: descs,
        segments: segments,
      );

      expect(result.length, 3);
      expect(result[0].status, MatchStatus.matched);
      expect(result[0].startFrame, 0);
      expect(result[0].endFrame, 2);
      expect(result[1].status, MatchStatus.matched);
      expect(result[1].startFrame, 3);
      expect(result[1].endFrame, 5);
      expect(result[2].status, MatchStatus.matched);
      expect(result[2].startFrame, 6);
      expect(result[2].endFrame, 9);
    });

    test('mixed: matched + no_match → no_match gets fallback range', () async {
      // seg 0: matched (hot pot frames 0-2)
      // seg 1: no_match (abstract topic, no visual)
      // seg 2: matched (street frames 6-9)
      final ai = _fake(sendPromptHandler: (_) =>
          '[["matched",0,2],["no_match",-1,-1],["matched",6,9]]');
      final matcher = ContentMatcherService(ai);

      final segments = _makeSegments(3, 5.0);
      final descs = ['hot pot', 'hot pot', 'hot pot', 'LED', 'LED', 'LED', 'street', 'street', 'street', 'street'];

      final result = await matcher.matchContentRangesWithStatus(
        visualDescriptions: descs,
        segments: segments,
      );

      expect(result.length, 3);
      expect(result[0].status, MatchStatus.matched);
      expect(result[0].startFrame, 0);
      expect(result[0].endFrame, 2);

      // no_match → fallback range assigned, but status stays no_match
      expect(result[1].status, MatchStatus.noMatch);
      // Fallback: even split of 10 frames / 3 segs = [(0,2),(3,5),(6,9)]
      // seg 1 gets fallback range (3,5)
      expect(result[1].startFrame, 3);
      expect(result[1].endFrame, 5);

      expect(result[2].status, MatchStatus.matched);
      expect(result[2].startFrame, 6);
      expect(result[2].endFrame, 9);
    });

    test('uncertain status → range kept but marked uncertain', () async {
      final ai = _fake(sendPromptHandler: (_) =>
          '[["uncertain",0,1],["matched",2,5]]');
      final matcher = ContentMatcherService(ai);

      final segments = _makeSegments(2, 5.0);
      final descs = ['A', 'B', 'C', 'D', 'E', 'F'];

      final result = await matcher.matchContentRangesWithStatus(
        visualDescriptions: descs,
        segments: segments,
      );

      expect(result.length, 2);
      expect(result[0].status, MatchStatus.uncertain);
      expect(result[0].startFrame, 0);
      expect(result[0].endFrame, 1);
      expect(result[1].status, MatchStatus.matched);
      expect(result[1].startFrame, 2);
      expect(result[1].endFrame, 5);
    });

    test('all no_match → all fallback ranges, all no_match status', () async {
      final ai = _fake(sendPromptHandler: (_) =>
          '[["no_match",-1,-1],["no_match",-1,-1]]');
      final matcher = ContentMatcherService(ai);

      final segments = _makeSegments(2, 5.0);
      final descs = ['A', 'B', 'C', 'D', 'E', 'F'];

      final result = await matcher.matchContentRangesWithStatus(
        visualDescriptions: descs,
        segments: segments,
      );

      expect(result.length, 2);
      expect(result[0].status, MatchStatus.noMatch);
      expect(result[1].status, MatchStatus.noMatch);
      // Fallback: even split 6/2 = [(0,2),(3,5)]
      expect(result[0].startFrame, 0);
      expect(result[0].endFrame, 2);
      expect(result[1].startFrame, 3);
      expect(result[1].endFrame, 5);
    });

    test('invalid status string → treated as uncertain', () async {
      final ai = _fake(sendPromptHandler: (_) =>
          '[["maybe",0,1],["matched",2,3]]');
      final matcher = ContentMatcherService(ai);

      final segments = _makeSegments(2, 5.0);
      final descs = ['A', 'B', 'C', 'D'];

      final result = await matcher.matchContentRangesWithStatus(
        visualDescriptions: descs,
        segments: segments,
      );

      expect(result.length, 2);
      // Unknown status "maybe" → uncertain (range kept if valid)
      expect(result[0].status, MatchStatus.uncertain);
      expect(result[0].startFrame, 0);
      expect(result[0].endFrame, 1);
      expect(result[1].status, MatchStatus.matched);
    });

    test('no_match with valid range → range ignored, fallback used', () async {
      // LLM returns no_match but with a range — range should be ignored
      final ai = _fake(sendPromptHandler: (_) =>
          '[["no_match",0,2],["matched",3,5]]');
      final matcher = ContentMatcherService(ai);

      final segments = _makeSegments(2, 5.0);
      final descs = ['A', 'B', 'C', 'D', 'E', 'F'];

      final result = await matcher.matchContentRangesWithStatus(
        visualDescriptions: descs,
        segments: segments,
      );

      expect(result[0].status, MatchStatus.noMatch);
      // Range from LLM ignored → fallback (0,2) [even split 6/2]
      expect(result[0].startFrame, 0);
      expect(result[0].endFrame, 2);
      expect(result[1].status, MatchStatus.matched);
      expect(result[1].startFrame, 3);
      expect(result[1].endFrame, 5);
    });

    test('matched with invalid range (-1,-1) → treated as no_match', () async {
      final ai = _fake(sendPromptHandler: (_) =>
          '[["matched",-1,-1],["matched",2,3]]');
      final matcher = ContentMatcherService(ai);

      final segments = _makeSegments(2, 5.0);
      final descs = ['A', 'B', 'C', 'D'];

      final result = await matcher.matchContentRangesWithStatus(
        visualDescriptions: descs,
        segments: segments,
      );

      expect(result.length, 2);
      // matched but range invalid → no_match with fallback
      expect(result[0].status, MatchStatus.noMatch);
      expect(result[1].status, MatchStatus.matched);
    });

    test('LLM throw → all fallback, all no_match', () async {
      final ai = _FakeAiProvider(
        sendPromptHandler: (_) => throw Exception('network error'),
      );
      final matcher = ContentMatcherService(ai);

      final segments = _makeSegments(2, 5.0);
      final descs = ['A', 'B', 'C', 'D'];

      final result = await matcher.matchContentRangesWithStatus(
        visualDescriptions: descs,
        segments: segments,
      );

      expect(result.length, 2);
      expect(result[0].status, MatchStatus.noMatch);
      expect(result[1].status, MatchStatus.noMatch);
      // fallbackRanges(4, 2) = [(0,1),(2,3)]
      expect(result[0].startFrame, 0);
      expect(result[0].endFrame, 1);
      expect(result[1].startFrame, 2);
      expect(result[1].endFrame, 3);
    });

    test('segment count mismatch → all fallback', () async {
      // 3 segments expected, LLM returns 2
      final ai = _fake(sendPromptHandler: (_) =>
          '[["matched",0,1],["matched",2,3]]');
      final matcher = ContentMatcherService(ai);

      final segments = _makeSegments(3, 5.0);
      final descs = ['A', 'B', 'C', 'D', 'E', 'F'];

      final result = await matcher.matchContentRangesWithStatus(
        visualDescriptions: descs,
        segments: segments,
      );

      expect(result.length, 3);
      // Mismatch → all fallback
      for (final r in result) {
        expect(r.status, MatchStatus.noMatch);
      }
    });

    test('invalid JSON → all fallback, all no_match', () async {
      final ai = _fake(sendPromptHandler: (_) => 'I cannot match');
      final matcher = ContentMatcherService(ai);

      final segments = _makeSegments(2, 5.0);
      final descs = ['A', 'B', 'C', 'D'];

      final result = await matcher.matchContentRangesWithStatus(
        visualDescriptions: descs,
        segments: segments,
      );

      expect(result.length, 2);
      expect(result[0].status, MatchStatus.noMatch);
      expect(result[1].status, MatchStatus.noMatch);
    });

    test('empty inputs → empty result', () async {
      final ai = _fake(sendPromptHandler: (_) => '[]');
      final matcher = ContentMatcherService(ai);

      final result = await matcher.matchContentRangesWithStatus(
        visualDescriptions: [],
        segments: [],
      );

      expect(result, isEmpty);
    });

    test('indices out of bounds → clamped', () async {
      final ai = _fake(sendPromptHandler: (_) =>
          '[["matched",0,99],["matched",50,60]]');
      final matcher = ContentMatcherService(ai);

      final segments = _makeSegments(2, 5.0);
      final descs = ['A', 'B', 'C', 'D', 'E'];

      final result = await matcher.matchContentRangesWithStatus(
        visualDescriptions: descs,
        segments: segments,
      );

      expect(result.length, 2);
      // 99 clamped to 4 (frameCount-1), 50 clamped to 4
      expect(result[0].endFrame, 4);
      expect(result[1].startFrame, 4);
      expect(result[1].endFrame, 4);
    });
  });

  group('matchContentRanges backward compat', () {
    test('still returns List<(int,int)> for existing callers', () async {
      final ai = _fake(sendPromptHandler: (_) =>
          '[["matched",0,2],["matched",3,5]]');
      final matcher = ContentMatcherService(ai);

      final segments = _makeSegments(2, 5.0);
      final descs = ['A', 'B', 'C', 'D', 'E', 'F'];

      final ranges = await matcher.matchContentRanges(
        visualDescriptions: descs,
        segments: segments,
      );

      expect(ranges.length, 2);
      expect(ranges[0], (0, 2));
      expect(ranges[1], (3, 5));
    });

    test('no_match segments still get fallback range in backward compat', () async {
      final ai = _fake(sendPromptHandler: (_) =>
          '[["matched",0,2],["no_match",-1,-1]]');
      final matcher = ContentMatcherService(ai);

      final segments = _makeSegments(2, 5.0);
      final descs = ['A', 'B', 'C', 'D', 'E', 'F'];

      final ranges = await matcher.matchContentRanges(
        visualDescriptions: descs,
        segments: segments,
      );

      expect(ranges.length, 2);
      // seg 0: matched (0,2)
      expect(ranges[0], (0, 2));
      // seg 1: no_match → fallback (3,5) [even split 6/2]
      expect(ranges[1], (3, 5));
    });
  });
}

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
