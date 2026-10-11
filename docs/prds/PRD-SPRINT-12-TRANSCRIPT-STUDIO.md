# PRD Sprint 12 — Transcript Export

**Dokumen ID:** PRD-SPRINT-12
**Modul Fokus:** Export/Download Transcript (.srt + .txt) dari Caption & Reframe Screen
**Target File:** `lib/screens/caption_reframe_screen.dart`, `lib/models/models.dart`, `test/*`
**Referensi:** `PRD-SPRINT-11` (ASR engine — done), `EXECUTION-ORDER-PRD.md`
**Status:** Draft — siap eksekusi (depends on S11, sudah done)

---

## 1. Latar Belakang & Masalah

S11 mengimplement ASR engine: `transcribe` → `Transcript` (word-level timestamp) tersimpan di `VideoSignals.transcript`. `CaptionReframeScreen` sudah baca transcript words dan tampilkan sebagai chips koreksi.

Mekanisme transcript **tidak diubah** — tetap: ASR → `Transcript` → `VideoSignals.transcript` (in-memory) → Caption screen baca words.

Satu-satunya gap: user tidak bisa **export/download** transcript. `Transcript.toSrt()` sudah ada di model tapi tidak ada UI yang memanggilnya. Tidak ada tombol download.

| # | Limitasi | Dampak |
|---|----------|--------|
| 1 | Tidak ada UI export transcript | User tidak bisa download hasil transkripsi |
| 2 | Hanya ada `toSrt()`, tidak ada `toTxt()` | Export .txt (plain text) tidak didukung |
| 3 | Export dialog punya placeholder disabled ".SRT transkrip — segera" tapi tidak aktif | User melihat opsi yang tidak berfungsi |

**Keputusan (2026-10-11):** S12 fokus sempit — tambah tombol export transcript (.srt + .txt) di Caption & Reframe screen. Mekanisme transcript tetap apa adanya. Fitur lanjutan (dedicated screen, persistence, editing, chunking, search, language) tidak masuk S12.

---

## 2. Sasaran (Scope of Work)

### 2.1 Tombol Export Transcript di Caption & Reframe Screen
- Tambah section "EXPORT TRANSCRIPT" di panel kanan Caption & Reframe screen, setelah section "KOREKSI TRANSKRIP".
- Dua tombol: **.SRT** dan **.TXT**.
- Klik tombol → file picker (pilih folder) → simpan file transcript ke folder pilihan.
- Bila transcript null/kosong (ASR belum jalan/gagal) → tombol disabled + pesan "Belum ada transcript."

### 2.2 Format Export
- **.srt** — via `Transcript.toSrt()` (sudah ada). Format: index + timecode (`00:00:00,000 --> 00:00:00,000`) + text per word.
- **.txt** — plain text `Transcript.fullText`. Tambah method `toTxt()` di model `Transcript`.

### 2.3 Naming File
- `{projectId}_{projectName}_transcript.srt` / `.txt`
- Sanitasi nama: ganti spasi/special chars dengan `_`.

---

## 3. Spesifikasi Teknis

### 3.1 `lib/models/models.dart` — tambah `toTxt()`
```dart
/// Plain text transcript (fullText).
String toTxt() => fullText;
```

### 3.2 `lib/screens/caption_reframe_screen.dart` — tambah export section
- Import `package:file_picker/file_picker.dart` dan `package:path_provider/path_provider.dart`.
- Ambil transcript: `state.signalsOf(widget.projectId)?.transcript`.
- Section baru setelah "KOREKSI TRANSKRIP":
  - Label "EXPORT TRANSCRIPT" (VT.mono).
  - Bila transcript null/kosong: tampilkan pesan disabled "Belum ada transcript. Jalankan ASR terlebih dahulu."
  - Bila transcript ada: dua tombol BButton (.SRT / .TXT).
- Method `_exportTranscript(String format)`:
  1. `FilePicker.platform.getDirectoryPath()` → pilih folder.
  2. Generate content: `transcript.toSrt()` atau `transcript.toTxt()`.
  3. Write file: `File('$folder/${_sanitizedProjectName}_transcript.$ext')`.
  4. SnackBar: "Transcript tersimpan: {path}".
  5. Try-catch: bila gagal → SnackBar error.

### 3.3 Export dialog placeholder
- Placeholder ".SRT transkrip — segera" di `export_dialog.dart` line 532 **dibiarkan** — itu untuk export .SRT sejajar dengan render video (burn-in / sidecar), berbeda konteks dengan download transcript standalone di Caption screen.

---

## 4. Rencana Testing

* **Test 12.1** `test/unit/models/transcript_export_test.dart`
  * `toSrt()` — format benar (index, timecode `HH:MM:SS,mmm`, text).
  * `toTxt()` — return `fullText` apa adanya.
  * Empty transcript → `toSrt()` return `''`, `toTxt()` return `''`.

* **Test 12.2** `test/widget/transcript_export_button_test.dart`
  * Caption screen dengan transcript → tombol .SRT dan .TXT visible dan enabled.
  * Caption screen tanpa transcript → tombol disabled, pesan "Belum ada transcript." tampil.
  * Klik tombol → mock file picker → file tertulis dengan nama benar.

---

## 5. Kriteria Penerimaan (Acceptance Criteria)

* Caption & Reframe screen punya section "EXPORT TRANSCRIPT" dengan tombol .SRT dan .TXT.
* Klik tombol → pilih folder → file tersimpan di folder tersebut.
* .SRT valid (dibuka di text editor / subtitle player → format benar).
* .TXT berisi plain text transkripsi.
* Bila transcript kosong/null → tombol disabled + pesan.
* Mekanisme transcript (ASR → VideoSignals.transcript → caption words) tidak berubah.
* `flutter analyze lib` → 0; `flutter test` hijau.

---

## 6. Risiko & Mitigasi

| Risiko | Dampak | Mitigasi |
|--------|--------|----------|
| File picker null (user cancel) | Rendah | Guard: bila folder null → noop, tidak error |
| Transcript words kosong (Gemini/text-only) → .srt kosong | Sedang | `toSrt()` return `''` bila words kosong; tombol .SRT tampilkan warning bila `words.isEmpty && fullText.isNotEmpty` → sarankan .TXT |
| Nama file conflict (sudah ada) | Rendah | `File.writeAsString` overwrite; atau append suffix `_2` |
| Path folder tidak writable | Rendah | Try-catch → SnackBar error |

---

## 7. Definition of Done

- `flutter analyze lib` → 0 error/warning/info.
- `flutter test` hijau (existing + 2 suite baru).
- Smoke test Linux: buka Caption & Reframe → klik .SRT → file tersimpan → buka di text editor → valid. Klik .TXT → file tersimpan → isi plain text.
- Transcript kosong → tombol disabled + pesan.
- Mekanisme transcript tidak berubah.

---

## 8. Dependency & Posisi Roadmap

- **Dependensi:** S11 (ASR engine + Transcript model + `toSrt()`) — DONE.
- **Integrasi:** Caption & Reframe screen (tambah section export).
- **Urutan:** setelah S11. Independen dari S05/S06/S07.
- **Estimasi:** 0.5–1 hari (method `toTxt()` + UI tombol + file picker + test).

---

## 9. Catatan & Out of Scope

Fitur berikut **tidak masuk S12** — dihilangkan dari scope (bukan deferred, bukan phase 2):
- Dedicated transcript screen (`/transcript` route).
- Transcript persistence (`transcript.json`).
- Transcript editing (klik kata → edit teks → persist).
- Audio chunking untuk video panjang (>25MB).
- Search transcript + jump-to-timecode.
- Language selection + re-transcribe.

Bila fitur-fitur tersebut dibutuhkan di masa depan, dibuat sebagai sprint baru terpisah (mis. S13+), bukan kelanjutan S12.

- **Export dialog placeholder** (".SRT transkrip — segera") tetap ada — konteksnya berbeda (sidecar/burn-in saat render video), bukan download standalone.
