# PRD Sprint 18 — Caption & Reframe In-Editor Sidebar

**Dokumen ID:** PRD-SPRINT-18  
**Modul Fokus:** Clip Editor Layout Restructure — Caption & Reframe Sidebar  
**Target File:** `lib/screens/clip_editor_screen.dart`, `lib/screens/caption_reframe_screen.dart`, `lib/widgets/caption_reframe_panel.dart` *(new)*, `lib/main.dart`  
**Referensi Utama:** Canvas `tMv8K` (Clip Editor), Canvas `i7Nwe` (Caption & Reframe)  
**Dependensi:** PRD-SPRINT-07 (UI Design Fidelity), PRD-SPRINT-12 (Transcript Studio)

---

## 1. Latar Belakang & Masalah

Saat ini fitur **Caption & Reframe** dan **Asset** di Clip Editor memiliki UX yang fragmented:

1. **Caption & Reframe** dibuka sebagai **route navigasi terpisah** (`/caption-reframe`, `CaptionReframeScreen`) — user harus meninggalkan Clip Editor, kehilangan konteks video preview, timeline, dan clip selection yang sedang aktif.
2. **CaptionReframeScreen punya video preview sendiri** (placeholder `Icons.person`, fake subject tracking box, OCR warning banner) yang **duplikat** dengan video preview player nyata di Clip Editor (`VideoPlayer` controller, play/pause, seek). Dua video preview di dua layar berbeda = redundansi.
3. **Asset sidebar** (kolom kanan 190px) menampilkan extracted assets sebagai list statis — tidak ada interaksi editing langsung.
4. Klik tombol "CAPTION & REFRAME" di top bar maupun overlay caption di video player **memicu navigasi push** (`Navigator.pushNamed('/caption-reframe')`) — bukan panel inline.

**Masalah:** Konteks editing terputus. User harus bolak-balik antar layar untuk menyesuaikan caption, reframe, dan clip trimming secara iteratif. Video preview terpisah di CaptionReframeScreen adalah dummy — tidak memutar video nyata, tidak ada seek, tidak ada play/pause. Workflow ideal: caption & reframe editing terjadi **in-place** di atas video preview nyata Clip Editor, tanpa meninggalkan layar.

---

## 2. Tujuan

* Menggantikan **Asset sidebar** (kolom 190px di sisi kanan Clip Editor) dengan **Caption & Reframe sidebar panel** yang interaktif.
* Menghapus navigasi push ke `/caption-reframe` — semua kontrol Caption & Reframe tersedia langsung di sidebar Clip Editor.
* **Menghapus video preview dummy di CaptionReframeScreen** — tidak ada lagi video preview terpisah. Clip Editor's video preview player (`VideoPlayer` controller, 420px) menjadi satu-satunya preview. Caption overlay, subject tracking box, dan OCR warning dirender langsung di atas video preview nyata.
* Asset list yang sebelumnya berada di sidebar tetap accessible via tombol **"ASSET LIBRARY"** (navigasi ke `/assets` — layar terpisah, tidak berubah).
* Video preview, timeline, clips list, dan prompt bar di Clip Editor **tidak terpengaruh** — tetap berfungsi seperti sebelumnya.
* Caption overlay pada video preview **live-update** saat user mengubah preset/posisi di sidebar (preview real-time).

---

## 3. Cakupan Perubahan

### 3.1 Clip Editor Screen (`clip_editor_screen.dart`)

#### A. Layout Restructure — Rightmost Sidebar

**SEBELUM (current):**
```
[ Video Player 420px ] [ Editor Controls (Expanded) ] [ Asset Sidebar 190px ]
```

**SESUDAH (target):**
```
[ Video Player 420px ] [ Editor Controls (Expanded) ] [ Caption & Reframe Sidebar 320px ]
```

* Sidebar width berubah dari `190px` → `320px` (untuk menampung kontrol caption & reframe yang lebih kompleks).
* Sidebar background tetap `$paper` (`Colors.white`), border kiri `3px` `$ink`.
* Sidebar dapat di-scroll vertikal (`ListView` / `SingleChildScrollView`).

#### B. Sidebar Content — Caption & Reframe Panel

Migrasi seluruh kontrol dari `CaptionReframeScreen` ke sidebar panel:

1. **ASPECT RATIO** — Toggle 9:16 (vertikal) vs 1:1 (persegi). Tetap sinkron dengan `_selectedAspectRatio` state di Clip Editor.
2. **MODE REFRAME** — "IKUTI SUBJEK" (crop dinamis AI) vs "BLUR-PAD" (latar blur statis).
3. **PRESET CAPTION** — 3 chip: POP KUNING, BOLD PUTIH, PINK BOX.
4. **POSISI CAPTION** — 3 button: ATAS, TENGAH, BAWAH.
5. **KOREKSI TRANSKRIP** — Word-by-word clickable Wrap untuk koreksi ASR. Source: `transcript.words` dari `AppState.signalsOf(projectId)`.
6. **EXPORT TRANSCRIPT** — Tombol `.SRT` dan `.TXT` (dari PRD-SPRINT-12). Section ini tetap visible hanya bila transcript tersedia; bila tidak ada, tampilkan info banner "Belum ada transcript. Jalankan ASR terlebih dahulu."

#### C. Top Bar — Hapus Tombol "CAPTION & REFRAME"

* Hapus `BButton(label: 'CAPTION & REFRAME', ...)` dari top bar Clip Editor.
* State caption/reframe sekarang dikelola in-editor — tidak perlu navigasi terpisah.
* Tombol yang tersisa di top bar: `HOOK FINDER`, `AUDIO`, `CANCEL`, `EXPORT`.

#### D. Caption Overlay — Live Preview on Video Player

* Caption overlay di video preview player (bottom positioned box) **bukan lagi klik-to-navigate**.
* Overlay menampilkan preview caption berdasarkan preset & posisi yang dipilih di sidebar — **real-time update**.
* Klik overlay caption: tidak ada action navigasi. Opsional: auto-scroll sidebar ke section "PRESET CAPTION" (nice-to-have).

#### E. State Management

* State caption & reframe (`_aspectRatio`, `_reframeMode`, `_captionPreset`, `_captionPosition`, `_activeWordIdx`) **berpindah** dari `CaptionReframeScreen` ke `_ClipEditorScreenState`.
* State ini bersifat **per-project** — idealnya disimpan di model `Project` atau `AppState` agar persist saat user beralih clip atau kembali dari screen lain. Minimum viable: simpan sebagai local state di Clip Editor (lost on pop).
* `_selectedAspectRatio` yang sudah ada di Clip Editor **di-unify** dengan `_aspectRatio` caption/reframe — jadi satu source of truth.

### 3.2 Caption Reframe Screen (`caption_reframe_screen.dart`)

#### A. Deprecation / Removal

* `CaptionReframeScreen` **dihapus** dari codebase.
* Route `/caption-reframe` **dihapus** dari `main.dart` (`onGenerateRoute` switch case).
* Import `caption_reframe_screen.dart` **dihapus** dari `main.dart`.

#### B. Extraction ke Widget

* Seluruh **UI kontrol** Caption & Reframe diekstrak menjadi widget reusable: `CaptionReframePanel`.
* **Video preview dummy di CaptionReframeScreen TIDAK diekstrak/dimigrasi** — dihapus entirely. Clip Editor's `VideoPlayer` controller menjadi satu-satunya preview.
* `_buildCaptionStylePreview()` logic (style switch by preset) **tetap dipakai** — dipindahkan ke Clip Editor untuk render overlay di atas video preview nyata.
* File baru: `lib/widgets/caption_reframe_panel.dart`.
* Widget menerima callback/param:
  ```dart
  CaptionReframePanel({
    required String projectId,
    required int aspectRatio,         // 0 = 9:16, 1 = 1:1
    required int reframeMode,         // 0 = Ikuti Subjek, 1 = Blur-Pad
    required int captionPreset,       // 0 = Pop Kuning, 1 = Bold Putih, 2 = Pink Box
    required int captionPosition,     // 0 = Atas, 1 = Tengah, 2 = Bawah
    required int activeWordIdx,
    required ValueChanged<int> onAspectRatioChanged,
    required ValueChanged<int> onReframeModeChanged,
    required ValueChanged<int> onCaptionPresetChanged,
    required ValueChanged<int> onCaptionPositionChanged,
    required ValueChanged<int> onActiveWordChanged,
  })
  ```
* Logic export transcript (`_exportTranscript`, `_buildExportSection`) juga dipindahkan ke panel widget atau helper terpisah.

### 3.3 Main Routing (`main.dart`)

* Hapus import: `import 'screens/caption_reframe_screen.dart';`
* Hapus case `/caption-reframe` dari `onGenerateRoute`.

### 3.4 Model / Persistence (Optional Enhancement)

* Tambahkan field ke model `Project` (atau sub-model `CaptionSettings`):
  ```dart
  class CaptionSettings {
    final int aspectRatio;      // 0 = 9:16, 1 = 1:1
    final int reframeMode;      // 0 = subject, 1 = blur-pad
    final int captionPreset;    // 0-2
    final int captionPosition;  // 0-2
  }
  ```
* Persist ke database (drift/isar) agar setting caption & reframe tersimpan per-project.
* Jika persistence belum siap pada sprint ini: simpan sebagai in-memory state di Clip Editor — ditandai sebagai **Phase 2**.

---

## 4. Layout Spec — Sidebar Detail

```
┌──────────────────────────────────────┐
│ CAPTION & REFRAME          [×]       │  ← Header, VT.mono(11), border bottom 2px
├──────────────────────────────────────┤
│ ASPECT RATIO                         │  ← Section label VT.mono(11)
│ [ 9:16 (VERTIKAL) ] [ 1:1 (PERSEGI) ]│  ← Toggle, 2 kolom equal
├──────────────────────────────────────┤
│ MODE REFRAME                         │
│ ┌──────────────┐ ┌──────────────┐    │
│ │ IKUTI SUBJEK │ │  BLUR-PAD    │    │  ← Card toggle, deskripsi singkat
│ │ Crop AI      │ │  Blur statis │    │
│ └──────────────┘ └──────────────┘    │
├──────────────────────────────────────┤
│ PRESET CAPTION                       │
│ [POP KUNING] [BOLD PUTIH] [PINK BOX] │  ← Wrap chips
├──────────────────────────────────────┤
│ POSISI CAPTION                       │
│ [ATAS]  [TENGAH]  [BAWAH]            │  ← 3 button equal width
├──────────────────────────────────────┤
│ EXPORT TRANSCRIPT                    │
│ [  .SRT  ] [  .TXT  ]                │  ← 2 tombol, disabled bila no transcript
├──────────────────────────────────────┤
│ KOREKSI TRANSKRIP                    │
│ Klik kata untuk koreksi ASR:         │
│ ┌────────────────────────────────┐   │
│ │ word1  word2  word3  word4 ... │   │  ← Wrap, scrollable, clickable
│ └────────────────────────────────┘   │
└──────────────────────────────────────┘
```

* Lebar sidebar: **320px** (fix).
* Padding: 16px semua sisi.
* Divider antar section: `Divider(color: VC.ink, thickness: 2)`.
* Scroll: vertical `SingleChildScrollView` atau `ListView`.
* Neo-Brutalism rules: zero border-radius, 2px border, hard shadow.

---

## 5. Video Preview — Single Preview Source

### 5.1 Penghapusan Video Preview Dummy

`CaptionReframeScreen` memiliki video preview sendiri (left pane, flex: 6) dengan:
* Placeholder `Icons.person` (size 120) — **bukan video nyata**.
* Fake subject tracking box (green border, statik di `top: 80`).
* Caption overlay preview (`_buildCaptionStylePreview`).
* OCR warning banner (yellow, statik).

**Semua ini dihapus.** Tidak ada migrasi preview dummy ke sidebar. Clip Editor's video preview player (420px, `VideoPlayer` controller dengan play/pause/seek/real video frame) menjadi **satu-satunya sumber preview**.

### 5.2 Caption Overlay — Live Preview on Video Player

* Caption overlay dirender di atas video preview player Clip Editor — **bukan lagi klik-to-navigate**.
* Overlay menampilkan preview caption berdasarkan preset & posisi yang dipilih di sidebar — **real-time update**.
* Klik overlay caption: tidak ada action navigasi. Opsional: auto-scroll sidebar ke section "PRESET CAPTION" (nice-to-have).

---

## 6. Acceptance Criteria

1. **Sidebar Replacement:** Asset sidebar (190px) di Clip Editor diganti dengan Caption & Reframe sidebar (320px). Asset list tidak lagi tampil di sidebar Clip Editor.
2. **In-Editor Panel:** Semua kontrol Caption & Reframe (aspect ratio, reframe mode, caption preset, caption position, koreksi transkrip, export transcript) berfungsi dari sidebar tanpa navigasi ke screen lain.
3. **No Navigation Push:** Tombol "CAPTION & REFRAME" dihapus dari top bar. Tidak ada lagi `Navigator.pushNamed('/caption-reframe')` di Clip Editor.
4. **Route Cleanup:** Route `/caption-reframe` dan `CaptionReframeScreen` dihapus dari `main.dart` dan codebase.
5. **Live Caption Preview:** Caption overlay di video preview player update real-time saat preset/posisi diubah di sidebar.
6. **Aspect Ratio Unification:** Toggle aspect ratio di sidebar sinkron dengan video preview player ratio — satu perubahan mempengaruhi keduanya.
7. **Transcript Features:** Export `.SRT`/`.TXT` dan koreksi transkrip word-by-word berfungsi identik seperti di `CaptionReframeScreen` sebelumnya.
8. **Asset Library Access:** Tombol "ASSET LIBRARY" tetap available — dipindahkan ke area lain di Clip Editor (misal di bawah clips list, atau di top bar) untuk akses ke `/assets` route.
9. **Design Fidelity:** Sidebar mengikuti Neo-Brutalism design system: zero border-radius, 2-3px border `$ink`, hard-edge shadow, tipografi `VT.mono`/`VT.display`/`VT.body`.
10. **No Regression:** Video player, timeline, clips list, prompt bar, audio panel, hook finder, dan export modal tetap berfungsi tanpa perubahan perilaku.
11. **No Duplicate Preview:** Tidak ada video preview dummy (placeholder `Icons.person`, fake tracking box) tersisa di codebase. Clip Editor video preview player adalah satu-satunya sumber preview.

---

## 7. Implementasi Phasing

### Phase 1 — Core Migration (Minimum Viable)
* Ekstrak `CaptionReframeScreen` UI → `CaptionReframePanel` widget.
* Ganti Asset sidebar di Clip Editor dengan `CaptionReframePanel`.
* Hapus route `/caption-reframe` dan `CaptionReframeScreen`.
* State caption/reframe sebagai local state di `_ClipEditorScreenState`.
* Live caption overlay preview.

### Phase 2 — Persistence
* Simpan `CaptionSettings` per-project ke database.
* Restore settings saat Clip Editor dibuka.

### Phase 3 — Enhancement (Nice-to-Have)
* Subject tracking bounding box di video preview (visualisasi reframe "IKUTI SUBJEK").
* OCR collision detection warning di video preview overlay.
* Collapsible sidebar (user bisa expand/collapse panel untuk lebih banyak ruang editor).

---

## 8. Risk & Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Sidebar 320px terlalu sempit untuk kontrol kompleks | UI cramped, readability turun | Gunakan scroll vertikal, kompaktkan spacing, test di min-width 1280px |
| State local hilang saat user navigasi ke Hook Finder & kembali | User kehilangan setting caption | Phase 2: persist ke model `Project`. Sementara: terima sebagai known limitation |
| Caption overlay menutupi video preview penting | UX degraded | Posisi default "BAWAH" (bottom), transparansi background `0.85`, user bisa pindah ke "ATAS" atau "TENGAH" |
| Hapus route `/caption-reframe` break deep-link / bookmark | Edge case | Tidak ada external consumer route ini (internal app only). Safe to remove. |

---

## 9. File Changes Summary

| File | Action |
|------|--------|
| `lib/screens/clip_editor_screen.dart` | **MODIFY** — ganti Asset sidebar → CaptionReframePanel, hapus tombol CAPTION & REFRAME di top bar, tambah state caption/reframe, live overlay |
| `lib/screens/caption_reframe_screen.dart` | **DELETE** — seluruh file dihapus (termasuk video preview dummy `Icons.person`, fake tracking box, OCR warning statik) |
| `lib/widgets/caption_reframe_panel.dart` | **CREATE** — widget baru, ekstraksi UI dari CaptionReframeScreen |
| `lib/main.dart` | **MODIFY** — hapus import + route `/caption-reframe` |
| `lib/models/models.dart` | **MODIFY (Phase 2)** — tambah `CaptionSettings` model |
| `lib/data/local/*` | **MODIFY (Phase 2)** — persistence CaptionSettings |

---

## 10. Test Plan

1. **Smoke Test:** Buka Clip Editor → sidebar kanan menampilkan Caption & Reframe panel (bukan Asset list).
2. **Preset Test:** Ganti preset caption (Kuning → Putih → Pink) → overlay di video preview berubah style real-time.
3. **Position Test:** Ganti posisi caption (Atas → Tengah → Bawah) → overlay berubah posisi di video preview.
4. **Aspect Ratio Test:** Toggle 9:16 ↔ 1:1 → video preview player ratio berubah, sidebar toggle sinkron.
5. **Transcript Test:** Jalankan ASR → words muncul di koreksi transkrip section → klik kata → highlight aktif.
6. **Export Test:** Klik `.SRT` / `.TXT` → file dialog muncul → file tersimpan dengan konten benar.
7. **No Navigation Test:** Klik overlay caption di video player → tidak ada navigasi push, tetap di Clip Editor.
8. **Asset Library Test:** Tombol "ASSET LIBRARY" tetap accessible → navigasi ke `/assets` berfungsi.
9. **Regression Test:** Video play/pause, timeline trim, clip selection, prompt filter, audio panel, hook finder, export modal → semua berfungsi tanpa error.
10. **Build Test:** `flutter analyze` 0 error, `flutter build linux` sukses.
11. **No Dummy Preview Test:** Search codebase untuk `Icons.person` + `size: 120` + `SUBJEK TERDETEKSI` → tidak ada hasil (video preview dummy CaptionReframeScreen terhapus).
