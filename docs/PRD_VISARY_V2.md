# Product Requirements Document (PRD) — Visary Desktop v2.0
**Project:** Visary — AI Video Clip Generator for Short-Form Creators  
**Platform:** Windows 11 Desktop (Flutter + Python Sidecar/FFmpeg Engine)  
**Status:** Ready for Sprint Execution & Automation Testing  
**Dokumen Referensi:** `Visary-PRD.md`, Codebase Audit `visary_app/lib`

---

## 1. Executive Summary & Audit Codebase

Visary adalah aplikasi desktop Windows 11 berbasis Flutter yang memproses video lokal, mengekstrak sinyal audio visual (ASR, VAD, scene boundary, energi RMS, OCR), dan menghasilkan clip pendek ($\ge 30$ detik) berorientasi *hook-first* untuk TikTok, Instagram Reels, dan YouTube Shorts.

### 1.1 Temuan Issue & Vulnerability Codebase

| ID | Modul / Lokasi | Tipe | Deskripsi Masalah | Dampak / Risiko |
|---|---|---|---|---|
| **ISS-01** | `lib/main.dart:16` | **Blocker** | `fvp.registerWith(...)` dipanggil sebelum `WidgetsFlutterBinding.ensureInitialized()`. | Fatal crash saat startup di platform Windows/Desktop. |
| **ISS-02** | `lib/screens/upload_screen.dart:37` | **High** | Tidak ada `try-catch` pada `addProjectFromUpload`. | UI *freeze/stuck loading* saat FFmpeg tidak ditemukan di PATH (`FfmpegMissingException`). |
| **ISS-03** | `lib/state/app_state.dart:282` | **High** | `removeProject()` hanya menghapus entri dari memory tanpa membersihkan folder workspace temp (`/tmp/visary/{id}`). | Storage leak; disk space user cepat penuh akibat penumpukan file klip & thumbnail. |
| **ISS-04** | `lib/state/app_state.dart:16` | **Architecture** | State project masih volatile (`List<Project>`). Belum terhubung ke Drift SQLite. | Riwayat project hilang setiap aplikasi ditutup/restart. |
| **ISS-05** | `lib/services/local_analyzer.dart:81` | **Medium** | Array `energy` kosong jika video tanpa audio (`probe.hasAudio == false`). | Potensi `StateError (No element)` saat reduksi nilai min/max RMS. |
| **ISS-06** | `lib/services/video_service.dart:258` | **Medium** | Filter complex FFmpeg `concat` pada klip `resequenced` rentan desinkronisasi audio jika batas waktu tidak tepat di keyframe audio. | Glitch audio/video pada titik sambungan klip. |
| **ISS-07** | Multiple Files (`clip_editor_screen.dart`, `settings_screen.dart`, `timeline.dart`) | **Low / Lint** | 21 Flutter Linter issues (`withOpacity` deprecated, `activeColor` deprecated, unused variables `_dragging`, `_timelineBlock`). | Technical debt, potensi bug saat upgrade SDK Flutter. |

---

## 2. Taksonomi Fitur (7 Fitur Utama & 26 Fitur Turunan)

```
VISARY DESKTOP ENGINE
├── 1. Otentikasi & Metering (Auth & Quota)
│   ├── 1.1 Form Login & Validation
│   ├── 1.2 OAuth Google Federated Login
│   └── 1.3 Quota Metering & Estimation Display
├── 2. Ingestion & Pre-processing (Upload & Metadata)
│   ├── 2.1 Multi-format Video Picker / Drag-and-Drop
│   ├── 2.2 Pre-flight Disk & Resource Validation
│   ├── 2.3 FFprobe Metadata Extractor
│   ├── 2.4 Auto Keyframe Thumbnail Generator
│   └── 2.5 Local Workspace & Session Manager
├── 3. Analisis Multimodal (Local Multimodal Engine)
│   ├── 3.1 ASR & Word-Level Timestamp (faster-whisper)
│   ├── 3.2 Shot Detection (FFmpeg scdet / PySceneDetect)
│   ├── 3.3 Audio RMS Energy Profiling (FFmpeg astats)
│   ├── 3.4 OCR Overlay Text Extractor (PaddleOCR)
│   └── 3.5 Timeline Data Synthesizer (JSON Scheme)
├── 4. Pembuatan Klip & Prompt (Clip Generation & Prompt Mode)
│   ├── 4.1 Hook Candidate Scorer (2–5 detik)
│   ├── 4.2 Auto Clip Generator (Linear vs Resequenced)
│   ├── 4.3 Durasi Rule Enforcer (<30s, 30-60s, 1-3m, >3m)
│   ├── 4.4 Prompt-based Clip Finder (Semantic Search)
│   └── 4.5 Dynamic Re-generation Filter (Target Duration)
├── 5. Editor Interaktif & Timeline (Player & Editor)
│   ├── 5.1 Synchronized Video Playback
│   ├── 5.2 Interactive Timeline Trimming & Snap
│   ├── 5.3 1-Click Hook Swap Engine
│   └── 5.4 Caption Word-by-Word Editor
├── 6. Render & Multi-Format Export (Export Engine)
│   ├── 6.1 Aspect Ratio Reframe (9:16 & 1:1, Blur-Pad Fallback)
│   ├── 6.2 Multi-segment Filter Complex Concat
│   ├── 6.3 Word-level Highlight Caption Burn-In (.srt)
│   ├── 6.4 HW Acceleration Detection (NVENC/QSV/AMF/x264)
│   └── 6.5 Render Progress Streamer & Cancel Pipeline
└── 7. Manajemen Aset Proyek (Asset Library)
    ├── 7.1 Automatic Asset Classifier (Hook/B-Roll/SoundBite/OCR)
    ├── 7.2 Lossless Segment Audio/Video Extractor
    └── 7.3 Instant Asset Playback Preview
```

---

## 3. Matriks Skenario Automation Testing

| Modul | Layer Test | Target Function / Widget | Kriteria Keberhasilan (Assertions) |
|---|---|---|---|
| **Auth** | Unit | `AppUser`, `QuotaInfo` | Validasi kalkulasi `quota.ratio` dan `quota.remaining`. |
| **Ingestion** | Unit | `VideoService.probe()` | Parse stdout JSON FFprobe menjadi `VideoProbe` (durasi, fps, size, audio flag). |
| **Ingestion** | Integration | `VideoService.isAvailable()` | Mengembalikan `true` jika biner ada, atau melempar `FfmpegMissingException` bila hilang. |
| **Ingestion** | Widget | `UploadScreen` | Rendering dropzone, event pick file, validasi trigger error state. |
| **Analyzer** | Unit | `LocalAnalyzer.scan()` | Menghasilkan `VideoSignals` dengan shot array terurut dan list RMS dBFS valid. |
| **Analyzer** | Unit | `LocalAnalyzer.hooks()` | Mengembalikan kandidat hook berdurasi 2–5 detik, tanpa tumpang tindih (*overlap*). |
| **Analyzer** | Unit | `LocalAnalyzer.clips()` | Durasi klip memenuhi syarat PRD ($\ge 30$s untuk video panjang, full video untuk input $<30$s). |
| **Timeline** | Widget | `NeoBrutalTimeline` | Drag playhead memperbarui `onPlayheadChanged`; drag handle trim memperbarui `onTrimChanged`. |
| **Editor** | Integration | `AppState.applyHookAsOpener()` | Mengubah klip menjadi `ClipType.resequenced` dan menempatkan part hook di indeks ke-0. |
| **Export** | Integration | `VideoService.renderClip()` | File output `.mp4` terbentuk, readable, durasi sesuai jumlah durasi `parts`, format sesuai (9:16 / 1:1). |
| **Export** | Integration | `VideoService.extractSegment()` | Menghasilkan `.mp4` (video) atau `.m4a` (audio soundbite) sesuai flag `audioOnly`. |
| **E2E Flow** | Integration | End-to-End Ingestion-to-Render | Upload video $\to$ Scan Sinyal $\to$ Generate Klip $\to$ Edit Trim $\to$ Export Render. |

---

## 4. Breakdown Rencana Sprint & Task

### Sprint 1: Core Service & Error Handling Fixes (Blocker & Stability)
*   **Task 1.1:** Tambahkan `WidgetsFlutterBinding.ensureInitialized()` di `main.dart`.
*   **Task 1.2:** Implementasikan *try-catch* dan error snack/dialog pada `UploadScreen` untuk menangani `FfmpegMissingException`.
*   **Task 1.3:** Fix linter issues (`withOpacity` $\to$ `withValues`, `activeColor` $\to$ `activeThumbColor`, remove unused elements).
*   **Task 1.4:** Buat unit test suite pertama untuk `VideoService` dan `LocalAnalyzer`.

### Sprint 2: Local Persistence & Storage Management (Architecture)
*   **Task 2.1:** Implementasi database Drift SQLite (`projects`, `clips`, `assets`, `exports`).
*   **Task 2.2:** Refactor `AppState` untuk sinkronisasi CRUD dengan Drift SQLite.
*   **Task 2.3:** Implementasikan *Garbage Collector* pembersihan folder temporer pada `removeProject()`.
*   **Task 2.4:** Buat integration test suite untuk validasi storage dan persistence recovery.

### Sprint 3: Analyzer Optimization & Audio/Video Resilience (Algorithm)
*   **Task 3.1:** Tambahkan *null/empty-safe handling* pada `LocalAnalyzer` untuk video murni visual (tanpa stream audio).
*   **Task 3.2:** Optimasi filter complex `renderClip` untuk eliminasi gap audio pada klip `resequenced`.
*   **Task 3.3:** Implementasi generator file `.srt` dari data timeline ASR/OCR.
*   **Task 3.4:** Buat unit & integration test untuk skenario video hening / tanpa audio.

### Sprint 4: UI Interactive Widgets & E2E Testing Suite (Quality Assurance)
*   **Task 4.1:** Widget test untuk `NeoBrutalTimeline` (drag playhead & trim handles).
*   **Task 4.2:** Widget test untuk `ExportModal` (pilihan resolusi 9:16 vs 1:1, status progress bar).
*   **Task 4.3:** Setup E2E Automation Pipeline menggunakan file video fixture (`assets/videos/sample.mp4`).

---

## 5. Non-Functional Requirements & Performance SLA

*   **Kecepatan Probing:** FFprobe metadata extraction $\le 500\text{ ms}$.
*   **Kecepatan Analisis Lokal:** Video 1 menit selesai dianalisis $\le 10\text{ detik}$ (filter `scdet` scale 320p + `astats`).
*   **Kecepatan Rendering:** Render klip 30–60 detik dengan preset `veryfast` $\le 45\text{ detik}$ per format.
*   **Disk Footprint:** Cache temporer per project $\le 50\text{ MB}$ (hanya thumbnail & proxy preview).
*   **Crash Rate:** 0 unhandled fatal exception saat biner eksternal tidak ditemukan.
