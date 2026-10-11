# PRD Sprint 11 — Speech Services (ASR / Cloud STT) — Phase 1

**Dokumen ID:** PRD-SPRINT-11
**Modul Fokus:** Provider Custom OpenAI-Compatible, ASR (Speech-to-Text) Cloud, Transcript Model, Integrasi Pipeline Analysis & Caption Editor
**Target File:** `lib/services/ai_provider_service.dart`, `lib/services/local_analyzer.dart`, `lib/models/models.dart`, `lib/state/app_state.dart`, `lib/screens/caption_reframe_screen.dart`, `lib/screens/settings_screen.dart`, `test/*`
**Referensi:** `PRD_VISARY_V2.md` (§3.1 ASR, §4.5.4 Caption Word-by-Word), `Visary-PRD.md` (line 71 ASR faster-whisper), `PRD-SPRINT-06` (BYOK/provider), `EXECUTION-ORDER-PRD.md`
**Status:** Draft — Phase 1 (ASR) siap eksekusi; TTS deferred (§9, awaiting approval)

---

## 1. Latar Belakang & Masalah

PRD V2 §3.1 menetapkan ASR faster-whisper dengan word-level timestamp sebagai bagian inti pipeline analysis multimodal. Pipeline upload punya `JobStage.asr` ('Transkrip audio (ASR)'). TAPI belum diimplementasi — `caption_reframe_screen.dart:21` eksplisit: "Belum ada ASR (backend AI belum tersedia) — kata transkrip diturunkan dari judul clip". Akibatnya:
- Caption editor memakai kata dummy dari judul, bukan transkripsi nyata.
- Hook scoring tidak memakai sinyal kata/kalimat (cuma energi+shot+OCR).
- Prompt-based clip search (semantic) tidak punya transkrip untuk dicari.
- Tidak ada file `.srt` (PRD task 3.3).

Rencana asli PRD (faster-whisper LOCAL via Python sidecar) tidak feasible: tidak ada Python sidecar di proyek (Flutter + FFmpeg saja). Bangun sidecar = infrastruktur besar.

**Keputusan (2026-10-11):** ASR via CLOUD provider, memakai key **Tokonomix** yang sudah dimiliki user. Tokonomix (tokonomix.ai) = gateway OpenAI-compatible dengan endpoint `/api/v1/audio/transcriptions` (model whisper-1). TTS deferred — Tokonomix tidak punya endpoint TTS, dan user belum punya key OpenAI/TokenMix/Mixen; TTS menunggu persetujuan lebih lanjut (§9).

| # | Limitasi saat ini | Lokasi | Dampak |
|---|-------------------|--------|--------|
| 1 | `JobStage.asr` tidak jalan nyata | `app_state.dart` (addProjectFromUpload) | Pipeline analysis tidak produksi transkrip |
| 2 | Caption word-by-word dummy | `caption_reframe_screen.dart:21-27` | Caption tidak refleksikan ucapan nyata |
| 3 | Tidak ada model Transcript/WordToken | `models.dart` | Word-level timestamp tidak terwakili |
| 4 | `AiProviderService` cuma `sendPrompt` + 3 provider hardcode (gemini/openai/groq) | `ai_provider_service.dart` | Tidak ada endpoint speech; tidak support Tokonomix (base URL konfigurabel) |
| 5 | Hook scoring tanpa sinyal kata | `local_analyzer.dart` | Skor kurang akurat (cuma energi+shot) |

---

## 2. Sasaran (Scope of Work) — Phase 1: ASR

### 2.1 Provider Custom OpenAI-Compatible
- Tambah `AiProviderType.custom('OpenAI-Compatible (custom base URL)')`.
- `SecureKeyStorage`: tambah `keyCustomApi` + `keyCustomBaseUrl`.
- Settings UI: pilih provider "custom" → input base URL + API key.
- `sendPrompt` + `transcribe` untuk custom: POST ke `{baseUrl}/chat/completions` dan `{baseUrl}/audio/transcriptions` dengan Bearer key.
- Sekalian bikin Visary support gateway OpenAI-compatible apapun (Tokonomix sekarang; TokenMix/Mixen/OpenRouter future) — bukan cuma 3 fixed.

### 2.2 ASR (transcribe)
- `AiProviderService.transcribe({audioFilePath, language?}) → Transcript`.
- Primary: Tokonomix — base URL `https://tokonomix.ai/api/v1`, key `tok_live_...`, endpoint `/audio/transcriptions`, model `whisper-1`.
- Juga jalan untuk OpenAI/Groq via custom provider (base URL masing-masing).
- Routing pola S06: BYOK/custom aktif → cloud ASR; tanpa key → fallback (transcript null, pipeline tetap jalan, degraded).

### 2.3 ASR ke Pipeline Analysis (tutup gap §3.1)
- `JobStage.asr` benar-benar berjalan: ekstrak audio dari video sumber → `transcribe` → `Transcript` (word-level timestamp).
- `Transcript` tersimpan di `VideoSignals` (field baru), di-cache per project.
- Caption editor (`caption_reframe_screen`) memakai word token nyata (bukan dummy judul).
- Hook scoring diperkaya sinyal kata (kepadatan kata, keyword, batas kalimat dari word timestamp).

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

### 2.5 Generator `.srt` (PRD task 3.3)
- Dari `Transcript.words` (atau segment bila no word ts) → format SRT (index, `HH:MM:SS,mmm --> HH:MM:SS,mmm`, text).

---

## 3. Spesifikasi Teknis

### 3.1 `lib/services/ai_provider_service.dart` — provider custom + transcribe

**Tambah enum + storage:**
```dart
enum AiProviderType {
  server('Server Visary (Default Kuota)'),
  gemini('Google Gemini API'),
  openai('OpenAI API'),
  groq('Groq Cloud API'),
  custom('OpenAI-Compatible (custom base URL)');  // BARU
  const AiProviderType(this.displayName);
  final String displayName;
}
// SecureKeyStorage:
static const keyCustomApi = 'byok_custom_api_key';
static const keyCustomBaseUrl = 'byok_custom_base_url';
Future<void> saveCustomKey(String key) => write(keyCustomApi, key);
Future<String?> getCustomKey() => read(keyCustomApi);
Future<void> saveCustomBaseUrl(String url) => write(keyCustomBaseUrl, url);
Future<String?> getCustomBaseUrl() => read(keyCustomBaseUrl);
```

**`sendPrompt` untuk custom:** POST `{baseUrl}/chat/completions`, Bearer key, model `gpt-4o-mini` (atau slug dari `GET {baseUrl}/models`). Bonus: B-roll S05 jalan via Tokonomix.

**ASR endpoint per provider:**

| Provider | Base URL | Endpoint | Model | Word timestamp? |
|----------|----------|----------|-------|-----------------|
| Custom (Tokonomix) | `https://tokonomix.ai/api/v1` | `POST /audio/transcriptions` | `whisper-1` | ✅ bila `verbose_json` + `timestamp_granularities[]=word` dukung (verifikasi saat eksekusi) |
| OpenAI (via custom) | `https://api.openai.com/v1` | `POST /audio/transcriptions` | `whisper-1` | ✅ |
| Groq (via custom) | `https://api.groq.com/openai/v1` | `POST /audio/transcriptions` | `whisper-large-v3` | ✅ |
| Gemini | (existing) | inline audio base64 di generateContent | gemini-2.0-flash | ❌ text/segment only |
| Server | gateway Visary | — | — | TBD |

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
  // custom/openai/groq: multipart POST {baseUrl}/audio/transcriptions
  //   file=audio, model (whisper-1 / whisper-large-v3), response_format=verbose_json,
  //   timestamp_granularities[]=word, language?
  //   parse: data['text'], data['words']=[{word,start,end},...]
  // gemini: inline audio (base64) di generateContent; words kosong.
}
```

Catatan: audio untuk transcribe harus file (<25MB). Video sumber di-extract dulu ke audio via `VideoService.extractAudio` (S10) sebelum dikirim. Video panjang → chunk per ~5 menit.

**Yang diverifikasi saat eksekusi:** apakah relay Tokonomix dukung `response_format=verbose_json` + `timestamp_granularities[]=word` (word-level timestamp caption). Dokumen dasar bilang "returns text string". Karena OpenAI-compatible, kemungkinan dukung; kalau strip → caption word-by-word terdegradasi (segment/text only).

### 3.2 `lib/services/local_analyzer.dart` — integrasi ASR
- `scan(filePath, probe)` tambah tahap ASR: extract audio → `aiService.transcribe` → `Transcript`.
- `VideoSignals` tambah field `Transcript? transcript`.
- Routing: BYOK/custom aktif → cloud ASR; bila tidak → `transcript = null` (fallback lokal tetap produksi shots/energy/OCR).
- Hook scoring diperkaya: kepadatan kata per detik, keyword match, batas kalimat (dari word timestamp).

### 3.3 `lib/screens/caption_reframe_screen.dart` — caption nyata
- Ganti `_words` (dummy dari judul) → `signals.transcript?.words ?? [clipTitle split]` (fallback).
- Klik kata untuk koreksi (PRD §4.5.4) — edit word token, persist.
- Caption playback menyala kata per kata sesuai playhead ↔ word.start/end.

### 3.4 `lib/screens/settings_screen.dart` — UI provider custom
- Pilih provider "OpenAI-Compatible (custom)" → input Base URL + API Key.
- Prefill saran: Tokonomix (`https://tokonomix.ai/api/v1`).
- Test connection: `GET {baseUrl}/models` (OpenAI-compatible).

### 3.5 Generator `.srt`
- Helper `Transcript.toSrt()` atau `VideoService.exportSrt(transcript, outputPath)` → format SRT (index, timecode, text).

---

## 4. Rencana Testing

* **Test 11.1** `test/unit/services/transcribe_test.dart`
  * Mock `http.Client` → simulasi response verbose_json (word timestamps) → parse `Transcript` benar (fullText + words dengan start/end).
  * Mock response text-only → `words` kosong, `fullText` terisi.
  * Fallback: BYOK off → `Transcript` kosong (tidak throw).
  * Custom provider: base URL dari storage → endpoint benar.
* **Test 11.2** `test/unit/models/transcript_test.dart`
  * `Transcript` round-trip; word token start/end; `.srt` generator format benar (index, timecode, text).
* **Test 11.3** `test/unit/services/custom_provider_test.dart`
  * `AiProviderType.custom` routing: `sendPrompt` + `transcribe` POST ke base URL dari storage.
  * `SecureKeyStorage` save/get custom key + base URL.
* **Test 11.4** `test/integration/asr_pipeline_test.dart`
  * `LocalAnalyzer.scan` dengan mock `AiProviderService.transcribe` → `VideoSignals.transcript` terisi; hook scoring pakai sinyal kata.
  * Fallback: BYOK off → transcript null, pipeline tetap produksi shots/energy.
* **Test 11.5** `test/widget/caption_transcript_test.dart`
  * Caption editor tampilkan word token nyata dari transcript (bukan dummy judul).
  * Fallback: transcript null → caption pakai clipTitle split.

---

## 5. Kriteria Penerimaan (Acceptance Criteria) — Phase 1

* Settings: pilih provider "custom" → input base URL Tokonomix + key → test connection sukses (`GET {baseUrl}/models`).
* Upload video → `JobStage.asr` jalan nyata → `Transcript` (word-level timestamp bila provider dukung) terisi & ter-cache per project.
* Caption editor menampilkan kata transkripsi nyata, menyala per kata sesuai playhead.
* Tanpa API key (BYOK off): pipeline analysis tetap jalan (shots/energy/OCR), transcript null, caption fallback ke teks OCR/judul — tidak crash.
* Generator `.srt` dari Transcript menghasilkan file SRT valid.
* `sendPrompt` (B-roll S05) juga jalan via custom provider (bonus — Tokonomix untuk LLM).
* `flutter analyze lib` → 0 issue; `flutter test` hijau (existing + 5 suite baru).
* Tidak ada nilai dummy/hardcoded baru di `lib/`.

---

## 6. Risiko & Mitigasi

| Risiko | Dampak | Mitigasi |
|--------|--------|----------|
| Tokonomix relay tidak dukung `verbose_json` + word timestamp | Sedang | Caption word-by-word terdegradasi (segment/text); fallback segment-level; UI tunjukkan keterbatasan; verifikasi saat eksekusi, dokumentasikan |
| Biaya API (Whisper per menit audio via Tokonomix) | Sedang | Cache transcript per project (sekali transcribe, reuse); estimasi biaya tampil sebelum transcribe |
| Audio >25MB (limit upload) | Sedang | Extract per-segment/chunk ~5 menit via `extractAudio` (S10) |
| Cloud ASR pecah prinsip local-first MVP (§7.5) | Sedang | Fallback lokal tetap jalan tanpa key; ASR = enhancement layer (bukan blocker). Update §7.5 note |
| Transkrip bahasa Indonesia/slang akurasi | Sedang | whisper-1 / whisper-large-v3 multi-bahasa; editor koreksi kata (§4.5.4) |
| Latency ASR video panjang | Sedang | Async dengan progress; bila >60s, chunk paralel |
| Rate limit / quota Tokonomix | Rendah | Routing S06 retry + fallback; pesan jelas 429 |

---

## 7. Definition of Done — Phase 1

- `flutter analyze lib` → 0 error/warning/info.
- `flutter test` hijau (existing + 5 suite baru).
- Smoke test Linux: set provider custom + Tokonomix key → upload video → transkrip muncul di caption editor (word-level bila dukung) → generate `.srt` valid. Tanpa key: pipeline jalan degraded.
- Tidak ada hardcoded/dummy baru.
- Provider custom OpenAI-compatible terdokumentasi + ter-test; Tokonomix bisa dipilih via Settings.

---

## 8. Dependency & Posisi Roadmap

- **Dependensi:** S06 (BYOK/provider infra) — sudah parsial. S11 extend dengan: (a) provider `custom` OpenAI-compatible + base URL, (b) `transcribe`. Bila routing S06 belum lengkap untuk analysis, S11 serap bagian ASR.
- **Integrasi:** S03 (analyzer) — `VideoSignals.transcript` field baru. S10 (audio) — `extractAudio` untuk siapkan audio sebelum transcribe.
- **Tidak dependensi:** S05 (B-roll) — independen, tapi bonus: `sendPrompt` custom ikut bikin S05 jalan via Tokonomix.
- **Urutan:** setelah Gate G1 (MVP lokal tervalidasi). S11 mengubah core pipeline analysis (ASR) → validasi Windows wajib.
- **Estimasi Phase 1 (ASR only):** 3–4 hari kerja (provider custom + transcribe + Transcript model + pipeline integration + caption rewrite + .srt + test). Lebih kecil dari estimasi awal (4–6 hari) karena TTS di-defer.

---

## 9. TTS — Deferred (Phase 2, awaiting approval)

TTS (text→audio, `synthesize`) **ditunda** menunggu persetujuan lebih lanjut. Alasan:
- Tokonomix (satu-satunya key yang user punya) tidak punya endpoint TTS (`/audio/speech`).
- TTS butuh OpenAI key, atau ganti gateway ke TokenMix (tokenmix.ai) / Mixen (api.mixen.ai) yang punya TTS.
- User belum punya key tersebut.

**Saat disetujui, scope TTS (Phase 2):**
- `AiProviderService.synthesize({text, voice, model, outputPath}) → mp3`.
- Endpoint: OpenAI `POST /audio/speech` (tts-1/tts-1-hd) via custom provider; atau TokenMix/Mixen bila key tersedia.
- `AppState.generateVoiceover(projectId, text, voice)` → `AssetItem(type: audio)` → integrasi S10 (replace audio clip).
- UI: tombol "GENERATE VOICEOVER" di AudioPanel → input teks + pilih voice.
- Testing: synthesize mock, voiceover widget.

Catatan: arsitektur provider custom (base URL) yang dibangun di Phase 1 sudah siap untuk TTS — saat disetujui, tinggal tambah `synthesize` + UI, tanpa rework provider.

---

## 10. Catatan & Out of Scope

- **Local faster-whisper (Python sidecar)** — out of scope. Rencana asli PRD §3.1, tidak feasible tanpa sidecar. Future: bangun sidecar terpisah, tambah sebagai provider (`AiProviderType.localWhisper`).
- **Antigravity Pro** — out of scope untuk speech. Antigravity = gateway chat/vision LLM only (Claude/Gemini/GPT-OSS), tidak ada endpoint ASR/TTS. Mungkin berguna untuk S05 (B-roll LLM) bila butuh quota.
- **Speaker diarization** — out of scope; future bila perlu.
- **Update PRD V2 §3.1 & §7.5** — §3.1 tetap berlaku (ASR) tapi approach berubah dari local faster-whisper → cloud provider (Tokonomix/custom). §7.5 (mode dasar lokal) perlu note: ASR jadi enhancement layer dengan fallback lokal (bukan blocker).
