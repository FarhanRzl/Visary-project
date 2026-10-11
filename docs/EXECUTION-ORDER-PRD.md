# Execution Order PRD — Visary Desktop
**Dokumen ID:** PRD-EXEC-ORDER
**Status:** Aktif — basis urutan eksekusi sprint
**Referensi:** `Visary-PRD.md`, `docs/PRD_VISARY_V2.md`, `docs/prds/PRD-SPRINT-01..08`
**Basis status:** Verifikasi langsung kode `visary_app/lib` + `flutter analyze lib` + `flutter test` (2026-10-10)

---

## 1. Tujuan

Menetapkan urutan pengerjaan 8 PRD sprint berdasarkan dependency teknis dan kondisi nyata codebase, supaya:
- tidak ada sprint yang dikerjakan di atas fondasi yang belum stabil;
- pekerjaan yang sudah selesai tidak diulang;
- fitur Phase 2 (AI/backend) tidak memblokir MVP lokal.

Penomoran sprint (01–08) adalah ID dokumen, **bukan** urutan eksekusi. Urutan eksekusi ada di §4.

---

## 2. Dependency Graph

```
S01 Core Stability ──► S02 Persistence ──► S03 Analyzer/FFmpeg ──► S08 Dummy Elimination ──► S04 E2E QA
                                                                          │
                                                                          ▼
                                                     [MVP LOKAL — Gate G1]
                                                                          │
                                                       ┌──────────────────┼──────────────────┐
                                                       ▼                  ▼                  ▼
                                               S06 BYOK API ──► S05 AI B-Roll        S07 UI Fidelity
                                               (routing AI)     (butuh provider AI)  (paralel, independen)
```

| Sprint | Bergantung pada | Alasan |
|--------|-----------------|--------|
| S01 | — | Startup crash & error boundary harus beres sebelum apapun |
| S02 | S01 | Persistensi butuh app stabil saat init |
| S03 | S01 | Analyzer/render harus tahan video tanpa audio sebelum di-wire ke UI |
| S08 | S02, S03 | UI nyata butuh data tersimpan (S02) dan pipeline render aman (S03) |
| S04 | S08 | Test E2E hanya bermakna setelah UI memakai data nyata |
| S06 | G1 | Router AI butuh fallback lokal yang sudah terbukti |
| S05 | S06 | Rekomendasi B-roll butuh provider AI (BYOK atau backend) |
| S07 | G1 | Polish visual; tidak mengubah logika, aman paralel dengan S05/S06 |

Catatan: S05 bernomor lebih kecil dari S06, tapi **S06 harus jalan duluan** karena S05 memakai `AiProviderService` yang dibuat di S06.

---

## 3. Status Terverifikasi (2026-10-10)

| Sprint | Status | Bukti |
|--------|--------|-------|
| **S01** Core Stability | ✅ Selesai | `WidgetsFlutterBinding.ensureInitialized()` di awal `main()`; `UploadScreen` menangkap `FfmpegMissingException`; `flutter analyze lib` → 0 issue |
| **S02** Persistence | ✅ Selesai | `lib/data/local/{database,project_repository,workspace_storage}.dart`; `main.dart` membuka DB + `restoreSession()` + `loadProjects()`; `removeProject()` menghapus row DB + folder workspace |
| **S03** Analyzer/FFmpeg | ✅ Selesai | Analyzer aman untuk video tanpa audio; `test/unit/services/*_test.dart` lulus |
| **S04** E2E QA | ✅ Suite ada | `test/widget/`, `test/unit/state/`, `test/integration/database_test.dart` → `flutter test`: **All tests passed (23)** |
| **S08** Dummy Elimination | 🔧 ~95% | Upload→probe→scan→hooks/clips/assets nyata. **Gap:** `lib/widgets/export_dialog.dart` masih simulasi (tidak memanggil `AppState.exportClip()`), `_targetFolder` hardcoded `C:\Users\Creator\Videos\Visary` |
| **S06** BYOK | ⏸️ Belum | — |
| **S05** AI B-Roll | ⏸️ Belum | — |
| **S07** UI Fidelity | ⏸️ Belum | — |

Catatan: S04 dikerjakan sebelum S08 tuntas, jadi test untuk alur export belum ada — wajib ditambah di Step 1.

---

## 4. Urutan Eksekusi

### Step 1 — Tutup S08: Export nyata (NEXT, prioritas tertinggi)
**Target file:** `lib/widgets/export_dialog.dart`, `lib/screens/clip_editor_screen.dart`, `test/widget/`, `test/integration/`

Task:
1. `ExportModal` menerima `projectId` + `clipId` (bukan hanya `clipTitle`/`clipDuration`).
2. Ganti `_targetFolder` hardcoded → default dari `path_provider` (`getDownloadsDirectory()`), tombol "Ganti" memakai `FilePicker.platform.getDirectoryPath()` (Linux & Windows).
3. Tombol Export memanggil `AppState.exportClip(formats, outputDir, onProgress)`; progress bar dari callback ffmpeg nyata, bukan timer.
4. `FfmpegFailedException` ditampilkan di dialog; sukses menampilkan path file hasil + tombol "Buka folder".
5. Opsi yang belum didukung engine (burn-in caption, `.srt`, HW encoder) di-disable dengan label "segera" — jangan tampil seolah aktif.
6. Widget test `ExportModal` + integration test render 9:16 & 1:1 dari `assets/videos/sample.mp4` (assert resolusi & durasi via ffprobe).

Exit criteria: export dari UI menghasilkan `.mp4` valid 1080x1920 / 1080x1080; tidak ada path/nilai hardcoded di `lib/`; `flutter test` hijau.

### Step 2 — Gate G1: MVP lokal
Checklist sebelum masuk Phase 2:
- [ ] Manual test Linux: upload MP4 asli 1–5 menit → kandidat clip → trim → export 9:16 & 1:1.
- [ ] Manual test Windows 11 (fvp + ffmpeg di PATH atau env override `VISARY_FFMPEG*`).
- [ ] Restart app → project, clip, asset masih ada.
- [ ] Hapus project → folder workspace terhapus.
- [ ] SLA PRD V2 §5: probe ≤500 ms, analisis video 1 menit ≤10 s, render clip 30–60 s ≤45 s/format.
- [ ] Tidak ada unhandled exception saat ffmpeg hilang / file korup.

### Step 3 — S06: BYOK & Hybrid AI Routing
Didahulukan dari S05: membangun `AiProviderService`, penyimpanan key terenkripsi, dan router (BYOK → backend → fallback `LocalAnalyzer`). Fallback lokal yang lolos G1 menjamin app tetap jalan tanpa key.

### Step 4 — S05: AI B-Roll Suggestion
Memakai `AiProviderService` dari S06. Deteksi gap visual dari sinyal yang sudah ada (kepadatan shot rendah + energi audio tinggi) → kirim ke VLM/LLM untuk keyword B-roll.

### Step 5 — S07: UI Design Fidelity (paralel dengan Step 3–4)
Alignment 10 layar ke `design/DESIGN-SPEC.md`. Independen dari logika; kerjakan di branch terpisah, merge setelah S05/S06 stabil untuk menghindari konflik di `clip_editor_screen.dart` dan `settings_screen.dart`.

---

## 5. Estimasi

| Step | Sprint | Estimasi | Paralel? |
|------|--------|----------|----------|
| 1 | S08 sisa (export) | 1–2 hari | — |
| 2 | Gate G1 | 1 hari (+ akses mesin Windows) | — |
| 3 | S06 | 3–4 hari | dengan S07 |
| 4 | S05 | 3–5 hari | dengan S07 |
| 5 | S07 | 4–6 hari | dengan S06/S05 |

Critical path: Step 1 → 2 → 3 → 4 ≈ 8–12 hari kerja. S07 tidak menambah critical path bila paralel.

---

## 6. Risiko

| Risiko | Dampak | Mitigasi |
|--------|--------|----------|
| Windows belum pernah dites (fvp/libmdk, path ffmpeg) | Tinggi — target platform utama | Wajib di Gate G1; bundel `ffmpeg.exe` di samping exe + env override |
| Render lambat tanpa GPU encoder | Sedang | Preset `veryfast`; deteksi NVENC/QSV/AMF dijadwalkan setelah G1 |
| S05/S06 bergantung API pihak ketiga (biaya, rate limit) | Sedang | Router selalu punya fallback `LocalAnalyzer` |
| Konflik merge S07 vs S05/S06 di screen yang sama | Rendah | Branch terpisah, merge S07 terakhir |

---

## 7. Definition of Done (per sprint)

- `flutter analyze lib` → 0 error.
- `flutter test` hijau, termasuk test baru untuk task sprint tersebut.
- Tidak ada nilai dummy/hardcoded baru di `lib/`.
- Smoke test manual alur utama di Linux; juga di Windows untuk sprint yang menyentuh platform/IO.
- Status sprint di §3 diperbarui dengan bukti (file/test).
