# PRD Sprint 02 — Local Persistence Architecture & Workspace Storage Lifecycle

**Dokumen ID:** PRD-SPRINT-02  
**Modul Fokus:** Drift SQLite Persistence, Cache Garbage Collection, Workspace Management  
**Target File:** `lib/data/local/`, `lib/state/app_state.dart`, `pubspec.yaml`  
**Issue Terkait:** ISS-03, ISS-04  

---

## 1. Latar Belakang & Masalah
* **ISS-03 (High):** Setiap kali project dibuat, aplikasi membuat folder temporer di `${Directory.systemTemp.path}/visary/$projectId`. Namun saat `removeProject()` dipanggil, folder ini tidak pernah dihapus. File preview video dan thumbnail menumpuk di disk dan memicu storage leak.
* **ISS-04 (Architecture):** Seluruh data project hanya disimpan di memori RAM (`final List<Project> projects = [];`). Saat aplikasi ditutup atau komputer restart, riwayat project, daftar clip yang telah digenerate, dan setting trim hilang seluruhnya (tidak sesuai PRD §4.1 & §9.1).

---

## 2. Sasaran Perbaikan (Scope of Work)
1. **Implementasi Database Drift (SQLite):**
   * Membuat tabel skema: `ProjectsTable`, `ClipsTable`, `AssetsTable`.
   * Migrasi entitas domain `Project`, `Clip`, `AssetItem` ke model database relational.
2. **Sinkronisasi AppState & Database:**
   * Membaca daftar project tersimpan saat aplikasi dijalankan (`loadProjects()`).
   * Insert & update otomatis ketika proses analisis selesai atau klip diedit.
3. **Workspace Storage Lifecycle & Cleanup:**
   * Menambahkan pembersihan folder fisik (`Directory.delete(recursive: true)`) saat project dihapus oleh user.
   * Menambahkan mekanisme *orphan temp cleaner* saat startup untuk menghapus project sampah yang gagal diproses.

---

## 3. Spesifikasi Teknis Skema Database

### 3.0 Tools & Library Referensi
* **[`simolus3/drift`](https://github.com/simolus3/drift):** ORM SQLite resmi Flutter untuk reactive query & cascading delete.
* **[`flutter/packages/path_provider`](https://github.com/flutter/packages/tree/main/packages/path_provider):** Manajemen path OS Windows untuk direktori cache & temp storage.

### 3.1 Skema Tabel (Drift)
```sql
CREATE TABLE projects (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  file_path TEXT NOT NULL,
  duration REAL NOT NULL,
  width INTEGER NOT NULL,
  height INTEGER NOT NULL,
  fps REAL NOT NULL,
  has_audio INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  thumbnail_path TEXT
);

CREATE TABLE clips (
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  score INTEGER NOT NULL,
  reason TEXT NOT NULL,
  type TEXT NOT NULL,
  parts_json TEXT NOT NULL,
  hook_json TEXT NOT NULL,
  selected_9x16 INTEGER NOT NULL,
  selected_1x1 INTEGER NOT NULL
);

CREATE TABLE assets (
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  start_sec REAL NOT NULL,
  end_sec REAL NOT NULL
);
```

### 3.2 Pembersihan Folder Fisik (`AppState.removeProject`)
```dart
Future<void> removeProject(String id) async {
  // 1. Hapus dari database SQLite
  await _db.deleteProject(id);
  
  // 2. Hapus direktori fisik di temp storage
  try {
    final d = Directory('${Directory.systemTemp.path}/visary/$id');
    if (await d.exists()) {
      await d.delete(recursive: true);
    }
  } catch (e) {
    debugPrint('Gagal membersihkan cache project $id: $e');
  }

  // 3. Update memory state
  projects.removeWhere((p) => p.id == id);
  _signals.remove(id);
  notifyListeners();
}
```

---

## 4. Rencana Automation Testing
* **Test 2.1:** `test/integration/database_test.dart`
  * Insert project, clip, dan asset ke Drift DB.
  * Validasi query `getAllProjects()` mengembalikan relasi data dengan lengkap.
  * Uji cascading delete: Menghapus project harus otomatis menghapus clips & assets terkait.
* **Test 2.2:** `test/unit/state/storage_lifecycle_test.dart`
  * Verifikasi pembuatan direktori workspace saat project dibuat.
  * Verifikasi penghapusan direktori fisik saat `removeProject()` dipanggil.

---

## 5. Kriteria Penerimaan (Acceptance Criteria)
* Aplikasi menyimpan project dan klip secara persisten; saat aplikasi ditutup dan dibuka kembali, project tetap tampil di dashboard.
* Menghapus project melalui UI menghapus entri dari database SQLite dan menghapus folder temporernya di disk.
* Seluruh integration test storage lulus 100%.
