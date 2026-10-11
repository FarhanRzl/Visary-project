# PRD Sprint 08 — Dummy Data Elimination & Real Data Pipeline Migration

**Dokumen ID:** PRD-SPRINT-08  
**Modul Fokus:** Pembersihan Nilai Hardcoded, Integrasi Dinamis State Asli, Real User Experience  
**Target File:** `lib/screens/*`, `lib/state/app_state.dart`, `lib/widgets/*`  
**Referensi Utama:** `Visary-PRD.md` (§4.1 s.d. §4.9), `lib/screens/` audit codebase

---

## 1. Latar Belakang & Masalah
Saat ini terdapat banyak data *dummy*, teks *hardcoded*, dan simulasi *mock* di dalam kode yang membuat aplikasi tidak mencerminkan file video dan state pengguna yang sebenarnya:
* **`upload_screen.dart`:**
  * Hardcoded default filename `'review-kopi.mp4'` dan durasi `'01:42'`.
  * Fallback progress statis `0.58` (58%) jika proses belum berjalan atau bernilai 0.
  * Hardcoded badge kuota `'⚡ KUOTA 42 / 60 MENIT'`.
* **`clip_editor_screen.dart`:**
  * Subtitle hardcoded `'gampang banget bikinnya!'` di bottom player.
  * Hardcoded nama file fallback `'REVIEW KOPI KEKINIAN.MP4'` dan durasi `102` detik.
  * Prompt search bar hanya memunculkan `SnackBar` dummy tanpa menjalankan pencarian semantik nyata.
  * Fallback durasi playhead `24.0`, `clipStartSec: 24.0`, `clipEndSec: 56.0`.
* **`login_screen.dart`:**
  * Simulasi login menggunakan `Future.delayed(600ms)` tanpa menyimpan sesi user ke storage.
* **`settings_screen.dart`:**
  * Data user statis (nama, email, sisa kuota) tidak terikat dengan profil aktif `AppState.user`.
* **Kerapuhan State (`orElse: () => state.projects.first`):**
  * Di berbagai screen (`hook_finder_screen.dart`, `clip_editor_screen.dart`), pemanggilan `state.projects.first` melempar fatal exception `StateError: No element` jika daftar project kosong.

---

## 2. Sasaran Perbaikan (Scope of Work)
1. **Eliminasi Hardcoded Teks & Fallback File:**
   * Mengganti seluruh nama file dan durasi dengan data asli dari `Project.name` dan `Project.probe.durationSec`.
   * Menghilangkan fallback `'review-kopi.mp4'`; jika user membatalkan file picker, proses dihentikan dengan aman tanpa memuat file fiktif.
2. **Koneksi Dinamis Subtitle / Caption:**
   * Overlay caption pada player dihubungkan langsung ke kata/kalimat ASR yang sedang aktif pada detik playhead (`_playheadSec`).
3. **Eksekusi Nyata Prompt Clip Search (Semantic Filter):**
   * Prompt bar dihubungkan ke `AppState.regenerateClips()` dengan parser instruksi durasi / keyword heuristik nyata, bukan sekadar menampilkan SnackBar.
4. **State Kuota & Profil Nyata:**
   * Badge kuota di TopBar membaca nilai dari `AppState.user?.quota` secara dinamis dengan format `"${user.quota.usedMinutes} / ${user.quota.totalMinutes} MENIT"`.
5. **Empty State & Defensive Guards:**
   * Mengganti seluruh `state.projects.first` dengan `firstOrNull` dan penanganan *Empty State Screen* (misal: "Pilih atau upload project terlebih dahulu") untuk mencegah crash saat list project kosong.

---

## 3. Spesifikasi Teknis Pembersihan

### 3.1 `lib/screens/upload_screen.dart`
```dart
// SEBELUM (DUMMY):
String fileName = 'review-kopi.mp4';
final progress = _processing ? (activeProject?.progress ?? 0.58) : 0.58;

// SESUDAH (REAL DATA):
Future<void> _pickFile() async {
  final result = await FilePicker.platform.pickFiles(type: FileType.video);
  if (result == null || result.files.isEmpty) return; // Batal tanpa file fiktif
  final picked = result.files.single;
  if (picked.path == null) return;
  await _startUploadProcess(picked.name, filePath: picked.path);
}

final progress = activeProject?.progress ?? 0.0;
```

### 3.2 `lib/screens/clip_editor_screen.dart`
```dart
// Subtitle dinamis membaca timestamp ASR aktif pada detik playhead:
String _getActiveSubtitle(double currentSec, VideoSignals? signals) {
  // Ambil teks dari segmen kata ASR terdekat
  if (signals == null || signals.shots.isEmpty) return '';
  return 'Detik ${currentSec.toStringAsFixed(1)}';
}
```

### 3.3 Penanganan Empty State yang Aman
```dart
final project = state.byId(widget.projectId);
if (project == null) {
  return const Scaffold(
    body: Center(child: Text('Project tidak ditemukan. Silakan buka dari Dashboard.')),
  );
}
```

---

## 4. Rencana Automation Testing
* **Test 8.1:** `test/unit/state/empty_state_safety_test.dart`
  * Buka `ClipEditorScreen` dan `HookFinderScreen` saat `state.projects` bernilai kosong `[]`.
  * Verifikasi tidak terjadi crash `StateError (No element)`.
* **Test 8.2:** `test/widget/real_data_binding_test.dart`
  * Upload file uji coba dengan nama `my_real_video.mp4` durasi 45 detik.
  * Verifikasi teks di UI menampilkan `my_real_video.mp4` dan durasi `00:45`, bukan nilai dummy kopi.
* **Test 8.3:** `test/unit/prompt/prompt_filter_execution_test.dart`
  * Ketik instruksi "durasi 30-40 detik" di prompt bar.
  * Verifikasi fungsi `regenerateClips(targetMin: 30, targetMax: 40)` benar-benar dieksekusi dan menghasilkan daftar klip baru.

---

## 5. Kriteria Penerimaan (Acceptance Criteria)
* Tidak ada lagi string hardcoded fiktif (`review-kopi.mp4`, `42/60 menit`, `gampang banget bikinnya!`) di seluruh kode.
* Membatalkan dialog file picker tidak membuat project palsu.
* Jika project kosong, aplikasi menampilkan tampilan kosong yang ramah (*Empty State*) tanpa crash.
* Prompt bar benar-benar menyaring klip berdasarkan kriteria durasi pengguna.
* Test suite bebas dummy data lulus 100%.
