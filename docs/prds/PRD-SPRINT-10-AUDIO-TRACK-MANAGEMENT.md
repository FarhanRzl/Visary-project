# PRD Sprint 10 — Audio Track Management (Mute / Extract / Replace)

**Dokumen ID:** PRD-SPRINT-10
**Modul Fokus:** Audio Asset Model, Mute/Extract/Replace Audio, Sync Preview, Export Audio Mixing
**Target File:** `lib/models/models.dart`, `lib/state/app_state.dart`, `lib/services/video_service.dart`, `lib/screens/clip_editor_screen.dart`, `lib/widgets/export_dialog.dart`, `lib/data/local/*`, `test/*`
**Referensi:** `PRD_VISARY_V2.md` (§4.5 Editor, §4.6 Export), `PRD-SPRINT-08` (export engine — DONE), `PRD-SPRINT-09` (Pro Timeline — DONE), `EXECUTION-ORDER-PRD.md`
**Status:** Draft — siap eksekusi

---

## 1. Latar Belakang & Masalah

Visary saat ini hanya memutar dan mengekspor audio dari video sumber. Creator short-form sering perlu:
- **Mute** audio asli (video tanpa suara, untuk dub/overlay eksternal).
- **Extract** audio dari video sumber sebagai aset terpisah (dipakai ulang).
- **Replace** audio sumber dengan audio lain (musik latar / voiceover buatan sendiri).

Keterbatasan saat ini:

| # | Limitasi | Lokasi | Dampak |
|---|----------|--------|--------|
| 1 | Tidak ada `AssetType.audio` — model aset hanya `hook/broll/soundBite/ocrText` | `models.dart:166` | Audio tidak bisa disimpan/dikelola sebagai aset |
| 2 | Tidak ada state audio mode (mute/replace/original) | `app_state.dart`, `Project` | Export selalu pakai audio sumber atau `-an` |
| 3 | `renderClip()` tidak menerima audio pengganti | `video_service.dart:246` | Tidak bisa render video dengan audio lain |
| 4 | Editor tidak ada kontrol audio (mute/upload/select/extract) | `clip_editor_screen.dart` | User tidak bisa manipulasi audio di editor |
| 5 | Preview editor hanya mainkan source file | `clip_editor_screen.dart:56` | User tidak dengar hasil replace sebelum export |
| 6 | `extractSegment(audioOnly:true)` sudah ada tapi tidak di-wire ke UI/aset | `video_service.dart:374` | Kapabilitas extract tersembunyi, tidak terpakai |

**Kabar baik:** extract audio ~80% sudah ada di service layer. Export engine (S08) sudah real. S10 adalah ekstensi bersih, bukan rewrite.

---

## 2. Sasaran (Scope of Work)

### 2.1 Phase 1 — Bounded, No AI (sprint ini)
- **Asset model audio** — `AssetType.audio`, field durasi/format, persistensi Drift, storage workspace.
- **Upload audio** — file_picker (mp3/wav/m4a/aac/ogg/flac) → copy workspace → `AssetItem(type: audio)`.
- **Extract audio** — wire `extractSegment(audioOnly:true)` → `AssetItem(type: audio)`.
- **Mute toggle** — flag per project; preview `setVolume(0)`; export `-an`.
- **Replace audio** — `activeAudioAssetId` project-level; select aset audio aktif.
- **Sync preview** — Approach 2: FFmpeg mux video-mute + audio pengganti → file preview, mainkan di `VideoPlayerController` eksisting.
- **Export mixing** — extend `renderClip`: muted→`-an`; replacement→map audio eksternal, `-shortest` (truncate-to-audio-length), re-encode aac.
- **Truncate-to-audio-length** — output = min(durasi video, durasi audio). Visual as-is dari source (tidak re-sequence).

### 2.2 Architecture Hook — Extension Point untuk Phase 2
Sediakan interface agar Phase 2 (audio-context-driven visual re-sequencing, dependensi S05+S06) tinggal plug-in tanpa rework:

```dart
/// Strategy: menentukan segment video yang ditampilkan.
/// Phase 1: LocalClipPlanner (passthrough — visual as-is dari source).
/// Phase 2: AudioContextClipPlanner (AI-backed — segment di-seleksi
///          berdasarkan konteks audio pengganti; butuh AiProviderService S06).
abstract class ClipSegmentPlanner {
  List<ClipPart> plan({
    required Project project,
    required VideoSignals? signals,
    AssetItem? audioAsset,
  });
}

class LocalClipPlanner implements ClipSegmentPlanner {
  // Phase 1: kembalikan parts clip yang sudah ada (visual as-is).
  @override
  List<ClipPart> plan({...}) => project.activeClip?.parts ?? [];
}

class AudioContextClipPlanner implements ClipSegmentPlanner {
  // Phase 2 STUB: fallback ke LocalClipPlanner jika AiProviderService tidak ada.
  // Implementasi penuh (post-S05/S06): ASR audio pengganti → match konteks
  // ↔ sinyal video (OCR/shot/transcript/VLM) → re-sequence parts.
  @override
  List<ClipPart> plan({...}) {
    // TODO(S05/S06): integrasi AiProviderService.
    return LocalClipPlanner().plan(project: project, signals: signals, audioAsset: audioAsset);
  }
}
```

Editor dan export memakai `ClipSegmentPlanner` (di-inject), default `LocalClipPlanner`. Phase 2 tinggal ganti impl.

---

## 3. Spesifikasi Teknis

### 3.1 `lib/models/models.dart`

```dart
// Tambah tipe aset audio
enum AssetType { hook, broll, soundBite, ocrText, audio }

// Mode audio per project
enum AudioMode { original, muted, replacement }

class AssetItem {
  final String id;
  final AssetType type;
  final String title;
  final String sourceFile;
  final double start;
  final double end;
  final double? durationSec;   // baru — durasi aset audio
  final String? audioFormat;    // baru — mp3/wav/aac/dst (null untuk non-audio)

  const AssetItem({
    required this.id,
    required this.type,
    required this.title,
    required this.sourceFile,
    required this.start,
    required this.end,
    this.durationSec,
    this.audioFormat,
  });
}

class Project {
  // tambah field:
  final AudioMode audioMode;            // default AudioMode.original
  final String? activeAudioAssetId;    // id AssetItem(type: audio) aktif
  // copyWith + equality + Drift serialization
}
```

### 3.2 `lib/services/video_service.dart`

**Extract audio** (wrapper existing `extractSegment`):
```dart
static Future<({String path, double durationSec, String format})> extractAudio({
  required String sourcePath,
  required double start,
  required double end,
  required String outputPath,
}) async {
  await extractSegment(
    sourcePath: sourcePath, start: start, end: end,
    outputPath: outputPath, audioOnly: true,
  );
  // probe hasil untuk durasi + format
  final probe = await probe(outputPath);
  return (path: outputPath, durationSec: probe.durationSec, format: probe.audioCodec ?? 'aac');
}
```

**Extend `renderClip`** — tambah parameter audio:
```dart
static Future<String> renderClip({
  required String sourcePath,
  required List<ClipPart> parts,
  required String outputPath,
  AspectFormat format = AspectFormat.v9x16,
  bool hasAudio = true,
  bool blurPad = true,
  String preset = 'veryfast',
  void Function(double progress)? onProgress,
  String? burnInSubtitlePath,
  // ── BARU (S10) ──
  AudioMode audioMode = AudioMode.original,
  String? replacementAudioPath,   // wajib jika audioMode == replacement
}) async {
  // ... bangun filter_complex video tetap (trim+concat+reframe) ...

  // Audio mapping per mode:
  // - original: concat audio sumber (perilaku saat ini)
  // - muted:    skip aLabels, akhiri dengan -an
  // - replacement: skip concat audio sumber; tambah input ke-2 = replacementAudioPath

  final args = <String>[
    '-hide_banner', '-nostdin', '-progress', 'pipe:1', '-loglevel', 'error',
    '-i', sourcePath,
    if (audioMode == AudioMode.replacement && replacementAudioPath != null) ...[
      '-stream_loop', '-1',          // loop audio jika lebih pendek
      '-i', replacementAudioPath,
    ],
    '-filter_complex', fc.toString(),
    '-map', '[vout]',
    if (audioMode == AudioMode.original && hasAudio) ...['-map', '[aout]', '-c:a', 'aac', '-b:a', '160k'],
    if (audioMode == AudioMode.replacement) ...['-map', '1:a:0', '-c:a', 'aac', '-b:a', '160k'],
    if (audioMode == AudioMode.muted || !hasAudio) '-an',
    if (audioMode == AudioMode.replacement) '-shortest',   // truncate-to-audio-length
    '-c:v', 'libx264', '-preset', preset, '-crf', '20',
    '-pix_fmt', 'yuv420p', '-movflags', '+faststart',
    '-y', outputPath,
  ];
}
```

**Preview mux** (Approach 2):
```dart
/// Mux video (mute) + audio pengganti → file preview untuk editor.
/// Dipakai sync preview; tidak reframe, video as-is.
static Future<String> muxPreviewAudio({
  required String videoPath,
  required String audioPath,
  required String outputPath,
}) async {
  final args = [
    '-hide_banner', '-loglevel', 'error',
    '-i', videoPath,
    '-stream_loop', '-1', '-i', audioPath,
    '-map', '0:v', '-map', '1:a:0',
    '-c:v', 'copy', '-c:a', 'aac', '-b:a', '160k',
    '-shortest', '-y', outputPath,
  ];
  // run + cek exit code, lempar FfmpegFailedException jika gagal
}
```

### 3.3 `lib/state/app_state.dart`
```dart
Future<AssetItem> uploadAudioAsset(String projectId, {String? filePath}) async {
  // file_picker audio → copy ke workspace/{projectId}/audio/{id}.{ext}
  // probe durasi + format → AssetItem(type: audio, durationSec, audioFormat)
  // persist via ProjectRepository + update state
}

Future<AssetItem> extractAudioAsset(String projectId, {required double start, required double end}) async {
  // VideoService.extractAudio(...) → AssetItem(type: audio)
}

void setAudioMode(String projectId, AudioMode mode);
void setActiveAudioAsset(String projectId, String? assetId);

// exportClip: teruskan audioMode + activeAudioAsset path ke renderClip
// buildPreviewWithAudio(projectId, clipId): muxPreviewAudio → return preview path
```

### 3.4 `lib/screens/clip_editor_screen.dart`
Panel kontrol audio (Neo-Brutalism, konsisten theme):
- Toggle **Mute** (AudioMode.muted ↔ original).
- Tombol **Upload Audio** → `uploadAudioAsset`.
- Tombol **Extract Audio** → `extractAudioAsset` (range = clip aktif atau full source).
- List aset audio (radio select) → `setActiveAudioAsset` + `setAudioMode(replacement)`.
- **Preview sync**: saat AudioMode.replacement, ganti `VideoPlayerController` ke file preview (muxPreviewAudio). Tombol "Apply" memicu mux (latency ~detik, indikator loading). Saat original/muted, kembali ke source file (`setVolume(0)` untuk muted).
- Editor dapat `ClipSegmentPlanner` via injection (default `LocalClipPlanner`).

### 3.5 `lib/widgets/export_dialog.dart`
- Tampilkan ringkasan audio mode (Original/Muted/Replacement: nama aset).
- Teruskan `audioMode` + `replacementAudioPath` ke `AppState.exportClip`.

---

## 4. Rencana Testing

* **Test 10.1** `test/unit/models/audio_asset_test.dart`
  * `AssetType.audio` ter-serialisasi Drift; `AudioMode` round-trip; `AssetItem(type: audio)` durasi/format terisi.
* **Test 10.2** `test/unit/services/extract_audio_test.dart`
  * `extractAudio` pada `assets/videos/sample.mp4` menghasilkan `.aac` valid; ffprobe assert codec audio + durasi ≈ range.
* **Test 10.3** `test/integration/export_audio_mode_test.dart`
  * Export **muted** → ffprobe assert TIDAK ada stream audio.
  * Export **replacement** (audio 5s, clip 30s) → ffprobe assert stream audio aac + durasi output ≈ 5s (truncate-to-audio-length via `-shortest`).
  * Export **replacement** (audio 60s, clip 30s) → durasi output ≈ 30s.
* **Test 10.4** `test/widget/audio_control_panel_test.dart`
  * Panel render; toggle mute ubah `AudioMode`; upload memicu `uploadAudioAsset` (mock); select aset set `activeAudioAssetId`.
* **Test 10.5** `test/unit/state/clip_segment_planner_test.dart`
  * `LocalClipPlanner.plan()` kembalikan parts clip aktif.
  * `AudioContextClipPlanner.plan()` fallback ke LocalClipPlanner (stub Phase 2).

---

## 5. Kriteria Penerimaan (Acceptance Criteria)

* Upload audio (mp3/wav/m4a) → muncul di list aset audio, durasi terisi.
* Select aset → set AudioMode.replacement → preview di editor memutar video-mute + audio pengganti (sync via muxed file).
* Toggle mute → preview `setVolume(0)`; export output tanpa stream audio (ffprobe).
* Extract audio → file `.aac` valid tersimpan sebagai aset, durasi sesuai range.
* Export replacement → output `.mp4` punya stream audio aac; durasi = min(video, audio) (truncate-to-audio-length).
* Tidak ada nilai hardcoded/dummy baru di `lib/`.
* `flutter analyze lib` → 0 issue (termasuk perbaikan 5 issue existing: unused import `timeline.dart` + 4 prefer_const `pro_timeline.dart`).
* `flutter test` hijau, termasuk 5 suite baru di §4.
* Architecture hook: `ClipSegmentPlanner` interface + `LocalClipPlanner` terpakai; `AudioContextClipPlanner` stub terdefinisi & ter-test fallback.

---

## 6. Risiko & Mitigasi

| Risiko | Dampak | Mitigasi |
|--------|--------|----------|
| **Tidak ada git repo** | Tinggi — tidak bisa branch/rollback saat sentuh `clip_editor_screen.dart` | `git init` + commit baseline sebelum mulai S10 |
| Konflik S10 vs S09 di `clip_editor_screen.dart` | Rendah — concern berbeda (panel audio vs timeline) | Panel audio = region terpisah; jangan utak `ProTimeline` widget |
| Preview mux latency saat Apply | Sedang — user tunggu ~detik | Indikator loading; mux hanya saat Apply, bukan realtime |
| Variasi format audio (mp3/wav/m4a/ogg) | Rendah — FFmpeg handle | Probe durasi untuk metadata; reject format tidak didukung dengan pesan jelas |
| `-shortest` edge case (audio 0s / video 0s) | Sedang | Guard: validasi durasi audio > 0 sebelum mux/export |
| Drift sync preview (kalau Approach 1 terpilih) | — | Tidak berlaku — S10 pakai Approach 2 (single muxed file) |

---

## 7. Definition of Done

- `flutter analyze lib` → 0 error/warning/info.
- `flutter test` hijau (suite existing + 5 suite baru).
- Smoke test manual Linux: upload video → extract audio → upload audio lain → replace → preview → export 9:16 → output benar (ffprobe audio stream + durasi).
- Tidak ada hardcoded/dummy baru.
- `ClipSegmentPlanner` hook terdokumentasi; Phase 2 path jelas (butuh S05+S06).

---

## 8. Dependency & Posisi Roadmap

- **Dependensi:** S08 (export engine) — DONE. S09 (Pro Timeline) — DONE (coexist).
- **Tidak dependensi:** S05 (AI B-Roll), S06 (BYOK) — hanya dibutuhkan untuk Phase 2 (audio-context matching), BUKAN Phase 1.
- **Estimasi:** 3–4 hari kerja (model + service + UI + export + test).
- **Urutan:** setelah Gate G1? — S10 bisa dikerjakan pra-G1 karena tidak menyentuh platform/IO kritis (audio upload = file_picker lokal, export = FFmpeg existing). Validasi Windows tetap wajib di Gate G1.

---

## 9. Catatan Phase 2 (di luar scope S10)

Vision full: audio pengganti menentukan visual yang tampil — segment video di-seleksi/re-sequenced berdasarkan konteks audio baru (narasi audio ↔ konten visual). Butuh:
- ASR audio pengganti (transkrip + semantik).
- Matching konteks audio ↔ sinyal video (OCR/shot/transcript/VLM existing).
- Implementasi `AudioContextClipPlanner` via `AiProviderService` (S06).
- Dikerjakan setelah S05 + S06 stabil.
