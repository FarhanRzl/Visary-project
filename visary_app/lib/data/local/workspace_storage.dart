import 'dart:io';

import 'package:flutter/foundation.dart';

/// Lifecycle folder kerja project di temp storage (PRD-SPRINT-02 §2.3).
///
/// Setiap project punya folder `<root>/<projectId>` untuk thumbnail dan
/// preview segmen. Folder dihapus saat project dihapus, dan folder yatim
/// (tanpa entri DB, mis. dari analisis yang gagal/crash) dibersihkan saat
/// startup.
class WorkspaceStorage {
  WorkspaceStorage({Directory? root})
      : root = root ?? Directory('${Directory.systemTemp.path}/visary');

  final Directory root;

  Directory dirOf(String projectId) =>
      Directory('${root.path}/$projectId');

  Future<Directory> ensure(String projectId) async {
    final d = dirOf(projectId);
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// Hapus folder fisik project. Error dicatat, tidak dilempar — kegagalan
  /// cleanup tidak boleh menggagalkan penghapusan project di DB.
  Future<void> delete(String projectId) async {
    try {
      final d = dirOf(projectId);
      if (await d.exists()) await d.delete(recursive: true);
    } catch (e) {
      debugPrint('Gagal membersihkan cache project $projectId: $e');
    }
  }

  /// Hapus semua folder project yang tidak ada di [knownIds].
  /// Mengembalikan daftar id yang dibersihkan.
  Future<List<String>> cleanOrphans(Set<String> knownIds) async {
    final removed = <String>[];
    if (!await root.exists()) return removed;
    await for (final e in root.list(followLinks: false)) {
      if (e is! Directory) continue;
      final id = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (knownIds.contains(id)) continue;
      try {
        await e.delete(recursive: true);
        removed.add(id);
      } catch (err) {
        debugPrint('Gagal menghapus folder yatim $id: $err');
      }
    }
    return removed;
  }
}
