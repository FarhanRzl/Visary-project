# Visary — Design Specification (Neo-Brutalism)

**Version**: 1.0 | **Last updated**: 2026-10-08

---

## Overview

Visary adalah desktop app (Windows 11, Flutter) untuk content creator short-form yang mengubah video panjang menjadi clip viral. Desain mengadopsi tema **neo-brutalism** dengan border tebal, shadow hard-edge, palet warna saturasi tinggi, dan tipografi display-heavy.

---

## Color Palette

| Variable | Value | Use |
|----------|-------|-----|
| `$bg` | #FFF4E0 | Screen background (krem) |
| `$paper` | #FFFFFF | Card/modal background |
| `$ink` | #111111 | Primary text, borders, icons |
| `$yellow` | #FFD23F | Primary CTA, active state |
| `$pink` | #FF6B9D | Accent, alternative action |
| `$blue` | #3A86FF | Info, feature highlight |
| `$green` | #06D6A0 | Success, quota, positive state |
| `$muted` | #8B8680 | Placeholder, hint text, secondary |

---

## Typography

| Role | Font | Size | Weight | Use |
|------|------|------|--------|-----|
| **Display** | Archivo Black | 22–30 | 900 | Heading, logo, modal title |
| **Body** | Space Grotesk | 13–15 | 400–700 | Form label, description, body text |
| **Mono** | JetBrains Mono | 10–13 | 400–700 | Timecode, data, badge, quota |

---

## Neo-Brutalism Rules

1. **Borders**: Solid 2–3px tebal, stroke `$ink`, siku (no border-radius)
2. **Shadow**: Outer shadow, offset 4–8px x/y, blur 0, color `#111111` (hard edge)
3. **Color**: Blok solid, saturasi tinggi, high contrast vs background
4. **Rotation**: Minor rotation (-6° to 6°) pada ikon/accent untuk dinamis
5. **Layout**: Grid visible, padding konsisten, spacing ketat (gap 8–24px)
6. **Density**: Tinggi, elemen terkemas untuk tidak membuang space
7. **Typography**: Heading besar + weight heavy, body normal-weight
8. **Interaction**: Hover = background + stroke change, no transition (instant)

---

## Components

### Button / Primary (`vsBtnP`)
- Fill: `$yellow`
- Stroke: `$ink` 2px
- Icon + label (display font, 700)
- Shadow: offset 5,5
- Padding: [12, 20]
- State: Active = current color; Disabled = opacity 0.5

### Button / Dark (`vsBtnD`)
- Fill: `$ink`
- Foreground: `$paper`
- Same structure as Primary

### Button / Outline (`vsBtnO`)
- Fill: `$paper`
- Stroke: `$ink` 3px
- Icon + label

### Input Field
- Fill: `$bg`
- Stroke: `$ink` 2px
- Padding: [12, 14]
- Placeholder: `$muted`
- Font: Body 14px

### Sidebar Item
- Fill: `$paper`
- Stroke: `$ink` 3px (right side)
- Padding: [12, 20]
- Gap: 12px (icon + text)
- Width: 200px

### Project Card
- Fill: `$paper`
- Stroke: `$ink` 2px
- Width: 320px
- Shadow: offset 6,6
- Child Thumb: 180px height, stroke bottom 3px

### Chip / Score / Badge
- Fill: `$yellow` / `$pink` / `$blue` / `$green`
- Stroke: `$ink` 2px
- Font: Mono 11–12px, weight 700
- Padding: [6, 10]

### Modal / Dialog
- Fill: `$paper`
- Stroke: `$ink` 3px
- Shadow: offset 8,8
- Padding: 40px
- Max width: 900px

---

## Screens (10 total)

### 1. Login
**Path**: Canvas ID `C7OG7`
- Center card layout
- Logo icon (yellow, rotated -6°)
- Email + password inputs
- "Masuk" button (primary)
- Google auth button
- "Buat akun" link at bottom
- **Status**: Complete ✓

### 2. Dashboard: Projects
**Path**: Canvas ID `enx1v`
- TopBar: Logo + Upload button (right)
- Sidebar: Projects, History, Settings nav
- Main: Grid of project cards (thumbnail, title, date, status chip)
- **Status**: Complete ✓

### 3. Upload & Analysis
**Path**: Canvas ID `GHDoN`
- TopBar: Logo + Quota badge (green)
- Dropzone: Icon + "DROP VIDEO DI SINI" + file types
- Progress panel: 5 steps (Normalisasi → ASR → OCR → VLM → LLM) dengan status icons + bar
- **Status**: Complete ✓

### 4. Clip Editor (Main)
**Path**: Canvas ID `tMv8K`
- TopBar: Back + project name + export/preview actions
- Left pane (460px): Video player (9:16, preview)
- Right pane (980px):
  - Prompt bar (search for clips via natural language)
  - Clips header + list (3 clips teaser)
  - Timeline: Ruler (0:00–1:42), tracks (SHOT/UCAPAN/CLIP), drag-trim info, snap-to-phrase button
  - Asset preview (hook, image, audio icons)
- **Status**: Complete ✓

### 5. Modal: Export
**Path**: Canvas ID `mNyq7`
- Title: "EXPORT 3 CLIP"
- Format picker: 9:16 + 1:1 (active, yellow), 4:5 + 16:9 (inactive, phase 2)
- Settings: Checkboxes for codec, audio norm, burn-in caption
- Destination folder + summary ("3 clip × 2 format = 6 file")
- Buttons: "RENDER 6 FILE" + "BATALKAN"
- **Status**: Complete ✓

### 6. Settings & Account
**Path**: Canvas ID `E1uYY2`
- TopBar: "VISARY" + close button
- Sidebar nav: AKUN (active), KUOTA & BILLING, PREFERENSI AI, GAYA CAPTION, TENTANG
- Content:
  - Account card (avatar + name + email + FREE PLAN badge)
  - Quota section (progress bar 42/60 min, reset date, upgrade button)
- **Status**: Complete ✓

### 7. Asset Library
**Path**: Canvas ID `v9yYA`
- TopBar: "ASSET LIBRARY · 12 ASSET" + search input
- Sidebar: Asset type filter (Hook, B-Roll, Sound Bite, OCR Text checkboxes) + project dropdown
- Grid: 2 rows × 3 cards per row
  - Card: Thumbnail (colored), title, metadata (video + timecode)
  - Actions: Preview + Export buttons
- **Status**: Complete ✓

---

## Layout Grid

**Base**: 1440×900 (desktop standard 16:9)

| Component | Width | Height | Padding |
|-----------|-------|--------|---------|
| TopBar | full | 90–91px | 40px vertical |
| Sidebar | 200–280px | fill | 20–28px |
| Modal | 460–900px | fit / 600px | 40px |
| Card | 300–320px | auto / 180–200px | 12–24px |
| Input | fill / 360px | 42–52px | 12–14px |

---

### 8. Hook Finder
**Path**: Canvas ID `pEUGr`
- TopBar: Project title + tabs (HOOK active, CLIP, ASSET)
- List: 5 hook candidates sorted by score
  - Score badge (0–100, color-coded: green ≥85, blue ≥70, else bg)
  - Thumbnail (play icon placeholder)
  - Quote text + reasoning ("Alasan: ...") + timestamp + signal tags
  - Actions: "JADIKAN PEMBUKA" (dark), "SIMPAN KE ASSET" (outline)
- Right panel: "SINYAL HOOK" — 6 signal types explained (pertanyaan retoris, pernyataan mengejutkan, emosi kuat, perubahan visual, teks overlay, puncak energi audio) with icon + color chip
- **Status**: Complete ✓

### 9. Caption & Reframe (Editor manual, PRD 4.6 + 4.8)
**Path**: Canvas ID `i7Nwe`
- Preview 9:16 / 1:1 toggle, box tracking wajah, caption word-highlight
- Reframe: IKUTI SUBJEK (crop dinamis) / BLUR-PAD (fallback)
- 3 preset caption (Pop Kuning, Bold Putih, Pink Box) + posisi atas/tengah/bawah
- Warning OCR: teks asli terdeteksi, caption dipindah otomatis
- Transkrip per baris, klik kata untuk koreksi salah ASR
- **Status**: Complete ✓

### 10. States: Dialogs & Errors
**Path**: Canvas ID `CBlI7`
- Konfirmasi analisis: estimasi kuota sebelum job + info privasi (video mentah tetap lokal)
- Prompt tidak menemukan momen: tampil momen paling mendekati, tidak memaksa hasil
- Server tidak terjangkau: hasil lokal tersimpan, AI tertunda, retry otomatis, opsi edit manual
- **Status**: Complete ✓

---

## Di luar MVP (sengaja belum didesain, sesuai PRD section 5)

- Format 4:5 & 16:9 (sudah tampil sebagai opsi nonaktif "fase 2" di Modal Export)
- Asset Library lintas project (ada catatan "fase 2" di Asset Library)
- Batch processing, saran judul/hashtag, template caption kustom
- Input link URL, direct publish, macOS

---

## Export Assets

All screens exported as PNG to `/Visary-project/design/`:
- `C7OG7.png` → Login
- `enx1v.png` → Dashboard
- `GHDoN.png` → Upload & Analysis
- `tMv8K.png` → Clip Editor
- `mNyq7.png` → Export Modal
- `E1uYY2.png` → Settings
- `v9yYA.png` → Asset Library
- `en5YU.png` → Design System Guide

---

## Implementation Notes

1. **Color tokens**: Use `$bg`, `$paper`, `$ink`, `$yellow`, `$pink`, `$blue`, `$green`, `$muted` as CSS custom properties or Flutter theme colors
2. **Typography**: Load Archivo Black, Space Grotesk, JetBrains Mono from Google Fonts or local
3. **Shadow**: All shadows are outer, offset 4–8px, blur 0, color `#111111` — do NOT use blur
4. **Rotation**: Apply to accent icons only (zap, upload, etc.) for -6° ≈ slight tilt
5. **Borders**: Never use borderRadius > 0; keep all corners sharp
6. **Spacing**: Use 8px base unit: gap 8/12/16/20/24/28/32, padding multiples
7. **Responsive**: No responsive breakpoints for MVP — fixed 1440×900 assumes desktop-only (Windows 11)
8. **Dark mode**: Not planned for MVP; single light theme only

---

## File References

- **PRD**: `/Visary-project/Visary-PRD.md` (417 lines, feature specs + architecture)
- **Pen.dev canvas**: `/home/farharzl/.pencil/documents/45a2bcf6-196a-4447-b706-0826f434a84e/pencil-new.pen` (live editing)
- **Assets exported**: `/Visary-project/design/*.png`

---

## Status Summary

✓ **MVP Design Complete**: All 7 primary screens designed with neo-brutalism theme  
✓ **Layout validation**: No collapsed/overflow issues in any screen  
✓ **Color & typography**: Consistent across all screens  
✓ **Ready for**: Flutter implementation (screens → Flutter widgets + state)

**Next step**: Handoff to development team for implementation. Reference pen-dev canvas for pixel-exact measurements if needed.
