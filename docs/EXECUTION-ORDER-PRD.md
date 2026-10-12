# Execution Order PRD — Visary Desktop
**Dokumen ID:** PRD-EXEC-ORDER
**Status:** Aktif — basis urutan eksekusi sprint
**Referensi:** `Visary-PRD.md`, `docs/PRD_VISARY_V2.md`, `docs/prds/PRD-SPRINT-01..14`
**Basis status:** Verifikasi langsung kode `visary_app/lib` + `flutter analyze lib` (0) + `flutter test` (180 pass) (2026-10-12); audit menyeluruh S05/S06/S07/S11/S14 — docs sebelumnya tertinggal di belakang kode.

---

## 1. Tujuan

Menetapkan urutan pengerjaan PRD sprint berdasarkan dependency teknis dan kondisi nyata codebase, supaya:
- tidak ada sprint yang dikerjakan di atas fondasi yang belum stabil;
- pekerjaan yang sudah selesai tidak diulang;
- fitur Phase 2 (AI/backend) tidak memblokir MVP lokal.

Penomoran sprint (01–14) adalah ID dokumen, **bukan** urutan eksekusi. Urutan eksekusi ada di §4.

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
                          S09 Pro Timeline (done)              S06 BYOK API (done) ──► S05 AI B-Roll (done)   S07 UI Fidelity
                                  │                                                       │                        (belum)
                                  ▼                                                       ▼
                          S10 Audio Track Mgmt (done)                           S14 Content-Aware Match (done)
                          S11 Speech (Phase 1)                                     S13 Resequencing (done)
                          S12 Transcript Export (done)
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
| S06 | G1 (dokumen) / S08 (kode) | Router AI butuh fallback lokal yang sudah terbukti — **sudah terimplementasi penuh di kode** |
| S05 | S06 | Rekomendasi B-roll memakai `AiProviderService` — **sudah terimplementasi** (`AiService` + `detectVisualGaps` + `renderWithBroll`) |
| S07 | G1 | Polish visual; tidak mengubah logika, aman paralel |
| S11 | S06 | ASR via BYOK provider — Phase 1 done |
| S12 | S11 | Transcript export butuh transcript model dari S11 |
| S13 | S11, S10 | Re-sequencing butuh word timestamps (ASR) + audio replacement (S10) |
| S14 | S06, S11, S13 | Content-aware match butuh vision API (S06) + transcript (S11) + resequencer (S13) — **done** |
| S15 | S11, S13, S14 | ASR & matching bug fixes butuh ASR pipeline (S11) + resequencer (S13) + content matcher (S14) |
| S16 | S11, S14, S15 | Semantic segmentation redesign butuh ASR (S11) + content matcher base (S14) + ASR fixes (S15) |

Catatan: S05 bernomar lebih kecil dari S06, tapi **S06 harus jalan duluan** karena S05 memakai `AiProviderService` yang dibuat di S06. Keduanya sekarang done di kode.

---

## 3. Status Terverifikasi (2026-10-12)

| Sprint | Status | Bukti |
|--------|--------|-------|
| **S01** Core Stability | ✅ Selesai | `WidgetsFlutterBinding.ensureInitialized()` di awal `main()`; `UploadScreen` menangkap `FfmpegMissingException` |
| **S02** Persistence | ✅ Selesai | `lib/data/local/{database,project_repository,workspace_storage}.dart`; `main.dart` membuka DB + `restoreSession()` + `loadProjects()`; `removeProject()` menghapus row DB + folder workspace |
| **S03** Analyzer/FFmpeg | ✅ Selesai | Analyzer aman untuk video tanpa audio; `test/unit/services/*_test.dart` lulus |
| **S04** E2E QA | ✅ Selesai | `test/widget/`, `test/unit/state/`, `test/integration/database_test.dart` → hijau |
| **S08** Dummy Elimination | ✅ Selesai | `export_dialog.dart` memanggil `AppState.exportClip()` (real, bukan simulasi); `outputDir` dari `getDownloadsDirectory()` + `FilePicker.getDirectoryPath()`; progress bar dari callback FFmpeg nyata; success → path file + tombol "Buka folder"; tidak ada hardcoded `C:\Users\...`; tidak ada dummy di `lib/` |
| **S09** Pro Timeline Editor | ✅ Selesai | `lib/widgets/pro_timeline.dart` (648 baris) — zoom/scroll, thumbnail strip, segment manipulation, snap, keyboard shortcut; ter-wire di `clip_editor_screen.dart`. Timeline lama (`timeline.dart`) tetap dipakai untuk B-roll placeholder. |
| **S10** Audio Track Mgmt | ✅ Selesai | `AssetType.audio`/`AudioMode`, Drift v2→v3, `renderClip` audioMode (muted/replacement + `-shortest` truncate), `muxPreviewAudio`, AudioPanel (mute/upload/extract/select), sync preview Approach 2, `ClipSegmentPlanner` hook. Phase 2 (audio-context) dilanjutkan via S14. |
| **S06** BYOK | ✅ Selesai | `AiProviderService` (618 baris): `testConnection` (Gemini/OpenAI/Groq/Custom), `isByokActive`, `sendPrompt` (Gemini generateContent / OpenAI-Groq chat/completions / Custom baseUrl), `visionPrompt` (S14), `transcribe` (S11 multipart ASR). `SecureKeyStorage` (flutter_secure_storage): Gemini/OpenAI/Groq/Custom key+baseUrl+model. Settings screen (`settings_screen.dart`): full BYOK UI — key input per provider, enable toggle, active provider selector, custom base URL + model. AppState: load/store semua BYOK settings saat init. Tests: `ai_provider_service_test.dart`, `secure_key_storage_test.dart`, `settings_byok_ui_test.dart`. |
| **S05** AI B-Roll | ✅ Selesai | `AiService` (`ai_service.dart`): `generateBrollKeyword` via `sendPrompt` + fallback heuristik, `generateBrollKeywords` batch, `detectAndEnrichGaps` (detect + AI enrich). `LocalAnalyzer.detectVisualGaps` — deteksi gap visual (segmen >4s, narasi kuat, visual statis). `BrollRecommendation` model dengan `copyWith`. `VideoService.renderWithBroll` — FFmpeg overlay render. `AppState.enrichBrollRecommendations` — wired setelah analisis, calls `aiBrollService.detectAndEnrichGaps`. `AppState.setBrollOverlay` — user assign file B-roll. Timeline B-roll placeholder (dashed-box). Tests: `broll_gap_analyzer_test.dart`, `timeline_broll_placeholder_test.dart`, `ffmpeg_broll_overlay_test.dart`. **Gap kecil:** `renderWithBroll` belum terima `audioMode` (B-roll + audio replacement belum terintegrasi di export path). |
| **S11** Speech Services | ✅ Phase 1 done | PRD `PRD-SPRINT-11-SPEECH-SERVICES.md`. Phase 1: provider custom OpenAI-compatible + `transcribe` (multipart verbose_json word-ts) + Transcript/WordToken model + `toSrt` + `VideoSignals.transcript` + `JobStage.asr` real + caption editor real words. **Remaining:** TTS (voiceover), hook-scoring word enrichment, Gemini inline-audio (TODO di `ai_provider_service.dart:548`), audio chunking. |
| **S12** Transcript Export | ✅ Selesai | PRD `PRD-SPRINT-12-TRANSCRIPT-STUDIO.md`. Tombol export/download transcript (.srt + .txt). `Transcript.toTxt()`. `_buildExportSection()`. |
| **S13** Audio-Driven Reseq | ✅ Selesai | PRD `PRD-SPRINT-13-AUDIO-DRIVEN-RESEQUENCE.md`. Transcribe replacement audio → word-boundary re-sequencing (sequential proportional mapping, speed-adjust clamp 0.25x–4x). `Resequencer` service. `Clip.copyWith()` + `ClipPart.speed`. |
| **S14** Content-Aware Match | ✅ Selesai | PRD `PRD-SPRINT-14-CONTENT-AWARE-MATCHING.md`. Vision API (`visionPrompt` — Gemini inline_data + OpenAI image_url + Custom, Groq/Server → UnsupportedError) + frame extraction per shot (`extractFrame`) + `ContentMatcherService` (describeFrames/extractTopics/matchContent, JSON parse + fallback sequential) + `Resequencer.buildParts(matchOrder)` + `AppState.contentAwareResequence()` pipeline (multi-stage fallback ke S13) + AudioPanel MATCH CONTENT button. |
| **S15** ASR & Matching Fixes |  Draft | PRD `PRD-SPRINT-15-ASR-MATCHING-FIXES.md`. Bug fixes: ASR silent failure (throw + retry 502/503), base64 newline bug (Gemini 400), transcript persist (Drift v4), ClipPart.speed persist, visual-only matching fallback (tanpa transcript), audio chunking >20MB, error display di upload screen. |
| **S16** Semantic Matching |  Draft | PRD `PRD-SPRINT-16-SEMANTIC-MATCHING.md`. Redesign: LLM semantic segmentation (1 call, N segments = shot count) menggantikan timing-based cut + per-segment extractTopics. API calls 2N+1 → N+2. TranscriptSegment model. Fallback ke S13 timing. Gemini timestamp warning. |
| **S07** UI Fidelity | ⏸️ Belum | `design/DESIGN-SPEC.md` + 8 design screen reference ada. Belum ada alignment work. |
| **Gate G1** | ⏸️ Belum | Validasi Windows 11 belum dijalankan. |

Catatan: 180 test pass, `flutter analyze lib` → 0. S06 dan S05 sudah done di kode meskipun sebelumnya ditandai "Belum" — docs tertinggal. Gate G1 (validasi Windows 11) **belum dijalankan** — tetap wajib sebelum publikasi.

---

## 4. Urutan Eksekusi

### Step 1 — S08: Export nyata ✅ DONE
`ExportModal` menerima `projectId`+`clipId`; panggil `AppState.exportClip(formats, outputDir, onProgress)`; progress FFmpeg nyata; path via `path_provider`; success → path + "Buka folder"; opsi unsupported di-disable.

### Step 2 — S09: Pro Timeline Editor ✅ DONE
`ProTimeline` terintegrasi; menggantikan `NeoBrutalTimeline`. Timeline lama (`timeline.dart`) tetap dipakai untuk B-roll placeholder.

### Step 3 — S10: Audio Track Management ✅ DONE
Phase 1 (bounded, no AI): upload/extract/mute/replace audio, sync preview, export mixing, `ClipSegmentPlanner` hook. Phase 2 (audio-context) dilanjutkan via S14.

### Step 4 — Gate G1: MVP lokal ⏸️ BELUM
Checklist sebelum masuk Phase 2:
- [ ] Manual test Linux: upload MP4 asli 1–5 menit → kandidat clip → trim → export 9:16 & 1:1.
- [ ] Manual test Linux: S10 — upload audio → replace → preview → export dengan audio pengganti.
- [ ] Manual test Linux: S14 — transcribe → match content → export → visual relevant dengan audio topic.
- [ ] Manual test Windows 11 (fvp + ffmpeg di PATH atau env override `VISARY_FFMPEG*`).
- [ ] Restart app → project, clip, asset (termasuk audio) masih ada.
- [ ] Hapus project → folder workspace terhapus.
- [ ] SLA PRD V2 §5: probe ≤500 ms, analisis video 1 menit ≤10 s, render clip 30–60 s ≤45 s/format.
- [ ] Tidak ada unhandled exception saat ffmpeg hilang / file korup.

### Step 5 — S06: BYOK & Hybrid AI Routing ✅ DONE
`AiProviderService`, `SecureKeyStorage`, settings screen UI, BYOK state di AppState. Router: BYOK aktif → provider endpoint; BYOK off → fallback `LocalAnalyzer` / simulasi server.

### Step 6 — S05: AI B-Roll Suggestion ✅ DONE
`AiService.detectAndEnrichGaps` memakai `AiProviderService` dari S06. `LocalAnalyzer.detectVisualGaps` deteksi gap (segmen >4s narasi kuat + visual statis) → kirim ke LLM untuk keyword B-roll. Fallback heuristik bila BYOK off. Timeline placeholder + `renderWithBroll` overlay. **Gap:** `renderWithBroll` belum terima `audioMode` — B-roll + audio replacement belum terintegrasi di export.

### Step 7 — S07: UI Design Fidelity ⏸️ BELUM
Alignment 10 layar ke `design/DESIGN-SPEC.md`. Independen dari logika; branch terpisah, merge setelah stabil.

### Step 8 — S11 Remaining (TTS + hook-scoring + Gemini inline-audio + chunking) ⏸️ BELUM
TTS voiceover, hook-scoring word enrichment, Gemini inline-audio base64 → text, audio chunking untuk file panjang.

---

## 5. Estimasi

| Step | Sprint | Estimasi | Status |
|------|--------|----------|--------|
| 1 | S08 export | — | ✅ done |
| 2 | S09 timeline | — | ✅ done |
| 3 | S10 audio (Phase 1) | — | ✅ done |
| 4 | Gate G1 | 1 hari (+ akses mesin Windows) | ⏸️ belum |
| 5 | S06 BYOK | — | ✅ done |
| 6 | S05 AI B-Roll | — | ✅ done |
| 7 | S07 UI fidelity | 4–6 hari | ⏸️ belum |
| 8 | S11 remaining (TTS + hook-scoring + Gemini inline + chunking) | 3–5 hari | ⏸️ belum |

Critical path tersisa: Step 4 (G1) → Step 7 (S07) + Step 8 (S11 remaining) paralel ≈ 5–7 hari kerja.

---

## 6. Risiko

| Risiko | Dampak | Mitigasi |
|--------|--------|----------|
| Windows belum pernah dites (fvp/libmdk, path ffmpeg) | Tinggi — target platform utama | Wajib di Gate G1; bundel `ffmpeg.exe` di samping exe + env override |
| Render lambat tanpa GPU encoder | Sedang | Preset `veryfast`; deteksi NVENC/QSV/AMF dijadwalkan setelah G1 |
| `renderWithBroll` belum terima `audioMode` | Rendah | B-roll + audio replacement belum terintegrasi; fix saat dibutuhkan |
| Gemini rate limit (free tier 15 RPM) | Sedang | Sequential processing, delay antar request (S14) |
| S11 TTS belum diimplementasi | Sedang | Voiceover deferred; app tetap jalan tanpa TTS |
| S07 alignment bisa konflik dengan S11/S14 changes | Rendah | Branch terpisah; merge setelah S11 remaining stabil |

---

## 7. Definition of Done (per sprint)

- `flutter analyze lib` → 0 error/warning/info.
- `flutter test` hijau, termasuk test baru untuk task sprint tersebut.
- Tidak ada nilai dummy/hardcoded baru di `lib/`.
- Smoke test manual alur utama di Linux; juga di Windows untuk sprint yang menyentuh platform/IO.
- Status sprint di §3 diperbarui dengan bukti (file/test).
