# PRD Sprint 14 — Content-Aware Audio-Visual Matching

**Dokumen ID:** PRD-SPRINT-14
**Modul Fokus:** Vision API (VLM), Frame Extraction, Audio Topic Extraction, LLM Content Matching, Content-Aware Re-sequencing
**Target File:** `lib/services/ai_provider_service.dart`, `lib/services/video_service.dart`, `lib/services/content_matcher_service.dart` (baru), `lib/services/resequence_service.dart`, `lib/state/app_state.dart`, `lib/widgets/audio_panel.dart`, `test/*`
**Referensi:** `PRD-SPRINT-05` (AI B-Roll — stub), `PRD-SPRINT-06` (BYOK — done), `PRD-SPRINT-11` (ASR), `PRD-SPRINT-13` (resequencing), `EXECUTION-ORDER-PRD.md`
**Status:** ✅ Selesai — semua scope §2.1–§2.8 terimplementasi. 180 test pass, analyze 0.

---

## 1. Latar Belakang & Masalah

S13 mengimplement timing-based re-sequencing: audio word boundaries → cut video sequentially → speed-adjust. Tapi **tidak ada content matching** — visual yang ditampilkan tidak relevan dengan topik yang dibahas audio.

**Gap:** Audio membahas "gunung" tapi video menampilkan "close-up wajah". Tidak ada pemahaman konten visual maupun audio.

**Solusi:** S14 — content-aware matching via VLM + LLM:
1. Extract frame per shot → kirim ke VLM (Gemini Vision) → visual description
2. Extract topic per audio segment dari transcript → kirim ke LLM → topic/keyword
3. Match audio topics ↔ visual descriptions via LLM → urutan terbaik
4. Re-sequence clips berdasarkan urutan matching + speed-adjust

**VLM Provider:** Gemini 1.5 Flash (free tier, vision support, sudah ada di BYOK). OpenAI GPT-4o sebagai alternatif (Phase 2/future).

---

## 2. Sasaran (Scope of Work)

### 2.1 Vision API (`AiProviderService.visionPrompt()`)
- Method baru `visionPrompt({prompt, imageBase64, mimeType})` → `String` (description).
- Gemini: `inline_data {mimeType, data: base64}` dalam `parts`.
- OpenAI GPT-4o: `image_url {url: "data:image/jpeg;base64,..."}` dalam `messages`.
- Groq: tidak support vision → throw `UnsupportedError`.
- Custom: coba format OpenAI-compatible vision.

### 2.2 Frame Extraction (`VideoService.extractFrame()`)
- Method baru `extractFrame({sourcePath, timestamp, outputPath})` → path file JPG.
- FFmpeg: `-ss {timestamp} -i {source} -frames:v 1 -q:v 2 {output}.jpg`.
- 1 frame per shot: timestamp = tengah shot `(shot[i] + shot[i+1]) / 2`.
- Bila shots minim (1 segment): extract frame per 3 detik.

### 2.3 Visual Description Service (`ContentMatcherService`)
- `describeFrames({frames, shots})` → `List<String>` descriptions.
- Untuk setiap frame: `visionPrompt(prompt="Describe this image briefly in one sentence", imageBase64)`.
- Batch: proses sequential (rate limit aware), bisa parallel bila memungkinkan.

### 2.4 Audio Topic Extraction
- `extractTopics({words, cutPoints})` → `List<String>` topics.
- Untuk setiap audio segment: kirim transcript text segment ke `sendPrompt()`.
- Prompt: "Summarize the topic of this text in 2-3 words: '{segment text}'".
- Return: list of topics, one per segment.

### 2.5 LLM Content Matching
- `matchContent({visualDescriptions, audioTopics})` → `List<int>` (visual index per audio segment).
- Kirim semua descriptions + topics ke LLM dalam satu prompt:
  ```
  Audio segments (with topics):
  1. Topic: "greeting"
  2. Topic: "coffee"
  
  Visual segments (with descriptions):
  A. "Person talking"
  B. "Coffee being poured"
  
  For each audio segment, which visual segment best matches?
  Return JSON array of visual indices: [index1, index2, ...]
  ```
- Parse JSON response → `List<int>`.
- Fallback: bila parse gagal → sequential ordering (S13 behavior).

### 2.6 Content-Aware Re-sequencing (`Resequencer` update)
- `buildParts()` update: terima `matchOrder` (List<int>) parameter.
- Untuk audio segment i: gunakan video segment `matchOrder[i]` (bukan sequential i).
- Speed-adjust tetap sama: `videoSegDur / audioSegDur`, clamp 0.25x–4x.
- Bila `matchOrder` null/kosong → fallback sequential (S13 behavior).

### 2.7 Pipeline Integration (`AppState`)
- Method baru `contentAwareResequence(String projectId)`:
  1. Extract frames per shot → save ke workspace.
  2. Describe frames via VLM → visual descriptions.
  3. Extract audio topics from transcript.
  4. Match content via LLM → match order.
  5. Resequence clips dengan match order.
  6. `notifyListeners()`.
- Trigger: tombol "MATCH CONTENT" di AudioPanel (setelah TRANSCRIBE AUDIO).
- Loading: multi-stage progress ("Extracting frames...", "Analyzing visuals...", "Matching...").
- Error handling: setiap stage bisa fail → fallback ke timing-based (S13).
- Bila Groq active (no vision): SnackBar "Vision butuh Gemini/OpenAI. Switch provider di Settings."

### 2.8 AudioPanel UI
- Tombol "MATCH CONTENT" (icon `Icons.compare`).
- Visible hanya jika: transcript ada (words not empty) + replacement audio active.
- Setelah klik: multi-stage progress indicator.
- Result: SnackBar "Content matched: N segments. Clips di-resequence."

---

## 3. Spesifikasi Teknis

### 3.1 `lib/services/ai_provider_service.dart` — visionPrompt
```dart
/// Vision inference: kirim image + text prompt ke VLM. PRD-SPRINT-14.
Future<String> visionPrompt({
  required String prompt,
  required String imageBase64,
  String mimeType = 'image/jpeg',
}) async {
  final active = await isByokActive();
  if (!active) throw StateError('BYOK tidak aktif');
  final provider = await storage.getActiveProvider();

  switch (provider) {
    case AiProviderType.gemini:
      // POST generateContent dengan inline_data
      final key = (await storage.getGeminiKey()) ?? '';
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$key',
      );
      final res = await _client.post(uri, headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'parts': [
            {'text': prompt},
            {'inline_data': {'mime_type': mimeType, 'data': imageBase64}},
          ]}],
        }),
      );
      // parse response → text
    case AiProviderType.openai:
      // POST chat/completions dengan image_url
    case AiProviderType.custom:
      // coba format OpenAI-compatible vision
    case AiProviderType.groq:
    case AiProviderType.server:
      throw UnsupportedError('Provider tidak support vision');
  }
}
```

### 3.2 `lib/services/video_service.dart` — extractFrame
```dart
/// Extract 1 frame dari video pada timestamp tertentu. PRD-SPRINT-14.
static Future<String> extractFrame({
  required String sourcePath,
  required double timestamp,
  required String outputPath,
}) async {
  await Directory(File(outputPath).parent.path).create(recursive: true);
  final args = [
    '-hide_banner', '-loglevel', 'error',
    '-ss', timestamp.toStringAsFixed(3),
    '-i', sourcePath,
    '-frames:v', '1',
    '-q:v', '2',
    '-y', outputPath,
  ];
  // run ffmpeg, return outputPath
}
```

### 3.3 `lib/services/content_matcher_service.dart` (baru)
```dart
class ContentMatcherService {
  final AiProviderService _ai;

  /// Describe setiap frame via VLM.
  Future<List<String>> describeFrames({
    required List<String> framePaths,
  }) async {
    final descriptions = <String>[];
    for (final path in framePaths) {
      final bytes = await File(path).readAsBytes();
      final b64 = base64Encode(bytes);
      final desc = await _ai.visionPrompt(
        prompt: 'Describe what is shown in this image in one concise sentence.',
        imageBase64: b64,
      );
      descriptions.add(desc);
    }
    return descriptions;
  }

  /// Extract topic per audio segment dari transcript.
  Future<List<String>> extractTopics({
    required List<WordToken> words,
    required List<double> cutPoints,
  }) async {
    final topics = <String>[];
    for (var i = 0; i < cutPoints.length - 1; i++) {
      final segWords = words.where((w) =>
        w.start >= cutPoints[i] && w.end <= cutPoints[i + 1]);
      final text = segWords.map((w) => w.word).join(' ');
      final topic = await _ai.sendPrompt(
        prompt: 'Summarize the topic of this text in 2-3 words: "$text"',
      );
      topics.add(topic.trim());
    }
    return topics;
  }

  /// Match audio topics ke visual descriptions via LLM.
  Future<List<int>> matchContent({
    required List<String> visualDescriptions,
    required List<String> audioTopics,
  }) async {
    final prompt = buildMatchPrompt(visualDescriptions, audioTopics);
    final response = await _ai.sendPrompt(prompt: prompt);
    return parseMatchResponse(response, audioTopics.length);
  }
}
```

### 3.4 `lib/services/resequence_service.dart` — update buildParts
```dart
List<ClipPart> buildParts({
  required List<double> cutPoints,
  required double videoDuration,
  required double fallbackDuration,
  List<int>? matchOrder, // PRD-SPRINT-14: content-aware ordering
}) {
  // ...
  for (var i = 0; i < numSegs; i++) {
    // Content-aware: gunakan matchOrder[i] untuk pilih video segment
    final segIdx = (matchOrder != null && i < matchOrder.length)
        ? matchOrder[i] : i;
    final vStart = segIdx * videoSegDur;
    final vEnd = (segIdx + 1) * videoSegDur;
    // ... speed-adjust same as before
  }
}
```

### 3.5 `lib/state/app_state.dart` — contentAwareResequence
```dart
Future<void> contentAwareResequence(String projectId) async {
  // 1. Extract frames per shot
  // 2. Describe frames via VLM
  // 3. Extract audio topics
  // 4. Match content
  // 5. Resequence with matchOrder
  // 6. notifyListeners()
}
```

---

## 4. Rencana Testing

* **Test 14.1** `test/unit/services/vision_prompt_test.dart`
  * Mock HTTP → visionPrompt parse response benar (Gemini format).
  * Groq provider → UnsupportedError.

* **Test 14.2** `test/unit/services/frame_extraction_test.dart`
  * extractFrame → file JPG ada di path.
  * Timestamp di tengah shot.

* **Test 14.3** `test/unit/services/content_matcher_test.dart`
  * describeFrames: mock visionPrompt → list descriptions.
  * extractTopics: mock sendPrompt → list topics.
  * matchContent: mock sendPrompt → parse JSON → List<int>.
  * matchContent parse fail → fallback sequential.

* **Test 14.4** `test/unit/services/resequence_content_aware_test.dart`
  * buildParts dengan matchOrder → video segments sesuai urutan match.
  * matchOrder null → fallback sequential (S13).
  * matchOrder length mismatch → clamp/fallback.

* **Test 14.5** `test/widget/audio_panel_match_button_test.dart`
  * Tombol MATCH CONTENT visible saat transcript + replacement aktif.
  * Tombol hidden bila transcript kosong atau mode original.

---

## 5. Kriteria Penerimaan

* Tombol "MATCH CONTENT" di AudioPanel, visible saat transcript + replacement audio aktif.
* Klik → extract frames → VLM describe → topic extraction → LLM match → resequence.
* Hasil export: video segment yang ditampilkan relevan dengan topik audio.
* Fallback: bila VLM/LLM gagal → timing-based resequence (S13).
* Bila Groq active → pesan "Vision butuh Gemini/OpenAI".
* Progress indicator multi-stage.
* `flutter analyze lib` → 0; `flutter test` hijau.

---

## 6. Risiko & Mitigasi

| Risiko | Dampak | Mitigasi |
|--------|--------|----------|
| Gemini rate limit (free tier 15 RPM) | Sedang | Sequential processing, delay antar request |
| VLM description tidak akurat | Sedang | Prompt engineering; fallback ke timing-based |
| LLM match response tidak parseable | Rendah | Try-catch parse → fallback sequential |
| Frame extraction lambat (video panjang) | Sedang | Limit max 20 frames; subsample bila shots > 20 |
| Groq tidak support vision | Tinggi | Deteksi provider → pesan switch ke Gemini/OpenAI |
| Cost API (banyak request) | Sedang | Gemini free tier; batch bila memungkinkan |
| Base64 image size besar | Rendah | Compress JPG q:v 2; resize bila perlu |

---

## 7. Definition of Done

- `flutter analyze lib` → 0.
- `flutter test` hijau (existing + 5 suite baru).
- Smoke test: video + replacement audio → TRANSCRIBE → MATCH CONTENT → export → visual relevant dengan audio topic.
- Fallback: VLM/LLM fail → timing-based (S13) tetap jalan.
- S13 timing-based resequence tidak break.

---

## 8. Dependency & Posisi Roadmap

- **Dependensi:** S06 (BYOK — done), S11 (ASR — done), S13 (resequencing — done).
- **Integrasi:** AudioPanel (tombol), AppState (pipeline), AiProviderService (vision), VideoService (frame), Resequencer (matchOrder).
- **Urutan:** setelah S13. Independen dari S07 (UI fidelity).
- **Estimasi:** 3–5 hari (vision API + frame extraction + matcher + resequence update + test).

---

## 9. Catatan & Out of Scope

- **Multi-frame per shot** (3 frame: awal/tengah/akhir) — out of scope. 1 frame per shot cukup untuk MVP.
- **Embedding similarity matching** — out of scope. LLM matching cukup untuk MVP.
- **OpenAI GPT-4o vision** — out of scope (Phase 2). Gemini free tier cukup.
- **Real-time preview** content-aware — out of scope. Preview tetap S10 (mute+replace). Content-aware hanya saat export.
- **Visual OCR** — OCR sudah ada di `VideoSignals` (S03), bisa dipakai sebagai additional context di matcher, tapi tidak masuk scope utama S14.
- **User manual override** match order — out of scope. User bisa edit parts manual setelah resequence via timeline editor.
