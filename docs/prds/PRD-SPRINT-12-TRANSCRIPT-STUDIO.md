# PRD Sprint 12 — Transcript Studio (Standalone Transcript Management)

**Dokumen ID:** PRD-SPRINT-12
**Modul Fokus:** Dedicated Transcript Screen, View/Edit/Export, Audio Chunking untuk Video Panjang, Search + Jump-to-Timecode, Persistensi Transcript
**Target File:** `lib/screens/transcript_screen.dart` (baru), `lib/services/ai_provider_service.dart` (chunking), `lib/state/app_state.dart`, `lib/services/video_service.dart`, `lib/screens/clip_editor_screen.dart`, `lib/main.dart`, `lib/models/models.dart`, `test/*`
**Referensi:** `PRD-SPRINT-11` (ASR engine — done), `PRD_VISARY_V2.md` (§4.5.4 Caption Word-by-Word), `EXECUTION-ORDER-PRD.md`
**Status:** Draft — siap eksekusi (depends on S11, sudah done)

---

## 1. Latar Belakang & Masalah

S11 mengimplement ASR engine: `transcribe` → `Transcript` (word-level) tersimpan di `VideoSignals.transcript`. Tapi UX transcript-nya **tercampur** dengan Caption & Reframe — kata transcript ditampilkan sebagai caption chips di screen yang sama dengan styling caption. Concern-nya berbeda:

- **Transcript** = manajemen teks: lihat full transkripsi, koreksi kata ASR, export, search, jump ke momen.
- **Caption & Reframe** = styling visual caption di video (preset, posisi, reframe).

Saat ini keduanya digabung. Selain itu ada gap:

| # | Limitasi | Dampak |
|---|----------|--------|
| 1 | Transcript tidak punya screen sendiri | User tidak bisa lihat/kelola full transkripsi terpisah dari caption styling |
| 2 | Audio > 25MB (video > ~18 menit) → ASR gagal (400 file too large) | Video panjang tidak dapat transcript sama sekali |
| 3 | Transcript tidak persist (hanya di memori `VideoSignals`) | Restart app → transcript hilang (harus re-upload/re-transcribe) |
| 4 | Tidak bisa edit/koreksi kata ASR | Kesalahan transkripsi (slang/istilah) tidak bisa diperbaiki |
| 5 | Export hanya `.srt` (via `toSrt` model), tidak ada UI export | User tidak bisa download transcript |
| 6 | Tidak ada search transcript | Susah cari momen tertentu di video panjang |
| 7 | Tidak bisa pilih bahasa (force zh/id/en) | Auto-detect bisa salah untuk audio campur/ambigu |

**Keputusan (2026-10-11):** Pisahkan transcript jadi fitur standalone — S12 Transcript Studio. Caption & Reframe jadi consumer (baca transcript), management ada di S12.

---

## 2. Sasaran (Scope of Work)

### 2.1 Dedicated Transcript Screen
- Route baru `/transcript` (argument: projectId), diakses dari editor (tombol "TRANSCRIPT" di top bar).
- `TranscriptScreen`: tampil full transcript + word tokens dengan timecode, scrollable.

### 2.2 Transcript Persistence
- Simpan `Transcript` (JSON: fullText + words + language + provider) ke workspace `{projectId}/transcript.json`.
- Load saat screen dibuka. Save saat edit.
- AppState: `getTranscript(projectId)` (load from file/cache), `saveTranscript(projectId, transcript)`.
- Restart app → transcript tetap ada (load dari file).

### 2.3 Transcript Editing (PRD §4.5.4)
- Klik kata → edit teks (dialog/inline) → persist ke transcript.words.
- Tambah/hapus kata (split/merge segment opsional — minimal: edit teks kata).

### 2.4 Export 3 Format
- `.srt` (via `Transcript.toSrt()` — sudah ada).
- `.txt` (fullText plain).
- `.vtt` (WEBVTT header + timecode pakai `.` bukan `,`).
- UI: tombol export per format → file picker folder → simpan.

### 2.5 Audio Chunking untuk Video Panjang (>25MB)
- ASR pipeline: bila audio extract > 25MB (atau durasi > threshold ~18 menit), **split per ~5 menit** → transcribe per chunk → **merge** word timestamps dengan offset (chunkStart + word.start).
- Hasil: satu `Transcript` covering full video (tidak peduli panjang).
- Pindah dari S11 remaining (§6) ke S12.

### 2.6 Search + Jump-to-Timecode
- Search bar: cari kata/frase di transcript → highlight + filter hasil.
- Klik kata/segment → **jump playhead editor** ke timecode itu (navigate back to editor + seek).

### 2.7 Language Selection
- Dropdown bahasa: auto / `id` / `en` / `zh` (Mandarin) / `ja` / dll.
- Tombol "Re-transcribe" → re-run ASR dengan `language` param → update transcript.

---

## 3. Spesifikasi Teknis

### 3.1 `lib/screens/transcript_screen.dart` (baru)
- StatefulWidget, `required this.projectId`.
- Load transcript via `state.getTranscript(projectId)`.
- Layout:
  - Top bar: BACK + judul + language dropdown + re-transcribe button.
  - Search bar (TextField).
  - Body: scrollable list word-chips (kata + timecode kecil), klik → edit dialog + jump.
  - Bottom: export buttons (.srt / .txt / .vtt).
- Edit: klik chip → AlertDialog dengan TextField → update word → `state.saveTranscript`.
- Jump: klik chip (long-press atau tombol jump) → `Navigator.pop` dengan result timecode → editor seek.
- Empty state: "Belum ada transcript. Pastikan ASR aktif (BYOK) + re-transcribe."

### 3.2 `lib/state/app_state.dart` — transcript persistence + chunking
```dart
Future<Transcript?> getTranscript(String projectId) async {
  // cache di _signals[projectId]?.transcript; bila null, load dari file
  final cached = _signals[projectId]?.transcript;
  if (cached != null) return cached;
  final dir = await _workDir(projectId);
  final f = File('${dir.path}/transcript.json');
  if (!f.existsSync()) return null;
  return _transcriptFromJson(jsonDecode(f.readAsStringSync()));
}

Future<void> saveTranscript(String projectId, Transcript t) async {
  _signals[projectId]?.transcript = t;
  final dir = await _workDir(projectId);
  final f = File('${dir.path}/transcript.json');
  await f.writeAsString(jsonEncode(_transcriptToJson(t)));
}

Future<void> retranscribe(String projectId, {String? language}) async {
  final p = byId(projectId);
  if (p == null) return;
  final dir = await _workDir(projectId);
  final asrAudio = '${dir.path}/asr_input.m4a';
  if (!File(asrAudio.existsSync())) {
    // re-extract bila file hilang
    await VideoService.extractAudio(sourcePath: p.filePath, start: 0, end: p.probe?.durationSec ?? 0, outputPath: asrAudio);
  }
  final t = await _transcribeChunked(asrAudio, p.probe?.durationSec ?? 0, language);
  await saveTranscript(projectId, t);
}
```

### 3.3 Chunking — `AiProviderService.transcribeChunked` (atao di AppState)
```dart
/// Transcribe audio panjang dengan chunking. Bila file < 25MB → single call.
/// Bila > 25MB → split per chunkDur detik, transcribe per chunk, merge offset.
Future<Transcript> transcribeChunked({
  required String audioFilePath,
  required double totalDuration,
  String? language,
  double chunkDur = 300, // 5 menit
}) async {
  final fileSize = await File(audioFilePath).length();
  const maxBytes = 24 * 1024 * 1024; // 24MB safety < 25MB limit
  if (fileSize <= maxBytes) {
    return transcribe(audioFilePath: audioFilePath, language: language);
  }
  // Split: extract per chunk via VideoService.extractSegment → transcribe → merge
  final chunks = <(double start, double end)>[];
  for (double s = 0; s < totalDuration; s += chunkDur) {
    chunks.add((s, min(s + chunkDur, totalDuration)));
  }
  final allWords = <WordToken>[];
  final allText = <String>[];
  for (final (cs, ce) in chunks) {
    final chunkFile = '${audioFilePath}_chunk_${cs.toInt()}.m4a';
    await VideoService.extractSegment(
      sourcePath: audioFilePath, start: cs, end: ce, outputPath: chunkFile);
    final t = await transcribe(audioFilePath: chunkFile, language: language);
    allText.add(t.fullText);
    allWords.addAll(t.words.map((w) => WordToken(
      word: w.word, start: w.start + cs, end: w.end + cs))); // offset
    try { File(chunkFile).deleteSync(); } catch (_) {}
  }
  return Transcript(
    fullText: allText.join(' '),
    words: allWords,
    language: language,
    provider: (await storage.getActiveProvider()).name,
  );
}
```
Pipeline ASR (addProjectFromUpload) ganti `transcribe` → `transcribeChunked`.

### 3.4 Export formats — helper di Transcript atau VideoService
```dart
String toVtt() {
  // 'WEBVTT\n\n' + cues dengan timecode pakai '.' (00:00:00.000)
}
String toTxt() => fullText;
```

### 3.5 Editor wiring
- Top bar editor: tambah tombol "TRANSCRIPT" → pushNamed('/transcript', arguments: projectId).
- Route `/transcript` → TranscriptScreen(projectId).
- Caption & Reframe: tetap baca `state.getTranscript(projectId)?.words` (consumer).

---

## 4. Rencana Testing

* **Test 12.1** `test/unit/models/transcript_export_test.dart`
  * `toSrt`, `toVtt` (WEBVTT header + `.` timecode), `toTxt` format benar.
* **Test 12.2** `test/unit/services/chunking_test.dart`
  * `transcribeChunked` dengan file < 24MB → single call (mock).
  * File > 24MB → split → multiple transcribe calls → merge words dengan offset benar (chunk1 words start 0, chunk2 words start +300s).
* **Test 12.3** `test/unit/state/transcript_persistence_test.dart`
  * `saveTranscript` → file `transcript.json` ada. `getTranscript` → load round-trip (words + fullText + language).
  * Cache: getTranscript return cached bila sudah di memori.
* **Test 12.4** `test/widget/transcript_screen_test.dart`
  * Render word chips dari transcript. Klik chip → edit dialog. Search filter hasil.
  * Empty state bila transcript null.
* **Test 12.5** `test/integration/asr_long_video_test.dart`
  * Pipeline ASR dengan audio mock > 25MB → chunking jalan → transcript merge offset benar.

---

## 5. Kriteria Penerimaan (Acceptance Criteria)

* Editor → tombol "TRANSCRIPT" → buka Transcript Studio.
* Transcript Studio tampilkan full transkripsi + word timecodes (scrollable).
* Video panjang (>18 menit / audio >25MB) → chunking jalan → transcript full (merge offset benar, tidak gagal 400).
* Edit kata: klik → edit teks → persist → survive restart (load dari transcript.json).
* Export: `.srt` + `.txt` + `.vtt` tersimpan valid.
* Search: cari kata → highlight; klik kata → jump playhead editor ke timecode.
* Language: pilih `zh`/`id`/`en`/auto → re-transcribe → transcript update.
* Restart app → transcript tetap ada (persistence).
* Caption & Reframe tetap baca transcript (consumer, tidak break).
* `flutter analyze lib` → 0; `flutter test` hijau.

---

## 6. Risiko & Mitigasi

| Risiko | Dampak | Mitigasi |
|--------|--------|----------|
| Chunking: transcribe per chunk lambat (video sangat panjang) | Sedang | Async progress per chunk; indikator; paralel bila memungkinkan |
| Offset timestamp merge tidak presisi di batas chunk | Sedang | Snap chunk di batas kalimat/hening (bila ada); toleransi minor |
| Edit kata tidak re-sync timecode | Rendah | Edit cuma ganti teks, timecode tetap (durasi kata tidak berubah) |
| transcript.json corrupt/versi schema | Rendah | Try-catch load; fallback re-transcribe bila parse gagal |
| Re-transcribe biaya API (ulang) | Sedang | Konfirmasi sebelum re-transcribe; cache hasil per language |
| Search di transcript sangat panjang (performa) | Rendah | Filter in-memory (word list) — cepat untuk ribuan kata |
| Gemini/word-ts kosong untuk Mandarin → search/jump terbatas | Sedang | Search pakai fullText bila words kosong; jump butuh words (fallback ke segment) |

---

## 7. Definition of Done

- `flutter analyze lib` → 0 error/warning/info.
- `flutter test` hijau (existing + 5 suite baru).
- Smoke test Linux: upload video panjang (>18 menit) → transcript full (chunking) → edit kata → restart → transcript tetap → export .srt/.txt/.vtt → search + jump.
- Caption & Reframe tetap jalan (consumer).
- Tidak ada hardcoded/dummy baru.

---

## 8. Dependency & Posisi Roadmap

- **Dependensi:** S11 (ASR engine + Transcript model) — DONE. Tidak butuh S05/S06.
- **Integrasi:** Editor (tombol TRANSCRIPT), Caption & Reframe (consumer).
- **Urutan:** setelah S11. Bisa paralel dengan S05/S06/S07 (independen).
- **Estimasi:** 3–5 hari (chunking + persistence + screen + edit + export + search + language + test).

---

## 9. Catatan & Out of Scope

- **Speaker diarization** (siapa bicara kapan) — out of scope; future.
- **Auto-translation transcript** (zh→id dll.) — out of scope; future sprint.
- **Transcript editing advanced** (split/merge segment, reorder) — S12 cuma edit teks kata; advanced ops future.
- **Caption & Reframe refactor** — S12 tidak rewrite Caption screen, hanya pastikan dia baca transcript dari source yang sama (`getTranscript`). Refactor styling caption = sprint terpisah bila perlu.
