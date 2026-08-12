// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}key'],
          )!,
      value:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}value'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  final DateTime updatedAt;
  const AppSetting({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AppSetting copyWith({String? key, String? value, DateTime? updatedAt}) =>
      AppSetting(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ArtistsTable extends Artists with TableInfo<$ArtistsTable, Artist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArtistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedNameMeta = const VerificationMeta(
    'normalizedName',
  );
  @override
  late final GeneratedColumn<String> normalizedName = GeneratedColumn<String>(
    'normalized_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    normalizedName,
    imageUrl,
    imagePath,
    provider,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'artists';
  @override
  VerificationContext validateIntegrity(
    Insertable<Artist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('normalized_name')) {
      context.handle(
        _normalizedNameMeta,
        normalizedName.isAcceptableOrUnknown(
          data['normalized_name']!,
          _normalizedNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizedNameMeta);
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Artist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Artist(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      normalizedName:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}normalized_name'],
          )!,
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      ),
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      ),
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
    );
  }

  @override
  $ArtistsTable createAlias(String alias) {
    return $ArtistsTable(attachedDatabase, alias);
  }
}

class Artist extends DataClass implements Insertable<Artist> {
  final String id;
  final String name;
  final String normalizedName;
  final String? imageUrl;
  final String? imagePath;
  final String? provider;
  final DateTime createdAt;
  const Artist({
    required this.id,
    required this.name,
    required this.normalizedName,
    this.imageUrl,
    this.imagePath,
    this.provider,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['normalized_name'] = Variable<String>(normalizedName);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    if (!nullToAbsent || imagePath != null) {
      map['image_path'] = Variable<String>(imagePath);
    }
    if (!nullToAbsent || provider != null) {
      map['provider'] = Variable<String>(provider);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ArtistsCompanion toCompanion(bool nullToAbsent) {
    return ArtistsCompanion(
      id: Value(id),
      name: Value(name),
      normalizedName: Value(normalizedName),
      imageUrl:
          imageUrl == null && nullToAbsent
              ? const Value.absent()
              : Value(imageUrl),
      imagePath:
          imagePath == null && nullToAbsent
              ? const Value.absent()
              : Value(imagePath),
      provider:
          provider == null && nullToAbsent
              ? const Value.absent()
              : Value(provider),
      createdAt: Value(createdAt),
    );
  }

  factory Artist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Artist(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      normalizedName: serializer.fromJson<String>(json['normalizedName']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      imagePath: serializer.fromJson<String?>(json['imagePath']),
      provider: serializer.fromJson<String?>(json['provider']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'normalizedName': serializer.toJson<String>(normalizedName),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'imagePath': serializer.toJson<String?>(imagePath),
      'provider': serializer.toJson<String?>(provider),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Artist copyWith({
    String? id,
    String? name,
    String? normalizedName,
    Value<String?> imageUrl = const Value.absent(),
    Value<String?> imagePath = const Value.absent(),
    Value<String?> provider = const Value.absent(),
    DateTime? createdAt,
  }) => Artist(
    id: id ?? this.id,
    name: name ?? this.name,
    normalizedName: normalizedName ?? this.normalizedName,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    imagePath: imagePath.present ? imagePath.value : this.imagePath,
    provider: provider.present ? provider.value : this.provider,
    createdAt: createdAt ?? this.createdAt,
  );
  Artist copyWithCompanion(ArtistsCompanion data) {
    return Artist(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      normalizedName:
          data.normalizedName.present
              ? data.normalizedName.value
              : this.normalizedName,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      provider: data.provider.present ? data.provider.value : this.provider,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Artist(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('imagePath: $imagePath, ')
          ..write('provider: $provider, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    normalizedName,
    imageUrl,
    imagePath,
    provider,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Artist &&
          other.id == this.id &&
          other.name == this.name &&
          other.normalizedName == this.normalizedName &&
          other.imageUrl == this.imageUrl &&
          other.imagePath == this.imagePath &&
          other.provider == this.provider &&
          other.createdAt == this.createdAt);
}

class ArtistsCompanion extends UpdateCompanion<Artist> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> normalizedName;
  final Value<String?> imageUrl;
  final Value<String?> imagePath;
  final Value<String?> provider;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ArtistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.normalizedName = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.provider = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ArtistsCompanion.insert({
    required String id,
    required String name,
    required String normalizedName,
    this.imageUrl = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.provider = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       normalizedName = Value(normalizedName),
       createdAt = Value(createdAt);
  static Insertable<Artist> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? normalizedName,
    Expression<String>? imageUrl,
    Expression<String>? imagePath,
    Expression<String>? provider,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (normalizedName != null) 'normalized_name': normalizedName,
      if (imageUrl != null) 'image_url': imageUrl,
      if (imagePath != null) 'image_path': imagePath,
      if (provider != null) 'provider': provider,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ArtistsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? normalizedName,
    Value<String?>? imageUrl,
    Value<String?>? imagePath,
    Value<String?>? provider,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ArtistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePath: imagePath ?? this.imagePath,
      provider: provider ?? this.provider,
      createdAt: createdAt ?? this.createdAt,
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
    if (normalizedName.present) {
      map['normalized_name'] = Variable<String>(normalizedName.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArtistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('imagePath: $imagePath, ')
          ..write('provider: $provider, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AlbumsTable extends Albums with TableInfo<$AlbumsTable, Album> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AlbumsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistIdMeta = const VerificationMeta(
    'artistId',
  );
  @override
  late final GeneratedColumn<String> artistId = GeneratedColumn<String>(
    'artist_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES artists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedNameMeta = const VerificationMeta(
    'normalizedName',
  );
  @override
  late final GeneratedColumn<String> normalizedName = GeneratedColumn<String>(
    'normalized_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverPathMeta = const VerificationMeta(
    'coverPath',
  );
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
    'cover_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _releaseDateMeta = const VerificationMeta(
    'releaseDate',
  );
  @override
  late final GeneratedColumn<String> releaseDate = GeneratedColumn<String>(
    'release_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalTracksMeta = const VerificationMeta(
    'totalTracks',
  );
  @override
  late final GeneratedColumn<int> totalTracks = GeneratedColumn<int>(
    'total_tracks',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumTypeMeta = const VerificationMeta(
    'albumType',
  );
  @override
  late final GeneratedColumn<String> albumType = GeneratedColumn<String>(
    'album_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    artistId,
    name,
    normalizedName,
    coverUrl,
    coverPath,
    releaseDate,
    totalTracks,
    albumType,
    provider,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'albums';
  @override
  VerificationContext validateIntegrity(
    Insertable<Album> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('artist_id')) {
      context.handle(
        _artistIdMeta,
        artistId.isAcceptableOrUnknown(data['artist_id']!, _artistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_artistIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('normalized_name')) {
      context.handle(
        _normalizedNameMeta,
        normalizedName.isAcceptableOrUnknown(
          data['normalized_name']!,
          _normalizedNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizedNameMeta);
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
      );
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('release_date')) {
      context.handle(
        _releaseDateMeta,
        releaseDate.isAcceptableOrUnknown(
          data['release_date']!,
          _releaseDateMeta,
        ),
      );
    }
    if (data.containsKey('total_tracks')) {
      context.handle(
        _totalTracksMeta,
        totalTracks.isAcceptableOrUnknown(
          data['total_tracks']!,
          _totalTracksMeta,
        ),
      );
    }
    if (data.containsKey('album_type')) {
      context.handle(
        _albumTypeMeta,
        albumType.isAcceptableOrUnknown(data['album_type']!, _albumTypeMeta),
      );
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Album map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Album(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      artistId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}artist_id'],
          )!,
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      normalizedName:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}normalized_name'],
          )!,
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      ),
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      releaseDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}release_date'],
      ),
      totalTracks: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_tracks'],
      ),
      albumType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_type'],
      ),
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      ),
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
    );
  }

  @override
  $AlbumsTable createAlias(String alias) {
    return $AlbumsTable(attachedDatabase, alias);
  }
}

class Album extends DataClass implements Insertable<Album> {
  final String id;
  final String artistId;
  final String name;
  final String normalizedName;
  final String? coverUrl;
  final String? coverPath;
  final String? releaseDate;
  final int? totalTracks;
  final String? albumType;
  final String? provider;
  final DateTime createdAt;
  const Album({
    required this.id,
    required this.artistId,
    required this.name,
    required this.normalizedName,
    this.coverUrl,
    this.coverPath,
    this.releaseDate,
    this.totalTracks,
    this.albumType,
    this.provider,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['artist_id'] = Variable<String>(artistId);
    map['name'] = Variable<String>(name);
    map['normalized_name'] = Variable<String>(normalizedName);
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    if (!nullToAbsent || releaseDate != null) {
      map['release_date'] = Variable<String>(releaseDate);
    }
    if (!nullToAbsent || totalTracks != null) {
      map['total_tracks'] = Variable<int>(totalTracks);
    }
    if (!nullToAbsent || albumType != null) {
      map['album_type'] = Variable<String>(albumType);
    }
    if (!nullToAbsent || provider != null) {
      map['provider'] = Variable<String>(provider);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AlbumsCompanion toCompanion(bool nullToAbsent) {
    return AlbumsCompanion(
      id: Value(id),
      artistId: Value(artistId),
      name: Value(name),
      normalizedName: Value(normalizedName),
      coverUrl:
          coverUrl == null && nullToAbsent
              ? const Value.absent()
              : Value(coverUrl),
      coverPath:
          coverPath == null && nullToAbsent
              ? const Value.absent()
              : Value(coverPath),
      releaseDate:
          releaseDate == null && nullToAbsent
              ? const Value.absent()
              : Value(releaseDate),
      totalTracks:
          totalTracks == null && nullToAbsent
              ? const Value.absent()
              : Value(totalTracks),
      albumType:
          albumType == null && nullToAbsent
              ? const Value.absent()
              : Value(albumType),
      provider:
          provider == null && nullToAbsent
              ? const Value.absent()
              : Value(provider),
      createdAt: Value(createdAt),
    );
  }

  factory Album.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Album(
      id: serializer.fromJson<String>(json['id']),
      artistId: serializer.fromJson<String>(json['artistId']),
      name: serializer.fromJson<String>(json['name']),
      normalizedName: serializer.fromJson<String>(json['normalizedName']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      releaseDate: serializer.fromJson<String?>(json['releaseDate']),
      totalTracks: serializer.fromJson<int?>(json['totalTracks']),
      albumType: serializer.fromJson<String?>(json['albumType']),
      provider: serializer.fromJson<String?>(json['provider']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'artistId': serializer.toJson<String>(artistId),
      'name': serializer.toJson<String>(name),
      'normalizedName': serializer.toJson<String>(normalizedName),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'coverPath': serializer.toJson<String?>(coverPath),
      'releaseDate': serializer.toJson<String?>(releaseDate),
      'totalTracks': serializer.toJson<int?>(totalTracks),
      'albumType': serializer.toJson<String?>(albumType),
      'provider': serializer.toJson<String?>(provider),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Album copyWith({
    String? id,
    String? artistId,
    String? name,
    String? normalizedName,
    Value<String?> coverUrl = const Value.absent(),
    Value<String?> coverPath = const Value.absent(),
    Value<String?> releaseDate = const Value.absent(),
    Value<int?> totalTracks = const Value.absent(),
    Value<String?> albumType = const Value.absent(),
    Value<String?> provider = const Value.absent(),
    DateTime? createdAt,
  }) => Album(
    id: id ?? this.id,
    artistId: artistId ?? this.artistId,
    name: name ?? this.name,
    normalizedName: normalizedName ?? this.normalizedName,
    coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    releaseDate: releaseDate.present ? releaseDate.value : this.releaseDate,
    totalTracks: totalTracks.present ? totalTracks.value : this.totalTracks,
    albumType: albumType.present ? albumType.value : this.albumType,
    provider: provider.present ? provider.value : this.provider,
    createdAt: createdAt ?? this.createdAt,
  );
  Album copyWithCompanion(AlbumsCompanion data) {
    return Album(
      id: data.id.present ? data.id.value : this.id,
      artistId: data.artistId.present ? data.artistId.value : this.artistId,
      name: data.name.present ? data.name.value : this.name,
      normalizedName:
          data.normalizedName.present
              ? data.normalizedName.value
              : this.normalizedName,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      releaseDate:
          data.releaseDate.present ? data.releaseDate.value : this.releaseDate,
      totalTracks:
          data.totalTracks.present ? data.totalTracks.value : this.totalTracks,
      albumType: data.albumType.present ? data.albumType.value : this.albumType,
      provider: data.provider.present ? data.provider.value : this.provider,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Album(')
          ..write('id: $id, ')
          ..write('artistId: $artistId, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('coverPath: $coverPath, ')
          ..write('releaseDate: $releaseDate, ')
          ..write('totalTracks: $totalTracks, ')
          ..write('albumType: $albumType, ')
          ..write('provider: $provider, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    artistId,
    name,
    normalizedName,
    coverUrl,
    coverPath,
    releaseDate,
    totalTracks,
    albumType,
    provider,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Album &&
          other.id == this.id &&
          other.artistId == this.artistId &&
          other.name == this.name &&
          other.normalizedName == this.normalizedName &&
          other.coverUrl == this.coverUrl &&
          other.coverPath == this.coverPath &&
          other.releaseDate == this.releaseDate &&
          other.totalTracks == this.totalTracks &&
          other.albumType == this.albumType &&
          other.provider == this.provider &&
          other.createdAt == this.createdAt);
}

class AlbumsCompanion extends UpdateCompanion<Album> {
  final Value<String> id;
  final Value<String> artistId;
  final Value<String> name;
  final Value<String> normalizedName;
  final Value<String?> coverUrl;
  final Value<String?> coverPath;
  final Value<String?> releaseDate;
  final Value<int?> totalTracks;
  final Value<String?> albumType;
  final Value<String?> provider;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AlbumsCompanion({
    this.id = const Value.absent(),
    this.artistId = const Value.absent(),
    this.name = const Value.absent(),
    this.normalizedName = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.releaseDate = const Value.absent(),
    this.totalTracks = const Value.absent(),
    this.albumType = const Value.absent(),
    this.provider = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AlbumsCompanion.insert({
    required String id,
    required String artistId,
    required String name,
    required String normalizedName,
    this.coverUrl = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.releaseDate = const Value.absent(),
    this.totalTracks = const Value.absent(),
    this.albumType = const Value.absent(),
    this.provider = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       artistId = Value(artistId),
       name = Value(name),
       normalizedName = Value(normalizedName),
       createdAt = Value(createdAt);
  static Insertable<Album> custom({
    Expression<String>? id,
    Expression<String>? artistId,
    Expression<String>? name,
    Expression<String>? normalizedName,
    Expression<String>? coverUrl,
    Expression<String>? coverPath,
    Expression<String>? releaseDate,
    Expression<int>? totalTracks,
    Expression<String>? albumType,
    Expression<String>? provider,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (artistId != null) 'artist_id': artistId,
      if (name != null) 'name': name,
      if (normalizedName != null) 'normalized_name': normalizedName,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (coverPath != null) 'cover_path': coverPath,
      if (releaseDate != null) 'release_date': releaseDate,
      if (totalTracks != null) 'total_tracks': totalTracks,
      if (albumType != null) 'album_type': albumType,
      if (provider != null) 'provider': provider,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AlbumsCompanion copyWith({
    Value<String>? id,
    Value<String>? artistId,
    Value<String>? name,
    Value<String>? normalizedName,
    Value<String?>? coverUrl,
    Value<String?>? coverPath,
    Value<String?>? releaseDate,
    Value<int?>? totalTracks,
    Value<String?>? albumType,
    Value<String?>? provider,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return AlbumsCompanion(
      id: id ?? this.id,
      artistId: artistId ?? this.artistId,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      coverUrl: coverUrl ?? this.coverUrl,
      coverPath: coverPath ?? this.coverPath,
      releaseDate: releaseDate ?? this.releaseDate,
      totalTracks: totalTracks ?? this.totalTracks,
      albumType: albumType ?? this.albumType,
      provider: provider ?? this.provider,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (artistId.present) {
      map['artist_id'] = Variable<String>(artistId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (normalizedName.present) {
      map['normalized_name'] = Variable<String>(normalizedName.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (releaseDate.present) {
      map['release_date'] = Variable<String>(releaseDate.value);
    }
    if (totalTracks.present) {
      map['total_tracks'] = Variable<int>(totalTracks.value);
    }
    if (albumType.present) {
      map['album_type'] = Variable<String>(albumType.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AlbumsCompanion(')
          ..write('id: $id, ')
          ..write('artistId: $artistId, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('coverPath: $coverPath, ')
          ..write('releaseDate: $releaseDate, ')
          ..write('totalTracks: $totalTracks, ')
          ..write('albumType: $albumType, ')
          ..write('provider: $provider, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TracksTable extends Tracks with TableInfo<$TracksTable, Track> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistIdMeta = const VerificationMeta(
    'artistId',
  );
  @override
  late final GeneratedColumn<String> artistId = GeneratedColumn<String>(
    'artist_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES artists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _albumIdMeta = const VerificationMeta(
    'albumId',
  );
  @override
  late final GeneratedColumn<String> albumId = GeneratedColumn<String>(
    'album_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES albums (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _isrcMeta = const VerificationMeta('isrc');
  @override
  late final GeneratedColumn<String> isrc = GeneratedColumn<String>(
    'isrc',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trackNumberMeta = const VerificationMeta(
    'trackNumber',
  );
  @override
  late final GeneratedColumn<int> trackNumber = GeneratedColumn<int>(
    'track_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalTracksMeta = const VerificationMeta(
    'totalTracks',
  );
  @override
  late final GeneratedColumn<int> totalTracks = GeneratedColumn<int>(
    'total_tracks',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _discNumberMeta = const VerificationMeta(
    'discNumber',
  );
  @override
  late final GeneratedColumn<int> discNumber = GeneratedColumn<int>(
    'disc_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalDiscsMeta = const VerificationMeta(
    'totalDiscs',
  );
  @override
  late final GeneratedColumn<int> totalDiscs = GeneratedColumn<int>(
    'total_discs',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _releaseDateMeta = const VerificationMeta(
    'releaseDate',
  );
  @override
  late final GeneratedColumn<String> releaseDate = GeneratedColumn<String>(
    'release_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _composerMeta = const VerificationMeta(
    'composer',
  );
  @override
  late final GeneratedColumn<String> composer = GeneratedColumn<String>(
    'composer',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _copyrightMeta = const VerificationMeta(
    'copyright',
  );
  @override
  late final GeneratedColumn<String> copyright = GeneratedColumn<String>(
    'copyright',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverPathMeta = const VerificationMeta(
    'coverPath',
  );
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
    'cover_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _videoPathMeta = const VerificationMeta(
    'videoPath',
  );
  @override
  late final GeneratedColumn<String> videoPath = GeneratedColumn<String>(
    'video_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lyricsPathMeta = const VerificationMeta(
    'lyricsPath',
  );
  @override
  late final GeneratedColumn<String> lyricsPath = GeneratedColumn<String>(
    'lyrics_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _spotifyIdMeta = const VerificationMeta(
    'spotifyId',
  );
  @override
  late final GeneratedColumn<String> spotifyId = GeneratedColumn<String>(
    'spotify_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    artistId,
    albumId,
    isrc,
    durationMs,
    trackNumber,
    totalTracks,
    discNumber,
    totalDiscs,
    releaseDate,
    genre,
    composer,
    label,
    copyright,
    coverUrl,
    coverPath,
    videoPath,
    lyricsPath,
    spotifyId,
    source,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Track> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('artist_id')) {
      context.handle(
        _artistIdMeta,
        artistId.isAcceptableOrUnknown(data['artist_id']!, _artistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_artistIdMeta);
    }
    if (data.containsKey('album_id')) {
      context.handle(
        _albumIdMeta,
        albumId.isAcceptableOrUnknown(data['album_id']!, _albumIdMeta),
      );
    } else if (isInserting) {
      context.missing(_albumIdMeta);
    }
    if (data.containsKey('isrc')) {
      context.handle(
        _isrcMeta,
        isrc.isAcceptableOrUnknown(data['isrc']!, _isrcMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('track_number')) {
      context.handle(
        _trackNumberMeta,
        trackNumber.isAcceptableOrUnknown(
          data['track_number']!,
          _trackNumberMeta,
        ),
      );
    }
    if (data.containsKey('total_tracks')) {
      context.handle(
        _totalTracksMeta,
        totalTracks.isAcceptableOrUnknown(
          data['total_tracks']!,
          _totalTracksMeta,
        ),
      );
    }
    if (data.containsKey('disc_number')) {
      context.handle(
        _discNumberMeta,
        discNumber.isAcceptableOrUnknown(data['disc_number']!, _discNumberMeta),
      );
    }
    if (data.containsKey('total_discs')) {
      context.handle(
        _totalDiscsMeta,
        totalDiscs.isAcceptableOrUnknown(data['total_discs']!, _totalDiscsMeta),
      );
    }
    if (data.containsKey('release_date')) {
      context.handle(
        _releaseDateMeta,
        releaseDate.isAcceptableOrUnknown(
          data['release_date']!,
          _releaseDateMeta,
        ),
      );
    }
    if (data.containsKey('genre')) {
      context.handle(
        _genreMeta,
        genre.isAcceptableOrUnknown(data['genre']!, _genreMeta),
      );
    }
    if (data.containsKey('composer')) {
      context.handle(
        _composerMeta,
        composer.isAcceptableOrUnknown(data['composer']!, _composerMeta),
      );
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('copyright')) {
      context.handle(
        _copyrightMeta,
        copyright.isAcceptableOrUnknown(data['copyright']!, _copyrightMeta),
      );
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
      );
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('video_path')) {
      context.handle(
        _videoPathMeta,
        videoPath.isAcceptableOrUnknown(data['video_path']!, _videoPathMeta),
      );
    }
    if (data.containsKey('lyrics_path')) {
      context.handle(
        _lyricsPathMeta,
        lyricsPath.isAcceptableOrUnknown(data['lyrics_path']!, _lyricsPathMeta),
      );
    }
    if (data.containsKey('spotify_id')) {
      context.handle(
        _spotifyIdMeta,
        spotifyId.isAcceptableOrUnknown(data['spotify_id']!, _spotifyIdMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Track map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Track(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      artistId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}artist_id'],
          )!,
      albumId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}album_id'],
          )!,
      isrc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}isrc'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      trackNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_number'],
      ),
      totalTracks: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_tracks'],
      ),
      discNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}disc_number'],
      ),
      totalDiscs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_discs'],
      ),
      releaseDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}release_date'],
      ),
      genre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre'],
      ),
      composer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}composer'],
      ),
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      copyright: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}copyright'],
      ),
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      ),
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      videoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_path'],
      ),
      lyricsPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lyrics_path'],
      ),
      spotifyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}spotify_id'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      ),
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
    );
  }

  @override
  $TracksTable createAlias(String alias) {
    return $TracksTable(attachedDatabase, alias);
  }
}

class Track extends DataClass implements Insertable<Track> {
  final String id;
  final String name;
  final String artistId;
  final String albumId;
  final String? isrc;
  final int? durationMs;
  final int? trackNumber;
  final int? totalTracks;
  final int? discNumber;
  final int? totalDiscs;
  final String? releaseDate;
  final String? genre;
  final String? composer;
  final String? label;
  final String? copyright;
  final String? coverUrl;
  final String? coverPath;
  final String? videoPath;
  final String? lyricsPath;
  final String? spotifyId;
  final String? source;
  final DateTime createdAt;
  const Track({
    required this.id,
    required this.name,
    required this.artistId,
    required this.albumId,
    this.isrc,
    this.durationMs,
    this.trackNumber,
    this.totalTracks,
    this.discNumber,
    this.totalDiscs,
    this.releaseDate,
    this.genre,
    this.composer,
    this.label,
    this.copyright,
    this.coverUrl,
    this.coverPath,
    this.videoPath,
    this.lyricsPath,
    this.spotifyId,
    this.source,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['artist_id'] = Variable<String>(artistId);
    map['album_id'] = Variable<String>(albumId);
    if (!nullToAbsent || isrc != null) {
      map['isrc'] = Variable<String>(isrc);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    if (!nullToAbsent || trackNumber != null) {
      map['track_number'] = Variable<int>(trackNumber);
    }
    if (!nullToAbsent || totalTracks != null) {
      map['total_tracks'] = Variable<int>(totalTracks);
    }
    if (!nullToAbsent || discNumber != null) {
      map['disc_number'] = Variable<int>(discNumber);
    }
    if (!nullToAbsent || totalDiscs != null) {
      map['total_discs'] = Variable<int>(totalDiscs);
    }
    if (!nullToAbsent || releaseDate != null) {
      map['release_date'] = Variable<String>(releaseDate);
    }
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    if (!nullToAbsent || composer != null) {
      map['composer'] = Variable<String>(composer);
    }
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    if (!nullToAbsent || copyright != null) {
      map['copyright'] = Variable<String>(copyright);
    }
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    if (!nullToAbsent || videoPath != null) {
      map['video_path'] = Variable<String>(videoPath);
    }
    if (!nullToAbsent || lyricsPath != null) {
      map['lyrics_path'] = Variable<String>(lyricsPath);
    }
    if (!nullToAbsent || spotifyId != null) {
      map['spotify_id'] = Variable<String>(spotifyId);
    }
    if (!nullToAbsent || source != null) {
      map['source'] = Variable<String>(source);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TracksCompanion toCompanion(bool nullToAbsent) {
    return TracksCompanion(
      id: Value(id),
      name: Value(name),
      artistId: Value(artistId),
      albumId: Value(albumId),
      isrc: isrc == null && nullToAbsent ? const Value.absent() : Value(isrc),
      durationMs:
          durationMs == null && nullToAbsent
              ? const Value.absent()
              : Value(durationMs),
      trackNumber:
          trackNumber == null && nullToAbsent
              ? const Value.absent()
              : Value(trackNumber),
      totalTracks:
          totalTracks == null && nullToAbsent
              ? const Value.absent()
              : Value(totalTracks),
      discNumber:
          discNumber == null && nullToAbsent
              ? const Value.absent()
              : Value(discNumber),
      totalDiscs:
          totalDiscs == null && nullToAbsent
              ? const Value.absent()
              : Value(totalDiscs),
      releaseDate:
          releaseDate == null && nullToAbsent
              ? const Value.absent()
              : Value(releaseDate),
      genre:
          genre == null && nullToAbsent ? const Value.absent() : Value(genre),
      composer:
          composer == null && nullToAbsent
              ? const Value.absent()
              : Value(composer),
      label:
          label == null && nullToAbsent ? const Value.absent() : Value(label),
      copyright:
          copyright == null && nullToAbsent
              ? const Value.absent()
              : Value(copyright),
      coverUrl:
          coverUrl == null && nullToAbsent
              ? const Value.absent()
              : Value(coverUrl),
      coverPath:
          coverPath == null && nullToAbsent
              ? const Value.absent()
              : Value(coverPath),
      videoPath:
          videoPath == null && nullToAbsent
              ? const Value.absent()
              : Value(videoPath),
      lyricsPath:
          lyricsPath == null && nullToAbsent
              ? const Value.absent()
              : Value(lyricsPath),
      spotifyId:
          spotifyId == null && nullToAbsent
              ? const Value.absent()
              : Value(spotifyId),
      source:
          source == null && nullToAbsent ? const Value.absent() : Value(source),
      createdAt: Value(createdAt),
    );
  }

  factory Track.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Track(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      artistId: serializer.fromJson<String>(json['artistId']),
      albumId: serializer.fromJson<String>(json['albumId']),
      isrc: serializer.fromJson<String?>(json['isrc']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      trackNumber: serializer.fromJson<int?>(json['trackNumber']),
      totalTracks: serializer.fromJson<int?>(json['totalTracks']),
      discNumber: serializer.fromJson<int?>(json['discNumber']),
      totalDiscs: serializer.fromJson<int?>(json['totalDiscs']),
      releaseDate: serializer.fromJson<String?>(json['releaseDate']),
      genre: serializer.fromJson<String?>(json['genre']),
      composer: serializer.fromJson<String?>(json['composer']),
      label: serializer.fromJson<String?>(json['label']),
      copyright: serializer.fromJson<String?>(json['copyright']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      videoPath: serializer.fromJson<String?>(json['videoPath']),
      lyricsPath: serializer.fromJson<String?>(json['lyricsPath']),
      spotifyId: serializer.fromJson<String?>(json['spotifyId']),
      source: serializer.fromJson<String?>(json['source']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'artistId': serializer.toJson<String>(artistId),
      'albumId': serializer.toJson<String>(albumId),
      'isrc': serializer.toJson<String?>(isrc),
      'durationMs': serializer.toJson<int?>(durationMs),
      'trackNumber': serializer.toJson<int?>(trackNumber),
      'totalTracks': serializer.toJson<int?>(totalTracks),
      'discNumber': serializer.toJson<int?>(discNumber),
      'totalDiscs': serializer.toJson<int?>(totalDiscs),
      'releaseDate': serializer.toJson<String?>(releaseDate),
      'genre': serializer.toJson<String?>(genre),
      'composer': serializer.toJson<String?>(composer),
      'label': serializer.toJson<String?>(label),
      'copyright': serializer.toJson<String?>(copyright),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'coverPath': serializer.toJson<String?>(coverPath),
      'videoPath': serializer.toJson<String?>(videoPath),
      'lyricsPath': serializer.toJson<String?>(lyricsPath),
      'spotifyId': serializer.toJson<String?>(spotifyId),
      'source': serializer.toJson<String?>(source),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Track copyWith({
    String? id,
    String? name,
    String? artistId,
    String? albumId,
    Value<String?> isrc = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    Value<int?> trackNumber = const Value.absent(),
    Value<int?> totalTracks = const Value.absent(),
    Value<int?> discNumber = const Value.absent(),
    Value<int?> totalDiscs = const Value.absent(),
    Value<String?> releaseDate = const Value.absent(),
    Value<String?> genre = const Value.absent(),
    Value<String?> composer = const Value.absent(),
    Value<String?> label = const Value.absent(),
    Value<String?> copyright = const Value.absent(),
    Value<String?> coverUrl = const Value.absent(),
    Value<String?> coverPath = const Value.absent(),
    Value<String?> videoPath = const Value.absent(),
    Value<String?> lyricsPath = const Value.absent(),
    Value<String?> spotifyId = const Value.absent(),
    Value<String?> source = const Value.absent(),
    DateTime? createdAt,
  }) => Track(
    id: id ?? this.id,
    name: name ?? this.name,
    artistId: artistId ?? this.artistId,
    albumId: albumId ?? this.albumId,
    isrc: isrc.present ? isrc.value : this.isrc,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    trackNumber: trackNumber.present ? trackNumber.value : this.trackNumber,
    totalTracks: totalTracks.present ? totalTracks.value : this.totalTracks,
    discNumber: discNumber.present ? discNumber.value : this.discNumber,
    totalDiscs: totalDiscs.present ? totalDiscs.value : this.totalDiscs,
    releaseDate: releaseDate.present ? releaseDate.value : this.releaseDate,
    genre: genre.present ? genre.value : this.genre,
    composer: composer.present ? composer.value : this.composer,
    label: label.present ? label.value : this.label,
    copyright: copyright.present ? copyright.value : this.copyright,
    coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    videoPath: videoPath.present ? videoPath.value : this.videoPath,
    lyricsPath: lyricsPath.present ? lyricsPath.value : this.lyricsPath,
    spotifyId: spotifyId.present ? spotifyId.value : this.spotifyId,
    source: source.present ? source.value : this.source,
    createdAt: createdAt ?? this.createdAt,
  );
  Track copyWithCompanion(TracksCompanion data) {
    return Track(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      artistId: data.artistId.present ? data.artistId.value : this.artistId,
      albumId: data.albumId.present ? data.albumId.value : this.albumId,
      isrc: data.isrc.present ? data.isrc.value : this.isrc,
      durationMs:
          data.durationMs.present ? data.durationMs.value : this.durationMs,
      trackNumber:
          data.trackNumber.present ? data.trackNumber.value : this.trackNumber,
      totalTracks:
          data.totalTracks.present ? data.totalTracks.value : this.totalTracks,
      discNumber:
          data.discNumber.present ? data.discNumber.value : this.discNumber,
      totalDiscs:
          data.totalDiscs.present ? data.totalDiscs.value : this.totalDiscs,
      releaseDate:
          data.releaseDate.present ? data.releaseDate.value : this.releaseDate,
      genre: data.genre.present ? data.genre.value : this.genre,
      composer: data.composer.present ? data.composer.value : this.composer,
      label: data.label.present ? data.label.value : this.label,
      copyright: data.copyright.present ? data.copyright.value : this.copyright,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      videoPath: data.videoPath.present ? data.videoPath.value : this.videoPath,
      lyricsPath:
          data.lyricsPath.present ? data.lyricsPath.value : this.lyricsPath,
      spotifyId: data.spotifyId.present ? data.spotifyId.value : this.spotifyId,
      source: data.source.present ? data.source.value : this.source,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Track(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('artistId: $artistId, ')
          ..write('albumId: $albumId, ')
          ..write('isrc: $isrc, ')
          ..write('durationMs: $durationMs, ')
          ..write('trackNumber: $trackNumber, ')
          ..write('totalTracks: $totalTracks, ')
          ..write('discNumber: $discNumber, ')
          ..write('totalDiscs: $totalDiscs, ')
          ..write('releaseDate: $releaseDate, ')
          ..write('genre: $genre, ')
          ..write('composer: $composer, ')
          ..write('label: $label, ')
          ..write('copyright: $copyright, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('coverPath: $coverPath, ')
          ..write('videoPath: $videoPath, ')
          ..write('lyricsPath: $lyricsPath, ')
          ..write('spotifyId: $spotifyId, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    artistId,
    albumId,
    isrc,
    durationMs,
    trackNumber,
    totalTracks,
    discNumber,
    totalDiscs,
    releaseDate,
    genre,
    composer,
    label,
    copyright,
    coverUrl,
    coverPath,
    videoPath,
    lyricsPath,
    spotifyId,
    source,
    createdAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Track &&
          other.id == this.id &&
          other.name == this.name &&
          other.artistId == this.artistId &&
          other.albumId == this.albumId &&
          other.isrc == this.isrc &&
          other.durationMs == this.durationMs &&
          other.trackNumber == this.trackNumber &&
          other.totalTracks == this.totalTracks &&
          other.discNumber == this.discNumber &&
          other.totalDiscs == this.totalDiscs &&
          other.releaseDate == this.releaseDate &&
          other.genre == this.genre &&
          other.composer == this.composer &&
          other.label == this.label &&
          other.copyright == this.copyright &&
          other.coverUrl == this.coverUrl &&
          other.coverPath == this.coverPath &&
          other.videoPath == this.videoPath &&
          other.lyricsPath == this.lyricsPath &&
          other.spotifyId == this.spotifyId &&
          other.source == this.source &&
          other.createdAt == this.createdAt);
}

class TracksCompanion extends UpdateCompanion<Track> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> artistId;
  final Value<String> albumId;
  final Value<String?> isrc;
  final Value<int?> durationMs;
  final Value<int?> trackNumber;
  final Value<int?> totalTracks;
  final Value<int?> discNumber;
  final Value<int?> totalDiscs;
  final Value<String?> releaseDate;
  final Value<String?> genre;
  final Value<String?> composer;
  final Value<String?> label;
  final Value<String?> copyright;
  final Value<String?> coverUrl;
  final Value<String?> coverPath;
  final Value<String?> videoPath;
  final Value<String?> lyricsPath;
  final Value<String?> spotifyId;
  final Value<String?> source;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const TracksCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.artistId = const Value.absent(),
    this.albumId = const Value.absent(),
    this.isrc = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.trackNumber = const Value.absent(),
    this.totalTracks = const Value.absent(),
    this.discNumber = const Value.absent(),
    this.totalDiscs = const Value.absent(),
    this.releaseDate = const Value.absent(),
    this.genre = const Value.absent(),
    this.composer = const Value.absent(),
    this.label = const Value.absent(),
    this.copyright = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.videoPath = const Value.absent(),
    this.lyricsPath = const Value.absent(),
    this.spotifyId = const Value.absent(),
    this.source = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TracksCompanion.insert({
    required String id,
    required String name,
    required String artistId,
    required String albumId,
    this.isrc = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.trackNumber = const Value.absent(),
    this.totalTracks = const Value.absent(),
    this.discNumber = const Value.absent(),
    this.totalDiscs = const Value.absent(),
    this.releaseDate = const Value.absent(),
    this.genre = const Value.absent(),
    this.composer = const Value.absent(),
    this.label = const Value.absent(),
    this.copyright = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.videoPath = const Value.absent(),
    this.lyricsPath = const Value.absent(),
    this.spotifyId = const Value.absent(),
    this.source = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       artistId = Value(artistId),
       albumId = Value(albumId),
       createdAt = Value(createdAt);
  static Insertable<Track> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? artistId,
    Expression<String>? albumId,
    Expression<String>? isrc,
    Expression<int>? durationMs,
    Expression<int>? trackNumber,
    Expression<int>? totalTracks,
    Expression<int>? discNumber,
    Expression<int>? totalDiscs,
    Expression<String>? releaseDate,
    Expression<String>? genre,
    Expression<String>? composer,
    Expression<String>? label,
    Expression<String>? copyright,
    Expression<String>? coverUrl,
    Expression<String>? coverPath,
    Expression<String>? videoPath,
    Expression<String>? lyricsPath,
    Expression<String>? spotifyId,
    Expression<String>? source,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (artistId != null) 'artist_id': artistId,
      if (albumId != null) 'album_id': albumId,
      if (isrc != null) 'isrc': isrc,
      if (durationMs != null) 'duration_ms': durationMs,
      if (trackNumber != null) 'track_number': trackNumber,
      if (totalTracks != null) 'total_tracks': totalTracks,
      if (discNumber != null) 'disc_number': discNumber,
      if (totalDiscs != null) 'total_discs': totalDiscs,
      if (releaseDate != null) 'release_date': releaseDate,
      if (genre != null) 'genre': genre,
      if (composer != null) 'composer': composer,
      if (label != null) 'label': label,
      if (copyright != null) 'copyright': copyright,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (coverPath != null) 'cover_path': coverPath,
      if (videoPath != null) 'video_path': videoPath,
      if (lyricsPath != null) 'lyrics_path': lyricsPath,
      if (spotifyId != null) 'spotify_id': spotifyId,
      if (source != null) 'source': source,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TracksCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? artistId,
    Value<String>? albumId,
    Value<String?>? isrc,
    Value<int?>? durationMs,
    Value<int?>? trackNumber,
    Value<int?>? totalTracks,
    Value<int?>? discNumber,
    Value<int?>? totalDiscs,
    Value<String?>? releaseDate,
    Value<String?>? genre,
    Value<String?>? composer,
    Value<String?>? label,
    Value<String?>? copyright,
    Value<String?>? coverUrl,
    Value<String?>? coverPath,
    Value<String?>? videoPath,
    Value<String?>? lyricsPath,
    Value<String?>? spotifyId,
    Value<String?>? source,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return TracksCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      artistId: artistId ?? this.artistId,
      albumId: albumId ?? this.albumId,
      isrc: isrc ?? this.isrc,
      durationMs: durationMs ?? this.durationMs,
      trackNumber: trackNumber ?? this.trackNumber,
      totalTracks: totalTracks ?? this.totalTracks,
      discNumber: discNumber ?? this.discNumber,
      totalDiscs: totalDiscs ?? this.totalDiscs,
      releaseDate: releaseDate ?? this.releaseDate,
      genre: genre ?? this.genre,
      composer: composer ?? this.composer,
      label: label ?? this.label,
      copyright: copyright ?? this.copyright,
      coverUrl: coverUrl ?? this.coverUrl,
      coverPath: coverPath ?? this.coverPath,
      videoPath: videoPath ?? this.videoPath,
      lyricsPath: lyricsPath ?? this.lyricsPath,
      spotifyId: spotifyId ?? this.spotifyId,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
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
    if (artistId.present) {
      map['artist_id'] = Variable<String>(artistId.value);
    }
    if (albumId.present) {
      map['album_id'] = Variable<String>(albumId.value);
    }
    if (isrc.present) {
      map['isrc'] = Variable<String>(isrc.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (trackNumber.present) {
      map['track_number'] = Variable<int>(trackNumber.value);
    }
    if (totalTracks.present) {
      map['total_tracks'] = Variable<int>(totalTracks.value);
    }
    if (discNumber.present) {
      map['disc_number'] = Variable<int>(discNumber.value);
    }
    if (totalDiscs.present) {
      map['total_discs'] = Variable<int>(totalDiscs.value);
    }
    if (releaseDate.present) {
      map['release_date'] = Variable<String>(releaseDate.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (composer.present) {
      map['composer'] = Variable<String>(composer.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (copyright.present) {
      map['copyright'] = Variable<String>(copyright.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (videoPath.present) {
      map['video_path'] = Variable<String>(videoPath.value);
    }
    if (lyricsPath.present) {
      map['lyrics_path'] = Variable<String>(lyricsPath.value);
    }
    if (spotifyId.present) {
      map['spotify_id'] = Variable<String>(spotifyId.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TracksCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('artistId: $artistId, ')
          ..write('albumId: $albumId, ')
          ..write('isrc: $isrc, ')
          ..write('durationMs: $durationMs, ')
          ..write('trackNumber: $trackNumber, ')
          ..write('totalTracks: $totalTracks, ')
          ..write('discNumber: $discNumber, ')
          ..write('totalDiscs: $totalDiscs, ')
          ..write('releaseDate: $releaseDate, ')
          ..write('genre: $genre, ')
          ..write('composer: $composer, ')
          ..write('label: $label, ')
          ..write('copyright: $copyright, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('coverPath: $coverPath, ')
          ..write('videoPath: $videoPath, ')
          ..write('lyricsPath: $lyricsPath, ')
          ..write('spotifyId: $spotifyId, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SourcesTable extends Sources with TableInfo<$SourcesTable, Source> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tracks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _externalIdMeta = const VerificationMeta(
    'externalId',
  );
  @override
  late final GeneratedColumn<String> externalId = GeneratedColumn<String>(
    'external_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qualityMeta = const VerificationMeta(
    'quality',
  );
  @override
  late final GeneratedColumn<String> quality = GeneratedColumn<String>(
    'quality',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioQualityMeta = const VerificationMeta(
    'audioQuality',
  );
  @override
  late final GeneratedColumn<String> audioQuality = GeneratedColumn<String>(
    'audio_quality',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metadataJsonMeta = const VerificationMeta(
    'metadataJson',
  );
  @override
  late final GeneratedColumn<String> metadataJson = GeneratedColumn<String>(
    'metadata_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    trackId,
    provider,
    externalId,
    quality,
    audioQuality,
    coverUrl,
    metadataJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<Source> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('external_id')) {
      context.handle(
        _externalIdMeta,
        externalId.isAcceptableOrUnknown(data['external_id']!, _externalIdMeta),
      );
    } else if (isInserting) {
      context.missing(_externalIdMeta);
    }
    if (data.containsKey('quality')) {
      context.handle(
        _qualityMeta,
        quality.isAcceptableOrUnknown(data['quality']!, _qualityMeta),
      );
    }
    if (data.containsKey('audio_quality')) {
      context.handle(
        _audioQualityMeta,
        audioQuality.isAcceptableOrUnknown(
          data['audio_quality']!,
          _audioQualityMeta,
        ),
      );
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
      );
    }
    if (data.containsKey('metadata_json')) {
      context.handle(
        _metadataJsonMeta,
        metadataJson.isAcceptableOrUnknown(
          data['metadata_json']!,
          _metadataJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Source map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Source(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      trackId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}track_id'],
          )!,
      provider:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}provider'],
          )!,
      externalId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}external_id'],
          )!,
      quality: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quality'],
      ),
      audioQuality: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_quality'],
      ),
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      ),
      metadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata_json'],
      ),
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
    );
  }

  @override
  $SourcesTable createAlias(String alias) {
    return $SourcesTable(attachedDatabase, alias);
  }
}

class Source extends DataClass implements Insertable<Source> {
  final String id;
  final String trackId;
  final String provider;
  final String externalId;
  final String? quality;
  final String? audioQuality;
  final String? coverUrl;
  final String? metadataJson;
  final DateTime createdAt;
  const Source({
    required this.id,
    required this.trackId,
    required this.provider,
    required this.externalId,
    this.quality,
    this.audioQuality,
    this.coverUrl,
    this.metadataJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['track_id'] = Variable<String>(trackId);
    map['provider'] = Variable<String>(provider);
    map['external_id'] = Variable<String>(externalId);
    if (!nullToAbsent || quality != null) {
      map['quality'] = Variable<String>(quality);
    }
    if (!nullToAbsent || audioQuality != null) {
      map['audio_quality'] = Variable<String>(audioQuality);
    }
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    if (!nullToAbsent || metadataJson != null) {
      map['metadata_json'] = Variable<String>(metadataJson);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SourcesCompanion toCompanion(bool nullToAbsent) {
    return SourcesCompanion(
      id: Value(id),
      trackId: Value(trackId),
      provider: Value(provider),
      externalId: Value(externalId),
      quality:
          quality == null && nullToAbsent
              ? const Value.absent()
              : Value(quality),
      audioQuality:
          audioQuality == null && nullToAbsent
              ? const Value.absent()
              : Value(audioQuality),
      coverUrl:
          coverUrl == null && nullToAbsent
              ? const Value.absent()
              : Value(coverUrl),
      metadataJson:
          metadataJson == null && nullToAbsent
              ? const Value.absent()
              : Value(metadataJson),
      createdAt: Value(createdAt),
    );
  }

  factory Source.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Source(
      id: serializer.fromJson<String>(json['id']),
      trackId: serializer.fromJson<String>(json['trackId']),
      provider: serializer.fromJson<String>(json['provider']),
      externalId: serializer.fromJson<String>(json['externalId']),
      quality: serializer.fromJson<String?>(json['quality']),
      audioQuality: serializer.fromJson<String?>(json['audioQuality']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      metadataJson: serializer.fromJson<String?>(json['metadataJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'trackId': serializer.toJson<String>(trackId),
      'provider': serializer.toJson<String>(provider),
      'externalId': serializer.toJson<String>(externalId),
      'quality': serializer.toJson<String?>(quality),
      'audioQuality': serializer.toJson<String?>(audioQuality),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'metadataJson': serializer.toJson<String?>(metadataJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Source copyWith({
    String? id,
    String? trackId,
    String? provider,
    String? externalId,
    Value<String?> quality = const Value.absent(),
    Value<String?> audioQuality = const Value.absent(),
    Value<String?> coverUrl = const Value.absent(),
    Value<String?> metadataJson = const Value.absent(),
    DateTime? createdAt,
  }) => Source(
    id: id ?? this.id,
    trackId: trackId ?? this.trackId,
    provider: provider ?? this.provider,
    externalId: externalId ?? this.externalId,
    quality: quality.present ? quality.value : this.quality,
    audioQuality: audioQuality.present ? audioQuality.value : this.audioQuality,
    coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
    metadataJson: metadataJson.present ? metadataJson.value : this.metadataJson,
    createdAt: createdAt ?? this.createdAt,
  );
  Source copyWithCompanion(SourcesCompanion data) {
    return Source(
      id: data.id.present ? data.id.value : this.id,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      provider: data.provider.present ? data.provider.value : this.provider,
      externalId:
          data.externalId.present ? data.externalId.value : this.externalId,
      quality: data.quality.present ? data.quality.value : this.quality,
      audioQuality:
          data.audioQuality.present
              ? data.audioQuality.value
              : this.audioQuality,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      metadataJson:
          data.metadataJson.present
              ? data.metadataJson.value
              : this.metadataJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Source(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('provider: $provider, ')
          ..write('externalId: $externalId, ')
          ..write('quality: $quality, ')
          ..write('audioQuality: $audioQuality, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    trackId,
    provider,
    externalId,
    quality,
    audioQuality,
    coverUrl,
    metadataJson,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Source &&
          other.id == this.id &&
          other.trackId == this.trackId &&
          other.provider == this.provider &&
          other.externalId == this.externalId &&
          other.quality == this.quality &&
          other.audioQuality == this.audioQuality &&
          other.coverUrl == this.coverUrl &&
          other.metadataJson == this.metadataJson &&
          other.createdAt == this.createdAt);
}

class SourcesCompanion extends UpdateCompanion<Source> {
  final Value<String> id;
  final Value<String> trackId;
  final Value<String> provider;
  final Value<String> externalId;
  final Value<String?> quality;
  final Value<String?> audioQuality;
  final Value<String?> coverUrl;
  final Value<String?> metadataJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SourcesCompanion({
    this.id = const Value.absent(),
    this.trackId = const Value.absent(),
    this.provider = const Value.absent(),
    this.externalId = const Value.absent(),
    this.quality = const Value.absent(),
    this.audioQuality = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SourcesCompanion.insert({
    required String id,
    required String trackId,
    required String provider,
    required String externalId,
    this.quality = const Value.absent(),
    this.audioQuality = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.metadataJson = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       trackId = Value(trackId),
       provider = Value(provider),
       externalId = Value(externalId),
       createdAt = Value(createdAt);
  static Insertable<Source> custom({
    Expression<String>? id,
    Expression<String>? trackId,
    Expression<String>? provider,
    Expression<String>? externalId,
    Expression<String>? quality,
    Expression<String>? audioQuality,
    Expression<String>? coverUrl,
    Expression<String>? metadataJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trackId != null) 'track_id': trackId,
      if (provider != null) 'provider': provider,
      if (externalId != null) 'external_id': externalId,
      if (quality != null) 'quality': quality,
      if (audioQuality != null) 'audio_quality': audioQuality,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (metadataJson != null) 'metadata_json': metadataJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SourcesCompanion copyWith({
    Value<String>? id,
    Value<String>? trackId,
    Value<String>? provider,
    Value<String>? externalId,
    Value<String?>? quality,
    Value<String?>? audioQuality,
    Value<String?>? coverUrl,
    Value<String?>? metadataJson,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return SourcesCompanion(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      provider: provider ?? this.provider,
      externalId: externalId ?? this.externalId,
      quality: quality ?? this.quality,
      audioQuality: audioQuality ?? this.audioQuality,
      coverUrl: coverUrl ?? this.coverUrl,
      metadataJson: metadataJson ?? this.metadataJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (externalId.present) {
      map['external_id'] = Variable<String>(externalId.value);
    }
    if (quality.present) {
      map['quality'] = Variable<String>(quality.value);
    }
    if (audioQuality.present) {
      map['audio_quality'] = Variable<String>(audioQuality.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (metadataJson.present) {
      map['metadata_json'] = Variable<String>(metadataJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SourcesCompanion(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('provider: $provider, ')
          ..write('externalId: $externalId, ')
          ..write('quality: $quality, ')
          ..write('audioQuality: $audioQuality, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FilesTable extends Files with TableInfo<$FilesTable, File> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
    'track_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tracks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _metadataIdMeta = const VerificationMeta(
    'metadataId',
  );
  @override
  late final GeneratedColumn<String> metadataId = GeneratedColumn<String>(
    'metadata_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sources (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK(source_type IN (\'download\', \'local_scan\'))',
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bitrateMeta = const VerificationMeta(
    'bitrate',
  );
  @override
  late final GeneratedColumn<int> bitrate = GeneratedColumn<int>(
    'bitrate',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bitDepthMeta = const VerificationMeta(
    'bitDepth',
  );
  @override
  late final GeneratedColumn<int> bitDepth = GeneratedColumn<int>(
    'bit_depth',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sampleRateMeta = const VerificationMeta(
    'sampleRate',
  );
  @override
  late final GeneratedColumn<int> sampleRate = GeneratedColumn<int>(
    'sample_rate',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _downloadedAtMeta = const VerificationMeta(
    'downloadedAt',
  );
  @override
  late final GeneratedColumn<DateTime> downloadedAt = GeneratedColumn<DateTime>(
    'downloaded_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scannedAtMeta = const VerificationMeta(
    'scannedAt',
  );
  @override
  late final GeneratedColumn<DateTime> scannedAt = GeneratedColumn<DateTime>(
    'scanned_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileModTimeMeta = const VerificationMeta(
    'fileModTime',
  );
  @override
  late final GeneratedColumn<int> fileModTime = GeneratedColumn<int>(
    'file_mod_time',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    trackId,
    metadataId,
    sourceId,
    filePath,
    sourceType,
    format,
    bitrate,
    bitDepth,
    sampleRate,
    downloadedAt,
    scannedAt,
    fileModTime,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'files';
  @override
  VerificationContext validateIntegrity(
    Insertable<File> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    }
    if (data.containsKey('metadata_id')) {
      context.handle(
        _metadataIdMeta,
        metadataId.isAcceptableOrUnknown(data['metadata_id']!, _metadataIdMeta),
      );
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceTypeMeta);
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    }
    if (data.containsKey('bitrate')) {
      context.handle(
        _bitrateMeta,
        bitrate.isAcceptableOrUnknown(data['bitrate']!, _bitrateMeta),
      );
    }
    if (data.containsKey('bit_depth')) {
      context.handle(
        _bitDepthMeta,
        bitDepth.isAcceptableOrUnknown(data['bit_depth']!, _bitDepthMeta),
      );
    }
    if (data.containsKey('sample_rate')) {
      context.handle(
        _sampleRateMeta,
        sampleRate.isAcceptableOrUnknown(data['sample_rate']!, _sampleRateMeta),
      );
    }
    if (data.containsKey('downloaded_at')) {
      context.handle(
        _downloadedAtMeta,
        downloadedAt.isAcceptableOrUnknown(
          data['downloaded_at']!,
          _downloadedAtMeta,
        ),
      );
    }
    if (data.containsKey('scanned_at')) {
      context.handle(
        _scannedAtMeta,
        scannedAt.isAcceptableOrUnknown(data['scanned_at']!, _scannedAtMeta),
      );
    }
    if (data.containsKey('file_mod_time')) {
      context.handle(
        _fileModTimeMeta,
        fileModTime.isAcceptableOrUnknown(
          data['file_mod_time']!,
          _fileModTimeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  File map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return File(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_id'],
      ),
      metadataId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata_id'],
      ),
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      ),
      filePath:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}file_path'],
          )!,
      sourceType:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}source_type'],
          )!,
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      ),
      bitrate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bitrate'],
      ),
      bitDepth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bit_depth'],
      ),
      sampleRate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sample_rate'],
      ),
      downloadedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}downloaded_at'],
      ),
      scannedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scanned_at'],
      ),
      fileModTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_mod_time'],
      ),
    );
  }

  @override
  $FilesTable createAlias(String alias) {
    return $FilesTable(attachedDatabase, alias);
  }
}

class File extends DataClass implements Insertable<File> {
  final String id;
  final String? trackId;
  final String? metadataId;
  final String? sourceId;
  final String filePath;
  final String sourceType;
  final String? format;
  final int? bitrate;
  final int? bitDepth;
  final int? sampleRate;
  final DateTime? downloadedAt;
  final DateTime? scannedAt;
  final int? fileModTime;
  const File({
    required this.id,
    this.trackId,
    this.metadataId,
    this.sourceId,
    required this.filePath,
    required this.sourceType,
    this.format,
    this.bitrate,
    this.bitDepth,
    this.sampleRate,
    this.downloadedAt,
    this.scannedAt,
    this.fileModTime,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || trackId != null) {
      map['track_id'] = Variable<String>(trackId);
    }
    if (!nullToAbsent || metadataId != null) {
      map['metadata_id'] = Variable<String>(metadataId);
    }
    if (!nullToAbsent || sourceId != null) {
      map['source_id'] = Variable<String>(sourceId);
    }
    map['file_path'] = Variable<String>(filePath);
    map['source_type'] = Variable<String>(sourceType);
    if (!nullToAbsent || format != null) {
      map['format'] = Variable<String>(format);
    }
    if (!nullToAbsent || bitrate != null) {
      map['bitrate'] = Variable<int>(bitrate);
    }
    if (!nullToAbsent || bitDepth != null) {
      map['bit_depth'] = Variable<int>(bitDepth);
    }
    if (!nullToAbsent || sampleRate != null) {
      map['sample_rate'] = Variable<int>(sampleRate);
    }
    if (!nullToAbsent || downloadedAt != null) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt);
    }
    if (!nullToAbsent || scannedAt != null) {
      map['scanned_at'] = Variable<DateTime>(scannedAt);
    }
    if (!nullToAbsent || fileModTime != null) {
      map['file_mod_time'] = Variable<int>(fileModTime);
    }
    return map;
  }

  FilesCompanion toCompanion(bool nullToAbsent) {
    return FilesCompanion(
      id: Value(id),
      trackId:
          trackId == null && nullToAbsent
              ? const Value.absent()
              : Value(trackId),
      metadataId:
          metadataId == null && nullToAbsent
              ? const Value.absent()
              : Value(metadataId),
      sourceId:
          sourceId == null && nullToAbsent
              ? const Value.absent()
              : Value(sourceId),
      filePath: Value(filePath),
      sourceType: Value(sourceType),
      format:
          format == null && nullToAbsent ? const Value.absent() : Value(format),
      bitrate:
          bitrate == null && nullToAbsent
              ? const Value.absent()
              : Value(bitrate),
      bitDepth:
          bitDepth == null && nullToAbsent
              ? const Value.absent()
              : Value(bitDepth),
      sampleRate:
          sampleRate == null && nullToAbsent
              ? const Value.absent()
              : Value(sampleRate),
      downloadedAt:
          downloadedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(downloadedAt),
      scannedAt:
          scannedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(scannedAt),
      fileModTime:
          fileModTime == null && nullToAbsent
              ? const Value.absent()
              : Value(fileModTime),
    );
  }

  factory File.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return File(
      id: serializer.fromJson<String>(json['id']),
      trackId: serializer.fromJson<String?>(json['trackId']),
      metadataId: serializer.fromJson<String?>(json['metadataId']),
      sourceId: serializer.fromJson<String?>(json['sourceId']),
      filePath: serializer.fromJson<String>(json['filePath']),
      sourceType: serializer.fromJson<String>(json['sourceType']),
      format: serializer.fromJson<String?>(json['format']),
      bitrate: serializer.fromJson<int?>(json['bitrate']),
      bitDepth: serializer.fromJson<int?>(json['bitDepth']),
      sampleRate: serializer.fromJson<int?>(json['sampleRate']),
      downloadedAt: serializer.fromJson<DateTime?>(json['downloadedAt']),
      scannedAt: serializer.fromJson<DateTime?>(json['scannedAt']),
      fileModTime: serializer.fromJson<int?>(json['fileModTime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'trackId': serializer.toJson<String?>(trackId),
      'metadataId': serializer.toJson<String?>(metadataId),
      'sourceId': serializer.toJson<String?>(sourceId),
      'filePath': serializer.toJson<String>(filePath),
      'sourceType': serializer.toJson<String>(sourceType),
      'format': serializer.toJson<String?>(format),
      'bitrate': serializer.toJson<int?>(bitrate),
      'bitDepth': serializer.toJson<int?>(bitDepth),
      'sampleRate': serializer.toJson<int?>(sampleRate),
      'downloadedAt': serializer.toJson<DateTime?>(downloadedAt),
      'scannedAt': serializer.toJson<DateTime?>(scannedAt),
      'fileModTime': serializer.toJson<int?>(fileModTime),
    };
  }

  File copyWith({
    String? id,
    Value<String?> trackId = const Value.absent(),
    Value<String?> metadataId = const Value.absent(),
    Value<String?> sourceId = const Value.absent(),
    String? filePath,
    String? sourceType,
    Value<String?> format = const Value.absent(),
    Value<int?> bitrate = const Value.absent(),
    Value<int?> bitDepth = const Value.absent(),
    Value<int?> sampleRate = const Value.absent(),
    Value<DateTime?> downloadedAt = const Value.absent(),
    Value<DateTime?> scannedAt = const Value.absent(),
    Value<int?> fileModTime = const Value.absent(),
  }) => File(
    id: id ?? this.id,
    trackId: trackId.present ? trackId.value : this.trackId,
    metadataId: metadataId.present ? metadataId.value : this.metadataId,
    sourceId: sourceId.present ? sourceId.value : this.sourceId,
    filePath: filePath ?? this.filePath,
    sourceType: sourceType ?? this.sourceType,
    format: format.present ? format.value : this.format,
    bitrate: bitrate.present ? bitrate.value : this.bitrate,
    bitDepth: bitDepth.present ? bitDepth.value : this.bitDepth,
    sampleRate: sampleRate.present ? sampleRate.value : this.sampleRate,
    downloadedAt: downloadedAt.present ? downloadedAt.value : this.downloadedAt,
    scannedAt: scannedAt.present ? scannedAt.value : this.scannedAt,
    fileModTime: fileModTime.present ? fileModTime.value : this.fileModTime,
  );
  File copyWithCompanion(FilesCompanion data) {
    return File(
      id: data.id.present ? data.id.value : this.id,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      metadataId:
          data.metadataId.present ? data.metadataId.value : this.metadataId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      sourceType:
          data.sourceType.present ? data.sourceType.value : this.sourceType,
      format: data.format.present ? data.format.value : this.format,
      bitrate: data.bitrate.present ? data.bitrate.value : this.bitrate,
      bitDepth: data.bitDepth.present ? data.bitDepth.value : this.bitDepth,
      sampleRate:
          data.sampleRate.present ? data.sampleRate.value : this.sampleRate,
      downloadedAt:
          data.downloadedAt.present
              ? data.downloadedAt.value
              : this.downloadedAt,
      scannedAt: data.scannedAt.present ? data.scannedAt.value : this.scannedAt,
      fileModTime:
          data.fileModTime.present ? data.fileModTime.value : this.fileModTime,
    );
  }

  @override
  String toString() {
    return (StringBuffer('File(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('metadataId: $metadataId, ')
          ..write('sourceId: $sourceId, ')
          ..write('filePath: $filePath, ')
          ..write('sourceType: $sourceType, ')
          ..write('format: $format, ')
          ..write('bitrate: $bitrate, ')
          ..write('bitDepth: $bitDepth, ')
          ..write('sampleRate: $sampleRate, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('scannedAt: $scannedAt, ')
          ..write('fileModTime: $fileModTime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    trackId,
    metadataId,
    sourceId,
    filePath,
    sourceType,
    format,
    bitrate,
    bitDepth,
    sampleRate,
    downloadedAt,
    scannedAt,
    fileModTime,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is File &&
          other.id == this.id &&
          other.trackId == this.trackId &&
          other.metadataId == this.metadataId &&
          other.sourceId == this.sourceId &&
          other.filePath == this.filePath &&
          other.sourceType == this.sourceType &&
          other.format == this.format &&
          other.bitrate == this.bitrate &&
          other.bitDepth == this.bitDepth &&
          other.sampleRate == this.sampleRate &&
          other.downloadedAt == this.downloadedAt &&
          other.scannedAt == this.scannedAt &&
          other.fileModTime == this.fileModTime);
}

class FilesCompanion extends UpdateCompanion<File> {
  final Value<String> id;
  final Value<String?> trackId;
  final Value<String?> metadataId;
  final Value<String?> sourceId;
  final Value<String> filePath;
  final Value<String> sourceType;
  final Value<String?> format;
  final Value<int?> bitrate;
  final Value<int?> bitDepth;
  final Value<int?> sampleRate;
  final Value<DateTime?> downloadedAt;
  final Value<DateTime?> scannedAt;
  final Value<int?> fileModTime;
  final Value<int> rowid;
  const FilesCompanion({
    this.id = const Value.absent(),
    this.trackId = const Value.absent(),
    this.metadataId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.filePath = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.format = const Value.absent(),
    this.bitrate = const Value.absent(),
    this.bitDepth = const Value.absent(),
    this.sampleRate = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.scannedAt = const Value.absent(),
    this.fileModTime = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FilesCompanion.insert({
    required String id,
    this.trackId = const Value.absent(),
    this.metadataId = const Value.absent(),
    this.sourceId = const Value.absent(),
    required String filePath,
    required String sourceType,
    this.format = const Value.absent(),
    this.bitrate = const Value.absent(),
    this.bitDepth = const Value.absent(),
    this.sampleRate = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.scannedAt = const Value.absent(),
    this.fileModTime = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       filePath = Value(filePath),
       sourceType = Value(sourceType);
  static Insertable<File> custom({
    Expression<String>? id,
    Expression<String>? trackId,
    Expression<String>? metadataId,
    Expression<String>? sourceId,
    Expression<String>? filePath,
    Expression<String>? sourceType,
    Expression<String>? format,
    Expression<int>? bitrate,
    Expression<int>? bitDepth,
    Expression<int>? sampleRate,
    Expression<DateTime>? downloadedAt,
    Expression<DateTime>? scannedAt,
    Expression<int>? fileModTime,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trackId != null) 'track_id': trackId,
      if (metadataId != null) 'metadata_id': metadataId,
      if (sourceId != null) 'source_id': sourceId,
      if (filePath != null) 'file_path': filePath,
      if (sourceType != null) 'source_type': sourceType,
      if (format != null) 'format': format,
      if (bitrate != null) 'bitrate': bitrate,
      if (bitDepth != null) 'bit_depth': bitDepth,
      if (sampleRate != null) 'sample_rate': sampleRate,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
      if (scannedAt != null) 'scanned_at': scannedAt,
      if (fileModTime != null) 'file_mod_time': fileModTime,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FilesCompanion copyWith({
    Value<String>? id,
    Value<String?>? trackId,
    Value<String?>? metadataId,
    Value<String?>? sourceId,
    Value<String>? filePath,
    Value<String>? sourceType,
    Value<String?>? format,
    Value<int?>? bitrate,
    Value<int?>? bitDepth,
    Value<int?>? sampleRate,
    Value<DateTime?>? downloadedAt,
    Value<DateTime?>? scannedAt,
    Value<int?>? fileModTime,
    Value<int>? rowid,
  }) {
    return FilesCompanion(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      metadataId: metadataId ?? this.metadataId,
      sourceId: sourceId ?? this.sourceId,
      filePath: filePath ?? this.filePath,
      sourceType: sourceType ?? this.sourceType,
      format: format ?? this.format,
      bitrate: bitrate ?? this.bitrate,
      bitDepth: bitDepth ?? this.bitDepth,
      sampleRate: sampleRate ?? this.sampleRate,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      scannedAt: scannedAt ?? this.scannedAt,
      fileModTime: fileModTime ?? this.fileModTime,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (metadataId.present) {
      map['metadata_id'] = Variable<String>(metadataId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (bitrate.present) {
      map['bitrate'] = Variable<int>(bitrate.value);
    }
    if (bitDepth.present) {
      map['bit_depth'] = Variable<int>(bitDepth.value);
    }
    if (sampleRate.present) {
      map['sample_rate'] = Variable<int>(sampleRate.value);
    }
    if (downloadedAt.present) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt.value);
    }
    if (scannedAt.present) {
      map['scanned_at'] = Variable<DateTime>(scannedAt.value);
    }
    if (fileModTime.present) {
      map['file_mod_time'] = Variable<int>(fileModTime.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FilesCompanion(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('metadataId: $metadataId, ')
          ..write('sourceId: $sourceId, ')
          ..write('filePath: $filePath, ')
          ..write('sourceType: $sourceType, ')
          ..write('format: $format, ')
          ..write('bitrate: $bitrate, ')
          ..write('bitDepth: $bitDepth, ')
          ..write('sampleRate: $sampleRate, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('scannedAt: $scannedAt, ')
          ..write('fileModTime: $fileModTime, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LovedTracksTable extends LovedTracks
    with TableInfo<$LovedTracksTable, LovedTrack> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LovedTracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackNameMeta = const VerificationMeta(
    'trackName',
  );
  @override
  late final GeneratedColumn<String> trackName = GeneratedColumn<String>(
    'track_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistNameMeta = const VerificationMeta(
    'artistName',
  );
  @override
  late final GeneratedColumn<String> artistName = GeneratedColumn<String>(
    'artist_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _albumNameMeta = const VerificationMeta(
    'albumName',
  );
  @override
  late final GeneratedColumn<String> albumName = GeneratedColumn<String>(
    'album_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverPathMeta = const VerificationMeta(
    'coverPath',
  );
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
    'cover_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isrcMeta = const VerificationMeta('isrc');
  @override
  late final GeneratedColumn<String> isrc = GeneratedColumn<String>(
    'isrc',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    trackId,
    trackName,
    artistName,
    albumName,
    coverUrl,
    coverPath,
    isrc,
    durationMs,
    provider,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'loved_tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<LovedTrack> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('track_name')) {
      context.handle(
        _trackNameMeta,
        trackName.isAcceptableOrUnknown(data['track_name']!, _trackNameMeta),
      );
    } else if (isInserting) {
      context.missing(_trackNameMeta);
    }
    if (data.containsKey('artist_name')) {
      context.handle(
        _artistNameMeta,
        artistName.isAcceptableOrUnknown(data['artist_name']!, _artistNameMeta),
      );
    } else if (isInserting) {
      context.missing(_artistNameMeta);
    }
    if (data.containsKey('album_name')) {
      context.handle(
        _albumNameMeta,
        albumName.isAcceptableOrUnknown(data['album_name']!, _albumNameMeta),
      );
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
      );
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('isrc')) {
      context.handle(
        _isrcMeta,
        isrc.isAcceptableOrUnknown(data['isrc']!, _isrcMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trackId};
  @override
  LovedTrack map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LovedTrack(
      trackId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}track_id'],
          )!,
      trackName:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}track_name'],
          )!,
      artistName:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}artist_name'],
          )!,
      albumName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_name'],
      ),
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      ),
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      isrc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}isrc'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      ),
      addedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}added_at'],
          )!,
    );
  }

  @override
  $LovedTracksTable createAlias(String alias) {
    return $LovedTracksTable(attachedDatabase, alias);
  }
}

class LovedTrack extends DataClass implements Insertable<LovedTrack> {
  final String trackId;
  final String trackName;
  final String artistName;
  final String? albumName;
  final String? coverUrl;
  final String? coverPath;
  final String? isrc;
  final int? durationMs;
  final String? provider;
  final DateTime addedAt;
  const LovedTrack({
    required this.trackId,
    required this.trackName,
    required this.artistName,
    this.albumName,
    this.coverUrl,
    this.coverPath,
    this.isrc,
    this.durationMs,
    this.provider,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_id'] = Variable<String>(trackId);
    map['track_name'] = Variable<String>(trackName);
    map['artist_name'] = Variable<String>(artistName);
    if (!nullToAbsent || albumName != null) {
      map['album_name'] = Variable<String>(albumName);
    }
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    if (!nullToAbsent || isrc != null) {
      map['isrc'] = Variable<String>(isrc);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    if (!nullToAbsent || provider != null) {
      map['provider'] = Variable<String>(provider);
    }
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  LovedTracksCompanion toCompanion(bool nullToAbsent) {
    return LovedTracksCompanion(
      trackId: Value(trackId),
      trackName: Value(trackName),
      artistName: Value(artistName),
      albumName:
          albumName == null && nullToAbsent
              ? const Value.absent()
              : Value(albumName),
      coverUrl:
          coverUrl == null && nullToAbsent
              ? const Value.absent()
              : Value(coverUrl),
      coverPath:
          coverPath == null && nullToAbsent
              ? const Value.absent()
              : Value(coverPath),
      isrc: isrc == null && nullToAbsent ? const Value.absent() : Value(isrc),
      durationMs:
          durationMs == null && nullToAbsent
              ? const Value.absent()
              : Value(durationMs),
      provider:
          provider == null && nullToAbsent
              ? const Value.absent()
              : Value(provider),
      addedAt: Value(addedAt),
    );
  }

  factory LovedTrack.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LovedTrack(
      trackId: serializer.fromJson<String>(json['trackId']),
      trackName: serializer.fromJson<String>(json['trackName']),
      artistName: serializer.fromJson<String>(json['artistName']),
      albumName: serializer.fromJson<String?>(json['albumName']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      isrc: serializer.fromJson<String?>(json['isrc']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      provider: serializer.fromJson<String?>(json['provider']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackId': serializer.toJson<String>(trackId),
      'trackName': serializer.toJson<String>(trackName),
      'artistName': serializer.toJson<String>(artistName),
      'albumName': serializer.toJson<String?>(albumName),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'coverPath': serializer.toJson<String?>(coverPath),
      'isrc': serializer.toJson<String?>(isrc),
      'durationMs': serializer.toJson<int?>(durationMs),
      'provider': serializer.toJson<String?>(provider),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  LovedTrack copyWith({
    String? trackId,
    String? trackName,
    String? artistName,
    Value<String?> albumName = const Value.absent(),
    Value<String?> coverUrl = const Value.absent(),
    Value<String?> coverPath = const Value.absent(),
    Value<String?> isrc = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    Value<String?> provider = const Value.absent(),
    DateTime? addedAt,
  }) => LovedTrack(
    trackId: trackId ?? this.trackId,
    trackName: trackName ?? this.trackName,
    artistName: artistName ?? this.artistName,
    albumName: albumName.present ? albumName.value : this.albumName,
    coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    isrc: isrc.present ? isrc.value : this.isrc,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    provider: provider.present ? provider.value : this.provider,
    addedAt: addedAt ?? this.addedAt,
  );
  LovedTrack copyWithCompanion(LovedTracksCompanion data) {
    return LovedTrack(
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      trackName: data.trackName.present ? data.trackName.value : this.trackName,
      artistName:
          data.artistName.present ? data.artistName.value : this.artistName,
      albumName: data.albumName.present ? data.albumName.value : this.albumName,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      isrc: data.isrc.present ? data.isrc.value : this.isrc,
      durationMs:
          data.durationMs.present ? data.durationMs.value : this.durationMs,
      provider: data.provider.present ? data.provider.value : this.provider,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LovedTrack(')
          ..write('trackId: $trackId, ')
          ..write('trackName: $trackName, ')
          ..write('artistName: $artistName, ')
          ..write('albumName: $albumName, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('coverPath: $coverPath, ')
          ..write('isrc: $isrc, ')
          ..write('durationMs: $durationMs, ')
          ..write('provider: $provider, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    trackId,
    trackName,
    artistName,
    albumName,
    coverUrl,
    coverPath,
    isrc,
    durationMs,
    provider,
    addedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LovedTrack &&
          other.trackId == this.trackId &&
          other.trackName == this.trackName &&
          other.artistName == this.artistName &&
          other.albumName == this.albumName &&
          other.coverUrl == this.coverUrl &&
          other.coverPath == this.coverPath &&
          other.isrc == this.isrc &&
          other.durationMs == this.durationMs &&
          other.provider == this.provider &&
          other.addedAt == this.addedAt);
}

class LovedTracksCompanion extends UpdateCompanion<LovedTrack> {
  final Value<String> trackId;
  final Value<String> trackName;
  final Value<String> artistName;
  final Value<String?> albumName;
  final Value<String?> coverUrl;
  final Value<String?> coverPath;
  final Value<String?> isrc;
  final Value<int?> durationMs;
  final Value<String?> provider;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const LovedTracksCompanion({
    this.trackId = const Value.absent(),
    this.trackName = const Value.absent(),
    this.artistName = const Value.absent(),
    this.albumName = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.isrc = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.provider = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LovedTracksCompanion.insert({
    required String trackId,
    required String trackName,
    required String artistName,
    this.albumName = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.isrc = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.provider = const Value.absent(),
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  }) : trackId = Value(trackId),
       trackName = Value(trackName),
       artistName = Value(artistName),
       addedAt = Value(addedAt);
  static Insertable<LovedTrack> custom({
    Expression<String>? trackId,
    Expression<String>? trackName,
    Expression<String>? artistName,
    Expression<String>? albumName,
    Expression<String>? coverUrl,
    Expression<String>? coverPath,
    Expression<String>? isrc,
    Expression<int>? durationMs,
    Expression<String>? provider,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (trackId != null) 'track_id': trackId,
      if (trackName != null) 'track_name': trackName,
      if (artistName != null) 'artist_name': artistName,
      if (albumName != null) 'album_name': albumName,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (coverPath != null) 'cover_path': coverPath,
      if (isrc != null) 'isrc': isrc,
      if (durationMs != null) 'duration_ms': durationMs,
      if (provider != null) 'provider': provider,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LovedTracksCompanion copyWith({
    Value<String>? trackId,
    Value<String>? trackName,
    Value<String>? artistName,
    Value<String?>? albumName,
    Value<String?>? coverUrl,
    Value<String?>? coverPath,
    Value<String?>? isrc,
    Value<int?>? durationMs,
    Value<String?>? provider,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return LovedTracksCompanion(
      trackId: trackId ?? this.trackId,
      trackName: trackName ?? this.trackName,
      artistName: artistName ?? this.artistName,
      albumName: albumName ?? this.albumName,
      coverUrl: coverUrl ?? this.coverUrl,
      coverPath: coverPath ?? this.coverPath,
      isrc: isrc ?? this.isrc,
      durationMs: durationMs ?? this.durationMs,
      provider: provider ?? this.provider,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (trackName.present) {
      map['track_name'] = Variable<String>(trackName.value);
    }
    if (artistName.present) {
      map['artist_name'] = Variable<String>(artistName.value);
    }
    if (albumName.present) {
      map['album_name'] = Variable<String>(albumName.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (isrc.present) {
      map['isrc'] = Variable<String>(isrc.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LovedTracksCompanion(')
          ..write('trackId: $trackId, ')
          ..write('trackName: $trackName, ')
          ..write('artistName: $artistName, ')
          ..write('albumName: $albumName, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('coverPath: $coverPath, ')
          ..write('isrc: $isrc, ')
          ..write('durationMs: $durationMs, ')
          ..write('provider: $provider, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FavoriteAlbumsTable extends FavoriteAlbums
    with TableInfo<$FavoriteAlbumsTable, FavoriteAlbum> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoriteAlbumsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _albumIdMeta = const VerificationMeta(
    'albumId',
  );
  @override
  late final GeneratedColumn<String> albumId = GeneratedColumn<String>(
    'album_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistIdMeta = const VerificationMeta(
    'artistId',
  );
  @override
  late final GeneratedColumn<String> artistId = GeneratedColumn<String>(
    'artist_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistNameMeta = const VerificationMeta(
    'artistName',
  );
  @override
  late final GeneratedColumn<String> artistName = GeneratedColumn<String>(
    'artist_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverPathMeta = const VerificationMeta(
    'coverPath',
  );
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
    'cover_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    albumId,
    name,
    artistId,
    artistName,
    coverUrl,
    coverPath,
    provider,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorite_albums';
  @override
  VerificationContext validateIntegrity(
    Insertable<FavoriteAlbum> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('album_id')) {
      context.handle(
        _albumIdMeta,
        albumId.isAcceptableOrUnknown(data['album_id']!, _albumIdMeta),
      );
    } else if (isInserting) {
      context.missing(_albumIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('artist_id')) {
      context.handle(
        _artistIdMeta,
        artistId.isAcceptableOrUnknown(data['artist_id']!, _artistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_artistIdMeta);
    }
    if (data.containsKey('artist_name')) {
      context.handle(
        _artistNameMeta,
        artistName.isAcceptableOrUnknown(data['artist_name']!, _artistNameMeta),
      );
    } else if (isInserting) {
      context.missing(_artistNameMeta);
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_coverUrlMeta);
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {albumId};
  @override
  FavoriteAlbum map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavoriteAlbum(
      albumId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}album_id'],
          )!,
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      artistId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}artist_id'],
          )!,
      artistName:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}artist_name'],
          )!,
      coverUrl:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}cover_url'],
          )!,
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      ),
      addedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}added_at'],
          )!,
    );
  }

  @override
  $FavoriteAlbumsTable createAlias(String alias) {
    return $FavoriteAlbumsTable(attachedDatabase, alias);
  }
}

class FavoriteAlbum extends DataClass implements Insertable<FavoriteAlbum> {
  final String albumId;
  final String name;
  final String artistId;
  final String artistName;
  final String coverUrl;
  final String? coverPath;
  final String? provider;
  final DateTime addedAt;
  const FavoriteAlbum({
    required this.albumId,
    required this.name,
    required this.artistId,
    required this.artistName,
    required this.coverUrl,
    this.coverPath,
    this.provider,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['album_id'] = Variable<String>(albumId);
    map['name'] = Variable<String>(name);
    map['artist_id'] = Variable<String>(artistId);
    map['artist_name'] = Variable<String>(artistName);
    map['cover_url'] = Variable<String>(coverUrl);
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    if (!nullToAbsent || provider != null) {
      map['provider'] = Variable<String>(provider);
    }
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  FavoriteAlbumsCompanion toCompanion(bool nullToAbsent) {
    return FavoriteAlbumsCompanion(
      albumId: Value(albumId),
      name: Value(name),
      artistId: Value(artistId),
      artistName: Value(artistName),
      coverUrl: Value(coverUrl),
      coverPath:
          coverPath == null && nullToAbsent
              ? const Value.absent()
              : Value(coverPath),
      provider:
          provider == null && nullToAbsent
              ? const Value.absent()
              : Value(provider),
      addedAt: Value(addedAt),
    );
  }

  factory FavoriteAlbum.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavoriteAlbum(
      albumId: serializer.fromJson<String>(json['albumId']),
      name: serializer.fromJson<String>(json['name']),
      artistId: serializer.fromJson<String>(json['artistId']),
      artistName: serializer.fromJson<String>(json['artistName']),
      coverUrl: serializer.fromJson<String>(json['coverUrl']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      provider: serializer.fromJson<String?>(json['provider']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'albumId': serializer.toJson<String>(albumId),
      'name': serializer.toJson<String>(name),
      'artistId': serializer.toJson<String>(artistId),
      'artistName': serializer.toJson<String>(artistName),
      'coverUrl': serializer.toJson<String>(coverUrl),
      'coverPath': serializer.toJson<String?>(coverPath),
      'provider': serializer.toJson<String?>(provider),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  FavoriteAlbum copyWith({
    String? albumId,
    String? name,
    String? artistId,
    String? artistName,
    String? coverUrl,
    Value<String?> coverPath = const Value.absent(),
    Value<String?> provider = const Value.absent(),
    DateTime? addedAt,
  }) => FavoriteAlbum(
    albumId: albumId ?? this.albumId,
    name: name ?? this.name,
    artistId: artistId ?? this.artistId,
    artistName: artistName ?? this.artistName,
    coverUrl: coverUrl ?? this.coverUrl,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    provider: provider.present ? provider.value : this.provider,
    addedAt: addedAt ?? this.addedAt,
  );
  FavoriteAlbum copyWithCompanion(FavoriteAlbumsCompanion data) {
    return FavoriteAlbum(
      albumId: data.albumId.present ? data.albumId.value : this.albumId,
      name: data.name.present ? data.name.value : this.name,
      artistId: data.artistId.present ? data.artistId.value : this.artistId,
      artistName:
          data.artistName.present ? data.artistName.value : this.artistName,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      provider: data.provider.present ? data.provider.value : this.provider,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteAlbum(')
          ..write('albumId: $albumId, ')
          ..write('name: $name, ')
          ..write('artistId: $artistId, ')
          ..write('artistName: $artistName, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('coverPath: $coverPath, ')
          ..write('provider: $provider, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    albumId,
    name,
    artistId,
    artistName,
    coverUrl,
    coverPath,
    provider,
    addedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoriteAlbum &&
          other.albumId == this.albumId &&
          other.name == this.name &&
          other.artistId == this.artistId &&
          other.artistName == this.artistName &&
          other.coverUrl == this.coverUrl &&
          other.coverPath == this.coverPath &&
          other.provider == this.provider &&
          other.addedAt == this.addedAt);
}

class FavoriteAlbumsCompanion extends UpdateCompanion<FavoriteAlbum> {
  final Value<String> albumId;
  final Value<String> name;
  final Value<String> artistId;
  final Value<String> artistName;
  final Value<String> coverUrl;
  final Value<String?> coverPath;
  final Value<String?> provider;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const FavoriteAlbumsCompanion({
    this.albumId = const Value.absent(),
    this.name = const Value.absent(),
    this.artistId = const Value.absent(),
    this.artistName = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.provider = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavoriteAlbumsCompanion.insert({
    required String albumId,
    required String name,
    required String artistId,
    required String artistName,
    required String coverUrl,
    this.coverPath = const Value.absent(),
    this.provider = const Value.absent(),
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  }) : albumId = Value(albumId),
       name = Value(name),
       artistId = Value(artistId),
       artistName = Value(artistName),
       coverUrl = Value(coverUrl),
       addedAt = Value(addedAt);
  static Insertable<FavoriteAlbum> custom({
    Expression<String>? albumId,
    Expression<String>? name,
    Expression<String>? artistId,
    Expression<String>? artistName,
    Expression<String>? coverUrl,
    Expression<String>? coverPath,
    Expression<String>? provider,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (albumId != null) 'album_id': albumId,
      if (name != null) 'name': name,
      if (artistId != null) 'artist_id': artistId,
      if (artistName != null) 'artist_name': artistName,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (coverPath != null) 'cover_path': coverPath,
      if (provider != null) 'provider': provider,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavoriteAlbumsCompanion copyWith({
    Value<String>? albumId,
    Value<String>? name,
    Value<String>? artistId,
    Value<String>? artistName,
    Value<String>? coverUrl,
    Value<String?>? coverPath,
    Value<String?>? provider,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return FavoriteAlbumsCompanion(
      albumId: albumId ?? this.albumId,
      name: name ?? this.name,
      artistId: artistId ?? this.artistId,
      artistName: artistName ?? this.artistName,
      coverUrl: coverUrl ?? this.coverUrl,
      coverPath: coverPath ?? this.coverPath,
      provider: provider ?? this.provider,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (albumId.present) {
      map['album_id'] = Variable<String>(albumId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (artistId.present) {
      map['artist_id'] = Variable<String>(artistId.value);
    }
    if (artistName.present) {
      map['artist_name'] = Variable<String>(artistName.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteAlbumsCompanion(')
          ..write('albumId: $albumId, ')
          ..write('name: $name, ')
          ..write('artistId: $artistId, ')
          ..write('artistName: $artistName, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('coverPath: $coverPath, ')
          ..write('provider: $provider, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FavoriteArtistsTable extends FavoriteArtists
    with TableInfo<$FavoriteArtistsTable, FavoriteArtist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoriteArtistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _artistIdMeta = const VerificationMeta(
    'artistId',
  );
  @override
  late final GeneratedColumn<String> artistId = GeneratedColumn<String>(
    'artist_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    artistId,
    name,
    imageUrl,
    imagePath,
    provider,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorite_artists';
  @override
  VerificationContext validateIntegrity(
    Insertable<FavoriteArtist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('artist_id')) {
      context.handle(
        _artistIdMeta,
        artistId.isAcceptableOrUnknown(data['artist_id']!, _artistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_artistIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_imageUrlMeta);
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {artistId};
  @override
  FavoriteArtist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavoriteArtist(
      artistId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}artist_id'],
          )!,
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      imageUrl:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}image_url'],
          )!,
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      ),
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      ),
      addedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}added_at'],
          )!,
    );
  }

  @override
  $FavoriteArtistsTable createAlias(String alias) {
    return $FavoriteArtistsTable(attachedDatabase, alias);
  }
}

class FavoriteArtist extends DataClass implements Insertable<FavoriteArtist> {
  final String artistId;
  final String name;
  final String imageUrl;
  final String? imagePath;
  final String? provider;
  final DateTime addedAt;
  const FavoriteArtist({
    required this.artistId,
    required this.name,
    required this.imageUrl,
    this.imagePath,
    this.provider,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['artist_id'] = Variable<String>(artistId);
    map['name'] = Variable<String>(name);
    map['image_url'] = Variable<String>(imageUrl);
    if (!nullToAbsent || imagePath != null) {
      map['image_path'] = Variable<String>(imagePath);
    }
    if (!nullToAbsent || provider != null) {
      map['provider'] = Variable<String>(provider);
    }
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  FavoriteArtistsCompanion toCompanion(bool nullToAbsent) {
    return FavoriteArtistsCompanion(
      artistId: Value(artistId),
      name: Value(name),
      imageUrl: Value(imageUrl),
      imagePath:
          imagePath == null && nullToAbsent
              ? const Value.absent()
              : Value(imagePath),
      provider:
          provider == null && nullToAbsent
              ? const Value.absent()
              : Value(provider),
      addedAt: Value(addedAt),
    );
  }

  factory FavoriteArtist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavoriteArtist(
      artistId: serializer.fromJson<String>(json['artistId']),
      name: serializer.fromJson<String>(json['name']),
      imageUrl: serializer.fromJson<String>(json['imageUrl']),
      imagePath: serializer.fromJson<String?>(json['imagePath']),
      provider: serializer.fromJson<String?>(json['provider']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'artistId': serializer.toJson<String>(artistId),
      'name': serializer.toJson<String>(name),
      'imageUrl': serializer.toJson<String>(imageUrl),
      'imagePath': serializer.toJson<String?>(imagePath),
      'provider': serializer.toJson<String?>(provider),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  FavoriteArtist copyWith({
    String? artistId,
    String? name,
    String? imageUrl,
    Value<String?> imagePath = const Value.absent(),
    Value<String?> provider = const Value.absent(),
    DateTime? addedAt,
  }) => FavoriteArtist(
    artistId: artistId ?? this.artistId,
    name: name ?? this.name,
    imageUrl: imageUrl ?? this.imageUrl,
    imagePath: imagePath.present ? imagePath.value : this.imagePath,
    provider: provider.present ? provider.value : this.provider,
    addedAt: addedAt ?? this.addedAt,
  );
  FavoriteArtist copyWithCompanion(FavoriteArtistsCompanion data) {
    return FavoriteArtist(
      artistId: data.artistId.present ? data.artistId.value : this.artistId,
      name: data.name.present ? data.name.value : this.name,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      provider: data.provider.present ? data.provider.value : this.provider,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteArtist(')
          ..write('artistId: $artistId, ')
          ..write('name: $name, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('imagePath: $imagePath, ')
          ..write('provider: $provider, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(artistId, name, imageUrl, imagePath, provider, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoriteArtist &&
          other.artistId == this.artistId &&
          other.name == this.name &&
          other.imageUrl == this.imageUrl &&
          other.imagePath == this.imagePath &&
          other.provider == this.provider &&
          other.addedAt == this.addedAt);
}

class FavoriteArtistsCompanion extends UpdateCompanion<FavoriteArtist> {
  final Value<String> artistId;
  final Value<String> name;
  final Value<String> imageUrl;
  final Value<String?> imagePath;
  final Value<String?> provider;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const FavoriteArtistsCompanion({
    this.artistId = const Value.absent(),
    this.name = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.provider = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavoriteArtistsCompanion.insert({
    required String artistId,
    required String name,
    required String imageUrl,
    this.imagePath = const Value.absent(),
    this.provider = const Value.absent(),
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  }) : artistId = Value(artistId),
       name = Value(name),
       imageUrl = Value(imageUrl),
       addedAt = Value(addedAt);
  static Insertable<FavoriteArtist> custom({
    Expression<String>? artistId,
    Expression<String>? name,
    Expression<String>? imageUrl,
    Expression<String>? imagePath,
    Expression<String>? provider,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (artistId != null) 'artist_id': artistId,
      if (name != null) 'name': name,
      if (imageUrl != null) 'image_url': imageUrl,
      if (imagePath != null) 'image_path': imagePath,
      if (provider != null) 'provider': provider,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavoriteArtistsCompanion copyWith({
    Value<String>? artistId,
    Value<String>? name,
    Value<String>? imageUrl,
    Value<String?>? imagePath,
    Value<String?>? provider,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return FavoriteArtistsCompanion(
      artistId: artistId ?? this.artistId,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePath: imagePath ?? this.imagePath,
      provider: provider ?? this.provider,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (artistId.present) {
      map['artist_id'] = Variable<String>(artistId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteArtistsCompanion(')
          ..write('artistId: $artistId, ')
          ..write('name: $name, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('imagePath: $imagePath, ')
          ..write('provider: $provider, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FavoritePlaylistsTable extends FavoritePlaylists
    with TableInfo<$FavoritePlaylistsTable, FavoritePlaylist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoritePlaylistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<String> playlistId = GeneratedColumn<String>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverPathMeta = const VerificationMeta(
    'coverPath',
  );
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
    'cover_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _externalUrlMeta = const VerificationMeta(
    'externalUrl',
  );
  @override
  late final GeneratedColumn<String> externalUrl = GeneratedColumn<String>(
    'external_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    playlistId,
    name,
    coverUrl,
    coverPath,
    description,
    provider,
    externalUrl,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorite_playlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<FavoritePlaylist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
      );
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    }
    if (data.containsKey('external_url')) {
      context.handle(
        _externalUrlMeta,
        externalUrl.isAcceptableOrUnknown(
          data['external_url']!,
          _externalUrlMeta,
        ),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playlistId};
  @override
  FavoritePlaylist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavoritePlaylist(
      playlistId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}playlist_id'],
          )!,
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      ),
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      ),
      externalUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_url'],
      ),
      addedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}added_at'],
          )!,
    );
  }

  @override
  $FavoritePlaylistsTable createAlias(String alias) {
    return $FavoritePlaylistsTable(attachedDatabase, alias);
  }
}

class FavoritePlaylist extends DataClass
    implements Insertable<FavoritePlaylist> {
  final String playlistId;
  final String name;
  final String? coverUrl;
  final String? coverPath;
  final String? description;
  final String? provider;
  final String? externalUrl;
  final DateTime addedAt;
  const FavoritePlaylist({
    required this.playlistId,
    required this.name,
    this.coverUrl,
    this.coverPath,
    this.description,
    this.provider,
    this.externalUrl,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['playlist_id'] = Variable<String>(playlistId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || provider != null) {
      map['provider'] = Variable<String>(provider);
    }
    if (!nullToAbsent || externalUrl != null) {
      map['external_url'] = Variable<String>(externalUrl);
    }
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  FavoritePlaylistsCompanion toCompanion(bool nullToAbsent) {
    return FavoritePlaylistsCompanion(
      playlistId: Value(playlistId),
      name: Value(name),
      coverUrl:
          coverUrl == null && nullToAbsent
              ? const Value.absent()
              : Value(coverUrl),
      coverPath:
          coverPath == null && nullToAbsent
              ? const Value.absent()
              : Value(coverPath),
      description:
          description == null && nullToAbsent
              ? const Value.absent()
              : Value(description),
      provider:
          provider == null && nullToAbsent
              ? const Value.absent()
              : Value(provider),
      externalUrl:
          externalUrl == null && nullToAbsent
              ? const Value.absent()
              : Value(externalUrl),
      addedAt: Value(addedAt),
    );
  }

  factory FavoritePlaylist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavoritePlaylist(
      playlistId: serializer.fromJson<String>(json['playlistId']),
      name: serializer.fromJson<String>(json['name']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      description: serializer.fromJson<String?>(json['description']),
      provider: serializer.fromJson<String?>(json['provider']),
      externalUrl: serializer.fromJson<String?>(json['externalUrl']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playlistId': serializer.toJson<String>(playlistId),
      'name': serializer.toJson<String>(name),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'coverPath': serializer.toJson<String?>(coverPath),
      'description': serializer.toJson<String?>(description),
      'provider': serializer.toJson<String?>(provider),
      'externalUrl': serializer.toJson<String?>(externalUrl),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  FavoritePlaylist copyWith({
    String? playlistId,
    String? name,
    Value<String?> coverUrl = const Value.absent(),
    Value<String?> coverPath = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> provider = const Value.absent(),
    Value<String?> externalUrl = const Value.absent(),
    DateTime? addedAt,
  }) => FavoritePlaylist(
    playlistId: playlistId ?? this.playlistId,
    name: name ?? this.name,
    coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    description: description.present ? description.value : this.description,
    provider: provider.present ? provider.value : this.provider,
    externalUrl: externalUrl.present ? externalUrl.value : this.externalUrl,
    addedAt: addedAt ?? this.addedAt,
  );
  FavoritePlaylist copyWithCompanion(FavoritePlaylistsCompanion data) {
    return FavoritePlaylist(
      playlistId:
          data.playlistId.present ? data.playlistId.value : this.playlistId,
      name: data.name.present ? data.name.value : this.name,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      description:
          data.description.present ? data.description.value : this.description,
      provider: data.provider.present ? data.provider.value : this.provider,
      externalUrl:
          data.externalUrl.present ? data.externalUrl.value : this.externalUrl,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavoritePlaylist(')
          ..write('playlistId: $playlistId, ')
          ..write('name: $name, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('coverPath: $coverPath, ')
          ..write('description: $description, ')
          ..write('provider: $provider, ')
          ..write('externalUrl: $externalUrl, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    playlistId,
    name,
    coverUrl,
    coverPath,
    description,
    provider,
    externalUrl,
    addedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoritePlaylist &&
          other.playlistId == this.playlistId &&
          other.name == this.name &&
          other.coverUrl == this.coverUrl &&
          other.coverPath == this.coverPath &&
          other.description == this.description &&
          other.provider == this.provider &&
          other.externalUrl == this.externalUrl &&
          other.addedAt == this.addedAt);
}

class FavoritePlaylistsCompanion extends UpdateCompanion<FavoritePlaylist> {
  final Value<String> playlistId;
  final Value<String> name;
  final Value<String?> coverUrl;
  final Value<String?> coverPath;
  final Value<String?> description;
  final Value<String?> provider;
  final Value<String?> externalUrl;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const FavoritePlaylistsCompanion({
    this.playlistId = const Value.absent(),
    this.name = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.description = const Value.absent(),
    this.provider = const Value.absent(),
    this.externalUrl = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavoritePlaylistsCompanion.insert({
    required String playlistId,
    required String name,
    this.coverUrl = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.description = const Value.absent(),
    this.provider = const Value.absent(),
    this.externalUrl = const Value.absent(),
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  }) : playlistId = Value(playlistId),
       name = Value(name),
       addedAt = Value(addedAt);
  static Insertable<FavoritePlaylist> custom({
    Expression<String>? playlistId,
    Expression<String>? name,
    Expression<String>? coverUrl,
    Expression<String>? coverPath,
    Expression<String>? description,
    Expression<String>? provider,
    Expression<String>? externalUrl,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playlistId != null) 'playlist_id': playlistId,
      if (name != null) 'name': name,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (coverPath != null) 'cover_path': coverPath,
      if (description != null) 'description': description,
      if (provider != null) 'provider': provider,
      if (externalUrl != null) 'external_url': externalUrl,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavoritePlaylistsCompanion copyWith({
    Value<String>? playlistId,
    Value<String>? name,
    Value<String?>? coverUrl,
    Value<String?>? coverPath,
    Value<String?>? description,
    Value<String?>? provider,
    Value<String?>? externalUrl,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return FavoritePlaylistsCompanion(
      playlistId: playlistId ?? this.playlistId,
      name: name ?? this.name,
      coverUrl: coverUrl ?? this.coverUrl,
      coverPath: coverPath ?? this.coverPath,
      description: description ?? this.description,
      provider: provider ?? this.provider,
      externalUrl: externalUrl ?? this.externalUrl,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playlistId.present) {
      map['playlist_id'] = Variable<String>(playlistId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (externalUrl.present) {
      map['external_url'] = Variable<String>(externalUrl.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoritePlaylistsCompanion(')
          ..write('playlistId: $playlistId, ')
          ..write('name: $name, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('coverPath: $coverPath, ')
          ..write('description: $description, ')
          ..write('provider: $provider, ')
          ..write('externalUrl: $externalUrl, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CollectionsTable extends Collections
    with TableInfo<$CollectionsTable, Collection> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CollectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverPathMeta = const VerificationMeta(
    'coverPath',
  );
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
    'cover_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customJsonMeta = const VerificationMeta(
    'customJson',
  );
  @override
  late final GeneratedColumn<String> customJson = GeneratedColumn<String>(
    'custom_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _itemJsonMeta = const VerificationMeta(
    'itemJson',
  );
  @override
  late final GeneratedColumn<String> itemJson = GeneratedColumn<String>(
    'item_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    coverPath,
    createdAt,
    updatedAt,
    customJson,
    itemJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'collections';
  @override
  VerificationContext validateIntegrity(
    Insertable<Collection> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('custom_json')) {
      context.handle(
        _customJsonMeta,
        customJson.isAcceptableOrUnknown(data['custom_json']!, _customJsonMeta),
      );
    }
    if (data.containsKey('item_json')) {
      context.handle(
        _itemJsonMeta,
        itemJson.isAcceptableOrUnknown(data['item_json']!, _itemJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Collection map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Collection(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      ),
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
      customJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_json'],
      ),
      itemJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_json'],
      ),
    );
  }

  @override
  $CollectionsTable createAlias(String alias) {
    return $CollectionsTable(attachedDatabase, alias);
  }
}

class Collection extends DataClass implements Insertable<Collection> {
  final String id;
  final String name;
  final String? type;
  final String? coverPath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? customJson;
  final String? itemJson;
  const Collection({
    required this.id,
    required this.name,
    this.type,
    this.coverPath,
    required this.createdAt,
    required this.updatedAt,
    this.customJson,
    this.itemJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || type != null) {
      map['type'] = Variable<String>(type);
    }
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || customJson != null) {
      map['custom_json'] = Variable<String>(customJson);
    }
    if (!nullToAbsent || itemJson != null) {
      map['item_json'] = Variable<String>(itemJson);
    }
    return map;
  }

  CollectionsCompanion toCompanion(bool nullToAbsent) {
    return CollectionsCompanion(
      id: Value(id),
      name: Value(name),
      type: type == null && nullToAbsent ? const Value.absent() : Value(type),
      coverPath:
          coverPath == null && nullToAbsent
              ? const Value.absent()
              : Value(coverPath),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      customJson:
          customJson == null && nullToAbsent
              ? const Value.absent()
              : Value(customJson),
      itemJson:
          itemJson == null && nullToAbsent
              ? const Value.absent()
              : Value(itemJson),
    );
  }

  factory Collection.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Collection(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String?>(json['type']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      customJson: serializer.fromJson<String?>(json['customJson']),
      itemJson: serializer.fromJson<String?>(json['itemJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String?>(type),
      'coverPath': serializer.toJson<String?>(coverPath),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'customJson': serializer.toJson<String?>(customJson),
      'itemJson': serializer.toJson<String?>(itemJson),
    };
  }

  Collection copyWith({
    String? id,
    String? name,
    Value<String?> type = const Value.absent(),
    Value<String?> coverPath = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<String?> customJson = const Value.absent(),
    Value<String?> itemJson = const Value.absent(),
  }) => Collection(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type.present ? type.value : this.type,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    customJson: customJson.present ? customJson.value : this.customJson,
    itemJson: itemJson.present ? itemJson.value : this.itemJson,
  );
  Collection copyWithCompanion(CollectionsCompanion data) {
    return Collection(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      customJson:
          data.customJson.present ? data.customJson.value : this.customJson,
      itemJson: data.itemJson.present ? data.itemJson.value : this.itemJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Collection(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('coverPath: $coverPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('customJson: $customJson, ')
          ..write('itemJson: $itemJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    coverPath,
    createdAt,
    updatedAt,
    customJson,
    itemJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Collection &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.coverPath == this.coverPath &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.customJson == this.customJson &&
          other.itemJson == this.itemJson);
}

class CollectionsCompanion extends UpdateCompanion<Collection> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> type;
  final Value<String?> coverPath;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String?> customJson;
  final Value<String?> itemJson;
  final Value<int> rowid;
  const CollectionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.customJson = const Value.absent(),
    this.itemJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CollectionsCompanion.insert({
    required String id,
    required String name,
    this.type = const Value.absent(),
    this.coverPath = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.customJson = const Value.absent(),
    this.itemJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Collection> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? coverPath,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? customJson,
    Expression<String>? itemJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (coverPath != null) 'cover_path': coverPath,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (customJson != null) 'custom_json': customJson,
      if (itemJson != null) 'item_json': itemJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CollectionsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? type,
    Value<String?>? coverPath,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String?>? customJson,
    Value<String?>? itemJson,
    Value<int>? rowid,
  }) {
    return CollectionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      coverPath: coverPath ?? this.coverPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customJson: customJson ?? this.customJson,
      itemJson: itemJson ?? this.itemJson,
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
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (customJson.present) {
      map['custom_json'] = Variable<String>(customJson.value);
    }
    if (itemJson.present) {
      map['item_json'] = Variable<String>(itemJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CollectionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('coverPath: $coverPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('customJson: $customJson, ')
          ..write('itemJson: $itemJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CollectionItemsTable extends CollectionItems
    with TableInfo<$CollectionItemsTable, CollectionItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CollectionItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _collectionIdMeta = const VerificationMeta(
    'collectionId',
  );
  @override
  late final GeneratedColumn<String> collectionId = GeneratedColumn<String>(
    'collection_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES collections (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
    'track_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tracks (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _itemJsonMeta = const VerificationMeta(
    'itemJson',
  );
  @override
  late final GeneratedColumn<String> itemJson = GeneratedColumn<String>(
    'item_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    collectionId,
    itemId,
    trackId,
    itemJson,
    addedAt,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'collection_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<CollectionItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('collection_id')) {
      context.handle(
        _collectionIdMeta,
        collectionId.isAcceptableOrUnknown(
          data['collection_id']!,
          _collectionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_collectionIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    }
    if (data.containsKey('item_json')) {
      context.handle(
        _itemJsonMeta,
        itemJson.isAcceptableOrUnknown(data['item_json']!, _itemJsonMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {collectionId, itemId};
  @override
  CollectionItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CollectionItem(
      collectionId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}collection_id'],
          )!,
      itemId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}item_id'],
          )!,
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_id'],
      ),
      itemJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_json'],
      ),
      addedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}added_at'],
          )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      ),
    );
  }

  @override
  $CollectionItemsTable createAlias(String alias) {
    return $CollectionItemsTable(attachedDatabase, alias);
  }
}

class CollectionItem extends DataClass implements Insertable<CollectionItem> {
  final String collectionId;
  final String itemId;
  final String? trackId;
  final String? itemJson;
  final DateTime addedAt;
  final int? position;
  const CollectionItem({
    required this.collectionId,
    required this.itemId,
    this.trackId,
    this.itemJson,
    required this.addedAt,
    this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['collection_id'] = Variable<String>(collectionId);
    map['item_id'] = Variable<String>(itemId);
    if (!nullToAbsent || trackId != null) {
      map['track_id'] = Variable<String>(trackId);
    }
    if (!nullToAbsent || itemJson != null) {
      map['item_json'] = Variable<String>(itemJson);
    }
    map['added_at'] = Variable<DateTime>(addedAt);
    if (!nullToAbsent || position != null) {
      map['position'] = Variable<int>(position);
    }
    return map;
  }

  CollectionItemsCompanion toCompanion(bool nullToAbsent) {
    return CollectionItemsCompanion(
      collectionId: Value(collectionId),
      itemId: Value(itemId),
      trackId:
          trackId == null && nullToAbsent
              ? const Value.absent()
              : Value(trackId),
      itemJson:
          itemJson == null && nullToAbsent
              ? const Value.absent()
              : Value(itemJson),
      addedAt: Value(addedAt),
      position:
          position == null && nullToAbsent
              ? const Value.absent()
              : Value(position),
    );
  }

  factory CollectionItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CollectionItem(
      collectionId: serializer.fromJson<String>(json['collectionId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      trackId: serializer.fromJson<String?>(json['trackId']),
      itemJson: serializer.fromJson<String?>(json['itemJson']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      position: serializer.fromJson<int?>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'collectionId': serializer.toJson<String>(collectionId),
      'itemId': serializer.toJson<String>(itemId),
      'trackId': serializer.toJson<String?>(trackId),
      'itemJson': serializer.toJson<String?>(itemJson),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'position': serializer.toJson<int?>(position),
    };
  }

  CollectionItem copyWith({
    String? collectionId,
    String? itemId,
    Value<String?> trackId = const Value.absent(),
    Value<String?> itemJson = const Value.absent(),
    DateTime? addedAt,
    Value<int?> position = const Value.absent(),
  }) => CollectionItem(
    collectionId: collectionId ?? this.collectionId,
    itemId: itemId ?? this.itemId,
    trackId: trackId.present ? trackId.value : this.trackId,
    itemJson: itemJson.present ? itemJson.value : this.itemJson,
    addedAt: addedAt ?? this.addedAt,
    position: position.present ? position.value : this.position,
  );
  CollectionItem copyWithCompanion(CollectionItemsCompanion data) {
    return CollectionItem(
      collectionId:
          data.collectionId.present
              ? data.collectionId.value
              : this.collectionId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      itemJson: data.itemJson.present ? data.itemJson.value : this.itemJson,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CollectionItem(')
          ..write('collectionId: $collectionId, ')
          ..write('itemId: $itemId, ')
          ..write('trackId: $trackId, ')
          ..write('itemJson: $itemJson, ')
          ..write('addedAt: $addedAt, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(collectionId, itemId, trackId, itemJson, addedAt, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CollectionItem &&
          other.collectionId == this.collectionId &&
          other.itemId == this.itemId &&
          other.trackId == this.trackId &&
          other.itemJson == this.itemJson &&
          other.addedAt == this.addedAt &&
          other.position == this.position);
}

class CollectionItemsCompanion extends UpdateCompanion<CollectionItem> {
  final Value<String> collectionId;
  final Value<String> itemId;
  final Value<String?> trackId;
  final Value<String?> itemJson;
  final Value<DateTime> addedAt;
  final Value<int?> position;
  final Value<int> rowid;
  const CollectionItemsCompanion({
    this.collectionId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.trackId = const Value.absent(),
    this.itemJson = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CollectionItemsCompanion.insert({
    required String collectionId,
    required String itemId,
    this.trackId = const Value.absent(),
    this.itemJson = const Value.absent(),
    required DateTime addedAt,
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : collectionId = Value(collectionId),
       itemId = Value(itemId),
       addedAt = Value(addedAt);
  static Insertable<CollectionItem> custom({
    Expression<String>? collectionId,
    Expression<String>? itemId,
    Expression<String>? trackId,
    Expression<String>? itemJson,
    Expression<DateTime>? addedAt,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (collectionId != null) 'collection_id': collectionId,
      if (itemId != null) 'item_id': itemId,
      if (trackId != null) 'track_id': trackId,
      if (itemJson != null) 'item_json': itemJson,
      if (addedAt != null) 'added_at': addedAt,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CollectionItemsCompanion copyWith({
    Value<String>? collectionId,
    Value<String>? itemId,
    Value<String?>? trackId,
    Value<String?>? itemJson,
    Value<DateTime>? addedAt,
    Value<int?>? position,
    Value<int>? rowid,
  }) {
    return CollectionItemsCompanion(
      collectionId: collectionId ?? this.collectionId,
      itemId: itemId ?? this.itemId,
      trackId: trackId ?? this.trackId,
      itemJson: itemJson ?? this.itemJson,
      addedAt: addedAt ?? this.addedAt,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (collectionId.present) {
      map['collection_id'] = Variable<String>(collectionId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (itemJson.present) {
      map['item_json'] = Variable<String>(itemJson.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CollectionItemsCompanion(')
          ..write('collectionId: $collectionId, ')
          ..write('itemId: $itemId, ')
          ..write('trackId: $trackId, ')
          ..write('itemJson: $itemJson, ')
          ..write('addedAt: $addedAt, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlayHistoryTable extends PlayHistory
    with TableInfo<$PlayHistoryTable, PlayHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
    'track_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trackNameMeta = const VerificationMeta(
    'trackName',
  );
  @override
  late final GeneratedColumn<String> trackName = GeneratedColumn<String>(
    'track_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistNameMeta = const VerificationMeta(
    'artistName',
  );
  @override
  late final GeneratedColumn<String> artistName = GeneratedColumn<String>(
    'artist_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _albumNameMeta = const VerificationMeta(
    'albumName',
  );
  @override
  late final GeneratedColumn<String> albumName = GeneratedColumn<String>(
    'album_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _playedAtMeta = const VerificationMeta(
    'playedAt',
  );
  @override
  late final GeneratedColumn<DateTime> playedAt = GeneratedColumn<DateTime>(
    'played_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _percentageMeta = const VerificationMeta(
    'percentage',
  );
  @override
  late final GeneratedColumn<int> percentage = GeneratedColumn<int>(
    'percentage',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    trackId,
    trackName,
    artistName,
    albumName,
    playedAt,
    durationMs,
    percentage,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'play_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlayHistoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    }
    if (data.containsKey('track_name')) {
      context.handle(
        _trackNameMeta,
        trackName.isAcceptableOrUnknown(data['track_name']!, _trackNameMeta),
      );
    } else if (isInserting) {
      context.missing(_trackNameMeta);
    }
    if (data.containsKey('artist_name')) {
      context.handle(
        _artistNameMeta,
        artistName.isAcceptableOrUnknown(data['artist_name']!, _artistNameMeta),
      );
    } else if (isInserting) {
      context.missing(_artistNameMeta);
    }
    if (data.containsKey('album_name')) {
      context.handle(
        _albumNameMeta,
        albumName.isAcceptableOrUnknown(data['album_name']!, _albumNameMeta),
      );
    }
    if (data.containsKey('played_at')) {
      context.handle(
        _playedAtMeta,
        playedAt.isAcceptableOrUnknown(data['played_at']!, _playedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_playedAtMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('percentage')) {
      context.handle(
        _percentageMeta,
        percentage.isAcceptableOrUnknown(data['percentage']!, _percentageMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlayHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlayHistoryData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_id'],
      ),
      trackName:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}track_name'],
          )!,
      artistName:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}artist_name'],
          )!,
      albumName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_name'],
      ),
      playedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}played_at'],
          )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      percentage: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}percentage'],
      ),
    );
  }

  @override
  $PlayHistoryTable createAlias(String alias) {
    return $PlayHistoryTable(attachedDatabase, alias);
  }
}

class PlayHistoryData extends DataClass implements Insertable<PlayHistoryData> {
  final int id;
  final String? trackId;
  final String trackName;
  final String artistName;
  final String? albumName;
  final DateTime playedAt;
  final int? durationMs;
  final int? percentage;
  const PlayHistoryData({
    required this.id,
    this.trackId,
    required this.trackName,
    required this.artistName,
    this.albumName,
    required this.playedAt,
    this.durationMs,
    this.percentage,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || trackId != null) {
      map['track_id'] = Variable<String>(trackId);
    }
    map['track_name'] = Variable<String>(trackName);
    map['artist_name'] = Variable<String>(artistName);
    if (!nullToAbsent || albumName != null) {
      map['album_name'] = Variable<String>(albumName);
    }
    map['played_at'] = Variable<DateTime>(playedAt);
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    if (!nullToAbsent || percentage != null) {
      map['percentage'] = Variable<int>(percentage);
    }
    return map;
  }

  PlayHistoryCompanion toCompanion(bool nullToAbsent) {
    return PlayHistoryCompanion(
      id: Value(id),
      trackId:
          trackId == null && nullToAbsent
              ? const Value.absent()
              : Value(trackId),
      trackName: Value(trackName),
      artistName: Value(artistName),
      albumName:
          albumName == null && nullToAbsent
              ? const Value.absent()
              : Value(albumName),
      playedAt: Value(playedAt),
      durationMs:
          durationMs == null && nullToAbsent
              ? const Value.absent()
              : Value(durationMs),
      percentage:
          percentage == null && nullToAbsent
              ? const Value.absent()
              : Value(percentage),
    );
  }

  factory PlayHistoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlayHistoryData(
      id: serializer.fromJson<int>(json['id']),
      trackId: serializer.fromJson<String?>(json['trackId']),
      trackName: serializer.fromJson<String>(json['trackName']),
      artistName: serializer.fromJson<String>(json['artistName']),
      albumName: serializer.fromJson<String?>(json['albumName']),
      playedAt: serializer.fromJson<DateTime>(json['playedAt']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      percentage: serializer.fromJson<int?>(json['percentage']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trackId': serializer.toJson<String?>(trackId),
      'trackName': serializer.toJson<String>(trackName),
      'artistName': serializer.toJson<String>(artistName),
      'albumName': serializer.toJson<String?>(albumName),
      'playedAt': serializer.toJson<DateTime>(playedAt),
      'durationMs': serializer.toJson<int?>(durationMs),
      'percentage': serializer.toJson<int?>(percentage),
    };
  }

  PlayHistoryData copyWith({
    int? id,
    Value<String?> trackId = const Value.absent(),
    String? trackName,
    String? artistName,
    Value<String?> albumName = const Value.absent(),
    DateTime? playedAt,
    Value<int?> durationMs = const Value.absent(),
    Value<int?> percentage = const Value.absent(),
  }) => PlayHistoryData(
    id: id ?? this.id,
    trackId: trackId.present ? trackId.value : this.trackId,
    trackName: trackName ?? this.trackName,
    artistName: artistName ?? this.artistName,
    albumName: albumName.present ? albumName.value : this.albumName,
    playedAt: playedAt ?? this.playedAt,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    percentage: percentage.present ? percentage.value : this.percentage,
  );
  PlayHistoryData copyWithCompanion(PlayHistoryCompanion data) {
    return PlayHistoryData(
      id: data.id.present ? data.id.value : this.id,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      trackName: data.trackName.present ? data.trackName.value : this.trackName,
      artistName:
          data.artistName.present ? data.artistName.value : this.artistName,
      albumName: data.albumName.present ? data.albumName.value : this.albumName,
      playedAt: data.playedAt.present ? data.playedAt.value : this.playedAt,
      durationMs:
          data.durationMs.present ? data.durationMs.value : this.durationMs,
      percentage:
          data.percentage.present ? data.percentage.value : this.percentage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlayHistoryData(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('trackName: $trackName, ')
          ..write('artistName: $artistName, ')
          ..write('albumName: $albumName, ')
          ..write('playedAt: $playedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('percentage: $percentage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    trackId,
    trackName,
    artistName,
    albumName,
    playedAt,
    durationMs,
    percentage,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayHistoryData &&
          other.id == this.id &&
          other.trackId == this.trackId &&
          other.trackName == this.trackName &&
          other.artistName == this.artistName &&
          other.albumName == this.albumName &&
          other.playedAt == this.playedAt &&
          other.durationMs == this.durationMs &&
          other.percentage == this.percentage);
}

class PlayHistoryCompanion extends UpdateCompanion<PlayHistoryData> {
  final Value<int> id;
  final Value<String?> trackId;
  final Value<String> trackName;
  final Value<String> artistName;
  final Value<String?> albumName;
  final Value<DateTime> playedAt;
  final Value<int?> durationMs;
  final Value<int?> percentage;
  const PlayHistoryCompanion({
    this.id = const Value.absent(),
    this.trackId = const Value.absent(),
    this.trackName = const Value.absent(),
    this.artistName = const Value.absent(),
    this.albumName = const Value.absent(),
    this.playedAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.percentage = const Value.absent(),
  });
  PlayHistoryCompanion.insert({
    this.id = const Value.absent(),
    this.trackId = const Value.absent(),
    required String trackName,
    required String artistName,
    this.albumName = const Value.absent(),
    required DateTime playedAt,
    this.durationMs = const Value.absent(),
    this.percentage = const Value.absent(),
  }) : trackName = Value(trackName),
       artistName = Value(artistName),
       playedAt = Value(playedAt);
  static Insertable<PlayHistoryData> custom({
    Expression<int>? id,
    Expression<String>? trackId,
    Expression<String>? trackName,
    Expression<String>? artistName,
    Expression<String>? albumName,
    Expression<DateTime>? playedAt,
    Expression<int>? durationMs,
    Expression<int>? percentage,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trackId != null) 'track_id': trackId,
      if (trackName != null) 'track_name': trackName,
      if (artistName != null) 'artist_name': artistName,
      if (albumName != null) 'album_name': albumName,
      if (playedAt != null) 'played_at': playedAt,
      if (durationMs != null) 'duration_ms': durationMs,
      if (percentage != null) 'percentage': percentage,
    });
  }

  PlayHistoryCompanion copyWith({
    Value<int>? id,
    Value<String?>? trackId,
    Value<String>? trackName,
    Value<String>? artistName,
    Value<String?>? albumName,
    Value<DateTime>? playedAt,
    Value<int?>? durationMs,
    Value<int?>? percentage,
  }) {
    return PlayHistoryCompanion(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      trackName: trackName ?? this.trackName,
      artistName: artistName ?? this.artistName,
      albumName: albumName ?? this.albumName,
      playedAt: playedAt ?? this.playedAt,
      durationMs: durationMs ?? this.durationMs,
      percentage: percentage ?? this.percentage,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (trackName.present) {
      map['track_name'] = Variable<String>(trackName.value);
    }
    if (artistName.present) {
      map['artist_name'] = Variable<String>(artistName.value);
    }
    if (albumName.present) {
      map['album_name'] = Variable<String>(albumName.value);
    }
    if (playedAt.present) {
      map['played_at'] = Variable<DateTime>(playedAt.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (percentage.present) {
      map['percentage'] = Variable<int>(percentage.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayHistoryCompanion(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('trackName: $trackName, ')
          ..write('artistName: $artistName, ')
          ..write('albumName: $albumName, ')
          ..write('playedAt: $playedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('percentage: $percentage')
          ..write(')'))
        .toString();
  }
}

class $PlayAggregatesTable extends PlayAggregates
    with TableInfo<$PlayAggregatesTable, PlayAggregate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayAggregatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK(type IN (\'track\', \'album\', \'artist\'))',
  );
  static const VerificationMeta _playCountMeta = const VerificationMeta(
    'playCount',
  );
  @override
  late final GeneratedColumn<int> playCount = GeneratedColumn<int>(
    'play_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastPlayedAtMeta = const VerificationMeta(
    'lastPlayedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastPlayedAt = GeneratedColumn<DateTime>(
    'last_played_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [itemId, type, playCount, lastPlayedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'play_aggregates';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlayAggregate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('play_count')) {
      context.handle(
        _playCountMeta,
        playCount.isAcceptableOrUnknown(data['play_count']!, _playCountMeta),
      );
    }
    if (data.containsKey('last_played_at')) {
      context.handle(
        _lastPlayedAtMeta,
        lastPlayedAt.isAcceptableOrUnknown(
          data['last_played_at']!,
          _lastPlayedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemId};
  @override
  PlayAggregate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlayAggregate(
      itemId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}item_id'],
          )!,
      type:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}type'],
          )!,
      playCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}play_count'],
      ),
      lastPlayedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_played_at'],
      ),
    );
  }

  @override
  $PlayAggregatesTable createAlias(String alias) {
    return $PlayAggregatesTable(attachedDatabase, alias);
  }
}

class PlayAggregate extends DataClass implements Insertable<PlayAggregate> {
  final String itemId;
  final String type;
  final int? playCount;
  final DateTime? lastPlayedAt;
  const PlayAggregate({
    required this.itemId,
    required this.type,
    this.playCount,
    this.lastPlayedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_id'] = Variable<String>(itemId);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || playCount != null) {
      map['play_count'] = Variable<int>(playCount);
    }
    if (!nullToAbsent || lastPlayedAt != null) {
      map['last_played_at'] = Variable<DateTime>(lastPlayedAt);
    }
    return map;
  }

  PlayAggregatesCompanion toCompanion(bool nullToAbsent) {
    return PlayAggregatesCompanion(
      itemId: Value(itemId),
      type: Value(type),
      playCount:
          playCount == null && nullToAbsent
              ? const Value.absent()
              : Value(playCount),
      lastPlayedAt:
          lastPlayedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(lastPlayedAt),
    );
  }

  factory PlayAggregate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlayAggregate(
      itemId: serializer.fromJson<String>(json['itemId']),
      type: serializer.fromJson<String>(json['type']),
      playCount: serializer.fromJson<int?>(json['playCount']),
      lastPlayedAt: serializer.fromJson<DateTime?>(json['lastPlayedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemId': serializer.toJson<String>(itemId),
      'type': serializer.toJson<String>(type),
      'playCount': serializer.toJson<int?>(playCount),
      'lastPlayedAt': serializer.toJson<DateTime?>(lastPlayedAt),
    };
  }

  PlayAggregate copyWith({
    String? itemId,
    String? type,
    Value<int?> playCount = const Value.absent(),
    Value<DateTime?> lastPlayedAt = const Value.absent(),
  }) => PlayAggregate(
    itemId: itemId ?? this.itemId,
    type: type ?? this.type,
    playCount: playCount.present ? playCount.value : this.playCount,
    lastPlayedAt: lastPlayedAt.present ? lastPlayedAt.value : this.lastPlayedAt,
  );
  PlayAggregate copyWithCompanion(PlayAggregatesCompanion data) {
    return PlayAggregate(
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      type: data.type.present ? data.type.value : this.type,
      playCount: data.playCount.present ? data.playCount.value : this.playCount,
      lastPlayedAt:
          data.lastPlayedAt.present
              ? data.lastPlayedAt.value
              : this.lastPlayedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlayAggregate(')
          ..write('itemId: $itemId, ')
          ..write('type: $type, ')
          ..write('playCount: $playCount, ')
          ..write('lastPlayedAt: $lastPlayedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(itemId, type, playCount, lastPlayedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayAggregate &&
          other.itemId == this.itemId &&
          other.type == this.type &&
          other.playCount == this.playCount &&
          other.lastPlayedAt == this.lastPlayedAt);
}

class PlayAggregatesCompanion extends UpdateCompanion<PlayAggregate> {
  final Value<String> itemId;
  final Value<String> type;
  final Value<int?> playCount;
  final Value<DateTime?> lastPlayedAt;
  final Value<int> rowid;
  const PlayAggregatesCompanion({
    this.itemId = const Value.absent(),
    this.type = const Value.absent(),
    this.playCount = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlayAggregatesCompanion.insert({
    required String itemId,
    required String type,
    this.playCount = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : itemId = Value(itemId),
       type = Value(type);
  static Insertable<PlayAggregate> custom({
    Expression<String>? itemId,
    Expression<String>? type,
    Expression<int>? playCount,
    Expression<DateTime>? lastPlayedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemId != null) 'item_id': itemId,
      if (type != null) 'type': type,
      if (playCount != null) 'play_count': playCount,
      if (lastPlayedAt != null) 'last_played_at': lastPlayedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlayAggregatesCompanion copyWith({
    Value<String>? itemId,
    Value<String>? type,
    Value<int?>? playCount,
    Value<DateTime?>? lastPlayedAt,
    Value<int>? rowid,
  }) {
    return PlayAggregatesCompanion(
      itemId: itemId ?? this.itemId,
      type: type ?? this.type,
      playCount: playCount ?? this.playCount,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (playCount.present) {
      map['play_count'] = Variable<int>(playCount.value);
    }
    if (lastPlayedAt.present) {
      map['last_played_at'] = Variable<DateTime>(lastPlayedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayAggregatesCompanion(')
          ..write('itemId: $itemId, ')
          ..write('type: $type, ')
          ..write('playCount: $playCount, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadQueueTable extends DownloadQueue
    with TableInfo<$DownloadQueueTable, DownloadQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackJsonMeta = const VerificationMeta(
    'trackJson',
  );
  @override
  late final GeneratedColumn<String> trackJson = GeneratedColumn<String>(
    'track_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemJsonMeta = const VerificationMeta(
    'itemJson',
  );
  @override
  late final GeneratedColumn<String> itemJson = GeneratedColumn<String>(
    'item_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT \'pending\' CHECK(status IN (\'pending\', \'downloading\', \'completed\', \'failed\'))',
    defaultValue: const CustomExpression('\'pending\''),
  );
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
    'progress',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    trackJson,
    itemJson,
    status,
    progress,
    createdAt,
    updatedAt,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadQueueData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('track_json')) {
      context.handle(
        _trackJsonMeta,
        trackJson.isAcceptableOrUnknown(data['track_json']!, _trackJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_trackJsonMeta);
    }
    if (data.containsKey('item_json')) {
      context.handle(
        _itemJsonMeta,
        itemJson.isAcceptableOrUnknown(data['item_json']!, _itemJsonMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DownloadQueueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadQueueData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      trackJson:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}track_json'],
          )!,
      itemJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_json'],
      ),
      status:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}status'],
          )!,
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress'],
      ),
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
      addedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}added_at'],
          )!,
    );
  }

  @override
  $DownloadQueueTable createAlias(String alias) {
    return $DownloadQueueTable(attachedDatabase, alias);
  }
}

class DownloadQueueData extends DataClass
    implements Insertable<DownloadQueueData> {
  final String id;
  final String trackJson;
  final String? itemJson;
  final String status;
  final double? progress;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime addedAt;
  const DownloadQueueData({
    required this.id,
    required this.trackJson,
    this.itemJson,
    required this.status,
    this.progress,
    required this.createdAt,
    required this.updatedAt,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['track_json'] = Variable<String>(trackJson);
    if (!nullToAbsent || itemJson != null) {
      map['item_json'] = Variable<String>(itemJson);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || progress != null) {
      map['progress'] = Variable<double>(progress);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  DownloadQueueCompanion toCompanion(bool nullToAbsent) {
    return DownloadQueueCompanion(
      id: Value(id),
      trackJson: Value(trackJson),
      itemJson:
          itemJson == null && nullToAbsent
              ? const Value.absent()
              : Value(itemJson),
      status: Value(status),
      progress:
          progress == null && nullToAbsent
              ? const Value.absent()
              : Value(progress),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      addedAt: Value(addedAt),
    );
  }

  factory DownloadQueueData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadQueueData(
      id: serializer.fromJson<String>(json['id']),
      trackJson: serializer.fromJson<String>(json['trackJson']),
      itemJson: serializer.fromJson<String?>(json['itemJson']),
      status: serializer.fromJson<String>(json['status']),
      progress: serializer.fromJson<double?>(json['progress']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'trackJson': serializer.toJson<String>(trackJson),
      'itemJson': serializer.toJson<String?>(itemJson),
      'status': serializer.toJson<String>(status),
      'progress': serializer.toJson<double?>(progress),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  DownloadQueueData copyWith({
    String? id,
    String? trackJson,
    Value<String?> itemJson = const Value.absent(),
    String? status,
    Value<double?> progress = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? addedAt,
  }) => DownloadQueueData(
    id: id ?? this.id,
    trackJson: trackJson ?? this.trackJson,
    itemJson: itemJson.present ? itemJson.value : this.itemJson,
    status: status ?? this.status,
    progress: progress.present ? progress.value : this.progress,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    addedAt: addedAt ?? this.addedAt,
  );
  DownloadQueueData copyWithCompanion(DownloadQueueCompanion data) {
    return DownloadQueueData(
      id: data.id.present ? data.id.value : this.id,
      trackJson: data.trackJson.present ? data.trackJson.value : this.trackJson,
      itemJson: data.itemJson.present ? data.itemJson.value : this.itemJson,
      status: data.status.present ? data.status.value : this.status,
      progress: data.progress.present ? data.progress.value : this.progress,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadQueueData(')
          ..write('id: $id, ')
          ..write('trackJson: $trackJson, ')
          ..write('itemJson: $itemJson, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    trackJson,
    itemJson,
    status,
    progress,
    createdAt,
    updatedAt,
    addedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadQueueData &&
          other.id == this.id &&
          other.trackJson == this.trackJson &&
          other.itemJson == this.itemJson &&
          other.status == this.status &&
          other.progress == this.progress &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.addedAt == this.addedAt);
}

class DownloadQueueCompanion extends UpdateCompanion<DownloadQueueData> {
  final Value<String> id;
  final Value<String> trackJson;
  final Value<String?> itemJson;
  final Value<String> status;
  final Value<double?> progress;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const DownloadQueueCompanion({
    this.id = const Value.absent(),
    this.trackJson = const Value.absent(),
    this.itemJson = const Value.absent(),
    this.status = const Value.absent(),
    this.progress = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadQueueCompanion.insert({
    required String id,
    required String trackJson,
    this.itemJson = const Value.absent(),
    this.status = const Value.absent(),
    this.progress = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       trackJson = Value(trackJson),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       addedAt = Value(addedAt);
  static Insertable<DownloadQueueData> custom({
    Expression<String>? id,
    Expression<String>? trackJson,
    Expression<String>? itemJson,
    Expression<String>? status,
    Expression<double>? progress,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trackJson != null) 'track_json': trackJson,
      if (itemJson != null) 'item_json': itemJson,
      if (status != null) 'status': status,
      if (progress != null) 'progress': progress,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadQueueCompanion copyWith({
    Value<String>? id,
    Value<String>? trackJson,
    Value<String?>? itemJson,
    Value<String>? status,
    Value<double?>? progress,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return DownloadQueueCompanion(
      id: id ?? this.id,
      trackJson: trackJson ?? this.trackJson,
      itemJson: itemJson ?? this.itemJson,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (trackJson.present) {
      map['track_json'] = Variable<String>(trackJson.value);
    }
    if (itemJson.present) {
      map['item_json'] = Variable<String>(itemJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadQueueCompanion(')
          ..write('id: $id, ')
          ..write('trackJson: $trackJson, ')
          ..write('itemJson: $itemJson, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadHistoryTable extends DownloadHistory
    with TableInfo<$DownloadHistoryTable, DownloadHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackNameMeta = const VerificationMeta(
    'trackName',
  );
  @override
  late final GeneratedColumn<String> trackName = GeneratedColumn<String>(
    'track_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistNameMeta = const VerificationMeta(
    'artistName',
  );
  @override
  late final GeneratedColumn<String> artistName = GeneratedColumn<String>(
    'artist_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _albumNameMeta = const VerificationMeta(
    'albumName',
  );
  @override
  late final GeneratedColumn<String> albumName = GeneratedColumn<String>(
    'album_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isrcMeta = const VerificationMeta('isrc');
  @override
  late final GeneratedColumn<String> isrc = GeneratedColumn<String>(
    'isrc',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serviceMeta = const VerificationMeta(
    'service',
  );
  @override
  late final GeneratedColumn<String> service = GeneratedColumn<String>(
    'service',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMeta = const VerificationMeta(
    'duration',
  );
  @override
  late final GeneratedColumn<int> duration = GeneratedColumn<int>(
    'duration',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _downloadedAtMeta = const VerificationMeta(
    'downloadedAt',
  );
  @override
  late final GeneratedColumn<DateTime> downloadedAt = GeneratedColumn<DateTime>(
    'downloaded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerTrackIdMeta = const VerificationMeta(
    'providerTrackId',
  );
  @override
  late final GeneratedColumn<String> providerTrackId = GeneratedColumn<String>(
    'provider_track_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _providerSourceMeta = const VerificationMeta(
    'providerSource',
  );
  @override
  late final GeneratedColumn<String> providerSource = GeneratedColumn<String>(
    'provider_source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverPathMeta = const VerificationMeta(
    'coverPath',
  );
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
    'cover_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    trackName,
    artistName,
    albumName,
    isrc,
    filePath,
    service,
    duration,
    downloadedAt,
    providerTrackId,
    providerSource,
    coverUrl,
    coverPath,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadHistoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('track_name')) {
      context.handle(
        _trackNameMeta,
        trackName.isAcceptableOrUnknown(data['track_name']!, _trackNameMeta),
      );
    } else if (isInserting) {
      context.missing(_trackNameMeta);
    }
    if (data.containsKey('artist_name')) {
      context.handle(
        _artistNameMeta,
        artistName.isAcceptableOrUnknown(data['artist_name']!, _artistNameMeta),
      );
    } else if (isInserting) {
      context.missing(_artistNameMeta);
    }
    if (data.containsKey('album_name')) {
      context.handle(
        _albumNameMeta,
        albumName.isAcceptableOrUnknown(data['album_name']!, _albumNameMeta),
      );
    }
    if (data.containsKey('isrc')) {
      context.handle(
        _isrcMeta,
        isrc.isAcceptableOrUnknown(data['isrc']!, _isrcMeta),
      );
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    }
    if (data.containsKey('service')) {
      context.handle(
        _serviceMeta,
        service.isAcceptableOrUnknown(data['service']!, _serviceMeta),
      );
    }
    if (data.containsKey('duration')) {
      context.handle(
        _durationMeta,
        duration.isAcceptableOrUnknown(data['duration']!, _durationMeta),
      );
    }
    if (data.containsKey('downloaded_at')) {
      context.handle(
        _downloadedAtMeta,
        downloadedAt.isAcceptableOrUnknown(
          data['downloaded_at']!,
          _downloadedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_downloadedAtMeta);
    }
    if (data.containsKey('provider_track_id')) {
      context.handle(
        _providerTrackIdMeta,
        providerTrackId.isAcceptableOrUnknown(
          data['provider_track_id']!,
          _providerTrackIdMeta,
        ),
      );
    }
    if (data.containsKey('provider_source')) {
      context.handle(
        _providerSourceMeta,
        providerSource.isAcceptableOrUnknown(
          data['provider_source']!,
          _providerSourceMeta,
        ),
      );
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
      );
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DownloadHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadHistoryData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      trackName:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}track_name'],
          )!,
      artistName:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}artist_name'],
          )!,
      albumName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_name'],
      ),
      isrc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}isrc'],
      ),
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      ),
      service: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}service'],
      ),
      duration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration'],
      ),
      downloadedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}downloaded_at'],
          )!,
      providerTrackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_track_id'],
      ),
      providerSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_source'],
      ),
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      ),
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
    );
  }

  @override
  $DownloadHistoryTable createAlias(String alias) {
    return $DownloadHistoryTable(attachedDatabase, alias);
  }
}

class DownloadHistoryData extends DataClass
    implements Insertable<DownloadHistoryData> {
  final String id;
  final String trackName;
  final String artistName;
  final String? albumName;
  final String? isrc;
  final String? filePath;
  final String? service;
  final int? duration;
  final DateTime downloadedAt;
  final String? providerTrackId;
  final String? providerSource;
  final String? coverUrl;
  final String? coverPath;
  const DownloadHistoryData({
    required this.id,
    required this.trackName,
    required this.artistName,
    this.albumName,
    this.isrc,
    this.filePath,
    this.service,
    this.duration,
    required this.downloadedAt,
    this.providerTrackId,
    this.providerSource,
    this.coverUrl,
    this.coverPath,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['track_name'] = Variable<String>(trackName);
    map['artist_name'] = Variable<String>(artistName);
    if (!nullToAbsent || albumName != null) {
      map['album_name'] = Variable<String>(albumName);
    }
    if (!nullToAbsent || isrc != null) {
      map['isrc'] = Variable<String>(isrc);
    }
    if (!nullToAbsent || filePath != null) {
      map['file_path'] = Variable<String>(filePath);
    }
    if (!nullToAbsent || service != null) {
      map['service'] = Variable<String>(service);
    }
    if (!nullToAbsent || duration != null) {
      map['duration'] = Variable<int>(duration);
    }
    map['downloaded_at'] = Variable<DateTime>(downloadedAt);
    if (!nullToAbsent || providerTrackId != null) {
      map['provider_track_id'] = Variable<String>(providerTrackId);
    }
    if (!nullToAbsent || providerSource != null) {
      map['provider_source'] = Variable<String>(providerSource);
    }
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    return map;
  }

  DownloadHistoryCompanion toCompanion(bool nullToAbsent) {
    return DownloadHistoryCompanion(
      id: Value(id),
      trackName: Value(trackName),
      artistName: Value(artistName),
      albumName:
          albumName == null && nullToAbsent
              ? const Value.absent()
              : Value(albumName),
      isrc: isrc == null && nullToAbsent ? const Value.absent() : Value(isrc),
      filePath:
          filePath == null && nullToAbsent
              ? const Value.absent()
              : Value(filePath),
      service:
          service == null && nullToAbsent
              ? const Value.absent()
              : Value(service),
      duration:
          duration == null && nullToAbsent
              ? const Value.absent()
              : Value(duration),
      downloadedAt: Value(downloadedAt),
      providerTrackId:
          providerTrackId == null && nullToAbsent
              ? const Value.absent()
              : Value(providerTrackId),
      providerSource:
          providerSource == null && nullToAbsent
              ? const Value.absent()
              : Value(providerSource),
      coverUrl:
          coverUrl == null && nullToAbsent
              ? const Value.absent()
              : Value(coverUrl),
      coverPath:
          coverPath == null && nullToAbsent
              ? const Value.absent()
              : Value(coverPath),
    );
  }

  factory DownloadHistoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadHistoryData(
      id: serializer.fromJson<String>(json['id']),
      trackName: serializer.fromJson<String>(json['trackName']),
      artistName: serializer.fromJson<String>(json['artistName']),
      albumName: serializer.fromJson<String?>(json['albumName']),
      isrc: serializer.fromJson<String?>(json['isrc']),
      filePath: serializer.fromJson<String?>(json['filePath']),
      service: serializer.fromJson<String?>(json['service']),
      duration: serializer.fromJson<int?>(json['duration']),
      downloadedAt: serializer.fromJson<DateTime>(json['downloadedAt']),
      providerTrackId: serializer.fromJson<String?>(json['providerTrackId']),
      providerSource: serializer.fromJson<String?>(json['providerSource']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'trackName': serializer.toJson<String>(trackName),
      'artistName': serializer.toJson<String>(artistName),
      'albumName': serializer.toJson<String?>(albumName),
      'isrc': serializer.toJson<String?>(isrc),
      'filePath': serializer.toJson<String?>(filePath),
      'service': serializer.toJson<String?>(service),
      'duration': serializer.toJson<int?>(duration),
      'downloadedAt': serializer.toJson<DateTime>(downloadedAt),
      'providerTrackId': serializer.toJson<String?>(providerTrackId),
      'providerSource': serializer.toJson<String?>(providerSource),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'coverPath': serializer.toJson<String?>(coverPath),
    };
  }

  DownloadHistoryData copyWith({
    String? id,
    String? trackName,
    String? artistName,
    Value<String?> albumName = const Value.absent(),
    Value<String?> isrc = const Value.absent(),
    Value<String?> filePath = const Value.absent(),
    Value<String?> service = const Value.absent(),
    Value<int?> duration = const Value.absent(),
    DateTime? downloadedAt,
    Value<String?> providerTrackId = const Value.absent(),
    Value<String?> providerSource = const Value.absent(),
    Value<String?> coverUrl = const Value.absent(),
    Value<String?> coverPath = const Value.absent(),
  }) => DownloadHistoryData(
    id: id ?? this.id,
    trackName: trackName ?? this.trackName,
    artistName: artistName ?? this.artistName,
    albumName: albumName.present ? albumName.value : this.albumName,
    isrc: isrc.present ? isrc.value : this.isrc,
    filePath: filePath.present ? filePath.value : this.filePath,
    service: service.present ? service.value : this.service,
    duration: duration.present ? duration.value : this.duration,
    downloadedAt: downloadedAt ?? this.downloadedAt,
    providerTrackId:
        providerTrackId.present ? providerTrackId.value : this.providerTrackId,
    providerSource:
        providerSource.present ? providerSource.value : this.providerSource,
    coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
  );
  DownloadHistoryData copyWithCompanion(DownloadHistoryCompanion data) {
    return DownloadHistoryData(
      id: data.id.present ? data.id.value : this.id,
      trackName: data.trackName.present ? data.trackName.value : this.trackName,
      artistName:
          data.artistName.present ? data.artistName.value : this.artistName,
      albumName: data.albumName.present ? data.albumName.value : this.albumName,
      isrc: data.isrc.present ? data.isrc.value : this.isrc,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      service: data.service.present ? data.service.value : this.service,
      duration: data.duration.present ? data.duration.value : this.duration,
      downloadedAt:
          data.downloadedAt.present
              ? data.downloadedAt.value
              : this.downloadedAt,
      providerTrackId:
          data.providerTrackId.present
              ? data.providerTrackId.value
              : this.providerTrackId,
      providerSource:
          data.providerSource.present
              ? data.providerSource.value
              : this.providerSource,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadHistoryData(')
          ..write('id: $id, ')
          ..write('trackName: $trackName, ')
          ..write('artistName: $artistName, ')
          ..write('albumName: $albumName, ')
          ..write('isrc: $isrc, ')
          ..write('filePath: $filePath, ')
          ..write('service: $service, ')
          ..write('duration: $duration, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('providerTrackId: $providerTrackId, ')
          ..write('providerSource: $providerSource, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('coverPath: $coverPath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    trackName,
    artistName,
    albumName,
    isrc,
    filePath,
    service,
    duration,
    downloadedAt,
    providerTrackId,
    providerSource,
    coverUrl,
    coverPath,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadHistoryData &&
          other.id == this.id &&
          other.trackName == this.trackName &&
          other.artistName == this.artistName &&
          other.albumName == this.albumName &&
          other.isrc == this.isrc &&
          other.filePath == this.filePath &&
          other.service == this.service &&
          other.duration == this.duration &&
          other.downloadedAt == this.downloadedAt &&
          other.providerTrackId == this.providerTrackId &&
          other.providerSource == this.providerSource &&
          other.coverUrl == this.coverUrl &&
          other.coverPath == this.coverPath);
}

class DownloadHistoryCompanion extends UpdateCompanion<DownloadHistoryData> {
  final Value<String> id;
  final Value<String> trackName;
  final Value<String> artistName;
  final Value<String?> albumName;
  final Value<String?> isrc;
  final Value<String?> filePath;
  final Value<String?> service;
  final Value<int?> duration;
  final Value<DateTime> downloadedAt;
  final Value<String?> providerTrackId;
  final Value<String?> providerSource;
  final Value<String?> coverUrl;
  final Value<String?> coverPath;
  final Value<int> rowid;
  const DownloadHistoryCompanion({
    this.id = const Value.absent(),
    this.trackName = const Value.absent(),
    this.artistName = const Value.absent(),
    this.albumName = const Value.absent(),
    this.isrc = const Value.absent(),
    this.filePath = const Value.absent(),
    this.service = const Value.absent(),
    this.duration = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.providerTrackId = const Value.absent(),
    this.providerSource = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadHistoryCompanion.insert({
    required String id,
    required String trackName,
    required String artistName,
    this.albumName = const Value.absent(),
    this.isrc = const Value.absent(),
    this.filePath = const Value.absent(),
    this.service = const Value.absent(),
    this.duration = const Value.absent(),
    required DateTime downloadedAt,
    this.providerTrackId = const Value.absent(),
    this.providerSource = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       trackName = Value(trackName),
       artistName = Value(artistName),
       downloadedAt = Value(downloadedAt);
  static Insertable<DownloadHistoryData> custom({
    Expression<String>? id,
    Expression<String>? trackName,
    Expression<String>? artistName,
    Expression<String>? albumName,
    Expression<String>? isrc,
    Expression<String>? filePath,
    Expression<String>? service,
    Expression<int>? duration,
    Expression<DateTime>? downloadedAt,
    Expression<String>? providerTrackId,
    Expression<String>? providerSource,
    Expression<String>? coverUrl,
    Expression<String>? coverPath,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trackName != null) 'track_name': trackName,
      if (artistName != null) 'artist_name': artistName,
      if (albumName != null) 'album_name': albumName,
      if (isrc != null) 'isrc': isrc,
      if (filePath != null) 'file_path': filePath,
      if (service != null) 'service': service,
      if (duration != null) 'duration': duration,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
      if (providerTrackId != null) 'provider_track_id': providerTrackId,
      if (providerSource != null) 'provider_source': providerSource,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (coverPath != null) 'cover_path': coverPath,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadHistoryCompanion copyWith({
    Value<String>? id,
    Value<String>? trackName,
    Value<String>? artistName,
    Value<String?>? albumName,
    Value<String?>? isrc,
    Value<String?>? filePath,
    Value<String?>? service,
    Value<int?>? duration,
    Value<DateTime>? downloadedAt,
    Value<String?>? providerTrackId,
    Value<String?>? providerSource,
    Value<String?>? coverUrl,
    Value<String?>? coverPath,
    Value<int>? rowid,
  }) {
    return DownloadHistoryCompanion(
      id: id ?? this.id,
      trackName: trackName ?? this.trackName,
      artistName: artistName ?? this.artistName,
      albumName: albumName ?? this.albumName,
      isrc: isrc ?? this.isrc,
      filePath: filePath ?? this.filePath,
      service: service ?? this.service,
      duration: duration ?? this.duration,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      providerTrackId: providerTrackId ?? this.providerTrackId,
      providerSource: providerSource ?? this.providerSource,
      coverUrl: coverUrl ?? this.coverUrl,
      coverPath: coverPath ?? this.coverPath,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (trackName.present) {
      map['track_name'] = Variable<String>(trackName.value);
    }
    if (artistName.present) {
      map['artist_name'] = Variable<String>(artistName.value);
    }
    if (albumName.present) {
      map['album_name'] = Variable<String>(albumName.value);
    }
    if (isrc.present) {
      map['isrc'] = Variable<String>(isrc.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (service.present) {
      map['service'] = Variable<String>(service.value);
    }
    if (duration.present) {
      map['duration'] = Variable<int>(duration.value);
    }
    if (downloadedAt.present) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt.value);
    }
    if (providerTrackId.present) {
      map['provider_track_id'] = Variable<String>(providerTrackId.value);
    }
    if (providerSource.present) {
      map['provider_source'] = Variable<String>(providerSource.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadHistoryCompanion(')
          ..write('id: $id, ')
          ..write('trackName: $trackName, ')
          ..write('artistName: $artistName, ')
          ..write('albumName: $albumName, ')
          ..write('isrc: $isrc, ')
          ..write('filePath: $filePath, ')
          ..write('service: $service, ')
          ..write('duration: $duration, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('providerTrackId: $providerTrackId, ')
          ..write('providerSource: $providerSource, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('coverPath: $coverPath, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadBatchesTable extends DownloadBatches
    with TableInfo<$DownloadBatchesTable, DownloadBatche> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadBatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _batchKeyMeta = const VerificationMeta(
    'batchKey',
  );
  @override
  late final GeneratedColumn<String> batchKey = GeneratedColumn<String>(
    'batch_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemTypeMeta = const VerificationMeta(
    'itemType',
  );
  @override
  late final GeneratedColumn<String> itemType = GeneratedColumn<String>(
    'item_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trackIdsMeta = const VerificationMeta(
    'trackIds',
  );
  @override
  late final GeneratedColumn<String> trackIds = GeneratedColumn<String>(
    'track_ids',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _downloadedAtMeta = const VerificationMeta(
    'downloadedAt',
  );
  @override
  late final GeneratedColumn<DateTime> downloadedAt = GeneratedColumn<DateTime>(
    'downloaded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    batchKey,
    itemType,
    itemId,
    source,
    name,
    trackIds,
    downloadedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_batches';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadBatche> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('batch_key')) {
      context.handle(
        _batchKeyMeta,
        batchKey.isAcceptableOrUnknown(data['batch_key']!, _batchKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_batchKeyMeta);
    }
    if (data.containsKey('item_type')) {
      context.handle(
        _itemTypeMeta,
        itemType.isAcceptableOrUnknown(data['item_type']!, _itemTypeMeta),
      );
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('track_ids')) {
      context.handle(
        _trackIdsMeta,
        trackIds.isAcceptableOrUnknown(data['track_ids']!, _trackIdsMeta),
      );
    }
    if (data.containsKey('downloaded_at')) {
      context.handle(
        _downloadedAtMeta,
        downloadedAt.isAcceptableOrUnknown(
          data['downloaded_at']!,
          _downloadedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_downloadedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {batchKey};
  @override
  DownloadBatche map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadBatche(
      batchKey:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}batch_key'],
          )!,
      itemType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_type'],
      ),
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      trackIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_ids'],
      ),
      downloadedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}downloaded_at'],
          )!,
    );
  }

  @override
  $DownloadBatchesTable createAlias(String alias) {
    return $DownloadBatchesTable(attachedDatabase, alias);
  }
}

class DownloadBatche extends DataClass implements Insertable<DownloadBatche> {
  final String batchKey;
  final String? itemType;
  final String? itemId;
  final String? source;
  final String? name;
  final String? trackIds;
  final DateTime downloadedAt;
  const DownloadBatche({
    required this.batchKey,
    this.itemType,
    this.itemId,
    this.source,
    this.name,
    this.trackIds,
    required this.downloadedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['batch_key'] = Variable<String>(batchKey);
    if (!nullToAbsent || itemType != null) {
      map['item_type'] = Variable<String>(itemType);
    }
    if (!nullToAbsent || itemId != null) {
      map['item_id'] = Variable<String>(itemId);
    }
    if (!nullToAbsent || source != null) {
      map['source'] = Variable<String>(source);
    }
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || trackIds != null) {
      map['track_ids'] = Variable<String>(trackIds);
    }
    map['downloaded_at'] = Variable<DateTime>(downloadedAt);
    return map;
  }

  DownloadBatchesCompanion toCompanion(bool nullToAbsent) {
    return DownloadBatchesCompanion(
      batchKey: Value(batchKey),
      itemType:
          itemType == null && nullToAbsent
              ? const Value.absent()
              : Value(itemType),
      itemId:
          itemId == null && nullToAbsent ? const Value.absent() : Value(itemId),
      source:
          source == null && nullToAbsent ? const Value.absent() : Value(source),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      trackIds:
          trackIds == null && nullToAbsent
              ? const Value.absent()
              : Value(trackIds),
      downloadedAt: Value(downloadedAt),
    );
  }

  factory DownloadBatche.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadBatche(
      batchKey: serializer.fromJson<String>(json['batchKey']),
      itemType: serializer.fromJson<String?>(json['itemType']),
      itemId: serializer.fromJson<String?>(json['itemId']),
      source: serializer.fromJson<String?>(json['source']),
      name: serializer.fromJson<String?>(json['name']),
      trackIds: serializer.fromJson<String?>(json['trackIds']),
      downloadedAt: serializer.fromJson<DateTime>(json['downloadedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'batchKey': serializer.toJson<String>(batchKey),
      'itemType': serializer.toJson<String?>(itemType),
      'itemId': serializer.toJson<String?>(itemId),
      'source': serializer.toJson<String?>(source),
      'name': serializer.toJson<String?>(name),
      'trackIds': serializer.toJson<String?>(trackIds),
      'downloadedAt': serializer.toJson<DateTime>(downloadedAt),
    };
  }

  DownloadBatche copyWith({
    String? batchKey,
    Value<String?> itemType = const Value.absent(),
    Value<String?> itemId = const Value.absent(),
    Value<String?> source = const Value.absent(),
    Value<String?> name = const Value.absent(),
    Value<String?> trackIds = const Value.absent(),
    DateTime? downloadedAt,
  }) => DownloadBatche(
    batchKey: batchKey ?? this.batchKey,
    itemType: itemType.present ? itemType.value : this.itemType,
    itemId: itemId.present ? itemId.value : this.itemId,
    source: source.present ? source.value : this.source,
    name: name.present ? name.value : this.name,
    trackIds: trackIds.present ? trackIds.value : this.trackIds,
    downloadedAt: downloadedAt ?? this.downloadedAt,
  );
  DownloadBatche copyWithCompanion(DownloadBatchesCompanion data) {
    return DownloadBatche(
      batchKey: data.batchKey.present ? data.batchKey.value : this.batchKey,
      itemType: data.itemType.present ? data.itemType.value : this.itemType,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      source: data.source.present ? data.source.value : this.source,
      name: data.name.present ? data.name.value : this.name,
      trackIds: data.trackIds.present ? data.trackIds.value : this.trackIds,
      downloadedAt:
          data.downloadedAt.present
              ? data.downloadedAt.value
              : this.downloadedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadBatche(')
          ..write('batchKey: $batchKey, ')
          ..write('itemType: $itemType, ')
          ..write('itemId: $itemId, ')
          ..write('source: $source, ')
          ..write('name: $name, ')
          ..write('trackIds: $trackIds, ')
          ..write('downloadedAt: $downloadedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    batchKey,
    itemType,
    itemId,
    source,
    name,
    trackIds,
    downloadedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadBatche &&
          other.batchKey == this.batchKey &&
          other.itemType == this.itemType &&
          other.itemId == this.itemId &&
          other.source == this.source &&
          other.name == this.name &&
          other.trackIds == this.trackIds &&
          other.downloadedAt == this.downloadedAt);
}

class DownloadBatchesCompanion extends UpdateCompanion<DownloadBatche> {
  final Value<String> batchKey;
  final Value<String?> itemType;
  final Value<String?> itemId;
  final Value<String?> source;
  final Value<String?> name;
  final Value<String?> trackIds;
  final Value<DateTime> downloadedAt;
  final Value<int> rowid;
  const DownloadBatchesCompanion({
    this.batchKey = const Value.absent(),
    this.itemType = const Value.absent(),
    this.itemId = const Value.absent(),
    this.source = const Value.absent(),
    this.name = const Value.absent(),
    this.trackIds = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadBatchesCompanion.insert({
    required String batchKey,
    this.itemType = const Value.absent(),
    this.itemId = const Value.absent(),
    this.source = const Value.absent(),
    this.name = const Value.absent(),
    this.trackIds = const Value.absent(),
    required DateTime downloadedAt,
    this.rowid = const Value.absent(),
  }) : batchKey = Value(batchKey),
       downloadedAt = Value(downloadedAt);
  static Insertable<DownloadBatche> custom({
    Expression<String>? batchKey,
    Expression<String>? itemType,
    Expression<String>? itemId,
    Expression<String>? source,
    Expression<String>? name,
    Expression<String>? trackIds,
    Expression<DateTime>? downloadedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (batchKey != null) 'batch_key': batchKey,
      if (itemType != null) 'item_type': itemType,
      if (itemId != null) 'item_id': itemId,
      if (source != null) 'source': source,
      if (name != null) 'name': name,
      if (trackIds != null) 'track_ids': trackIds,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadBatchesCompanion copyWith({
    Value<String>? batchKey,
    Value<String?>? itemType,
    Value<String?>? itemId,
    Value<String?>? source,
    Value<String?>? name,
    Value<String?>? trackIds,
    Value<DateTime>? downloadedAt,
    Value<int>? rowid,
  }) {
    return DownloadBatchesCompanion(
      batchKey: batchKey ?? this.batchKey,
      itemType: itemType ?? this.itemType,
      itemId: itemId ?? this.itemId,
      source: source ?? this.source,
      name: name ?? this.name,
      trackIds: trackIds ?? this.trackIds,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (batchKey.present) {
      map['batch_key'] = Variable<String>(batchKey.value);
    }
    if (itemType.present) {
      map['item_type'] = Variable<String>(itemType.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (trackIds.present) {
      map['track_ids'] = Variable<String>(trackIds.value);
    }
    if (downloadedAt.present) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadBatchesCompanion(')
          ..write('batchKey: $batchKey, ')
          ..write('itemType: $itemType, ')
          ..write('itemId: $itemId, ')
          ..write('source: $source, ')
          ..write('name: $name, ')
          ..write('trackIds: $trackIds, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HiddenDownloadIdsTable extends HiddenDownloadIds
    with TableInfo<$HiddenDownloadIdsTable, HiddenDownloadId> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HiddenDownloadIdsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _downloadIdMeta = const VerificationMeta(
    'downloadId',
  );
  @override
  late final GeneratedColumn<String> downloadId = GeneratedColumn<String>(
    'download_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [downloadId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'hidden_download_ids';
  @override
  VerificationContext validateIntegrity(
    Insertable<HiddenDownloadId> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('download_id')) {
      context.handle(
        _downloadIdMeta,
        downloadId.isAcceptableOrUnknown(data['download_id']!, _downloadIdMeta),
      );
    } else if (isInserting) {
      context.missing(_downloadIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {downloadId};
  @override
  HiddenDownloadId map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HiddenDownloadId(
      downloadId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}download_id'],
          )!,
    );
  }

  @override
  $HiddenDownloadIdsTable createAlias(String alias) {
    return $HiddenDownloadIdsTable(attachedDatabase, alias);
  }
}

class HiddenDownloadId extends DataClass
    implements Insertable<HiddenDownloadId> {
  final String downloadId;
  const HiddenDownloadId({required this.downloadId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['download_id'] = Variable<String>(downloadId);
    return map;
  }

  HiddenDownloadIdsCompanion toCompanion(bool nullToAbsent) {
    return HiddenDownloadIdsCompanion(downloadId: Value(downloadId));
  }

  factory HiddenDownloadId.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HiddenDownloadId(
      downloadId: serializer.fromJson<String>(json['downloadId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'downloadId': serializer.toJson<String>(downloadId),
    };
  }

  HiddenDownloadId copyWith({String? downloadId}) =>
      HiddenDownloadId(downloadId: downloadId ?? this.downloadId);
  HiddenDownloadId copyWithCompanion(HiddenDownloadIdsCompanion data) {
    return HiddenDownloadId(
      downloadId:
          data.downloadId.present ? data.downloadId.value : this.downloadId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HiddenDownloadId(')
          ..write('downloadId: $downloadId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => downloadId.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HiddenDownloadId && other.downloadId == this.downloadId);
}

class HiddenDownloadIdsCompanion extends UpdateCompanion<HiddenDownloadId> {
  final Value<String> downloadId;
  final Value<int> rowid;
  const HiddenDownloadIdsCompanion({
    this.downloadId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HiddenDownloadIdsCompanion.insert({
    required String downloadId,
    this.rowid = const Value.absent(),
  }) : downloadId = Value(downloadId);
  static Insertable<HiddenDownloadId> custom({
    Expression<String>? downloadId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (downloadId != null) 'download_id': downloadId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HiddenDownloadIdsCompanion copyWith({
    Value<String>? downloadId,
    Value<int>? rowid,
  }) {
    return HiddenDownloadIdsCompanion(
      downloadId: downloadId ?? this.downloadId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (downloadId.present) {
      map['download_id'] = Variable<String>(downloadId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HiddenDownloadIdsCompanion(')
          ..write('downloadId: $downloadId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecentSearchesTable extends RecentSearches
    with TableInfo<$RecentSearchesTable, RecentSearche> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecentSearchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _queryMeta = const VerificationMeta('query');
  @override
  late final GeneratedColumn<String> query = GeneratedColumn<String>(
    'query',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _searchedAtMeta = const VerificationMeta(
    'searchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> searchedAt = GeneratedColumn<DateTime>(
    'searched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [query, searchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recent_searches';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecentSearche> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('query')) {
      context.handle(
        _queryMeta,
        query.isAcceptableOrUnknown(data['query']!, _queryMeta),
      );
    } else if (isInserting) {
      context.missing(_queryMeta);
    }
    if (data.containsKey('searched_at')) {
      context.handle(
        _searchedAtMeta,
        searchedAt.isAcceptableOrUnknown(data['searched_at']!, _searchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_searchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {query};
  @override
  RecentSearche map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecentSearche(
      query:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}query'],
          )!,
      searchedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}searched_at'],
          )!,
    );
  }

  @override
  $RecentSearchesTable createAlias(String alias) {
    return $RecentSearchesTable(attachedDatabase, alias);
  }
}

class RecentSearche extends DataClass implements Insertable<RecentSearche> {
  final String query;
  final DateTime searchedAt;
  const RecentSearche({required this.query, required this.searchedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['query'] = Variable<String>(query);
    map['searched_at'] = Variable<DateTime>(searchedAt);
    return map;
  }

  RecentSearchesCompanion toCompanion(bool nullToAbsent) {
    return RecentSearchesCompanion(
      query: Value(query),
      searchedAt: Value(searchedAt),
    );
  }

  factory RecentSearche.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecentSearche(
      query: serializer.fromJson<String>(json['query']),
      searchedAt: serializer.fromJson<DateTime>(json['searchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'query': serializer.toJson<String>(query),
      'searchedAt': serializer.toJson<DateTime>(searchedAt),
    };
  }

  RecentSearche copyWith({String? query, DateTime? searchedAt}) =>
      RecentSearche(
        query: query ?? this.query,
        searchedAt: searchedAt ?? this.searchedAt,
      );
  RecentSearche copyWithCompanion(RecentSearchesCompanion data) {
    return RecentSearche(
      query: data.query.present ? data.query.value : this.query,
      searchedAt:
          data.searchedAt.present ? data.searchedAt.value : this.searchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecentSearche(')
          ..write('query: $query, ')
          ..write('searchedAt: $searchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(query, searchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecentSearche &&
          other.query == this.query &&
          other.searchedAt == this.searchedAt);
}

class RecentSearchesCompanion extends UpdateCompanion<RecentSearche> {
  final Value<String> query;
  final Value<DateTime> searchedAt;
  final Value<int> rowid;
  const RecentSearchesCompanion({
    this.query = const Value.absent(),
    this.searchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecentSearchesCompanion.insert({
    required String query,
    required DateTime searchedAt,
    this.rowid = const Value.absent(),
  }) : query = Value(query),
       searchedAt = Value(searchedAt);
  static Insertable<RecentSearche> custom({
    Expression<String>? query,
    Expression<DateTime>? searchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (query != null) 'query': query,
      if (searchedAt != null) 'searched_at': searchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecentSearchesCompanion copyWith({
    Value<String>? query,
    Value<DateTime>? searchedAt,
    Value<int>? rowid,
  }) {
    return RecentSearchesCompanion(
      query: query ?? this.query,
      searchedAt: searchedAt ?? this.searchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (query.present) {
      map['query'] = Variable<String>(query.value);
    }
    if (searchedAt.present) {
      map['searched_at'] = Variable<DateTime>(searchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecentSearchesCompanion(')
          ..write('query: $query, ')
          ..write('searchedAt: $searchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecentAccessTable extends RecentAccess
    with TableInfo<$RecentAccessTable, RecentAccessData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecentAccessTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemJsonMeta = const VerificationMeta(
    'itemJson',
  );
  @override
  late final GeneratedColumn<String> itemJson = GeneratedColumn<String>(
    'item_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accessedAtMeta = const VerificationMeta(
    'accessedAt',
  );
  @override
  late final GeneratedColumn<DateTime> accessedAt = GeneratedColumn<DateTime>(
    'accessed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, itemJson, type, accessedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recent_access';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecentAccessData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('item_json')) {
      context.handle(
        _itemJsonMeta,
        itemJson.isAcceptableOrUnknown(data['item_json']!, _itemJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_itemJsonMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('accessed_at')) {
      context.handle(
        _accessedAtMeta,
        accessedAt.isAcceptableOrUnknown(data['accessed_at']!, _accessedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_accessedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  RecentAccessData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecentAccessData(
      key:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}key'],
          )!,
      itemJson:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}item_json'],
          )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      ),
      accessedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}accessed_at'],
          )!,
    );
  }

  @override
  $RecentAccessTable createAlias(String alias) {
    return $RecentAccessTable(attachedDatabase, alias);
  }
}

class RecentAccessData extends DataClass
    implements Insertable<RecentAccessData> {
  final String key;
  final String itemJson;
  final String? type;
  final DateTime accessedAt;
  const RecentAccessData({
    required this.key,
    required this.itemJson,
    this.type,
    required this.accessedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['item_json'] = Variable<String>(itemJson);
    if (!nullToAbsent || type != null) {
      map['type'] = Variable<String>(type);
    }
    map['accessed_at'] = Variable<DateTime>(accessedAt);
    return map;
  }

  RecentAccessCompanion toCompanion(bool nullToAbsent) {
    return RecentAccessCompanion(
      key: Value(key),
      itemJson: Value(itemJson),
      type: type == null && nullToAbsent ? const Value.absent() : Value(type),
      accessedAt: Value(accessedAt),
    );
  }

  factory RecentAccessData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecentAccessData(
      key: serializer.fromJson<String>(json['key']),
      itemJson: serializer.fromJson<String>(json['itemJson']),
      type: serializer.fromJson<String?>(json['type']),
      accessedAt: serializer.fromJson<DateTime>(json['accessedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'itemJson': serializer.toJson<String>(itemJson),
      'type': serializer.toJson<String?>(type),
      'accessedAt': serializer.toJson<DateTime>(accessedAt),
    };
  }

  RecentAccessData copyWith({
    String? key,
    String? itemJson,
    Value<String?> type = const Value.absent(),
    DateTime? accessedAt,
  }) => RecentAccessData(
    key: key ?? this.key,
    itemJson: itemJson ?? this.itemJson,
    type: type.present ? type.value : this.type,
    accessedAt: accessedAt ?? this.accessedAt,
  );
  RecentAccessData copyWithCompanion(RecentAccessCompanion data) {
    return RecentAccessData(
      key: data.key.present ? data.key.value : this.key,
      itemJson: data.itemJson.present ? data.itemJson.value : this.itemJson,
      type: data.type.present ? data.type.value : this.type,
      accessedAt:
          data.accessedAt.present ? data.accessedAt.value : this.accessedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecentAccessData(')
          ..write('key: $key, ')
          ..write('itemJson: $itemJson, ')
          ..write('type: $type, ')
          ..write('accessedAt: $accessedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, itemJson, type, accessedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecentAccessData &&
          other.key == this.key &&
          other.itemJson == this.itemJson &&
          other.type == this.type &&
          other.accessedAt == this.accessedAt);
}

class RecentAccessCompanion extends UpdateCompanion<RecentAccessData> {
  final Value<String> key;
  final Value<String> itemJson;
  final Value<String?> type;
  final Value<DateTime> accessedAt;
  final Value<int> rowid;
  const RecentAccessCompanion({
    this.key = const Value.absent(),
    this.itemJson = const Value.absent(),
    this.type = const Value.absent(),
    this.accessedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecentAccessCompanion.insert({
    required String key,
    required String itemJson,
    this.type = const Value.absent(),
    required DateTime accessedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       itemJson = Value(itemJson),
       accessedAt = Value(accessedAt);
  static Insertable<RecentAccessData> custom({
    Expression<String>? key,
    Expression<String>? itemJson,
    Expression<String>? type,
    Expression<DateTime>? accessedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (itemJson != null) 'item_json': itemJson,
      if (type != null) 'type': type,
      if (accessedAt != null) 'accessed_at': accessedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecentAccessCompanion copyWith({
    Value<String>? key,
    Value<String>? itemJson,
    Value<String?>? type,
    Value<DateTime>? accessedAt,
    Value<int>? rowid,
  }) {
    return RecentAccessCompanion(
      key: key ?? this.key,
      itemJson: itemJson ?? this.itemJson,
      type: type ?? this.type,
      accessedAt: accessedAt ?? this.accessedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (itemJson.present) {
      map['item_json'] = Variable<String>(itemJson.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (accessedAt.present) {
      map['accessed_at'] = Variable<DateTime>(accessedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecentAccessCompanion(')
          ..write('key: $key, ')
          ..write('itemJson: $itemJson, ')
          ..write('type: $type, ')
          ..write('accessedAt: $accessedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SecretCountersTable extends SecretCounters
    with TableInfo<$SecretCountersTable, SecretCounter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SecretCountersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<int> value = GeneratedColumn<int>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'secret_counters';
  @override
  VerificationContext validateIntegrity(
    Insertable<SecretCounter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SecretCounter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SecretCounter(
      key:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}key'],
          )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}value'],
      ),
    );
  }

  @override
  $SecretCountersTable createAlias(String alias) {
    return $SecretCountersTable(attachedDatabase, alias);
  }
}

class SecretCounter extends DataClass implements Insertable<SecretCounter> {
  final String key;
  final int? value;
  const SecretCounter({required this.key, this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<int>(value);
    }
    return map;
  }

  SecretCountersCompanion toCompanion(bool nullToAbsent) {
    return SecretCountersCompanion(
      key: Value(key),
      value:
          value == null && nullToAbsent ? const Value.absent() : Value(value),
    );
  }

  factory SecretCounter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SecretCounter(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<int?>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<int?>(value),
    };
  }

  SecretCounter copyWith({
    String? key,
    Value<int?> value = const Value.absent(),
  }) => SecretCounter(
    key: key ?? this.key,
    value: value.present ? value.value : this.value,
  );
  SecretCounter copyWithCompanion(SecretCountersCompanion data) {
    return SecretCounter(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SecretCounter(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SecretCounter &&
          other.key == this.key &&
          other.value == this.value);
}

class SecretCountersCompanion extends UpdateCompanion<SecretCounter> {
  final Value<String> key;
  final Value<int?> value;
  final Value<int> rowid;
  const SecretCountersCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SecretCountersCompanion.insert({
    required String key,
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<SecretCounter> custom({
    Expression<String>? key,
    Expression<int>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SecretCountersCompanion copyWith({
    Value<String>? key,
    Value<int?>? value,
    Value<int>? rowid,
  }) {
    return SecretCountersCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<int>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SecretCountersCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SecretUnlocksTable extends SecretUnlocks
    with TableInfo<$SecretUnlocksTable, SecretUnlock> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SecretUnlocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unlockedAtMeta = const VerificationMeta(
    'unlockedAt',
  );
  @override
  late final GeneratedColumn<DateTime> unlockedAt = GeneratedColumn<DateTime>(
    'unlocked_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, unlockedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'secret_unlocks';
  @override
  VerificationContext validateIntegrity(
    Insertable<SecretUnlock> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('unlocked_at')) {
      context.handle(
        _unlockedAtMeta,
        unlockedAt.isAcceptableOrUnknown(data['unlocked_at']!, _unlockedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_unlockedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SecretUnlock map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SecretUnlock(
      key:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}key'],
          )!,
      unlockedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}unlocked_at'],
          )!,
    );
  }

  @override
  $SecretUnlocksTable createAlias(String alias) {
    return $SecretUnlocksTable(attachedDatabase, alias);
  }
}

class SecretUnlock extends DataClass implements Insertable<SecretUnlock> {
  final String key;
  final DateTime unlockedAt;
  const SecretUnlock({required this.key, required this.unlockedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['unlocked_at'] = Variable<DateTime>(unlockedAt);
    return map;
  }

  SecretUnlocksCompanion toCompanion(bool nullToAbsent) {
    return SecretUnlocksCompanion(
      key: Value(key),
      unlockedAt: Value(unlockedAt),
    );
  }

  factory SecretUnlock.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SecretUnlock(
      key: serializer.fromJson<String>(json['key']),
      unlockedAt: serializer.fromJson<DateTime>(json['unlockedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'unlockedAt': serializer.toJson<DateTime>(unlockedAt),
    };
  }

  SecretUnlock copyWith({String? key, DateTime? unlockedAt}) => SecretUnlock(
    key: key ?? this.key,
    unlockedAt: unlockedAt ?? this.unlockedAt,
  );
  SecretUnlock copyWithCompanion(SecretUnlocksCompanion data) {
    return SecretUnlock(
      key: data.key.present ? data.key.value : this.key,
      unlockedAt:
          data.unlockedAt.present ? data.unlockedAt.value : this.unlockedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SecretUnlock(')
          ..write('key: $key, ')
          ..write('unlockedAt: $unlockedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, unlockedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SecretUnlock &&
          other.key == this.key &&
          other.unlockedAt == this.unlockedAt);
}

class SecretUnlocksCompanion extends UpdateCompanion<SecretUnlock> {
  final Value<String> key;
  final Value<DateTime> unlockedAt;
  final Value<int> rowid;
  const SecretUnlocksCompanion({
    this.key = const Value.absent(),
    this.unlockedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SecretUnlocksCompanion.insert({
    required String key,
    required DateTime unlockedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       unlockedAt = Value(unlockedAt);
  static Insertable<SecretUnlock> custom({
    Expression<String>? key,
    Expression<DateTime>? unlockedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (unlockedAt != null) 'unlocked_at': unlockedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SecretUnlocksCompanion copyWith({
    Value<String>? key,
    Value<DateTime>? unlockedAt,
    Value<int>? rowid,
  }) {
    return SecretUnlocksCompanion(
      key: key ?? this.key,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (unlockedAt.present) {
      map['unlocked_at'] = Variable<DateTime>(unlockedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SecretUnlocksCompanion(')
          ..write('key: $key, ')
          ..write('unlockedAt: $unlockedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserPremiumTable extends UserPremium
    with TableInfo<$UserPremiumTable, UserPremiumData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserPremiumTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'default\'',
    defaultValue: const CustomExpression('\'default\''),
  );
  static const VerificationMeta _tierMeta = const VerificationMeta('tier');
  @override
  late final GeneratedColumn<String> tier = GeneratedColumn<String>(
    'tier',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT \'free\' CHECK(tier IN (\'free\', \'premium\', \'lifetime\'))',
    defaultValue: const CustomExpression('\'free\''),
  );
  static const VerificationMeta _premiumUntilMeta = const VerificationMeta(
    'premiumUntil',
  );
  @override
  late final GeneratedColumn<int> premiumUntil = GeneratedColumn<int>(
    'premium_until',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dailyPlayLimitMeta = const VerificationMeta(
    'dailyPlayLimit',
  );
  @override
  late final GeneratedColumn<int> dailyPlayLimit = GeneratedColumn<int>(
    'daily_play_limit',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tier,
    premiumUntil,
    dailyPlayLimit,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_premium';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserPremiumData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('tier')) {
      context.handle(
        _tierMeta,
        tier.isAcceptableOrUnknown(data['tier']!, _tierMeta),
      );
    }
    if (data.containsKey('premium_until')) {
      context.handle(
        _premiumUntilMeta,
        premiumUntil.isAcceptableOrUnknown(
          data['premium_until']!,
          _premiumUntilMeta,
        ),
      );
    }
    if (data.containsKey('daily_play_limit')) {
      context.handle(
        _dailyPlayLimitMeta,
        dailyPlayLimit.isAcceptableOrUnknown(
          data['daily_play_limit']!,
          _dailyPlayLimitMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserPremiumData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserPremiumData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      tier:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}tier'],
          )!,
      premiumUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}premium_until'],
      ),
      dailyPlayLimit: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}daily_play_limit'],
      ),
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $UserPremiumTable createAlias(String alias) {
    return $UserPremiumTable(attachedDatabase, alias);
  }
}

class UserPremiumData extends DataClass implements Insertable<UserPremiumData> {
  final String id;
  final String tier;
  final int? premiumUntil;
  final int? dailyPlayLimit;
  final DateTime createdAt;
  final DateTime updatedAt;
  const UserPremiumData({
    required this.id,
    required this.tier,
    this.premiumUntil,
    this.dailyPlayLimit,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tier'] = Variable<String>(tier);
    if (!nullToAbsent || premiumUntil != null) {
      map['premium_until'] = Variable<int>(premiumUntil);
    }
    if (!nullToAbsent || dailyPlayLimit != null) {
      map['daily_play_limit'] = Variable<int>(dailyPlayLimit);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UserPremiumCompanion toCompanion(bool nullToAbsent) {
    return UserPremiumCompanion(
      id: Value(id),
      tier: Value(tier),
      premiumUntil:
          premiumUntil == null && nullToAbsent
              ? const Value.absent()
              : Value(premiumUntil),
      dailyPlayLimit:
          dailyPlayLimit == null && nullToAbsent
              ? const Value.absent()
              : Value(dailyPlayLimit),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserPremiumData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserPremiumData(
      id: serializer.fromJson<String>(json['id']),
      tier: serializer.fromJson<String>(json['tier']),
      premiumUntil: serializer.fromJson<int?>(json['premiumUntil']),
      dailyPlayLimit: serializer.fromJson<int?>(json['dailyPlayLimit']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tier': serializer.toJson<String>(tier),
      'premiumUntil': serializer.toJson<int?>(premiumUntil),
      'dailyPlayLimit': serializer.toJson<int?>(dailyPlayLimit),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserPremiumData copyWith({
    String? id,
    String? tier,
    Value<int?> premiumUntil = const Value.absent(),
    Value<int?> dailyPlayLimit = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => UserPremiumData(
    id: id ?? this.id,
    tier: tier ?? this.tier,
    premiumUntil: premiumUntil.present ? premiumUntil.value : this.premiumUntil,
    dailyPlayLimit:
        dailyPlayLimit.present ? dailyPlayLimit.value : this.dailyPlayLimit,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UserPremiumData copyWithCompanion(UserPremiumCompanion data) {
    return UserPremiumData(
      id: data.id.present ? data.id.value : this.id,
      tier: data.tier.present ? data.tier.value : this.tier,
      premiumUntil:
          data.premiumUntil.present
              ? data.premiumUntil.value
              : this.premiumUntil,
      dailyPlayLimit:
          data.dailyPlayLimit.present
              ? data.dailyPlayLimit.value
              : this.dailyPlayLimit,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserPremiumData(')
          ..write('id: $id, ')
          ..write('tier: $tier, ')
          ..write('premiumUntil: $premiumUntil, ')
          ..write('dailyPlayLimit: $dailyPlayLimit, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, tier, premiumUntil, dailyPlayLimit, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserPremiumData &&
          other.id == this.id &&
          other.tier == this.tier &&
          other.premiumUntil == this.premiumUntil &&
          other.dailyPlayLimit == this.dailyPlayLimit &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class UserPremiumCompanion extends UpdateCompanion<UserPremiumData> {
  final Value<String> id;
  final Value<String> tier;
  final Value<int?> premiumUntil;
  final Value<int?> dailyPlayLimit;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const UserPremiumCompanion({
    this.id = const Value.absent(),
    this.tier = const Value.absent(),
    this.premiumUntil = const Value.absent(),
    this.dailyPlayLimit = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserPremiumCompanion.insert({
    this.id = const Value.absent(),
    this.tier = const Value.absent(),
    this.premiumUntil = const Value.absent(),
    this.dailyPlayLimit = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<UserPremiumData> custom({
    Expression<String>? id,
    Expression<String>? tier,
    Expression<int>? premiumUntil,
    Expression<int>? dailyPlayLimit,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tier != null) 'tier': tier,
      if (premiumUntil != null) 'premium_until': premiumUntil,
      if (dailyPlayLimit != null) 'daily_play_limit': dailyPlayLimit,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserPremiumCompanion copyWith({
    Value<String>? id,
    Value<String>? tier,
    Value<int?>? premiumUntil,
    Value<int?>? dailyPlayLimit,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return UserPremiumCompanion(
      id: id ?? this.id,
      tier: tier ?? this.tier,
      premiumUntil: premiumUntil ?? this.premiumUntil,
      dailyPlayLimit: dailyPlayLimit ?? this.dailyPlayLimit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tier.present) {
      map['tier'] = Variable<String>(tier.value);
    }
    if (premiumUntil.present) {
      map['premium_until'] = Variable<int>(premiumUntil.value);
    }
    if (dailyPlayLimit.present) {
      map['daily_play_limit'] = Variable<int>(dailyPlayLimit.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserPremiumCompanion(')
          ..write('id: $id, ')
          ..write('tier: $tier, ')
          ..write('premiumUntil: $premiumUntil, ')
          ..write('dailyPlayLimit: $dailyPlayLimit, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QuotaUsageTable extends QuotaUsage
    with TableInfo<$QuotaUsageTable, QuotaUsageData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuotaUsageTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMinutesMeta = const VerificationMeta(
    'durationMinutes',
  );
  @override
  late final GeneratedColumn<double> durationMinutes = GeneratedColumn<double>(
    'duration_minutes',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'reserved\'',
    defaultValue: const CustomExpression('\'reserved\''),
  );
  static const VerificationMeta _downloadedAtMeta = const VerificationMeta(
    'downloadedAt',
  );
  @override
  late final GeneratedColumn<DateTime> downloadedAt = GeneratedColumn<DateTime>(
    'downloaded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    trackId,
    durationMinutes,
    status,
    downloadedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'quota_usage';
  @override
  VerificationContext validateIntegrity(
    Insertable<QuotaUsageData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('duration_minutes')) {
      context.handle(
        _durationMinutesMeta,
        durationMinutes.isAcceptableOrUnknown(
          data['duration_minutes']!,
          _durationMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durationMinutesMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('downloaded_at')) {
      context.handle(
        _downloadedAtMeta,
        downloadedAt.isAcceptableOrUnknown(
          data['downloaded_at']!,
          _downloadedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_downloadedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, trackId, downloadedAt};
  @override
  QuotaUsageData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuotaUsageData(
      userId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}user_id'],
          )!,
      trackId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}track_id'],
          )!,
      durationMinutes:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}duration_minutes'],
          )!,
      status:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}status'],
          )!,
      downloadedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}downloaded_at'],
          )!,
    );
  }

  @override
  $QuotaUsageTable createAlias(String alias) {
    return $QuotaUsageTable(attachedDatabase, alias);
  }
}

class QuotaUsageData extends DataClass implements Insertable<QuotaUsageData> {
  final String userId;
  final String trackId;
  final double durationMinutes;
  final String status;
  final DateTime downloadedAt;
  const QuotaUsageData({
    required this.userId,
    required this.trackId,
    required this.durationMinutes,
    required this.status,
    required this.downloadedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['track_id'] = Variable<String>(trackId);
    map['duration_minutes'] = Variable<double>(durationMinutes);
    map['status'] = Variable<String>(status);
    map['downloaded_at'] = Variable<DateTime>(downloadedAt);
    return map;
  }

  QuotaUsageCompanion toCompanion(bool nullToAbsent) {
    return QuotaUsageCompanion(
      userId: Value(userId),
      trackId: Value(trackId),
      durationMinutes: Value(durationMinutes),
      status: Value(status),
      downloadedAt: Value(downloadedAt),
    );
  }

  factory QuotaUsageData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuotaUsageData(
      userId: serializer.fromJson<String>(json['userId']),
      trackId: serializer.fromJson<String>(json['trackId']),
      durationMinutes: serializer.fromJson<double>(json['durationMinutes']),
      status: serializer.fromJson<String>(json['status']),
      downloadedAt: serializer.fromJson<DateTime>(json['downloadedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'trackId': serializer.toJson<String>(trackId),
      'durationMinutes': serializer.toJson<double>(durationMinutes),
      'status': serializer.toJson<String>(status),
      'downloadedAt': serializer.toJson<DateTime>(downloadedAt),
    };
  }

  QuotaUsageData copyWith({
    String? userId,
    String? trackId,
    double? durationMinutes,
    String? status,
    DateTime? downloadedAt,
  }) => QuotaUsageData(
    userId: userId ?? this.userId,
    trackId: trackId ?? this.trackId,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    status: status ?? this.status,
    downloadedAt: downloadedAt ?? this.downloadedAt,
  );
  QuotaUsageData copyWithCompanion(QuotaUsageCompanion data) {
    return QuotaUsageData(
      userId: data.userId.present ? data.userId.value : this.userId,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      durationMinutes:
          data.durationMinutes.present
              ? data.durationMinutes.value
              : this.durationMinutes,
      status: data.status.present ? data.status.value : this.status,
      downloadedAt:
          data.downloadedAt.present
              ? data.downloadedAt.value
              : this.downloadedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuotaUsageData(')
          ..write('userId: $userId, ')
          ..write('trackId: $trackId, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('status: $status, ')
          ..write('downloadedAt: $downloadedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(userId, trackId, durationMinutes, status, downloadedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuotaUsageData &&
          other.userId == this.userId &&
          other.trackId == this.trackId &&
          other.durationMinutes == this.durationMinutes &&
          other.status == this.status &&
          other.downloadedAt == this.downloadedAt);
}

class QuotaUsageCompanion extends UpdateCompanion<QuotaUsageData> {
  final Value<String> userId;
  final Value<String> trackId;
  final Value<double> durationMinutes;
  final Value<String> status;
  final Value<DateTime> downloadedAt;
  final Value<int> rowid;
  const QuotaUsageCompanion({
    this.userId = const Value.absent(),
    this.trackId = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.status = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QuotaUsageCompanion.insert({
    required String userId,
    required String trackId,
    required double durationMinutes,
    this.status = const Value.absent(),
    required DateTime downloadedAt,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       trackId = Value(trackId),
       durationMinutes = Value(durationMinutes),
       downloadedAt = Value(downloadedAt);
  static Insertable<QuotaUsageData> custom({
    Expression<String>? userId,
    Expression<String>? trackId,
    Expression<double>? durationMinutes,
    Expression<String>? status,
    Expression<DateTime>? downloadedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (trackId != null) 'track_id': trackId,
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      if (status != null) 'status': status,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QuotaUsageCompanion copyWith({
    Value<String>? userId,
    Value<String>? trackId,
    Value<double>? durationMinutes,
    Value<String>? status,
    Value<DateTime>? downloadedAt,
    Value<int>? rowid,
  }) {
    return QuotaUsageCompanion(
      userId: userId ?? this.userId,
      trackId: trackId ?? this.trackId,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      status: status ?? this.status,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (durationMinutes.present) {
      map['duration_minutes'] = Variable<double>(durationMinutes.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (downloadedAt.present) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuotaUsageCompanion(')
          ..write('userId: $userId, ')
          ..write('trackId: $trackId, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('status: $status, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserDailyPlaysTable extends UserDailyPlays
    with TableInfo<$UserDailyPlaysTable, UserDailyPlay> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserDailyPlaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playCountMeta = const VerificationMeta(
    'playCount',
  );
  @override
  late final GeneratedColumn<int> playCount = GeneratedColumn<int>(
    'play_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, date, playCount];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_daily_plays';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserDailyPlay> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('play_count')) {
      context.handle(
        _playCountMeta,
        playCount.isAcceptableOrUnknown(data['play_count']!, _playCountMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserDailyPlay map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserDailyPlay(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      date:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}date'],
          )!,
      playCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}play_count'],
      ),
    );
  }

  @override
  $UserDailyPlaysTable createAlias(String alias) {
    return $UserDailyPlaysTable(attachedDatabase, alias);
  }
}

class UserDailyPlay extends DataClass implements Insertable<UserDailyPlay> {
  final int id;
  final String date;
  final int? playCount;
  const UserDailyPlay({required this.id, required this.date, this.playCount});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<String>(date);
    if (!nullToAbsent || playCount != null) {
      map['play_count'] = Variable<int>(playCount);
    }
    return map;
  }

  UserDailyPlaysCompanion toCompanion(bool nullToAbsent) {
    return UserDailyPlaysCompanion(
      id: Value(id),
      date: Value(date),
      playCount:
          playCount == null && nullToAbsent
              ? const Value.absent()
              : Value(playCount),
    );
  }

  factory UserDailyPlay.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserDailyPlay(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<String>(json['date']),
      playCount: serializer.fromJson<int?>(json['playCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<String>(date),
      'playCount': serializer.toJson<int?>(playCount),
    };
  }

  UserDailyPlay copyWith({
    int? id,
    String? date,
    Value<int?> playCount = const Value.absent(),
  }) => UserDailyPlay(
    id: id ?? this.id,
    date: date ?? this.date,
    playCount: playCount.present ? playCount.value : this.playCount,
  );
  UserDailyPlay copyWithCompanion(UserDailyPlaysCompanion data) {
    return UserDailyPlay(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      playCount: data.playCount.present ? data.playCount.value : this.playCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserDailyPlay(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('playCount: $playCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, date, playCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserDailyPlay &&
          other.id == this.id &&
          other.date == this.date &&
          other.playCount == this.playCount);
}

class UserDailyPlaysCompanion extends UpdateCompanion<UserDailyPlay> {
  final Value<int> id;
  final Value<String> date;
  final Value<int?> playCount;
  const UserDailyPlaysCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.playCount = const Value.absent(),
  });
  UserDailyPlaysCompanion.insert({
    this.id = const Value.absent(),
    required String date,
    this.playCount = const Value.absent(),
  }) : date = Value(date);
  static Insertable<UserDailyPlay> custom({
    Expression<int>? id,
    Expression<String>? date,
    Expression<int>? playCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (playCount != null) 'play_count': playCount,
    });
  }

  UserDailyPlaysCompanion copyWith({
    Value<int>? id,
    Value<String>? date,
    Value<int?>? playCount,
  }) {
    return UserDailyPlaysCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      playCount: playCount ?? this.playCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (playCount.present) {
      map['play_count'] = Variable<int>(playCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserDailyPlaysCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('playCount: $playCount')
          ..write(')'))
        .toString();
  }
}

class $IsrcCacheTable extends IsrcCache
    with TableInfo<$IsrcCacheTable, IsrcCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IsrcCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _isrcMeta = const VerificationMeta('isrc');
  @override
  late final GeneratedColumn<String> isrc = GeneratedColumn<String>(
    'isrc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _albumArtistMeta = const VerificationMeta(
    'albumArtist',
  );
  @override
  late final GeneratedColumn<String> albumArtist = GeneratedColumn<String>(
    'album_artist',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<int> fetchedAt = GeneratedColumn<int>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [isrc, genre, albumArtist, fetchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'isrc_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<IsrcCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('isrc')) {
      context.handle(
        _isrcMeta,
        isrc.isAcceptableOrUnknown(data['isrc']!, _isrcMeta),
      );
    } else if (isInserting) {
      context.missing(_isrcMeta);
    }
    if (data.containsKey('genre')) {
      context.handle(
        _genreMeta,
        genre.isAcceptableOrUnknown(data['genre']!, _genreMeta),
      );
    }
    if (data.containsKey('album_artist')) {
      context.handle(
        _albumArtistMeta,
        albumArtist.isAcceptableOrUnknown(
          data['album_artist']!,
          _albumArtistMeta,
        ),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {isrc};
  @override
  IsrcCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IsrcCacheData(
      isrc:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}isrc'],
          )!,
      genre:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}genre'],
          )!,
      albumArtist:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}album_artist'],
          )!,
      fetchedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}fetched_at'],
          )!,
    );
  }

  @override
  $IsrcCacheTable createAlias(String alias) {
    return $IsrcCacheTable(attachedDatabase, alias);
  }
}

class IsrcCacheData extends DataClass implements Insertable<IsrcCacheData> {
  final String isrc;
  final String genre;
  final String albumArtist;
  final int fetchedAt;
  const IsrcCacheData({
    required this.isrc,
    required this.genre,
    required this.albumArtist,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['isrc'] = Variable<String>(isrc);
    map['genre'] = Variable<String>(genre);
    map['album_artist'] = Variable<String>(albumArtist);
    map['fetched_at'] = Variable<int>(fetchedAt);
    return map;
  }

  IsrcCacheCompanion toCompanion(bool nullToAbsent) {
    return IsrcCacheCompanion(
      isrc: Value(isrc),
      genre: Value(genre),
      albumArtist: Value(albumArtist),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory IsrcCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IsrcCacheData(
      isrc: serializer.fromJson<String>(json['isrc']),
      genre: serializer.fromJson<String>(json['genre']),
      albumArtist: serializer.fromJson<String>(json['albumArtist']),
      fetchedAt: serializer.fromJson<int>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'isrc': serializer.toJson<String>(isrc),
      'genre': serializer.toJson<String>(genre),
      'albumArtist': serializer.toJson<String>(albumArtist),
      'fetchedAt': serializer.toJson<int>(fetchedAt),
    };
  }

  IsrcCacheData copyWith({
    String? isrc,
    String? genre,
    String? albumArtist,
    int? fetchedAt,
  }) => IsrcCacheData(
    isrc: isrc ?? this.isrc,
    genre: genre ?? this.genre,
    albumArtist: albumArtist ?? this.albumArtist,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  IsrcCacheData copyWithCompanion(IsrcCacheCompanion data) {
    return IsrcCacheData(
      isrc: data.isrc.present ? data.isrc.value : this.isrc,
      genre: data.genre.present ? data.genre.value : this.genre,
      albumArtist:
          data.albumArtist.present ? data.albumArtist.value : this.albumArtist,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IsrcCacheData(')
          ..write('isrc: $isrc, ')
          ..write('genre: $genre, ')
          ..write('albumArtist: $albumArtist, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(isrc, genre, albumArtist, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IsrcCacheData &&
          other.isrc == this.isrc &&
          other.genre == this.genre &&
          other.albumArtist == this.albumArtist &&
          other.fetchedAt == this.fetchedAt);
}

class IsrcCacheCompanion extends UpdateCompanion<IsrcCacheData> {
  final Value<String> isrc;
  final Value<String> genre;
  final Value<String> albumArtist;
  final Value<int> fetchedAt;
  final Value<int> rowid;
  const IsrcCacheCompanion({
    this.isrc = const Value.absent(),
    this.genre = const Value.absent(),
    this.albumArtist = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IsrcCacheCompanion.insert({
    required String isrc,
    this.genre = const Value.absent(),
    this.albumArtist = const Value.absent(),
    required int fetchedAt,
    this.rowid = const Value.absent(),
  }) : isrc = Value(isrc),
       fetchedAt = Value(fetchedAt);
  static Insertable<IsrcCacheData> custom({
    Expression<String>? isrc,
    Expression<String>? genre,
    Expression<String>? albumArtist,
    Expression<int>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (isrc != null) 'isrc': isrc,
      if (genre != null) 'genre': genre,
      if (albumArtist != null) 'album_artist': albumArtist,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IsrcCacheCompanion copyWith({
    Value<String>? isrc,
    Value<String>? genre,
    Value<String>? albumArtist,
    Value<int>? fetchedAt,
    Value<int>? rowid,
  }) {
    return IsrcCacheCompanion(
      isrc: isrc ?? this.isrc,
      genre: genre ?? this.genre,
      albumArtist: albumArtist ?? this.albumArtist,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (isrc.present) {
      map['isrc'] = Variable<String>(isrc.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (albumArtist.present) {
      map['album_artist'] = Variable<String>(albumArtist.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<int>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IsrcCacheCompanion(')
          ..write('isrc: $isrc, ')
          ..write('genre: $genre, ')
          ..write('albumArtist: $albumArtist, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VideoUrlCacheTable extends VideoUrlCache
    with TableInfo<$VideoUrlCacheTable, VideoUrlCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VideoUrlCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackNameMeta = const VerificationMeta(
    'trackName',
  );
  @override
  late final GeneratedColumn<String> trackName = GeneratedColumn<String>(
    'track_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistNameMeta = const VerificationMeta(
    'artistName',
  );
  @override
  late final GeneratedColumn<String> artistName = GeneratedColumn<String>(
    'artist_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<int> cachedAt = GeneratedColumn<int>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    trackName,
    artistName,
    url,
    source,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'video_url_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<VideoUrlCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('track_name')) {
      context.handle(
        _trackNameMeta,
        trackName.isAcceptableOrUnknown(data['track_name']!, _trackNameMeta),
      );
    } else if (isInserting) {
      context.missing(_trackNameMeta);
    }
    if (data.containsKey('artist_name')) {
      context.handle(
        _artistNameMeta,
        artistName.isAcceptableOrUnknown(data['artist_name']!, _artistNameMeta),
      );
    } else if (isInserting) {
      context.missing(_artistNameMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VideoUrlCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VideoUrlCacheData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      trackName:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}track_name'],
          )!,
      artistName:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}artist_name'],
          )!,
      url:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}url'],
          )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      ),
      cachedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}cached_at'],
          )!,
    );
  }

  @override
  $VideoUrlCacheTable createAlias(String alias) {
    return $VideoUrlCacheTable(attachedDatabase, alias);
  }
}

class VideoUrlCacheData extends DataClass
    implements Insertable<VideoUrlCacheData> {
  final String id;
  final String trackName;
  final String artistName;
  final String url;
  final String? source;
  final int cachedAt;
  const VideoUrlCacheData({
    required this.id,
    required this.trackName,
    required this.artistName,
    required this.url,
    this.source,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['track_name'] = Variable<String>(trackName);
    map['artist_name'] = Variable<String>(artistName);
    map['url'] = Variable<String>(url);
    if (!nullToAbsent || source != null) {
      map['source'] = Variable<String>(source);
    }
    map['cached_at'] = Variable<int>(cachedAt);
    return map;
  }

  VideoUrlCacheCompanion toCompanion(bool nullToAbsent) {
    return VideoUrlCacheCompanion(
      id: Value(id),
      trackName: Value(trackName),
      artistName: Value(artistName),
      url: Value(url),
      source:
          source == null && nullToAbsent ? const Value.absent() : Value(source),
      cachedAt: Value(cachedAt),
    );
  }

  factory VideoUrlCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VideoUrlCacheData(
      id: serializer.fromJson<String>(json['id']),
      trackName: serializer.fromJson<String>(json['trackName']),
      artistName: serializer.fromJson<String>(json['artistName']),
      url: serializer.fromJson<String>(json['url']),
      source: serializer.fromJson<String?>(json['source']),
      cachedAt: serializer.fromJson<int>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'trackName': serializer.toJson<String>(trackName),
      'artistName': serializer.toJson<String>(artistName),
      'url': serializer.toJson<String>(url),
      'source': serializer.toJson<String?>(source),
      'cachedAt': serializer.toJson<int>(cachedAt),
    };
  }

  VideoUrlCacheData copyWith({
    String? id,
    String? trackName,
    String? artistName,
    String? url,
    Value<String?> source = const Value.absent(),
    int? cachedAt,
  }) => VideoUrlCacheData(
    id: id ?? this.id,
    trackName: trackName ?? this.trackName,
    artistName: artistName ?? this.artistName,
    url: url ?? this.url,
    source: source.present ? source.value : this.source,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  VideoUrlCacheData copyWithCompanion(VideoUrlCacheCompanion data) {
    return VideoUrlCacheData(
      id: data.id.present ? data.id.value : this.id,
      trackName: data.trackName.present ? data.trackName.value : this.trackName,
      artistName:
          data.artistName.present ? data.artistName.value : this.artistName,
      url: data.url.present ? data.url.value : this.url,
      source: data.source.present ? data.source.value : this.source,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VideoUrlCacheData(')
          ..write('id: $id, ')
          ..write('trackName: $trackName, ')
          ..write('artistName: $artistName, ')
          ..write('url: $url, ')
          ..write('source: $source, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, trackName, artistName, url, source, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VideoUrlCacheData &&
          other.id == this.id &&
          other.trackName == this.trackName &&
          other.artistName == this.artistName &&
          other.url == this.url &&
          other.source == this.source &&
          other.cachedAt == this.cachedAt);
}

class VideoUrlCacheCompanion extends UpdateCompanion<VideoUrlCacheData> {
  final Value<String> id;
  final Value<String> trackName;
  final Value<String> artistName;
  final Value<String> url;
  final Value<String?> source;
  final Value<int> cachedAt;
  final Value<int> rowid;
  const VideoUrlCacheCompanion({
    this.id = const Value.absent(),
    this.trackName = const Value.absent(),
    this.artistName = const Value.absent(),
    this.url = const Value.absent(),
    this.source = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VideoUrlCacheCompanion.insert({
    required String id,
    required String trackName,
    required String artistName,
    required String url,
    this.source = const Value.absent(),
    required int cachedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       trackName = Value(trackName),
       artistName = Value(artistName),
       url = Value(url),
       cachedAt = Value(cachedAt);
  static Insertable<VideoUrlCacheData> custom({
    Expression<String>? id,
    Expression<String>? trackName,
    Expression<String>? artistName,
    Expression<String>? url,
    Expression<String>? source,
    Expression<int>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trackName != null) 'track_name': trackName,
      if (artistName != null) 'artist_name': artistName,
      if (url != null) 'url': url,
      if (source != null) 'source': source,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VideoUrlCacheCompanion copyWith({
    Value<String>? id,
    Value<String>? trackName,
    Value<String>? artistName,
    Value<String>? url,
    Value<String?>? source,
    Value<int>? cachedAt,
    Value<int>? rowid,
  }) {
    return VideoUrlCacheCompanion(
      id: id ?? this.id,
      trackName: trackName ?? this.trackName,
      artistName: artistName ?? this.artistName,
      url: url ?? this.url,
      source: source ?? this.source,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (trackName.present) {
      map['track_name'] = Variable<String>(trackName.value);
    }
    if (artistName.present) {
      map['artist_name'] = Variable<String>(artistName.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<int>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VideoUrlCacheCompanion(')
          ..write('id: $id, ')
          ..write('trackName: $trackName, ')
          ..write('artistName: $artistName, ')
          ..write('url: $url, ')
          ..write('source: $source, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JsonCacheTable extends JsonCache
    with TableInfo<$JsonCacheTable, JsonCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JsonCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<int> timestamp = GeneratedColumn<int>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, json, timestamp];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'json_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<JsonCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  JsonCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JsonCacheData(
      key:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}key'],
          )!,
      json:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}json'],
          )!,
      timestamp:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}timestamp'],
          )!,
    );
  }

  @override
  $JsonCacheTable createAlias(String alias) {
    return $JsonCacheTable(attachedDatabase, alias);
  }
}

class JsonCacheData extends DataClass implements Insertable<JsonCacheData> {
  final String key;
  final String json;
  final int timestamp;
  const JsonCacheData({
    required this.key,
    required this.json,
    required this.timestamp,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['json'] = Variable<String>(json);
    map['timestamp'] = Variable<int>(timestamp);
    return map;
  }

  JsonCacheCompanion toCompanion(bool nullToAbsent) {
    return JsonCacheCompanion(
      key: Value(key),
      json: Value(json),
      timestamp: Value(timestamp),
    );
  }

  factory JsonCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JsonCacheData(
      key: serializer.fromJson<String>(json['key']),
      json: serializer.fromJson<String>(json['json']),
      timestamp: serializer.fromJson<int>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'json': serializer.toJson<String>(json),
      'timestamp': serializer.toJson<int>(timestamp),
    };
  }

  JsonCacheData copyWith({String? key, String? json, int? timestamp}) =>
      JsonCacheData(
        key: key ?? this.key,
        json: json ?? this.json,
        timestamp: timestamp ?? this.timestamp,
      );
  JsonCacheData copyWithCompanion(JsonCacheCompanion data) {
    return JsonCacheData(
      key: data.key.present ? data.key.value : this.key,
      json: data.json.present ? data.json.value : this.json,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JsonCacheData(')
          ..write('key: $key, ')
          ..write('json: $json, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, json, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JsonCacheData &&
          other.key == this.key &&
          other.json == this.json &&
          other.timestamp == this.timestamp);
}

class JsonCacheCompanion extends UpdateCompanion<JsonCacheData> {
  final Value<String> key;
  final Value<String> json;
  final Value<int> timestamp;
  final Value<int> rowid;
  const JsonCacheCompanion({
    this.key = const Value.absent(),
    this.json = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JsonCacheCompanion.insert({
    required String key,
    required String json,
    required int timestamp,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       json = Value(json),
       timestamp = Value(timestamp);
  static Insertable<JsonCacheData> custom({
    Expression<String>? key,
    Expression<String>? json,
    Expression<int>? timestamp,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (json != null) 'json': json,
      if (timestamp != null) 'timestamp': timestamp,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JsonCacheCompanion copyWith({
    Value<String>? key,
    Value<String>? json,
    Value<int>? timestamp,
    Value<int>? rowid,
  }) {
    return JsonCacheCompanion(
      key: key ?? this.key,
      json: json ?? this.json,
      timestamp: timestamp ?? this.timestamp,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<int>(timestamp.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JsonCacheCompanion(')
          ..write('key: $key, ')
          ..write('json: $json, ')
          ..write('timestamp: $timestamp, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SimilarArtistsTable extends SimilarArtists
    with TableInfo<$SimilarArtistsTable, SimilarArtist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SimilarArtistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _artistIdMeta = const VerificationMeta(
    'artistId',
  );
  @override
  late final GeneratedColumn<String> artistId = GeneratedColumn<String>(
    'artist_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES artists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _similarArtistIdMeta = const VerificationMeta(
    'similarArtistId',
  );
  @override
  late final GeneratedColumn<String> similarArtistId = GeneratedColumn<String>(
    'similar_artist_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES artists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _similarityScoreMeta = const VerificationMeta(
    'similarityScore',
  );
  @override
  late final GeneratedColumn<double> similarityScore = GeneratedColumn<double>(
    'similarity_score',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    artistId,
    similarArtistId,
    similarityScore,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'similar_artists';
  @override
  VerificationContext validateIntegrity(
    Insertable<SimilarArtist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('artist_id')) {
      context.handle(
        _artistIdMeta,
        artistId.isAcceptableOrUnknown(data['artist_id']!, _artistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_artistIdMeta);
    }
    if (data.containsKey('similar_artist_id')) {
      context.handle(
        _similarArtistIdMeta,
        similarArtistId.isAcceptableOrUnknown(
          data['similar_artist_id']!,
          _similarArtistIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_similarArtistIdMeta);
    }
    if (data.containsKey('similarity_score')) {
      context.handle(
        _similarityScoreMeta,
        similarityScore.isAcceptableOrUnknown(
          data['similarity_score']!,
          _similarityScoreMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {artistId, similarArtistId};
  @override
  SimilarArtist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SimilarArtist(
      artistId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}artist_id'],
          )!,
      similarArtistId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}similar_artist_id'],
          )!,
      similarityScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}similarity_score'],
      ),
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
    );
  }

  @override
  $SimilarArtistsTable createAlias(String alias) {
    return $SimilarArtistsTable(attachedDatabase, alias);
  }
}

class SimilarArtist extends DataClass implements Insertable<SimilarArtist> {
  final String artistId;
  final String similarArtistId;
  final double? similarityScore;
  final DateTime createdAt;
  const SimilarArtist({
    required this.artistId,
    required this.similarArtistId,
    this.similarityScore,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['artist_id'] = Variable<String>(artistId);
    map['similar_artist_id'] = Variable<String>(similarArtistId);
    if (!nullToAbsent || similarityScore != null) {
      map['similarity_score'] = Variable<double>(similarityScore);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SimilarArtistsCompanion toCompanion(bool nullToAbsent) {
    return SimilarArtistsCompanion(
      artistId: Value(artistId),
      similarArtistId: Value(similarArtistId),
      similarityScore:
          similarityScore == null && nullToAbsent
              ? const Value.absent()
              : Value(similarityScore),
      createdAt: Value(createdAt),
    );
  }

  factory SimilarArtist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SimilarArtist(
      artistId: serializer.fromJson<String>(json['artistId']),
      similarArtistId: serializer.fromJson<String>(json['similarArtistId']),
      similarityScore: serializer.fromJson<double?>(json['similarityScore']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'artistId': serializer.toJson<String>(artistId),
      'similarArtistId': serializer.toJson<String>(similarArtistId),
      'similarityScore': serializer.toJson<double?>(similarityScore),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SimilarArtist copyWith({
    String? artistId,
    String? similarArtistId,
    Value<double?> similarityScore = const Value.absent(),
    DateTime? createdAt,
  }) => SimilarArtist(
    artistId: artistId ?? this.artistId,
    similarArtistId: similarArtistId ?? this.similarArtistId,
    similarityScore:
        similarityScore.present ? similarityScore.value : this.similarityScore,
    createdAt: createdAt ?? this.createdAt,
  );
  SimilarArtist copyWithCompanion(SimilarArtistsCompanion data) {
    return SimilarArtist(
      artistId: data.artistId.present ? data.artistId.value : this.artistId,
      similarArtistId:
          data.similarArtistId.present
              ? data.similarArtistId.value
              : this.similarArtistId,
      similarityScore:
          data.similarityScore.present
              ? data.similarityScore.value
              : this.similarityScore,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SimilarArtist(')
          ..write('artistId: $artistId, ')
          ..write('similarArtistId: $similarArtistId, ')
          ..write('similarityScore: $similarityScore, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(artistId, similarArtistId, similarityScore, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SimilarArtist &&
          other.artistId == this.artistId &&
          other.similarArtistId == this.similarArtistId &&
          other.similarityScore == this.similarityScore &&
          other.createdAt == this.createdAt);
}

class SimilarArtistsCompanion extends UpdateCompanion<SimilarArtist> {
  final Value<String> artistId;
  final Value<String> similarArtistId;
  final Value<double?> similarityScore;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SimilarArtistsCompanion({
    this.artistId = const Value.absent(),
    this.similarArtistId = const Value.absent(),
    this.similarityScore = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SimilarArtistsCompanion.insert({
    required String artistId,
    required String similarArtistId,
    this.similarityScore = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : artistId = Value(artistId),
       similarArtistId = Value(similarArtistId),
       createdAt = Value(createdAt);
  static Insertable<SimilarArtist> custom({
    Expression<String>? artistId,
    Expression<String>? similarArtistId,
    Expression<double>? similarityScore,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (artistId != null) 'artist_id': artistId,
      if (similarArtistId != null) 'similar_artist_id': similarArtistId,
      if (similarityScore != null) 'similarity_score': similarityScore,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SimilarArtistsCompanion copyWith({
    Value<String>? artistId,
    Value<String>? similarArtistId,
    Value<double?>? similarityScore,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return SimilarArtistsCompanion(
      artistId: artistId ?? this.artistId,
      similarArtistId: similarArtistId ?? this.similarArtistId,
      similarityScore: similarityScore ?? this.similarityScore,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (artistId.present) {
      map['artist_id'] = Variable<String>(artistId.value);
    }
    if (similarArtistId.present) {
      map['similar_artist_id'] = Variable<String>(similarArtistId.value);
    }
    if (similarityScore.present) {
      map['similarity_score'] = Variable<double>(similarityScore.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SimilarArtistsCompanion(')
          ..write('artistId: $artistId, ')
          ..write('similarArtistId: $similarArtistId, ')
          ..write('similarityScore: $similarityScore, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $ArtistsTable artists = $ArtistsTable(this);
  late final $AlbumsTable albums = $AlbumsTable(this);
  late final $TracksTable tracks = $TracksTable(this);
  late final $SourcesTable sources = $SourcesTable(this);
  late final $FilesTable files = $FilesTable(this);
  late final $LovedTracksTable lovedTracks = $LovedTracksTable(this);
  late final $FavoriteAlbumsTable favoriteAlbums = $FavoriteAlbumsTable(this);
  late final $FavoriteArtistsTable favoriteArtists = $FavoriteArtistsTable(
    this,
  );
  late final $FavoritePlaylistsTable favoritePlaylists =
      $FavoritePlaylistsTable(this);
  late final $CollectionsTable collections = $CollectionsTable(this);
  late final $CollectionItemsTable collectionItems = $CollectionItemsTable(
    this,
  );
  late final $PlayHistoryTable playHistory = $PlayHistoryTable(this);
  late final $PlayAggregatesTable playAggregates = $PlayAggregatesTable(this);
  late final $DownloadQueueTable downloadQueue = $DownloadQueueTable(this);
  late final $DownloadHistoryTable downloadHistory = $DownloadHistoryTable(
    this,
  );
  late final $DownloadBatchesTable downloadBatches = $DownloadBatchesTable(
    this,
  );
  late final $HiddenDownloadIdsTable hiddenDownloadIds =
      $HiddenDownloadIdsTable(this);
  late final $RecentSearchesTable recentSearches = $RecentSearchesTable(this);
  late final $RecentAccessTable recentAccess = $RecentAccessTable(this);
  late final $SecretCountersTable secretCounters = $SecretCountersTable(this);
  late final $SecretUnlocksTable secretUnlocks = $SecretUnlocksTable(this);
  late final $UserPremiumTable userPremium = $UserPremiumTable(this);
  late final $QuotaUsageTable quotaUsage = $QuotaUsageTable(this);
  late final $UserDailyPlaysTable userDailyPlays = $UserDailyPlaysTable(this);
  late final $IsrcCacheTable isrcCache = $IsrcCacheTable(this);
  late final $VideoUrlCacheTable videoUrlCache = $VideoUrlCacheTable(this);
  late final $JsonCacheTable jsonCache = $JsonCacheTable(this);
  late final $SimilarArtistsTable similarArtists = $SimilarArtistsTable(this);
  late final Index idxArtistsName = Index(
    'idx_artists_name',
    'CREATE INDEX idx_artists_name ON artists (normalized_name)',
  );
  late final Index idxAlbumsArtistId = Index(
    'idx_albums_artist_id',
    'CREATE INDEX idx_albums_artist_id ON albums (artist_id)',
  );
  late final Index idxTracksArtistId = Index(
    'idx_tracks_artist_id',
    'CREATE INDEX idx_tracks_artist_id ON tracks (artist_id)',
  );
  late final Index idxTracksAlbumId = Index(
    'idx_tracks_album_id',
    'CREATE INDEX idx_tracks_album_id ON tracks (album_id)',
  );
  late final Index idxTracksIsrc = Index(
    'idx_tracks_isrc',
    'CREATE INDEX idx_tracks_isrc ON tracks (isrc)',
  );
  late final Index idxSourcesTrackId = Index(
    'idx_sources_track_id',
    'CREATE INDEX idx_sources_track_id ON sources (track_id)',
  );
  late final Index idxLovedAddedAt = Index(
    'idx_loved_added_at',
    'CREATE INDEX idx_loved_added_at ON loved_tracks (added_at)',
  );
  late final Index idxFavAlbumAddedAt = Index(
    'idx_fav_album_added_at',
    'CREATE INDEX idx_fav_album_added_at ON favorite_albums (added_at)',
  );
  late final Index idxFavArtistAddedAt = Index(
    'idx_fav_artist_added_at',
    'CREATE INDEX idx_fav_artist_added_at ON favorite_artists (added_at)',
  );
  late final Index idxFavPlaylistAddedAt = Index(
    'idx_fav_playlist_added_at',
    'CREATE INDEX idx_fav_playlist_added_at ON favorite_playlists (added_at)',
  );
  late final Index idxCollectionsUpdatedAt = Index(
    'idx_collections_updated_at',
    'CREATE INDEX idx_collections_updated_at ON collections (updated_at)',
  );
  late final Index idxColItemsCollectionId = Index(
    'idx_col_items_collection_id',
    'CREATE INDEX idx_col_items_collection_id ON collection_items (collection_id)',
  );
  late final Index idxPlayHistoryPlayedAt = Index(
    'idx_play_history_played_at',
    'CREATE INDEX idx_play_history_played_at ON play_history (played_at)',
  );
  late final Index idxPlayAggTypeCount = Index(
    'idx_play_agg_type_count',
    'CREATE INDEX idx_play_agg_type_count ON play_aggregates (type, play_count)',
  );
  late final Index idxDlQueueStatus = Index(
    'idx_dl_queue_status',
    'CREATE INDEX idx_dl_queue_status ON download_queue (status)',
  );
  late final Index idxDlHistoryIsrc = Index(
    'idx_dl_history_isrc',
    'CREATE INDEX idx_dl_history_isrc ON download_history (isrc)',
  );
  late final Index idxDlHistoryDownloadedAt = Index(
    'idx_dl_history_downloaded_at',
    'CREATE INDEX idx_dl_history_downloaded_at ON download_history (downloaded_at)',
  );
  late final Index idxDlBatchesItem = Index(
    'idx_dl_batches_item',
    'CREATE INDEX idx_dl_batches_item ON download_batches (item_id, item_type)',
  );
  late final Index idxRecentSearchesDate = Index(
    'idx_recent_searches_date',
    'CREATE INDEX idx_recent_searches_date ON recent_searches (searched_at)',
  );
  late final Index idxRecentAccessDate = Index(
    'idx_recent_access_date',
    'CREATE INDEX idx_recent_access_date ON recent_access (accessed_at)',
  );
  late final Index idxQuotaStatus = Index(
    'idx_quota_status',
    'CREATE INDEX idx_quota_status ON quota_usage (status)',
  );
  late final Index idxQuotaUser = Index(
    'idx_quota_user',
    'CREATE INDEX idx_quota_user ON quota_usage (user_id)',
  );
  late final Index idxDailyPlaysDate = Index(
    'idx_daily_plays_date',
    'CREATE INDEX idx_daily_plays_date ON user_daily_plays (date)',
  );
  late final Index idxVideoCacheLookup = Index(
    'idx_video_cache_lookup',
    'CREATE INDEX idx_video_cache_lookup ON video_url_cache (track_name, artist_name)',
  );
  late final SettingsDao settingsDao = SettingsDao(this as AppDatabase);
  late final ContentDao contentDao = ContentDao(this as AppDatabase);
  late final FavoritesDao favoritesDao = FavoritesDao(this as AppDatabase);
  late final CollectionsDao collectionsDao = CollectionsDao(
    this as AppDatabase,
  );
  late final PlayHistoryDao playHistoryDao = PlayHistoryDao(
    this as AppDatabase,
  );
  late final DownloadDao downloadDao = DownloadDao(this as AppDatabase);
  late final RecentDao recentDao = RecentDao(this as AppDatabase);
  late final PremiumDao premiumDao = PremiumDao(this as AppDatabase);
  late final CacheDao cacheDao = CacheDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    appSettings,
    artists,
    albums,
    tracks,
    sources,
    files,
    lovedTracks,
    favoriteAlbums,
    favoriteArtists,
    favoritePlaylists,
    collections,
    collectionItems,
    playHistory,
    playAggregates,
    downloadQueue,
    downloadHistory,
    downloadBatches,
    hiddenDownloadIds,
    recentSearches,
    recentAccess,
    secretCounters,
    secretUnlocks,
    userPremium,
    quotaUsage,
    userDailyPlays,
    isrcCache,
    videoUrlCache,
    jsonCache,
    similarArtists,
    idxArtistsName,
    idxAlbumsArtistId,
    idxTracksArtistId,
    idxTracksAlbumId,
    idxTracksIsrc,
    idxSourcesTrackId,
    idxLovedAddedAt,
    idxFavAlbumAddedAt,
    idxFavArtistAddedAt,
    idxFavPlaylistAddedAt,
    idxCollectionsUpdatedAt,
    idxColItemsCollectionId,
    idxPlayHistoryPlayedAt,
    idxPlayAggTypeCount,
    idxDlQueueStatus,
    idxDlHistoryIsrc,
    idxDlHistoryDownloadedAt,
    idxDlBatchesItem,
    idxRecentSearchesDate,
    idxRecentAccessDate,
    idxQuotaStatus,
    idxQuotaUser,
    idxDailyPlaysDate,
    idxVideoCacheLookup,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'artists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('albums', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'artists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('tracks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'albums',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('tracks', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('sources', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('files', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sources',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('files', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'collections',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('collection_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('collection_items', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'artists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('similar_artists', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'artists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('similar_artists', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;
typedef $$ArtistsTableCreateCompanionBuilder =
    ArtistsCompanion Function({
      required String id,
      required String name,
      required String normalizedName,
      Value<String?> imageUrl,
      Value<String?> imagePath,
      Value<String?> provider,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ArtistsTableUpdateCompanionBuilder =
    ArtistsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> normalizedName,
      Value<String?> imageUrl,
      Value<String?> imagePath,
      Value<String?> provider,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$ArtistsTableReferences
    extends BaseReferences<_$AppDatabase, $ArtistsTable, Artist> {
  $$ArtistsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$AlbumsTable, List<Album>> _albumsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.albums,
    aliasName: 'artists__id__albums__artist_id',
  );

  $$AlbumsTableProcessedTableManager get albumsRefs {
    final manager = $$AlbumsTableTableManager(
      $_db,
      $_db.albums,
    ).filter((f) => f.artistId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_albumsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TracksTable, List<Track>> _tracksRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tracks,
    aliasName: 'artists__id__tracks__artist_id',
  );

  $$TracksTableProcessedTableManager get tracksRefs {
    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.artistId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_tracksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ArtistsTableFilterComposer
    extends Composer<_$AppDatabase, $ArtistsTable> {
  $$ArtistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> albumsRefs(
    Expression<bool> Function($$AlbumsTableFilterComposer f) f,
  ) {
    final $$AlbumsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.albums,
      getReferencedColumn: (t) => t.artistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlbumsTableFilterComposer(
            $db: $db,
            $table: $db.albums,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> tracksRefs(
    Expression<bool> Function($$TracksTableFilterComposer f) f,
  ) {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.artistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ArtistsTableOrderingComposer
    extends Composer<_$AppDatabase, $ArtistsTable> {
  $$ArtistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ArtistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ArtistsTable> {
  $$ArtistsTableAnnotationComposer({
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

  GeneratedColumn<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> albumsRefs<T extends Object>(
    Expression<T> Function($$AlbumsTableAnnotationComposer a) f,
  ) {
    final $$AlbumsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.albums,
      getReferencedColumn: (t) => t.artistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlbumsTableAnnotationComposer(
            $db: $db,
            $table: $db.albums,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> tracksRefs<T extends Object>(
    Expression<T> Function($$TracksTableAnnotationComposer a) f,
  ) {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.artistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ArtistsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ArtistsTable,
          Artist,
          $$ArtistsTableFilterComposer,
          $$ArtistsTableOrderingComposer,
          $$ArtistsTableAnnotationComposer,
          $$ArtistsTableCreateCompanionBuilder,
          $$ArtistsTableUpdateCompanionBuilder,
          (Artist, $$ArtistsTableReferences),
          Artist,
          PrefetchHooks Function({bool albumsRefs, bool tracksRefs})
        > {
  $$ArtistsTableTableManager(_$AppDatabase db, $ArtistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ArtistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$ArtistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$ArtistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> normalizedName = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<String?> provider = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArtistsCompanion(
                id: id,
                name: name,
                normalizedName: normalizedName,
                imageUrl: imageUrl,
                imagePath: imagePath,
                provider: provider,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String normalizedName,
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<String?> provider = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ArtistsCompanion.insert(
                id: id,
                name: name,
                normalizedName: normalizedName,
                imageUrl: imageUrl,
                imagePath: imagePath,
                provider: provider,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$ArtistsTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({albumsRefs = false, tracksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (albumsRefs) db.albums,
                if (tracksRefs) db.tracks,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (albumsRefs)
                    await $_getPrefetchedData<Artist, $ArtistsTable, Album>(
                      currentTable: table,
                      referencedTable: $$ArtistsTableReferences
                          ._albumsRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$ArtistsTableReferences(
                                db,
                                table,
                                p0,
                              ).albumsRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.artistId == item.id,
                          ),
                      typedResults: items,
                    ),
                  if (tracksRefs)
                    await $_getPrefetchedData<Artist, $ArtistsTable, Track>(
                      currentTable: table,
                      referencedTable: $$ArtistsTableReferences
                          ._tracksRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$ArtistsTableReferences(
                                db,
                                table,
                                p0,
                              ).tracksRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.artistId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ArtistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ArtistsTable,
      Artist,
      $$ArtistsTableFilterComposer,
      $$ArtistsTableOrderingComposer,
      $$ArtistsTableAnnotationComposer,
      $$ArtistsTableCreateCompanionBuilder,
      $$ArtistsTableUpdateCompanionBuilder,
      (Artist, $$ArtistsTableReferences),
      Artist,
      PrefetchHooks Function({bool albumsRefs, bool tracksRefs})
    >;
typedef $$AlbumsTableCreateCompanionBuilder =
    AlbumsCompanion Function({
      required String id,
      required String artistId,
      required String name,
      required String normalizedName,
      Value<String?> coverUrl,
      Value<String?> coverPath,
      Value<String?> releaseDate,
      Value<int?> totalTracks,
      Value<String?> albumType,
      Value<String?> provider,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$AlbumsTableUpdateCompanionBuilder =
    AlbumsCompanion Function({
      Value<String> id,
      Value<String> artistId,
      Value<String> name,
      Value<String> normalizedName,
      Value<String?> coverUrl,
      Value<String?> coverPath,
      Value<String?> releaseDate,
      Value<int?> totalTracks,
      Value<String?> albumType,
      Value<String?> provider,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$AlbumsTableReferences
    extends BaseReferences<_$AppDatabase, $AlbumsTable, Album> {
  $$AlbumsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ArtistsTable _artistIdTable(_$AppDatabase db) =>
      db.artists.createAlias('albums__artist_id__artists__id');

  $$ArtistsTableProcessedTableManager get artistId {
    final $_column = $_itemColumn<String>('artist_id')!;

    final manager = $$ArtistsTableTableManager(
      $_db,
      $_db.artists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_artistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TracksTable, List<Track>> _tracksRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tracks,
    aliasName: 'albums__id__tracks__album_id',
  );

  $$TracksTableProcessedTableManager get tracksRefs {
    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.albumId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_tracksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AlbumsTableFilterComposer
    extends Composer<_$AppDatabase, $AlbumsTable> {
  $$AlbumsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalTracks => $composableBuilder(
    column: $table.totalTracks,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumType => $composableBuilder(
    column: $table.albumType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ArtistsTableFilterComposer get artistId {
    final $$ArtistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.artistId,
      referencedTable: $db.artists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArtistsTableFilterComposer(
            $db: $db,
            $table: $db.artists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> tracksRefs(
    Expression<bool> Function($$TracksTableFilterComposer f) f,
  ) {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.albumId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AlbumsTableOrderingComposer
    extends Composer<_$AppDatabase, $AlbumsTable> {
  $$AlbumsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalTracks => $composableBuilder(
    column: $table.totalTracks,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumType => $composableBuilder(
    column: $table.albumType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ArtistsTableOrderingComposer get artistId {
    final $$ArtistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.artistId,
      referencedTable: $db.artists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArtistsTableOrderingComposer(
            $db: $db,
            $table: $db.artists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AlbumsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AlbumsTable> {
  $$AlbumsTableAnnotationComposer({
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

  GeneratedColumn<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<String> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalTracks => $composableBuilder(
    column: $table.totalTracks,
    builder: (column) => column,
  );

  GeneratedColumn<String> get albumType =>
      $composableBuilder(column: $table.albumType, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ArtistsTableAnnotationComposer get artistId {
    final $$ArtistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.artistId,
      referencedTable: $db.artists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArtistsTableAnnotationComposer(
            $db: $db,
            $table: $db.artists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> tracksRefs<T extends Object>(
    Expression<T> Function($$TracksTableAnnotationComposer a) f,
  ) {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.albumId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AlbumsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AlbumsTable,
          Album,
          $$AlbumsTableFilterComposer,
          $$AlbumsTableOrderingComposer,
          $$AlbumsTableAnnotationComposer,
          $$AlbumsTableCreateCompanionBuilder,
          $$AlbumsTableUpdateCompanionBuilder,
          (Album, $$AlbumsTableReferences),
          Album,
          PrefetchHooks Function({bool artistId, bool tracksRefs})
        > {
  $$AlbumsTableTableManager(_$AppDatabase db, $AlbumsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$AlbumsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$AlbumsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$AlbumsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> artistId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> normalizedName = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<String?> releaseDate = const Value.absent(),
                Value<int?> totalTracks = const Value.absent(),
                Value<String?> albumType = const Value.absent(),
                Value<String?> provider = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AlbumsCompanion(
                id: id,
                artistId: artistId,
                name: name,
                normalizedName: normalizedName,
                coverUrl: coverUrl,
                coverPath: coverPath,
                releaseDate: releaseDate,
                totalTracks: totalTracks,
                albumType: albumType,
                provider: provider,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String artistId,
                required String name,
                required String normalizedName,
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<String?> releaseDate = const Value.absent(),
                Value<int?> totalTracks = const Value.absent(),
                Value<String?> albumType = const Value.absent(),
                Value<String?> provider = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => AlbumsCompanion.insert(
                id: id,
                artistId: artistId,
                name: name,
                normalizedName: normalizedName,
                coverUrl: coverUrl,
                coverPath: coverPath,
                releaseDate: releaseDate,
                totalTracks: totalTracks,
                albumType: albumType,
                provider: provider,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$AlbumsTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({artistId = false, tracksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (tracksRefs) db.tracks],
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
                  dynamic
                >
              >(state) {
                if (artistId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.artistId,
                            referencedTable: $$AlbumsTableReferences
                                ._artistIdTable(db),
                            referencedColumn:
                                $$AlbumsTableReferences._artistIdTable(db).id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (tracksRefs)
                    await $_getPrefetchedData<Album, $AlbumsTable, Track>(
                      currentTable: table,
                      referencedTable: $$AlbumsTableReferences._tracksRefsTable(
                        db,
                      ),
                      managerFromTypedResult:
                          (p0) =>
                              $$AlbumsTableReferences(db, table, p0).tracksRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.albumId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$AlbumsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AlbumsTable,
      Album,
      $$AlbumsTableFilterComposer,
      $$AlbumsTableOrderingComposer,
      $$AlbumsTableAnnotationComposer,
      $$AlbumsTableCreateCompanionBuilder,
      $$AlbumsTableUpdateCompanionBuilder,
      (Album, $$AlbumsTableReferences),
      Album,
      PrefetchHooks Function({bool artistId, bool tracksRefs})
    >;
typedef $$TracksTableCreateCompanionBuilder =
    TracksCompanion Function({
      required String id,
      required String name,
      required String artistId,
      required String albumId,
      Value<String?> isrc,
      Value<int?> durationMs,
      Value<int?> trackNumber,
      Value<int?> totalTracks,
      Value<int?> discNumber,
      Value<int?> totalDiscs,
      Value<String?> releaseDate,
      Value<String?> genre,
      Value<String?> composer,
      Value<String?> label,
      Value<String?> copyright,
      Value<String?> coverUrl,
      Value<String?> coverPath,
      Value<String?> videoPath,
      Value<String?> lyricsPath,
      Value<String?> spotifyId,
      Value<String?> source,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$TracksTableUpdateCompanionBuilder =
    TracksCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> artistId,
      Value<String> albumId,
      Value<String?> isrc,
      Value<int?> durationMs,
      Value<int?> trackNumber,
      Value<int?> totalTracks,
      Value<int?> discNumber,
      Value<int?> totalDiscs,
      Value<String?> releaseDate,
      Value<String?> genre,
      Value<String?> composer,
      Value<String?> label,
      Value<String?> copyright,
      Value<String?> coverUrl,
      Value<String?> coverPath,
      Value<String?> videoPath,
      Value<String?> lyricsPath,
      Value<String?> spotifyId,
      Value<String?> source,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$TracksTableReferences
    extends BaseReferences<_$AppDatabase, $TracksTable, Track> {
  $$TracksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ArtistsTable _artistIdTable(_$AppDatabase db) =>
      db.artists.createAlias('tracks__artist_id__artists__id');

  $$ArtistsTableProcessedTableManager get artistId {
    final $_column = $_itemColumn<String>('artist_id')!;

    final manager = $$ArtistsTableTableManager(
      $_db,
      $_db.artists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_artistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AlbumsTable _albumIdTable(_$AppDatabase db) =>
      db.albums.createAlias('tracks__album_id__albums__id');

  $$AlbumsTableProcessedTableManager get albumId {
    final $_column = $_itemColumn<String>('album_id')!;

    final manager = $$AlbumsTableTableManager(
      $_db,
      $_db.albums,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_albumIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$SourcesTable, List<Source>> _sourcesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.sources,
    aliasName: 'tracks__id__sources__track_id',
  );

  $$SourcesTableProcessedTableManager get sourcesRefs {
    final manager = $$SourcesTableTableManager(
      $_db,
      $_db.sources,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_sourcesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FilesTable, List<File>> _filesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.files,
    aliasName: 'tracks__id__files__track_id',
  );

  $$FilesTableProcessedTableManager get filesRefs {
    final manager = $$FilesTableTableManager(
      $_db,
      $_db.files,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_filesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CollectionItemsTable, List<CollectionItem>>
  _collectionItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.collectionItems,
    aliasName: 'tracks__id__collection_items__track_id',
  );

  $$CollectionItemsTableProcessedTableManager get collectionItemsRefs {
    final manager = $$CollectionItemsTableTableManager(
      $_db,
      $_db.collectionItems,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _collectionItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TracksTableFilterComposer
    extends Composer<_$AppDatabase, $TracksTable> {
  $$TracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get isrc => $composableBuilder(
    column: $table.isrc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get trackNumber => $composableBuilder(
    column: $table.trackNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalTracks => $composableBuilder(
    column: $table.totalTracks,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get discNumber => $composableBuilder(
    column: $table.discNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalDiscs => $composableBuilder(
    column: $table.totalDiscs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get composer => $composableBuilder(
    column: $table.composer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get copyright => $composableBuilder(
    column: $table.copyright,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoPath => $composableBuilder(
    column: $table.videoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lyricsPath => $composableBuilder(
    column: $table.lyricsPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spotifyId => $composableBuilder(
    column: $table.spotifyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ArtistsTableFilterComposer get artistId {
    final $$ArtistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.artistId,
      referencedTable: $db.artists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArtistsTableFilterComposer(
            $db: $db,
            $table: $db.artists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AlbumsTableFilterComposer get albumId {
    final $$AlbumsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.albumId,
      referencedTable: $db.albums,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlbumsTableFilterComposer(
            $db: $db,
            $table: $db.albums,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> sourcesRefs(
    Expression<bool> Function($$SourcesTableFilterComposer f) f,
  ) {
    final $$SourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableFilterComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> filesRefs(
    Expression<bool> Function($$FilesTableFilterComposer f) f,
  ) {
    final $$FilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.files,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilesTableFilterComposer(
            $db: $db,
            $table: $db.files,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> collectionItemsRefs(
    Expression<bool> Function($$CollectionItemsTableFilterComposer f) f,
  ) {
    final $$CollectionItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.collectionItems,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionItemsTableFilterComposer(
            $db: $db,
            $table: $db.collectionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TracksTableOrderingComposer
    extends Composer<_$AppDatabase, $TracksTable> {
  $$TracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get isrc => $composableBuilder(
    column: $table.isrc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get trackNumber => $composableBuilder(
    column: $table.trackNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalTracks => $composableBuilder(
    column: $table.totalTracks,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get discNumber => $composableBuilder(
    column: $table.discNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalDiscs => $composableBuilder(
    column: $table.totalDiscs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get composer => $composableBuilder(
    column: $table.composer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get copyright => $composableBuilder(
    column: $table.copyright,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoPath => $composableBuilder(
    column: $table.videoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lyricsPath => $composableBuilder(
    column: $table.lyricsPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spotifyId => $composableBuilder(
    column: $table.spotifyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ArtistsTableOrderingComposer get artistId {
    final $$ArtistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.artistId,
      referencedTable: $db.artists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArtistsTableOrderingComposer(
            $db: $db,
            $table: $db.artists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AlbumsTableOrderingComposer get albumId {
    final $$AlbumsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.albumId,
      referencedTable: $db.albums,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlbumsTableOrderingComposer(
            $db: $db,
            $table: $db.albums,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TracksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TracksTable> {
  $$TracksTableAnnotationComposer({
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

  GeneratedColumn<String> get isrc =>
      $composableBuilder(column: $table.isrc, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get trackNumber => $composableBuilder(
    column: $table.trackNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalTracks => $composableBuilder(
    column: $table.totalTracks,
    builder: (column) => column,
  );

  GeneratedColumn<int> get discNumber => $composableBuilder(
    column: $table.discNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalDiscs => $composableBuilder(
    column: $table.totalDiscs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<String> get composer =>
      $composableBuilder(column: $table.composer, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get copyright =>
      $composableBuilder(column: $table.copyright, builder: (column) => column);

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<String> get videoPath =>
      $composableBuilder(column: $table.videoPath, builder: (column) => column);

  GeneratedColumn<String> get lyricsPath => $composableBuilder(
    column: $table.lyricsPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get spotifyId =>
      $composableBuilder(column: $table.spotifyId, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ArtistsTableAnnotationComposer get artistId {
    final $$ArtistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.artistId,
      referencedTable: $db.artists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArtistsTableAnnotationComposer(
            $db: $db,
            $table: $db.artists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AlbumsTableAnnotationComposer get albumId {
    final $$AlbumsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.albumId,
      referencedTable: $db.albums,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlbumsTableAnnotationComposer(
            $db: $db,
            $table: $db.albums,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> sourcesRefs<T extends Object>(
    Expression<T> Function($$SourcesTableAnnotationComposer a) f,
  ) {
    final $$SourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> filesRefs<T extends Object>(
    Expression<T> Function($$FilesTableAnnotationComposer a) f,
  ) {
    final $$FilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.files,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilesTableAnnotationComposer(
            $db: $db,
            $table: $db.files,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> collectionItemsRefs<T extends Object>(
    Expression<T> Function($$CollectionItemsTableAnnotationComposer a) f,
  ) {
    final $$CollectionItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.collectionItems,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.collectionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TracksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TracksTable,
          Track,
          $$TracksTableFilterComposer,
          $$TracksTableOrderingComposer,
          $$TracksTableAnnotationComposer,
          $$TracksTableCreateCompanionBuilder,
          $$TracksTableUpdateCompanionBuilder,
          (Track, $$TracksTableReferences),
          Track,
          PrefetchHooks Function({
            bool artistId,
            bool albumId,
            bool sourcesRefs,
            bool filesRefs,
            bool collectionItemsRefs,
          })
        > {
  $$TracksTableTableManager(_$AppDatabase db, $TracksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$TracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$TracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$TracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> artistId = const Value.absent(),
                Value<String> albumId = const Value.absent(),
                Value<String?> isrc = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<int?> trackNumber = const Value.absent(),
                Value<int?> totalTracks = const Value.absent(),
                Value<int?> discNumber = const Value.absent(),
                Value<int?> totalDiscs = const Value.absent(),
                Value<String?> releaseDate = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<String?> composer = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<String?> copyright = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<String?> videoPath = const Value.absent(),
                Value<String?> lyricsPath = const Value.absent(),
                Value<String?> spotifyId = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TracksCompanion(
                id: id,
                name: name,
                artistId: artistId,
                albumId: albumId,
                isrc: isrc,
                durationMs: durationMs,
                trackNumber: trackNumber,
                totalTracks: totalTracks,
                discNumber: discNumber,
                totalDiscs: totalDiscs,
                releaseDate: releaseDate,
                genre: genre,
                composer: composer,
                label: label,
                copyright: copyright,
                coverUrl: coverUrl,
                coverPath: coverPath,
                videoPath: videoPath,
                lyricsPath: lyricsPath,
                spotifyId: spotifyId,
                source: source,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String artistId,
                required String albumId,
                Value<String?> isrc = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<int?> trackNumber = const Value.absent(),
                Value<int?> totalTracks = const Value.absent(),
                Value<int?> discNumber = const Value.absent(),
                Value<int?> totalDiscs = const Value.absent(),
                Value<String?> releaseDate = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<String?> composer = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<String?> copyright = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<String?> videoPath = const Value.absent(),
                Value<String?> lyricsPath = const Value.absent(),
                Value<String?> spotifyId = const Value.absent(),
                Value<String?> source = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => TracksCompanion.insert(
                id: id,
                name: name,
                artistId: artistId,
                albumId: albumId,
                isrc: isrc,
                durationMs: durationMs,
                trackNumber: trackNumber,
                totalTracks: totalTracks,
                discNumber: discNumber,
                totalDiscs: totalDiscs,
                releaseDate: releaseDate,
                genre: genre,
                composer: composer,
                label: label,
                copyright: copyright,
                coverUrl: coverUrl,
                coverPath: coverPath,
                videoPath: videoPath,
                lyricsPath: lyricsPath,
                spotifyId: spotifyId,
                source: source,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$TracksTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({
            artistId = false,
            albumId = false,
            sourcesRefs = false,
            filesRefs = false,
            collectionItemsRefs = false,
          }) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (sourcesRefs) db.sources,
                if (filesRefs) db.files,
                if (collectionItemsRefs) db.collectionItems,
              ],
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
                  dynamic
                >
              >(state) {
                if (artistId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.artistId,
                            referencedTable: $$TracksTableReferences
                                ._artistIdTable(db),
                            referencedColumn:
                                $$TracksTableReferences._artistIdTable(db).id,
                          )
                          as T;
                }
                if (albumId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.albumId,
                            referencedTable: $$TracksTableReferences
                                ._albumIdTable(db),
                            referencedColumn:
                                $$TracksTableReferences._albumIdTable(db).id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (sourcesRefs)
                    await $_getPrefetchedData<Track, $TracksTable, Source>(
                      currentTable: table,
                      referencedTable: $$TracksTableReferences
                          ._sourcesRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$TracksTableReferences(
                                db,
                                table,
                                p0,
                              ).sourcesRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.trackId == item.id,
                          ),
                      typedResults: items,
                    ),
                  if (filesRefs)
                    await $_getPrefetchedData<Track, $TracksTable, File>(
                      currentTable: table,
                      referencedTable: $$TracksTableReferences._filesRefsTable(
                        db,
                      ),
                      managerFromTypedResult:
                          (p0) =>
                              $$TracksTableReferences(db, table, p0).filesRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.trackId == item.id,
                          ),
                      typedResults: items,
                    ),
                  if (collectionItemsRefs)
                    await $_getPrefetchedData<
                      Track,
                      $TracksTable,
                      CollectionItem
                    >(
                      currentTable: table,
                      referencedTable: $$TracksTableReferences
                          ._collectionItemsRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$TracksTableReferences(
                                db,
                                table,
                                p0,
                              ).collectionItemsRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.trackId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TracksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TracksTable,
      Track,
      $$TracksTableFilterComposer,
      $$TracksTableOrderingComposer,
      $$TracksTableAnnotationComposer,
      $$TracksTableCreateCompanionBuilder,
      $$TracksTableUpdateCompanionBuilder,
      (Track, $$TracksTableReferences),
      Track,
      PrefetchHooks Function({
        bool artistId,
        bool albumId,
        bool sourcesRefs,
        bool filesRefs,
        bool collectionItemsRefs,
      })
    >;
typedef $$SourcesTableCreateCompanionBuilder =
    SourcesCompanion Function({
      required String id,
      required String trackId,
      required String provider,
      required String externalId,
      Value<String?> quality,
      Value<String?> audioQuality,
      Value<String?> coverUrl,
      Value<String?> metadataJson,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$SourcesTableUpdateCompanionBuilder =
    SourcesCompanion Function({
      Value<String> id,
      Value<String> trackId,
      Value<String> provider,
      Value<String> externalId,
      Value<String?> quality,
      Value<String?> audioQuality,
      Value<String?> coverUrl,
      Value<String?> metadataJson,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$SourcesTableReferences
    extends BaseReferences<_$AppDatabase, $SourcesTable, Source> {
  $$SourcesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TracksTable _trackIdTable(_$AppDatabase db) =>
      db.tracks.createAlias('sources__track_id__tracks__id');

  $$TracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<String>('track_id')!;

    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$FilesTable, List<File>> _filesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.files,
    aliasName: 'sources__id__files__source_id',
  );

  $$FilesTableProcessedTableManager get filesRefs {
    final manager = $$FilesTableTableManager(
      $_db,
      $_db.files,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_filesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SourcesTableFilterComposer
    extends Composer<_$AppDatabase, $SourcesTable> {
  $$SourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioQuality => $composableBuilder(
    column: $table.audioQuality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TracksTableFilterComposer get trackId {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> filesRefs(
    Expression<bool> Function($$FilesTableFilterComposer f) f,
  ) {
    final $$FilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.files,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilesTableFilterComposer(
            $db: $db,
            $table: $db.files,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SourcesTableOrderingComposer
    extends Composer<_$AppDatabase, $SourcesTable> {
  $$SourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioQuality => $composableBuilder(
    column: $table.audioQuality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TracksTableOrderingComposer get trackId {
    final $$TracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableOrderingComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SourcesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SourcesTable> {
  $$SourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get quality =>
      $composableBuilder(column: $table.quality, builder: (column) => column);

  GeneratedColumn<String> get audioQuality => $composableBuilder(
    column: $table.audioQuality,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$TracksTableAnnotationComposer get trackId {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> filesRefs<T extends Object>(
    Expression<T> Function($$FilesTableAnnotationComposer a) f,
  ) {
    final $$FilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.files,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FilesTableAnnotationComposer(
            $db: $db,
            $table: $db.files,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SourcesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SourcesTable,
          Source,
          $$SourcesTableFilterComposer,
          $$SourcesTableOrderingComposer,
          $$SourcesTableAnnotationComposer,
          $$SourcesTableCreateCompanionBuilder,
          $$SourcesTableUpdateCompanionBuilder,
          (Source, $$SourcesTableReferences),
          Source,
          PrefetchHooks Function({bool trackId, bool filesRefs})
        > {
  $$SourcesTableTableManager(_$AppDatabase db, $SourcesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$SourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$SourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$SourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> trackId = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String> externalId = const Value.absent(),
                Value<String?> quality = const Value.absent(),
                Value<String?> audioQuality = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> metadataJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SourcesCompanion(
                id: id,
                trackId: trackId,
                provider: provider,
                externalId: externalId,
                quality: quality,
                audioQuality: audioQuality,
                coverUrl: coverUrl,
                metadataJson: metadataJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String trackId,
                required String provider,
                required String externalId,
                Value<String?> quality = const Value.absent(),
                Value<String?> audioQuality = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> metadataJson = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => SourcesCompanion.insert(
                id: id,
                trackId: trackId,
                provider: provider,
                externalId: externalId,
                quality: quality,
                audioQuality: audioQuality,
                coverUrl: coverUrl,
                metadataJson: metadataJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$SourcesTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({trackId = false, filesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (filesRefs) db.files],
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
                  dynamic
                >
              >(state) {
                if (trackId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.trackId,
                            referencedTable: $$SourcesTableReferences
                                ._trackIdTable(db),
                            referencedColumn:
                                $$SourcesTableReferences._trackIdTable(db).id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (filesRefs)
                    await $_getPrefetchedData<Source, $SourcesTable, File>(
                      currentTable: table,
                      referencedTable: $$SourcesTableReferences._filesRefsTable(
                        db,
                      ),
                      managerFromTypedResult:
                          (p0) =>
                              $$SourcesTableReferences(db, table, p0).filesRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.sourceId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SourcesTable,
      Source,
      $$SourcesTableFilterComposer,
      $$SourcesTableOrderingComposer,
      $$SourcesTableAnnotationComposer,
      $$SourcesTableCreateCompanionBuilder,
      $$SourcesTableUpdateCompanionBuilder,
      (Source, $$SourcesTableReferences),
      Source,
      PrefetchHooks Function({bool trackId, bool filesRefs})
    >;
typedef $$FilesTableCreateCompanionBuilder =
    FilesCompanion Function({
      required String id,
      Value<String?> trackId,
      Value<String?> metadataId,
      Value<String?> sourceId,
      required String filePath,
      required String sourceType,
      Value<String?> format,
      Value<int?> bitrate,
      Value<int?> bitDepth,
      Value<int?> sampleRate,
      Value<DateTime?> downloadedAt,
      Value<DateTime?> scannedAt,
      Value<int?> fileModTime,
      Value<int> rowid,
    });
typedef $$FilesTableUpdateCompanionBuilder =
    FilesCompanion Function({
      Value<String> id,
      Value<String?> trackId,
      Value<String?> metadataId,
      Value<String?> sourceId,
      Value<String> filePath,
      Value<String> sourceType,
      Value<String?> format,
      Value<int?> bitrate,
      Value<int?> bitDepth,
      Value<int?> sampleRate,
      Value<DateTime?> downloadedAt,
      Value<DateTime?> scannedAt,
      Value<int?> fileModTime,
      Value<int> rowid,
    });

final class $$FilesTableReferences
    extends BaseReferences<_$AppDatabase, $FilesTable, File> {
  $$FilesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TracksTable _trackIdTable(_$AppDatabase db) =>
      db.tracks.createAlias('files__track_id__tracks__id');

  $$TracksTableProcessedTableManager? get trackId {
    final $_column = $_itemColumn<String>('track_id');
    if ($_column == null) return null;
    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SourcesTable _sourceIdTable(_$AppDatabase db) =>
      db.sources.createAlias('files__source_id__sources__id');

  $$SourcesTableProcessedTableManager? get sourceId {
    final $_column = $_itemColumn<String>('source_id');
    if ($_column == null) return null;
    final manager = $$SourcesTableTableManager(
      $_db,
      $_db.sources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FilesTableFilterComposer extends Composer<_$AppDatabase, $FilesTable> {
  $$FilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadataId => $composableBuilder(
    column: $table.metadataId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bitrate => $composableBuilder(
    column: $table.bitrate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bitDepth => $composableBuilder(
    column: $table.bitDepth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scannedAt => $composableBuilder(
    column: $table.scannedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileModTime => $composableBuilder(
    column: $table.fileModTime,
    builder: (column) => ColumnFilters(column),
  );

  $$TracksTableFilterComposer get trackId {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SourcesTableFilterComposer get sourceId {
    final $$SourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableFilterComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FilesTableOrderingComposer
    extends Composer<_$AppDatabase, $FilesTable> {
  $$FilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadataId => $composableBuilder(
    column: $table.metadataId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bitrate => $composableBuilder(
    column: $table.bitrate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bitDepth => $composableBuilder(
    column: $table.bitDepth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scannedAt => $composableBuilder(
    column: $table.scannedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileModTime => $composableBuilder(
    column: $table.fileModTime,
    builder: (column) => ColumnOrderings(column),
  );

  $$TracksTableOrderingComposer get trackId {
    final $$TracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableOrderingComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SourcesTableOrderingComposer get sourceId {
    final $$SourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableOrderingComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FilesTable> {
  $$FilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get metadataId => $composableBuilder(
    column: $table.metadataId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<int> get bitrate =>
      $composableBuilder(column: $table.bitrate, builder: (column) => column);

  GeneratedColumn<int> get bitDepth =>
      $composableBuilder(column: $table.bitDepth, builder: (column) => column);

  GeneratedColumn<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get scannedAt =>
      $composableBuilder(column: $table.scannedAt, builder: (column) => column);

  GeneratedColumn<int> get fileModTime => $composableBuilder(
    column: $table.fileModTime,
    builder: (column) => column,
  );

  $$TracksTableAnnotationComposer get trackId {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SourcesTableAnnotationComposer get sourceId {
    final $$SourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FilesTable,
          File,
          $$FilesTableFilterComposer,
          $$FilesTableOrderingComposer,
          $$FilesTableAnnotationComposer,
          $$FilesTableCreateCompanionBuilder,
          $$FilesTableUpdateCompanionBuilder,
          (File, $$FilesTableReferences),
          File,
          PrefetchHooks Function({bool trackId, bool sourceId})
        > {
  $$FilesTableTableManager(_$AppDatabase db, $FilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$FilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$FilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$FilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> trackId = const Value.absent(),
                Value<String?> metadataId = const Value.absent(),
                Value<String?> sourceId = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<String?> format = const Value.absent(),
                Value<int?> bitrate = const Value.absent(),
                Value<int?> bitDepth = const Value.absent(),
                Value<int?> sampleRate = const Value.absent(),
                Value<DateTime?> downloadedAt = const Value.absent(),
                Value<DateTime?> scannedAt = const Value.absent(),
                Value<int?> fileModTime = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FilesCompanion(
                id: id,
                trackId: trackId,
                metadataId: metadataId,
                sourceId: sourceId,
                filePath: filePath,
                sourceType: sourceType,
                format: format,
                bitrate: bitrate,
                bitDepth: bitDepth,
                sampleRate: sampleRate,
                downloadedAt: downloadedAt,
                scannedAt: scannedAt,
                fileModTime: fileModTime,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> trackId = const Value.absent(),
                Value<String?> metadataId = const Value.absent(),
                Value<String?> sourceId = const Value.absent(),
                required String filePath,
                required String sourceType,
                Value<String?> format = const Value.absent(),
                Value<int?> bitrate = const Value.absent(),
                Value<int?> bitDepth = const Value.absent(),
                Value<int?> sampleRate = const Value.absent(),
                Value<DateTime?> downloadedAt = const Value.absent(),
                Value<DateTime?> scannedAt = const Value.absent(),
                Value<int?> fileModTime = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FilesCompanion.insert(
                id: id,
                trackId: trackId,
                metadataId: metadataId,
                sourceId: sourceId,
                filePath: filePath,
                sourceType: sourceType,
                format: format,
                bitrate: bitrate,
                bitDepth: bitDepth,
                sampleRate: sampleRate,
                downloadedAt: downloadedAt,
                scannedAt: scannedAt,
                fileModTime: fileModTime,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$FilesTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({trackId = false, sourceId = false}) {
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
                  dynamic
                >
              >(state) {
                if (trackId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.trackId,
                            referencedTable: $$FilesTableReferences
                                ._trackIdTable(db),
                            referencedColumn:
                                $$FilesTableReferences._trackIdTable(db).id,
                          )
                          as T;
                }
                if (sourceId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.sourceId,
                            referencedTable: $$FilesTableReferences
                                ._sourceIdTable(db),
                            referencedColumn:
                                $$FilesTableReferences._sourceIdTable(db).id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FilesTable,
      File,
      $$FilesTableFilterComposer,
      $$FilesTableOrderingComposer,
      $$FilesTableAnnotationComposer,
      $$FilesTableCreateCompanionBuilder,
      $$FilesTableUpdateCompanionBuilder,
      (File, $$FilesTableReferences),
      File,
      PrefetchHooks Function({bool trackId, bool sourceId})
    >;
typedef $$LovedTracksTableCreateCompanionBuilder =
    LovedTracksCompanion Function({
      required String trackId,
      required String trackName,
      required String artistName,
      Value<String?> albumName,
      Value<String?> coverUrl,
      Value<String?> coverPath,
      Value<String?> isrc,
      Value<int?> durationMs,
      Value<String?> provider,
      required DateTime addedAt,
      Value<int> rowid,
    });
typedef $$LovedTracksTableUpdateCompanionBuilder =
    LovedTracksCompanion Function({
      Value<String> trackId,
      Value<String> trackName,
      Value<String> artistName,
      Value<String?> albumName,
      Value<String?> coverUrl,
      Value<String?> coverPath,
      Value<String?> isrc,
      Value<int?> durationMs,
      Value<String?> provider,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

class $$LovedTracksTableFilterComposer
    extends Composer<_$AppDatabase, $LovedTracksTable> {
  $$LovedTracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get trackId => $composableBuilder(
    column: $table.trackId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackName => $composableBuilder(
    column: $table.trackName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumName => $composableBuilder(
    column: $table.albumName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get isrc => $composableBuilder(
    column: $table.isrc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LovedTracksTableOrderingComposer
    extends Composer<_$AppDatabase, $LovedTracksTable> {
  $$LovedTracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get trackId => $composableBuilder(
    column: $table.trackId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackName => $composableBuilder(
    column: $table.trackName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumName => $composableBuilder(
    column: $table.albumName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get isrc => $composableBuilder(
    column: $table.isrc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LovedTracksTableAnnotationComposer
    extends Composer<_$AppDatabase, $LovedTracksTable> {
  $$LovedTracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get trackId =>
      $composableBuilder(column: $table.trackId, builder: (column) => column);

  GeneratedColumn<String> get trackName =>
      $composableBuilder(column: $table.trackName, builder: (column) => column);

  GeneratedColumn<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get albumName =>
      $composableBuilder(column: $table.albumName, builder: (column) => column);

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<String> get isrc =>
      $composableBuilder(column: $table.isrc, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$LovedTracksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LovedTracksTable,
          LovedTrack,
          $$LovedTracksTableFilterComposer,
          $$LovedTracksTableOrderingComposer,
          $$LovedTracksTableAnnotationComposer,
          $$LovedTracksTableCreateCompanionBuilder,
          $$LovedTracksTableUpdateCompanionBuilder,
          (
            LovedTrack,
            BaseReferences<_$AppDatabase, $LovedTracksTable, LovedTrack>,
          ),
          LovedTrack,
          PrefetchHooks Function()
        > {
  $$LovedTracksTableTableManager(_$AppDatabase db, $LovedTracksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$LovedTracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$LovedTracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$LovedTracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> trackId = const Value.absent(),
                Value<String> trackName = const Value.absent(),
                Value<String> artistName = const Value.absent(),
                Value<String?> albumName = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<String?> isrc = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String?> provider = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LovedTracksCompanion(
                trackId: trackId,
                trackName: trackName,
                artistName: artistName,
                albumName: albumName,
                coverUrl: coverUrl,
                coverPath: coverPath,
                isrc: isrc,
                durationMs: durationMs,
                provider: provider,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String trackId,
                required String trackName,
                required String artistName,
                Value<String?> albumName = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<String?> isrc = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String?> provider = const Value.absent(),
                required DateTime addedAt,
                Value<int> rowid = const Value.absent(),
              }) => LovedTracksCompanion.insert(
                trackId: trackId,
                trackName: trackName,
                artistName: artistName,
                albumName: albumName,
                coverUrl: coverUrl,
                coverPath: coverPath,
                isrc: isrc,
                durationMs: durationMs,
                provider: provider,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LovedTracksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LovedTracksTable,
      LovedTrack,
      $$LovedTracksTableFilterComposer,
      $$LovedTracksTableOrderingComposer,
      $$LovedTracksTableAnnotationComposer,
      $$LovedTracksTableCreateCompanionBuilder,
      $$LovedTracksTableUpdateCompanionBuilder,
      (
        LovedTrack,
        BaseReferences<_$AppDatabase, $LovedTracksTable, LovedTrack>,
      ),
      LovedTrack,
      PrefetchHooks Function()
    >;
typedef $$FavoriteAlbumsTableCreateCompanionBuilder =
    FavoriteAlbumsCompanion Function({
      required String albumId,
      required String name,
      required String artistId,
      required String artistName,
      required String coverUrl,
      Value<String?> coverPath,
      Value<String?> provider,
      required DateTime addedAt,
      Value<int> rowid,
    });
typedef $$FavoriteAlbumsTableUpdateCompanionBuilder =
    FavoriteAlbumsCompanion Function({
      Value<String> albumId,
      Value<String> name,
      Value<String> artistId,
      Value<String> artistName,
      Value<String> coverUrl,
      Value<String?> coverPath,
      Value<String?> provider,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

class $$FavoriteAlbumsTableFilterComposer
    extends Composer<_$AppDatabase, $FavoriteAlbumsTable> {
  $$FavoriteAlbumsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get albumId => $composableBuilder(
    column: $table.albumId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artistId => $composableBuilder(
    column: $table.artistId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FavoriteAlbumsTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoriteAlbumsTable> {
  $$FavoriteAlbumsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get albumId => $composableBuilder(
    column: $table.albumId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artistId => $composableBuilder(
    column: $table.artistId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FavoriteAlbumsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoriteAlbumsTable> {
  $$FavoriteAlbumsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get albumId =>
      $composableBuilder(column: $table.albumId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get artistId =>
      $composableBuilder(column: $table.artistId, builder: (column) => column);

  GeneratedColumn<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$FavoriteAlbumsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FavoriteAlbumsTable,
          FavoriteAlbum,
          $$FavoriteAlbumsTableFilterComposer,
          $$FavoriteAlbumsTableOrderingComposer,
          $$FavoriteAlbumsTableAnnotationComposer,
          $$FavoriteAlbumsTableCreateCompanionBuilder,
          $$FavoriteAlbumsTableUpdateCompanionBuilder,
          (
            FavoriteAlbum,
            BaseReferences<_$AppDatabase, $FavoriteAlbumsTable, FavoriteAlbum>,
          ),
          FavoriteAlbum,
          PrefetchHooks Function()
        > {
  $$FavoriteAlbumsTableTableManager(
    _$AppDatabase db,
    $FavoriteAlbumsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$FavoriteAlbumsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$FavoriteAlbumsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$FavoriteAlbumsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> albumId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> artistId = const Value.absent(),
                Value<String> artistName = const Value.absent(),
                Value<String> coverUrl = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<String?> provider = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavoriteAlbumsCompanion(
                albumId: albumId,
                name: name,
                artistId: artistId,
                artistName: artistName,
                coverUrl: coverUrl,
                coverPath: coverPath,
                provider: provider,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String albumId,
                required String name,
                required String artistId,
                required String artistName,
                required String coverUrl,
                Value<String?> coverPath = const Value.absent(),
                Value<String?> provider = const Value.absent(),
                required DateTime addedAt,
                Value<int> rowid = const Value.absent(),
              }) => FavoriteAlbumsCompanion.insert(
                albumId: albumId,
                name: name,
                artistId: artistId,
                artistName: artistName,
                coverUrl: coverUrl,
                coverPath: coverPath,
                provider: provider,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FavoriteAlbumsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FavoriteAlbumsTable,
      FavoriteAlbum,
      $$FavoriteAlbumsTableFilterComposer,
      $$FavoriteAlbumsTableOrderingComposer,
      $$FavoriteAlbumsTableAnnotationComposer,
      $$FavoriteAlbumsTableCreateCompanionBuilder,
      $$FavoriteAlbumsTableUpdateCompanionBuilder,
      (
        FavoriteAlbum,
        BaseReferences<_$AppDatabase, $FavoriteAlbumsTable, FavoriteAlbum>,
      ),
      FavoriteAlbum,
      PrefetchHooks Function()
    >;
typedef $$FavoriteArtistsTableCreateCompanionBuilder =
    FavoriteArtistsCompanion Function({
      required String artistId,
      required String name,
      required String imageUrl,
      Value<String?> imagePath,
      Value<String?> provider,
      required DateTime addedAt,
      Value<int> rowid,
    });
typedef $$FavoriteArtistsTableUpdateCompanionBuilder =
    FavoriteArtistsCompanion Function({
      Value<String> artistId,
      Value<String> name,
      Value<String> imageUrl,
      Value<String?> imagePath,
      Value<String?> provider,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

class $$FavoriteArtistsTableFilterComposer
    extends Composer<_$AppDatabase, $FavoriteArtistsTable> {
  $$FavoriteArtistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get artistId => $composableBuilder(
    column: $table.artistId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FavoriteArtistsTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoriteArtistsTable> {
  $$FavoriteArtistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get artistId => $composableBuilder(
    column: $table.artistId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FavoriteArtistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoriteArtistsTable> {
  $$FavoriteArtistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get artistId =>
      $composableBuilder(column: $table.artistId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$FavoriteArtistsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FavoriteArtistsTable,
          FavoriteArtist,
          $$FavoriteArtistsTableFilterComposer,
          $$FavoriteArtistsTableOrderingComposer,
          $$FavoriteArtistsTableAnnotationComposer,
          $$FavoriteArtistsTableCreateCompanionBuilder,
          $$FavoriteArtistsTableUpdateCompanionBuilder,
          (
            FavoriteArtist,
            BaseReferences<
              _$AppDatabase,
              $FavoriteArtistsTable,
              FavoriteArtist
            >,
          ),
          FavoriteArtist,
          PrefetchHooks Function()
        > {
  $$FavoriteArtistsTableTableManager(
    _$AppDatabase db,
    $FavoriteArtistsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () =>
                  $$FavoriteArtistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$FavoriteArtistsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$FavoriteArtistsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> artistId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> imageUrl = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<String?> provider = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavoriteArtistsCompanion(
                artistId: artistId,
                name: name,
                imageUrl: imageUrl,
                imagePath: imagePath,
                provider: provider,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String artistId,
                required String name,
                required String imageUrl,
                Value<String?> imagePath = const Value.absent(),
                Value<String?> provider = const Value.absent(),
                required DateTime addedAt,
                Value<int> rowid = const Value.absent(),
              }) => FavoriteArtistsCompanion.insert(
                artistId: artistId,
                name: name,
                imageUrl: imageUrl,
                imagePath: imagePath,
                provider: provider,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FavoriteArtistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FavoriteArtistsTable,
      FavoriteArtist,
      $$FavoriteArtistsTableFilterComposer,
      $$FavoriteArtistsTableOrderingComposer,
      $$FavoriteArtistsTableAnnotationComposer,
      $$FavoriteArtistsTableCreateCompanionBuilder,
      $$FavoriteArtistsTableUpdateCompanionBuilder,
      (
        FavoriteArtist,
        BaseReferences<_$AppDatabase, $FavoriteArtistsTable, FavoriteArtist>,
      ),
      FavoriteArtist,
      PrefetchHooks Function()
    >;
typedef $$FavoritePlaylistsTableCreateCompanionBuilder =
    FavoritePlaylistsCompanion Function({
      required String playlistId,
      required String name,
      Value<String?> coverUrl,
      Value<String?> coverPath,
      Value<String?> description,
      Value<String?> provider,
      Value<String?> externalUrl,
      required DateTime addedAt,
      Value<int> rowid,
    });
typedef $$FavoritePlaylistsTableUpdateCompanionBuilder =
    FavoritePlaylistsCompanion Function({
      Value<String> playlistId,
      Value<String> name,
      Value<String?> coverUrl,
      Value<String?> coverPath,
      Value<String?> description,
      Value<String?> provider,
      Value<String?> externalUrl,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

class $$FavoritePlaylistsTableFilterComposer
    extends Composer<_$AppDatabase, $FavoritePlaylistsTable> {
  $$FavoritePlaylistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get playlistId => $composableBuilder(
    column: $table.playlistId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get externalUrl => $composableBuilder(
    column: $table.externalUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FavoritePlaylistsTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoritePlaylistsTable> {
  $$FavoritePlaylistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get playlistId => $composableBuilder(
    column: $table.playlistId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalUrl => $composableBuilder(
    column: $table.externalUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FavoritePlaylistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoritePlaylistsTable> {
  $$FavoritePlaylistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get playlistId => $composableBuilder(
    column: $table.playlistId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get externalUrl => $composableBuilder(
    column: $table.externalUrl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$FavoritePlaylistsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FavoritePlaylistsTable,
          FavoritePlaylist,
          $$FavoritePlaylistsTableFilterComposer,
          $$FavoritePlaylistsTableOrderingComposer,
          $$FavoritePlaylistsTableAnnotationComposer,
          $$FavoritePlaylistsTableCreateCompanionBuilder,
          $$FavoritePlaylistsTableUpdateCompanionBuilder,
          (
            FavoritePlaylist,
            BaseReferences<
              _$AppDatabase,
              $FavoritePlaylistsTable,
              FavoritePlaylist
            >,
          ),
          FavoritePlaylist,
          PrefetchHooks Function()
        > {
  $$FavoritePlaylistsTableTableManager(
    _$AppDatabase db,
    $FavoritePlaylistsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$FavoritePlaylistsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$FavoritePlaylistsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$FavoritePlaylistsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> playlistId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> provider = const Value.absent(),
                Value<String?> externalUrl = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavoritePlaylistsCompanion(
                playlistId: playlistId,
                name: name,
                coverUrl: coverUrl,
                coverPath: coverPath,
                description: description,
                provider: provider,
                externalUrl: externalUrl,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String playlistId,
                required String name,
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> provider = const Value.absent(),
                Value<String?> externalUrl = const Value.absent(),
                required DateTime addedAt,
                Value<int> rowid = const Value.absent(),
              }) => FavoritePlaylistsCompanion.insert(
                playlistId: playlistId,
                name: name,
                coverUrl: coverUrl,
                coverPath: coverPath,
                description: description,
                provider: provider,
                externalUrl: externalUrl,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FavoritePlaylistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FavoritePlaylistsTable,
      FavoritePlaylist,
      $$FavoritePlaylistsTableFilterComposer,
      $$FavoritePlaylistsTableOrderingComposer,
      $$FavoritePlaylistsTableAnnotationComposer,
      $$FavoritePlaylistsTableCreateCompanionBuilder,
      $$FavoritePlaylistsTableUpdateCompanionBuilder,
      (
        FavoritePlaylist,
        BaseReferences<
          _$AppDatabase,
          $FavoritePlaylistsTable,
          FavoritePlaylist
        >,
      ),
      FavoritePlaylist,
      PrefetchHooks Function()
    >;
typedef $$CollectionsTableCreateCompanionBuilder =
    CollectionsCompanion Function({
      required String id,
      required String name,
      Value<String?> type,
      Value<String?> coverPath,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<String?> customJson,
      Value<String?> itemJson,
      Value<int> rowid,
    });
typedef $$CollectionsTableUpdateCompanionBuilder =
    CollectionsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> type,
      Value<String?> coverPath,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> customJson,
      Value<String?> itemJson,
      Value<int> rowid,
    });

final class $$CollectionsTableReferences
    extends BaseReferences<_$AppDatabase, $CollectionsTable, Collection> {
  $$CollectionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CollectionItemsTable, List<CollectionItem>>
  _collectionItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.collectionItems,
    aliasName: 'collections__id__collection_items__collection_id',
  );

  $$CollectionItemsTableProcessedTableManager get collectionItemsRefs {
    final manager = $$CollectionItemsTableTableManager(
      $_db,
      $_db.collectionItems,
    ).filter((f) => f.collectionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _collectionItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CollectionsTableFilterComposer
    extends Composer<_$AppDatabase, $CollectionsTable> {
  $$CollectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customJson => $composableBuilder(
    column: $table.customJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemJson => $composableBuilder(
    column: $table.itemJson,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> collectionItemsRefs(
    Expression<bool> Function($$CollectionItemsTableFilterComposer f) f,
  ) {
    final $$CollectionItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.collectionItems,
      getReferencedColumn: (t) => t.collectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionItemsTableFilterComposer(
            $db: $db,
            $table: $db.collectionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CollectionsTableOrderingComposer
    extends Composer<_$AppDatabase, $CollectionsTable> {
  $$CollectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customJson => $composableBuilder(
    column: $table.customJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemJson => $composableBuilder(
    column: $table.itemJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CollectionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CollectionsTable> {
  $$CollectionsTableAnnotationComposer({
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

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get customJson => $composableBuilder(
    column: $table.customJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get itemJson =>
      $composableBuilder(column: $table.itemJson, builder: (column) => column);

  Expression<T> collectionItemsRefs<T extends Object>(
    Expression<T> Function($$CollectionItemsTableAnnotationComposer a) f,
  ) {
    final $$CollectionItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.collectionItems,
      getReferencedColumn: (t) => t.collectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.collectionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CollectionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CollectionsTable,
          Collection,
          $$CollectionsTableFilterComposer,
          $$CollectionsTableOrderingComposer,
          $$CollectionsTableAnnotationComposer,
          $$CollectionsTableCreateCompanionBuilder,
          $$CollectionsTableUpdateCompanionBuilder,
          (Collection, $$CollectionsTableReferences),
          Collection,
          PrefetchHooks Function({bool collectionItemsRefs})
        > {
  $$CollectionsTableTableManager(_$AppDatabase db, $CollectionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$CollectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$CollectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$CollectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> type = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> customJson = const Value.absent(),
                Value<String?> itemJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CollectionsCompanion(
                id: id,
                name: name,
                type: type,
                coverPath: coverPath,
                createdAt: createdAt,
                updatedAt: updatedAt,
                customJson: customJson,
                itemJson: itemJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> type = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<String?> customJson = const Value.absent(),
                Value<String?> itemJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CollectionsCompanion.insert(
                id: id,
                name: name,
                type: type,
                coverPath: coverPath,
                createdAt: createdAt,
                updatedAt: updatedAt,
                customJson: customJson,
                itemJson: itemJson,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$CollectionsTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({collectionItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (collectionItemsRefs) db.collectionItems,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (collectionItemsRefs)
                    await $_getPrefetchedData<
                      Collection,
                      $CollectionsTable,
                      CollectionItem
                    >(
                      currentTable: table,
                      referencedTable: $$CollectionsTableReferences
                          ._collectionItemsRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$CollectionsTableReferences(
                                db,
                                table,
                                p0,
                              ).collectionItemsRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.collectionId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CollectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CollectionsTable,
      Collection,
      $$CollectionsTableFilterComposer,
      $$CollectionsTableOrderingComposer,
      $$CollectionsTableAnnotationComposer,
      $$CollectionsTableCreateCompanionBuilder,
      $$CollectionsTableUpdateCompanionBuilder,
      (Collection, $$CollectionsTableReferences),
      Collection,
      PrefetchHooks Function({bool collectionItemsRefs})
    >;
typedef $$CollectionItemsTableCreateCompanionBuilder =
    CollectionItemsCompanion Function({
      required String collectionId,
      required String itemId,
      Value<String?> trackId,
      Value<String?> itemJson,
      required DateTime addedAt,
      Value<int?> position,
      Value<int> rowid,
    });
typedef $$CollectionItemsTableUpdateCompanionBuilder =
    CollectionItemsCompanion Function({
      Value<String> collectionId,
      Value<String> itemId,
      Value<String?> trackId,
      Value<String?> itemJson,
      Value<DateTime> addedAt,
      Value<int?> position,
      Value<int> rowid,
    });

final class $$CollectionItemsTableReferences
    extends
        BaseReferences<_$AppDatabase, $CollectionItemsTable, CollectionItem> {
  $$CollectionItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CollectionsTable _collectionIdTable(_$AppDatabase db) => db
      .collections
      .createAlias('collection_items__collection_id__collections__id');

  $$CollectionsTableProcessedTableManager get collectionId {
    final $_column = $_itemColumn<String>('collection_id')!;

    final manager = $$CollectionsTableTableManager(
      $_db,
      $_db.collections,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_collectionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TracksTable _trackIdTable(_$AppDatabase db) =>
      db.tracks.createAlias('collection_items__track_id__tracks__id');

  $$TracksTableProcessedTableManager? get trackId {
    final $_column = $_itemColumn<String>('track_id');
    if ($_column == null) return null;
    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CollectionItemsTableFilterComposer
    extends Composer<_$AppDatabase, $CollectionItemsTable> {
  $$CollectionItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemJson => $composableBuilder(
    column: $table.itemJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  $$CollectionsTableFilterComposer get collectionId {
    final $$CollectionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.collections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionsTableFilterComposer(
            $db: $db,
            $table: $db.collections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TracksTableFilterComposer get trackId {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CollectionItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $CollectionItemsTable> {
  $$CollectionItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemJson => $composableBuilder(
    column: $table.itemJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  $$CollectionsTableOrderingComposer get collectionId {
    final $$CollectionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.collections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionsTableOrderingComposer(
            $db: $db,
            $table: $db.collections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TracksTableOrderingComposer get trackId {
    final $$TracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableOrderingComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CollectionItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CollectionItemsTable> {
  $$CollectionItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get itemJson =>
      $composableBuilder(column: $table.itemJson, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$CollectionsTableAnnotationComposer get collectionId {
    final $$CollectionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.collections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionsTableAnnotationComposer(
            $db: $db,
            $table: $db.collections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TracksTableAnnotationComposer get trackId {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CollectionItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CollectionItemsTable,
          CollectionItem,
          $$CollectionItemsTableFilterComposer,
          $$CollectionItemsTableOrderingComposer,
          $$CollectionItemsTableAnnotationComposer,
          $$CollectionItemsTableCreateCompanionBuilder,
          $$CollectionItemsTableUpdateCompanionBuilder,
          (CollectionItem, $$CollectionItemsTableReferences),
          CollectionItem,
          PrefetchHooks Function({bool collectionId, bool trackId})
        > {
  $$CollectionItemsTableTableManager(
    _$AppDatabase db,
    $CollectionItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () =>
                  $$CollectionItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$CollectionItemsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$CollectionItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> collectionId = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String?> trackId = const Value.absent(),
                Value<String?> itemJson = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int?> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CollectionItemsCompanion(
                collectionId: collectionId,
                itemId: itemId,
                trackId: trackId,
                itemJson: itemJson,
                addedAt: addedAt,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String collectionId,
                required String itemId,
                Value<String?> trackId = const Value.absent(),
                Value<String?> itemJson = const Value.absent(),
                required DateTime addedAt,
                Value<int?> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CollectionItemsCompanion.insert(
                collectionId: collectionId,
                itemId: itemId,
                trackId: trackId,
                itemJson: itemJson,
                addedAt: addedAt,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$CollectionItemsTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({collectionId = false, trackId = false}) {
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
                  dynamic
                >
              >(state) {
                if (collectionId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.collectionId,
                            referencedTable: $$CollectionItemsTableReferences
                                ._collectionIdTable(db),
                            referencedColumn:
                                $$CollectionItemsTableReferences
                                    ._collectionIdTable(db)
                                    .id,
                          )
                          as T;
                }
                if (trackId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.trackId,
                            referencedTable: $$CollectionItemsTableReferences
                                ._trackIdTable(db),
                            referencedColumn:
                                $$CollectionItemsTableReferences
                                    ._trackIdTable(db)
                                    .id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CollectionItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CollectionItemsTable,
      CollectionItem,
      $$CollectionItemsTableFilterComposer,
      $$CollectionItemsTableOrderingComposer,
      $$CollectionItemsTableAnnotationComposer,
      $$CollectionItemsTableCreateCompanionBuilder,
      $$CollectionItemsTableUpdateCompanionBuilder,
      (CollectionItem, $$CollectionItemsTableReferences),
      CollectionItem,
      PrefetchHooks Function({bool collectionId, bool trackId})
    >;
typedef $$PlayHistoryTableCreateCompanionBuilder =
    PlayHistoryCompanion Function({
      Value<int> id,
      Value<String?> trackId,
      required String trackName,
      required String artistName,
      Value<String?> albumName,
      required DateTime playedAt,
      Value<int?> durationMs,
      Value<int?> percentage,
    });
typedef $$PlayHistoryTableUpdateCompanionBuilder =
    PlayHistoryCompanion Function({
      Value<int> id,
      Value<String?> trackId,
      Value<String> trackName,
      Value<String> artistName,
      Value<String?> albumName,
      Value<DateTime> playedAt,
      Value<int?> durationMs,
      Value<int?> percentage,
    });

class $$PlayHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $PlayHistoryTable> {
  $$PlayHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackId => $composableBuilder(
    column: $table.trackId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackName => $composableBuilder(
    column: $table.trackName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumName => $composableBuilder(
    column: $table.albumName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get playedAt => $composableBuilder(
    column: $table.playedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get percentage => $composableBuilder(
    column: $table.percentage,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlayHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $PlayHistoryTable> {
  $$PlayHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackId => $composableBuilder(
    column: $table.trackId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackName => $composableBuilder(
    column: $table.trackName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumName => $composableBuilder(
    column: $table.albumName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get playedAt => $composableBuilder(
    column: $table.playedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get percentage => $composableBuilder(
    column: $table.percentage,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlayHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlayHistoryTable> {
  $$PlayHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get trackId =>
      $composableBuilder(column: $table.trackId, builder: (column) => column);

  GeneratedColumn<String> get trackName =>
      $composableBuilder(column: $table.trackName, builder: (column) => column);

  GeneratedColumn<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get albumName =>
      $composableBuilder(column: $table.albumName, builder: (column) => column);

  GeneratedColumn<DateTime> get playedAt =>
      $composableBuilder(column: $table.playedAt, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get percentage => $composableBuilder(
    column: $table.percentage,
    builder: (column) => column,
  );
}

class $$PlayHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlayHistoryTable,
          PlayHistoryData,
          $$PlayHistoryTableFilterComposer,
          $$PlayHistoryTableOrderingComposer,
          $$PlayHistoryTableAnnotationComposer,
          $$PlayHistoryTableCreateCompanionBuilder,
          $$PlayHistoryTableUpdateCompanionBuilder,
          (
            PlayHistoryData,
            BaseReferences<_$AppDatabase, $PlayHistoryTable, PlayHistoryData>,
          ),
          PlayHistoryData,
          PrefetchHooks Function()
        > {
  $$PlayHistoryTableTableManager(_$AppDatabase db, $PlayHistoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$PlayHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$PlayHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$PlayHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> trackId = const Value.absent(),
                Value<String> trackName = const Value.absent(),
                Value<String> artistName = const Value.absent(),
                Value<String?> albumName = const Value.absent(),
                Value<DateTime> playedAt = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<int?> percentage = const Value.absent(),
              }) => PlayHistoryCompanion(
                id: id,
                trackId: trackId,
                trackName: trackName,
                artistName: artistName,
                albumName: albumName,
                playedAt: playedAt,
                durationMs: durationMs,
                percentage: percentage,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> trackId = const Value.absent(),
                required String trackName,
                required String artistName,
                Value<String?> albumName = const Value.absent(),
                required DateTime playedAt,
                Value<int?> durationMs = const Value.absent(),
                Value<int?> percentage = const Value.absent(),
              }) => PlayHistoryCompanion.insert(
                id: id,
                trackId: trackId,
                trackName: trackName,
                artistName: artistName,
                albumName: albumName,
                playedAt: playedAt,
                durationMs: durationMs,
                percentage: percentage,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlayHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlayHistoryTable,
      PlayHistoryData,
      $$PlayHistoryTableFilterComposer,
      $$PlayHistoryTableOrderingComposer,
      $$PlayHistoryTableAnnotationComposer,
      $$PlayHistoryTableCreateCompanionBuilder,
      $$PlayHistoryTableUpdateCompanionBuilder,
      (
        PlayHistoryData,
        BaseReferences<_$AppDatabase, $PlayHistoryTable, PlayHistoryData>,
      ),
      PlayHistoryData,
      PrefetchHooks Function()
    >;
typedef $$PlayAggregatesTableCreateCompanionBuilder =
    PlayAggregatesCompanion Function({
      required String itemId,
      required String type,
      Value<int?> playCount,
      Value<DateTime?> lastPlayedAt,
      Value<int> rowid,
    });
typedef $$PlayAggregatesTableUpdateCompanionBuilder =
    PlayAggregatesCompanion Function({
      Value<String> itemId,
      Value<String> type,
      Value<int?> playCount,
      Value<DateTime?> lastPlayedAt,
      Value<int> rowid,
    });

class $$PlayAggregatesTableFilterComposer
    extends Composer<_$AppDatabase, $PlayAggregatesTable> {
  $$PlayAggregatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playCount => $composableBuilder(
    column: $table.playCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlayAggregatesTableOrderingComposer
    extends Composer<_$AppDatabase, $PlayAggregatesTable> {
  $$PlayAggregatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playCount => $composableBuilder(
    column: $table.playCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlayAggregatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlayAggregatesTable> {
  $$PlayAggregatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get playCount =>
      $composableBuilder(column: $table.playCount, builder: (column) => column);

  GeneratedColumn<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => column,
  );
}

class $$PlayAggregatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlayAggregatesTable,
          PlayAggregate,
          $$PlayAggregatesTableFilterComposer,
          $$PlayAggregatesTableOrderingComposer,
          $$PlayAggregatesTableAnnotationComposer,
          $$PlayAggregatesTableCreateCompanionBuilder,
          $$PlayAggregatesTableUpdateCompanionBuilder,
          (
            PlayAggregate,
            BaseReferences<_$AppDatabase, $PlayAggregatesTable, PlayAggregate>,
          ),
          PlayAggregate,
          PrefetchHooks Function()
        > {
  $$PlayAggregatesTableTableManager(
    _$AppDatabase db,
    $PlayAggregatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$PlayAggregatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$PlayAggregatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$PlayAggregatesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> itemId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int?> playCount = const Value.absent(),
                Value<DateTime?> lastPlayedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlayAggregatesCompanion(
                itemId: itemId,
                type: type,
                playCount: playCount,
                lastPlayedAt: lastPlayedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String itemId,
                required String type,
                Value<int?> playCount = const Value.absent(),
                Value<DateTime?> lastPlayedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlayAggregatesCompanion.insert(
                itemId: itemId,
                type: type,
                playCount: playCount,
                lastPlayedAt: lastPlayedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlayAggregatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlayAggregatesTable,
      PlayAggregate,
      $$PlayAggregatesTableFilterComposer,
      $$PlayAggregatesTableOrderingComposer,
      $$PlayAggregatesTableAnnotationComposer,
      $$PlayAggregatesTableCreateCompanionBuilder,
      $$PlayAggregatesTableUpdateCompanionBuilder,
      (
        PlayAggregate,
        BaseReferences<_$AppDatabase, $PlayAggregatesTable, PlayAggregate>,
      ),
      PlayAggregate,
      PrefetchHooks Function()
    >;
typedef $$DownloadQueueTableCreateCompanionBuilder =
    DownloadQueueCompanion Function({
      required String id,
      required String trackJson,
      Value<String?> itemJson,
      Value<String> status,
      Value<double?> progress,
      required DateTime createdAt,
      required DateTime updatedAt,
      required DateTime addedAt,
      Value<int> rowid,
    });
typedef $$DownloadQueueTableUpdateCompanionBuilder =
    DownloadQueueCompanion Function({
      Value<String> id,
      Value<String> trackJson,
      Value<String?> itemJson,
      Value<String> status,
      Value<double?> progress,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

class $$DownloadQueueTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadQueueTable> {
  $$DownloadQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackJson => $composableBuilder(
    column: $table.trackJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemJson => $composableBuilder(
    column: $table.itemJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadQueueTable> {
  $$DownloadQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackJson => $composableBuilder(
    column: $table.trackJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemJson => $composableBuilder(
    column: $table.itemJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadQueueTable> {
  $$DownloadQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get trackJson =>
      $composableBuilder(column: $table.trackJson, builder: (column) => column);

  GeneratedColumn<String> get itemJson =>
      $composableBuilder(column: $table.itemJson, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$DownloadQueueTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadQueueTable,
          DownloadQueueData,
          $$DownloadQueueTableFilterComposer,
          $$DownloadQueueTableOrderingComposer,
          $$DownloadQueueTableAnnotationComposer,
          $$DownloadQueueTableCreateCompanionBuilder,
          $$DownloadQueueTableUpdateCompanionBuilder,
          (
            DownloadQueueData,
            BaseReferences<
              _$AppDatabase,
              $DownloadQueueTable,
              DownloadQueueData
            >,
          ),
          DownloadQueueData,
          PrefetchHooks Function()
        > {
  $$DownloadQueueTableTableManager(_$AppDatabase db, $DownloadQueueTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$DownloadQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$DownloadQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$DownloadQueueTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> trackJson = const Value.absent(),
                Value<String?> itemJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<double?> progress = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadQueueCompanion(
                id: id,
                trackJson: trackJson,
                itemJson: itemJson,
                status: status,
                progress: progress,
                createdAt: createdAt,
                updatedAt: updatedAt,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String trackJson,
                Value<String?> itemJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<double?> progress = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                required DateTime addedAt,
                Value<int> rowid = const Value.absent(),
              }) => DownloadQueueCompanion.insert(
                id: id,
                trackJson: trackJson,
                itemJson: itemJson,
                status: status,
                progress: progress,
                createdAt: createdAt,
                updatedAt: updatedAt,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadQueueTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadQueueTable,
      DownloadQueueData,
      $$DownloadQueueTableFilterComposer,
      $$DownloadQueueTableOrderingComposer,
      $$DownloadQueueTableAnnotationComposer,
      $$DownloadQueueTableCreateCompanionBuilder,
      $$DownloadQueueTableUpdateCompanionBuilder,
      (
        DownloadQueueData,
        BaseReferences<_$AppDatabase, $DownloadQueueTable, DownloadQueueData>,
      ),
      DownloadQueueData,
      PrefetchHooks Function()
    >;
typedef $$DownloadHistoryTableCreateCompanionBuilder =
    DownloadHistoryCompanion Function({
      required String id,
      required String trackName,
      required String artistName,
      Value<String?> albumName,
      Value<String?> isrc,
      Value<String?> filePath,
      Value<String?> service,
      Value<int?> duration,
      required DateTime downloadedAt,
      Value<String?> providerTrackId,
      Value<String?> providerSource,
      Value<String?> coverUrl,
      Value<String?> coverPath,
      Value<int> rowid,
    });
typedef $$DownloadHistoryTableUpdateCompanionBuilder =
    DownloadHistoryCompanion Function({
      Value<String> id,
      Value<String> trackName,
      Value<String> artistName,
      Value<String?> albumName,
      Value<String?> isrc,
      Value<String?> filePath,
      Value<String?> service,
      Value<int?> duration,
      Value<DateTime> downloadedAt,
      Value<String?> providerTrackId,
      Value<String?> providerSource,
      Value<String?> coverUrl,
      Value<String?> coverPath,
      Value<int> rowid,
    });

class $$DownloadHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadHistoryTable> {
  $$DownloadHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackName => $composableBuilder(
    column: $table.trackName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumName => $composableBuilder(
    column: $table.albumName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get isrc => $composableBuilder(
    column: $table.isrc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get service => $composableBuilder(
    column: $table.service,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerTrackId => $composableBuilder(
    column: $table.providerTrackId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerSource => $composableBuilder(
    column: $table.providerSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadHistoryTable> {
  $$DownloadHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackName => $composableBuilder(
    column: $table.trackName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumName => $composableBuilder(
    column: $table.albumName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get isrc => $composableBuilder(
    column: $table.isrc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get service => $composableBuilder(
    column: $table.service,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerTrackId => $composableBuilder(
    column: $table.providerTrackId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerSource => $composableBuilder(
    column: $table.providerSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadHistoryTable> {
  $$DownloadHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get trackName =>
      $composableBuilder(column: $table.trackName, builder: (column) => column);

  GeneratedColumn<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get albumName =>
      $composableBuilder(column: $table.albumName, builder: (column) => column);

  GeneratedColumn<String> get isrc =>
      $composableBuilder(column: $table.isrc, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get service =>
      $composableBuilder(column: $table.service, builder: (column) => column);

  GeneratedColumn<int> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerTrackId => $composableBuilder(
    column: $table.providerTrackId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerSource => $composableBuilder(
    column: $table.providerSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);
}

class $$DownloadHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadHistoryTable,
          DownloadHistoryData,
          $$DownloadHistoryTableFilterComposer,
          $$DownloadHistoryTableOrderingComposer,
          $$DownloadHistoryTableAnnotationComposer,
          $$DownloadHistoryTableCreateCompanionBuilder,
          $$DownloadHistoryTableUpdateCompanionBuilder,
          (
            DownloadHistoryData,
            BaseReferences<
              _$AppDatabase,
              $DownloadHistoryTable,
              DownloadHistoryData
            >,
          ),
          DownloadHistoryData,
          PrefetchHooks Function()
        > {
  $$DownloadHistoryTableTableManager(
    _$AppDatabase db,
    $DownloadHistoryTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () =>
                  $$DownloadHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$DownloadHistoryTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$DownloadHistoryTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> trackName = const Value.absent(),
                Value<String> artistName = const Value.absent(),
                Value<String?> albumName = const Value.absent(),
                Value<String?> isrc = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<String?> service = const Value.absent(),
                Value<int?> duration = const Value.absent(),
                Value<DateTime> downloadedAt = const Value.absent(),
                Value<String?> providerTrackId = const Value.absent(),
                Value<String?> providerSource = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadHistoryCompanion(
                id: id,
                trackName: trackName,
                artistName: artistName,
                albumName: albumName,
                isrc: isrc,
                filePath: filePath,
                service: service,
                duration: duration,
                downloadedAt: downloadedAt,
                providerTrackId: providerTrackId,
                providerSource: providerSource,
                coverUrl: coverUrl,
                coverPath: coverPath,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String trackName,
                required String artistName,
                Value<String?> albumName = const Value.absent(),
                Value<String?> isrc = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<String?> service = const Value.absent(),
                Value<int?> duration = const Value.absent(),
                required DateTime downloadedAt,
                Value<String?> providerTrackId = const Value.absent(),
                Value<String?> providerSource = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadHistoryCompanion.insert(
                id: id,
                trackName: trackName,
                artistName: artistName,
                albumName: albumName,
                isrc: isrc,
                filePath: filePath,
                service: service,
                duration: duration,
                downloadedAt: downloadedAt,
                providerTrackId: providerTrackId,
                providerSource: providerSource,
                coverUrl: coverUrl,
                coverPath: coverPath,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadHistoryTable,
      DownloadHistoryData,
      $$DownloadHistoryTableFilterComposer,
      $$DownloadHistoryTableOrderingComposer,
      $$DownloadHistoryTableAnnotationComposer,
      $$DownloadHistoryTableCreateCompanionBuilder,
      $$DownloadHistoryTableUpdateCompanionBuilder,
      (
        DownloadHistoryData,
        BaseReferences<
          _$AppDatabase,
          $DownloadHistoryTable,
          DownloadHistoryData
        >,
      ),
      DownloadHistoryData,
      PrefetchHooks Function()
    >;
typedef $$DownloadBatchesTableCreateCompanionBuilder =
    DownloadBatchesCompanion Function({
      required String batchKey,
      Value<String?> itemType,
      Value<String?> itemId,
      Value<String?> source,
      Value<String?> name,
      Value<String?> trackIds,
      required DateTime downloadedAt,
      Value<int> rowid,
    });
typedef $$DownloadBatchesTableUpdateCompanionBuilder =
    DownloadBatchesCompanion Function({
      Value<String> batchKey,
      Value<String?> itemType,
      Value<String?> itemId,
      Value<String?> source,
      Value<String?> name,
      Value<String?> trackIds,
      Value<DateTime> downloadedAt,
      Value<int> rowid,
    });

class $$DownloadBatchesTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadBatchesTable> {
  $$DownloadBatchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get batchKey => $composableBuilder(
    column: $table.batchKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackIds => $composableBuilder(
    column: $table.trackIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadBatchesTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadBatchesTable> {
  $$DownloadBatchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get batchKey => $composableBuilder(
    column: $table.batchKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackIds => $composableBuilder(
    column: $table.trackIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadBatchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadBatchesTable> {
  $$DownloadBatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get batchKey =>
      $composableBuilder(column: $table.batchKey, builder: (column) => column);

  GeneratedColumn<String> get itemType =>
      $composableBuilder(column: $table.itemType, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get trackIds =>
      $composableBuilder(column: $table.trackIds, builder: (column) => column);

  GeneratedColumn<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => column,
  );
}

class $$DownloadBatchesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadBatchesTable,
          DownloadBatche,
          $$DownloadBatchesTableFilterComposer,
          $$DownloadBatchesTableOrderingComposer,
          $$DownloadBatchesTableAnnotationComposer,
          $$DownloadBatchesTableCreateCompanionBuilder,
          $$DownloadBatchesTableUpdateCompanionBuilder,
          (
            DownloadBatche,
            BaseReferences<
              _$AppDatabase,
              $DownloadBatchesTable,
              DownloadBatche
            >,
          ),
          DownloadBatche,
          PrefetchHooks Function()
        > {
  $$DownloadBatchesTableTableManager(
    _$AppDatabase db,
    $DownloadBatchesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () =>
                  $$DownloadBatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$DownloadBatchesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$DownloadBatchesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> batchKey = const Value.absent(),
                Value<String?> itemType = const Value.absent(),
                Value<String?> itemId = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> trackIds = const Value.absent(),
                Value<DateTime> downloadedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadBatchesCompanion(
                batchKey: batchKey,
                itemType: itemType,
                itemId: itemId,
                source: source,
                name: name,
                trackIds: trackIds,
                downloadedAt: downloadedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String batchKey,
                Value<String?> itemType = const Value.absent(),
                Value<String?> itemId = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> trackIds = const Value.absent(),
                required DateTime downloadedAt,
                Value<int> rowid = const Value.absent(),
              }) => DownloadBatchesCompanion.insert(
                batchKey: batchKey,
                itemType: itemType,
                itemId: itemId,
                source: source,
                name: name,
                trackIds: trackIds,
                downloadedAt: downloadedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadBatchesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadBatchesTable,
      DownloadBatche,
      $$DownloadBatchesTableFilterComposer,
      $$DownloadBatchesTableOrderingComposer,
      $$DownloadBatchesTableAnnotationComposer,
      $$DownloadBatchesTableCreateCompanionBuilder,
      $$DownloadBatchesTableUpdateCompanionBuilder,
      (
        DownloadBatche,
        BaseReferences<_$AppDatabase, $DownloadBatchesTable, DownloadBatche>,
      ),
      DownloadBatche,
      PrefetchHooks Function()
    >;
typedef $$HiddenDownloadIdsTableCreateCompanionBuilder =
    HiddenDownloadIdsCompanion Function({
      required String downloadId,
      Value<int> rowid,
    });
typedef $$HiddenDownloadIdsTableUpdateCompanionBuilder =
    HiddenDownloadIdsCompanion Function({
      Value<String> downloadId,
      Value<int> rowid,
    });

class $$HiddenDownloadIdsTableFilterComposer
    extends Composer<_$AppDatabase, $HiddenDownloadIdsTable> {
  $$HiddenDownloadIdsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get downloadId => $composableBuilder(
    column: $table.downloadId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HiddenDownloadIdsTableOrderingComposer
    extends Composer<_$AppDatabase, $HiddenDownloadIdsTable> {
  $$HiddenDownloadIdsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get downloadId => $composableBuilder(
    column: $table.downloadId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HiddenDownloadIdsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HiddenDownloadIdsTable> {
  $$HiddenDownloadIdsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get downloadId => $composableBuilder(
    column: $table.downloadId,
    builder: (column) => column,
  );
}

class $$HiddenDownloadIdsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HiddenDownloadIdsTable,
          HiddenDownloadId,
          $$HiddenDownloadIdsTableFilterComposer,
          $$HiddenDownloadIdsTableOrderingComposer,
          $$HiddenDownloadIdsTableAnnotationComposer,
          $$HiddenDownloadIdsTableCreateCompanionBuilder,
          $$HiddenDownloadIdsTableUpdateCompanionBuilder,
          (
            HiddenDownloadId,
            BaseReferences<
              _$AppDatabase,
              $HiddenDownloadIdsTable,
              HiddenDownloadId
            >,
          ),
          HiddenDownloadId,
          PrefetchHooks Function()
        > {
  $$HiddenDownloadIdsTableTableManager(
    _$AppDatabase db,
    $HiddenDownloadIdsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$HiddenDownloadIdsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$HiddenDownloadIdsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$HiddenDownloadIdsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> downloadId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HiddenDownloadIdsCompanion(
                downloadId: downloadId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String downloadId,
                Value<int> rowid = const Value.absent(),
              }) => HiddenDownloadIdsCompanion.insert(
                downloadId: downloadId,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HiddenDownloadIdsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HiddenDownloadIdsTable,
      HiddenDownloadId,
      $$HiddenDownloadIdsTableFilterComposer,
      $$HiddenDownloadIdsTableOrderingComposer,
      $$HiddenDownloadIdsTableAnnotationComposer,
      $$HiddenDownloadIdsTableCreateCompanionBuilder,
      $$HiddenDownloadIdsTableUpdateCompanionBuilder,
      (
        HiddenDownloadId,
        BaseReferences<
          _$AppDatabase,
          $HiddenDownloadIdsTable,
          HiddenDownloadId
        >,
      ),
      HiddenDownloadId,
      PrefetchHooks Function()
    >;
typedef $$RecentSearchesTableCreateCompanionBuilder =
    RecentSearchesCompanion Function({
      required String query,
      required DateTime searchedAt,
      Value<int> rowid,
    });
typedef $$RecentSearchesTableUpdateCompanionBuilder =
    RecentSearchesCompanion Function({
      Value<String> query,
      Value<DateTime> searchedAt,
      Value<int> rowid,
    });

class $$RecentSearchesTableFilterComposer
    extends Composer<_$AppDatabase, $RecentSearchesTable> {
  $$RecentSearchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get searchedAt => $composableBuilder(
    column: $table.searchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecentSearchesTableOrderingComposer
    extends Composer<_$AppDatabase, $RecentSearchesTable> {
  $$RecentSearchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get searchedAt => $composableBuilder(
    column: $table.searchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecentSearchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecentSearchesTable> {
  $$RecentSearchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get query =>
      $composableBuilder(column: $table.query, builder: (column) => column);

  GeneratedColumn<DateTime> get searchedAt => $composableBuilder(
    column: $table.searchedAt,
    builder: (column) => column,
  );
}

class $$RecentSearchesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecentSearchesTable,
          RecentSearche,
          $$RecentSearchesTableFilterComposer,
          $$RecentSearchesTableOrderingComposer,
          $$RecentSearchesTableAnnotationComposer,
          $$RecentSearchesTableCreateCompanionBuilder,
          $$RecentSearchesTableUpdateCompanionBuilder,
          (
            RecentSearche,
            BaseReferences<_$AppDatabase, $RecentSearchesTable, RecentSearche>,
          ),
          RecentSearche,
          PrefetchHooks Function()
        > {
  $$RecentSearchesTableTableManager(
    _$AppDatabase db,
    $RecentSearchesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$RecentSearchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$RecentSearchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$RecentSearchesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> query = const Value.absent(),
                Value<DateTime> searchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecentSearchesCompanion(
                query: query,
                searchedAt: searchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String query,
                required DateTime searchedAt,
                Value<int> rowid = const Value.absent(),
              }) => RecentSearchesCompanion.insert(
                query: query,
                searchedAt: searchedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecentSearchesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecentSearchesTable,
      RecentSearche,
      $$RecentSearchesTableFilterComposer,
      $$RecentSearchesTableOrderingComposer,
      $$RecentSearchesTableAnnotationComposer,
      $$RecentSearchesTableCreateCompanionBuilder,
      $$RecentSearchesTableUpdateCompanionBuilder,
      (
        RecentSearche,
        BaseReferences<_$AppDatabase, $RecentSearchesTable, RecentSearche>,
      ),
      RecentSearche,
      PrefetchHooks Function()
    >;
typedef $$RecentAccessTableCreateCompanionBuilder =
    RecentAccessCompanion Function({
      required String key,
      required String itemJson,
      Value<String?> type,
      required DateTime accessedAt,
      Value<int> rowid,
    });
typedef $$RecentAccessTableUpdateCompanionBuilder =
    RecentAccessCompanion Function({
      Value<String> key,
      Value<String> itemJson,
      Value<String?> type,
      Value<DateTime> accessedAt,
      Value<int> rowid,
    });

class $$RecentAccessTableFilterComposer
    extends Composer<_$AppDatabase, $RecentAccessTable> {
  $$RecentAccessTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemJson => $composableBuilder(
    column: $table.itemJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get accessedAt => $composableBuilder(
    column: $table.accessedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecentAccessTableOrderingComposer
    extends Composer<_$AppDatabase, $RecentAccessTable> {
  $$RecentAccessTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemJson => $composableBuilder(
    column: $table.itemJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get accessedAt => $composableBuilder(
    column: $table.accessedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecentAccessTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecentAccessTable> {
  $$RecentAccessTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get itemJson =>
      $composableBuilder(column: $table.itemJson, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<DateTime> get accessedAt => $composableBuilder(
    column: $table.accessedAt,
    builder: (column) => column,
  );
}

class $$RecentAccessTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecentAccessTable,
          RecentAccessData,
          $$RecentAccessTableFilterComposer,
          $$RecentAccessTableOrderingComposer,
          $$RecentAccessTableAnnotationComposer,
          $$RecentAccessTableCreateCompanionBuilder,
          $$RecentAccessTableUpdateCompanionBuilder,
          (
            RecentAccessData,
            BaseReferences<_$AppDatabase, $RecentAccessTable, RecentAccessData>,
          ),
          RecentAccessData,
          PrefetchHooks Function()
        > {
  $$RecentAccessTableTableManager(_$AppDatabase db, $RecentAccessTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$RecentAccessTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$RecentAccessTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$RecentAccessTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> itemJson = const Value.absent(),
                Value<String?> type = const Value.absent(),
                Value<DateTime> accessedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecentAccessCompanion(
                key: key,
                itemJson: itemJson,
                type: type,
                accessedAt: accessedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String itemJson,
                Value<String?> type = const Value.absent(),
                required DateTime accessedAt,
                Value<int> rowid = const Value.absent(),
              }) => RecentAccessCompanion.insert(
                key: key,
                itemJson: itemJson,
                type: type,
                accessedAt: accessedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecentAccessTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecentAccessTable,
      RecentAccessData,
      $$RecentAccessTableFilterComposer,
      $$RecentAccessTableOrderingComposer,
      $$RecentAccessTableAnnotationComposer,
      $$RecentAccessTableCreateCompanionBuilder,
      $$RecentAccessTableUpdateCompanionBuilder,
      (
        RecentAccessData,
        BaseReferences<_$AppDatabase, $RecentAccessTable, RecentAccessData>,
      ),
      RecentAccessData,
      PrefetchHooks Function()
    >;
typedef $$SecretCountersTableCreateCompanionBuilder =
    SecretCountersCompanion Function({
      required String key,
      Value<int?> value,
      Value<int> rowid,
    });
typedef $$SecretCountersTableUpdateCompanionBuilder =
    SecretCountersCompanion Function({
      Value<String> key,
      Value<int?> value,
      Value<int> rowid,
    });

class $$SecretCountersTableFilterComposer
    extends Composer<_$AppDatabase, $SecretCountersTable> {
  $$SecretCountersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SecretCountersTableOrderingComposer
    extends Composer<_$AppDatabase, $SecretCountersTable> {
  $$SecretCountersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SecretCountersTableAnnotationComposer
    extends Composer<_$AppDatabase, $SecretCountersTable> {
  $$SecretCountersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<int> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SecretCountersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SecretCountersTable,
          SecretCounter,
          $$SecretCountersTableFilterComposer,
          $$SecretCountersTableOrderingComposer,
          $$SecretCountersTableAnnotationComposer,
          $$SecretCountersTableCreateCompanionBuilder,
          $$SecretCountersTableUpdateCompanionBuilder,
          (
            SecretCounter,
            BaseReferences<_$AppDatabase, $SecretCountersTable, SecretCounter>,
          ),
          SecretCounter,
          PrefetchHooks Function()
        > {
  $$SecretCountersTableTableManager(
    _$AppDatabase db,
    $SecretCountersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$SecretCountersTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$SecretCountersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$SecretCountersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<int?> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) =>
                  SecretCountersCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                Value<int?> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SecretCountersCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SecretCountersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SecretCountersTable,
      SecretCounter,
      $$SecretCountersTableFilterComposer,
      $$SecretCountersTableOrderingComposer,
      $$SecretCountersTableAnnotationComposer,
      $$SecretCountersTableCreateCompanionBuilder,
      $$SecretCountersTableUpdateCompanionBuilder,
      (
        SecretCounter,
        BaseReferences<_$AppDatabase, $SecretCountersTable, SecretCounter>,
      ),
      SecretCounter,
      PrefetchHooks Function()
    >;
typedef $$SecretUnlocksTableCreateCompanionBuilder =
    SecretUnlocksCompanion Function({
      required String key,
      required DateTime unlockedAt,
      Value<int> rowid,
    });
typedef $$SecretUnlocksTableUpdateCompanionBuilder =
    SecretUnlocksCompanion Function({
      Value<String> key,
      Value<DateTime> unlockedAt,
      Value<int> rowid,
    });

class $$SecretUnlocksTableFilterComposer
    extends Composer<_$AppDatabase, $SecretUnlocksTable> {
  $$SecretUnlocksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get unlockedAt => $composableBuilder(
    column: $table.unlockedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SecretUnlocksTableOrderingComposer
    extends Composer<_$AppDatabase, $SecretUnlocksTable> {
  $$SecretUnlocksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get unlockedAt => $composableBuilder(
    column: $table.unlockedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SecretUnlocksTableAnnotationComposer
    extends Composer<_$AppDatabase, $SecretUnlocksTable> {
  $$SecretUnlocksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<DateTime> get unlockedAt => $composableBuilder(
    column: $table.unlockedAt,
    builder: (column) => column,
  );
}

class $$SecretUnlocksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SecretUnlocksTable,
          SecretUnlock,
          $$SecretUnlocksTableFilterComposer,
          $$SecretUnlocksTableOrderingComposer,
          $$SecretUnlocksTableAnnotationComposer,
          $$SecretUnlocksTableCreateCompanionBuilder,
          $$SecretUnlocksTableUpdateCompanionBuilder,
          (
            SecretUnlock,
            BaseReferences<_$AppDatabase, $SecretUnlocksTable, SecretUnlock>,
          ),
          SecretUnlock,
          PrefetchHooks Function()
        > {
  $$SecretUnlocksTableTableManager(_$AppDatabase db, $SecretUnlocksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$SecretUnlocksTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$SecretUnlocksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$SecretUnlocksTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<DateTime> unlockedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SecretUnlocksCompanion(
                key: key,
                unlockedAt: unlockedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required DateTime unlockedAt,
                Value<int> rowid = const Value.absent(),
              }) => SecretUnlocksCompanion.insert(
                key: key,
                unlockedAt: unlockedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SecretUnlocksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SecretUnlocksTable,
      SecretUnlock,
      $$SecretUnlocksTableFilterComposer,
      $$SecretUnlocksTableOrderingComposer,
      $$SecretUnlocksTableAnnotationComposer,
      $$SecretUnlocksTableCreateCompanionBuilder,
      $$SecretUnlocksTableUpdateCompanionBuilder,
      (
        SecretUnlock,
        BaseReferences<_$AppDatabase, $SecretUnlocksTable, SecretUnlock>,
      ),
      SecretUnlock,
      PrefetchHooks Function()
    >;
typedef $$UserPremiumTableCreateCompanionBuilder =
    UserPremiumCompanion Function({
      Value<String> id,
      Value<String> tier,
      Value<int?> premiumUntil,
      Value<int?> dailyPlayLimit,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$UserPremiumTableUpdateCompanionBuilder =
    UserPremiumCompanion Function({
      Value<String> id,
      Value<String> tier,
      Value<int?> premiumUntil,
      Value<int?> dailyPlayLimit,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$UserPremiumTableFilterComposer
    extends Composer<_$AppDatabase, $UserPremiumTable> {
  $$UserPremiumTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get premiumUntil => $composableBuilder(
    column: $table.premiumUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dailyPlayLimit => $composableBuilder(
    column: $table.dailyPlayLimit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserPremiumTableOrderingComposer
    extends Composer<_$AppDatabase, $UserPremiumTable> {
  $$UserPremiumTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get premiumUntil => $composableBuilder(
    column: $table.premiumUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dailyPlayLimit => $composableBuilder(
    column: $table.dailyPlayLimit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserPremiumTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserPremiumTable> {
  $$UserPremiumTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tier =>
      $composableBuilder(column: $table.tier, builder: (column) => column);

  GeneratedColumn<int> get premiumUntil => $composableBuilder(
    column: $table.premiumUntil,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dailyPlayLimit => $composableBuilder(
    column: $table.dailyPlayLimit,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UserPremiumTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserPremiumTable,
          UserPremiumData,
          $$UserPremiumTableFilterComposer,
          $$UserPremiumTableOrderingComposer,
          $$UserPremiumTableAnnotationComposer,
          $$UserPremiumTableCreateCompanionBuilder,
          $$UserPremiumTableUpdateCompanionBuilder,
          (
            UserPremiumData,
            BaseReferences<_$AppDatabase, $UserPremiumTable, UserPremiumData>,
          ),
          UserPremiumData,
          PrefetchHooks Function()
        > {
  $$UserPremiumTableTableManager(_$AppDatabase db, $UserPremiumTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$UserPremiumTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$UserPremiumTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$UserPremiumTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tier = const Value.absent(),
                Value<int?> premiumUntil = const Value.absent(),
                Value<int?> dailyPlayLimit = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserPremiumCompanion(
                id: id,
                tier: tier,
                premiumUntil: premiumUntil,
                dailyPlayLimit: dailyPlayLimit,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tier = const Value.absent(),
                Value<int?> premiumUntil = const Value.absent(),
                Value<int?> dailyPlayLimit = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => UserPremiumCompanion.insert(
                id: id,
                tier: tier,
                premiumUntil: premiumUntil,
                dailyPlayLimit: dailyPlayLimit,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserPremiumTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserPremiumTable,
      UserPremiumData,
      $$UserPremiumTableFilterComposer,
      $$UserPremiumTableOrderingComposer,
      $$UserPremiumTableAnnotationComposer,
      $$UserPremiumTableCreateCompanionBuilder,
      $$UserPremiumTableUpdateCompanionBuilder,
      (
        UserPremiumData,
        BaseReferences<_$AppDatabase, $UserPremiumTable, UserPremiumData>,
      ),
      UserPremiumData,
      PrefetchHooks Function()
    >;
typedef $$QuotaUsageTableCreateCompanionBuilder =
    QuotaUsageCompanion Function({
      required String userId,
      required String trackId,
      required double durationMinutes,
      Value<String> status,
      required DateTime downloadedAt,
      Value<int> rowid,
    });
typedef $$QuotaUsageTableUpdateCompanionBuilder =
    QuotaUsageCompanion Function({
      Value<String> userId,
      Value<String> trackId,
      Value<double> durationMinutes,
      Value<String> status,
      Value<DateTime> downloadedAt,
      Value<int> rowid,
    });

class $$QuotaUsageTableFilterComposer
    extends Composer<_$AppDatabase, $QuotaUsageTable> {
  $$QuotaUsageTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackId => $composableBuilder(
    column: $table.trackId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QuotaUsageTableOrderingComposer
    extends Composer<_$AppDatabase, $QuotaUsageTable> {
  $$QuotaUsageTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackId => $composableBuilder(
    column: $table.trackId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QuotaUsageTableAnnotationComposer
    extends Composer<_$AppDatabase, $QuotaUsageTable> {
  $$QuotaUsageTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get trackId =>
      $composableBuilder(column: $table.trackId, builder: (column) => column);

  GeneratedColumn<double> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => column,
  );
}

class $$QuotaUsageTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QuotaUsageTable,
          QuotaUsageData,
          $$QuotaUsageTableFilterComposer,
          $$QuotaUsageTableOrderingComposer,
          $$QuotaUsageTableAnnotationComposer,
          $$QuotaUsageTableCreateCompanionBuilder,
          $$QuotaUsageTableUpdateCompanionBuilder,
          (
            QuotaUsageData,
            BaseReferences<_$AppDatabase, $QuotaUsageTable, QuotaUsageData>,
          ),
          QuotaUsageData,
          PrefetchHooks Function()
        > {
  $$QuotaUsageTableTableManager(_$AppDatabase db, $QuotaUsageTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$QuotaUsageTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$QuotaUsageTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$QuotaUsageTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> trackId = const Value.absent(),
                Value<double> durationMinutes = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> downloadedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuotaUsageCompanion(
                userId: userId,
                trackId: trackId,
                durationMinutes: durationMinutes,
                status: status,
                downloadedAt: downloadedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required String trackId,
                required double durationMinutes,
                Value<String> status = const Value.absent(),
                required DateTime downloadedAt,
                Value<int> rowid = const Value.absent(),
              }) => QuotaUsageCompanion.insert(
                userId: userId,
                trackId: trackId,
                durationMinutes: durationMinutes,
                status: status,
                downloadedAt: downloadedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QuotaUsageTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QuotaUsageTable,
      QuotaUsageData,
      $$QuotaUsageTableFilterComposer,
      $$QuotaUsageTableOrderingComposer,
      $$QuotaUsageTableAnnotationComposer,
      $$QuotaUsageTableCreateCompanionBuilder,
      $$QuotaUsageTableUpdateCompanionBuilder,
      (
        QuotaUsageData,
        BaseReferences<_$AppDatabase, $QuotaUsageTable, QuotaUsageData>,
      ),
      QuotaUsageData,
      PrefetchHooks Function()
    >;
typedef $$UserDailyPlaysTableCreateCompanionBuilder =
    UserDailyPlaysCompanion Function({
      Value<int> id,
      required String date,
      Value<int?> playCount,
    });
typedef $$UserDailyPlaysTableUpdateCompanionBuilder =
    UserDailyPlaysCompanion Function({
      Value<int> id,
      Value<String> date,
      Value<int?> playCount,
    });

class $$UserDailyPlaysTableFilterComposer
    extends Composer<_$AppDatabase, $UserDailyPlaysTable> {
  $$UserDailyPlaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playCount => $composableBuilder(
    column: $table.playCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserDailyPlaysTableOrderingComposer
    extends Composer<_$AppDatabase, $UserDailyPlaysTable> {
  $$UserDailyPlaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playCount => $composableBuilder(
    column: $table.playCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserDailyPlaysTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserDailyPlaysTable> {
  $$UserDailyPlaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get playCount =>
      $composableBuilder(column: $table.playCount, builder: (column) => column);
}

class $$UserDailyPlaysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserDailyPlaysTable,
          UserDailyPlay,
          $$UserDailyPlaysTableFilterComposer,
          $$UserDailyPlaysTableOrderingComposer,
          $$UserDailyPlaysTableAnnotationComposer,
          $$UserDailyPlaysTableCreateCompanionBuilder,
          $$UserDailyPlaysTableUpdateCompanionBuilder,
          (
            UserDailyPlay,
            BaseReferences<_$AppDatabase, $UserDailyPlaysTable, UserDailyPlay>,
          ),
          UserDailyPlay,
          PrefetchHooks Function()
        > {
  $$UserDailyPlaysTableTableManager(
    _$AppDatabase db,
    $UserDailyPlaysTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$UserDailyPlaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$UserDailyPlaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$UserDailyPlaysTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<int?> playCount = const Value.absent(),
              }) => UserDailyPlaysCompanion(
                id: id,
                date: date,
                playCount: playCount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String date,
                Value<int?> playCount = const Value.absent(),
              }) => UserDailyPlaysCompanion.insert(
                id: id,
                date: date,
                playCount: playCount,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserDailyPlaysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserDailyPlaysTable,
      UserDailyPlay,
      $$UserDailyPlaysTableFilterComposer,
      $$UserDailyPlaysTableOrderingComposer,
      $$UserDailyPlaysTableAnnotationComposer,
      $$UserDailyPlaysTableCreateCompanionBuilder,
      $$UserDailyPlaysTableUpdateCompanionBuilder,
      (
        UserDailyPlay,
        BaseReferences<_$AppDatabase, $UserDailyPlaysTable, UserDailyPlay>,
      ),
      UserDailyPlay,
      PrefetchHooks Function()
    >;
typedef $$IsrcCacheTableCreateCompanionBuilder =
    IsrcCacheCompanion Function({
      required String isrc,
      Value<String> genre,
      Value<String> albumArtist,
      required int fetchedAt,
      Value<int> rowid,
    });
typedef $$IsrcCacheTableUpdateCompanionBuilder =
    IsrcCacheCompanion Function({
      Value<String> isrc,
      Value<String> genre,
      Value<String> albumArtist,
      Value<int> fetchedAt,
      Value<int> rowid,
    });

class $$IsrcCacheTableFilterComposer
    extends Composer<_$AppDatabase, $IsrcCacheTable> {
  $$IsrcCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get isrc => $composableBuilder(
    column: $table.isrc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumArtist => $composableBuilder(
    column: $table.albumArtist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$IsrcCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $IsrcCacheTable> {
  $$IsrcCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get isrc => $composableBuilder(
    column: $table.isrc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumArtist => $composableBuilder(
    column: $table.albumArtist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IsrcCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $IsrcCacheTable> {
  $$IsrcCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get isrc =>
      $composableBuilder(column: $table.isrc, builder: (column) => column);

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<String> get albumArtist => $composableBuilder(
    column: $table.albumArtist,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$IsrcCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $IsrcCacheTable,
          IsrcCacheData,
          $$IsrcCacheTableFilterComposer,
          $$IsrcCacheTableOrderingComposer,
          $$IsrcCacheTableAnnotationComposer,
          $$IsrcCacheTableCreateCompanionBuilder,
          $$IsrcCacheTableUpdateCompanionBuilder,
          (
            IsrcCacheData,
            BaseReferences<_$AppDatabase, $IsrcCacheTable, IsrcCacheData>,
          ),
          IsrcCacheData,
          PrefetchHooks Function()
        > {
  $$IsrcCacheTableTableManager(_$AppDatabase db, $IsrcCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$IsrcCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$IsrcCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$IsrcCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> isrc = const Value.absent(),
                Value<String> genre = const Value.absent(),
                Value<String> albumArtist = const Value.absent(),
                Value<int> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IsrcCacheCompanion(
                isrc: isrc,
                genre: genre,
                albumArtist: albumArtist,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String isrc,
                Value<String> genre = const Value.absent(),
                Value<String> albumArtist = const Value.absent(),
                required int fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => IsrcCacheCompanion.insert(
                isrc: isrc,
                genre: genre,
                albumArtist: albumArtist,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$IsrcCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $IsrcCacheTable,
      IsrcCacheData,
      $$IsrcCacheTableFilterComposer,
      $$IsrcCacheTableOrderingComposer,
      $$IsrcCacheTableAnnotationComposer,
      $$IsrcCacheTableCreateCompanionBuilder,
      $$IsrcCacheTableUpdateCompanionBuilder,
      (
        IsrcCacheData,
        BaseReferences<_$AppDatabase, $IsrcCacheTable, IsrcCacheData>,
      ),
      IsrcCacheData,
      PrefetchHooks Function()
    >;
typedef $$VideoUrlCacheTableCreateCompanionBuilder =
    VideoUrlCacheCompanion Function({
      required String id,
      required String trackName,
      required String artistName,
      required String url,
      Value<String?> source,
      required int cachedAt,
      Value<int> rowid,
    });
typedef $$VideoUrlCacheTableUpdateCompanionBuilder =
    VideoUrlCacheCompanion Function({
      Value<String> id,
      Value<String> trackName,
      Value<String> artistName,
      Value<String> url,
      Value<String?> source,
      Value<int> cachedAt,
      Value<int> rowid,
    });

class $$VideoUrlCacheTableFilterComposer
    extends Composer<_$AppDatabase, $VideoUrlCacheTable> {
  $$VideoUrlCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackName => $composableBuilder(
    column: $table.trackName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VideoUrlCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $VideoUrlCacheTable> {
  $$VideoUrlCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackName => $composableBuilder(
    column: $table.trackName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VideoUrlCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $VideoUrlCacheTable> {
  $$VideoUrlCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get trackName =>
      $composableBuilder(column: $table.trackName, builder: (column) => column);

  GeneratedColumn<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$VideoUrlCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VideoUrlCacheTable,
          VideoUrlCacheData,
          $$VideoUrlCacheTableFilterComposer,
          $$VideoUrlCacheTableOrderingComposer,
          $$VideoUrlCacheTableAnnotationComposer,
          $$VideoUrlCacheTableCreateCompanionBuilder,
          $$VideoUrlCacheTableUpdateCompanionBuilder,
          (
            VideoUrlCacheData,
            BaseReferences<
              _$AppDatabase,
              $VideoUrlCacheTable,
              VideoUrlCacheData
            >,
          ),
          VideoUrlCacheData,
          PrefetchHooks Function()
        > {
  $$VideoUrlCacheTableTableManager(_$AppDatabase db, $VideoUrlCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$VideoUrlCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$VideoUrlCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$VideoUrlCacheTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> trackName = const Value.absent(),
                Value<String> artistName = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<int> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VideoUrlCacheCompanion(
                id: id,
                trackName: trackName,
                artistName: artistName,
                url: url,
                source: source,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String trackName,
                required String artistName,
                required String url,
                Value<String?> source = const Value.absent(),
                required int cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => VideoUrlCacheCompanion.insert(
                id: id,
                trackName: trackName,
                artistName: artistName,
                url: url,
                source: source,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VideoUrlCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VideoUrlCacheTable,
      VideoUrlCacheData,
      $$VideoUrlCacheTableFilterComposer,
      $$VideoUrlCacheTableOrderingComposer,
      $$VideoUrlCacheTableAnnotationComposer,
      $$VideoUrlCacheTableCreateCompanionBuilder,
      $$VideoUrlCacheTableUpdateCompanionBuilder,
      (
        VideoUrlCacheData,
        BaseReferences<_$AppDatabase, $VideoUrlCacheTable, VideoUrlCacheData>,
      ),
      VideoUrlCacheData,
      PrefetchHooks Function()
    >;
typedef $$JsonCacheTableCreateCompanionBuilder =
    JsonCacheCompanion Function({
      required String key,
      required String json,
      required int timestamp,
      Value<int> rowid,
    });
typedef $$JsonCacheTableUpdateCompanionBuilder =
    JsonCacheCompanion Function({
      Value<String> key,
      Value<String> json,
      Value<int> timestamp,
      Value<int> rowid,
    });

class $$JsonCacheTableFilterComposer
    extends Composer<_$AppDatabase, $JsonCacheTable> {
  $$JsonCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );
}

class $$JsonCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $JsonCacheTable> {
  $$JsonCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$JsonCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $JsonCacheTable> {
  $$JsonCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<int> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);
}

class $$JsonCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $JsonCacheTable,
          JsonCacheData,
          $$JsonCacheTableFilterComposer,
          $$JsonCacheTableOrderingComposer,
          $$JsonCacheTableAnnotationComposer,
          $$JsonCacheTableCreateCompanionBuilder,
          $$JsonCacheTableUpdateCompanionBuilder,
          (
            JsonCacheData,
            BaseReferences<_$AppDatabase, $JsonCacheTable, JsonCacheData>,
          ),
          JsonCacheData,
          PrefetchHooks Function()
        > {
  $$JsonCacheTableTableManager(_$AppDatabase db, $JsonCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$JsonCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$JsonCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$JsonCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<int> timestamp = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JsonCacheCompanion(
                key: key,
                json: json,
                timestamp: timestamp,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String json,
                required int timestamp,
                Value<int> rowid = const Value.absent(),
              }) => JsonCacheCompanion.insert(
                key: key,
                json: json,
                timestamp: timestamp,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$JsonCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $JsonCacheTable,
      JsonCacheData,
      $$JsonCacheTableFilterComposer,
      $$JsonCacheTableOrderingComposer,
      $$JsonCacheTableAnnotationComposer,
      $$JsonCacheTableCreateCompanionBuilder,
      $$JsonCacheTableUpdateCompanionBuilder,
      (
        JsonCacheData,
        BaseReferences<_$AppDatabase, $JsonCacheTable, JsonCacheData>,
      ),
      JsonCacheData,
      PrefetchHooks Function()
    >;
typedef $$SimilarArtistsTableCreateCompanionBuilder =
    SimilarArtistsCompanion Function({
      required String artistId,
      required String similarArtistId,
      Value<double?> similarityScore,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$SimilarArtistsTableUpdateCompanionBuilder =
    SimilarArtistsCompanion Function({
      Value<String> artistId,
      Value<String> similarArtistId,
      Value<double?> similarityScore,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$SimilarArtistsTableReferences
    extends BaseReferences<_$AppDatabase, $SimilarArtistsTable, SimilarArtist> {
  $$SimilarArtistsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ArtistsTable _artistIdTable(_$AppDatabase db) =>
      db.artists.createAlias('similar_artists__artist_id__artists__id');

  $$ArtistsTableProcessedTableManager get artistId {
    final $_column = $_itemColumn<String>('artist_id')!;

    final manager = $$ArtistsTableTableManager(
      $_db,
      $_db.artists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_artistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ArtistsTable _similarArtistIdTable(_$AppDatabase db) =>
      db.artists.createAlias('similar_artists__similar_artist_id__artists__id');

  $$ArtistsTableProcessedTableManager get similarArtistId {
    final $_column = $_itemColumn<String>('similar_artist_id')!;

    final manager = $$ArtistsTableTableManager(
      $_db,
      $_db.artists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_similarArtistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SimilarArtistsTableFilterComposer
    extends Composer<_$AppDatabase, $SimilarArtistsTable> {
  $$SimilarArtistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<double> get similarityScore => $composableBuilder(
    column: $table.similarityScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ArtistsTableFilterComposer get artistId {
    final $$ArtistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.artistId,
      referencedTable: $db.artists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArtistsTableFilterComposer(
            $db: $db,
            $table: $db.artists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ArtistsTableFilterComposer get similarArtistId {
    final $$ArtistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.similarArtistId,
      referencedTable: $db.artists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArtistsTableFilterComposer(
            $db: $db,
            $table: $db.artists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SimilarArtistsTableOrderingComposer
    extends Composer<_$AppDatabase, $SimilarArtistsTable> {
  $$SimilarArtistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<double> get similarityScore => $composableBuilder(
    column: $table.similarityScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ArtistsTableOrderingComposer get artistId {
    final $$ArtistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.artistId,
      referencedTable: $db.artists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArtistsTableOrderingComposer(
            $db: $db,
            $table: $db.artists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ArtistsTableOrderingComposer get similarArtistId {
    final $$ArtistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.similarArtistId,
      referencedTable: $db.artists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArtistsTableOrderingComposer(
            $db: $db,
            $table: $db.artists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SimilarArtistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SimilarArtistsTable> {
  $$SimilarArtistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<double> get similarityScore => $composableBuilder(
    column: $table.similarityScore,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ArtistsTableAnnotationComposer get artistId {
    final $$ArtistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.artistId,
      referencedTable: $db.artists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArtistsTableAnnotationComposer(
            $db: $db,
            $table: $db.artists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ArtistsTableAnnotationComposer get similarArtistId {
    final $$ArtistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.similarArtistId,
      referencedTable: $db.artists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArtistsTableAnnotationComposer(
            $db: $db,
            $table: $db.artists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SimilarArtistsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SimilarArtistsTable,
          SimilarArtist,
          $$SimilarArtistsTableFilterComposer,
          $$SimilarArtistsTableOrderingComposer,
          $$SimilarArtistsTableAnnotationComposer,
          $$SimilarArtistsTableCreateCompanionBuilder,
          $$SimilarArtistsTableUpdateCompanionBuilder,
          (SimilarArtist, $$SimilarArtistsTableReferences),
          SimilarArtist,
          PrefetchHooks Function({bool artistId, bool similarArtistId})
        > {
  $$SimilarArtistsTableTableManager(
    _$AppDatabase db,
    $SimilarArtistsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$SimilarArtistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$SimilarArtistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$SimilarArtistsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> artistId = const Value.absent(),
                Value<String> similarArtistId = const Value.absent(),
                Value<double?> similarityScore = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SimilarArtistsCompanion(
                artistId: artistId,
                similarArtistId: similarArtistId,
                similarityScore: similarityScore,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String artistId,
                required String similarArtistId,
                Value<double?> similarityScore = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => SimilarArtistsCompanion.insert(
                artistId: artistId,
                similarArtistId: similarArtistId,
                similarityScore: similarityScore,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$SimilarArtistsTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({artistId = false, similarArtistId = false}) {
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
                  dynamic
                >
              >(state) {
                if (artistId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.artistId,
                            referencedTable: $$SimilarArtistsTableReferences
                                ._artistIdTable(db),
                            referencedColumn:
                                $$SimilarArtistsTableReferences
                                    ._artistIdTable(db)
                                    .id,
                          )
                          as T;
                }
                if (similarArtistId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.similarArtistId,
                            referencedTable: $$SimilarArtistsTableReferences
                                ._similarArtistIdTable(db),
                            referencedColumn:
                                $$SimilarArtistsTableReferences
                                    ._similarArtistIdTable(db)
                                    .id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SimilarArtistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SimilarArtistsTable,
      SimilarArtist,
      $$SimilarArtistsTableFilterComposer,
      $$SimilarArtistsTableOrderingComposer,
      $$SimilarArtistsTableAnnotationComposer,
      $$SimilarArtistsTableCreateCompanionBuilder,
      $$SimilarArtistsTableUpdateCompanionBuilder,
      (SimilarArtist, $$SimilarArtistsTableReferences),
      SimilarArtist,
      PrefetchHooks Function({bool artistId, bool similarArtistId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$ArtistsTableTableManager get artists =>
      $$ArtistsTableTableManager(_db, _db.artists);
  $$AlbumsTableTableManager get albums =>
      $$AlbumsTableTableManager(_db, _db.albums);
  $$TracksTableTableManager get tracks =>
      $$TracksTableTableManager(_db, _db.tracks);
  $$SourcesTableTableManager get sources =>
      $$SourcesTableTableManager(_db, _db.sources);
  $$FilesTableTableManager get files =>
      $$FilesTableTableManager(_db, _db.files);
  $$LovedTracksTableTableManager get lovedTracks =>
      $$LovedTracksTableTableManager(_db, _db.lovedTracks);
  $$FavoriteAlbumsTableTableManager get favoriteAlbums =>
      $$FavoriteAlbumsTableTableManager(_db, _db.favoriteAlbums);
  $$FavoriteArtistsTableTableManager get favoriteArtists =>
      $$FavoriteArtistsTableTableManager(_db, _db.favoriteArtists);
  $$FavoritePlaylistsTableTableManager get favoritePlaylists =>
      $$FavoritePlaylistsTableTableManager(_db, _db.favoritePlaylists);
  $$CollectionsTableTableManager get collections =>
      $$CollectionsTableTableManager(_db, _db.collections);
  $$CollectionItemsTableTableManager get collectionItems =>
      $$CollectionItemsTableTableManager(_db, _db.collectionItems);
  $$PlayHistoryTableTableManager get playHistory =>
      $$PlayHistoryTableTableManager(_db, _db.playHistory);
  $$PlayAggregatesTableTableManager get playAggregates =>
      $$PlayAggregatesTableTableManager(_db, _db.playAggregates);
  $$DownloadQueueTableTableManager get downloadQueue =>
      $$DownloadQueueTableTableManager(_db, _db.downloadQueue);
  $$DownloadHistoryTableTableManager get downloadHistory =>
      $$DownloadHistoryTableTableManager(_db, _db.downloadHistory);
  $$DownloadBatchesTableTableManager get downloadBatches =>
      $$DownloadBatchesTableTableManager(_db, _db.downloadBatches);
  $$HiddenDownloadIdsTableTableManager get hiddenDownloadIds =>
      $$HiddenDownloadIdsTableTableManager(_db, _db.hiddenDownloadIds);
  $$RecentSearchesTableTableManager get recentSearches =>
      $$RecentSearchesTableTableManager(_db, _db.recentSearches);
  $$RecentAccessTableTableManager get recentAccess =>
      $$RecentAccessTableTableManager(_db, _db.recentAccess);
  $$SecretCountersTableTableManager get secretCounters =>
      $$SecretCountersTableTableManager(_db, _db.secretCounters);
  $$SecretUnlocksTableTableManager get secretUnlocks =>
      $$SecretUnlocksTableTableManager(_db, _db.secretUnlocks);
  $$UserPremiumTableTableManager get userPremium =>
      $$UserPremiumTableTableManager(_db, _db.userPremium);
  $$QuotaUsageTableTableManager get quotaUsage =>
      $$QuotaUsageTableTableManager(_db, _db.quotaUsage);
  $$UserDailyPlaysTableTableManager get userDailyPlays =>
      $$UserDailyPlaysTableTableManager(_db, _db.userDailyPlays);
  $$IsrcCacheTableTableManager get isrcCache =>
      $$IsrcCacheTableTableManager(_db, _db.isrcCache);
  $$VideoUrlCacheTableTableManager get videoUrlCache =>
      $$VideoUrlCacheTableTableManager(_db, _db.videoUrlCache);
  $$JsonCacheTableTableManager get jsonCache =>
      $$JsonCacheTableTableManager(_db, _db.jsonCache);
  $$SimilarArtistsTableTableManager get similarArtists =>
      $$SimilarArtistsTableTableManager(_db, _db.similarArtists);
}
