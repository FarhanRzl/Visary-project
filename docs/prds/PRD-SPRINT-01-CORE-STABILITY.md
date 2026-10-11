# PRD Sprint 01 — Core App Stability, Error Handling & Linter Fixes

**Dokumen ID:** PRD-SPRINT-01  
**Modul Fokus:** App Inisialisasi, Error Boundary, Code Quality, Core Unit Tests  
**Target File:** `lib/main.dart`, `lib/screens/upload_screen.dart`, `test/unit/`  
**Issue Terkait:** ISS-01, ISS-02, ISS-07  

---

## 1. Latar Belakang & Masalah
* **ISS-01 (Blocker):** Pemanggilan `fvp.registerWith(...)` di `lib/main.dart` dieksekusi sebelum framework Flutter menginisialisasi engine bindings (`WidgetsFlutterBinding.ensureInitialized()`). Pada runtime desktop Windows/Linux, ini menyebabkan `NullThrownError` atau fatal application crash saat pertama kali dibuka.
* **ISS-02 (High):** Operasi upload dan probing di `UploadScreen` tidak membungkus fungsi `state.addProjectFromUpload(...)` dalam blok `try-catch`. Ketika binary FFmpeg/FFprobe tidak terdeteksi di OS, aplikasi mengalami *silent failure* dengan state UI menggantung di loading progress.
* **ISS-07 (Linter):** Terdapat 21 warning linter (deprecated API `withOpacity` vs `withValues`, `activeColor` vs `activeThumbColor`, dan dead code `_timelineBlock` / `_dragging`).

---

## 2. Sasaran Perbaikan (Scope of Work)
1. **Binding Initialization:** Memastikan `WidgetsFlutterBinding.ensureInitialized()` dipanggil paling awal sebelum native plugin registrasi.
2. **Error Boundary & Feedback Dialog:** Menambahkan penanganan `FfmpegMissingException` dan `FileSystemException` pada `UploadScreen`, menampilkan dialog peringatan Neo-Brutalist yang jelas ke pengguna jika tooling eksternal belum siap.
3. **Pembersihan Linter 100%:** Memperbarui semua sintaks deprecated ke Flutter SDK terkini dan menghapus deklarasi yang tidak terpakai sehingga hasil `flutter analyze` bersih (0 issues).
4. **Core Automation Test Suite:** Menyediakan unit test dasar untuk memvalidasi parser probing dan exception handling.

---

## 3. Spesifikasi Teknis Perbaikan

### 3.0 Tools & Library Referensi
* **[`media_kit/media_kit`](https://github.com/media-kit/media-kit):** Video player engine alternatif berbasis libmpv jika `fvp` bermasalah di native desktop bindings.
* **[`flutter/samples - errortrap`](https://github.com/flutter/samples):** Blueprint error catching global `PlatformDispatcher.instance.onError`.

### 3.1 `lib/main.dart`
```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  fvp.registerWith(options: {
    'platforms': ['linux', 'windows', 'macos']
  });
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const VisaryApp(),
    ),
  );
}
```

### 3.2 `lib/screens/upload_screen.dart`
Bungkus `_startUploadProcess` dengan error handler:
* Tampilkan dialog modal jika `FfmpegMissingException` terjadi.
* Reset state `_processing = false` saat error tertangkap.

### 3.3 Pembersihan Linter
* Ganti `.withOpacity(val)` menjadi `.withValues(alpha: val)`.
* Ganti `activeColor: ...` pada `Switch` menjadi `activeThumbColor: ...`.
* Hapus variabel privat `_dragging` yang tidak terpakai di `UploadScreen`.
* Hapus fungsi `_timelineBlock` yang tidak terpakai di `ClipEditorScreen`.

---

## 4. Rencana Automation Testing
* **Test 1.1:** `test/unit/services/video_service_test.dart`
  * Validasi `VideoService.isAvailable()` saat binary terpasang vs tidak terpasang.
  * Validasi lemparan `FfmpegMissingException` saat path executable tidak valid.
* **Test 1.2:** `test/unit/services/local_analyzer_test.dart`
  * Validasi parsing `VideoProbe` dengan mock data JSON.
* **Test 1.3:** CI Linter Check: `flutter analyze` exit code 0.

---

## 5. Kriteria Penerimaan (Acceptance Criteria)
* Aplikasi dapat dibuka di desktop tanpa crash inisialisasi binding.
* Jika FFmpeg diubah ke binary palsu, UI menampilkan dialog peringatan informatif, bukan stuck loading.
* Perintah `flutter analyze` menghasilkan 0 error dan 0 warning.
* Unit test Sprint 01 lulus 100%.
