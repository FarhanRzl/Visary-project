# Execution Order PRD — Visary Desktop
**Dokumen ID:** PRD-EXEC-ORDER
**Status:** Aktif — basis urutan eksekusi sprint
**Referensi:** `Visary-PRD.md`, `docs/PRD_VISARY_V2.md`, `docs/prds/PRD-SPRINT-01..10`
**Basis status:** Verifikasi langsung kode `visary_app/lib` + `flutter analyze lib` + `flutter test` (2026-10-10); koreksi status S08/S09 + penambahan S10 (2026-10-11); S10 selesai + penambahan S11 (2026-10-11)

---

## 1. Tujuan

Menetapkan urutan pengerjaan PRD sprint berdasarkan dependency teknis dan kondisi nyata codebase, supaya:
- tidak ada sprint yang dikerjakan di atas fondasi yang belum stabil;
- pekerjaan yang sudah selesai tidak diulang;
- fitur Phase 2 (AI/backend) tidak memblokir MVP lokal.

Penomoran sprint (01–10) adalah ID dokumen, **bukan** urutan eksekusi. Urutan eksekusi ada di §4.

---

## 2. Dependency Graph

```
S01 Core Stability ──► S02 Persistence ──► S03 Analyzer/FFmpeg ──► S08 Dummy Elimination ──► S04 E2E QA
                                                                          │
                                                                          ▼
                                                     [MVP LOKAL — Gate G1]
                                                                          │
                                  ┌───────────────────────────────────────┼───────────────────────┐
                                  ▼                                       ▼                       ▼
                          S09 Pro Timeline (done)              S06 BYOK API ──► S05 AI B-Roll   S07 UI Fidelity
                                  │                              (routing AI)     (butuh AI)    (paralel)
                                  ▼
                          S10 Audio Track Mgmt (NEXT — pre-G1 OK)
                          (Phase 1 bounded; Phase 2 butuh S05+S06)
```

| Sprint | Bergantung pada | Alasan |
|--------|-----------------|--------|
| S01 | — | Startup crash & error boundary harus beres sebelum apapun |
| S02 | S01 | Persistensi butuh app stabil saat init |
| S03 | S01 | Analyzer/render harus tahan video tanpa audio sebelum di-wire ke UI |
| S08 | S02, S03 | UI nyata butuh data tersimpan (S02) dan pipeline render aman (S03) |
| S04 | S08 | Test E2E hanya bermakna setelah UI memakai data nyata |
| S09 | S04 | Pro timeline editor butuh editor + data nyata stabil |
| S10 | S08 (export engine) | Audio replacement extend `renderClip`; tidak butuh AI di Phase 1 |
| S06 | G1 | Router AI butuh fallback lokal yang sudah terbukti |
| S05 | S06 | Rekomendasi B-roll butuh provider AI (BYOK atau backend) |
| S07 | G1 | Polish visual; tidak mengubah logika, aman paralel dengan S05/S06 |

Catatan: S05 bernomar lebih kecil dari S06, tapi **S06 harus jalan duluan** karena S05 memakai `AiProviderService` yang dibuat di S06. S10 Phase 2 (audio-context matching) juga butuh S05+S06.

---

## 3. Status Terverifikasi (2026-10-11)

| Sprint | Status | Bukti |
|--------|--------|-------|
| **S01** Core Stability | ✅ Selesai | `WidgetsFlutterBinding.ensureInitialized()` di awal `main()`; `UploadScreen` menangkap `FfmpegMissingException` |
| **S02** Persistence | ✅ Selesai | `lib/data/local/{database,project_repository,workspace_storage}.dart`; `main.dart` membuka DB + `restoreSession()` + `loadProjects()`; `removeProject()` menghapus row DB + folder workspace |
| **S03** Analyzer/FFmpeg | ✅ Selesai | Analyzer aman untuk video tanpa audio; `test/unit/services/*_test.dart` lulus |
| **S04** E2E QA | ✅ Selesai | `test/widget/`, `test/unit/state/`, `test/integration/database_test.dart` → `flutter test`: **All tests passed (73)** |
| **S08** Dummy Elimination | ✅ Selesai | `export_dialog.dart` memanggil `AppState.exportClip()` (real, bukan simulasi); `outputDir` dari `getDownloadsDirectory()` + `FilePicker.getDirectoryPath()`; progress bar dari callback FFmpeg nyata; success → path file + tombol "Buka folder"; tidak ada hardcoded `C:\Users\...`; tidak ada dummy `review-kopi`/`42/60`/`0.58` di `lib/` |
| **S09** Pro Timeline Editor | ✅ Selesai | `lib/widgets/pro_timeline.dart` (648 baris) — zoom/scroll, thumbnail strip, segment manipulation, snap, keyboard shortcut; ter-wire di `clip_editor_screen.dart:573`. Timeline lama (`timeline.dart`) jadi unused import. **5 lint issue tersisa** (1 warning unused import + 4 info `prefer_const`) — masuk DoD S10 |
| **S10** Audio Track Mgmt | ✅ Selesai | `AssetType.audio`/`AudioMode`, Drift v2→v3, `renderClip` audioMode (muted/replacement + `-shortest` truncate), `muxPreviewAudio`, AudioPanel (mute/upload/extract/select), sync preview Approach 2, `ClipSegmentPlanner` hook. 91 test pass, analyze 0. Branch `feature/s10-audio-track-management`. Phase 2 (audio-context) deferred |
| **S06** BYOK | ⏸️ Belum | — |
| **S05** AI B-Roll | ⏸️ Belum | — |
| **S07** UI Fidelity | ⏸️ Belum | — |
| **S11** Speech Services | ✅ Phase 1 done | PRD `PRD-SPRINT-11-SPEECH-SERVICES.md`. Phase 1: provider custom OpenAI-compatible (Tokonomix base URL) + `transcribe` (multipart verbose_json word-ts) + Transcript/WordToken model + `toSrt` + `VideoSignals.transcript` + `JobStage.asr` real + caption editor real words. TTS deferred (§9, awaiting approval). 103 test, analyze 0. Remaining: hook-scoring word enrichment, Gemini inline-audio, chunking. |

Catatan: S04 (23 → 73 test) kini mencakup alur export. S08 export nyata sudah tervalidasi via `renderClip` + `extractSegment`. Gate G1 (validasi Windows 11) **belum dijalankan** — tetap wajib sebelum Phase 2 AI.

---

## 4. Urutan Eksekusi

### Step 1 — S08: Export nyata ✅ DONE
`ExportModal` menerima `projectId`+`clipId`; panggil `AppState.exportClip(formats, outputDir, onProgress)`; progress FFmpeg nyata; path via `path_provider`; success → path + "Buka folder"; opsi unsupported di-disable. Exit criteria terpenuhi.

### Step 2 — S09: Pro Timeline Editor ✅ DONE
`ProTimeline` terintegrasi; menggantikan `NeoBrutalTimeline`. Sisa: 5 lint issue (bersih-bersih di S10 DoD).

### Step 3 — S10: Audio Track Management ✅ DONE
**Target file:** `lib/models/models.dart`, `lib/state/app_state.dart`, `lib/services/video_service.dart`, `lib/screens/clip_editor_screen.dart`, `lib/widgets/export_dialog.dart`, `lib/data/local/*`, `test/*`

Phase 1 (bounded, no AI):
1. `AssetType.audio` + field durasi/format; `AudioMode { original, muted, replacement }`; migration Drift; storage workspace.
2. Upload audio — `file_picker` (mp3/wav/m4a/aac/ogg/flac) → copy workspace → `AssetItem(type: audio)`.
3. Extract audio — wire `VideoService.extractSegment(audioOnly:true)` → `AssetItem`.
4. Mute toggle — flag project; preview `setVolume(0)`; export `-an`.
5. Replace audio — `activeAudioAssetId`; select aset aktif.
6. Sync preview — Approach 2: `muxPreviewAudio` (FFmpeg video-mute + audio pengganti) → `VideoPlayerController` eksisting.
7. Export mixing — extend `renderClip`: `audioMode` + `replacementAudioPath`; muted→`-an`; replacement→map audio eksternal + `-shortest` (truncate-to-audio-length).
8. Architecture hook — `ClipSegmentPlanner` interface (`LocalClipPlanner` Phase 1, `AudioContextClipPlanner` stub Phase 2).
9. Bersih-bersih 5 lint issue S09 (unused import `timeline.dart` + 4 `prefer_const` `pro_timeline.dart`).
10. Test: model audio, extract, export audio mode (ffprobe assert), widget panel, planner fallback.

Exit criteria: upload audio → replace → preview synced → export → output mp4 punya audio pengganti (ffprobe assert aac + durasi min(video,audio)); mute → export no audio; extract → file valid; `flutter analyze` 0; `flutter test` hijau.

### Step 4 — Gate G1: MVP lokal
Checklist sebelum masuk Phase 2:
- [ ] Manual test Linux: upload MP4 asli 1–5 menit → kandidat clip → trim → export 9:16 & 1:1.
- [ ] Manual test Linux: S10 — upload audio → replace → preview → export dengan audio pengganti.
- [ ] Manual test Windows 11 (fvp + ffmpeg di PATH atau env override `VISARY_FFMPEG*`).
- [ ] Restart app → project, clip, asset (termasuk audio) masih ada.
- [ ] Hapus project → folder workspace terhapus.
- [ ] SLA PRD V2 §5: probe ≤500 ms, analisis video 1 menit ≤10 s, render clip 30–60 s ≤45 s/format.
- [ ] Tidak ada unhandled exception saat ffmpeg hilang / file korup.

### Step 5 — S06: BYOK & Hybrid AI Routing
Membangun `AiProviderService`, penyimpanan key terenkripsi, router (BYOK → backend → fallback `LocalAnalyzer`). Fallback lokal yang lolos G1 menjamin app tetap jalan tanpa key.

### Step 6 — S05: AI B-Roll Suggestion
Memakai `AiProviderService` dari S06. Deteksi gap visual dari sinyal yang sudah ada (kepadatan shot rendah + energi audio tinggi) → kirim ke VLM/LLM untuk keyword B-roll.

### Step 7 — S07: UI Design Fidelity (paralel dengan Step 5–6)
Alignment 10 layar ke `design/DESIGN-SPEC.md`. Independen dari logika; branch terpisah, merge setelah S05/S06 stabil untuk menghindari konflik di `clip_editor_screen.dart` dan `settings_screen.dart`.

### Step 8 (future) — S10 Phase 2: Audio-Context-Driven Visual Re-sequencing
Implementasi `AudioContextClipPlanner` via `AiProviderService` (S06) + sinyal AI (S05). Butuh S05+S06 stabil.

---

## 5. Estimasi

| Step | Sprint | Estimasi | Paralel? |
|------|--------|----------|----------|
| 1 | S08 export | ✅ done | — |
| 2 | S09 timeline | ✅ done | — |
| 3 | S10 audio (Phase 1) | 3–4 hari | — |
| 4 | Gate G1 | 1 hari (+ akses mesin Windows) | — |
| 5 | S06 | 3–4 hari | dengan S07 |
| 6 | S05 | 3–5 hari | dengan S07 |
| 7 | S07 | 4–6 hari | dengan S06/S05 |
| 8 | S10 Phase 2 | TBD (post-S05/S06) | — |

Critical path: Step 3 → 4 → 5 → 6 ≈ 7–10 hari kerja sisanya. S07 tidak menambah critical path bila paralel.

---

## 6. Risiko

| Risiko | Dampak | Mitigasi |
|--------|--------|----------|
| Windows belum pernah dites (fvp/libmdk, path ffmpeg) | Tinggi — target platform utama | Wajib di Gate G1; bundel `ffmpeg.exe` di samping exe + env override |
| Render lambat tanpa GPU encoder | Sedang | Preset `veryfast`; deteksi NVENC/QSV/AMF dijadwalkan setelah G1 |
| S05/S06 bergantung API pihak ketiga (biaya, rate limit) | Sedang | Router selalu punya fallback `LocalAnalyzer` |
| Konflik merge S10 vs S09 di `clip_editor_screen.dart` | Rendah | Panel audio = region terpisah; jangan utak `ProTimeline` |
| `-shortest` edge case (audio 0s) | Sedang | Guard durasi audio > 0 sebelum mux/export (S10) |
| Commit langsung ke main (tanpa branch per sprint) | Sedang | `git init` done (2026-10-11, SSH ke GitHub); pertimbangkan branch per sprint saat S05/S07 paralel |

---

## 7. Definition of Done (per sprint)

- `flutter analyze lib` → 0 error/warning/info.
- `flutter test` hijau, termasuk test baru untuk task sprint tersebut.
- Tidak ada nilai dummy/hardcoded baru di `lib/`.
- Smoke test manual alur utama di Linux; juga di Windows untuk sprint yang menyentuh platform/IO.
- Status sprint di §3 diperbarui dengan bukti (file/test).
