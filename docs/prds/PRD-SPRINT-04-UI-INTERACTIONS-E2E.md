# PRD Sprint 04 — UI Widget Testing & End-to-End Automation Pipeline

**Dokumen ID:** PRD-SPRINT-04  
**Modul Fokus:** Widget Testing, Interactive Editor Components, End-to-End Test Suite  
**Target File:** `test/widget/`, `test/e2e/`, `lib/widgets/timeline.dart`, `lib/screens/`  
**Fitur Terkait:** Fitur Utama 5 (Interactive Editor) & Fitur Utama 6 (Export Pipeline)  

---

## 1. Latar Belakang & Masalah
* Komponen interaktif seperti `NeoBrutalTimeline` membutuhkan pengetesan khusus untuk memastikan bahwa geseran playhead dan trimming range pada layar editor dapat merespons gesture drag pengguna tanpa menghasilkan nilai negatif atau `NaN`.
* Diperlukan pengujian menyeluruh (End-to-End Test) yang mensimulasikan workflow lengkap pengguna: membuka aplikasi $\to$ mengunggah video $\to$ memantau progres analisis $\to$ memilih klip $\to$ mengubah rentang trim $\to$ mengekspor file video final.

---

## 2. Sasaran Perbaikan (Scope of Work)
1. **Widget Automation Testing Suite:**
   * Widget test untuk `UploadScreen`: Memastikan perubahan label stage analisis dan progress bar sesuai dengan pergerakan job state.
   * Widget test untuk `NeoBrutalTimeline`: Memastikan gesture drag playhead memicu callback `onPlayheadChanged` dan drag handle trim memicu `onTrimChanged`.
   * Widget test untuk `ExportModal`: Memastikan toggle format (9:16 vs 1:1) dan tombol export terhubung dengan benar.
2. **End-to-End (E2E) Integration Pipeline:**
   * Mengintegrasikan `test/e2e/full_pipeline_test.dart` menggunakan sampel video lokal (`assets/videos/sample.mp4`).
   * Menguji aliran data utuh dari `addProjectFromUpload()` sampai `exportClip()`.

---

## 3. Spesifikasi Skenario E2E Automation Test

### 3.0 Tools & Library Referensi
* **[`flutter/plugins/packages/integration_test`](https://github.com/flutter/plugins/tree/main/packages/integration_test):** Package resmi Flutter untuk E2E testing di platform Desktop (Windows), karena tool seluler seperti Patrol tidak mendukung Windows desktop.
* **`package:process` (Mock ProcessManager):** Mengganti panggilan biner `Process.run('ffmpeg')` dengan mock process pada Unit Test agar CI/CD berjalan dalam orde milidetik tanpa bergantung pada ketersediaan binary FFmpeg di OS.
* **Drift In-Memory DB (`NativeDatabase.memory()`):** Menjalankan pengujian SQLite di RAM murni tanpa meninggalkan sisa database fisik di disk.

### 3.0.1 Strategi & Isolasi Layer Testing (Testing Pyramid)
1. **Unit Test (70%):** Murni memori & mock HTTP/Process. Waktu eksekusi $< 5$ detik untuk seluruh suite.
2. **Integration Test (20%):** Memanggil FFmpeg nyata terhadap file fixture `assets/videos/sample.mp4` & SQLite lokal.
3. **Widget & Golden Test (10%):** Menguji interaksi drag timeline & presisi visual Neo-Brutalism dengan font lokal ter-load.

```
[Start Test]
  │
  ├── 1. Inisialisasi AppState & Mock Environment
  │
  ├── 2. Upload Execution: `addProjectFromUpload('sample.mp4')`
  │      └── Assert: JobStage == JobStage.done, progress == 1.0, clips.length > 0
  │
  ├── 3. Clip Selection & Modification
  │      └── Action: `updateClipRange(projectId, clipId, 5.0, 35.0)`
  │      └── Assert: Clip parts duration == 30.0 detik
  │
  ├── 4. Export Rendering: `exportClip(projectId, clipId, [v9x16, v1x1])`
  │      └── Assert: 2 file MP4 terbentuk di target output directory
  │      └── Assert: Ukuran file > 0 byte
  │
[End Test - Success]
```

---

## 4. Rencana Automation Testing

### 4.1 Widget Test `NeoBrutalTimelineTest`
* Pump `NeoBrutalTimeline` widget dengan parameter `durationSec: 100`.
* Gerakkan mouse/drag pada koordinat timeline.
* Verifikasi callback `onPlayheadChanged` dipanggil dengan rentang detik $0 \le t \le 100$.

### 4.2 Widget Test `ExportModalTest`
* Pump `ExportModal` dialog.
* Tap checkbox format 9:16 dan 1:1.
* Tap tombol "MULAI EXPORT" dan verifikasi fungsi callback export dipanggil.

---

## 5. Kriteria Penerimaan (Acceptance Criteria)
* Seluruh Widget Test suite lulus 100% tanpa throwing render overflow error.
* Integration E2E Test berhasil mengeksekusi pipeline utuh dari ingestion sampai file `.mp4` tersimpan di disk.
* Seluruh test suite (Sprint 01 sampai Sprint 04) siap dijalankan secara otomatis via CI/CD pipeline (`flutter test`).
