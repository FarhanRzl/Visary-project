import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'ai_provider_service.dart';

/// Content-aware audio-visual matching via VLM + LLM. PRD-SPRINT-14 + S16.
///
/// S16: Semantic segmentation replaces timing-based cut + per-segment extractTopics.
/// 1. `describeFrames` — VLM (Gemini Vision) memberi deskripsi per frame.
/// 2. `segmentByContext` — LLM pecah transcript jadi N segmen berdasarkan konteks (1 call).
/// 3. `matchContent` — LLM mencocokkan segments ↔ visual descriptions (1 call).
class ContentMatcherService {
  ContentMatcherService(this._ai);

  final AiProviderService _ai;

  /// Describe semua frame via VLM dalam 1 batch call (PRD-SPRINT-17 quota fix).
  ///
  /// S14 awalnya 1 call per frame (N calls). Gemini free tier limit 5 RPM →
  /// habis di frame ke-5. Batch: 1 call untuk semua frame.
  Future<List<String>> describeFrames({
    required List<String> framePaths,
  }) async {
    if (framePaths.isEmpty) return [];

    // Read all frames → base64 list.
    final b64List = <String>[];
    for (final path in framePaths) {
      try {
        final bytes = await File(path).readAsBytes();
        b64List.add(base64Encode(bytes).replaceAll('\n', ''));
      } catch (e) {
        debugPrint('[ContentMatcher] read frame gagal untuk $path: $e');
        b64List.add('');
      }
    }

    // Batch: 1 API call for all frames.
    final validB64 = b64List.where((b) => b.isNotEmpty).toList();
    if (validB64.isEmpty) {
      // All frames failed to read → return empty descriptions per frame.
      return List.generate(framePaths.length, (_) => '');
    }
    try {
      final batchDescs = await _ai.visionBatchPrompt(
        imageBase64List: validB64,
      );
      // Map batch results back to original frame positions.
      final descriptions = <String>[];
      var validIdx = 0;
      for (final b64 in b64List) {
        if (b64.isEmpty) {
          descriptions.add('');
        } else {
          descriptions.add(
            validIdx < batchDescs.length ? batchDescs[validIdx] : '');
          validIdx++;
        }
      }
      return descriptions;
    } catch (e) {
      final msg = e.toString();
      final transient = msg.contains('503') || msg.contains('429');
      if (transient) {
        // Gemini overload/quota — per-frame akan gagal juga.
        // Return empty descriptions, pipeline lanjut dengan visual-only fallback.
        debugPrint('[ContentMatcher] batch gagal (transient): $e → skip per-frame, visual-only');
        return List.generate(framePaths.length, (_) => '');
      }
      // Non-transient error (400, dll) → coba per-frame (mungkin batch terlalu besar).
      debugPrint('[ContentMatcher] batch gagal: $e → per-frame fallback');
      final descriptions = <String>[];
      for (var i = 0; i < framePaths.length; i++) {
        if (b64List[i].isEmpty) {
          descriptions.add('');
          continue;
        }
        try {
          final desc = await _ai.visionPrompt(
            prompt: 'Describe what is shown in this image in one concise sentence.',
            imageBase64: b64List[i],
          );
          descriptions.add(desc.trim());
        } catch (e) {
          debugPrint('[ContentMatcher] describeFrames gagal untuk frame $i: $e');
          descriptions.add('');
        }
      }
      return descriptions;
    }
  }

  // ── S16: Semantic segmentation ──

  /// Semantic segmentation: pecah transcript menjadi N segmen berdasarkan
  /// konteks/topik. N = jumlah shot video. PRD-SPRINT-16 §2.1.
  ///
  /// Menggantikan detectCutPoints (timing) + extractTopics (per-segment LLM).
  /// Satu LLM call → semua segmen + topic.
  Future<List<TranscriptSegment>> segmentByContext({
    required Transcript transcript,
    required int targetSegments,
  }) async {
    if (transcript.words.isEmpty || targetSegments <= 0) return [];

    // Clamp targetSegments ke max(wordCount, 1) — shot count bisa > word count.
    final effectiveTarget =
        targetSegments.clamp(1, transcript.words.length);

    final prompt = _buildSegmentPrompt(transcript, effectiveTarget);
    String response;
    try {
      response = await _ai.sendPrompt(prompt: prompt);
    } catch (e) {
      debugPrint('[S16] segmentByContext LLM gagal: $e');
      return []; // → caller fallback ke detectCutPoints
    }

    return _parseSegmentResponse(response, transcript.words, effectiveTarget);
  }

  /// Build prompt untuk LLM semantic segmentation. PRD-SPRINT-16 §2.6.
  String _buildSegmentPrompt(Transcript transcript, int targetSegments) {
    final buf = StringBuffer();
    buf.writeln('You are a content segmentation engine. '
        'Split this transcript into exactly $targetSegments segments '
        'based on topic/context shifts.');
    buf.writeln();
    buf.writeln('Transcript (word-indexed):');

    // Limit to first 500 words to avoid prompt too long (PRD §6 risk).
    final maxWords = transcript.words.length > 500
        ? 500
        : transcript.words.length;
    for (var i = 0; i < maxWords; i++) {
      buf.writeln('$i: "${transcript.words[i].word}"');
    }
    if (transcript.words.length > 500) {
      buf.writeln('... (${transcript.words.length - 500} more words truncated)');
    }

    buf.writeln();
    buf.writeln('Return ONLY a JSON array: '
        '[{"startWord": 0, "endWord": 5, "topic": "greeting"}, ...]');
    buf.writeln('- startWord/endWord: 0-based word index (inclusive)');
    buf.writeln('- Exactly $targetSegments segments');
    buf.writeln('- Cover all words (endWord of last = ${maxWords - 1})');
    buf.writeln('- topic: 2-3 word English label');
    return buf.toString();
  }

  /// Parse JSON response → List<TranscriptSegment>. PRD-SPRINT-16 §2.1.
  /// Validasi: tepat targetSegments, cover semua words, index valid.
  List<TranscriptSegment> _parseSegmentResponse(
    String response,
    List<WordToken> words,
    int targetSegments,
  ) {
    try {
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(response);
      if (jsonMatch == null) return [];

      final parsed = jsonDecode(jsonMatch.group(0)!);
      final segments = <TranscriptSegment>[];

      for (final s in parsed) {
        final startWord = (s['startWord'] as num).toInt();
        final endWord = (s['endWord'] as num).toInt();
        final topic = (s['topic'] as String?) ?? '';

        // Clamp to valid word indices.
        final sw = startWord.clamp(0, words.length - 1);
        final ew = endWord.clamp(sw, words.length - 1);

        segments.add(TranscriptSegment(
          startWord: sw,
          endWord: ew,
          topic: topic,
          startSec: words[sw].start,
          endSec: words[ew].end,
        ));
      }

      // Validasi jumlah segmen.
      if (segments.length != targetSegments) {
        debugPrint('[S16] segment count ${segments.length} != target $targetSegments → fallback');
        return [];
      }

      return segments;
    } catch (e) {
      debugPrint('[S16] parse segment gagal: $e');
      return [];
    }
  }

  // ── S14 legacy (fallback path) ──

  /// Extract topic per audio segment dari transcript. PRD-SPRINT-14 §2.4.
  /// Dipakai sebagai fallback bila semantic segmentation gagal (S16 §2.7).
  Future<List<String>> extractTopics({
    required List<WordToken> words,
    required List<double> cutPoints,
  }) async {
    final topics = <String>[];
    for (var i = 0; i < cutPoints.length - 1; i++) {
      final segStart = cutPoints[i];
      final segEnd = cutPoints[i + 1];
      final segWords = words
          .where((w) => w.start >= segStart && w.end <= segEnd)
          .toList();
      final text = segWords.map((w) => w.word).join(' ');
      if (text.isEmpty) {
        topics.add('');
        continue;
      }
      try {
        final topic = await _ai.sendPrompt(
          prompt: 'Summarize the topic of this text in 2-3 words: "$text"',
        );
        topics.add(topic.trim());
      } catch (e) {
        debugPrint('[ContentMatcher] extractTopics gagal untuk segment $i: $e');
        topics.add('');
      }
    }
    return topics;
  }

  /// Match audio segments ke visual descriptions via LLM.
  /// PRD-SPRINT-14 §2.5 + S16 §2.3 (segments overload).
  ///
  /// S16 path: terima List<TranscriptSegment> (sudah ada topic).
  /// S14 path: terima List<String> audioTopics (legacy fallback).
  /// Fallback: bila parse gagal → sequential [0, 1, 2, ...].
  Future<List<int>> matchContent({
    required List<String> visualDescriptions,
    List<String>? audioTopics,
    List<TranscriptSegment>? segments,
  }) async {
    // S16 path: segments already have topics.
    if (segments != null && segments.isNotEmpty) {
      if (visualDescriptions.isEmpty) {
        return List.generate(segments.length, (i) => i);
      }
      final prompt = _buildMatchPromptSegments(visualDescriptions, segments);
      String response;
      try {
        response = await _ai.sendPrompt(prompt: prompt);
      } catch (e) {
        debugPrint('[ContentMatcher] matchContent LLM call gagal: $e');
        return List.generate(segments.length, (i) => i);
      }
      return _parseMatchResponse(response, segments.length,
          visualCount: visualDescriptions.length);
    }

    // S14 legacy path: audioTopics strings.
    final topics = audioTopics ?? [];
    if (topics.isEmpty || visualDescriptions.isEmpty) {
      return List.generate(topics.length, (i) => i);
    }

    final prompt = _buildMatchPrompt(visualDescriptions, topics);
    String response;
    try {
      response = await _ai.sendPrompt(prompt: prompt);
    } catch (e) {
      debugPrint('[ContentMatcher] matchContent LLM call gagal: $e');
      return List.generate(topics.length, (i) => i);
    }

    return _parseMatchResponse(response, topics.length,
        visualCount: visualDescriptions.length);
  }

  /// Build match prompt untuk S16 segments (sudah ada topic). PRD-SPRINT-16 §2.6.
  String _buildMatchPromptSegments(
      List<String> visualDescriptions, List<TranscriptSegment> segments) {
    final buf = StringBuffer();
    buf.writeln('Audio segments (with topics):');
    for (var i = 0; i < segments.length; i++) {
      buf.writeln('${i + 1}. Topic: "${segments[i].topic}"');
    }
    buf.writeln();
    buf.writeln('Visual segments (with descriptions):');
    for (var i = 0; i < visualDescriptions.length; i++) {
      buf.writeln('${_letter(i)}. "${visualDescriptions[i]}"');
    }
    buf.writeln();
    buf.writeln(
        'For each audio segment (in order 1 to ${segments.length}), '
        'which visual segment best matches?');
    buf.writeln(
        'Return ONLY a JSON array of visual segment indices (0-based), '
        'one per audio segment. Example: [0, 2, 1]');
    return buf.toString();
  }

  /// Build prompt untuk LLM content matching.
  String _buildMatchPrompt(
      List<String> visualDescriptions, List<String> audioTopics) {
    final buf = StringBuffer();
    buf.writeln('Audio segments (with topics):');
    for (var i = 0; i < audioTopics.length; i++) {
      buf.writeln('${i + 1}. Topic: "${audioTopics[i]}"');
    }
    buf.writeln();
    buf.writeln('Visual segments (with descriptions):');
    for (var i = 0; i < visualDescriptions.length; i++) {
      buf.writeln('${_letter(i)}. "${visualDescriptions[i]}"');
    }
    buf.writeln();
    buf.writeln(
        'For each audio segment (in order 1 to ${audioTopics.length}), '
        'which visual segment best matches?');
    buf.writeln(
        'Return ONLY a JSON array of visual segment indices (0-based), '
        'one per audio segment. Example: [0, 2, 1]');
    return buf.toString();
  }

  /// Parse LLM response → List<int>. Fallback sequential bila gagal.
  List<int> _parseMatchResponse(
    String response,
    int expectedLength, {
    required int visualCount,
  }) {
    try {
      // Extract JSON array from response (LLM mungkin tambahkan teks).
      final arrayMatch = RegExp(r'\[([^\]]*)\]').firstMatch(response);
      if (arrayMatch == null) {
        return List.generate(expectedLength, (i) => i);
      }
      final jsonStr = '[${arrayMatch.group(1)}]';
      final parsed = jsonDecode(jsonStr) as List;
      final indices = parsed
          .map((e) => (e is num) ? e.toInt() : int.tryParse('$e') ?? -1)
          .where((v) => v >= 0)
          .toList();

      // Validasi: panjang harus sama dengan expectedLength.
      if (indices.length != expectedLength) {
        return List.generate(expectedLength, (i) => i);
      }

      // Clamp indices ke range visual segments.
      return indices
          .map((v) => v.clamp(0, visualCount > 0 ? visualCount - 1 : 0))
          .toList();
    } catch (e) {
      debugPrint('[ContentMatcher] parse JSON gagal: $e → fallback sequential');
      return List.generate(expectedLength, (i) => i);
    }
  }

  /// Match audio segments to visual frame RANGES via LLM.
  ///
  /// New approach (PRD-SPRINT-18 content matching redesign):
  /// Instead of matching 1 frame index per audio segment, find a CONTIGUOUS
  /// RANGE of frames per audio topic. Visual persists until audio topic changes.
  ///
  /// Returns list of (startFrameIdx, endFrameIdx) per audio segment.
  /// Each range maps to actual frame timestamps → visual segment boundaries.
  Future<List<(int, int)>> matchContentRanges({
    required List<String> visualDescriptions,
    required List<TranscriptSegment> segments,
  }) async {
    if (segments.isEmpty || visualDescriptions.isEmpty) {
      return List.generate(
          segments.length, (i) => (0, visualDescriptions.length - 1 < 0 ? 0 : 0));
    }

    final prompt = _buildRangeMatchPrompt(visualDescriptions, segments);
    String response;
    try {
      response = await _ai.sendPrompt(prompt: prompt);
    } catch (e) {
      debugPrint('[ContentMatcher] matchContentRanges LLM call gagal: $e');
      // Fallback: distribute frames evenly across segments.
      return fallbackRanges(visualDescriptions.length, segments.length);
    }

    return _parseRangeResponse(
        response, segments.length, visualDescriptions.length);
  }

  /// Build prompt for range-based matching.
  String _buildRangeMatchPrompt(
      List<String> visualDescriptions, List<TranscriptSegment> segments) {
    final buf = StringBuffer();
    buf.writeln('You are a content matching engine.');
    buf.writeln();
    buf.writeln('Audio segments (in order):');
    for (var i = 0; i < segments.length; i++) {
      buf.writeln('${i + 1}. Topic: "${segments[i].topic}" '
          '(audio: ${segments[i].duration.toStringAsFixed(1)}s)');
    }
    buf.writeln();
    buf.writeln('Visual frames (sampled from video, in chronological order):');
    for (var i = 0; i < visualDescriptions.length; i++) {
      buf.writeln('$i. "${visualDescriptions[i]}"');
    }
    buf.writeln();
    buf.writeln('For each audio segment, find the CONTIGUOUS range of visual '
        'frames that best shows its topic.');
    buf.writeln('The visual should persist until the audio topic changes.');
    buf.writeln('All frames must be covered (no gaps, no overlaps).');
    buf.writeln();
    buf.writeln('Return ONLY a JSON array of [startFrame, endFrame] pairs '
        '(0-based, inclusive).');
    buf.writeln('Example: [[0,2], [3,5], [6,9]]');
    buf.writeln('Length must equal ${segments.length}.');
    return buf.toString();
  }

  /// Parse range response → List<(int, int)>.
  List<(int, int)> _parseRangeResponse(
    String response,
    int expectedLength,
    int frameCount,
  ) {
    try {
      final arrayMatch = RegExp(r'\[[\s\S]*\]').firstMatch(response);
      if (arrayMatch == null) {
        return fallbackRanges(frameCount, expectedLength);
      }
      final parsed = jsonDecode(arrayMatch.group(0)!) as List;
      final ranges = <(int, int)>[];
      for (final e in parsed) {
        if (e is List && e.length >= 2) {
          final start = (e[0] as num).toInt().clamp(0, frameCount - 1);
          final end = (e[1] as num).toInt().clamp(start, frameCount - 1);
          ranges.add((start, end));
        }
      }
      if (ranges.length != expectedLength) {
        return fallbackRanges(frameCount, expectedLength);
      }
      return ranges;
    } catch (e) {
      debugPrint('[ContentMatcher] parse ranges gagal: $e → fallback');
      return fallbackRanges(frameCount, expectedLength);
    }
  }

  /// Fallback: distribute frames evenly across segments.
  /// Public for use by AppState when matchContentRanges throws.
  List<(int, int)> fallbackRanges(int frameCount, int segCount) {
    if (frameCount <= 0 || segCount <= 0) return [];
    final perSeg = frameCount ~/ segCount;
    final ranges = <(int, int)>[];
    var start = 0;
    for (var i = 0; i < segCount; i++) {
      var end = start + perSeg - 1;
      if (i == segCount - 1) end = frameCount - 1; // last gets remainder
      end = end.clamp(start, frameCount - 1);
      ranges.add((start, end));
      start = end + 1;
    }
    return ranges;
  }

  /// Convert index 0-based ke huruf (0 → A, 1 → B, ...).
  String _letter(int i) =>
      String.fromCharCode('A'.codeUnitAt(0) + i);
}
