import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'ai_provider_service.dart';

/// Content-aware audio-visual matching via VLM + LLM. PRD-SPRINT-14.
///
/// 1. `describeFrames` — VLM (Gemini Vision) memberi deskripsi per frame.
/// 2. `extractTopics` — LLM meringkas topik per audio segment.
/// 3. `matchContent` — LLM mencocokkan audio topics ↔ visual descriptions.
class ContentMatcherService {
  ContentMatcherService(this._ai);

  final AiProviderService _ai;

  /// Describe setiap frame via VLM. PRD-SPRINT-14 §2.3.
  ///
  /// Untuk setiap frame: baca bytes → base64 encode → `visionPrompt()`.
  /// Mengembalikan list deskripsi, satu per frame.
  Future<List<String>> describeFrames({
    required List<String> framePaths,
  }) async {
    final descriptions = <String>[];
    for (final path in framePaths) {
      try {
        final bytes = await File(path).readAsBytes();
        final b64 = base64Encode(bytes);
        final desc = await _ai.visionPrompt(
          prompt: 'Describe what is shown in this image in one concise sentence.',
          imageBase64: b64,
        );
        descriptions.add(desc.trim());
      } catch (e) {
        debugPrint('[ContentMatcher] describeFrames gagal untuk $path: $e');
        descriptions.add('');
      }
    }
    return descriptions;
  }

  /// Extract topic per audio segment dari transcript. PRD-SPRINT-14 §2.4.
  ///
  /// Untuk setiap audio segment (dari cutPoints): join words dalam range,
  /// kirim ke `sendPrompt()` untuk summary 2-3 kata.
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

  /// Match audio topics ke visual descriptions via LLM. PRD-SPRINT-14 §2.5.
  ///
  /// Kirim semua descriptions + topics ke LLM dalam satu prompt, minta
  /// JSON array of visual indices per audio segment.
  /// Fallback: bila parse gagal → sequential [0, 1, 2, ...].
  Future<List<int>> matchContent({
    required List<String> visualDescriptions,
    required List<String> audioTopics,
  }) async {
    if (audioTopics.isEmpty || visualDescriptions.isEmpty) {
      return List.generate(audioTopics.length, (i) => i);
    }

    final prompt = _buildMatchPrompt(visualDescriptions, audioTopics);
    String response;
    try {
      response = await _ai.sendPrompt(prompt: prompt);
    } catch (e) {
      debugPrint('[ContentMatcher] matchContent LLM call gagal: $e');
      return List.generate(audioTopics.length, (i) => i);
    }

    return _parseMatchResponse(response, audioTopics.length,
        visualCount: visualDescriptions.length);
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

  /// Convert index 0-based ke huruf (0 → A, 1 → B, ...).
  String _letter(int i) =>
      String.fromCharCode('A'.codeUnitAt(0) + i);
}
