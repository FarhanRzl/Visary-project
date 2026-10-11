# PRD Sprint 09 — Pro Timeline Editor (CapCut/Opus Clip Parity)

**Dokumen ID:** PRD-SPRINT-09  
**Modul Fokus:** Interactive Timeline, Multi-Track Editing, Zoom/Scroll, Snap, Segment Manipulation  
**Target File:** `lib/widgets/timeline.dart`, `lib/screens/clip_editor_screen.dart`, `lib/state/app_state.dart`, `lib/services/video_service.dart`  
**Referensi:** CapCut Desktop Timeline, Opus Clip Editor, PRD §4.8 (Editor Manual)  
**Status:** Draft — menunggu eksekusi  

---

## 1. Latar Belakang & Masalah

Timeline editor saat ini (`NeoBrutalTimeline`) memiliki 10 limitasi kritis yang membuatnya tidak bisa dipakai untuk editing nyata:

| # | Limitasi | Dampak |
|---|----------|--------|
| 1 | **Track data mock** — shot blocks & audio blocks hardcoded rasio statis | Timeline tidak refleksikan sinyal nyata dari video |
| 2 | **Single clip trim only** — hanya 1 pasang handle kiri/kanan | Tidak bisa edit multi-segment clip (resequenced punya 2-3 parts) |
| 3 | **No zoom** — skala fixed, tidak bisa perbesar untuk presisi | Editing presisi tidak mungkin untuk video panjang |
| 4 | **No horizontal scroll** — tidak bisa geser timeline | Video >2 menit tidak muat di layar 1440px |
| 5 | **No waveform** — audio track cuma blok warna | User tidak lihat pola audio untuk tentukan cut point |
| 6 | **No thumbnail strip** — video track kosong | User tidak lihat konten visual di timeline |
| 7 | **No segment manipulation** — tidak bisa split/move/reorder/delete part | Clip resequenced tidak bisa diedit visualnya |
| 8 | **No snap** — trim tidak snap ke shot boundary atau keyframe | Cut point tidak presisi, bisa terpotong di tengah frame |
| 9 | **No keyboard shortcut** — tidak ada J/K/L, space, delete | Workflow lambat, harus klik semua |
| 10 | **No ripple edit** — mengubah durasi segment tidak geser segment setelahnya | Rearrangement manual, error-prone |

---

## 2. Sasaran Perbaikan (Scope of Work)

### 2.1 Real Signal Tracks (Data Binding)
- Track SHOT: render shot boundary nyata dari `VideoSignals.shots` (bukan mock)
- Track AUDIO: render waveform dari `VideoSignals.energy` (RMS per detik → height bar)
- Track CLIP: render setiap `ClipPart` sebagai block terpisah dengan label durasi
- Track B-ROLL: sudah ada dari S05, pertahankan

### 2.2 Zoom & Scroll
- **Zoom level** 1x–50x via mouse wheel scroll (Ctrl+scroll) atau slider
- **Horizontal scroll** otomatis saat zoom > viewport width
- **Min visible duration**: 5 detik (max zoom), max visible: full video (min zoom)
- **Playhead auto-follow**: saat playing, timeline scroll mengikuti playhead
- **Zoom-to-fit** button: reset ke full video view

### 2.3 Thumbnail Strip (Video Track)
- Extract 1 keyframe per N detik (N adaptif terhadap zoom level)
- Render sebagai `Image.file` strip horizontal di video track
- Cache thumbnail di workspace storage per project
- Lazy loading: hanya render thumbnail yang visible di viewport

### 2.4 Waveform Rendering (Audio Track)
- Render RMS energy sebagai bar chart vertikal (height = normalized RMS)
- Warna: `VC.green` untuk level normal, `VC.pink` untuk peak (>-15 dBFS)
- Resolution adaptif: 1 bar per detik (zoom out) → 1 bar per 0.1s (zoom in)
- Audio-less video: tampilkan "NO AUDIO" placeholder

### 2.5 Segment Manipulation (Multi-Part Editing)
- Setiap `ClipPart` dirender sebagai block draggable terpisah di CLIP track
- **Drag segment**: geser segment kiri/kanan → update `ClipPart.start/end`
- **Split segment**: klik di tengah segment → potong jadi 2 part di playhead position
- **Delete segment**: klik kanan / tombol → hapus part, ripple shift
- **Reorder segments**: drag segment ke posisi lain → reorder `Clip.parts` list
- **Ripple edit**: saat segment dihapus/dipendekkan, segment setelahnya geser maju
- **Snap**: trim/split snap ke shot boundary (±2s tolerance) dan keyframe

### 2.6 Keyboard Shortcuts
| Key | Action |
|-----|--------|
| Space | Play/Pause |
| J | Rewind 5s |
| K | Pause |
| L | Forward 5s |
| S | Split at playhead |
| Delete/Backspace | Delete selected segment |
| Ctrl+Z | Undo last edit |
| Ctrl+Shift+Z | Redo |
| +/= | Zoom in |
| - | Zoom out |
| 0 | Zoom to fit |
| Arrow Left/Right | Frame step (←/→) |

### 2.7 Selection & Multi-Select
- Klik segment → select (highlight border `VC.yellow`)
- Shift+klik → multi-select
- Drag selection box → select semua segment dalam box
- Selected segments bisa di-delete/move bersamaan

### 2.8 Undo/Redo Stack
- `EditAction` enum: `trim`, `split`, `delete`, `reorder`, `hookSwap`
- Stack dengan max 50 actions
- `Ctrl+Z` pop, `Ctrl+Shift+Z` redo
- Setiap action simpan state `Clip.parts` sebelum dan sesudah

---

## 3. Spesifikasi Teknis

### 3.0 Tools & Library Referensi
* **[CapCut Desktop](https://www.capcut.com):** Blueprint multi-track timeline, segment drag, ripple edit, thumbnail strip, waveform.
* **[Opus Clip](https://opus.pro):** Blueprint clip card list → timeline sync, hook swap, score badge inline.
* **[flutter/packages/video_player](https://github.com/flutter/packages/tree/main/packages/video_player):** Frame-accurate seek untuk thumbnail extraction.
* **[media_kit/media_kit](https://github.com/media-kit/media-kit):** Alternatif player dengan frame-level control.

### 3.1 Arsitektur Timeline Baru

```
NeoBrutalTimeline (StatefulWidget)
├── TimelineController (ChangeNotifier)
│   ├── zoomLevel: double (1.0 = full video visible)
│   ├── scrollOffset: double (detik, posisi scroll kiri)
│   ├── playhead: double (detik)
│   ├── selectedSegments: Set<int> (index ClipPart)
│   └── undoStack: List<EditAction>
├── TimelineRuler (time markers, adaptif zoom)
├── TimelineViewport (Scrollable + Zoomable)
│   ├── VideoTrack (thumbnail strip)
│   ├── AudioTrack (waveform bars)
│   ├── ClipTrack (segment blocks, draggable, snap)
│   └── BrollTrack (placeholder overlay)
├── TimelineToolbar (split, delete, zoom controls)
└── KeyboardHandler (Focus widget untuk shortcuts)
```

### 3.2 Thumbnail Cache System
```dart
class ThumbnailCache {
  /// Extract 1 frame per [intervalSec] dari video, simpan ke workspace.
  /// Dipanggil sekali saat project pertama kali dibuka di editor.
  static Future<void> generate({
    required String sourcePath,
    required String projectId,
    required double durationSec,
    required double intervalSec,
  }) async {
    final dir = await WorkspaceStorage.ensure(projectId);
    final count = (durationSec / intervalSec).ceil();
    for (var i = 0; i < count; i++) {
      final t = i * intervalSec;
      await VideoService.extractThumbnail(
        sourcePath: sourcePath,
        atSec: t,
        outPath: '${dir.path}/thumb_${i.toString().padLeft(5, '0')}.jpg',
        width: 160, // thumbnail kecil untuk strip
      );
    }
  }

  /// Ambil thumbnail untuk rentang [start, end] yang visible di viewport.
  static String? get(String projectId, double timeSec, double intervalSec) {
    final idx = (timeSec / intervalSec).floor();
    final path = '${WorkspaceStorage.basePath}/$projectId/thumb_${idx.toString().padLeft(5, '0')}.jpg';
    return File(path).existsSync() ? path : null;
  }
}
```

### 3.3 Waveform Rendering
```dart
Widget _buildWaveform(VideoSignals signals, double viewStart, double viewEnd) {
  final pts = signals.energy.where((p) =>
    p.timeSec >= viewStart && p.timeSec < viewEnd).toList();
  if (pts.isEmpty) return _noAudioPlaceholder();

  final maxDb = pts.map((p) => p.rmsDb).reduce(max);
  final minDb = pts.map((p) => p.rmsDb).reduce(min);
  final range = (maxDb - minDb).abs().clamp(0.1, double.infinity);

  return LayoutBuilder(builder: (c, constraints) {
    final barWidth = constraints.maxWidth / pts.length;
    return Stack(children: pts.map((p) {
      final norm = ((p.rmsDb - minDb) / range).clamp(0.0, 1.0);
      final x = ((p.timeSec - viewStart) / (viewEnd - viewStart)) * constraints.maxWidth;
      final isPeak = p.rmsDb > -15;
      return Positioned(
        left: x,
        width: barWidth,
        bottom: 0,
        height: norm * constraints.maxHeight,
        child: Container(color: isPeak ? VC.pink : VC.green),
      );
    }).toList());
  });
}
```

### 3.4 Segment Drag & Snap
```dart
void _onSegmentDrag(int partIndex, double deltaSec) {
  final clip = selectedClip;
  final parts = [...clip.parts];
  final p = parts[partIndex];

  // Snap ke shot boundary terdekat (toleransi 2s)
  double snappedStart = _snapToShot(p.start + deltaSec);
  double snappedEnd = snappedStart + p.duration;

  // Clamp: tidak overlap dengan part sebelumnya/sesudahnya
  if (partIndex > 0) {
    snappedStart = max(snappedStart, parts[partIndex - 1].end);
  }
  if (partIndex < parts.length - 1) {
    snappedEnd = min(snappedEnd, parts[partIndex + 1].start);
  }

  parts[partIndex] = ClipPart(snappedStart, snappedEnd);
  controller.updateParts(parts);
}

double _snapToShot(double t, {double tol = 2.0}) {
  for (final s in signals.shots) {
    if ((s - t).abs() < tol) return s;
  }
  return t;
}
```

### 3.5 Split at Playhead
```dart
void _splitAtPlayhead() {
  final clip = selectedClip;
  final pos = controller.playhead;
  for (var i = 0; i < clip.parts.length; i++) {
    final p = clip.parts[i];
    if (pos > p.start + 0.5 && pos < p.end - 0.5) {
      final parts = [...clip.parts];
      parts[i] = ClipPart(p.start, pos);
      parts.insert(i + 1, ClipPart(pos, p.end));
      controller.pushAction(EditAction.split(clip.id, i, p, parts[i], parts[i+1]));
      controller.updateParts(parts);
      break;
    }
  }
}
```

---

## 4. Rencana Automation Testing

* **Test 9.1:** `test/unit/services/thumbnail_cache_test.dart`
  * Generate thumbnail strip untuk sample.mp4 (assert file count = duration/interval).
  * Get thumbnail by time → path exists.
* **Test 9.2:** `test/widget/timeline_zoom_scroll_test.dart`
  * Pump timeline dengan zoom 1x, 5x, 20x → assert viewport duration.
  * Scroll horizontal → assert viewStart/viewEnd berubah.
* **Test 9.3:** `test/widget/timeline_segment_drag_test.dart`
  * Drag segment kiri → assert ClipPart.start berubah.
  * Drag dekat shot boundary → assert snap (start == shot time).
  * Split at playhead → assert parts.length bertambah.
  * Delete segment → assert parts.length berkurang + ripple shift.
* **Test 9.4:** `test/unit/state/undo_redo_test.dart`
  * Push 3 edit actions → undo 3x → state kembali ke awal.
  * Redo 2x → state = action ke-2.
* **Test 9.5:** `test/widget/timeline_waveform_test.dart`
  * Pump timeline dengan VideoSignals (energy ada) → waveform bars terender.
  * Video tanpa audio → "NO AUDIO" placeholder muncul.

---

## 5. Kriteria Penerimaan (Acceptance Criteria)

* Timeline menampilkan thumbnail strip nyata dari video di video track.
* Timeline menampilkan waveform dari sinyal audio nyata di audio track.
* User bisa zoom in/out (1x–50x) via Ctrl+scroll atau slider.
* User bisa scroll horizontal saat zoom melebihi viewport.
* Setiap segment clip (ClipPart) bisa di-drag untuk trim, dengan snap ke shot boundary.
* User bisa split segment di playhead via tombol "S" atau toolbar.
* User bisa delete segment → segment setelahnya ripple shift maju.
* User bisa reorder segment via drag.
* Keyboard shortcuts (Space, J/K/L, S, Delete, Ctrl+Z) berfungsi.
* Undo/redo stack menyimpan dan memulihkan max 50 edit actions.
* Track SHOT menampilkan shot boundary nyata (bukan mock).
* Track CLIP menampilkan setiap ClipPart sebagai block terpisah dengan label durasi.
* Test suite S09 lulus 100%.

---

## 6. Estimasi

| Task | Estimasi | Paralel? |
|------|----------|----------|
| Thumbnail cache system | 1–2 hari | — |
| Waveform rendering | 1 hari | dengan thumbnail |
| Zoom & scroll controller | 1–2 hari | — |
| Segment drag + snap | 2–3 hari | — |
| Split + delete + ripple | 1–2 hari | dengan segment drag |
| Reorder segments | 1 hari | — |
| Keyboard shortcuts | 0.5 hari | — |
| Undo/redo stack | 1 hari | — |
| Real signal track binding | 0.5 hari | — |
| Tests | 1–2 hari | — |
| **Total** | **10–14 hari kerja** | |

Critical path: thumbnail cache → zoom/scroll → segment drag → split/delete → undo/redo ≈ 7–9 hari.

---

## 7. Risiko

| Risiko | Dampak | Mitigasi |
|--------|--------|----------|
| Thumbnail extraction lambat untuk video panjang (>10 menit) | Sedang | Generate di background thread, lazy load hanya visible range |
| Waveform rendering lag untuk 100+ bars | Rendah | Limit bars per viewport (max 200), downsample energy data |
| Drag precision di high-DPI display | Rendah | Konversi pixel→detik pakai LayoutBuilder actual width |
| Undo stack memory untuk video panjang | Rendah | Max 50 actions, simpan diff bukan full state |
| Conflict dengan existing timeline tests (S04, S07) | Sedang | Buat widget baru `ProTimeline`, deprecate `NeoBrutalTimeline` |

---

## 8. Migration Plan

1. Buat `ProTimeline` widget baru (tidak overwrite `NeoBrutalTimeline`).
2. `ClipEditorScreen` switch ke `ProTimeline` dengan feature flag.
3. Existing tests untuk `NeoBrutalTimeline` tetap jalan (backward compat).
4. Setelah stabil, hapus `NeoBrutalTimeline` dan update tests.

---

## 9. Definition of Done

- `flutter analyze lib` → 0 error.
- `flutter test` hijau, termasuk test baru untuk S09.
- Manual test: upload video → buka editor → zoom → drag segment → split → delete → undo → redo.
- Timeline menampilkan thumbnail + waveform nyata.
- Keyboard shortcuts berfungsi di desktop Linux & Windows.
