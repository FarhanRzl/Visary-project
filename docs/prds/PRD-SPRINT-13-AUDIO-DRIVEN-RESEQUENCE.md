# PRD Sprint 13 — Audio-Driven Visual Re-sequencing

**Dokumen ID:** PRD-SPRINT-13
**Modul Fokus:** Transcribe Replacement Audio → Word-Boundary Re-sequencing Visual
**Target File:** `lib/state/app_state.dart`, `lib/widgets/audio_panel.dart`, `lib/services/clip_segment_planner.dart`, `lib/screens/clip_editor_screen.dart`, `lib/models/models.dart`, `test/*`
**Referensi:** `PRD-SPRINT-10` (audio replacement), `PRD-SPRINT-11` (ASR engine), `EXECUTION-ORDER-PRD.md`
**Status:** Draft — siap eksekusi (depends on S10 + S11, sudah done)

---

## 1. Latar Belakang & Masalah

S10 mengimplement audio replacement: upload audio → `AssetItem(type: audio)` → `setActiveAudioAsset` → preview mute+replace → export dengan audio pengganti.

S11 mengimplement ASR: `transcribe(audioFilePath)` → `Transcript` (word-level timestamp). Saat ini ASR hanya transkripsi audio asli video (`asr_input.m4a`) saat upload video — sekali jalan.

**Gap:** Saat user mengganti audio, transcript tetap dari audio asli video. Audio pengganti tidak ditranskripsi. Visual video tidak mengikuti rhythm/konten audio pengganti — clip parts tetap dari analisis video asli.

**Keinginan:** Audio pengganti → transkripsi → word timestamps → jadi trigger cut/switch visual video supaya visual mengikuti audio baru.

| # | Limitasi | Dampak |
|---|----------|--------|
| 1 | ASR hanya transkripsi audio asli video, bukan audio pengganti | Transcript tidak merepresentasikan audio yang sebenarnya dipakai |
| 2 | Tidak ada tombol transkripsi audio pengganti | User tidak bisa transkripsi audio pengganti |
| 3 | ClipSegmentPlanner tidak di-wire ke pipeline | Re-sequencing visual tidak pernah terjadi |
| 4 | Clip parts statis dari analisis video asli | Visual tidak mengikuti rhythm audio pengganti |

**Keputusan (2026-10-11):** S13 — transkripsi audio pengganti (manual trigger) + word-boundary re-sequencing (cut video di word boundary/pause). Transcript dari audio pengganti menimpa transcript lama. Strategi: simple, deterministik, tanpa AI content matching.

---

## 2. Sasaran (Scope of Work)

### 2.1 Transcribe Replacement Audio (Manual Trigger)
- Tombol "TRANSCRIBE AUDIO" di AudioPanel, visible hanya saat `audioMode == AudioMode.replacement`.
- Klik → `AppState.transcribeReplacementAudio(projectId)`:
  1. Ambil `project.activeAudioAsset.sourceFile` (file audio pengganti).
  2. Panggil `aiService.transcribe(audioFilePath: sourceFile)`.
  3. Timpa `signals.transcript` dengan hasil baru.
  4. Trigger re-sequencing (§2.2).
  5. `notifyListeners()`.
- Loading state: tombol → spinner + "Mentranskripsi...".
- Error handling: ASR gagal → SnackBar error, transcript tidak berubah.
- Bila BYOK off / provider tidak ada → SnackBar "Aktifkan BYOK ASR di Settings."

### 2.2 Word-Boundary Re-sequencing
- Setelah transcript audio pengganti siap, re-sequence semua clip parts di project.
- Algoritma (simple, deterministik):

  1. **Detect cut points** dari word timestamps:
     - Pause detection: gap antara `word[i].end` dan `word[i+1].start` ≥ 200ms → cut point.
     - Fallback: bila tidak ada pause, group setiap N kata (default 5) → cut point.
  2. **Map ke video segments**:
     - Ambil `signals.shots` (shot boundaries) sebagai segmen video tersedia.
     - Bila shots kosong, bagi video menjadi segmen 3s.
  3. **Create new ClipParts**:
     - Setiap audio segment (antara dua cut points) → satu ClipPart.
     - ClipPart duration = audio segment duration.
     - ClipPart points to video segment (cycle through shots): shot[0], shot[1], ..., shot[N-1], shot[0], ...
     - ClipPart(start, end) = ambil slice dari video shot sesuai durasi audio segment.
  4. **Total clip duration** = total audio duration (dari word pertama sampai terakhir).
  5. **Cycle handling**: bila video lebih pendek dari audio → cycle ulang dari awal.

- Implementasi: method `AppState.resequenceClips(String projectId)` yang update `clip.parts` untuk semua clip.
- Setelah re-sequence, timeline editor menampilkan parts baru.

### 2.3 Transcript Overwrite
- `signals.transcript` selalu dari audio aktif terakhir:
  - Transkripsi audio pengganti → timpa transcript lama.
  - Bila audio mode kembali ke original → transcript tetap dari audio pengganti terakhir (tidak auto-revert).
  - Bila user ingin transcript audio asli → re-upload video (transkripsi ulang saat upload).

### 2.4 Wiring
- `transcribeReplacementAudio` → `resequenceClips` → update `clip.parts` → `notifyListeners()`.
- Export tetap pakai `clip.parts` langsung (tidak ubah exportClip).
- ClipSegmentPlanner tetap ada sebagai utility, tapi re-sequencing terjadi di AppState (bukan di export time).

---

## 3. Spesifikasi Teknis

### 3.1 `lib/state/app_state.dart` — transcribeReplacementAudio + resequenceClips
```dart
/// Transkripsi audio pengganti → timpa transcript → re-sequence clips.
/// PRD-SPRINT-13.
Future<void> transcribeReplacementAudio(String projectId) async {
  final p = byId(projectId);
  if (p == null) throw StateError('Project tidak ditemukan');
  final audio = p.activeAudioAsset;
  if (audio == null) throw StateError('Tidak ada audio pengganti aktif');

  final signals = _signals[projectId];
  if (signals == null) throw StateError('Signals belum di-scan');

  // Transcribe audio pengganti
  final t = await _aiService.transcribe(audioFilePath: audio.sourceFile);
  signals.transcript = t; // timpa transcript lama
  debugPrint('[S13] transkrip audio pengganti: ${t.words.length} words, '
      'provider=${t.provider}');

  // Re-sequence semua clip
  resequenceClips(projectId);
  notifyListeners();
}

/// Re-sequence clip parts berdasarkan word boundary dari transcript.
/// PRD-SPRINT-13 §2.2.
void resequenceClips(String projectId) {
  final p = byId(projectId);
  if (p == null) return;
  final signals = _signals[projectId];
  final t = signals?.transcript;
  if (t == null || t.words.isEmpty) return;

  // Detect cut points
  final cutPoints = _detectCutPoints(t.words);
  // Map ke video segments
  final videoSegments = _videoSegments(signals!, p.probe?.durationSec ?? 0);
  // Build new parts per clip
  final clips = p.clips.map((clip) {
    final newParts = _buildResequencedParts(
      cutPoints: cutPoints,
      videoSegments: videoSegments,
      clipDuration: clip.parts.fold(0.0, (sum, cp) => sum + cp.duration),
    );
    return clip.copyWith(
      parts: newParts,
      type: ClipType.resequenced,
    );
  }).toList();
  _put(p.copyWith(clips: clips));
}
```

### 3.2 Cut point detection
```dart
/// Detect cut points dari word timestamps.
/// Pause ≥ 200ms = cut. Fallback: group setiap 5 kata.
List<double> _detectCutPoints(List<WordToken> words) {
  const pauseThreshold = 0.2; // 200ms
  const fallbackGroupSize = 5;
  final points = <double>[words.first.start];

  for (var i = 0; i < words.length - 1; i++) {
    final gap = words[i + 1].start - words[i].end;
    if (gap >= pauseThreshold) {
      points.add(words[i + 1].start); // cut di awal kata berikutnya
    }
  }

  // Fallback: bila terlalu sedikit cuts, group setiap N kata
  if (points.length < 3) {
    points.clear();
    for (var i = 0; i < words.length; i += fallbackGroupSize) {
      points.add(words[i].start);
    }
  }

  points.add(words.last.end); // akhir
  return points;
}
```

### 3.3 Video segments
```dart
/// Segmen video tersedia (dari shot boundaries atau dibagi 3s).
List<(double, double)> _videoSegments(VideoSignals signals, double duration) {
  if (signals.shots.length > 1) {
    return [
      for (var i = 0; i < signals.shots.length - 1; i++)
        (signals.shots[i], signals.shots[i + 1]),
    ];
  }
  // Fallback: bagi 3s
  final segs = <(double, double)>[];
  for (double s = 0; s < duration; s += 3) {
    segs.add((s, (s + 3).clamp(0, duration)));
  }
  return segs.isEmpty ? [(0, duration)] : segs;
}
```

### 3.4 Build re-sequenced parts
```dart
/// Build ClipParts: setiap audio segment → satu video segment (cycle).
List<ClipPart> _buildResequencedParts({
  required List<double> cutPoints,
  required List<(double, double)> videoSegments,
  required double clipDuration,
}) {
  final parts = <ClipPart>[];
  var segIdx = 0;

  for (var i = 0; i < cutPoints.length - 1; i++) {
    final audioStart = cutPoints[i];
    final audioEnd = cutPoints[i + 1];
    final segDur = audioEnd - audioStart;
    if (segDur <= 0) continue;

    final (vStart, vEnd) = videoSegments[segIdx % videoSegments.length];
    final vDur = vEnd - vStart;
    final takeDur = segDur < vDur ? segDur : vDur;

    parts.add(ClipPart(vStart, vStart + takeDur));
    segIdx++;
  }

  return parts.isEmpty ? [ClipPart(0, clipDuration)] : parts;
}
```

### 3.5 `lib/widgets/audio_panel.dart` — tombol Transcribe Audio
- Setelah section audio mode/selection, tambah:
  - Label "TRANSKRIPSI AUDIO PENGGANTI" (VT.mono).
  - Bila `audioMode == AudioMode.replacement`: BButton "TRANSCRIBE AUDIO" (icon `Icons.mic`).
  - Klik → `state.transcribeReplacementAudio(projectId)`.
  - Loading: `_isTranscribing` flag → spinner + disabled.
  - Success: SnackBar "Transkrip audio pengganti: N words. Clips di-resequence."
  - Error: SnackBar error message.
  - Bila `audioMode != AudioMode.replacement`: hidden.

### 3.6 Model changes
- `Clip.copyWith(parts: ..., type: ...)` — sudah ada? Cek. Bila belum, tambah.
- `ClipType.resequenced` — sudah ada (dari S09/S10).

---

## 4. Rencana Testing

* **Test 13.1** `test/unit/services/resequence_test.dart`
  * `_detectCutPoints`: pause ≥ 200ms → cut point. Tanpa pause → fallback group 5 kata.
  * `_videoSegments`: dari shots. Fallback 3s bila shots kosong.
  * `_buildResequencedParts`: audio segments → video segments (cycle). Durasi benar.
  * Edge: 1 word → 1 part. 0 words → return original parts.

* **Test 13.2** `test/unit/state/transcribe_replacement_test.dart`
  * `transcribeReplacementAudio`: mock aiService.transcribe → transcript overwrite → resequence called.
  * No active audio → throw StateError.
  * ASR fail → exception propagated.

* **Test 13.3** `test/widget/audio_panel_transcribe_button_test.dart`
  * AudioPanel dengan replacement mode → tombol "TRANSCRIBE AUDIO" visible.
  * AudioPanel dengan original/muted mode → tombol hidden.
  * Klik tombol → loading state → success snack.

---

## 5. Kriteria Penerimaan (Acceptance Criteria)

* AudioPanel menampilkan tombol "TRANSCRIBE AUDIO" saat replacement audio aktif.
* Klik tombol → ASR transkripsi audio pengganti → transcript timpa yang lama.
* Setelah transkripsi, semua clip parts di-resequence (word-boundary cuts).
* Timeline editor menampilkan parts baru (resequenced).
* Export menggunakan parts baru → visual video cut di word boundary audio pengganti.
* Bila audio mode original/muted → tombol hidden.
* Bila ASR gagal → SnackBar error, transcript/clips tidak berubah.
* `flutter analyze lib` → 0; `flutter test` hijau.

---

## 6. Risiko & Mitigasi

| Risiko | Dampak | Mitigasi |
|--------|--------|----------|
| Re-sequencing menghasilkan cuts terlalu rapat (setiap kata) | Video tidak nyonton dilihat | Pause detection + fallback group 5 kata |
| Video lebih pendek dari audio → cycle ulang | Segmen video berulang | Cycle through shots — efek montage |
| Audio pengganti tanpa speech (musik) → words kosong | Re-sequence tidak jalan | Guard: words kosong → return original parts, SnackBar sarankan audio dengan speech |
| Clip duration mismatch dengan audio duration | Export audio/video tidak sinkron | Clip duration = audio duration (dari word timestamps) |
| Re-sequence mengubah clip yang sudah user-edit manual | User kehilangan edit | Konfirmasi sebelum re-sequence: "Re-sequence akan mengubah urutan visual semua clip. Lanjutkan?" |
| Transcribe audio panjang lambat | User menunggu | Loading state + progress |

---

## 7. Definition of Done

- `flutter analyze lib` → 0 error/warning/info.
- `flutter test` hijau (existing + 3 suite baru).
- Smoke test Linux: upload video → upload audio pengganti → klik TRANSCRIBE → transcript baru → clips resequenced → timeline update → export → visual cut di word boundary.
- Transcript kosong (musik/no speech) → guard + SnackBar.
- Mekanisme audio replacement (S10) tidak break.

---

## 8. Dependency & Posisi Roadmap

- **Dependensi:** S10 (audio replacement), S11 (ASR engine) — DONE.
- **Integrasi:** AudioPanel (tombol), AppState (transcribe + resequence), ClipSegmentPlanner (utility).
- **Urutan:** setelah S12. Independen dari S05/S06/S07.
- **Estimasi:** 2–3 hari (transcribe method + resequence algorithm + UI tombol + test).

---

## 9. Catatan & Out of Scope

- **AI content matching** (kata transcript ↔ visual video via VLM/LLM) — out of scope. S13 cuma timing-based (word boundary). Content matching butuh S05+S06, future sprint.
- **Auto-revert transcript** saat audio mode kembali ke original — out of scope. Transcript tetap dari audio terakhir yang ditranskripsi.
- **Transcript persistence** — out of scope (sama seperti S12). Transcript in-memory, hilang saat restart.
- **User manual edit parts setelah re-sequence** — didukung (timeline editor tetap bisa edit parts setelah re-sequence).
- **Audio chunking** untuk audio pengganti > 25MB — out of scope (sama seperti S11/S12). Future sprint.
- **Preview sync** antara audio pengganti + visual resequenced — S10 preview (mute+replace) tetap jalan. Preview tidak real-time resequenced (hanya export yang resequenced).
