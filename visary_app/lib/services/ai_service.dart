import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'ai_provider_service.dart';
import 'local_analyzer.dart';

/// AI B-Roll Prompt Generator (PRD-SPRINT-05 §2.2).
///
/// Membaca konteks narasi pada "Gap Visual" (segmen dengan visual monoton
/// tapi energi audio tinggi), lalu mengirim prompt ke VLM/LLM via
/// [AiProviderService] untuk mendapatkan keyword pencarian stok video.
///
/// Jika AI tidak tersedia (mode dasar, PRD §7.5), keyword dihasilkan
/// heuristik dari [LocalAnalyzer].
class AiService {
  AiService({AiProviderService? providerService})
      : _provider = providerService ?? AiProviderService();

  final AiProviderService _provider;

  /// Generate keyword B-roll untuk satu gap via AI provider.
  ///
  /// [context] adalah teks narasi/konteks di sekitar segmen (transkrip ASR
  /// atau deskripsi heuristik). [gap] berisi rentang waktu dan alasan.
  ///
  /// Mengembalikan keyword prompt yang siap dipakai untuk pencarian stok video
  /// (mis. "Cinematic coffee pouring close-up").
  Future<String> generateBrollKeyword({
    required BrollRecommendation gap,
    String? context,
  }) async {
    // Jika AI tidak aktif, pakai keyword heuristik yang sudah ada.
    final active = await _provider.isByokActive();
    if (!active) {
      debugPrint('[AiService] BYOK nonaktif — keyword heuristik dipakai.');
      return gap.keywordPrompt;
    }

    final prompt = _buildPrompt(gap, context);
    try {
      final result = await _provider.sendPrompt(
        prompt: prompt,
        systemInstruction: _systemPrompt,
      );
      final keyword = result.trim();
      if (keyword.isEmpty) return gap.keywordPrompt;
      return keyword;
    } catch (e) {
      debugPrint('[AiService] AI prompt gagal: $e — fallback heuristik.');
      return gap.keywordPrompt;
    }
  }

  /// Generate keyword B-roll untuk batch gap sekaligus.
  Future<List<BrollRecommendation>> generateBrollKeywords({
    required List<BrollRecommendation> gaps,
    String? Function(BrollRecommendation gap)? contextFor,
  }) async {
    final results = <BrollRecommendation>[];
    for (final gap in gaps) {
      final ctx = contextFor?.call(gap);
      final keyword = await generateBrollKeyword(gap: gap, context: ctx);
      results.add(gap.copyWith(keywordPrompt: keyword));
    }
    return results;
  }

  static const _systemPrompt =
      'You are a B-roll recommendation engine for short-form video creators. '
      'Given a visual gap description with audio context, generate a concise '
      'English keyword phrase (max 8 words) suitable for searching stock video. '
      'Format: descriptive, cinematic, action-oriented. '
      'Example: "Cinematic coffee pouring close-up latte art". '
      'Return ONLY the keyword phrase, no explanation.';

  String _buildPrompt(BrollRecommendation gap, String? context) {
    final dur = (gap.endSec - gap.startSec).toStringAsFixed(0);
    final buf = StringBuffer()
      ..writeln('Visual gap detected in video:')
      ..writeln('  Duration: ${dur}s (static visual, no shot change)')
      ..writeln('  Audio energy: high (narration active)')
      ..writeln('  Reason: ${gap.reason}');
    if (context != null && context.isNotEmpty) {
      buf.writeln('  Narration context: "$context"');
    }
    buf.writeln('Generate a B-roll search keyword for this segment.');
    return buf.toString();
  }

  /// Deteksi gap visual + generate keyword AI dalam satu langkah.
  /// Dipakai AppState setelah analisis selesai untuk melengkapi clip dengan
  /// rekomendasi B-roll.
  Future<List<BrollRecommendation>> detectAndEnrichGaps({
    required VideoSignals signals,
    required double clipStart,
    required double clipEnd,
    String? narrationContext,
  }) async {
    final gaps = LocalAnalyzer.detectVisualGaps(
      signals,
      a: clipStart,
      b: clipEnd,
    );

    if (gaps.isEmpty) return [];

    final enriched = await generateBrollKeywords(
      gaps: gaps,
      contextFor: narrationContext != null ? (_) => narrationContext : null,
    );
    return enriched;
  }
}
