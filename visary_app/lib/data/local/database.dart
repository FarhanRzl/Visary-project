import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

/// Tabel project — PRD-SPRINT-02 §3.1.
@DataClassName('ProjectRow')
class ProjectsTable extends Table {
  @override
  String get tableName => 'projects';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get filePath => text().named('file_path')();
  RealColumn get duration => real()();
  IntColumn get width => integer()();
  IntColumn get height => integer()();
  RealColumn get fps => real()();
  BoolColumn get hasAudio => boolean().named('has_audio')();
  IntColumn get createdAt => integer().named('created_at')();
  TextColumn get thumbnailPath => text().named('thumbnail_path').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tabel clip — cascading delete mengikuti project induk.
@DataClassName('ClipRow')
class ClipsTable extends Table {
  @override
  String get tableName => 'clips';

  TextColumn get id => text()();
  TextColumn get projectId => text()
      .named('project_id')
      .references(ProjectsTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  IntColumn get score => integer()();
  TextColumn get reason => text()();
  TextColumn get type => text()();
  TextColumn get partsJson => text().named('parts_json')();
  TextColumn get hookJson => text().named('hook_json')();
  BoolColumn get selected9x16 => boolean().named('selected_9x16')();
  BoolColumn get selected1x1 => boolean().named('selected_1x1')();

  /// PK komposit: id clip (c0, c1, ...) unik hanya dalam satu project,
  /// jadi id saja tidak cukup sebagai primary key antar-project.
  @override
  Set<Column> get primaryKey => {id, projectId};
}

/// Tabel asset — cascading delete mengikuti project induk.
@DataClassName('AssetRow')
class AssetsTable extends Table {
  @override
  String get tableName => 'assets';

  TextColumn get id => text()();
  TextColumn get projectId => text()
      .named('project_id')
      .references(ProjectsTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get type => text()();
  TextColumn get title => text()();
  TextColumn get sourceFile => text().named('source_file')();
  RealColumn get startSec => real().named('start_sec')();
  RealColumn get endSec => real().named('end_sec')();

  /// PK komposit: id asset (a_s0, a_b0, ...) unik hanya dalam satu project.
  @override
  Set<Column> get primaryKey => {id, projectId};
}

@DriftDatabase(tables: [ProjectsTable, ClipsTable, AssetsTable])
class VisaryDatabase extends _$VisaryDatabase {
  VisaryDatabase(super.e);

  /// DB nyata di direktori dokumen aplikasi.
  static Future<VisaryDatabase> open() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'visary.sqlite'));
    return VisaryDatabase(NativeDatabase(file));
  }

  /// DB in-memory untuk test.
  factory VisaryDatabase.memory() =>
      VisaryDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 2;

  /// Foreign key constraint harus diaktifkan eksplisit di SQLite,
  /// kalau tidak cascading delete tidak jalan.
  ///
  /// v1→v2: PK clips & assets jadi komposit {id, project_id} supaya id clip
  /// (c0, c1, ...) dan asset (a_s0, ...) tidak bentrok antar-project.
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Recreate kedua tabel dengan PK komposit. Data lama diturunkan
            // (bisa dibangun ulang dari analisis video).
            await m.deleteTable('clips');
            await m.createTable(clipsTable);
            await m.deleteTable('assets');
            await m.createTable(assetsTable);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<List<ProjectRow>> getAllProjects() => (select(projectsTable)
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .get();

  Future<List<ClipRow>> getClips(String projectId) =>
      (select(clipsTable)..where((t) => t.projectId.equals(projectId))).get();

  Future<List<AssetRow>> getAssets(String projectId) =>
      (select(assetsTable)..where((t) => t.projectId.equals(projectId))).get();

  Future<void> upsertProject(ProjectsTableCompanion row) =>
      into(projectsTable).insertOnConflictUpdate(row);

  Future<void> upsertClip(ClipsTableCompanion row) =>
      into(clipsTable).insertOnConflictUpdate(row);

  Future<void> upsertAsset(AssetsTableCompanion row) =>
      into(assetsTable).insertOnConflictUpdate(row);

  /// Ganti seluruh clip milik satu project (dipakai saat regenerate).
  /// Tidak memakai transaction sendiri — dipanggil dalam transaction save().
  Future<void> replaceClips(
      String projectId, List<ClipsTableCompanion> rows) async {
    await (delete(clipsTable)..where((t) => t.projectId.equals(projectId)))
        .go();
    for (final r in rows) {
      await into(clipsTable).insert(r);
    }
  }

  /// Ganti seluruh asset milik satu project.
  /// Tidak memakai transaction sendiri — dipanggil dalam transaction save().
  Future<void> replaceAssets(
      String projectId, List<AssetsTableCompanion> rows) async {
    await (delete(assetsTable)..where((t) => t.projectId.equals(projectId)))
        .go();
    for (final r in rows) {
      await into(assetsTable).insert(r);
    }
  }

  /// Hapus project. Clip & asset ikut terhapus lewat ON DELETE CASCADE.
  Future<void> deleteProject(String id) =>
      (delete(projectsTable)..where((t) => t.id.equals(id))).go();
}
