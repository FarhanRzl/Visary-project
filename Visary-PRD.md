# Visary — PRD (Product Requirements Document)

Versi: 1.0 (draft MVP)
Tanggal: 7 Oktober 2026
Platform: Windows 11 (Flutter desktop)
Status: Draft, menunggu review

---

## 1. Ringkasan

Visary adalah aplikasi desktop Windows untuk content creator short-form. User upload video, lalu Visary menganalisis narasi (audio) dan konteks visual, kemudian menghasilkan clip siap upload untuk TikTok, Instagram Reels, YouTube Shorts, Facebook Reels, dan RedNote.

Konsep diadaptasi dari fitur ClipAnything milik Opus Clip (clipping berbasis analisis multimodal + prompt bahasa natural), digabung dengan 4 modul:

1. Hook Finder: deteksi momen paling kuat sebagai pembuka clip.
2. Clip Generator (repurposing): beberapa clip hook-first, durasi ≥30 detik.
3. Multi-format Export: reframe otomatis + caption burn-in.
4. Asset Library: ekstraksi hook, B-roll, sound bite, teks overlay.

Plus Mode Prompt: user mengetik instruksi ("ambil bagian yang bahas harga"), Visary mencari momen yang relevan.

---

## 2. Keputusan yang sudah dikunci

| Topik | Keputusan |
|---|---|
| Target user | Content creator short-form |
| Platform | Windows 11 |
| Input MVP | Upload file lokal (input link ditunda) |
| Durasi input | Tidak dibatasi (bawah maupun atas) |
| Durasi output | Minimal 30 detik per clip final, tanpa batas atas |
| Visual analysis | Masuk MVP |
| Mode prompt | Masuk MVP |
| Arsitektur | Hybrid: pemrosesan berat lokal, AI (VLM/LLM) lewat backend server sendiri |
| Cloud provider | Backend server milik sendiri (bukan API key milik user) |

---

## 3. Aturan durasi (konsekuensi "tanpa batas")

Karena input tidak dibatasi tapi output minimal 30 detik, perilaku sistem ditentukan per kasus:

| Durasi input | Perilaku |
|---|---|
| < 30 detik | Tidak bisa membuat clip ≥30 detik. Output = 1 versi full video (reframe + caption + hook dipindah ke depan bila valid). Clip boleh <30 detik dengan label "di bawah minimum". User diberi warning. |
| 30–60 detik | 1–2 varian (re-sequence hook-first / versi asli yang dioptimasi). Overlap diperbolehkan. |
| 1–3 menit | 2–5 clip, overlap maksimal 50%. |
| > 3 menit (long-form) | 3–10+ clip. Analisis wajib chunked (lihat 7.4). Waktu proses dan biaya naik linear, user diberi estimasi sebelum mulai. |

Catatan:
- Aturan ≥30 detik hanya untuk clip final. Aset di Asset Library (hook 2–5 detik, B-roll, sound bite) dikecualikan.
- Tanpa batas atas output, tetapi default rekomendasi 30–90 detik (sweet spot short-form). User bisa mengubah target durasi di setting job.
- Batas praktis tetap ada: ruang disk dan RAM. Validasi dilakukan sebelum proses (cek free disk ≥ 3x ukuran video).

---

## 4. Fitur MVP

### 4.1 Upload & Project
- Drag-drop / file picker: MP4, MOV, MKV, WebM, AVI.
- Probe via FFprobe: durasi, resolusi, aspect ratio, fps, codec, ada audio atau tidak.
- 1 video = 1 project. Riwayat project tersimpan lokal (SQLite).
- Hasil analisis di-cache, jadi re-generate clip tidak perlu analisis ulang.

### 4.2 Analisis multimodal
Output: satu timeline ber-timestamp yang menggabungkan semua sinyal.

Audio (lokal):
- ASR faster-whisper dengan timestamp per kata. Bahasa: Indonesia, Inggris, campuran (auto-detect).
- Voice activity detection: bagian ucapan vs musik vs hening.
- Puncak loudness/energi.

Visual (lokal):
- Shot detection (PySceneDetect).
- Keyframe per shot (+ sampling tambahan tiap 2 detik untuk shot panjang).
- OCR teks overlay (PaddleOCR) — penting karena banyak short video tanpa narasi.
- Face/subject detection + tracking (MediaPipe / YOLO-nano) untuk reframe.

Semantik (server → VLM/LLM):
- Deskripsi tiap shot: aksi, objek, emosi, setting.
- Penandaan struktur: hook / setup / isi / klimaks / CTA.
- Skor per segmen.

### 4.3 Hook Finder
- Kandidat hook: segmen 2–5 detik dengan pertanyaan retoris, pernyataan mengejutkan, emosi kuat, perubahan visual tajam, teks overlay mencolok, puncak energi audio.
- Skor hook 0–100 + alasan (teks).
- Hook dipakai sebagai pembuka clip, juga disimpan ke Asset Library.

### 4.4 Clip Generator
- Kandidat clip disusun LLM: start, end, posisi hook, urutan segmen, judul, alasan, skor viralitas.
- Dua tipe clip:
  - Linear: potongan berurutan dari video asli.
  - Re-sequenced: hook dipindah ke depan, lalu sisa segmen berurutan.
- Validasi di kode (bukan oleh LLM):
  - Durasi ≥30 detik (kecuali kasus input <30 detik).
  - Titik potong snap ke batas kalimat (timestamp kata ASR) dan batas shot.
  - Tidak ada kalimat terpotong di tengah.
  - Re-sequence hanya jika LLM menandai narasi tetap koheren.
- Hasil ditampilkan sebagai kartu: preview, skor, durasi, alasan.

### 4.5 Mode Prompt (ClipAnything)
- Input teks bebas, contoh:
  - "Ambil momen paling lucu"
  - "Bagian yang menjelaskan cara pakai produk"
  - "Semua momen ada kucing"
- Pencarian: embedding lokal (multilingual) atas timeline → kandidat segmen → LLM di server memilih dan menyusun clip.
- Prompt bisa dikombinasi dengan target durasi dan jumlah clip.
- Jika tidak ada momen relevan: tampilkan "tidak ditemukan" + momen paling mendekati, bukan memaksa hasil.

### 4.6 Multi-format Export
- MVP: 9:16 dan 1:1. (4:5 dan 16:9 di fase 2.)
- Reframe:
  - Crop dinamis mengikuti subjek/wajah (smoothing agar kamera tidak goyang).
  - Fallback: blur-pad background bila subjek tidak terdeteksi atau ada 2 subjek berjauhan.
- Caption otomatis:
  - Burn-in, gaya word-by-word highlight (gaya short-form populer).
  - 2–3 preset style MVP (font, warna, posisi).
  - Hindari menimpa teks overlay asli (posisi dari OCR).
- Encode: H.264 + AAC, 1080x1920 / 1080x1080, 30/60 fps. Hardware encoder (NVENC / QSV / AMF) jika tersedia, fallback x264.
- Export juga file .srt terpisah.

### 4.7 Asset Library
- Ekstraksi otomatis: hook, B-roll (shot tanpa ucapan), sound bite (kalimat kuat), teks overlay (hasil OCR).
- MVP: list per project + preview + export file. Library lintas project → fase 2.

### 4.8 Editor manual
- Player (media_kit) + timeline: waveform, thumbnail shot, transkrip.
- Geser start/end clip (snap ke kata/shot), tukar hook, hapus segmen.
- Edit teks caption (koreksi salah ASR).
- Pilih format dan style caption.
- Preview sebelum render (preview ringan, bukan render final).

### 4.9 Akun & kuota
Karena AI berjalan di server sendiri:
- Login (email + password / Google). Token disimpan di Windows Credential Manager.
- Kuota menit video per akun (free / berbayar), ditampilkan di app.
- Estimasi kuota terpakai ditampilkan sebelum job dimulai.

---

## 5. Di luar MVP (fase berikutnya)

Fase 2:
- Format 4:5 dan 16:9.
- Asset Library lintas project.
- Template caption kustom + animasi.
- Saran judul, deskripsi, hashtag per platform.
- Batch processing.
- Mode offline penuh (VLM lokal Moondream/SmolVLM).

Fase 3:
- Input link (TikTok/IG/YouTube/FB/RedNote) — butuh kajian ToS & legal.
- Direct publish ke platform via API resmi.
- macOS.
- B-roll dari stock, efek, musik.

---

## 6. Arsitektur sistem

```
┌──────────────────── PC user (Windows 11) ────────────────────┐
│                                                              │
│  Flutter app (UI)                                            │
│   - media_kit player, timeline editor, project list          │
│   - Drift (SQLite) untuk project/clip/asset                  │
│        │  HTTP + WebSocket (127.0.0.1)                        │
│        ▼                                                     │
│  Local engine (Python sidecar, FastAPI, PyInstaller .exe)    │
│   - FFmpeg: probe, extract, cut, reframe, encode             │
│   - faster-whisper (ASR), PaddleOCR, PySceneDetect,          │
│     MediaPipe, embedding multilingual                         │
│   - Job runner + progress + cancel                           │
│        │  HTTPS (JSON + keyframe JPEG terkompresi)            │
└────────┼─────────────────────────────────────────────────────┘
         ▼
┌──────────────────── Backend server Visary ───────────────────┐
│  API gateway (FastAPI)                                       │
│   - Auth (JWT), kuota, rate limit, metering                  │
│   - AI orchestrator: prompt template, validasi JSON output   │
│  Worker (arq/Celery) + Redis                                 │
│  PostgreSQL: user, kuota, usage log, job metadata            │
│  Object storage (R2/S3): keyframe sementara (TTL 24 jam)     │
│        │                                                     │
│        ▼                                                     │
│  Provider AI: Gemini Flash (utama), fallback GPT-4o-mini     │
└──────────────────────────────────────────────────────────────┘
```

Prinsip:
- Video mentah TIDAK di-upload ke server. Yang dikirim hanya keyframe (JPEG kecil), transkrip, dan teks OCR. Ini menekan biaya bandwidth/storage dan menjaga privasi.
- API key provider AI hanya ada di server, tidak pernah di aplikasi.
- Server stateless terhadap konten: data AI disimpan sementara, dihapus otomatis.
- Render selalu lokal, jadi server tidak butuh GPU.

---

## 7. Pipeline detail

### 7.1 Tahapan job
1. Probe & normalisasi (FFmpeg): audio 16 kHz mono, proxy video 480p untuk analisis.
2. ASR + VAD (paralel dengan langkah 3).
3. Shot detection → keyframe → OCR → face tracking.
4. Bangun timeline lokal (JSON).
5. Kirim ke server: timeline + keyframe → VLM deskripsi shot → LLM struktur & skor.
6. Generate kandidat clip (otomatis atau dari prompt) di server, validasi aturan di lokal.
7. User review/edit.
8. Render lokal per format.

### 7.2 Skema timeline (ringkas)
```json
{
  "video": {"duration": 74.2, "width": 1080, "height": 1920, "fps": 30},
  "words": [{"w": "Halo", "s": 0.32, "e": 0.61, "conf": 0.94}],
  "sentences": [{"id": 1, "s": 0.32, "e": 3.10, "text": "..."}],
  "shots": [{"id": 1, "s": 0.0, "e": 2.4, "keyframe": "kf_001.jpg",
             "ocr": ["DIJAMIN KAGET"], "faces": 1,
             "desc": "...", "emotion": "surprised"}],
  "audio": {"speech": [[0.3, 20.1]], "music": [[0, 74.2]], "energy_peaks": [1.2, 33.5]},
  "segments": [{"s": 0.3, "e": 3.1, "role": "hook", "hook_score": 87}]
}
```

### 7.3 Kontrak output LLM (clip)
```json
{
  "clips": [{
    "title": "...",
    "parts": [{"s": 33.5, "e": 36.0}, {"s": 3.1, "e": 31.0}],
    "hook": {"s": 33.5, "e": 36.0},
    "duration": 30.4,
    "score": 82,
    "reason": "...",
    "type": "resequenced"
  }]
}
```
Output divalidasi dengan schema (Pydantic). Jika gagal validasi: retry 1x, lalu fallback heuristik.

### 7.4 Video panjang (tanpa batas atas)
- Analisis lokal per chunk 5 menit, hasil digabung.
- LLM map-reduce: ringkasan + kandidat per chunk → seleksi global.
- Keyframe dibatasi (misal maks 1 per 2 detik, dedup frame mirip) untuk mengontrol biaya.
- Job bisa di-resume jika aplikasi ditutup.

### 7.5 Fallback saat server tidak tersedia
- Analisis lokal tetap jalan (ASR, OCR, shot).
- Clip dihasilkan dengan skor heuristik (energi audio, batas kalimat, kata kunci, perubahan shot) + pencarian prompt via embedding lokal.
- Hasil ditandai "mode dasar".

---

## 8. Backend server (direncanakan dari nol)

### 8.1 Stack
| Komponen | Pilihan | Alasan |
|---|---|---|
| Bahasa/framework | Python 3.12 + FastAPI | Satu bahasa dengan sidecar, ekosistem AI |
| Queue | Redis + arq | Ringan, async, cukup untuk MVP |
| Database | PostgreSQL 16 | User, kuota, usage, job |
| Object storage | Cloudflare R2 | Tanpa biaya egress, S3-compatible |
| Auth | JWT + refresh token (fastapi-users) atau Supabase Auth | Cepat diimplementasi |
| AI provider | Gemini Flash (utama), OpenAI GPT-4o-mini (fallback) | Murah, mendukung gambar, output JSON |
| Deploy | Docker Compose | Sederhana untuk 1 server |
| Reverse proxy | Caddy | HTTPS otomatis |
| Monitoring | Sentry + Uptime Kuma + log terstruktur | Murah/gratis |
| Billing (fase 2) | Midtrans / Xendit (lokal) + Stripe/LemonSqueezy (global) | Pasar Indonesia |

### 8.2 Endpoint utama
```
POST /auth/register | /auth/login | /auth/refresh
GET  /me/quota
POST /jobs                      → buat job, cek & reservasi kuota
POST /jobs/{id}/keyframes       → upload keyframe (presigned URL R2)
POST /jobs/{id}/analyze         → VLM deskripsi + struktur
POST /jobs/{id}/clips           → generate clip (auto / prompt)
GET  /jobs/{id}                 → status
WS   /jobs/{id}/events          → progres
```

### 8.3 Hosting (tahap)
| Tahap | Setup | Estimasi biaya infra/bulan |
|---|---|---|
| Development | Lokal / 1 VPS kecil (2 vCPU, 4 GB) | ± $5–10 |
| Beta (≤500 user) | 1 VPS 4 vCPU 8 GB (Hetzner/DigitalOcean/Biznet) + Postgres di VPS yang sama + R2 | ± $20–50 |
| Growth | 2+ instance API di belakang load balancer, managed Postgres, Redis terpisah | ± $150–400 |

Server tidak butuh GPU karena inferensi AI dilakukan provider dan render lokal.

### 8.4 Estimasi biaya AI per video (perlu diverifikasi dengan harga provider terkini)
Asumsi video 1 menit: ±30 keyframe + transkrip + OCR, 2 call LLM.
- Input: ±10–15 ribu token, output: ±2–3 ribu token.
- Dengan model kelas Gemini Flash: kira-kira < $0.01 per menit video.
- Video panjang naik linear terhadap jumlah keyframe → dibatasi via kuota menit.

Biaya terbesar kemungkinan bukan AI, tapi waktu engineering dan support.

### 8.5 Keamanan server
- Rate limit per user dan per IP.
- Validasi ukuran/jumlah keyframe per job.
- Keyframe dihapus otomatis (TTL 24 jam).
- Prompt user disanitasi; output AI selalu divalidasi schema.
- Secret di environment / secret manager, bukan di repo.
- Log tidak menyimpan isi transkrip secara permanen.

---

## 9. Struktur project

```
Visary-project/
├── app/                      # Flutter desktop
│   └── lib/
│       ├── core/             # theme, router, DI, constants
│       ├── data/             # drift db, api clients (sidecar, server)
│       ├── domain/           # entity: Project, Clip, Asset, Timeline
│       └── features/
│           ├── auth/
│           ├── projects/
│           ├── upload/
│           ├── analysis/     # progres job
│           ├── clips/        # kartu clip, mode prompt
│           ├── editor/       # timeline, trim, caption
│           ├── assets/
│           └── export/
├── engine/                   # Python sidecar (lokal)
│   ├── api/                  # FastAPI routes, websocket
│   ├── pipeline/             # probe, asr, ocr, shots, faces, timeline
│   ├── selection/            # validasi aturan clip, heuristik fallback
│   ├── render/               # ffmpeg reframe, caption (ASS), encode
│   └── models/               # downloader + cache model
├── server/                   # Backend cloud
│   ├── app/                  # FastAPI: auth, jobs, quota, ai
│   ├── worker/               # arq tasks
│   ├── prompts/              # template prompt VLM/LLM (versioned)
│   └── docker-compose.yml
└── docs/
```

State management Flutter: Riverpod. Database lokal: Drift (SQLite).

### 9.1 Skema data lokal (ringkas)
- projects(id, name, video_path, duration, width, height, status, created_at)
- timelines(project_id, json, version, created_at)
- clips(id, project_id, title, parts_json, hook_json, duration, score, reason, type, source[auto|prompt], prompt, edited)
- caption_overrides(clip_id, word_index, text)
- assets(id, project_id, kind[hook|broll|soundbite|text], s, e, file_path)
- exports(id, clip_id, format, style, file_path, status, error)

---

## 10. Kebutuhan non-fungsional

| Item | Target |
|---|---|
| OS | Windows 11 64-bit |
| Spek minimum | CPU 4 core, RAM 8 GB, disk kosong 10 GB, internet untuk mode AI penuh |
| Rekomendasi | CPU 8 core, RAM 16 GB, GPU NVIDIA (CUDA) / encoder hardware |
| Waktu analisis | Video 1 menit ≤ 2 menit (spek minimum, mode hybrid) |
| Waktu render | Clip 30–60 detik ≤ 1 menit per format (spek minimum) |
| Installer | ≤ 400 MB; model diunduh saat first-run (±1–1.5 GB) |
| Stabilitas | Crash sidecar terdeteksi dan di-restart otomatis; job bisa di-resume |
| Privasi | Video tidak meninggalkan perangkat; data AI di server dihapus ≤24 jam |
| Bahasa UI | Bahasa Indonesia (Inggris fase 2) |

---

## 11. Risiko

| Risiko | Mitigasi |
|---|---|
| Akurasi ASR bahasa Indonesia/campuran dan slang | Uji model small vs medium, editor caption wajib ada |
| Video tanpa narasi (musik + teks) | OCR + VLM sebagai sinyal utama |
| Re-sequence merusak alur cerita | Validasi koherensi oleh LLM + snap kalimat + default linear |
| Hak cipta video milik orang lain | Disclaimer + ToS: user bertanggung jawab atas hak konten |
| Penyalahgunaan kuota/biaya AI | Auth, kuota menit, rate limit, batas keyframe |
| Ukuran & kompleksitas packaging Python | PyInstaller onedir, model on-demand, uji di Windows bersih |
| Antivirus false positive (exe PyInstaller) | Code signing certificate |
| Lisensi FFmpeg | Pakai build LGPL, link dinamis, sertakan notice |
| Ketergantungan 1 provider AI | Abstraksi provider di server + fallback model kedua |

---

## 12. Metrik keberhasilan MVP

- ≥70% clip auto-generated diekspor tanpa edit besar (indikator kualitas).
- Waktu dari upload sampai clip pertama siap < 5 menit (video 1 menit, spek minimum).
- Render success rate ≥98%.
- Akurasi kata caption (WER) ≤15% untuk konten bahasa Indonesia bersih.
- Retensi 7 hari ≥30% di beta.

---

## 13. Milestone (usulan)

| Sprint | Fokus |
|---|---|
| 0 (1 minggu) | Spike: faster-whisper ID, PaddleOCR, PySceneDetect, FFmpeg reframe di Windows; uji Gemini dengan 10 sample video |
| 1–2 | Sidecar engine: probe, ASR, shots, OCR, timeline; Flutter: upload + project list |
| 3–4 | Server: auth, kuota, endpoint analyze/clips; integrasi app ↔ server |
| 5–6 | Clip generator + mode prompt + kartu hasil |
| 7–8 | Render: reframe, caption burn-in, export; editor manual |
| 9 | Asset library, fallback mode dasar, error handling |
| 10 | Packaging installer, code signing, beta tertutup |

---

## 14. Pertanyaan terbuka

1. Model bisnis: freemium kuota menit? Berapa menit gratis per bulan?
2. Login wajib sejak awal, atau boleh mode dasar tanpa akun?
3. Gaya caption default: perlu referensi visual (contoh akun/video acuan)?
4. Bahasa konten prioritas selain Indonesia/Inggris (Mandarin untuk RedNote)?
5. Target jumlah user beta dan timeline rilis?
