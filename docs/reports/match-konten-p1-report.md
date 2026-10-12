# Match Konten — Stabilization & Cost Optimization Report

**Tanggal:** 2026-10-12  
**Branch:** `feature/s18-caption-reframe-sidebar`  
**Base commit:** `6a13ad0`  
**Latest commit:** `abe38a9`

---

## Prioritas 1 — Test Range Matching: SELESAI

### Perubahan File

| File | Aksi | Baris |
|------|------|-------|
| `test/unit/services/range_matching_test.dart` | NEW | 381 |
| `test/unit/services/resequence_frame_ranges_test.dart` | NEW | 392 |
| `lib/services/content_matcher_service.dart` | FIX | +5 |

### Test yang Dibuat (36 total)

**range_matching_test.dart (20 tests):**

| Group | Test | Skenario |
|-------|------|----------|
| matchContentRanges | valid JSON ranges → parsed correctly | `[[0,2],[3,5],[6,9]]` → exact match |
| matchContentRanges | LLM response with extra text → regex extracts JSON array | Teks + JSON + teks |
| matchContentRanges | invalid JSON (plain text) → fallback even split | `"I cannot match"` |
| matchContentRanges | malformed JSON array → fallback | `[[0,2],[3,]` |
| matchContentRanges | indices out of bounds → clamped to frameCount-1 | `[10,99]` → clamped |
| matchContentRanges | start > end → end clamped to start | `[5,2]` → `(4,4)` |
| matchContentRanges | segment count mismatch → fallback | 3 segs, 2 ranges returned |
| matchContentRanges | LLM throw → fallback even split | Exception("network error") |
| matchContentRanges | empty segments → degenerate ranges | `segments: []` |
| matchContentRanges | empty visual descriptions → degenerate ranges | `descs: []` |
| matchContentRanges | nested empty arrays → fallback | `[[],[]]` |
| fallbackRanges | even split: 6 frames, 3 segs | `[(0,1),(2,3),(4,5)]` |
| fallbackRanges | remainder to last: 7 frames, 3 segs | `[(0,1),(2,3),(4,6)]` |
| fallbackRanges | equal count: 3 frames, 3 segs | `[(0,0),(1,1),(2,2)]` |
| fallbackRanges | more segs than frames: 2 frames, 4 segs | No crash, all indices ≤1 |
| fallbackRanges | zero frame count → empty | `fallbackRanges(0, 3)` |
| fallbackRanges | zero segment count → empty | `fallbackRanges(6, 0)` |
| fallbackRanges | single segment → covers all frames | `fallbackRanges(10, 1)` → `(0,9)` |
| fallbackRanges | not evenly divisible: 10 frames, 3 segs | `[(0,2),(3,5),(6,9)]` |
| fallbackRanges | **fallback can produce visually-wrong-but-valid output** | Documents false-positive risk |

**resequence_frame_ranges_test.dart (16 tests):**

| Group | Test | Skenario |
|-------|------|----------|
| buildPartsWithFrameRanges | 3 segments, 6 frames → correct boundaries | vStart/vEnd from timestamps, midpoint |
| buildPartsWithFrameRanges | last frame end uses videoDuration | endClamped=last → vEnd=videoDuration |
| buildPartsWithFrameRanges | mid frame end uses midpoint to next frame | `midpoint(6,10)=8` |
| buildPartsWithFrameRanges | speed clamp 0.25x: visual 1s, audio 100s | rawSpeed=0.01 → clamp 0.25 |
| buildPartsWithFrameRanges | speed clamp 4.0x: visual 20s, audio 1s | rawSpeed=20 → clamp 4.0 |
| buildPartsWithFrameRanges | speed 1.0x: visual = audio duration | Exact match |
| buildPartsWithFrameRanges | zero-duration audio segment → skipped | `audioDur <= 0` → continue |
| buildPartsWithFrameRanges | empty segments → fallback | `[ClipPart(0, fallback)]` |
| buildPartsWithFrameRanges | empty frameTimestamps → fallback | `[ClipPart(0, fallback)]` |
| buildPartsWithFrameRanges | empty frameRanges → fallback | `[ClipPart(0, fallback)]` |
| buildPartsWithFrameRanges | vEnd <= vStart → vStart + 0.1 | Degenerate case |
| buildPartsWithFrameRanges | frame index out of bounds → clamped | endIdx=99 → clamped |
| buildPartsWithFrameRanges | more segments than frameRanges → only matching processed | 3 segs, 2 ranges → 2 parts |
| resequenceWithFrameRanges | clips updated with new parts | type=resequenced, parts replaced |
| resequenceWithFrameRanges | empty segments → clips unchanged | Returns as-is |
| resequenceWithFrameRanges | multiple clips each get resequenced | All clips updated |

### Bug Ditemukan & Diperbaiki

**Bug: `fallbackRanges` crash saat `segCount > frameCount`**

- **Root cause:** `perSeg = frameCount ~/ segCount = 0` → `end = start - 1` → `end.clamp(start, frameCount-1)` throws `Invalid argument(s)` karena `start > frameCount-1` (lower bound > upper bound di `int.clamp`)
- **Impact:** Crash saat audio memiliki lebih banyak segmen topik daripada frame terekstrak. Skenario realistis: video 10s dengan 5 topik audio tapi hanya 5 frame terekstrak (max 30 frames, interval 2s).
- **Fix:** Tambah `start = start.clamp(0, frameCount - 1)` sebelum `end = end.clamp(start, frameCount - 1)`. Start di-clamp ke valid range dulu, sehingga lower bound tidak pernah exceed upper bound.
- **File:** `lib/services/content_matcher_service.dart:460`
- **Commit:** `abe38a9`

### Temuan: Fallback Dapat Menghasilkan Visual Salah Tapi Tampak Berhasil

Test `fallback can produce visually-wrong-but-valid output` mendokumentasikan:

```
Skenario: 6 frames, 3 segments
Visual: [hot_pot, hot_pot, hot_pot, LED_screen, LED_screen, LED_screen]
Audio topics: [hot_pot, LED_screen, hot_pot]  (non-sequential)

fallbackRanges(6, 3) → [(0,1), (2,3), (4,5)]

seg 0 (hot_pot)     → frames 0-1 (hot_pot)     ✓ correct
seg 1 (LED_screen)  → frames 2-3 (hot_pot!)     ✗ partially wrong
seg 2 (hot_pot)     → frames 4-5 (LED_screen!)  ✗ WRONG
```

Hasil fallback **syntactically valid** (contiguous, no gaps, no overlaps) tapi **semantically incorrect**. Ini false-positive risk: pipeline tidak crash, clips di-generate, tapi visual tidak match audio topic. User tidak akan tahu kecuali menonton hasil.

### Hasil Test Sebelum vs Sesudah

| Metric | Sebelum | Sesudah |
|--------|---------|---------|
| Total tests | 231 pass | **267 pass** |
| Tests for matchContentRanges | 0 | **11** |
| Tests for fallbackRanges | 0 | **9** |
| Tests for buildPartsWithFrameRanges | 0 | **13** |
| Tests for resequenceWithFrameRanges | 0 | **3** |
| flutter analyze lib | 0 issues | **0 issues** |
| Failing tests | 0 | **0** |

### Commit

`abe38a9` — test(s18): range matching unit tests + fix fallbackRanges crash

---

## Prioritas 2 — Validasi End-to-End: BERIKUTNYA

Akan dilanjutkan setelah laporan ini. Memerlukan:
- Video nyata dengan multiple topic changes
- Gemini Vision API recovery (sebelumnya 503)
- Provider alternatif via auto-switch routing jika Gemini masih 503

---

## Risiko yang Masih Tersisa (dari Prioritas 1)

1. **Fallback false-positive:** `fallbackRanges` menghasilkan range valid tapi semantically wrong. Tidak ada confidence score untuk membedakan hasil LLM match vs fallback. Prioritas 3 (semantik matching) akan mengatasi ini.

2. **`matchContentRanges` prompt belum memberikan opsi "no_match":** LLM dipaksa return range untuk setiap segmen, bahkan bila tidak ada frame yang relevan. Prioritas 3 akan menambah status `matched`/`uncertain`/`no_match`.

3. **Bug fix `fallbackRanges` adalah production code change:** Meskipun fix hanya 1 baris (`start.clamp`), ini mengubah behavior production. Test sebelumnya tidak cover kasus `segCount > frameCount`, jadi bug tidak terdeteksi sampai test baru dibuat. Test sekarang cover kasus ini.
