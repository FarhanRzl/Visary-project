# PRD Sprint 03 — Signal Analyzer Resilience & FFmpeg Filter Complex Fixes

**Dokumen ID:** PRD-SPRINT-03  
**Modul Fokus:** Local Signal Analyzer, Robust Scoring, FFmpeg Render Pipeline  
**Target File:** `lib/services/local_analyzer.dart`, `lib/services/video_service.dart`  
**Issue Terkait:** ISS-05, ISS-06  

---

## 1. Latar Belakang & Masalah
* **ISS-05 (Medium):** Pada file video tanpa channel audio (`probe.hasAudio == false`), list `energy` pada `VideoSignals` bernilai kosong. Di method `_score(s, a, b)` dan `assets(s, ...)`, jika array kosong dievaluasi tanpa pengecekan ketat, operasi reduksi list seperti `reduce(min)` melempar `StateError: Bad state: No element`. Hal ini menggagalkan proses analisis untuk konten B-roll/video visual bisu.
* **ISS-06 (Medium):** Saat merender klip jenis `ClipType.resequenced` (hook dipindah ke depan, diikuti sisa bagian klip), pemotongan stream audio dan video menggunakan `trim` dan `atrim` di FFmpeg filter complex rentan mengalami micro-gap atau desinkronisasi audio. Hal ini disebabkan perbedaan antara batas frame video dengan packet sample audio.

---

## 2. Sasaran Perbaikan (Scope of Work)
1. **Peningkatan Robustness `LocalAnalyzer`:**
   * Memastikan seluruh kalkulasi skor energi audio aman dari `empty-list` exception.
   * Menyediakan strategi scoring fallback murni berbasis kepadatan pergantian shot visual (`cutsPerMin`) ketika video tidak memiliki audio.
2. **Penyempurnaan FFmpeg Filter Complex:**
   * Menambahkan parameter `asetpts=PTS-STARTPTS` dan `aresample=async=1000` pada filter complex untuk mencegah audio drifting atau glitch pada titik potong klip re-sequenced.
   * Validasi format output untuk memastikan SAR/DAR 1:1 dan kompatibel dengan encoder H.264/AAC standar mobile.
3. **Penyempurnaan Caption Burn-in & Subtitle File:**
   * Menggunakan format **Advanced SubStation Alpha (`.ass`)** alih-alih `.srt` biasa agar mendukung animasi kata-per-kata (*word-by-word highlight color*) khas CapCut/Submagic via filter FFmpeg `-vf "subtitles=file.ass"`.
4. **Strategi Map-Reduce untuk Video Panjang (> 10 Menit):**
   * Membagi video panjang menjadi *chunk* lokal 5 menit, menyeleksi kandidat per chunk, lalu mengirim ringkasan ke LLM untuk memangkas konsumsi token.

---

## 3. Spesifikasi Teknis Perbaikan

### 3.0 Tools & Library Referensi
* **[`Breakthrough/PySceneDetect`](https://github.com/Breakthrough/PySceneDetect):** Standar deteksi scene boundary & shot transition.
* **[`kkroening/ffmpeg-python`](https://github.com/kkroening/ffmpeg-python):** Acuan penyusunan FFmpeg filter complex (concat, atrim, aresample).
* **[`chang-pro/clippro`](https://github.com/chang-pro/clippro):** Blueprint alur chunking video panjang, integrasi `PySceneDetect`, dan FFmpeg filter complex untuk blur-pad background 9:16 + burn-in ASS karaoke.
* **[`Steezy-code/clipper`](https://github.com/Steezy-code/clipper):** Blueprint alur sinkronisasi A/V kata-per-kata ASR `faster-whisper` dan virtual camera motion smoothing.

### 3.0.1 Blueprint User Story & Pipeline Flow (Adopted from ClipPro)
```
[Long Video Input]
        │
        ├── 1. Chunking (>10m) ──► Potong chunk 5-20 menit dengan overlap 30s
        ├── 2. Faster-Whisper  ──► Ekstraksi kata ber-timestamp (Word-level JSON)
        ├── 3. Scene Detection ──► PySceneDetect tandai shot boundary
        └── 4. FFmpeg Concat   ──► Concat multi-part tanpa micro-gap audio
```

### 3.1 Pembenahan `_score` pada `lib/services/local_analyzer.dart`
```dart
static int _score(VideoSignals s, double a, double b) {
  final dur = b - a;
  if (dur <= 0) return 40;

  double eNorm = 0.5;
  if (s.energy.isNotEmpty) {
    final vals = s.energy.map((p) => p.rmsDb).where((v) => v > -89).toList();
    if (vals.isNotEmpty) {
      final lo = vals.reduce(min), hi = vals.reduce(max);
      final m = s.meanEnergy(a, b);
      eNorm = (hi - lo) < 0.5 ? 0.5 : ((m - lo) / (hi - lo)).clamp(0.0, 1.0);
    }
  }

  // Jika tidak ada audio, bobot dialihkan ke ritme visual (shot frequency)
  final cutsPerMin = s.shotsIn(a, b) / (dur / 60);
  final cNorm = (cutsPerMin / 20).clamp(0.0, 1.0);

  if (s.energy.isEmpty) {
    return (40 + 60 * cNorm).round().clamp(0, 100);
  }
  return (40 + 40 * eNorm + 20 * cNorm).round().clamp(0, 100);
}
```

### 3.2 Pembenahan Filter Concat pada `lib/services/video_service.dart`
```dart
// Untuk menjaga sinkronisasi audio pada pemotongan multi-part:
if (hasAudio) {
  fc.write('[0:a]atrim=start=$s:end=$e,asetpts=PTS-STARTPTS,aresample=async=1000[a$i];');
  aLabels.add('[a$i]');
}
```

---

## 4. Rencana Automation Testing
* **Test 3.1:** `test/unit/services/analyzer_audio_fallback_test.dart`
  * Jalankan `LocalAnalyzer.scan()` dan `clips()` dengan `VideoProbe(hasAudio: false)`.
  * Verifikasi tidak ada exception yang dilempar dan klip berhasil dihasilkan.
* **Test 3.2:** `test/integration/ffmpeg_render_resequence_test.dart`
  * Render klip multi-part `resequenced` menggunakan video sampel.
  * Verifikasi file output `.mp4` memiliki stream audio dan video dengan durasi yang tepat.

---

## 5. Kriteria Penerimaan (Acceptance Criteria)
* Video tanpa audio dapat diproses dan menghasilkan klip serta aset B-roll tanpa crash.
* Render klip resequenced menghasilkan file video yang mulus di titik potong tanpa lonjakan audio atau desinkronisasi suara.
* Test suite analyzer dan render lulus 100%.
