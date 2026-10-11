# PRD Sprint 11 — Speech Services (Cloud STT + TTS)

**Dokumen ID:** PRD-SPRINT-11
**Modul Fokus:** ASR (Speech-to-Text) Cloud, TTS (Text-to-Speech) Cloud, Transcript Model, Integrasi Pipeline Analysis & Caption Editor
**Target File:** `lib/services/ai_provider_service.dart`, `lib/services/local_analyzer.dart`, `lib/models/models.dart`, `lib/state/app_state.dart`, `lib/screens/caption_reframe_screen.dart`, `lib/screens/upload_screen.dart`, `lib/widgets/audio_panel.dart`, `test/*`
**Referensi:** `PRD_VISARY_V2.md` (§3.1 ASR, §4.5.4 Caption Word-by-Word), `Visary-PRD.md` (line 71 ASR faster-whisper), `PRD-SPRINT-06` (BYOK/provider), `PRD-SPRINT-10` (audio asset — integrasi TTS), `EXECUTION-ORDER-PRD.md`
**Status:** Draft — siap eksekusi (post-Gate G1)

---

## 1. Latar Belakang & Masalah

Visary punya dua gap terkait speech:

**Gap 1 — ASR (audio→text) stubbed.** PRD V2 §3.1 menetapkan ASR faster-whisper dengan word-level timestamp sebagai bagian inti pipeline analysis multimodal. Pipeline upload punya `JobStage.asr` ('Transkrip audio (ASR)'). TAPI belum diimplementasi — `caption_reframe_screen.dart:21` eksplisit: "Belum ada ASR (backend AI belum tersedia) — kata transkrip diturunkan dari judul clip". Akibatnya:
- Caption editor memakai kata dummy dari judul, bukan transkripsi nyata.
- Hook scoring tidak memakai sinyal kata/kalimat (cuma energi+shot+OCR).
- Prompt-based clip search (semantic) tidak punya transkrip untuk dicari.
- Tidak ada file `.srt` (PRD task 3.3).

**Gap 2 — TTS (text→audio) tidak ada.** Kapabilitas generate audio dari teks (voiceover/narasi) tidak ada di PRD mana pun dan tidak di kode. Use case: user tulis naskah caption → TTS → audio asset → replace audio clip (integrasi S10); dubbing; aksesibilitas.

**Rencana asli PRD** (faster-whisper LOCAL via Python sidecar) tidak feasible saat ini: tidak ada Python sidecar di proyek (Flutter + FFmpeg saja). Bangun sidecar = infrastruktur besar (bundle Python + model, packaging Windows berat).

**Keputusan (2026-10-11):** ASR + TTS via CLOUD provider, meng-extend `AiProviderService` (S06 infra sudah ada: BYOK key storage + connection test + `sendPrompt`). Satu sprint terpadu "Speech Services".

| # | Limitasi saat ini | Lokasi | Dampak |
|---|-------------------|--------|--------|
| 1 | `JobStage.asr` tidak jalan nyata | `app_state.dart` (addProjectFromUpload) | Pipeline analysis tidak produksi transkrip |
| 2 | Caption word-by-word dummy | `caption_reframe_screen.dart:21-27` | Caption tidak refleksikan ucapan nyata |
| 3 | Tidak ada model Transcript/WordToken | `models.dart` | Word-level timestamp tidak terwakili |
| 4 | `AiProviderService` cuma `sendPrompt` (text-gen) | `ai_provider_service.dart:235` | Tidak ada endpoint speech (STT/TTS) |
| 5 | Hook scoring tanpa sinyal kata | `local_analyzer.dart` | Skor kurang akurat (cuma energi+shot) |
| 6 | TTS tidak ada | — | Voiceover/narasi tidak bisa di-generate |

---

## 2. Sasaran (Scope of Work)

### 2.1 Extend AiProviderService dengan Speech
- `transcribe({audioFilePath, language?}) → TranscriptResult` — ASR cloud.
- `synthesize({text, voice?, model?}) → String audioFilePath` — TTS cloud, output disimpan ke workspace.
- Routing mengikuti pola S06: BYOK key aktif → cloud; tanpa key → fallback (ASR: transkrip kosong/null, pipeline tetap jalan; TTS: throw error jelas "butuh API key").

### 2.2 ASR ke Pipeline Analysis (tutup gap §3.1)
- `JobStage.asr` benar-benar berjalan: ekstrak audio dari video sumber → `transcribe` → `Transcript` (word-level timestamp).
- `Transcript` tersimpan di `VideoSignals` (atau field project), di-cache per project.
- Caption editor (`caption_reframe_screen`) memakai word token nyata (bukan dummy judul).
- Hook scoring diperkaya sinyal kata (kepadatan kata, keyword, batas kalimat).
- Generator `.srt` dari Transcript (PRD task 3.3).

### 2.3 TTS → Audio Asset (integrasi S10)
- UI: tombol "Generate Voiceover" — input teks (naskah/caption) → `synthesize` → file audio → `AssetItem(type: audio)` → langsung bisa dipakai S10 (replace audio clip).
- Pilihan voice (OpenAI: alloy/echo/fable/onyx/nova/shimmer).
- Output format mp3.

### 2.4 Transcript Model & Word Timestamp
```dart
class WordToken {
  final String word;
  final double start;   // detik
  final double end;     // detik
  const WordToken({required this.word, required this.start, required this.end});
}

class Transcript {
  final String fullText;
  final List<WordToken> words;     // word-level timestamp (kosong bila provider tak dukung)
  final String? language;          // auto-detect atau ditentukan
  final AiProviderType provider;   // sumber transkripsi
  const Transcript({required this.fullText, required this.words, this.language, required this.provider});
}
```

---

## 3. Spesifikasi Teknis

### 3.1 `lib/services/ai_provider_service.dart` — transcribe + synthesize

**ASR endpoint per provider:**

| Provider | Endpoint | Model | Word timestamp? |
|----------|----------|-------|-----------------|
| OpenAI | `POST https://api.openai.com/v1/audio/transcriptions` (multipart) | `whisper-1` | ✅ `response_format=verbose_json` + `timestamp_granularities[]=word` |
| Groq | `POST https://api.groq.com/openai/v1/audio/transcriptions` (multipart) | `whisper-large-v3` | ✅ verbose_json (word) |
| Gemini | `POST .../v1beta/models/gemini-2.0-flash:generateContent` (inline audio base64) | gemini-2.0-flash | ❌ text/segment only (caption word-by-word degraded) |
| Server | gateway Visary | — | TBD |

```dart
Future<Transcript> transcribe({
  required String audioFilePath,
  String? language,        // 'id'/'en'/null=auto
}) async {
  final active = await isByokActive();
  if (!active) {
    // Fallback: tanpa key, transkrip kosong — pipeline tetap jalan (degraded).
    return Transcript(fullText: '', words: const [], language: null,
        provider: AiProviderType.server);
  }
  final provider = await storage.getActiveProvider();
  switch (provider) {
    case AiProviderType.openai:
    case AiProviderType.groq:
      // multipart: file=audio, model, response_format=verbose_json,
      // timestamp_granularities[]=word, language?
      // parse: data['text'], data['words']=[{word,start,end},...]
      ...
    case AiProviderType.gemini:
      // inline audio (base64) di generateContent parts; parse text dari candidates.
      // words kosong (Gemini tidak berikan word timestamp).
      ...
    case AiProviderType.server:
      ...
  }
}
```

Catatan: audio untuk OpenAI/Groq harus file (<25MB) — video sumber perlu di-extract dulu ke audio segment via `VideoService.extractAudio` (S10) sebelum dikirim. Untuk video panjang, chunk per ~5 menit atau pakai Gemini Files API.

**TTS endpoint per provider:**

| Provider | Endpoint | Model | Catatan |
|----------|----------|-------|---------|
| OpenAI | `POST https://api.openai.com/v1/audio/speech` (JSON) | `tts-1` / `tts-1-hd` | voice: alloy/echo/fable/onyx/nova/shimmer; response audio/mpeg |
| Groq | — | — | ❌ tidak punya TTS |
| Gemini | — | — | ❌ tidak punya TTS standar (Google Cloud TTS = provider terpisah, out of scope) |

```dart
Future<String> synthesize({
  required String text,
  String voice = 'nova',        // OpenAI voice
  String model = 'tts-1',       // tts-1 (cepat) / tts-1-hd (kualitas)
  required String outputPath,   // workspace .mp3
}) async {
  final active = await isByokActive();
  if (!active) throw StateError('TTS butuh API key (BYOK). Aktifkan di Settings.');
  final provider = await storage.getActiveProvider();
  // Hanya OpenAI yang dukung TTS di provider set saat ini.
  if (provider != AiProviderType.openai) {
    throw UnsupportedError('TTS hanya didukung via OpenAI. Provider aktif: ${provider.displayName}');
  }
  final key = (await storage.getOpenAiKey()) ?? '';
  final res = await _client.post(
    Uri.parse('https://api.openai.com/v1/audio/speech'),
    headers: {'Authorization': 'Bearer $key', 'Content-Type': 'application/json'},
    body: jsonEncode({'model': model, 'input': text, 'voice': voice, 'response_format': 'mp3'}),
  );
  if (res.statusCode == 200) {
    await File(outputPath).writeAsBytes(res.bodyBytes);
    return outputPath;
  }
  throw Exception('OpenAI TTS Error ${res.statusCode}: ${res.body}');
}
```

**Konstraint provider penting:**
- **TTS narrow ke OpenAI** — Groq & Gemini tidak punya TTS. UI harus jelas: TTS butuh OpenAI key aktif.
- **ASR fleksibel** — OpenAI Whisper + Groq whisper-large-v3 (cepat/murah). Gemini audio multimodal (text only, no word timestamp → caption word-by-word terdegradasi).

### 3.2 `lib/services/local_analyzer.dart` — integrasi ASR
- `scan(filePath, probe)` tambah tahap ASR: extract audio → `aiService.transcribe` → `Transcript`.
- `VideoSignals` tambah field `Transcript? transcript`.
- Routing: bila BYOK aktif → cloud ASR; bila tidak → `transcript = null` (fallback lokal tetap produksi shots/energy/OCR).
- Hook scoring diperkaya: kepadatan kata per detik, keyword match, batas kalimat (dari word timestamp).

### 3.3 `lib/screens/caption_reframe_screen.dart` — caption nyata
- Ganti `_words` (dummy dari judul) → `signals.transcript?.words ?? [clipTitle split]` (fallback).
- Klik kata untuk koreksi (PRD §4.5.4) — edit word token, persist.
- Caption playback menyala kata per kata sesuai playhead ↔ word.start/end.

### 3.4 `lib/state/app_state.dart` — TTS workflow
```dart
Future<AssetItem> generateVoiceover(String projectId, {required String text, String voice = 'nova'}) async {
  final dir = await _workDir(projectId);
  final audioDir = Directory('${dir.path}/audio');
  if (!await audioDir.exists()) await audioDir.create(recursive: true);
  final id = 'a_tts${DateTime.now().millisecondsSinceEpoch}';
  final outPath = '${audioDir.path}/$id.mp3';
  await aiService.providerService.synthesize(text: text, voice: voice, outputPath: outPath);
  final probe = await VideoService.probe(outPath);
  final asset = AssetItem(
    id: id, type: AssetType.audio, title: 'Voiceover ${text.length}ch',
    sourceFile: outPath, start: 0, end: probe.durationSec,
    durationSec: probe.durationSec, audioFormat: 'mp3',
  );
  addAsset(projectId, asset);
  return asset;
}
```

### 3.5 `lib/widgets/audio_panel.dart` — UI TTS
- Tombol "GENERATE VOICEOVER" → dialog input teks + pilih voice → `generateVoiceover` → auto-select as replacement (integrasi S10 `setActiveAudioAsset`).
- Indikator: TTS butuh OpenAI key (disable + hint bila provider bukan OpenAI / BYOK off).

### 3.6 Generator `.srt` (PRD task 3.3)
- Dari `Transcript.words` (atau segment bila no word ts) → format SRT (index, `HH:MM:SS,mmm --> HH:MM:SS,mmm`, text).
- `VideoService.exportSrt(transcript, outputPath)` atau helper di utils.

---

## 4. Rencana Testing

* **Test 11.1** `test/unit/services/transcribe_test.dart`
  * Mock `http.Client` → simulasi response verbose_json OpenAI (word timestamps) → parse `Transcript` benar (fullText + words dengan start/end).
  * Mock Groq response → parse benar.
  * Mock Gemini response (text only) → `words` kosong, `fullText` terisi.
  * Fallback: BYOK off → `Transcript` kosong (tidak throw).
* **Test 11.2** `test/unit/services/synthesize_test.dart`
  * Mock `http.Client` → response audio bytes → tulis file .mp3, path benar.
  * Provider bukan OpenAI → `UnsupportedError`.
  * BYOK off → `StateError` (pesan jelas).
* **Test 11.3** `test/unit/models/transcript_test.dart`
  * `Transcript` round-trip; word token start/end; `.srt` generator format benar (index, timecode, text).
* **Test 11.4** `test/integration/asr_pipeline_test.dart`
  * `LocalAnalyzer.scan` dengan mock `AiProviderService.transcribe` → `VideoSignals.transcript` terisi; hook scoring pakai sinyal kata.
  * Fallback: BYOK off → transcript null, pipeline tetap produksi shots/energy.
* **Test 11.5** `test/widget/voiceover_panel_test.dart`
  * Tombol "GENERATE VOICEOVER" render; input teks + voice → panggil `generateVoiceover` (mock); aset audio muncul.
  * Provider bukan OpenAI → tombol disable + hint.

---

## 5. Kriteria Penerimaan (Acceptance Criteria)

* Upload video → `JobStage.asr` jalan nyata → `Transcript` (word-level timestamp untuk OpenAI/Groq) terisi & ter-cache per project.
* Caption editor (`caption_reframe_screen`) menampilkan kata transkripsi nyata, menyala per kata sesuai playhead.
* Tanpa API key (BYOK off): pipeline analysis tetap jalan (shots/energy/OCR), transcript null, caption fallback ke teks OCR/judul — tidak crash.
* TTS: input teks + pilih voice → generate .mp3 → jadi `AssetItem(type: audio)` → bisa langsung replace audio clip (S10).
* TTS hanya jalan bila provider OpenAI + BYOK aktif; otherwise UI disable + hint jelas.
* Generator `.srt` dari Transcript menghasilkan file SRT valid (format index + timecode + text).
* `flutter analyze lib` → 0 issue; `flutter test` hijau (existing + 5 suite baru).
* Tidak ada nilai dummy/hardcoded baru di `lib/`.

---

## 6. Risiko & Mitigasi

| Risiko | Dampak | Mitigasi |
|--------|--------|----------|
| Biaya API (Whisper per menit, TTS per karakter) | Sedang | Estimasi biaya tampil sebelum generate; batas input teks TTS; cache transcript per project |
| Audio >25MB (limit OpenAI/Groq upload) | Sedang | Extract per-segment/chunk ~5 menit via `extractAudio`; atau pakai Gemini Files API untuk besar |
| Gemini ASR tidak beri word timestamp | Sedang | Caption word-by-word terdegradasi (segment-level); UI tunjukkan keterbatasan; rekomendasi OpenAI/Groq untuk caption presisi |
| TTS narrow ke OpenAI | Rendah | UI jelas; future: tambah Google Cloud TTS sebagai provider ke-4 |
| Latency ASR video panjang | Sedang | Async dengan progress; bila >60s, chunk paralel |
| Transkrip bahasa Indonesia/slang akurasi | Sedang | Pilih model (Groq whisper-large-v3 lebih baik multi-bahasa); editor koreksi kata (§4.5.4) |
| Cloud ASR pecah prinsip local-first MVP (§7.5) | Sedang | Fallback lokal tetap jalan tanpa key; ASR = enhancement layer (bukan blocker MVP). Update §7.5 note |
| Rate limit / quota | Rendah | Routing S06 retry + fallback; pesan jelas 429 |

---

## 7. Definition of Done

- `flutter analyze lib` → 0 error/warning/info.
- `flutter test` hijau (existing + 5 suite baru).
- Smoke test Linux: upload video → transkrip muncul di caption editor (OpenAI/Groq key) → generate voiceover dari teks → replace audio → export. Tanpa key: pipeline jalan degraded.
- `.srt` generate valid (diverifikasi player eksternal).
- Tidak ada hardcoded/dummy baru.
- Routing S06: BYOK → cloud; tanpa key → fallback lokal. ASR/TTS tidak crash tanpa key (ASR degraded, TTS error jelas).

---

## 8. Dependency & Posisi Roadmap

- **Dependensi:** S06 (BYOK/provider infra) — sudah parsial (`AiProviderService`: key storage + connection test + `sendPrompt`). S11 extend dengan `transcribe`/`synthesize`. Bila routing S06 belum lengkap untuk analysis, S11 serap bagian speech.
- **Integrasi:** S10 (audio asset) — TTS output jadi aset audio → replace. S03 (analyzer) — `VideoSignals.transcript` field baru.
- **Tidak dependensi:** S05 (AI B-roll) — independen, bisa paralel.
- **Urutan:** setelah Gate G1 (MVP lokal tervalidasi). S11 mengubah core pipeline analysis (ASR) → validasi Windows wajib.
- **Estimasi:** 4–6 hari kerja (provider speech methods + Transcript model + pipeline integration + caption rewrite + TTS UI + .srt + test).

---

## 9. Catatan & Out of Scope

- **Local faster-whisper (Python sidecar)** — out of scope. Rencana asli PRD §3.1, tapi tidak feasible tanpa sidecar. Bila future ingin offline ASR: bangun sidecar terpisah (sprint infra), lalu tambah sebagai provider ke-4 (`AiProviderType.localWhisper`).
- **Google Cloud TTS** sebagai provider TTS ke-2 — out of scope (bila butuh alternatif selain OpenAI).
- **Dubbing multi-bahasa** (ASR → translate → TTS bahasa lain) — out of scope, future sprint.
- **Voice cloning** — out of scope.
- **Speaker diarization** (siapa bicara kapan) — out of scope; future bila perlu (Whisper API tidak native dukung, butuh model terpisah).
- **Update PRD V2 §3.1 & §7.5** — §3.1 tetap berlaku (ASR) tapi approach berubah dari local faster-whisper → cloud provider. §7.5 (mode dasar lokal) perlu note: ASR jadi enhancement layer dengan fallback lokal (bukan blocker).
