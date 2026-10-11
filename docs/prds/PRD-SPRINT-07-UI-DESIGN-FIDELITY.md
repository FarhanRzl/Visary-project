# PRD Sprint 07 — Comprehensive UI/UX Design System Fidelity (Pen.dev Alignment)

**Dokumen ID:** PRD-SPRINT-07  
**Modul Fokus:** Full-App Neo-Brutalism Design Alignment & Pen.dev Canvas Compliance (10 Screens Total)  
**Target File:** `lib/theme/tokens.dart`, `lib/widgets/brutal.dart`, `lib/screens/*`, `lib/widgets/*`  
**Referensi Utama:** `design/DESIGN-SPEC.md`, Canvas `C7OG7`, `enx1v`, `GHDoN`, `tMv8K`, `mNyq7`, `E1uYY2`, `v9yYA`, `pEUGr`, `i7Nwe`, `CBlI7`

---

## 1. Latar Belakang & Masalah
Visary dirancang dengan gaya **Neo-Brutalism** khas yang ditentukan secara presisi di spesifikasi desain pen.dev (`design/DESIGN-SPEC.md`). Audit terhadap codebase Flutter saat ini menunjukkan ketidaksesuaian visual (*design drift*) di beberapa komponen dan seluruh 10 layar utama:
* Penggunaan border-radius di beberapa widget (melanggar aturan *zero border-radius* tajam).
* Perbedaan offset dan blur shadow (pen.dev mewajibkan *outer shadow, hard-edge, offset 4–8px, blur 0, color `#111111`*).
* Inkonsistensi warna token (`$bg` `#FFF4E0`, `$paper` `#FFFFFF`, `$ink` `#111111`, `$yellow` `#FFD23F`, `$pink` `#FF6B9D`, `$blue` `#3A86FF`, `$green` `#06D6A0`).
* Tidak ada rendering nyata pada thumbnail keyframe (`Image.file`) di Project Card dan Asset Card.

---

## 2. Cakupan Perbaikan Seluruh Layar (10 Screens Scope)

### 2.1 Global Token & Component System (`tokens.dart` & `brutal.dart`)
* **Neo-Brutalism Rules Enforcement:**
  * Strict solid 2–3px border stroke dengan warna `$ink` (`#111111`).
  * Hard-edge shadow tanpa blur (`blurRadius: 0`, offset 4–8px x/y, color `#111111`).
  * Zero border-radius di semua kontainer, tombol, input, dan dialog.
  * Tipografi 3-tier: Display (`Archivo Black` / heavy), Body (`Space Grotesk`), Mono (`JetBrains Mono`).

---

### 2.2 Alignment Detil per Layar (10 Screens)

#### 1. Login Screen (Canvas `C7OG7`)
* Card tengah dengan background `$paper`, shadow offset 8px, border 3px.
* Logo ikonik dengan rotasi -6° berlatar belakang `$yellow`.
* Tombol utama "MASUK" (`$yellow`), tombol OAuth "MASUK DENGAN GOOGLE" (outline).

#### 2. Dashboard Projects (Canvas `enx1v`)
* **Project Cards Grid:** Lebar kartu 320px, tinggi thumbnail 180px dengan border bottom 3px. Menampilkan gambar keyframe nyata (`project.thumbnailPath`), metadata resolusi/FPS/durasi, serta badge status & jumlah klip.
* **TopBar & Sidebar:** Proporsi lebar 200px untuk sidebar, padding 20-28px.

#### 3. Upload & Analysis (Canvas `GHDoN`)
* **Left Pane (Dropzone 60%):** Drag-and-drop zone berlatar `$paper`, ikon rotasi -6° (`$yellow`).
* **Right Pane (Analysis Panel 40%):** Checklist 5 langkah dengan ikon bulat (centang `$green` / active `$yellow`), progress bar `$pink`.

#### 4. Clip Editor Main Screen (Canvas `tMv8K`)
* **Left Pane (Video Player 420px):** Player vertical 9:16 berlatar `#181818`, overlay caption interactive box.
* **Right Pane (Editor Controls):** Prompt Bar ber-tag magenta "PROMPT", Clips List Header & Cards (score badge dinamis $\ge 90$ `$pink`, $\ge 80$ `$yellow`), Interactive Timeline.
* **Rightmost Sidebar (Asset Extraction 190px):** List aset terekstrak ber-ikon warna sesuai tipe.

#### 5. Modal Export (Canvas `mNyq7`)
* Modal dialog ber-shadow offset 8px, border 3px, max-width 900px.
* Header "EXPORT N CLIP" + pilihan format aktif (9:16, 1:1) & fase 2 (4:5, 16:9).

#### 6. Settings & Account (Canvas `E1uYY2`)
* Navigasi sidebar tab (AKUN, KUOTA, PREFERENSI AI, GAYA CAPTION).
* Progress bar kuota terpakai + tombol upgrade plan.

#### 7. Asset Library (Canvas `v9yYA`)
* **Asset Cards Grid:** Grid 2 row × 3 col. Kartu aset WAJIB memuat thumbnail snapshot visual, ikon warna khusus, serta tombol aksi "PREVIEW" & "EXPORT".

#### 8. Hook Finder (Canvas `pEUGr`)
* Daftar Kandidat Hook berdasar skor (hijau $\ge 85$, biru $\ge 70$), tombol "JADIKAN PEMBUKA" (`$ink`) dan "SIMPAN KE ASSET" (outline).

#### 9. Caption & Reframe Editor (Canvas `i7Nwe`)
* Toggle ratio 9:16 / 1:1 dengan bounding box tracking wajah/subjek.
* **Algoritma Smoothing Auto-Reframe:** Menggunakan *Exponential Moving Average* pada koordinat $(x, y)$ crop window untuk mencegah gerakan kamera patah (*jitter*) saat subjek bergerak.
* Reframe Mode: "IKUTI SUBJEK" vs "BLUR-PAD". Preset style caption & OCR warning banner.

#### 10. Dialogs, Alerts & Offline States (Canvas `CBlI7`)
* Konfirmasi Pre-Analysis, Prompt No-Match Fallback, dan Offline Modal Alert yang 100% brutalist (sudut siku, shadow offset 8px).

---

## 3. Spesifikasi Teknis Perbaikan Komponen (Contoh: `_ProjectCard`)

### 3.0 Tools & Library Referensi
* **[`material-foundation/google-fonts-flutter`](https://github.com/material-foundation/google-fonts-flutter):** Memuat font Archivo Black, Space Grotesk, dan JetBrains Mono.
* **[`SelfMadeSystem/neo_brutalism_ui`](https://github.com/SelfMadeSystem/neo_brutalism_ui):** Pola dasar border tajam, zero radius, dan hard shadow.
* **[`Steezy-code/clipper`](https://github.com/Steezy-code/clipper):** Blueprint UX review studio: Ingest video $\to$ Ranked Candidates list $\to$ Multi-format toggle $\to$ Interactive Timeline trim $\to$ Single-clip re-render.

### 3.0.1 Blueprint User Story (Visual Review & Editing Workflow)
* **User Story:** "Sebagai editor, saya ingin meninjau daftar klip ber-skor virilitas, mengubah rasio (9:16 vs 1:1), menggeser trim timeline secara instan, dan melihat preview B-roll/caption secara langsung sebelum mengekspor file final."

```dart
class _ProjectCard extends StatelessWidget {
  const _ProjectCard(this.project);
  final Project project;

  @override
  Widget build(BuildContext context) {
    final thumb = project.thumbnailPath;
    final hasThumb = thumb != null && File(thumb).existsSync();

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: VC.paper,
        border: Border.all(color: VC.ink, width: 2),
        boxShadow: const [BoxShadow(color: VC.ink, offset: Offset(6, 6), blurRadius: 0)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail Area (180px)
          Container(
            height: 180,
            width: double.infinity,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: VC.ink, width: 3)),
              color: VC.bg,
            ),
            child: hasThumb
                ? Image.file(File(thumb), fit: BoxFit.cover)
                : const Center(child: Icon(Icons.play_arrow, size: 36)),
          ),
          // Metadata
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(project.name, style: VT.body(14, weight: FontWeight.w700)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    BTag(project.stage.name.toUpperCase(), color: VC.bg),
                    const Spacer(),
                    if (project.clips.isNotEmpty) BTag('${project.clips.length} CLIPS', color: VC.yellow),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## 4. Rencana Automation Testing

* **Test 7.1:** `test/widget/theme_tokens_compliance_test.dart`
  * Verifikasi seluruh komponen utama (`BButton`, `BBox`, `BInput`, `BTag`) menggunakan `border-radius == 0` dan `boxShadow` dengan `blurRadius == 0`.
* **Test 7.2:** `test/widget/screens_golden_fidelity_test.dart`
  * Pump widget untuk masing-masing dari 10 layar utama dan verifikasi rasio, ketebalan border, font keluarga (Archivo Black, Space Grotesk), dan rendering snapshot (Image.file) sesuai spesifikasi pen.dev.

---

## 5. Kriteria Penerimaan (Acceptance Criteria)
* Ke-10 layar utama Visary (Login $\to$ Dialogs) 100% konsisten dengan desain canvas pen.dev (`DESIGN-SPEC.md`).
* Seluruh elemen UI menerapkan aturan Neo-Brutalisme.
* Thumbnail keyframe asli video berhasil dirender di kartu project dan kartu aset.
* Test suite verifikasi UI lulus 100%.
