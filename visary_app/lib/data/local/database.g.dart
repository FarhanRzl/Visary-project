// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ProjectsTableTable extends ProjectsTable
    with TableInfo<$ProjectsTableTable, ProjectRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _durationMeta =
      const VerificationMeta('duration');
  @override
  late final GeneratedColumn<double> duration = GeneratedColumn<double>(
      'duration', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
      'width', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
      'height', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _fpsMeta = const VerificationMeta('fps');
  @override
  late final GeneratedColumn<double> fps = GeneratedColumn<double>(
      'fps', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _hasAudioMeta =
      const VerificationMeta('hasAudio');
  @override
  late final GeneratedColumn<bool> hasAudio = GeneratedColumn<bool>(
      'has_audio', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("has_audio" IN (0, 1))'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _thumbnailPathMeta =
      const VerificationMeta('thumbnailPath');
  @override
  late final GeneratedColumn<String> thumbnailPath = GeneratedColumn<String>(
      'thumbnail_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _audioModeMeta =
      const VerificationMeta('audioMode');
  @override
  late final GeneratedColumn<String> audioMode = GeneratedColumn<String>(
      'audio_mode', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _activeAudioAssetIdMeta =
      const VerificationMeta('activeAudioAssetId');
  @override
  late final GeneratedColumn<String> activeAudioAssetId =
      GeneratedColumn<String>('active_audio_asset_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        filePath,
        duration,
        width,
        height,
        fps,
        hasAudio,
        createdAt,
        thumbnailPath,
        audioMode,
        activeAudioAssetId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'projects';
  @override
  VerificationContext validateIntegrity(Insertable<ProjectRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('duration')) {
      context.handle(_durationMeta,
          duration.isAcceptableOrUnknown(data['duration']!, _durationMeta));
    } else if (isInserting) {
      context.missing(_durationMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
          _widthMeta, width.isAcceptableOrUnknown(data['width']!, _widthMeta));
    } else if (isInserting) {
      context.missing(_widthMeta);
    }
    if (data.containsKey('height')) {
      context.handle(_heightMeta,
          height.isAcceptableOrUnknown(data['height']!, _heightMeta));
    } else if (isInserting) {
      context.missing(_heightMeta);
    }
    if (data.containsKey('fps')) {
      context.handle(
          _fpsMeta, fps.isAcceptableOrUnknown(data['fps']!, _fpsMeta));
    } else if (isInserting) {
      context.missing(_fpsMeta);
    }
    if (data.containsKey('has_audio')) {
      context.handle(_hasAudioMeta,
          hasAudio.isAcceptableOrUnknown(data['has_audio']!, _hasAudioMeta));
    } else if (isInserting) {
      context.missing(_hasAudioMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('thumbnail_path')) {
      context.handle(
          _thumbnailPathMeta,
          thumbnailPath.isAcceptableOrUnknown(
              data['thumbnail_path']!, _thumbnailPathMeta));
    }
    if (data.containsKey('audio_mode')) {
      context.handle(_audioModeMeta,
          audioMode.isAcceptableOrUnknown(data['audio_mode']!, _audioModeMeta));
    }
    if (data.containsKey('active_audio_asset_id')) {
      context.handle(
          _activeAudioAssetIdMeta,
          activeAudioAssetId.isAcceptableOrUnknown(
              data['active_audio_asset_id']!, _activeAudioAssetIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProjectRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path'])!,
      duration: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}duration'])!,
      width: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}width'])!,
      height: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}height'])!,
      fps: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}fps'])!,
      hasAudio: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}has_audio'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
      thumbnailPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}thumbnail_path']),
      audioMode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}audio_mode']),
      activeAudioAssetId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}active_audio_asset_id']),
    );
  }

  @override
  $ProjectsTableTable createAlias(String alias) {
    return $ProjectsTableTable(attachedDatabase, alias);
  }
}

class ProjectRow extends DataClass implements Insertable<ProjectRow> {
  final String id;
  final String name;
  final String filePath;
  final double duration;
  final int width;
  final int height;
  final double fps;
  final bool hasAudio;
  final int createdAt;
  final String? thumbnailPath;
  final String? audioMode;
  final String? activeAudioAssetId;
  const ProjectRow(
      {required this.id,
      required this.name,
      required this.filePath,
      required this.duration,
      required this.width,
      required this.height,
      required this.fps,
      required this.hasAudio,
      required this.createdAt,
      this.thumbnailPath,
      this.audioMode,
      this.activeAudioAssetId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['file_path'] = Variable<String>(filePath);
    map['duration'] = Variable<double>(duration);
    map['width'] = Variable<int>(width);
    map['height'] = Variable<int>(height);
    map['fps'] = Variable<double>(fps);
    map['has_audio'] = Variable<bool>(hasAudio);
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || thumbnailPath != null) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath);
    }
    if (!nullToAbsent || audioMode != null) {
      map['audio_mode'] = Variable<String>(audioMode);
    }
    if (!nullToAbsent || activeAudioAssetId != null) {
      map['active_audio_asset_id'] = Variable<String>(activeAudioAssetId);
    }
    return map;
  }

  ProjectsTableCompanion toCompanion(bool nullToAbsent) {
    return ProjectsTableCompanion(
      id: Value(id),
      name: Value(name),
      filePath: Value(filePath),
      duration: Value(duration),
      width: Value(width),
      height: Value(height),
      fps: Value(fps),
      hasAudio: Value(hasAudio),
      createdAt: Value(createdAt),
      thumbnailPath: thumbnailPath == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailPath),
      audioMode: audioMode == null && nullToAbsent
          ? const Value.absent()
          : Value(audioMode),
      activeAudioAssetId: activeAudioAssetId == null && nullToAbsent
          ? const Value.absent()
          : Value(activeAudioAssetId),
    );
  }

  factory ProjectRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjectRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      filePath: serializer.fromJson<String>(json['filePath']),
      duration: serializer.fromJson<double>(json['duration']),
      width: serializer.fromJson<int>(json['width']),
      height: serializer.fromJson<int>(json['height']),
      fps: serializer.fromJson<double>(json['fps']),
      hasAudio: serializer.fromJson<bool>(json['hasAudio']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      thumbnailPath: serializer.fromJson<String?>(json['thumbnailPath']),
      audioMode: serializer.fromJson<String?>(json['audioMode']),
      activeAudioAssetId:
          serializer.fromJson<String?>(json['activeAudioAssetId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'filePath': serializer.toJson<String>(filePath),
      'duration': serializer.toJson<double>(duration),
      'width': serializer.toJson<int>(width),
      'height': serializer.toJson<int>(height),
      'fps': serializer.toJson<double>(fps),
      'hasAudio': serializer.toJson<bool>(hasAudio),
      'createdAt': serializer.toJson<int>(createdAt),
      'thumbnailPath': serializer.toJson<String?>(thumbnailPath),
      'audioMode': serializer.toJson<String?>(audioMode),
      'activeAudioAssetId': serializer.toJson<String?>(activeAudioAssetId),
    };
  }

  ProjectRow copyWith(
          {String? id,
          String? name,
          String? filePath,
          double? duration,
          int? width,
          int? height,
          double? fps,
          bool? hasAudio,
          int? createdAt,
          Value<String?> thumbnailPath = const Value.absent(),
          Value<String?> audioMode = const Value.absent(),
          Value<String?> activeAudioAssetId = const Value.absent()}) =>
      ProjectRow(
        id: id ?? this.id,
        name: name ?? this.name,
        filePath: filePath ?? this.filePath,
        duration: duration ?? this.duration,
        width: width ?? this.width,
        height: height ?? this.height,
        fps: fps ?? this.fps,
        hasAudio: hasAudio ?? this.hasAudio,
        createdAt: createdAt ?? this.createdAt,
        thumbnailPath:
            thumbnailPath.present ? thumbnailPath.value : this.thumbnailPath,
        audioMode: audioMode.present ? audioMode.value : this.audioMode,
        activeAudioAssetId: activeAudioAssetId.present
            ? activeAudioAssetId.value
            : this.activeAudioAssetId,
      );
  ProjectRow copyWithCompanion(ProjectsTableCompanion data) {
    return ProjectRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      duration: data.duration.present ? data.duration.value : this.duration,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      fps: data.fps.present ? data.fps.value : this.fps,
      hasAudio: data.hasAudio.present ? data.hasAudio.value : this.hasAudio,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      thumbnailPath: data.thumbnailPath.present
          ? data.thumbnailPath.value
          : this.thumbnailPath,
      audioMode: data.audioMode.present ? data.audioMode.value : this.audioMode,
      activeAudioAssetId: data.activeAudioAssetId.present
          ? data.activeAudioAssetId.value
          : this.activeAudioAssetId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('filePath: $filePath, ')
          ..write('duration: $duration, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('fps: $fps, ')
          ..write('hasAudio: $hasAudio, ')
          ..write('createdAt: $createdAt, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('audioMode: $audioMode, ')
          ..write('activeAudioAssetId: $activeAudioAssetId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, filePath, duration, width, height,
      fps, hasAudio, createdAt, thumbnailPath, audioMode, activeAudioAssetId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.filePath == this.filePath &&
          other.duration == this.duration &&
          other.width == this.width &&
          other.height == this.height &&
          other.fps == this.fps &&
          other.hasAudio == this.hasAudio &&
          other.createdAt == this.createdAt &&
          other.thumbnailPath == this.thumbnailPath &&
          other.audioMode == this.audioMode &&
          other.activeAudioAssetId == this.activeAudioAssetId);
}

class ProjectsTableCompanion extends UpdateCompanion<ProjectRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> filePath;
  final Value<double> duration;
  final Value<int> width;
  final Value<int> height;
  final Value<double> fps;
  final Value<bool> hasAudio;
  final Value<int> createdAt;
  final Value<String?> thumbnailPath;
  final Value<String?> audioMode;
  final Value<String?> activeAudioAssetId;
  final Value<int> rowid;
  const ProjectsTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.filePath = const Value.absent(),
    this.duration = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.fps = const Value.absent(),
    this.hasAudio = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    this.audioMode = const Value.absent(),
    this.activeAudioAssetId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectsTableCompanion.insert({
    required String id,
    required String name,
    required String filePath,
    required double duration,
    required int width,
    required int height,
    required double fps,
    required bool hasAudio,
    required int createdAt,
    this.thumbnailPath = const Value.absent(),
    this.audioMode = const Value.absent(),
    this.activeAudioAssetId = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        filePath = Value(filePath),
        duration = Value(duration),
        width = Value(width),
        height = Value(height),
        fps = Value(fps),
        hasAudio = Value(hasAudio),
        createdAt = Value(createdAt);
  static Insertable<ProjectRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? filePath,
    Expression<double>? duration,
    Expression<int>? width,
    Expression<int>? height,
    Expression<double>? fps,
    Expression<bool>? hasAudio,
    Expression<int>? createdAt,
    Expression<String>? thumbnailPath,
    Expression<String>? audioMode,
    Expression<String>? activeAudioAssetId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (filePath != null) 'file_path': filePath,
      if (duration != null) 'duration': duration,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (fps != null) 'fps': fps,
      if (hasAudio != null) 'has_audio': hasAudio,
      if (createdAt != null) 'created_at': createdAt,
      if (thumbnailPath != null) 'thumbnail_path': thumbnailPath,
      if (audioMode != null) 'audio_mode': audioMode,
      if (activeAudioAssetId != null)
        'active_audio_asset_id': activeAudioAssetId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? filePath,
      Value<double>? duration,
      Value<int>? width,
      Value<int>? height,
      Value<double>? fps,
      Value<bool>? hasAudio,
      Value<int>? createdAt,
      Value<String?>? thumbnailPath,
      Value<String?>? audioMode,
      Value<String?>? activeAudioAssetId,
      Value<int>? rowid}) {
    return ProjectsTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      filePath: filePath ?? this.filePath,
      duration: duration ?? this.duration,
      width: width ?? this.width,
      height: height ?? this.height,
      fps: fps ?? this.fps,
      hasAudio: hasAudio ?? this.hasAudio,
      createdAt: createdAt ?? this.createdAt,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      audioMode: audioMode ?? this.audioMode,
      activeAudioAssetId: activeAudioAssetId ?? this.activeAudioAssetId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (duration.present) {
      map['duration'] = Variable<double>(duration.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (fps.present) {
      map['fps'] = Variable<double>(fps.value);
    }
    if (hasAudio.present) {
      map['has_audio'] = Variable<bool>(hasAudio.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (thumbnailPath.present) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath.value);
    }
    if (audioMode.present) {
      map['audio_mode'] = Variable<String>(audioMode.value);
    }
    if (activeAudioAssetId.present) {
      map['active_audio_asset_id'] = Variable<String>(activeAudioAssetId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectsTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('filePath: $filePath, ')
          ..write('duration: $duration, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('fps: $fps, ')
          ..write('hasAudio: $hasAudio, ')
          ..write('createdAt: $createdAt, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('audioMode: $audioMode, ')
          ..write('activeAudioAssetId: $activeAudioAssetId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ClipsTableTable extends ClipsTable
    with TableInfo<$ClipsTableTable, ClipRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClipsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
      'project_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES projects (id) ON DELETE CASCADE'));
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<int> score = GeneratedColumn<int>(
      'score', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
      'reason', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _partsJsonMeta =
      const VerificationMeta('partsJson');
  @override
  late final GeneratedColumn<String> partsJson = GeneratedColumn<String>(
      'parts_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _hookJsonMeta =
      const VerificationMeta('hookJson');
  @override
  late final GeneratedColumn<String> hookJson = GeneratedColumn<String>(
      'hook_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _selected9x16Meta =
      const VerificationMeta('selected9x16');
  @override
  late final GeneratedColumn<bool> selected9x16 = GeneratedColumn<bool>(
      'selected_9x16', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("selected_9x16" IN (0, 1))'));
  static const VerificationMeta _selected1x1Meta =
      const VerificationMeta('selected1x1');
  @override
  late final GeneratedColumn<bool> selected1x1 = GeneratedColumn<bool>(
      'selected_1x1', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("selected_1x1" IN (0, 1))'));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        projectId,
        title,
        score,
        reason,
        type,
        partsJson,
        hookJson,
        selected9x16,
        selected1x1
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'clips';
  @override
  VerificationContext validateIntegrity(Insertable<ClipRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('score')) {
      context.handle(
          _scoreMeta, score.isAcceptableOrUnknown(data['score']!, _scoreMeta));
    } else if (isInserting) {
      context.missing(_scoreMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(_reasonMeta,
          reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta));
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('parts_json')) {
      context.handle(_partsJsonMeta,
          partsJson.isAcceptableOrUnknown(data['parts_json']!, _partsJsonMeta));
    } else if (isInserting) {
      context.missing(_partsJsonMeta);
    }
    if (data.containsKey('hook_json')) {
      context.handle(_hookJsonMeta,
          hookJson.isAcceptableOrUnknown(data['hook_json']!, _hookJsonMeta));
    } else if (isInserting) {
      context.missing(_hookJsonMeta);
    }
    if (data.containsKey('selected_9x16')) {
      context.handle(
          _selected9x16Meta,
          selected9x16.isAcceptableOrUnknown(
              data['selected_9x16']!, _selected9x16Meta));
    } else if (isInserting) {
      context.missing(_selected9x16Meta);
    }
    if (data.containsKey('selected_1x1')) {
      context.handle(
          _selected1x1Meta,
          selected1x1.isAcceptableOrUnknown(
              data['selected_1x1']!, _selected1x1Meta));
    } else if (isInserting) {
      context.missing(_selected1x1Meta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id, projectId};
  @override
  ClipRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClipRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      score: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}score'])!,
      reason: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reason'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      partsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parts_json'])!,
      hookJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}hook_json'])!,
      selected9x16: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}selected_9x16'])!,
      selected1x1: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}selected_1x1'])!,
    );
  }

  @override
  $ClipsTableTable createAlias(String alias) {
    return $ClipsTableTable(attachedDatabase, alias);
  }
}

class ClipRow extends DataClass implements Insertable<ClipRow> {
  final String id;
  final String projectId;
  final String title;
  final int score;
  final String reason;
  final String type;
  final String partsJson;
  final String hookJson;
  final bool selected9x16;
  final bool selected1x1;
  const ClipRow(
      {required this.id,
      required this.projectId,
      required this.title,
      required this.score,
      required this.reason,
      required this.type,
      required this.partsJson,
      required this.hookJson,
      required this.selected9x16,
      required this.selected1x1});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['title'] = Variable<String>(title);
    map['score'] = Variable<int>(score);
    map['reason'] = Variable<String>(reason);
    map['type'] = Variable<String>(type);
    map['parts_json'] = Variable<String>(partsJson);
    map['hook_json'] = Variable<String>(hookJson);
    map['selected_9x16'] = Variable<bool>(selected9x16);
    map['selected_1x1'] = Variable<bool>(selected1x1);
    return map;
  }

  ClipsTableCompanion toCompanion(bool nullToAbsent) {
    return ClipsTableCompanion(
      id: Value(id),
      projectId: Value(projectId),
      title: Value(title),
      score: Value(score),
      reason: Value(reason),
      type: Value(type),
      partsJson: Value(partsJson),
      hookJson: Value(hookJson),
      selected9x16: Value(selected9x16),
      selected1x1: Value(selected1x1),
    );
  }

  factory ClipRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClipRow(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      title: serializer.fromJson<String>(json['title']),
      score: serializer.fromJson<int>(json['score']),
      reason: serializer.fromJson<String>(json['reason']),
      type: serializer.fromJson<String>(json['type']),
      partsJson: serializer.fromJson<String>(json['partsJson']),
      hookJson: serializer.fromJson<String>(json['hookJson']),
      selected9x16: serializer.fromJson<bool>(json['selected9x16']),
      selected1x1: serializer.fromJson<bool>(json['selected1x1']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'title': serializer.toJson<String>(title),
      'score': serializer.toJson<int>(score),
      'reason': serializer.toJson<String>(reason),
      'type': serializer.toJson<String>(type),
      'partsJson': serializer.toJson<String>(partsJson),
      'hookJson': serializer.toJson<String>(hookJson),
      'selected9x16': serializer.toJson<bool>(selected9x16),
      'selected1x1': serializer.toJson<bool>(selected1x1),
    };
  }

  ClipRow copyWith(
          {String? id,
          String? projectId,
          String? title,
          int? score,
          String? reason,
          String? type,
          String? partsJson,
          String? hookJson,
          bool? selected9x16,
          bool? selected1x1}) =>
      ClipRow(
        id: id ?? this.id,
        projectId: projectId ?? this.projectId,
        title: title ?? this.title,
        score: score ?? this.score,
        reason: reason ?? this.reason,
        type: type ?? this.type,
        partsJson: partsJson ?? this.partsJson,
        hookJson: hookJson ?? this.hookJson,
        selected9x16: selected9x16 ?? this.selected9x16,
        selected1x1: selected1x1 ?? this.selected1x1,
      );
  ClipRow copyWithCompanion(ClipsTableCompanion data) {
    return ClipRow(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      title: data.title.present ? data.title.value : this.title,
      score: data.score.present ? data.score.value : this.score,
      reason: data.reason.present ? data.reason.value : this.reason,
      type: data.type.present ? data.type.value : this.type,
      partsJson: data.partsJson.present ? data.partsJson.value : this.partsJson,
      hookJson: data.hookJson.present ? data.hookJson.value : this.hookJson,
      selected9x16: data.selected9x16.present
          ? data.selected9x16.value
          : this.selected9x16,
      selected1x1:
          data.selected1x1.present ? data.selected1x1.value : this.selected1x1,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClipRow(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('title: $title, ')
          ..write('score: $score, ')
          ..write('reason: $reason, ')
          ..write('type: $type, ')
          ..write('partsJson: $partsJson, ')
          ..write('hookJson: $hookJson, ')
          ..write('selected9x16: $selected9x16, ')
          ..write('selected1x1: $selected1x1')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, projectId, title, score, reason, type,
      partsJson, hookJson, selected9x16, selected1x1);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClipRow &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.title == this.title &&
          other.score == this.score &&
          other.reason == this.reason &&
          other.type == this.type &&
          other.partsJson == this.partsJson &&
          other.hookJson == this.hookJson &&
          other.selected9x16 == this.selected9x16 &&
          other.selected1x1 == this.selected1x1);
}

class ClipsTableCompanion extends UpdateCompanion<ClipRow> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> title;
  final Value<int> score;
  final Value<String> reason;
  final Value<String> type;
  final Value<String> partsJson;
  final Value<String> hookJson;
  final Value<bool> selected9x16;
  final Value<bool> selected1x1;
  final Value<int> rowid;
  const ClipsTableCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.title = const Value.absent(),
    this.score = const Value.absent(),
    this.reason = const Value.absent(),
    this.type = const Value.absent(),
    this.partsJson = const Value.absent(),
    this.hookJson = const Value.absent(),
    this.selected9x16 = const Value.absent(),
    this.selected1x1 = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ClipsTableCompanion.insert({
    required String id,
    required String projectId,
    required String title,
    required int score,
    required String reason,
    required String type,
    required String partsJson,
    required String hookJson,
    required bool selected9x16,
    required bool selected1x1,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        projectId = Value(projectId),
        title = Value(title),
        score = Value(score),
        reason = Value(reason),
        type = Value(type),
        partsJson = Value(partsJson),
        hookJson = Value(hookJson),
        selected9x16 = Value(selected9x16),
        selected1x1 = Value(selected1x1);
  static Insertable<ClipRow> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? title,
    Expression<int>? score,
    Expression<String>? reason,
    Expression<String>? type,
    Expression<String>? partsJson,
    Expression<String>? hookJson,
    Expression<bool>? selected9x16,
    Expression<bool>? selected1x1,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (title != null) 'title': title,
      if (score != null) 'score': score,
      if (reason != null) 'reason': reason,
      if (type != null) 'type': type,
      if (partsJson != null) 'parts_json': partsJson,
      if (hookJson != null) 'hook_json': hookJson,
      if (selected9x16 != null) 'selected_9x16': selected9x16,
      if (selected1x1 != null) 'selected_1x1': selected1x1,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ClipsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? projectId,
      Value<String>? title,
      Value<int>? score,
      Value<String>? reason,
      Value<String>? type,
      Value<String>? partsJson,
      Value<String>? hookJson,
      Value<bool>? selected9x16,
      Value<bool>? selected1x1,
      Value<int>? rowid}) {
    return ClipsTableCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      score: score ?? this.score,
      reason: reason ?? this.reason,
      type: type ?? this.type,
      partsJson: partsJson ?? this.partsJson,
      hookJson: hookJson ?? this.hookJson,
      selected9x16: selected9x16 ?? this.selected9x16,
      selected1x1: selected1x1 ?? this.selected1x1,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (score.present) {
      map['score'] = Variable<int>(score.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (partsJson.present) {
      map['parts_json'] = Variable<String>(partsJson.value);
    }
    if (hookJson.present) {
      map['hook_json'] = Variable<String>(hookJson.value);
    }
    if (selected9x16.present) {
      map['selected_9x16'] = Variable<bool>(selected9x16.value);
    }
    if (selected1x1.present) {
      map['selected_1x1'] = Variable<bool>(selected1x1.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClipsTableCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('title: $title, ')
          ..write('score: $score, ')
          ..write('reason: $reason, ')
          ..write('type: $type, ')
          ..write('partsJson: $partsJson, ')
          ..write('hookJson: $hookJson, ')
          ..write('selected9x16: $selected9x16, ')
          ..write('selected1x1: $selected1x1, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AssetsTableTable extends AssetsTable
    with TableInfo<$AssetsTableTable, AssetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssetsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
      'project_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES projects (id) ON DELETE CASCADE'));
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sourceFileMeta =
      const VerificationMeta('sourceFile');
  @override
  late final GeneratedColumn<String> sourceFile = GeneratedColumn<String>(
      'source_file', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _startSecMeta =
      const VerificationMeta('startSec');
  @override
  late final GeneratedColumn<double> startSec = GeneratedColumn<double>(
      'start_sec', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _endSecMeta = const VerificationMeta('endSec');
  @override
  late final GeneratedColumn<double> endSec = GeneratedColumn<double>(
      'end_sec', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _durationSecMeta =
      const VerificationMeta('durationSec');
  @override
  late final GeneratedColumn<double> durationSec = GeneratedColumn<double>(
      'duration_sec', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _audioFormatMeta =
      const VerificationMeta('audioFormat');
  @override
  late final GeneratedColumn<String> audioFormat = GeneratedColumn<String>(
      'audio_format', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        projectId,
        type,
        title,
        sourceFile,
        startSec,
        endSec,
        durationSec,
        audioFormat
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'assets';
  @override
  VerificationContext validateIntegrity(Insertable<AssetRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('source_file')) {
      context.handle(
          _sourceFileMeta,
          sourceFile.isAcceptableOrUnknown(
              data['source_file']!, _sourceFileMeta));
    } else if (isInserting) {
      context.missing(_sourceFileMeta);
    }
    if (data.containsKey('start_sec')) {
      context.handle(_startSecMeta,
          startSec.isAcceptableOrUnknown(data['start_sec']!, _startSecMeta));
    } else if (isInserting) {
      context.missing(_startSecMeta);
    }
    if (data.containsKey('end_sec')) {
      context.handle(_endSecMeta,
          endSec.isAcceptableOrUnknown(data['end_sec']!, _endSecMeta));
    } else if (isInserting) {
      context.missing(_endSecMeta);
    }
    if (data.containsKey('duration_sec')) {
      context.handle(
          _durationSecMeta,
          durationSec.isAcceptableOrUnknown(
              data['duration_sec']!, _durationSecMeta));
    }
    if (data.containsKey('audio_format')) {
      context.handle(
          _audioFormatMeta,
          audioFormat.isAcceptableOrUnknown(
              data['audio_format']!, _audioFormatMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id, projectId};
  @override
  AssetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AssetRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      sourceFile: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_file'])!,
      startSec: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}start_sec'])!,
      endSec: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}end_sec'])!,
      durationSec: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}duration_sec']),
      audioFormat: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}audio_format']),
    );
  }

  @override
  $AssetsTableTable createAlias(String alias) {
    return $AssetsTableTable(attachedDatabase, alias);
  }
}

class AssetRow extends DataClass implements Insertable<AssetRow> {
  final String id;
  final String projectId;
  final String type;
  final String title;
  final String sourceFile;
  final double startSec;
  final double endSec;
  final double? durationSec;
  final String? audioFormat;
  const AssetRow(
      {required this.id,
      required this.projectId,
      required this.type,
      required this.title,
      required this.sourceFile,
      required this.startSec,
      required this.endSec,
      this.durationSec,
      this.audioFormat});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['type'] = Variable<String>(type);
    map['title'] = Variable<String>(title);
    map['source_file'] = Variable<String>(sourceFile);
    map['start_sec'] = Variable<double>(startSec);
    map['end_sec'] = Variable<double>(endSec);
    if (!nullToAbsent || durationSec != null) {
      map['duration_sec'] = Variable<double>(durationSec);
    }
    if (!nullToAbsent || audioFormat != null) {
      map['audio_format'] = Variable<String>(audioFormat);
    }
    return map;
  }

  AssetsTableCompanion toCompanion(bool nullToAbsent) {
    return AssetsTableCompanion(
      id: Value(id),
      projectId: Value(projectId),
      type: Value(type),
      title: Value(title),
      sourceFile: Value(sourceFile),
      startSec: Value(startSec),
      endSec: Value(endSec),
      durationSec: durationSec == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSec),
      audioFormat: audioFormat == null && nullToAbsent
          ? const Value.absent()
          : Value(audioFormat),
    );
  }

  factory AssetRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AssetRow(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      type: serializer.fromJson<String>(json['type']),
      title: serializer.fromJson<String>(json['title']),
      sourceFile: serializer.fromJson<String>(json['sourceFile']),
      startSec: serializer.fromJson<double>(json['startSec']),
      endSec: serializer.fromJson<double>(json['endSec']),
      durationSec: serializer.fromJson<double?>(json['durationSec']),
      audioFormat: serializer.fromJson<String?>(json['audioFormat']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'type': serializer.toJson<String>(type),
      'title': serializer.toJson<String>(title),
      'sourceFile': serializer.toJson<String>(sourceFile),
      'startSec': serializer.toJson<double>(startSec),
      'endSec': serializer.toJson<double>(endSec),
      'durationSec': serializer.toJson<double?>(durationSec),
      'audioFormat': serializer.toJson<String?>(audioFormat),
    };
  }

  AssetRow copyWith(
          {String? id,
          String? projectId,
          String? type,
          String? title,
          String? sourceFile,
          double? startSec,
          double? endSec,
          Value<double?> durationSec = const Value.absent(),
          Value<String?> audioFormat = const Value.absent()}) =>
      AssetRow(
        id: id ?? this.id,
        projectId: projectId ?? this.projectId,
        type: type ?? this.type,
        title: title ?? this.title,
        sourceFile: sourceFile ?? this.sourceFile,
        startSec: startSec ?? this.startSec,
        endSec: endSec ?? this.endSec,
        durationSec: durationSec.present ? durationSec.value : this.durationSec,
        audioFormat: audioFormat.present ? audioFormat.value : this.audioFormat,
      );
  AssetRow copyWithCompanion(AssetsTableCompanion data) {
    return AssetRow(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      type: data.type.present ? data.type.value : this.type,
      title: data.title.present ? data.title.value : this.title,
      sourceFile:
          data.sourceFile.present ? data.sourceFile.value : this.sourceFile,
      startSec: data.startSec.present ? data.startSec.value : this.startSec,
      endSec: data.endSec.present ? data.endSec.value : this.endSec,
      durationSec:
          data.durationSec.present ? data.durationSec.value : this.durationSec,
      audioFormat:
          data.audioFormat.present ? data.audioFormat.value : this.audioFormat,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AssetRow(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('sourceFile: $sourceFile, ')
          ..write('startSec: $startSec, ')
          ..write('endSec: $endSec, ')
          ..write('durationSec: $durationSec, ')
          ..write('audioFormat: $audioFormat')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, projectId, type, title, sourceFile,
      startSec, endSec, durationSec, audioFormat);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssetRow &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.type == this.type &&
          other.title == this.title &&
          other.sourceFile == this.sourceFile &&
          other.startSec == this.startSec &&
          other.endSec == this.endSec &&
          other.durationSec == this.durationSec &&
          other.audioFormat == this.audioFormat);
}

class AssetsTableCompanion extends UpdateCompanion<AssetRow> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> type;
  final Value<String> title;
  final Value<String> sourceFile;
  final Value<double> startSec;
  final Value<double> endSec;
  final Value<double?> durationSec;
  final Value<String?> audioFormat;
  final Value<int> rowid;
  const AssetsTableCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.sourceFile = const Value.absent(),
    this.startSec = const Value.absent(),
    this.endSec = const Value.absent(),
    this.durationSec = const Value.absent(),
    this.audioFormat = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AssetsTableCompanion.insert({
    required String id,
    required String projectId,
    required String type,
    required String title,
    required String sourceFile,
    required double startSec,
    required double endSec,
    this.durationSec = const Value.absent(),
    this.audioFormat = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        projectId = Value(projectId),
        type = Value(type),
        title = Value(title),
        sourceFile = Value(sourceFile),
        startSec = Value(startSec),
        endSec = Value(endSec);
  static Insertable<AssetRow> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? type,
    Expression<String>? title,
    Expression<String>? sourceFile,
    Expression<double>? startSec,
    Expression<double>? endSec,
    Expression<double>? durationSec,
    Expression<String>? audioFormat,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (type != null) 'type': type,
      if (title != null) 'title': title,
      if (sourceFile != null) 'source_file': sourceFile,
      if (startSec != null) 'start_sec': startSec,
      if (endSec != null) 'end_sec': endSec,
      if (durationSec != null) 'duration_sec': durationSec,
      if (audioFormat != null) 'audio_format': audioFormat,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AssetsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? projectId,
      Value<String>? type,
      Value<String>? title,
      Value<String>? sourceFile,
      Value<double>? startSec,
      Value<double>? endSec,
      Value<double?>? durationSec,
      Value<String?>? audioFormat,
      Value<int>? rowid}) {
    return AssetsTableCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      type: type ?? this.type,
      title: title ?? this.title,
      sourceFile: sourceFile ?? this.sourceFile,
      startSec: startSec ?? this.startSec,
      endSec: endSec ?? this.endSec,
      durationSec: durationSec ?? this.durationSec,
      audioFormat: audioFormat ?? this.audioFormat,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (sourceFile.present) {
      map['source_file'] = Variable<String>(sourceFile.value);
    }
    if (startSec.present) {
      map['start_sec'] = Variable<double>(startSec.value);
    }
    if (endSec.present) {
      map['end_sec'] = Variable<double>(endSec.value);
    }
    if (durationSec.present) {
      map['duration_sec'] = Variable<double>(durationSec.value);
    }
    if (audioFormat.present) {
      map['audio_format'] = Variable<String>(audioFormat.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssetsTableCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('sourceFile: $sourceFile, ')
          ..write('startSec: $startSec, ')
          ..write('endSec: $endSec, ')
          ..write('durationSec: $durationSec, ')
          ..write('audioFormat: $audioFormat, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TranscriptsTableTable extends TranscriptsTable
    with TableInfo<$TranscriptsTableTable, TranscriptRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TranscriptsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
      'project_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES projects (id) ON DELETE CASCADE'));
  static const VerificationMeta _assetIdMeta =
      const VerificationMeta('assetId');
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
      'asset_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _fullTextMeta =
      const VerificationMeta('fullText');
  @override
  late final GeneratedColumn<String> fullText = GeneratedColumn<String>(
      'full_text', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _wordsJsonMeta =
      const VerificationMeta('wordsJson');
  @override
  late final GeneratedColumn<String> wordsJson = GeneratedColumn<String>(
      'words_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _languageMeta =
      const VerificationMeta('language');
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
      'language', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _providerMeta =
      const VerificationMeta('provider');
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
      'provider', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [projectId, assetId, fullText, wordsJson, language, provider, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transcripts';
  @override
  VerificationContext validateIntegrity(Insertable<TranscriptRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('asset_id')) {
      context.handle(_assetIdMeta,
          assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta));
    }
    if (data.containsKey('full_text')) {
      context.handle(_fullTextMeta,
          fullText.isAcceptableOrUnknown(data['full_text']!, _fullTextMeta));
    } else if (isInserting) {
      context.missing(_fullTextMeta);
    }
    if (data.containsKey('words_json')) {
      context.handle(_wordsJsonMeta,
          wordsJson.isAcceptableOrUnknown(data['words_json']!, _wordsJsonMeta));
    } else if (isInserting) {
      context.missing(_wordsJsonMeta);
    }
    if (data.containsKey('language')) {
      context.handle(_languageMeta,
          language.isAcceptableOrUnknown(data['language']!, _languageMeta));
    }
    if (data.containsKey('provider')) {
      context.handle(_providerMeta,
          provider.isAcceptableOrUnknown(data['provider']!, _providerMeta));
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {projectId};
  @override
  TranscriptRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TranscriptRow(
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_id'])!,
      assetId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}asset_id']),
      fullText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}full_text'])!,
      wordsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}words_json'])!,
      language: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}language']),
      provider: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}provider'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $TranscriptsTableTable createAlias(String alias) {
    return $TranscriptsTableTable(attachedDatabase, alias);
  }
}

class TranscriptRow extends DataClass implements Insertable<TranscriptRow> {
  final String projectId;
  final String? assetId;
  final String fullText;
  final String wordsJson;
  final String? language;
  final String provider;
  final int createdAt;
  const TranscriptRow(
      {required this.projectId,
      this.assetId,
      required this.fullText,
      required this.wordsJson,
      this.language,
      required this.provider,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['project_id'] = Variable<String>(projectId);
    if (!nullToAbsent || assetId != null) {
      map['asset_id'] = Variable<String>(assetId);
    }
    map['full_text'] = Variable<String>(fullText);
    map['words_json'] = Variable<String>(wordsJson);
    if (!nullToAbsent || language != null) {
      map['language'] = Variable<String>(language);
    }
    map['provider'] = Variable<String>(provider);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  TranscriptsTableCompanion toCompanion(bool nullToAbsent) {
    return TranscriptsTableCompanion(
      projectId: Value(projectId),
      assetId: assetId == null && nullToAbsent
          ? const Value.absent()
          : Value(assetId),
      fullText: Value(fullText),
      wordsJson: Value(wordsJson),
      language: language == null && nullToAbsent
          ? const Value.absent()
          : Value(language),
      provider: Value(provider),
      createdAt: Value(createdAt),
    );
  }

  factory TranscriptRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TranscriptRow(
      projectId: serializer.fromJson<String>(json['projectId']),
      assetId: serializer.fromJson<String?>(json['assetId']),
      fullText: serializer.fromJson<String>(json['fullText']),
      wordsJson: serializer.fromJson<String>(json['wordsJson']),
      language: serializer.fromJson<String?>(json['language']),
      provider: serializer.fromJson<String>(json['provider']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'projectId': serializer.toJson<String>(projectId),
      'assetId': serializer.toJson<String?>(assetId),
      'fullText': serializer.toJson<String>(fullText),
      'wordsJson': serializer.toJson<String>(wordsJson),
      'language': serializer.toJson<String?>(language),
      'provider': serializer.toJson<String>(provider),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  TranscriptRow copyWith(
          {String? projectId,
          Value<String?> assetId = const Value.absent(),
          String? fullText,
          String? wordsJson,
          Value<String?> language = const Value.absent(),
          String? provider,
          int? createdAt}) =>
      TranscriptRow(
        projectId: projectId ?? this.projectId,
        assetId: assetId.present ? assetId.value : this.assetId,
        fullText: fullText ?? this.fullText,
        wordsJson: wordsJson ?? this.wordsJson,
        language: language.present ? language.value : this.language,
        provider: provider ?? this.provider,
        createdAt: createdAt ?? this.createdAt,
      );
  TranscriptRow copyWithCompanion(TranscriptsTableCompanion data) {
    return TranscriptRow(
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      fullText: data.fullText.present ? data.fullText.value : this.fullText,
      wordsJson: data.wordsJson.present ? data.wordsJson.value : this.wordsJson,
      language: data.language.present ? data.language.value : this.language,
      provider: data.provider.present ? data.provider.value : this.provider,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TranscriptRow(')
          ..write('projectId: $projectId, ')
          ..write('assetId: $assetId, ')
          ..write('fullText: $fullText, ')
          ..write('wordsJson: $wordsJson, ')
          ..write('language: $language, ')
          ..write('provider: $provider, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      projectId, assetId, fullText, wordsJson, language, provider, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TranscriptRow &&
          other.projectId == this.projectId &&
          other.assetId == this.assetId &&
          other.fullText == this.fullText &&
          other.wordsJson == this.wordsJson &&
          other.language == this.language &&
          other.provider == this.provider &&
          other.createdAt == this.createdAt);
}

class TranscriptsTableCompanion extends UpdateCompanion<TranscriptRow> {
  final Value<String> projectId;
  final Value<String?> assetId;
  final Value<String> fullText;
  final Value<String> wordsJson;
  final Value<String?> language;
  final Value<String> provider;
  final Value<int> createdAt;
  final Value<int> rowid;
  const TranscriptsTableCompanion({
    this.projectId = const Value.absent(),
    this.assetId = const Value.absent(),
    this.fullText = const Value.absent(),
    this.wordsJson = const Value.absent(),
    this.language = const Value.absent(),
    this.provider = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TranscriptsTableCompanion.insert({
    required String projectId,
    this.assetId = const Value.absent(),
    required String fullText,
    required String wordsJson,
    this.language = const Value.absent(),
    required String provider,
    required int createdAt,
    this.rowid = const Value.absent(),
  })  : projectId = Value(projectId),
        fullText = Value(fullText),
        wordsJson = Value(wordsJson),
        provider = Value(provider),
        createdAt = Value(createdAt);
  static Insertable<TranscriptRow> custom({
    Expression<String>? projectId,
    Expression<String>? assetId,
    Expression<String>? fullText,
    Expression<String>? wordsJson,
    Expression<String>? language,
    Expression<String>? provider,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (projectId != null) 'project_id': projectId,
      if (assetId != null) 'asset_id': assetId,
      if (fullText != null) 'full_text': fullText,
      if (wordsJson != null) 'words_json': wordsJson,
      if (language != null) 'language': language,
      if (provider != null) 'provider': provider,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TranscriptsTableCompanion copyWith(
      {Value<String>? projectId,
      Value<String?>? assetId,
      Value<String>? fullText,
      Value<String>? wordsJson,
      Value<String?>? language,
      Value<String>? provider,
      Value<int>? createdAt,
      Value<int>? rowid}) {
    return TranscriptsTableCompanion(
      projectId: projectId ?? this.projectId,
      assetId: assetId ?? this.assetId,
      fullText: fullText ?? this.fullText,
      wordsJson: wordsJson ?? this.wordsJson,
      language: language ?? this.language,
      provider: provider ?? this.provider,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (fullText.present) {
      map['full_text'] = Variable<String>(fullText.value);
    }
    if (wordsJson.present) {
      map['words_json'] = Variable<String>(wordsJson.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TranscriptsTableCompanion(')
          ..write('projectId: $projectId, ')
          ..write('assetId: $assetId, ')
          ..write('fullText: $fullText, ')
          ..write('wordsJson: $wordsJson, ')
          ..write('language: $language, ')
          ..write('provider: $provider, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$VisaryDatabase extends GeneratedDatabase {
  _$VisaryDatabase(QueryExecutor e) : super(e);
  $VisaryDatabaseManager get managers => $VisaryDatabaseManager(this);
  late final $ProjectsTableTable projectsTable = $ProjectsTableTable(this);
  late final $ClipsTableTable clipsTable = $ClipsTableTable(this);
  late final $AssetsTableTable assetsTable = $AssetsTableTable(this);
  late final $TranscriptsTableTable transcriptsTable =
      $TranscriptsTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [projectsTable, clipsTable, assetsTable, transcriptsTable];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('projects',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('clips', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('projects',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('assets', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('projects',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('transcripts', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$ProjectsTableTableCreateCompanionBuilder = ProjectsTableCompanion
    Function({
  required String id,
  required String name,
  required String filePath,
  required double duration,
  required int width,
  required int height,
  required double fps,
  required bool hasAudio,
  required int createdAt,
  Value<String?> thumbnailPath,
  Value<String?> audioMode,
  Value<String?> activeAudioAssetId,
  Value<int> rowid,
});
typedef $$ProjectsTableTableUpdateCompanionBuilder = ProjectsTableCompanion
    Function({
  Value<String> id,
  Value<String> name,
  Value<String> filePath,
  Value<double> duration,
  Value<int> width,
  Value<int> height,
  Value<double> fps,
  Value<bool> hasAudio,
  Value<int> createdAt,
  Value<String?> thumbnailPath,
  Value<String?> audioMode,
  Value<String?> activeAudioAssetId,
  Value<int> rowid,
});

final class $$ProjectsTableTableReferences
    extends BaseReferences<_$VisaryDatabase, $ProjectsTableTable, ProjectRow> {
  $$ProjectsTableTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ClipsTableTable, List<ClipRow>>
      _clipsTableRefsTable(_$VisaryDatabase db) =>
          MultiTypedResultKey.fromTable(db.clipsTable,
              aliasName: 'projects__id__clips__project_id');

  $$ClipsTableTableProcessedTableManager get clipsTableRefs {
    final manager = $$ClipsTableTableTableManager($_db, $_db.clipsTable)
        .filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_clipsTableRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$AssetsTableTable, List<AssetRow>>
      _assetsTableRefsTable(_$VisaryDatabase db) =>
          MultiTypedResultKey.fromTable(db.assetsTable,
              aliasName: 'projects__id__assets__project_id');

  $$AssetsTableTableProcessedTableManager get assetsTableRefs {
    final manager = $$AssetsTableTableTableManager($_db, $_db.assetsTable)
        .filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_assetsTableRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$TranscriptsTableTable, List<TranscriptRow>>
      _transcriptsTableRefsTable(_$VisaryDatabase db) =>
          MultiTypedResultKey.fromTable(db.transcriptsTable,
              aliasName: 'projects__id__transcripts__project_id');

  $$TranscriptsTableTableProcessedTableManager get transcriptsTableRefs {
    final manager = $$TranscriptsTableTableTableManager(
            $_db, $_db.transcriptsTable)
        .filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_transcriptsTableRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ProjectsTableTableFilterComposer
    extends Composer<_$VisaryDatabase, $ProjectsTableTable> {
  $$ProjectsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get duration => $composableBuilder(
      column: $table.duration, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get width => $composableBuilder(
      column: $table.width, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get height => $composableBuilder(
      column: $table.height, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get fps => $composableBuilder(
      column: $table.fps, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get hasAudio => $composableBuilder(
      column: $table.hasAudio, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get thumbnailPath => $composableBuilder(
      column: $table.thumbnailPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get audioMode => $composableBuilder(
      column: $table.audioMode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get activeAudioAssetId => $composableBuilder(
      column: $table.activeAudioAssetId,
      builder: (column) => ColumnFilters(column));

  Expression<bool> clipsTableRefs(
      Expression<bool> Function($$ClipsTableTableFilterComposer f) f) {
    final $$ClipsTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.clipsTable,
        getReferencedColumn: (t) => t.projectId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ClipsTableTableFilterComposer(
              $db: $db,
              $table: $db.clipsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> assetsTableRefs(
      Expression<bool> Function($$AssetsTableTableFilterComposer f) f) {
    final $$AssetsTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.assetsTable,
        getReferencedColumn: (t) => t.projectId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AssetsTableTableFilterComposer(
              $db: $db,
              $table: $db.assetsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> transcriptsTableRefs(
      Expression<bool> Function($$TranscriptsTableTableFilterComposer f) f) {
    final $$TranscriptsTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.transcriptsTable,
        getReferencedColumn: (t) => t.projectId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TranscriptsTableTableFilterComposer(
              $db: $db,
              $table: $db.transcriptsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ProjectsTableTableOrderingComposer
    extends Composer<_$VisaryDatabase, $ProjectsTableTable> {
  $$ProjectsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get duration => $composableBuilder(
      column: $table.duration, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get width => $composableBuilder(
      column: $table.width, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get height => $composableBuilder(
      column: $table.height, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get fps => $composableBuilder(
      column: $table.fps, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get hasAudio => $composableBuilder(
      column: $table.hasAudio, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get thumbnailPath => $composableBuilder(
      column: $table.thumbnailPath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get audioMode => $composableBuilder(
      column: $table.audioMode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get activeAudioAssetId => $composableBuilder(
      column: $table.activeAudioAssetId,
      builder: (column) => ColumnOrderings(column));
}

class $$ProjectsTableTableAnnotationComposer
    extends Composer<_$VisaryDatabase, $ProjectsTableTable> {
  $$ProjectsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<double> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<double> get fps =>
      $composableBuilder(column: $table.fps, builder: (column) => column);

  GeneratedColumn<bool> get hasAudio =>
      $composableBuilder(column: $table.hasAudio, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get thumbnailPath => $composableBuilder(
      column: $table.thumbnailPath, builder: (column) => column);

  GeneratedColumn<String> get audioMode =>
      $composableBuilder(column: $table.audioMode, builder: (column) => column);

  GeneratedColumn<String> get activeAudioAssetId => $composableBuilder(
      column: $table.activeAudioAssetId, builder: (column) => column);

  Expression<T> clipsTableRefs<T extends Object>(
      Expression<T> Function($$ClipsTableTableAnnotationComposer a) f) {
    final $$ClipsTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.clipsTable,
        getReferencedColumn: (t) => t.projectId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ClipsTableTableAnnotationComposer(
              $db: $db,
              $table: $db.clipsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> assetsTableRefs<T extends Object>(
      Expression<T> Function($$AssetsTableTableAnnotationComposer a) f) {
    final $$AssetsTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.assetsTable,
        getReferencedColumn: (t) => t.projectId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AssetsTableTableAnnotationComposer(
              $db: $db,
              $table: $db.assetsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> transcriptsTableRefs<T extends Object>(
      Expression<T> Function($$TranscriptsTableTableAnnotationComposer a) f) {
    final $$TranscriptsTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.transcriptsTable,
        getReferencedColumn: (t) => t.projectId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TranscriptsTableTableAnnotationComposer(
              $db: $db,
              $table: $db.transcriptsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ProjectsTableTableTableManager extends RootTableManager<
    _$VisaryDatabase,
    $ProjectsTableTable,
    ProjectRow,
    $$ProjectsTableTableFilterComposer,
    $$ProjectsTableTableOrderingComposer,
    $$ProjectsTableTableAnnotationComposer,
    $$ProjectsTableTableCreateCompanionBuilder,
    $$ProjectsTableTableUpdateCompanionBuilder,
    (ProjectRow, $$ProjectsTableTableReferences),
    ProjectRow,
    PrefetchHooks Function(
        {bool clipsTableRefs,
        bool assetsTableRefs,
        bool transcriptsTableRefs})> {
  $$ProjectsTableTableTableManager(
      _$VisaryDatabase db, $ProjectsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> filePath = const Value.absent(),
            Value<double> duration = const Value.absent(),
            Value<int> width = const Value.absent(),
            Value<int> height = const Value.absent(),
            Value<double> fps = const Value.absent(),
            Value<bool> hasAudio = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<String?> thumbnailPath = const Value.absent(),
            Value<String?> audioMode = const Value.absent(),
            Value<String?> activeAudioAssetId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProjectsTableCompanion(
            id: id,
            name: name,
            filePath: filePath,
            duration: duration,
            width: width,
            height: height,
            fps: fps,
            hasAudio: hasAudio,
            createdAt: createdAt,
            thumbnailPath: thumbnailPath,
            audioMode: audioMode,
            activeAudioAssetId: activeAudioAssetId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String filePath,
            required double duration,
            required int width,
            required int height,
            required double fps,
            required bool hasAudio,
            required int createdAt,
            Value<String?> thumbnailPath = const Value.absent(),
            Value<String?> audioMode = const Value.absent(),
            Value<String?> activeAudioAssetId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProjectsTableCompanion.insert(
            id: id,
            name: name,
            filePath: filePath,
            duration: duration,
            width: width,
            height: height,
            fps: fps,
            hasAudio: hasAudio,
            createdAt: createdAt,
            thumbnailPath: thumbnailPath,
            audioMode: audioMode,
            activeAudioAssetId: activeAudioAssetId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$ProjectsTableTable, ProjectRow>(table),
                    $$ProjectsTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {clipsTableRefs = false,
              assetsTableRefs = false,
              transcriptsTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (clipsTableRefs) db.clipsTable,
                if (assetsTableRefs) db.assetsTable,
                if (transcriptsTableRefs) db.transcriptsTable
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (clipsTableRefs)
                    await $_getPrefetchedData<ProjectRow, $ProjectsTableTable,
                            ClipRow>(
                        currentTable: table,
                        referencedTable: $$ProjectsTableTableReferences
                            ._clipsTableRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProjectsTableTableReferences(db, table, p0)
                                .clipsTableRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.projectId == item.id),
                        typedResults: items),
                  if (assetsTableRefs)
                    await $_getPrefetchedData<ProjectRow, $ProjectsTableTable,
                            AssetRow>(
                        currentTable: table,
                        referencedTable: $$ProjectsTableTableReferences
                            ._assetsTableRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProjectsTableTableReferences(db, table, p0)
                                .assetsTableRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.projectId == item.id),
                        typedResults: items),
                  if (transcriptsTableRefs)
                    await $_getPrefetchedData<ProjectRow, $ProjectsTableTable,
                            TranscriptRow>(
                        currentTable: table,
                        referencedTable: $$ProjectsTableTableReferences
                            ._transcriptsTableRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProjectsTableTableReferences(db, table, p0)
                                .transcriptsTableRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.projectId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ProjectsTableTableProcessedTableManager = ProcessedTableManager<
    _$VisaryDatabase,
    $ProjectsTableTable,
    ProjectRow,
    $$ProjectsTableTableFilterComposer,
    $$ProjectsTableTableOrderingComposer,
    $$ProjectsTableTableAnnotationComposer,
    $$ProjectsTableTableCreateCompanionBuilder,
    $$ProjectsTableTableUpdateCompanionBuilder,
    (ProjectRow, $$ProjectsTableTableReferences),
    ProjectRow,
    PrefetchHooks Function(
        {bool clipsTableRefs,
        bool assetsTableRefs,
        bool transcriptsTableRefs})>;
typedef $$ClipsTableTableCreateCompanionBuilder = ClipsTableCompanion Function({
  required String id,
  required String projectId,
  required String title,
  required int score,
  required String reason,
  required String type,
  required String partsJson,
  required String hookJson,
  required bool selected9x16,
  required bool selected1x1,
  Value<int> rowid,
});
typedef $$ClipsTableTableUpdateCompanionBuilder = ClipsTableCompanion Function({
  Value<String> id,
  Value<String> projectId,
  Value<String> title,
  Value<int> score,
  Value<String> reason,
  Value<String> type,
  Value<String> partsJson,
  Value<String> hookJson,
  Value<bool> selected9x16,
  Value<bool> selected1x1,
  Value<int> rowid,
});

final class $$ClipsTableTableReferences
    extends BaseReferences<_$VisaryDatabase, $ClipsTableTable, ClipRow> {
  $$ClipsTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTableTable _projectIdTable(_$VisaryDatabase db) =>
      db.projectsTable.createAlias('clips__project_id__projects__id');

  $$ProjectsTableTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableTableManager($_db, $_db.projectsTable)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ClipsTableTableFilterComposer
    extends Composer<_$VisaryDatabase, $ClipsTableTable> {
  $$ClipsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get score => $composableBuilder(
      column: $table.score, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reason => $composableBuilder(
      column: $table.reason, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get partsJson => $composableBuilder(
      column: $table.partsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get hookJson => $composableBuilder(
      column: $table.hookJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get selected9x16 => $composableBuilder(
      column: $table.selected9x16, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get selected1x1 => $composableBuilder(
      column: $table.selected1x1, builder: (column) => ColumnFilters(column));

  $$ProjectsTableTableFilterComposer get projectId {
    final $$ProjectsTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projectsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableTableFilterComposer(
              $db: $db,
              $table: $db.projectsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ClipsTableTableOrderingComposer
    extends Composer<_$VisaryDatabase, $ClipsTableTable> {
  $$ClipsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get score => $composableBuilder(
      column: $table.score, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reason => $composableBuilder(
      column: $table.reason, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get partsJson => $composableBuilder(
      column: $table.partsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get hookJson => $composableBuilder(
      column: $table.hookJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get selected9x16 => $composableBuilder(
      column: $table.selected9x16,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get selected1x1 => $composableBuilder(
      column: $table.selected1x1, builder: (column) => ColumnOrderings(column));

  $$ProjectsTableTableOrderingComposer get projectId {
    final $$ProjectsTableTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projectsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableTableOrderingComposer(
              $db: $db,
              $table: $db.projectsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ClipsTableTableAnnotationComposer
    extends Composer<_$VisaryDatabase, $ClipsTableTable> {
  $$ClipsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get partsJson =>
      $composableBuilder(column: $table.partsJson, builder: (column) => column);

  GeneratedColumn<String> get hookJson =>
      $composableBuilder(column: $table.hookJson, builder: (column) => column);

  GeneratedColumn<bool> get selected9x16 => $composableBuilder(
      column: $table.selected9x16, builder: (column) => column);

  GeneratedColumn<bool> get selected1x1 => $composableBuilder(
      column: $table.selected1x1, builder: (column) => column);

  $$ProjectsTableTableAnnotationComposer get projectId {
    final $$ProjectsTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projectsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableTableAnnotationComposer(
              $db: $db,
              $table: $db.projectsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ClipsTableTableTableManager extends RootTableManager<
    _$VisaryDatabase,
    $ClipsTableTable,
    ClipRow,
    $$ClipsTableTableFilterComposer,
    $$ClipsTableTableOrderingComposer,
    $$ClipsTableTableAnnotationComposer,
    $$ClipsTableTableCreateCompanionBuilder,
    $$ClipsTableTableUpdateCompanionBuilder,
    (ClipRow, $$ClipsTableTableReferences),
    ClipRow,
    PrefetchHooks Function({bool projectId})> {
  $$ClipsTableTableTableManager(_$VisaryDatabase db, $ClipsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClipsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClipsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClipsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> projectId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<int> score = const Value.absent(),
            Value<String> reason = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> partsJson = const Value.absent(),
            Value<String> hookJson = const Value.absent(),
            Value<bool> selected9x16 = const Value.absent(),
            Value<bool> selected1x1 = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ClipsTableCompanion(
            id: id,
            projectId: projectId,
            title: title,
            score: score,
            reason: reason,
            type: type,
            partsJson: partsJson,
            hookJson: hookJson,
            selected9x16: selected9x16,
            selected1x1: selected1x1,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String projectId,
            required String title,
            required int score,
            required String reason,
            required String type,
            required String partsJson,
            required String hookJson,
            required bool selected9x16,
            required bool selected1x1,
            Value<int> rowid = const Value.absent(),
          }) =>
              ClipsTableCompanion.insert(
            id: id,
            projectId: projectId,
            title: title,
            score: score,
            reason: reason,
            type: type,
            partsJson: partsJson,
            hookJson: hookJson,
            selected9x16: selected9x16,
            selected1x1: selected1x1,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$ClipsTableTable, ClipRow>(table),
                    $$ClipsTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (projectId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.projectId,
                    referencedTable:
                        $$ClipsTableTableReferences._projectIdTable(db),
                    referencedColumn:
                        $$ClipsTableTableReferences._projectIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$ClipsTableTableProcessedTableManager = ProcessedTableManager<
    _$VisaryDatabase,
    $ClipsTableTable,
    ClipRow,
    $$ClipsTableTableFilterComposer,
    $$ClipsTableTableOrderingComposer,
    $$ClipsTableTableAnnotationComposer,
    $$ClipsTableTableCreateCompanionBuilder,
    $$ClipsTableTableUpdateCompanionBuilder,
    (ClipRow, $$ClipsTableTableReferences),
    ClipRow,
    PrefetchHooks Function({bool projectId})>;
typedef $$AssetsTableTableCreateCompanionBuilder = AssetsTableCompanion
    Function({
  required String id,
  required String projectId,
  required String type,
  required String title,
  required String sourceFile,
  required double startSec,
  required double endSec,
  Value<double?> durationSec,
  Value<String?> audioFormat,
  Value<int> rowid,
});
typedef $$AssetsTableTableUpdateCompanionBuilder = AssetsTableCompanion
    Function({
  Value<String> id,
  Value<String> projectId,
  Value<String> type,
  Value<String> title,
  Value<String> sourceFile,
  Value<double> startSec,
  Value<double> endSec,
  Value<double?> durationSec,
  Value<String?> audioFormat,
  Value<int> rowid,
});

final class $$AssetsTableTableReferences
    extends BaseReferences<_$VisaryDatabase, $AssetsTableTable, AssetRow> {
  $$AssetsTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTableTable _projectIdTable(_$VisaryDatabase db) =>
      db.projectsTable.createAlias('assets__project_id__projects__id');

  $$ProjectsTableTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableTableManager($_db, $_db.projectsTable)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$AssetsTableTableFilterComposer
    extends Composer<_$VisaryDatabase, $AssetsTableTable> {
  $$AssetsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceFile => $composableBuilder(
      column: $table.sourceFile, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get startSec => $composableBuilder(
      column: $table.startSec, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get endSec => $composableBuilder(
      column: $table.endSec, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get durationSec => $composableBuilder(
      column: $table.durationSec, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get audioFormat => $composableBuilder(
      column: $table.audioFormat, builder: (column) => ColumnFilters(column));

  $$ProjectsTableTableFilterComposer get projectId {
    final $$ProjectsTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projectsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableTableFilterComposer(
              $db: $db,
              $table: $db.projectsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AssetsTableTableOrderingComposer
    extends Composer<_$VisaryDatabase, $AssetsTableTable> {
  $$AssetsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceFile => $composableBuilder(
      column: $table.sourceFile, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get startSec => $composableBuilder(
      column: $table.startSec, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get endSec => $composableBuilder(
      column: $table.endSec, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get durationSec => $composableBuilder(
      column: $table.durationSec, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get audioFormat => $composableBuilder(
      column: $table.audioFormat, builder: (column) => ColumnOrderings(column));

  $$ProjectsTableTableOrderingComposer get projectId {
    final $$ProjectsTableTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projectsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableTableOrderingComposer(
              $db: $db,
              $table: $db.projectsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AssetsTableTableAnnotationComposer
    extends Composer<_$VisaryDatabase, $AssetsTableTable> {
  $$AssetsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get sourceFile => $composableBuilder(
      column: $table.sourceFile, builder: (column) => column);

  GeneratedColumn<double> get startSec =>
      $composableBuilder(column: $table.startSec, builder: (column) => column);

  GeneratedColumn<double> get endSec =>
      $composableBuilder(column: $table.endSec, builder: (column) => column);

  GeneratedColumn<double> get durationSec => $composableBuilder(
      column: $table.durationSec, builder: (column) => column);

  GeneratedColumn<String> get audioFormat => $composableBuilder(
      column: $table.audioFormat, builder: (column) => column);

  $$ProjectsTableTableAnnotationComposer get projectId {
    final $$ProjectsTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projectsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableTableAnnotationComposer(
              $db: $db,
              $table: $db.projectsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AssetsTableTableTableManager extends RootTableManager<
    _$VisaryDatabase,
    $AssetsTableTable,
    AssetRow,
    $$AssetsTableTableFilterComposer,
    $$AssetsTableTableOrderingComposer,
    $$AssetsTableTableAnnotationComposer,
    $$AssetsTableTableCreateCompanionBuilder,
    $$AssetsTableTableUpdateCompanionBuilder,
    (AssetRow, $$AssetsTableTableReferences),
    AssetRow,
    PrefetchHooks Function({bool projectId})> {
  $$AssetsTableTableTableManager(_$VisaryDatabase db, $AssetsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AssetsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AssetsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AssetsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> projectId = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> sourceFile = const Value.absent(),
            Value<double> startSec = const Value.absent(),
            Value<double> endSec = const Value.absent(),
            Value<double?> durationSec = const Value.absent(),
            Value<String?> audioFormat = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AssetsTableCompanion(
            id: id,
            projectId: projectId,
            type: type,
            title: title,
            sourceFile: sourceFile,
            startSec: startSec,
            endSec: endSec,
            durationSec: durationSec,
            audioFormat: audioFormat,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String projectId,
            required String type,
            required String title,
            required String sourceFile,
            required double startSec,
            required double endSec,
            Value<double?> durationSec = const Value.absent(),
            Value<String?> audioFormat = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AssetsTableCompanion.insert(
            id: id,
            projectId: projectId,
            type: type,
            title: title,
            sourceFile: sourceFile,
            startSec: startSec,
            endSec: endSec,
            durationSec: durationSec,
            audioFormat: audioFormat,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$AssetsTableTable, AssetRow>(table),
                    $$AssetsTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (projectId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.projectId,
                    referencedTable:
                        $$AssetsTableTableReferences._projectIdTable(db),
                    referencedColumn:
                        $$AssetsTableTableReferences._projectIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$AssetsTableTableProcessedTableManager = ProcessedTableManager<
    _$VisaryDatabase,
    $AssetsTableTable,
    AssetRow,
    $$AssetsTableTableFilterComposer,
    $$AssetsTableTableOrderingComposer,
    $$AssetsTableTableAnnotationComposer,
    $$AssetsTableTableCreateCompanionBuilder,
    $$AssetsTableTableUpdateCompanionBuilder,
    (AssetRow, $$AssetsTableTableReferences),
    AssetRow,
    PrefetchHooks Function({bool projectId})>;
typedef $$TranscriptsTableTableCreateCompanionBuilder
    = TranscriptsTableCompanion Function({
  required String projectId,
  Value<String?> assetId,
  required String fullText,
  required String wordsJson,
  Value<String?> language,
  required String provider,
  required int createdAt,
  Value<int> rowid,
});
typedef $$TranscriptsTableTableUpdateCompanionBuilder
    = TranscriptsTableCompanion Function({
  Value<String> projectId,
  Value<String?> assetId,
  Value<String> fullText,
  Value<String> wordsJson,
  Value<String?> language,
  Value<String> provider,
  Value<int> createdAt,
  Value<int> rowid,
});

final class $$TranscriptsTableTableReferences extends BaseReferences<
    _$VisaryDatabase, $TranscriptsTableTable, TranscriptRow> {
  $$TranscriptsTableTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTableTable _projectIdTable(_$VisaryDatabase db) =>
      db.projectsTable.createAlias('transcripts__project_id__projects__id');

  $$ProjectsTableTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableTableManager($_db, $_db.projectsTable)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$TranscriptsTableTableFilterComposer
    extends Composer<_$VisaryDatabase, $TranscriptsTableTable> {
  $$TranscriptsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get assetId => $composableBuilder(
      column: $table.assetId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fullText => $composableBuilder(
      column: $table.fullText, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get wordsJson => $composableBuilder(
      column: $table.wordsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get language => $composableBuilder(
      column: $table.language, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get provider => $composableBuilder(
      column: $table.provider, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$ProjectsTableTableFilterComposer get projectId {
    final $$ProjectsTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projectsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableTableFilterComposer(
              $db: $db,
              $table: $db.projectsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TranscriptsTableTableOrderingComposer
    extends Composer<_$VisaryDatabase, $TranscriptsTableTable> {
  $$TranscriptsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get assetId => $composableBuilder(
      column: $table.assetId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fullText => $composableBuilder(
      column: $table.fullText, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get wordsJson => $composableBuilder(
      column: $table.wordsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get language => $composableBuilder(
      column: $table.language, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get provider => $composableBuilder(
      column: $table.provider, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$ProjectsTableTableOrderingComposer get projectId {
    final $$ProjectsTableTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projectsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableTableOrderingComposer(
              $db: $db,
              $table: $db.projectsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TranscriptsTableTableAnnotationComposer
    extends Composer<_$VisaryDatabase, $TranscriptsTableTable> {
  $$TranscriptsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);

  GeneratedColumn<String> get fullText =>
      $composableBuilder(column: $table.fullText, builder: (column) => column);

  GeneratedColumn<String> get wordsJson =>
      $composableBuilder(column: $table.wordsJson, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ProjectsTableTableAnnotationComposer get projectId {
    final $$ProjectsTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projectsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableTableAnnotationComposer(
              $db: $db,
              $table: $db.projectsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TranscriptsTableTableTableManager extends RootTableManager<
    _$VisaryDatabase,
    $TranscriptsTableTable,
    TranscriptRow,
    $$TranscriptsTableTableFilterComposer,
    $$TranscriptsTableTableOrderingComposer,
    $$TranscriptsTableTableAnnotationComposer,
    $$TranscriptsTableTableCreateCompanionBuilder,
    $$TranscriptsTableTableUpdateCompanionBuilder,
    (TranscriptRow, $$TranscriptsTableTableReferences),
    TranscriptRow,
    PrefetchHooks Function({bool projectId})> {
  $$TranscriptsTableTableTableManager(
      _$VisaryDatabase db, $TranscriptsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TranscriptsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TranscriptsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TranscriptsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> projectId = const Value.absent(),
            Value<String?> assetId = const Value.absent(),
            Value<String> fullText = const Value.absent(),
            Value<String> wordsJson = const Value.absent(),
            Value<String?> language = const Value.absent(),
            Value<String> provider = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TranscriptsTableCompanion(
            projectId: projectId,
            assetId: assetId,
            fullText: fullText,
            wordsJson: wordsJson,
            language: language,
            provider: provider,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String projectId,
            Value<String?> assetId = const Value.absent(),
            required String fullText,
            required String wordsJson,
            Value<String?> language = const Value.absent(),
            required String provider,
            required int createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              TranscriptsTableCompanion.insert(
            projectId: projectId,
            assetId: assetId,
            fullText: fullText,
            wordsJson: wordsJson,
            language: language,
            provider: provider,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$TranscriptsTableTable, TranscriptRow>(table),
                    $$TranscriptsTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (projectId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.projectId,
                    referencedTable:
                        $$TranscriptsTableTableReferences._projectIdTable(db),
                    referencedColumn: $$TranscriptsTableTableReferences
                        ._projectIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$TranscriptsTableTableProcessedTableManager = ProcessedTableManager<
    _$VisaryDatabase,
    $TranscriptsTableTable,
    TranscriptRow,
    $$TranscriptsTableTableFilterComposer,
    $$TranscriptsTableTableOrderingComposer,
    $$TranscriptsTableTableAnnotationComposer,
    $$TranscriptsTableTableCreateCompanionBuilder,
    $$TranscriptsTableTableUpdateCompanionBuilder,
    (TranscriptRow, $$TranscriptsTableTableReferences),
    TranscriptRow,
    PrefetchHooks Function({bool projectId})>;

class $VisaryDatabaseManager {
  final _$VisaryDatabase _db;
  $VisaryDatabaseManager(this._db);
  $$ProjectsTableTableTableManager get projectsTable =>
      $$ProjectsTableTableTableManager(_db, _db.projectsTable);
  $$ClipsTableTableTableManager get clipsTable =>
      $$ClipsTableTableTableManager(_db, _db.clipsTable);
  $$AssetsTableTableTableManager get assetsTable =>
      $$AssetsTableTableTableManager(_db, _db.assetsTable);
  $$TranscriptsTableTableTableManager get transcriptsTable =>
      $$TranscriptsTableTableTableManager(_db, _db.transcriptsTable);
}
