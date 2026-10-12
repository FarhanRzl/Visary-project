# PRD Sprint 16 — Semantic Audio Segmentation + Content Matching Redesign

**Dokumen ID:** PRD-SPRINT-16
**Modul Fokus:** Semantic segmentation, LLM context-aware splitting, matching pipeline redesign
**Target File:** `lib/services/content_matcher_service.dart`, `lib/services/resequence_service.dart`, `lib/services/ai_provider_service.dart`, `lib/state/app_state.dart`, `lib/widgets/audio_panel.dart`, `lib/models/models.dart`, `test/*`
**Referensi:** `PRD-SPRINT-13` (resequencing), `PRD-SPRINT-14` (content matching), `PRD-SPRINT-15` (ASR fixes), `EXECUTION-ORDER-PRD.md`
**Status:** 📝 Draft

---

## 1. Latar Belakang & Masalah

S14 content matching memakai **timing-based segmentation** (pause ≥200ms atau group 5 kata) lalu per-segment LLM topic extraction. Masalah:

1. **Segmentasi tidak relevan konten.** Cut by pause timing → satu topik bisa terpecah di tengah, atau dua topik berbeda menyatu di satu segmen.
2. **Boros API call.** N segmen × extractTopics = N LLM calls, padaharnya segmentasi + topic bisa sekali jalan dalam satu call.
3. **Matching quality rendah.** Topic per segmen timing-based tidak reflect konteks narasi sebenarnya.
4. **Jumlah segmen mismatch.** Cut points dari pause ≠ jumlah shot video. Resequencer cycle video segments → visual berulang.

**Pandangan user:** ASR output dipotong berdasarkan **konteks** yang diangkat, bukan timing. Matching tinggal isi visual per konteks. Jumlah segmen = jumlah shot video.

---

## 2. Sasaran (Scope of Work)

### 2.1 Semantic Segmentation (`ContentMatcherService.segmentByContext`)
- Method baru: kirim full transcript text + word list + target segment count (N = jumlah shot video) ke LLM dalam **satu call**.
- LLM return JSON array: `[{startWord, endWord, topic}, ...]` — N segmen sesuai shot count.
- Setiap segmen: `startWord`/`endWord` = index kata (0-based), `topic` = 2-3 kata label.
- Konversi word index → timestamp: `word[startWord].start` → `word[endWord].end`.
- **Menggantikan:** `detectCutPoints` (timing) + `extractTopics` (per-segment LLM) dari S14.

### 2.2 TranscriptSegment Model (`models.dart`)
```dart
class TranscriptSegment {
  final int startWord;    // index kata awal (0-based)
  final int endWord;      // index kata akhir (inclusive)
  final String topic;     // label topik 2-3 kata
  final double startSec;  // diturunkan dari word[startWord].start
  final double endSec;    // diturunkan dari word[endWord].end

  double get duration => endSec - startSec;
}
```

### 2.3 Matching Pipeline Redesign (`app_state.dart` — `contentAwareResequence`)

**Flow baru:**
```
Stage 1: Extract frames per shot (VLM)          → visual descriptions [N]
Stage 2: Semantic segmentation (1 LLM call)     → segments [{topic, timeRange}] [N]
Stage 3: Match segments ↔ visuals (1 LLM call)  → matchOrder [N]
Stage 4: Resequence with matchOrder             → ClipParts
```

**vs flow lama (S14):**
```
Stage 1: Extract frames per shot                → visual descriptions
Stage 2: detectCutPoints (timing)               → cut points [M]
Stage 3: extractTopics per segment (M calls)    → topics [M]
Stage 4: matchContent (1 call)                  → matchOrder [M→N mapping]
Stage 5: Resequence
```

Hemat: M-1 API calls (extractTopics eliminasi). Segmentasi = N (match shot count), bukan M (timing-based).

### 2.4 Resequencer Update (`resequence_service.dart`)
- `buildParts` menerima `List<TranscriptSegment>` alih-alih `List<double> cutPoints`.
- Per segmen i: audio duration = `segment[i].duration`, video segment = `matchOrder[i]`.
- Speed-adjust: `videoSegDur / segment[i].duration`, clamp 0.25x–4x.
- Fallback: jika segments null/kosong → sequential (S13 behavior dengan `detectCutPoints`).

### 2.5 Gemini Timestamp Warning (`audio_panel.dart`)
- Jika provider aktif = Gemini → tampilkan info saat klik TRANSCRIBE:
  "Estimasi timestamp (Gemini) — kurang presisi. Untuk word-level akurat, gunakan OpenAI/Groq/Custom (Whisper) di Settings."
- Bukan blocking — user tetap bisa lanjut. Hanya awareness.

### 2.6 Match Prompt Redesign (`content_matcher_service.dart`)
- `_buildSegmentPrompt(transcript, wordCount, targetSegments)`:
  ```
  You are a content segmentation engine. Split this transcript into exactly N segments
  based on topic/context shifts. N = {targetSegments}.

  Transcript (word-indexed):
  0: "Hello"
  1: "everyone"
  2: "today"
  ...

  Return JSON: [{"startWord": 0, "endWord": 5, "topic": "greeting"}, ...]
  - startWord/endWord: 0-based word index (inclusive)
  - Exactly {targetSegments} segments
  - Cover all words (endWord of last = {wordCount-1})
  - topic: 2-3 word English label
  ```
- `_buildMatchPrompt` update: terima `List<TranscriptSegment>` (sudah ada topic) + visual descriptions.

### 2.7 Fallback Chain
1. Semantic segmentation gagal (LLM error / parse fail / wrong count) → fallback `detectCutPoints` (S13 timing) + `extractTopics` (S14 per-segment).
2. `detectCutPoints` gagal → fallback sequential segments (3s each).
3. Match gagal → fallback sequential matchOrder `[0, 1, 2, ...]`.

---

## 3. Spesifikasi Teknis

### 3.1 `lib/models/models.dart` — TranscriptSegment
```dart
/// Segmen transcript berdasarkan konteks/topik (PRD-SPRINT-16).
/// Dihasilkan oleh LLM semantic segmentation, bukan timing-based cut.
class TranscriptSegment {
  final int startWord;
  final int endWord;
  final String topic;
  final double startSec;
  final double endSec;

  const TranscriptSegment({
    required this.startWord,
    required this.endWord,
    required this.topic,
    required this.startSec,
    required this.endSec,
  });

  double get duration => endSec - startSec;

  /// Apakah segmen ini valid (punya durasi > 0).
  bool get isValid => duration > 0 && endWord >= startWord;
}
```

### 3.2 `lib/services/content_matcher_service.dart` — segmentByContext
```dart
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

  final prompt = _buildSegmentPrompt(transcript, targetSegments);
  String response;
  try {
    response = await _ai.sendPrompt(prompt: prompt);
  } catch (e) {
    debugPrint('[S16] segmentByContext LLM gagal: $e');
    return []; // → caller fallback ke detectCutPoints
  }

  return _parseSegmentResponse(response, transcript.words, targetSegments);
}

/// Parse JSON response → List<TranscriptSegment>.
/// Validasi: tepat targetSegments, cover semua words, index valid.
List<TranscriptSegment> _parseSegmentResponse(
  String response,
  List<WordToken> words,
  int targetSegments,
) {
  try {
    final jsonMatch = RegExp(r'\[.*\]', dotMatch: true).firstMatch(response);
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
    if (segments.length != targetSegments) return [];

    return segments;
  } catch (e) {
    debugPrint('[S16] parse segment gagal: $e');
    return [];
  }
}
```

### 3.3 `lib/services/resequence_service.dart` — buildParts with segments
```dart
/// Build ClipParts dari semantic segments + matchOrder. PRD-SPRINT-16.
///
/// Setiap segmen punya: audio duration (segment.duration), video segment
/// index (matchOrder[i]), speed-adjust clamp 0.25x–4x.
List<ClipPart> buildPartsWithSegments({
  required List<TranscriptSegment> segments,
  required double videoDuration,
  required double fallbackDuration,
  List<int>? matchOrder,
}) {
  if (segments.isEmpty || videoDuration <= 0) {
    return [ClipPart(0, fallbackDuration)];
  }

  final numSegs = segments.length;
  final videoSegDur = videoDuration / numSegs;
  final parts = <ClipPart>[];

  for (var i = 0; i < numSegs; i++) {
    final audioDur = segments[i].duration;
    if (audioDur <= 0) continue;

    final segIdx = (matchOrder != null && i < matchOrder.length)
        ? matchOrder[i]
        : i;
    final vStart = segIdx * videoSegDur;
    final vEnd = (segIdx + 1) * videoSegDur;

    final rawSpeed = videoSegDur / audioDur;
    final speed = rawSpeed.clamp(0.25, 4.0);

    parts.add(ClipPart(vStart, vEnd, speed));
  }

  return parts.isEmpty ? [ClipPart(0, fallbackDuration)] : parts;
}
```

### 3.4 `lib/state/app_state.dart` — contentAwareResequence redesign
```dart
Future<List<int>> contentAwareResequence(String projectId, ...) async {
  // ... provider check, frame extraction (Stage 1) — same as S14 ...

  // ── Stage 2: Semantic segmentation ──
  onProgress?.call('Segmenting transcript by context...');
  final shotCount = frameTimestamps.length;
  final t = signals.transcript;

  List<TranscriptSegment> segments;
  if (t != null && t.words.isNotEmpty) {
    segments = await matcher.segmentByContext(
      transcript: t,
      targetSegments: shotCount,
    );
    if (segments.isEmpty) {
      // Fallback: S13 timing-based cut points.
      debugPrint('[S16] semantic segment gagal → fallback timing');
      final cutPoints = _resequencer.detectCutPoints(t.words);
      segments = _cutPointsToSegments(cutPoints, t.words);
    }
  } else {
    // Visual-only: no transcript → sequential segments.
    segments = _sequentialSegments(shotCount, videoDuration);
  }

  // ── Stage 3: Match content ──
  onProgress?.call('Matching content...');
  matchOrder = await matcher.matchContent(
    visualDescriptions: visualDescriptions,
    segments: segments,  // already has topics
  );

  // ── Stage 4: Resequence ──
  onProgress?.call('Re-sequencing clips...');
  final newClips = _resequencer.resequenceWithSegments(
    clips: p.clips,
    segments: segments,
    videoDuration: videoDuration,
    matchOrder: matchOrder,
  );
  // ... notifyListeners ...
}
```

### 3.5 Gemini Timestamp Warning
```dart
// audio_panel.dart — _transcribeAudio()
final provider = state.activeAiProvider;
if (provider == AiProviderType.gemini) {
  showBrutalSnack(context,
    'Estimasi timestamp (Gemini) — kurang presisi. '
    'Untuk word-level akurat, gunakan OpenAI/Groq/Custom (Whisper) di Settings.',
    color: VC.yellow);
}
```

---

## 4. Rencana Testing

* **Test 16.1** `test/unit/services/semantic_segmentation_test.dart`
  * `segmentByContext` dengan mock LLM response → parse benar (N segmen, word index valid, topic terisi).
  * Parse response dengan wrong segment count → return empty (fallback).
  * Parse response dengan invalid word index → clamp ke valid range.
  * LLM error → return empty (fallback).

* **Test 16.2** `test/unit/services/resequence_segments_test.dart`
  * `buildPartsWithSegments` dengan N segments + matchOrder → ClipParts sesuai.
  * Segments kosong → fallback `[ClipPart(0, fallback)]`.
  * Speed-adjust: audioDur ≠ videoSegDur → speed benar, clamp 0.25–4x.

* **Test 16.3** `test/unit/services/match_prompt_test.dart`
  * `_buildSegmentPrompt` mengandung word count + target segments.
  * `_buildMatchPrompt` dengan segments (sudah ada topic) → prompt benar.

* **Test 16.4** `test/unit/services/fallback_chain_test.dart`
  * Semantic segment gagal → fallback detectCutPoints → segments valid.
  * detectCutPoints gagal → fallback sequential 3s → segments valid.
  * Match gagal → fallback sequential matchOrder.

* **Test 16.5** `test/widget/gemini_warning_test.dart`
  * Provider = Gemini → snackbar warning muncul saat TRANSCRIBE.
  * Provider = OpenAI → tidak ada warning.

---

## 5. Kriteria Penerimaan

* TRANSCRIBE audio pengganti → segmentByContext → N segmen sesuai shot count.
* MATCH CONTENT → visual diisi per segmen konteks (bukan timing).
* Jumlah API call berkurang: dari 2N+1 menjadi N+2.
* Fallback: semantic segment gagal → timing-based (S13) tetap jalan.
* Fallback: transcript kosong → visual-only matching.
* Provider Gemini → warning "estimasi timestamp" tampil.
* `flutter analyze lib` → 0; `flutter test` hijau.

---

## 6. Risiko & Mitigasi

| Risiko | Dampak | Mitigasi |
|--------|--------|----------|
| LLM return wrong segment count | Sedang | Validasi count = targetSegments. Mismatch → fallback detectCutPoints. |
| LLM return invalid word index | Rendah | Clamp ke [0, wordCount-1]. Skip invalid segmen. |
| Gemini word timestamps estimated → segment boundary tidak presisi | Sedang | UI warning. User bisa switch ke Whisper provider. |
| Shot count > word count (video banyak shot, audio pendek) | Rendah | Clamp targetSegments ke max(wordCount, 1). |
| LLM prompt terlalu panjang (transcript ribuan kata) | Sedang | Limit transcript to first 500 words dalam prompt. Topic extraction tetap akurat. |
| S13 detectCutPoints compatibility | Rendah | `detectCutPoints` tetap dipertahankan sebagai fallback. `buildParts` (lama) tetap untuk S13 path. |

---

## 7. Definition of Done

- `flutter analyze lib` → 0.
- `flutter test` hijau (existing + 5 suite baru).
- Smoke test: video + replacement audio → TRANSCRIBE → MATCH CONTENT → visual relevant dengan konteks audio per segmen.
- Smoke test: fallback semantic gagal → timing-based tetap jalan.
- Smoke test: provider Gemini → warning tampil.
- S13 timing-based resequencing tidak break (fallback path).
- S14 existing matching tidak break (visual-only path tetap jalan).

---

## 8. Dependency & Posisi Roadmap

- **Dependensi:** S11 (ASR), S13 (resequencing — fallback), S14 (content matching — base), S15 (ASR fixes — base).
- **Integrasi:** ContentMatcherService (semantic segmentation + matching), Resequencer (buildPartsWithSegments), AppState (pipeline redesign), AudioPanel (Gemini warning), models.dart (TranscriptSegment).
- **Urutan:** setelah S15. Independen dari S07 (UI fidelity).
- **Estimasi:** 3–4 hari (semantic segmentation + prompt engineering + resequencer update + pipeline redesign + fallback chain + test).

---

## 9. Catatan & Out of Scope

- **Whisper provider routing** (prioritize OpenAI/Groq/custom over Gemini) — out of scope. S16 menampilkan warning untuk Gemini, tidak force switch.
- **Multi-frame per shot** (3 frame: awal/tengah/akhir) — out of scope. 1 frame per shot tetap.
- **User manual override segment/match** — out of scope. User bisa edit parts manual setelah resequence via timeline editor.
- **Embedding similarity matching** — out of scope. LLM matching tetap.
- **Segment preview UI** (tampilkan segmen + topic sebelum match) — out of scope. Future enhancement.
- **Re-segmentation with different N** (user adjust shot count) — out of scope. N = shot count tetap.
- **TranscriptSegment persistensi** — out of scope untuk S16. Segments di-recompute setiap MATCH CONTENT. Persist di future jika perlu.
