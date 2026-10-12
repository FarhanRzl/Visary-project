# PRD Sprint 15 — ASR & Content Matching Flow Fixes

**Dokumen ID:** PRD-SPRINT-15
**Modul Fokus:** ASR pipeline, transcript persistensi, content matching fallback, base64 encoding, retry mechanism
**Target File:** `lib/services/ai_provider_service.dart`, `lib/services/content_matcher_service.dart`, `lib/services/resequence_service.dart`, `lib/state/app_state.dart`, `lib/data/local/database.dart`, `lib/data/local/project_repository.dart`, `lib/screens/upload_screen.dart`, `lib/widgets/audio_panel.dart`, `test/*`
**Referensi:** `PRD-SPRINT-11` (ASR), `PRD-SPRINT-13` (resequencing), `PRD-SPRINT-14` (content matching), `EXECUTION-ORDER-PRD.md`
**Status:** 📝 Draft

---

## 1. Latar Belakang & Masalah

S14 content-aware matching dan S11/S13 ASR pipeline sudah terimplementasi, tapi memiliki bug dan gap yang membuat flow tidak reliable:

### 1.1 ASR Silent Failure (CRITICAL)
`_transcribeViaGemini` return `Transcript` kosong saat API error (non-200) — user tidak lihat apa-apa, tidak ada pesan error. Gemini API key saat ini mendapat 503 "high demand" → transcript kosong → ASR "tidak muncul".

**Root cause:** Error ditelan diam-diam (`return Transcript(empty)` bukan `throw`).

### 1.2 Base64 Newline Bug (CRITICAL)
Dart `base64Encode` dari `dart:convert` wrap output di 76 chars dengan `\n` (RFC 2045 MIME format). Gemini API `inline_data.data` reject dengan 400 "Base64 decoding failed". Bug ini latent — belum muncul karena 503 blocking sebelum base64 di-parse. Affects: ASR audio + VLM vision image.

### 1.3 Transcript Tidak Persist
`VideoSignals.transcript` in-memory only (`_signals` Map). Setelah app restart, project load dari DB tapi transcript hilang. User harus re-transcribe audio pengganti setiap restart.

### 1.4 ClipPart.speed Tidak Persist
`ProjectMapper._partsToJson` hanya simpan `[start, end]` — speed tidak disimpan. Setelah restart, resequenced clips kehilangan speed adjustment → export salah.

### 1.5 Content Matching Tidak Work Tanpa Transcript
`contentAwareResequence` throw `StateError` jika transcript kosong. Tidak ada fallback ke visual-only matching (VLM frames tanpa audio context).

### 1.6 No Retry untuk Transient Errors
Gemini API 502/503 tidak di-retry. OpenAI/Groq/custom `transcribe` juga tidak retry. Satu transient error = pipeline gagal total.

---

## 2. Sasaran (Scope of Work)

### 2.1 ASR Error Surfacing & Retry (`ai_provider_service.dart`)
- `_transcribeViaGemini`: throw exception pada non-200 (bukan return empty Transcript).
- Retry 502/503 sampai 3x dengan exponential backoff (2s, 4s, 8s).
- Helper `_extractGeminiError(responseBody)` → parse JSON error message.
- Throw pada transcript kosong (bukan return empty).
- **Catatan:** Fix ini sudah di-apply di session sebelumnya (uncommitted). PRD mendokumentasikan + menambah retry untuk provider non-Gemini.

### 2.2 Base64 Newline Fix (`ai_provider_service.dart` + `content_matcher_service.dart`)
- Gemini inline_data (ASR + vision): strip `\n` dari base64Encode output sebelum kirim.
- Pattern: `base64Encode(bytes).replaceAll('\n', '')` atau `base64.encode(bytes)` dari `dart:convert` dengan `Codec` yang tidak wrap.
- Apply ke: `_transcribeViaGemini` (audio), `visionPrompt` Gemini case (image), `content_matcher_service.dart` `describeFrames`.

### 2.3 Transcript Persistensi (Drift schema v3→v4)
- Tabel baru `transcripts`:
  - `project_id` TEXT FK → projects.id (CASCADE)
  - `asset_id` TEXT nullable (audio pengganti yang di-transcribe)
  - `full_text` TEXT
  - `words_json` TEXT (JSON array of `{word, start, end}`)
  - `language` TEXT nullable
  - `provider` TEXT
  - `created_at` INTEGER
- `schemaVersion` bump 3 → 4.
- `MigrationStrategy.onUpgrade`: `if (from < 4) m.createTable(transcriptsTable)`.
- `ProjectRepository`: `saveTranscript(projectId, Transcript)`, `loadTranscript(projectId)`.
- `AppState.transcribeReplacementAudio`: setelah transcribe → persist ke DB.
- `AppState.loadProjects`: setelah load → restore transcript ke `_signals` (buat minimal `VideoSignals` jika null).
- `AppState.addProjectFromUpload`: setelah ASR → persist transcript (jika berhasil).

### 2.4 ClipPart.speed Persistensi (`project_repository.dart`)
- `_partsToJson`: simpan `[start, end, speed]` (speed optional, default 1.0).
- `_partsFromJson`: baca speed dari index 2 jika ada, else 1.0.
- `_partToJson` / `_partFromJson`: sama, simpan speed.
- Backward compatible: data lama `[start, end]` tetap bisa dibaca (speed defaults to 1.0).

### 2.5 Content Matching Visual-Only Fallback (`content_matcher_service.dart` + `app_state.dart`)
- `contentAwareResequence`: jika transcript kosong/null → skip Stage 3 (extractTopics), lanjut ke visual-only matching.
- Visual-only matching: `matchContent` dengan `audioTopics = []` → LLM match berdasarkan visual descriptions saja, urutan berdasarkan relevance/variety (tidak ada audio topic untuk match).
- Atau: jika tidak ada transcript, fallback ke sequential resequencing (S13 tanpa transcript = default clips).
- UI: tampilkan info "Visual-only matching (tanpa transcript)" di progress indicator.

### 2.6 ASR Error Display di Upload Screen (`upload_screen.dart`)
- Setelah `addProjectFromUpload` selesai: cek `state.asrError`. Jika tidak null → tampilkan dialog "Transkripsi Audio Gagal" dengan pesan error + saran (cek API key/provider di Settings).
- Pipeline tetap non-fatal: clip dibuat tanpa transcript.
- **Catatan:** Fix ini sudah di-apply di session sebelumnya (uncommitted).

### 2.7 Audio Chunking untuk File >20MB (`ai_provider_service.dart`)
- Gemini inline_data limit: ~20MB per request (base64 ~26MB).
- Jika audio file >18MB: split jadi chunk masing-masing <18MB via FFmpeg.
- Transcribe tiap chunk → merge transcript (word timestamps di-offset per chunk duration).
- Implementasi: `_transcribeViaGemini` cek file size sebelum base64 encode. Jika >18MB → split → loop transcribe → merge.

---

## 3. Spesifikasi Teknis

### 3.1 Base64 Fix Pattern
```dart
// SEBELUM (bug):
final b64 = base64Encode(bytes);  // wraps at 76 chars with \n

// SESUDAH (fix):
final b64 = base64Encode(bytes).replaceAll('\n', '');
// atau:
final b64 = base64.encode(bytes);  // tidak wrap di Dart? verify.
```

### 3.2 Drift Schema v4 — Tabel transcripts
```dart
@DataClassName('TranscriptRow')
class TranscriptsTable extends Table {
  @override
  String get tableName => 'transcripts';

  TextColumn get projectId => text()
      .named('project_id')
      .references(ProjectsTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get assetId => text().named('asset_id').nullable()();
  TextColumn get fullText => text().named('full_text')();
  TextColumn get wordsJson => text().named('words_json')();
  TextColumn get language => text().nullable()();
  TextColumn get provider => text()();
  IntColumn get createdAt => integer().named('created_at')();

  @override
  Set<Column> get primaryKey => {projectId};
}
```

### 3.3 ClipPart.speed Persistensi
```dart
// SEBELUM (bug):
static String _partsToJson(List<ClipPart> parts) =>
    jsonEncode(parts.map((p) => [p.start, p.end]).toList());

// SESUDAH (fix):
static String _partsToJson(List<ClipPart> parts) =>
    jsonEncode(parts.map((p) => [p.start, p.end, p.speed]).toList());

static List<ClipPart> _partsFromJson(String s) {
  final raw = jsonDecode(s) as List;
  return raw.map((e) {
    final arr = e as List;
    final speed = arr.length > 2 ? (arr[2] as num).toDouble() : 1.0;
    return ClipPart(
      (arr[0] as num).toDouble(),
      (arr[1] as num).toDouble(),
      speed,
    );
  }).toList();
}
```

### 3.4 Visual-Only Matching Fallback
```dart
// app_state.dart — contentAwareResequence
final t = signals.transcript;
List<String> audioTopics = [];

if (t != null && t.words.isNotEmpty) {
  // Stage 3: Extract audio topics
  onProgress?.call('Extracting topics...');
  final cutPoints = _resequencer.detectCutPoints(t.words);
  audioTopics = await matcher.extractTopics(words: t.words, cutPoints: cutPoints);
} else {
  onProgress?.call('Visual-only matching (no transcript)...');
  // Skip topic extraction, proceed with visual descriptions only
}

// Stage 4: Match — matchContent handle empty audioTopics
matchOrder = await matcher.matchContent(
  visualDescriptions: visualDescriptions,
  audioTopics: audioTopics,  // boleh kosong
);
```

### 3.5 Audio Chunking
```dart
// ai_provider_service.dart — _transcribeViaGemini
final fileSize = file.lengthSync();
const maxBytes = 18 * 1024 * 1024;  // 18MB safety margin

if (fileSize > maxBytes) {
  return await _transcribeGeminiChunked(audioFilePath, language, fileSize);
}
// else: existing single-request path

Future<Transcript> _transcribeGeminiChunked(...) async {
  // 1. Probe duration via ffprobe
  // 2. Split into N chunks: each chunk ≈ (duration * maxBytes / fileSize)
  // 3. For each chunk: extract via FFmpeg → base64 → transcribe
  // 4. Offset word timestamps: chunk[i] words += chunkStart
  // 5. Merge all words + fullText
}
```

---

## 4. Rencana Testing

* **Test 15.1** `test/unit/services/asr_error_handling_test.dart`
  * `_transcribeViaGemini` non-200 → throw Exception (bukan return empty).
  * 503 → retry 3x → throw jika masih gagal.
  * `_extractGeminiError` parse JSON error message benar.

* **Test 15.2** `test/unit/services/base64_encoding_test.dart`
  * `base64Encode(bytes).replaceAll('\n', '')` tidak mengandung `\n`.
  * Gemini inline_data dengan clean base64 → tidak 400 "Base64 decoding failed".

* **Test 15.3** `test/unit/data/transcript_persistence_test.dart`
  * Save transcript → load → sama (fullText, words, language, provider).
  * Delete project → transcript ikut terhapus (CASCADE).
  * Load project tanpa transcript → transcript null (tidak crash).

* **Test 15.4** `test/unit/data/clippart_speed_persistence_test.dart`
  * ClipPart dengan speed != 1.0 → save → load → speed tetap.
  * Data lama `[start, end]` (tanpa speed) → load → speed = 1.0 (backward compat).

* **Test 15.5** `test/unit/services/content_matching_visual_only_test.dart`
  * `contentAwareResequence` dengan transcript null → visual-only matching jalan.
  * `contentAwareResequence` dengan transcript kosong → visual-only matching jalan.
  * `matchContent` dengan `audioTopics = []` → return valid matchOrder.

* **Test 15.6** `test/unit/services/asr_chunking_test.dart`
  * Audio >18MB → split → merge → transcript length sama dengan single-request (mock).
  * Word timestamps di-offset dengan benar per chunk.

---

## 5. Kriteria Penerimaan

* Upload video baru → ASR jalan → jika gagal, dialog error muncul dengan pesan jelas.
* Upload audio pengganti → TRANSCRIBE → jika gagal, snackbar error muncul.
* Restart app → transcript masih ada (tidak perlu re-transcribe).
* Restart app → resequenced clips speed tetap (tidak reset ke 1.0).
* MATCH CONTENT tanpa transcript → visual-only matching jalan (tidak throw).
* Gemini 503 → retry 3x → jika masih gagal, error jelas ke user.
* Base64 audio/image bersih dari `\n` → Gemini tidak reject 400.
* Audio >20MB → chunked → transcript lengkap.
* `flutter analyze lib` → 0; `flutter test` hijau.

---

## 6. Risiko & Mitigasi

| Risiko | Dampak | Mitigasi |
|--------|--------|----------|
| Drift schema bump v4 bisa break DB existing | Tinggi | Additive migration (CREATE TABLE baru, tidak ALTER existing). Test dengan DB lama. |
| ClipPart.speed format change break data lama | Sedang | Backward compat: `[start, end]` tetap valid (speed defaults 1.0). |
| Gemini 503 persisten (bukan transient) | Sedang | Retry 3x cukup untuk transient. Jika persisten → error jelas ke user, suggest ganti key/provider. |
| Audio chunking merge tidak akurat | Rendah | Offset berdasar ffprobe duration per chunk. Test dengan audio 25MB. |
| Visual-only matching quality rendah | Rendah | Fallback ke sequential jika matchOrder parse gagal. User bisa transcribe dulu untuk hasil lebih baik. |

---

## 7. Definition of Done

- `flutter analyze lib` → 0.
- `flutter test` hijau (existing + 6 suite baru).
- Smoke test: upload video → ASR → restart → transcript masih ada → MATCH CONTENT → export.
- Smoke test: upload audio pengganti → TRANSCRIBE → restart → transcript replacement masih ada.
- Smoke test: MATCH CONTENT tanpa transcript → visual-only → tidak crash.
- Smoke test: audio >20MB → chunked → transcript lengkap.

---

## 8. Dependency & Posisi Roadmap

- **Dependensi:** S11 (ASR — done), S13 (resequencing — done), S14 (content matching — done).
- **Integrasi:** AiProviderService (ASR+vision), ContentMatcherService (matching), AppState (pipeline), Drift (persist), ProjectRepository (mapper), UploadScreen (error UI), AudioPanel (error UI).
- **Urutan:** setelah S14. Independen dari S07 (UI fidelity) dan Gate G1.
- **Estimasi:** 3–4 hari (base64 fix + Drift v4 + speed persist + visual-only fallback + chunking + retry + test).

---

## 9. Catatan & Out of Scope

- **Whisper provider routing** (prioritize OpenAI/Groq/custom over Gemini untuk word timestamps) — out of scope. PRD ini fix bugs di flow yang ada, tidak redesign provider routing. Gemini tetap primary untuk provider yang aktif.
- **Word-level timestamp estimation improvement** — out of scope. Estimation 2.5 wps tetap dipakai untuk Gemini. Improve di PRD terpisah jika perlu.
- **TTS (voiceover)** — out of scope. Tetap S11 remaining.
- **Multi-frame per shot** (3 frame: awal/tengah/akhir) — out of scope. 1 frame per shot tetap.
- **User manual override match order** — out of scope.
- **Embedding similarity matching** — out of scope. LLM matching tetap.
