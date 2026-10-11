# PRD Sprint 05 — AI-Driven Visual Context & B-Roll Recommendation

**Dokumen ID:** PRD-SPRINT-05  
**Modul Fokus:** Integrasi VLM (Visual Language Model), Deteksi Gap Visual, Rekomendasi B-Roll Eksternal  
**Target File:** `lib/services/ai_service.dart` (Baru), `lib/screens/clip_editor_screen.dart`, `lib/widgets/timeline.dart`  
**Fitur Terkait:** Fitur Utama 4 (Clip Engine & Prompt) & Fitur Utama 7 (Asset Library)

---

## 1. Latar Belakang & Masalah
Dalam pembuatan klip *short-form*, retensi audiens sangat bergantung pada sinkronisasi antara narasi (audio) dan visual yang menarik. Saat AI merakit klip atau meng-*generate* narasi hook, seringkali video sumber tidak memiliki adegan visual pendukung yang relevan di titik tersebut (misal: *talking-head* yang monoton atau transisi kosong). Jika hal ini dibiarkan, klip akan membosankan.

**Solusi:** Sistem harus bisa mendeteksi "Gap Visual" (narasi kuat tetapi visual monoton) dan secara otomatis merekomendasikan *placeholder* B-roll dengan kata kunci pencarian (misal: "Rekomendasi B-roll: Orang minum kopi di kafe estetik") agar kreator dapat mengunduh dan menyisipkannya.

---

## 2. Sasaran Perbaikan (Scope of Work)
1. **Deteksi Visual-Audio Mismatch (Gap Analyzer):**
   * Menganalisis korelasi antara transkrip audio (ASR) dan skor kepadatan visual (pergantian shot/deteksi objek VLM).
   * Menandai segmen dengan durasi $> 4$ detik yang memiliki narasi kuat namun berstatus *low-visual-engagement* (visual statis/monoton).
2. **AI B-Roll Prompt Generator:**
   * Membaca konteks narasi pada "Gap Visual" tersebut.
   * Menghasilkan teks rekomendasi pencarian stok video (contoh: *"B-roll: close up pouring latte art"*).
3. **UI/UX Timeline Placeholder:**
   * Menampilkan blok *placeholder* bergaris putus-putus (*dashed box*) pada `NeoBrutalTimeline` dengan label rekomendasi B-roll.
   * Menambahkan tombol aksi pada layar editor untuk mengunduh/memasukkan video eksternal guna menimpa (*overlay*) track visual di titik tersebut.

---

## 3. Spesifikasi Teknis & Rencana Eksekusi

### 3.0 Tools & Library Referensi
* **Dart HTTP Client (`package:http`):** Digunakan untuk hit REST API Pexels secara langsung, karena SDK resmi mayoritas berbasis JS.
* **FFmpeg `overlay` filter:** Arsitektur visual overlay B-roll akan dibangun murni menggunakan skrip filter complex FFmpeg bawaan (`-filter_complex "[bg][fg]overlay"`).
* **[`Steezy-code/clipper`](https://github.com/Steezy-code/clipper):** Blueprint alur auto B-roll cutaway dari Pexels pada keyword moments, deteksi visual gap, dan compositing FFmpeg overlay.

### 3.0.1 Blueprint User Story & Pipeline Flow (Adopted from Steezy Clipper)
* **User Story:** "Sebagai kreator, ketika video saya memiliki narasi panjang tanpa adegan menarik, saya ingin aplikasi secara otomatis menyarankan dan menyisipkan klip stok video (B-roll) yang relevan dengan topik ucapan tersebut agar penonton tidak bosan."
* **Pipeline Flow:**
```
[Transcript Kata Kunci] ──► [LLM Gap Detector] ──► [Pexels Video Search] ──► [FFmpeg Overlay Filter]
  "kopi nikmat"          Narasi >4s tanpa cut      Unduh MP4 B-Roll 1080p     Gantikan video, tahan audio
```

### 3.1 Skema Data B-Roll Recommendation
Penambahan *property* pada entitas timeline klip:
```dart
class BrollRecommendation {
  final double startSec;
  final double endSec;
  final String keywordPrompt; // Contoh: "Cinematic coffee pouring"
  final String reason;        // Contoh: "Visual terlalu monoton (statis >5 detik)"
  
  BrollRecommendation({
    required this.startSec,
    required this.endSec,
    required this.keywordPrompt,
    required this.reason,
  });
}
```

### 3.2 Alur Eksekusi (Pipeline)
1. **Fase Scanning:** `LocalAnalyzer` memindai area klip yang memiliki *low shot density* (tidak ada *cut* selama $\ge 5$ detik) tetapi *energy audio* (narasi) tinggi.
2. **Fase AI Prompting:** Area ini dikirim ke modul AI (VLM/LLM di backend) beserta teks ASR untuk mendapatkan instruksi visual yang pas.
3. **Fase Timeline Overlay:** `NeoBrutalTimeline` me-render `BrollRecommendation` sebagai *track* terpisah (*B-roll track*) di atas *main track* video.
4. **Fase Rendering (FFmpeg):** Jika user mengganti *placeholder* dengan video B-roll eksternal asli, FFmpeg filter complex akan disesuaikan menggunakan filter `overlay` dari `[broll_input]` ke `[main_video_input]` pada durasi spesifik tanpa menimpa audio sumber.

---

## 4. Rencana Automation Testing
* **Test 5.1:** `test/unit/services/broll_gap_analyzer_test.dart`
  * Berikan mock timeline dengan narasi 10 detik tanpa ada pergantian shot (visual statis).
  * Validasi algoritma berhasil membuahkan setidaknya 1 objek `BrollRecommendation`.
* **Test 5.2:** `test/widget/timeline_broll_placeholder_test.dart`
  * *Pump* komponen timeline dengan state klip yang memiliki rekomendasi B-roll.
  * Pastikan UI *dashed-box placeholder* muncul di koordinat waktu yang tepat.
* **Test 5.3:** `test/integration/ffmpeg_broll_overlay_test.dart`
  * Uji penggabungan (overlay) file B-roll sekunder ke file utama menggunakan FFmpeg dengan rentang waktu tertentu.

---

## 5. Kriteria Penerimaan (Acceptance Criteria)
* Aplikasi dapat mendeteksi segmen klip statis (tanpa *cut*) dan memunculkan rekomendasi pencarian stok B-roll secara otomatis di timeline.
* Klik pada placeholder B-roll membuka dialog untuk input file eksternal.
* Export klip menggabungkan B-roll eksternal di rentang waktu yang direkomendasikan tanpa memotong suara asli *talking head*.
