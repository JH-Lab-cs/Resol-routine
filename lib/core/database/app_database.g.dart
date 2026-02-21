// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ContentPacksTable extends ContentPacks
    with TableInfo<$ContentPacksTable, ContentPack> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentPacksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (version >= 1)',
  );
  static const VerificationMeta _localeMeta = const VerificationMeta('locale');
  @override
  late final GeneratedColumn<String> locale = GeneratedColumn<String>(
    'locale',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 2),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _checksumMeta = const VerificationMeta(
    'checksum',
  );
  @override
  late final GeneratedColumn<String> checksum = GeneratedColumn<String>(
    'checksum',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    version,
    locale,
    title,
    description,
    checksum,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_packs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContentPack> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('locale')) {
      context.handle(
        _localeMeta,
        locale.isAcceptableOrUnknown(data['locale']!, _localeMeta),
      );
    } else if (isInserting) {
      context.missing(_localeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
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
    if (data.containsKey('checksum')) {
      context.handle(
        _checksumMeta,
        checksum.isAcceptableOrUnknown(data['checksum']!, _checksumMeta),
      );
    } else if (isInserting) {
      context.missing(_checksumMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ContentPack map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentPack(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      locale: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}locale'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      checksum: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checksum'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ContentPacksTable createAlias(String alias) {
    return $ContentPacksTable(attachedDatabase, alias);
  }
}

class ContentPack extends DataClass implements Insertable<ContentPack> {
  final String id;
  final int version;
  final String locale;
  final String title;
  final String? description;
  final String checksum;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ContentPack({
    required this.id,
    required this.version,
    required this.locale,
    required this.title,
    this.description,
    required this.checksum,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['version'] = Variable<int>(version);
    map['locale'] = Variable<String>(locale);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['checksum'] = Variable<String>(checksum);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ContentPacksCompanion toCompanion(bool nullToAbsent) {
    return ContentPacksCompanion(
      id: Value(id),
      version: Value(version),
      locale: Value(locale),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      checksum: Value(checksum),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ContentPack.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentPack(
      id: serializer.fromJson<String>(json['id']),
      version: serializer.fromJson<int>(json['version']),
      locale: serializer.fromJson<String>(json['locale']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      checksum: serializer.fromJson<String>(json['checksum']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'version': serializer.toJson<int>(version),
      'locale': serializer.toJson<String>(locale),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'checksum': serializer.toJson<String>(checksum),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ContentPack copyWith({
    String? id,
    int? version,
    String? locale,
    String? title,
    Value<String?> description = const Value.absent(),
    String? checksum,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ContentPack(
    id: id ?? this.id,
    version: version ?? this.version,
    locale: locale ?? this.locale,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    checksum: checksum ?? this.checksum,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ContentPack copyWithCompanion(ContentPacksCompanion data) {
    return ContentPack(
      id: data.id.present ? data.id.value : this.id,
      version: data.version.present ? data.version.value : this.version,
      locale: data.locale.present ? data.locale.value : this.locale,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      checksum: data.checksum.present ? data.checksum.value : this.checksum,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentPack(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('locale: $locale, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('checksum: $checksum, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    version,
    locale,
    title,
    description,
    checksum,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentPack &&
          other.id == this.id &&
          other.version == this.version &&
          other.locale == this.locale &&
          other.title == this.title &&
          other.description == this.description &&
          other.checksum == this.checksum &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ContentPacksCompanion extends UpdateCompanion<ContentPack> {
  final Value<String> id;
  final Value<int> version;
  final Value<String> locale;
  final Value<String> title;
  final Value<String?> description;
  final Value<String> checksum;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ContentPacksCompanion({
    this.id = const Value.absent(),
    this.version = const Value.absent(),
    this.locale = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.checksum = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContentPacksCompanion.insert({
    required String id,
    required int version,
    required String locale,
    required String title,
    this.description = const Value.absent(),
    required String checksum,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       version = Value(version),
       locale = Value(locale),
       title = Value(title),
       checksum = Value(checksum);
  static Insertable<ContentPack> custom({
    Expression<String>? id,
    Expression<int>? version,
    Expression<String>? locale,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? checksum,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (version != null) 'version': version,
      if (locale != null) 'locale': locale,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (checksum != null) 'checksum': checksum,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContentPacksCompanion copyWith({
    Value<String>? id,
    Value<int>? version,
    Value<String>? locale,
    Value<String>? title,
    Value<String?>? description,
    Value<String>? checksum,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ContentPacksCompanion(
      id: id ?? this.id,
      version: version ?? this.version,
      locale: locale ?? this.locale,
      title: title ?? this.title,
      description: description ?? this.description,
      checksum: checksum ?? this.checksum,
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
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (locale.present) {
      map['locale'] = Variable<String>(locale.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (checksum.present) {
      map['checksum'] = Variable<String>(checksum.value);
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
    return (StringBuffer('ContentPacksCompanion(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('locale: $locale, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('checksum: $checksum, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PassagesTable extends Passages with TableInfo<$PassagesTable, Passage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PassagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _packIdMeta = const VerificationMeta('packId');
  @override
  late final GeneratedColumn<String> packId = GeneratedColumn<String>(
    'pack_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES content_packs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<Sentence>, String>
  sentencesJson = GeneratedColumn<String>(
    'sentences_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<List<Sentence>>($PassagesTable.$convertersentencesJson);
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (order_index >= 0)',
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    packId,
    title,
    sentencesJson,
    orderIndex,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'passages';
  @override
  VerificationContext validateIntegrity(
    Insertable<Passage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('pack_id')) {
      context.handle(
        _packIdMeta,
        packId.isAcceptableOrUnknown(data['pack_id']!, _packIdMeta),
      );
    } else if (isInserting) {
      context.missing(_packIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Passage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Passage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      packId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pack_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      sentencesJson: $PassagesTable.$convertersentencesJson.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}sentences_json'],
        )!,
      ),
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PassagesTable createAlias(String alias) {
    return $PassagesTable(attachedDatabase, alias);
  }

  static TypeConverter<List<Sentence>, String> $convertersentencesJson =
      const SentencesConverter();
}

class Passage extends DataClass implements Insertable<Passage> {
  final String id;
  final String packId;
  final String? title;
  final List<Sentence> sentencesJson;
  final int orderIndex;
  final DateTime createdAt;
  const Passage({
    required this.id,
    required this.packId,
    this.title,
    required this.sentencesJson,
    required this.orderIndex,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['pack_id'] = Variable<String>(packId);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    {
      map['sentences_json'] = Variable<String>(
        $PassagesTable.$convertersentencesJson.toSql(sentencesJson),
      );
    }
    map['order_index'] = Variable<int>(orderIndex);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PassagesCompanion toCompanion(bool nullToAbsent) {
    return PassagesCompanion(
      id: Value(id),
      packId: Value(packId),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      sentencesJson: Value(sentencesJson),
      orderIndex: Value(orderIndex),
      createdAt: Value(createdAt),
    );
  }

  factory Passage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Passage(
      id: serializer.fromJson<String>(json['id']),
      packId: serializer.fromJson<String>(json['packId']),
      title: serializer.fromJson<String?>(json['title']),
      sentencesJson: serializer.fromJson<List<Sentence>>(json['sentencesJson']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'packId': serializer.toJson<String>(packId),
      'title': serializer.toJson<String?>(title),
      'sentencesJson': serializer.toJson<List<Sentence>>(sentencesJson),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Passage copyWith({
    String? id,
    String? packId,
    Value<String?> title = const Value.absent(),
    List<Sentence>? sentencesJson,
    int? orderIndex,
    DateTime? createdAt,
  }) => Passage(
    id: id ?? this.id,
    packId: packId ?? this.packId,
    title: title.present ? title.value : this.title,
    sentencesJson: sentencesJson ?? this.sentencesJson,
    orderIndex: orderIndex ?? this.orderIndex,
    createdAt: createdAt ?? this.createdAt,
  );
  Passage copyWithCompanion(PassagesCompanion data) {
    return Passage(
      id: data.id.present ? data.id.value : this.id,
      packId: data.packId.present ? data.packId.value : this.packId,
      title: data.title.present ? data.title.value : this.title,
      sentencesJson: data.sentencesJson.present
          ? data.sentencesJson.value
          : this.sentencesJson,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Passage(')
          ..write('id: $id, ')
          ..write('packId: $packId, ')
          ..write('title: $title, ')
          ..write('sentencesJson: $sentencesJson, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, packId, title, sentencesJson, orderIndex, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Passage &&
          other.id == this.id &&
          other.packId == this.packId &&
          other.title == this.title &&
          other.sentencesJson == this.sentencesJson &&
          other.orderIndex == this.orderIndex &&
          other.createdAt == this.createdAt);
}

class PassagesCompanion extends UpdateCompanion<Passage> {
  final Value<String> id;
  final Value<String> packId;
  final Value<String?> title;
  final Value<List<Sentence>> sentencesJson;
  final Value<int> orderIndex;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PassagesCompanion({
    this.id = const Value.absent(),
    this.packId = const Value.absent(),
    this.title = const Value.absent(),
    this.sentencesJson = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PassagesCompanion.insert({
    required String id,
    required String packId,
    this.title = const Value.absent(),
    required List<Sentence> sentencesJson,
    required int orderIndex,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       packId = Value(packId),
       sentencesJson = Value(sentencesJson),
       orderIndex = Value(orderIndex);
  static Insertable<Passage> custom({
    Expression<String>? id,
    Expression<String>? packId,
    Expression<String>? title,
    Expression<String>? sentencesJson,
    Expression<int>? orderIndex,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (packId != null) 'pack_id': packId,
      if (title != null) 'title': title,
      if (sentencesJson != null) 'sentences_json': sentencesJson,
      if (orderIndex != null) 'order_index': orderIndex,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PassagesCompanion copyWith({
    Value<String>? id,
    Value<String>? packId,
    Value<String?>? title,
    Value<List<Sentence>>? sentencesJson,
    Value<int>? orderIndex,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return PassagesCompanion(
      id: id ?? this.id,
      packId: packId ?? this.packId,
      title: title ?? this.title,
      sentencesJson: sentencesJson ?? this.sentencesJson,
      orderIndex: orderIndex ?? this.orderIndex,
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
    if (packId.present) {
      map['pack_id'] = Variable<String>(packId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (sentencesJson.present) {
      map['sentences_json'] = Variable<String>(
        $PassagesTable.$convertersentencesJson.toSql(sentencesJson.value),
      );
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
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
    return (StringBuffer('PassagesCompanion(')
          ..write('id: $id, ')
          ..write('packId: $packId, ')
          ..write('title: $title, ')
          ..write('sentencesJson: $sentencesJson, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScriptsTable extends Scripts with TableInfo<$ScriptsTable, Script> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScriptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _packIdMeta = const VerificationMeta('packId');
  @override
  late final GeneratedColumn<String> packId = GeneratedColumn<String>(
    'pack_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES content_packs (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<Sentence>, String>
  sentencesJson = GeneratedColumn<String>(
    'sentences_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<List<Sentence>>($ScriptsTable.$convertersentencesJson);
  @override
  late final GeneratedColumnWithTypeConverter<List<Turn>, String> turnsJson =
      GeneratedColumn<String>(
        'turns_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<List<Turn>>($ScriptsTable.$converterturnsJson);
  @override
  late final GeneratedColumnWithTypeConverter<TtsPlan, String> ttsPlanJson =
      GeneratedColumn<String>(
        'tts_plan_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TtsPlan>($ScriptsTable.$converterttsPlanJson);
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (order_index >= 0)',
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    packId,
    sentencesJson,
    turnsJson,
    ttsPlanJson,
    orderIndex,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scripts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Script> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('pack_id')) {
      context.handle(
        _packIdMeta,
        packId.isAcceptableOrUnknown(data['pack_id']!, _packIdMeta),
      );
    } else if (isInserting) {
      context.missing(_packIdMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Script map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Script(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      packId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pack_id'],
      )!,
      sentencesJson: $ScriptsTable.$convertersentencesJson.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}sentences_json'],
        )!,
      ),
      turnsJson: $ScriptsTable.$converterturnsJson.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}turns_json'],
        )!,
      ),
      ttsPlanJson: $ScriptsTable.$converterttsPlanJson.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}tts_plan_json'],
        )!,
      ),
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ScriptsTable createAlias(String alias) {
    return $ScriptsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<Sentence>, String> $convertersentencesJson =
      const SentencesConverter();
  static TypeConverter<List<Turn>, String> $converterturnsJson =
      const TurnsConverter();
  static TypeConverter<TtsPlan, String> $converterttsPlanJson =
      const TtsPlanConverter();
}

class Script extends DataClass implements Insertable<Script> {
  final String id;
  final String packId;
  final List<Sentence> sentencesJson;
  final List<Turn> turnsJson;
  final TtsPlan ttsPlanJson;
  final int orderIndex;
  final DateTime createdAt;
  const Script({
    required this.id,
    required this.packId,
    required this.sentencesJson,
    required this.turnsJson,
    required this.ttsPlanJson,
    required this.orderIndex,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['pack_id'] = Variable<String>(packId);
    {
      map['sentences_json'] = Variable<String>(
        $ScriptsTable.$convertersentencesJson.toSql(sentencesJson),
      );
    }
    {
      map['turns_json'] = Variable<String>(
        $ScriptsTable.$converterturnsJson.toSql(turnsJson),
      );
    }
    {
      map['tts_plan_json'] = Variable<String>(
        $ScriptsTable.$converterttsPlanJson.toSql(ttsPlanJson),
      );
    }
    map['order_index'] = Variable<int>(orderIndex);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ScriptsCompanion toCompanion(bool nullToAbsent) {
    return ScriptsCompanion(
      id: Value(id),
      packId: Value(packId),
      sentencesJson: Value(sentencesJson),
      turnsJson: Value(turnsJson),
      ttsPlanJson: Value(ttsPlanJson),
      orderIndex: Value(orderIndex),
      createdAt: Value(createdAt),
    );
  }

  factory Script.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Script(
      id: serializer.fromJson<String>(json['id']),
      packId: serializer.fromJson<String>(json['packId']),
      sentencesJson: serializer.fromJson<List<Sentence>>(json['sentencesJson']),
      turnsJson: serializer.fromJson<List<Turn>>(json['turnsJson']),
      ttsPlanJson: serializer.fromJson<TtsPlan>(json['ttsPlanJson']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'packId': serializer.toJson<String>(packId),
      'sentencesJson': serializer.toJson<List<Sentence>>(sentencesJson),
      'turnsJson': serializer.toJson<List<Turn>>(turnsJson),
      'ttsPlanJson': serializer.toJson<TtsPlan>(ttsPlanJson),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Script copyWith({
    String? id,
    String? packId,
    List<Sentence>? sentencesJson,
    List<Turn>? turnsJson,
    TtsPlan? ttsPlanJson,
    int? orderIndex,
    DateTime? createdAt,
  }) => Script(
    id: id ?? this.id,
    packId: packId ?? this.packId,
    sentencesJson: sentencesJson ?? this.sentencesJson,
    turnsJson: turnsJson ?? this.turnsJson,
    ttsPlanJson: ttsPlanJson ?? this.ttsPlanJson,
    orderIndex: orderIndex ?? this.orderIndex,
    createdAt: createdAt ?? this.createdAt,
  );
  Script copyWithCompanion(ScriptsCompanion data) {
    return Script(
      id: data.id.present ? data.id.value : this.id,
      packId: data.packId.present ? data.packId.value : this.packId,
      sentencesJson: data.sentencesJson.present
          ? data.sentencesJson.value
          : this.sentencesJson,
      turnsJson: data.turnsJson.present ? data.turnsJson.value : this.turnsJson,
      ttsPlanJson: data.ttsPlanJson.present
          ? data.ttsPlanJson.value
          : this.ttsPlanJson,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Script(')
          ..write('id: $id, ')
          ..write('packId: $packId, ')
          ..write('sentencesJson: $sentencesJson, ')
          ..write('turnsJson: $turnsJson, ')
          ..write('ttsPlanJson: $ttsPlanJson, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    packId,
    sentencesJson,
    turnsJson,
    ttsPlanJson,
    orderIndex,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Script &&
          other.id == this.id &&
          other.packId == this.packId &&
          other.sentencesJson == this.sentencesJson &&
          other.turnsJson == this.turnsJson &&
          other.ttsPlanJson == this.ttsPlanJson &&
          other.orderIndex == this.orderIndex &&
          other.createdAt == this.createdAt);
}

class ScriptsCompanion extends UpdateCompanion<Script> {
  final Value<String> id;
  final Value<String> packId;
  final Value<List<Sentence>> sentencesJson;
  final Value<List<Turn>> turnsJson;
  final Value<TtsPlan> ttsPlanJson;
  final Value<int> orderIndex;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ScriptsCompanion({
    this.id = const Value.absent(),
    this.packId = const Value.absent(),
    this.sentencesJson = const Value.absent(),
    this.turnsJson = const Value.absent(),
    this.ttsPlanJson = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScriptsCompanion.insert({
    required String id,
    required String packId,
    required List<Sentence> sentencesJson,
    required List<Turn> turnsJson,
    required TtsPlan ttsPlanJson,
    required int orderIndex,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       packId = Value(packId),
       sentencesJson = Value(sentencesJson),
       turnsJson = Value(turnsJson),
       ttsPlanJson = Value(ttsPlanJson),
       orderIndex = Value(orderIndex);
  static Insertable<Script> custom({
    Expression<String>? id,
    Expression<String>? packId,
    Expression<String>? sentencesJson,
    Expression<String>? turnsJson,
    Expression<String>? ttsPlanJson,
    Expression<int>? orderIndex,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (packId != null) 'pack_id': packId,
      if (sentencesJson != null) 'sentences_json': sentencesJson,
      if (turnsJson != null) 'turns_json': turnsJson,
      if (ttsPlanJson != null) 'tts_plan_json': ttsPlanJson,
      if (orderIndex != null) 'order_index': orderIndex,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScriptsCompanion copyWith({
    Value<String>? id,
    Value<String>? packId,
    Value<List<Sentence>>? sentencesJson,
    Value<List<Turn>>? turnsJson,
    Value<TtsPlan>? ttsPlanJson,
    Value<int>? orderIndex,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ScriptsCompanion(
      id: id ?? this.id,
      packId: packId ?? this.packId,
      sentencesJson: sentencesJson ?? this.sentencesJson,
      turnsJson: turnsJson ?? this.turnsJson,
      ttsPlanJson: ttsPlanJson ?? this.ttsPlanJson,
      orderIndex: orderIndex ?? this.orderIndex,
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
    if (packId.present) {
      map['pack_id'] = Variable<String>(packId.value);
    }
    if (sentencesJson.present) {
      map['sentences_json'] = Variable<String>(
        $ScriptsTable.$convertersentencesJson.toSql(sentencesJson.value),
      );
    }
    if (turnsJson.present) {
      map['turns_json'] = Variable<String>(
        $ScriptsTable.$converterturnsJson.toSql(turnsJson.value),
      );
    }
    if (ttsPlanJson.present) {
      map['tts_plan_json'] = Variable<String>(
        $ScriptsTable.$converterttsPlanJson.toSql(ttsPlanJson.value),
      );
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
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
    return (StringBuffer('ScriptsCompanion(')
          ..write('id: $id, ')
          ..write('packId: $packId, ')
          ..write('sentencesJson: $sentencesJson, ')
          ..write('turnsJson: $turnsJson, ')
          ..write('ttsPlanJson: $ttsPlanJson, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QuestionsTable extends Questions
    with TableInfo<$QuestionsTable, Question> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuestionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _skillMeta = const VerificationMeta('skill');
  @override
  late final GeneratedColumn<String> skill = GeneratedColumn<String>(
    'skill',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (skill IN (\'LISTENING\', \'READING\'))',
  );
  static const VerificationMeta _typeTagMeta = const VerificationMeta(
    'typeTag',
  );
  @override
  late final GeneratedColumn<String> typeTag = GeneratedColumn<String>(
    'type_tag',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 2),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackMeta = const VerificationMeta('track');
  @override
  late final GeneratedColumn<String> track = GeneratedColumn<String>(
    'track',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (track IN (\'M3\', \'H1\', \'H2\', \'H3\'))',
  );
  static const VerificationMeta _difficultyMeta = const VerificationMeta(
    'difficulty',
  );
  @override
  late final GeneratedColumn<int> difficulty = GeneratedColumn<int>(
    'difficulty',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (difficulty BETWEEN 1 AND 5)',
  );
  static const VerificationMeta _passageIdMeta = const VerificationMeta(
    'passageId',
  );
  @override
  late final GeneratedColumn<String> passageId = GeneratedColumn<String>(
    'passage_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES passages (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _scriptIdMeta = const VerificationMeta(
    'scriptId',
  );
  @override
  late final GeneratedColumn<String> scriptId = GeneratedColumn<String>(
    'script_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES scripts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _promptMeta = const VerificationMeta('prompt');
  @override
  late final GeneratedColumn<String> prompt = GeneratedColumn<String>(
    'prompt',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<OptionMap, String> optionsJson =
      GeneratedColumn<String>(
        'options_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<OptionMap>($QuestionsTable.$converteroptionsJson);
  static const VerificationMeta _answerKeyMeta = const VerificationMeta(
    'answerKey',
  );
  @override
  late final GeneratedColumn<String> answerKey = GeneratedColumn<String>(
    'answer_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (answer_key IN (\'A\', \'B\', \'C\', \'D\', \'E\'))',
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (order_index >= 0)',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    skill,
    typeTag,
    track,
    difficulty,
    passageId,
    scriptId,
    prompt,
    optionsJson,
    answerKey,
    orderIndex,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'questions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Question> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('skill')) {
      context.handle(
        _skillMeta,
        skill.isAcceptableOrUnknown(data['skill']!, _skillMeta),
      );
    } else if (isInserting) {
      context.missing(_skillMeta);
    }
    if (data.containsKey('type_tag')) {
      context.handle(
        _typeTagMeta,
        typeTag.isAcceptableOrUnknown(data['type_tag']!, _typeTagMeta),
      );
    } else if (isInserting) {
      context.missing(_typeTagMeta);
    }
    if (data.containsKey('track')) {
      context.handle(
        _trackMeta,
        track.isAcceptableOrUnknown(data['track']!, _trackMeta),
      );
    } else if (isInserting) {
      context.missing(_trackMeta);
    }
    if (data.containsKey('difficulty')) {
      context.handle(
        _difficultyMeta,
        difficulty.isAcceptableOrUnknown(data['difficulty']!, _difficultyMeta),
      );
    } else if (isInserting) {
      context.missing(_difficultyMeta);
    }
    if (data.containsKey('passage_id')) {
      context.handle(
        _passageIdMeta,
        passageId.isAcceptableOrUnknown(data['passage_id']!, _passageIdMeta),
      );
    }
    if (data.containsKey('script_id')) {
      context.handle(
        _scriptIdMeta,
        scriptId.isAcceptableOrUnknown(data['script_id']!, _scriptIdMeta),
      );
    }
    if (data.containsKey('prompt')) {
      context.handle(
        _promptMeta,
        prompt.isAcceptableOrUnknown(data['prompt']!, _promptMeta),
      );
    } else if (isInserting) {
      context.missing(_promptMeta);
    }
    if (data.containsKey('answer_key')) {
      context.handle(
        _answerKeyMeta,
        answerKey.isAcceptableOrUnknown(data['answer_key']!, _answerKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_answerKeyMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Question map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Question(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      skill: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}skill'],
      )!,
      typeTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type_tag'],
      )!,
      track: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track'],
      )!,
      difficulty: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}difficulty'],
      )!,
      passageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}passage_id'],
      ),
      scriptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}script_id'],
      ),
      prompt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prompt'],
      )!,
      optionsJson: $QuestionsTable.$converteroptionsJson.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}options_json'],
        )!,
      ),
      answerKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answer_key'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
    );
  }

  @override
  $QuestionsTable createAlias(String alias) {
    return $QuestionsTable(attachedDatabase, alias);
  }

  static TypeConverter<OptionMap, String> $converteroptionsJson =
      const OptionMapConverter();
}

class Question extends DataClass implements Insertable<Question> {
  final String id;
  final String skill;
  final String typeTag;
  final String track;
  final int difficulty;
  final String? passageId;
  final String? scriptId;
  final String prompt;
  final OptionMap optionsJson;
  final String answerKey;
  final int orderIndex;
  const Question({
    required this.id,
    required this.skill,
    required this.typeTag,
    required this.track,
    required this.difficulty,
    this.passageId,
    this.scriptId,
    required this.prompt,
    required this.optionsJson,
    required this.answerKey,
    required this.orderIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['skill'] = Variable<String>(skill);
    map['type_tag'] = Variable<String>(typeTag);
    map['track'] = Variable<String>(track);
    map['difficulty'] = Variable<int>(difficulty);
    if (!nullToAbsent || passageId != null) {
      map['passage_id'] = Variable<String>(passageId);
    }
    if (!nullToAbsent || scriptId != null) {
      map['script_id'] = Variable<String>(scriptId);
    }
    map['prompt'] = Variable<String>(prompt);
    {
      map['options_json'] = Variable<String>(
        $QuestionsTable.$converteroptionsJson.toSql(optionsJson),
      );
    }
    map['answer_key'] = Variable<String>(answerKey);
    map['order_index'] = Variable<int>(orderIndex);
    return map;
  }

  QuestionsCompanion toCompanion(bool nullToAbsent) {
    return QuestionsCompanion(
      id: Value(id),
      skill: Value(skill),
      typeTag: Value(typeTag),
      track: Value(track),
      difficulty: Value(difficulty),
      passageId: passageId == null && nullToAbsent
          ? const Value.absent()
          : Value(passageId),
      scriptId: scriptId == null && nullToAbsent
          ? const Value.absent()
          : Value(scriptId),
      prompt: Value(prompt),
      optionsJson: Value(optionsJson),
      answerKey: Value(answerKey),
      orderIndex: Value(orderIndex),
    );
  }

  factory Question.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Question(
      id: serializer.fromJson<String>(json['id']),
      skill: serializer.fromJson<String>(json['skill']),
      typeTag: serializer.fromJson<String>(json['typeTag']),
      track: serializer.fromJson<String>(json['track']),
      difficulty: serializer.fromJson<int>(json['difficulty']),
      passageId: serializer.fromJson<String?>(json['passageId']),
      scriptId: serializer.fromJson<String?>(json['scriptId']),
      prompt: serializer.fromJson<String>(json['prompt']),
      optionsJson: serializer.fromJson<OptionMap>(json['optionsJson']),
      answerKey: serializer.fromJson<String>(json['answerKey']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'skill': serializer.toJson<String>(skill),
      'typeTag': serializer.toJson<String>(typeTag),
      'track': serializer.toJson<String>(track),
      'difficulty': serializer.toJson<int>(difficulty),
      'passageId': serializer.toJson<String?>(passageId),
      'scriptId': serializer.toJson<String?>(scriptId),
      'prompt': serializer.toJson<String>(prompt),
      'optionsJson': serializer.toJson<OptionMap>(optionsJson),
      'answerKey': serializer.toJson<String>(answerKey),
      'orderIndex': serializer.toJson<int>(orderIndex),
    };
  }

  Question copyWith({
    String? id,
    String? skill,
    String? typeTag,
    String? track,
    int? difficulty,
    Value<String?> passageId = const Value.absent(),
    Value<String?> scriptId = const Value.absent(),
    String? prompt,
    OptionMap? optionsJson,
    String? answerKey,
    int? orderIndex,
  }) => Question(
    id: id ?? this.id,
    skill: skill ?? this.skill,
    typeTag: typeTag ?? this.typeTag,
    track: track ?? this.track,
    difficulty: difficulty ?? this.difficulty,
    passageId: passageId.present ? passageId.value : this.passageId,
    scriptId: scriptId.present ? scriptId.value : this.scriptId,
    prompt: prompt ?? this.prompt,
    optionsJson: optionsJson ?? this.optionsJson,
    answerKey: answerKey ?? this.answerKey,
    orderIndex: orderIndex ?? this.orderIndex,
  );
  Question copyWithCompanion(QuestionsCompanion data) {
    return Question(
      id: data.id.present ? data.id.value : this.id,
      skill: data.skill.present ? data.skill.value : this.skill,
      typeTag: data.typeTag.present ? data.typeTag.value : this.typeTag,
      track: data.track.present ? data.track.value : this.track,
      difficulty: data.difficulty.present
          ? data.difficulty.value
          : this.difficulty,
      passageId: data.passageId.present ? data.passageId.value : this.passageId,
      scriptId: data.scriptId.present ? data.scriptId.value : this.scriptId,
      prompt: data.prompt.present ? data.prompt.value : this.prompt,
      optionsJson: data.optionsJson.present
          ? data.optionsJson.value
          : this.optionsJson,
      answerKey: data.answerKey.present ? data.answerKey.value : this.answerKey,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Question(')
          ..write('id: $id, ')
          ..write('skill: $skill, ')
          ..write('typeTag: $typeTag, ')
          ..write('track: $track, ')
          ..write('difficulty: $difficulty, ')
          ..write('passageId: $passageId, ')
          ..write('scriptId: $scriptId, ')
          ..write('prompt: $prompt, ')
          ..write('optionsJson: $optionsJson, ')
          ..write('answerKey: $answerKey, ')
          ..write('orderIndex: $orderIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    skill,
    typeTag,
    track,
    difficulty,
    passageId,
    scriptId,
    prompt,
    optionsJson,
    answerKey,
    orderIndex,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Question &&
          other.id == this.id &&
          other.skill == this.skill &&
          other.typeTag == this.typeTag &&
          other.track == this.track &&
          other.difficulty == this.difficulty &&
          other.passageId == this.passageId &&
          other.scriptId == this.scriptId &&
          other.prompt == this.prompt &&
          other.optionsJson == this.optionsJson &&
          other.answerKey == this.answerKey &&
          other.orderIndex == this.orderIndex);
}

class QuestionsCompanion extends UpdateCompanion<Question> {
  final Value<String> id;
  final Value<String> skill;
  final Value<String> typeTag;
  final Value<String> track;
  final Value<int> difficulty;
  final Value<String?> passageId;
  final Value<String?> scriptId;
  final Value<String> prompt;
  final Value<OptionMap> optionsJson;
  final Value<String> answerKey;
  final Value<int> orderIndex;
  final Value<int> rowid;
  const QuestionsCompanion({
    this.id = const Value.absent(),
    this.skill = const Value.absent(),
    this.typeTag = const Value.absent(),
    this.track = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.passageId = const Value.absent(),
    this.scriptId = const Value.absent(),
    this.prompt = const Value.absent(),
    this.optionsJson = const Value.absent(),
    this.answerKey = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QuestionsCompanion.insert({
    required String id,
    required String skill,
    required String typeTag,
    required String track,
    required int difficulty,
    this.passageId = const Value.absent(),
    this.scriptId = const Value.absent(),
    required String prompt,
    required OptionMap optionsJson,
    required String answerKey,
    required int orderIndex,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       skill = Value(skill),
       typeTag = Value(typeTag),
       track = Value(track),
       difficulty = Value(difficulty),
       prompt = Value(prompt),
       optionsJson = Value(optionsJson),
       answerKey = Value(answerKey),
       orderIndex = Value(orderIndex);
  static Insertable<Question> custom({
    Expression<String>? id,
    Expression<String>? skill,
    Expression<String>? typeTag,
    Expression<String>? track,
    Expression<int>? difficulty,
    Expression<String>? passageId,
    Expression<String>? scriptId,
    Expression<String>? prompt,
    Expression<String>? optionsJson,
    Expression<String>? answerKey,
    Expression<int>? orderIndex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (skill != null) 'skill': skill,
      if (typeTag != null) 'type_tag': typeTag,
      if (track != null) 'track': track,
      if (difficulty != null) 'difficulty': difficulty,
      if (passageId != null) 'passage_id': passageId,
      if (scriptId != null) 'script_id': scriptId,
      if (prompt != null) 'prompt': prompt,
      if (optionsJson != null) 'options_json': optionsJson,
      if (answerKey != null) 'answer_key': answerKey,
      if (orderIndex != null) 'order_index': orderIndex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QuestionsCompanion copyWith({
    Value<String>? id,
    Value<String>? skill,
    Value<String>? typeTag,
    Value<String>? track,
    Value<int>? difficulty,
    Value<String?>? passageId,
    Value<String?>? scriptId,
    Value<String>? prompt,
    Value<OptionMap>? optionsJson,
    Value<String>? answerKey,
    Value<int>? orderIndex,
    Value<int>? rowid,
  }) {
    return QuestionsCompanion(
      id: id ?? this.id,
      skill: skill ?? this.skill,
      typeTag: typeTag ?? this.typeTag,
      track: track ?? this.track,
      difficulty: difficulty ?? this.difficulty,
      passageId: passageId ?? this.passageId,
      scriptId: scriptId ?? this.scriptId,
      prompt: prompt ?? this.prompt,
      optionsJson: optionsJson ?? this.optionsJson,
      answerKey: answerKey ?? this.answerKey,
      orderIndex: orderIndex ?? this.orderIndex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (skill.present) {
      map['skill'] = Variable<String>(skill.value);
    }
    if (typeTag.present) {
      map['type_tag'] = Variable<String>(typeTag.value);
    }
    if (track.present) {
      map['track'] = Variable<String>(track.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<int>(difficulty.value);
    }
    if (passageId.present) {
      map['passage_id'] = Variable<String>(passageId.value);
    }
    if (scriptId.present) {
      map['script_id'] = Variable<String>(scriptId.value);
    }
    if (prompt.present) {
      map['prompt'] = Variable<String>(prompt.value);
    }
    if (optionsJson.present) {
      map['options_json'] = Variable<String>(
        $QuestionsTable.$converteroptionsJson.toSql(optionsJson.value),
      );
    }
    if (answerKey.present) {
      map['answer_key'] = Variable<String>(answerKey.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuestionsCompanion(')
          ..write('id: $id, ')
          ..write('skill: $skill, ')
          ..write('typeTag: $typeTag, ')
          ..write('track: $track, ')
          ..write('difficulty: $difficulty, ')
          ..write('passageId: $passageId, ')
          ..write('scriptId: $scriptId, ')
          ..write('prompt: $prompt, ')
          ..write('optionsJson: $optionsJson, ')
          ..write('answerKey: $answerKey, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExplanationsTable extends Explanations
    with TableInfo<$ExplanationsTable, Explanation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExplanationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questionIdMeta = const VerificationMeta(
    'questionId',
  );
  @override
  late final GeneratedColumn<String> questionId = GeneratedColumn<String>(
    'question_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES questions (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  evidenceSentenceIdsJson =
      GeneratedColumn<String>(
        'evidence_sentence_ids_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<List<String>>(
        $ExplanationsTable.$converterevidenceSentenceIdsJson,
      );
  static const VerificationMeta _whyCorrectKoMeta = const VerificationMeta(
    'whyCorrectKo',
  );
  @override
  late final GeneratedColumn<String> whyCorrectKo = GeneratedColumn<String>(
    'why_correct_ko',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<OptionMap, String>
  whyWrongKoJson = GeneratedColumn<String>(
    'why_wrong_ko_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<OptionMap>($ExplanationsTable.$converterwhyWrongKoJson);
  static const VerificationMeta _vocabNotesJsonMeta = const VerificationMeta(
    'vocabNotesJson',
  );
  @override
  late final GeneratedColumn<String> vocabNotesJson = GeneratedColumn<String>(
    'vocab_notes_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _structureNotesKoMeta = const VerificationMeta(
    'structureNotesKo',
  );
  @override
  late final GeneratedColumn<String> structureNotesKo = GeneratedColumn<String>(
    'structure_notes_ko',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _glossKoJsonMeta = const VerificationMeta(
    'glossKoJson',
  );
  @override
  late final GeneratedColumn<String> glossKoJson = GeneratedColumn<String>(
    'gloss_ko_json',
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    questionId,
    evidenceSentenceIdsJson,
    whyCorrectKo,
    whyWrongKoJson,
    vocabNotesJson,
    structureNotesKo,
    glossKoJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'explanations';
  @override
  VerificationContext validateIntegrity(
    Insertable<Explanation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('question_id')) {
      context.handle(
        _questionIdMeta,
        questionId.isAcceptableOrUnknown(data['question_id']!, _questionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_questionIdMeta);
    }
    if (data.containsKey('why_correct_ko')) {
      context.handle(
        _whyCorrectKoMeta,
        whyCorrectKo.isAcceptableOrUnknown(
          data['why_correct_ko']!,
          _whyCorrectKoMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_whyCorrectKoMeta);
    }
    if (data.containsKey('vocab_notes_json')) {
      context.handle(
        _vocabNotesJsonMeta,
        vocabNotesJson.isAcceptableOrUnknown(
          data['vocab_notes_json']!,
          _vocabNotesJsonMeta,
        ),
      );
    }
    if (data.containsKey('structure_notes_ko')) {
      context.handle(
        _structureNotesKoMeta,
        structureNotesKo.isAcceptableOrUnknown(
          data['structure_notes_ko']!,
          _structureNotesKoMeta,
        ),
      );
    }
    if (data.containsKey('gloss_ko_json')) {
      context.handle(
        _glossKoJsonMeta,
        glossKoJson.isAcceptableOrUnknown(
          data['gloss_ko_json']!,
          _glossKoJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {questionId},
  ];
  @override
  Explanation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Explanation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      questionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question_id'],
      )!,
      evidenceSentenceIdsJson: $ExplanationsTable
          .$converterevidenceSentenceIdsJson
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}evidence_sentence_ids_json'],
            )!,
          ),
      whyCorrectKo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}why_correct_ko'],
      )!,
      whyWrongKoJson: $ExplanationsTable.$converterwhyWrongKoJson.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}why_wrong_ko_json'],
        )!,
      ),
      vocabNotesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vocab_notes_json'],
      ),
      structureNotesKo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}structure_notes_ko'],
      ),
      glossKoJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gloss_ko_json'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ExplanationsTable createAlias(String alias) {
    return $ExplanationsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $converterevidenceSentenceIdsJson =
      const StringListConverter();
  static TypeConverter<OptionMap, String> $converterwhyWrongKoJson =
      const OptionMapConverter();
}

class Explanation extends DataClass implements Insertable<Explanation> {
  final String id;
  final String questionId;
  final List<String> evidenceSentenceIdsJson;
  final String whyCorrectKo;
  final OptionMap whyWrongKoJson;
  final String? vocabNotesJson;
  final String? structureNotesKo;
  final String? glossKoJson;
  final DateTime createdAt;
  const Explanation({
    required this.id,
    required this.questionId,
    required this.evidenceSentenceIdsJson,
    required this.whyCorrectKo,
    required this.whyWrongKoJson,
    this.vocabNotesJson,
    this.structureNotesKo,
    this.glossKoJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['question_id'] = Variable<String>(questionId);
    {
      map['evidence_sentence_ids_json'] = Variable<String>(
        $ExplanationsTable.$converterevidenceSentenceIdsJson.toSql(
          evidenceSentenceIdsJson,
        ),
      );
    }
    map['why_correct_ko'] = Variable<String>(whyCorrectKo);
    {
      map['why_wrong_ko_json'] = Variable<String>(
        $ExplanationsTable.$converterwhyWrongKoJson.toSql(whyWrongKoJson),
      );
    }
    if (!nullToAbsent || vocabNotesJson != null) {
      map['vocab_notes_json'] = Variable<String>(vocabNotesJson);
    }
    if (!nullToAbsent || structureNotesKo != null) {
      map['structure_notes_ko'] = Variable<String>(structureNotesKo);
    }
    if (!nullToAbsent || glossKoJson != null) {
      map['gloss_ko_json'] = Variable<String>(glossKoJson);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ExplanationsCompanion toCompanion(bool nullToAbsent) {
    return ExplanationsCompanion(
      id: Value(id),
      questionId: Value(questionId),
      evidenceSentenceIdsJson: Value(evidenceSentenceIdsJson),
      whyCorrectKo: Value(whyCorrectKo),
      whyWrongKoJson: Value(whyWrongKoJson),
      vocabNotesJson: vocabNotesJson == null && nullToAbsent
          ? const Value.absent()
          : Value(vocabNotesJson),
      structureNotesKo: structureNotesKo == null && nullToAbsent
          ? const Value.absent()
          : Value(structureNotesKo),
      glossKoJson: glossKoJson == null && nullToAbsent
          ? const Value.absent()
          : Value(glossKoJson),
      createdAt: Value(createdAt),
    );
  }

  factory Explanation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Explanation(
      id: serializer.fromJson<String>(json['id']),
      questionId: serializer.fromJson<String>(json['questionId']),
      evidenceSentenceIdsJson: serializer.fromJson<List<String>>(
        json['evidenceSentenceIdsJson'],
      ),
      whyCorrectKo: serializer.fromJson<String>(json['whyCorrectKo']),
      whyWrongKoJson: serializer.fromJson<OptionMap>(json['whyWrongKoJson']),
      vocabNotesJson: serializer.fromJson<String?>(json['vocabNotesJson']),
      structureNotesKo: serializer.fromJson<String?>(json['structureNotesKo']),
      glossKoJson: serializer.fromJson<String?>(json['glossKoJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'questionId': serializer.toJson<String>(questionId),
      'evidenceSentenceIdsJson': serializer.toJson<List<String>>(
        evidenceSentenceIdsJson,
      ),
      'whyCorrectKo': serializer.toJson<String>(whyCorrectKo),
      'whyWrongKoJson': serializer.toJson<OptionMap>(whyWrongKoJson),
      'vocabNotesJson': serializer.toJson<String?>(vocabNotesJson),
      'structureNotesKo': serializer.toJson<String?>(structureNotesKo),
      'glossKoJson': serializer.toJson<String?>(glossKoJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Explanation copyWith({
    String? id,
    String? questionId,
    List<String>? evidenceSentenceIdsJson,
    String? whyCorrectKo,
    OptionMap? whyWrongKoJson,
    Value<String?> vocabNotesJson = const Value.absent(),
    Value<String?> structureNotesKo = const Value.absent(),
    Value<String?> glossKoJson = const Value.absent(),
    DateTime? createdAt,
  }) => Explanation(
    id: id ?? this.id,
    questionId: questionId ?? this.questionId,
    evidenceSentenceIdsJson:
        evidenceSentenceIdsJson ?? this.evidenceSentenceIdsJson,
    whyCorrectKo: whyCorrectKo ?? this.whyCorrectKo,
    whyWrongKoJson: whyWrongKoJson ?? this.whyWrongKoJson,
    vocabNotesJson: vocabNotesJson.present
        ? vocabNotesJson.value
        : this.vocabNotesJson,
    structureNotesKo: structureNotesKo.present
        ? structureNotesKo.value
        : this.structureNotesKo,
    glossKoJson: glossKoJson.present ? glossKoJson.value : this.glossKoJson,
    createdAt: createdAt ?? this.createdAt,
  );
  Explanation copyWithCompanion(ExplanationsCompanion data) {
    return Explanation(
      id: data.id.present ? data.id.value : this.id,
      questionId: data.questionId.present
          ? data.questionId.value
          : this.questionId,
      evidenceSentenceIdsJson: data.evidenceSentenceIdsJson.present
          ? data.evidenceSentenceIdsJson.value
          : this.evidenceSentenceIdsJson,
      whyCorrectKo: data.whyCorrectKo.present
          ? data.whyCorrectKo.value
          : this.whyCorrectKo,
      whyWrongKoJson: data.whyWrongKoJson.present
          ? data.whyWrongKoJson.value
          : this.whyWrongKoJson,
      vocabNotesJson: data.vocabNotesJson.present
          ? data.vocabNotesJson.value
          : this.vocabNotesJson,
      structureNotesKo: data.structureNotesKo.present
          ? data.structureNotesKo.value
          : this.structureNotesKo,
      glossKoJson: data.glossKoJson.present
          ? data.glossKoJson.value
          : this.glossKoJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Explanation(')
          ..write('id: $id, ')
          ..write('questionId: $questionId, ')
          ..write('evidenceSentenceIdsJson: $evidenceSentenceIdsJson, ')
          ..write('whyCorrectKo: $whyCorrectKo, ')
          ..write('whyWrongKoJson: $whyWrongKoJson, ')
          ..write('vocabNotesJson: $vocabNotesJson, ')
          ..write('structureNotesKo: $structureNotesKo, ')
          ..write('glossKoJson: $glossKoJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    questionId,
    evidenceSentenceIdsJson,
    whyCorrectKo,
    whyWrongKoJson,
    vocabNotesJson,
    structureNotesKo,
    glossKoJson,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Explanation &&
          other.id == this.id &&
          other.questionId == this.questionId &&
          other.evidenceSentenceIdsJson == this.evidenceSentenceIdsJson &&
          other.whyCorrectKo == this.whyCorrectKo &&
          other.whyWrongKoJson == this.whyWrongKoJson &&
          other.vocabNotesJson == this.vocabNotesJson &&
          other.structureNotesKo == this.structureNotesKo &&
          other.glossKoJson == this.glossKoJson &&
          other.createdAt == this.createdAt);
}

class ExplanationsCompanion extends UpdateCompanion<Explanation> {
  final Value<String> id;
  final Value<String> questionId;
  final Value<List<String>> evidenceSentenceIdsJson;
  final Value<String> whyCorrectKo;
  final Value<OptionMap> whyWrongKoJson;
  final Value<String?> vocabNotesJson;
  final Value<String?> structureNotesKo;
  final Value<String?> glossKoJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ExplanationsCompanion({
    this.id = const Value.absent(),
    this.questionId = const Value.absent(),
    this.evidenceSentenceIdsJson = const Value.absent(),
    this.whyCorrectKo = const Value.absent(),
    this.whyWrongKoJson = const Value.absent(),
    this.vocabNotesJson = const Value.absent(),
    this.structureNotesKo = const Value.absent(),
    this.glossKoJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExplanationsCompanion.insert({
    required String id,
    required String questionId,
    required List<String> evidenceSentenceIdsJson,
    required String whyCorrectKo,
    required OptionMap whyWrongKoJson,
    this.vocabNotesJson = const Value.absent(),
    this.structureNotesKo = const Value.absent(),
    this.glossKoJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       questionId = Value(questionId),
       evidenceSentenceIdsJson = Value(evidenceSentenceIdsJson),
       whyCorrectKo = Value(whyCorrectKo),
       whyWrongKoJson = Value(whyWrongKoJson);
  static Insertable<Explanation> custom({
    Expression<String>? id,
    Expression<String>? questionId,
    Expression<String>? evidenceSentenceIdsJson,
    Expression<String>? whyCorrectKo,
    Expression<String>? whyWrongKoJson,
    Expression<String>? vocabNotesJson,
    Expression<String>? structureNotesKo,
    Expression<String>? glossKoJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (questionId != null) 'question_id': questionId,
      if (evidenceSentenceIdsJson != null)
        'evidence_sentence_ids_json': evidenceSentenceIdsJson,
      if (whyCorrectKo != null) 'why_correct_ko': whyCorrectKo,
      if (whyWrongKoJson != null) 'why_wrong_ko_json': whyWrongKoJson,
      if (vocabNotesJson != null) 'vocab_notes_json': vocabNotesJson,
      if (structureNotesKo != null) 'structure_notes_ko': structureNotesKo,
      if (glossKoJson != null) 'gloss_ko_json': glossKoJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExplanationsCompanion copyWith({
    Value<String>? id,
    Value<String>? questionId,
    Value<List<String>>? evidenceSentenceIdsJson,
    Value<String>? whyCorrectKo,
    Value<OptionMap>? whyWrongKoJson,
    Value<String?>? vocabNotesJson,
    Value<String?>? structureNotesKo,
    Value<String?>? glossKoJson,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ExplanationsCompanion(
      id: id ?? this.id,
      questionId: questionId ?? this.questionId,
      evidenceSentenceIdsJson:
          evidenceSentenceIdsJson ?? this.evidenceSentenceIdsJson,
      whyCorrectKo: whyCorrectKo ?? this.whyCorrectKo,
      whyWrongKoJson: whyWrongKoJson ?? this.whyWrongKoJson,
      vocabNotesJson: vocabNotesJson ?? this.vocabNotesJson,
      structureNotesKo: structureNotesKo ?? this.structureNotesKo,
      glossKoJson: glossKoJson ?? this.glossKoJson,
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
    if (questionId.present) {
      map['question_id'] = Variable<String>(questionId.value);
    }
    if (evidenceSentenceIdsJson.present) {
      map['evidence_sentence_ids_json'] = Variable<String>(
        $ExplanationsTable.$converterevidenceSentenceIdsJson.toSql(
          evidenceSentenceIdsJson.value,
        ),
      );
    }
    if (whyCorrectKo.present) {
      map['why_correct_ko'] = Variable<String>(whyCorrectKo.value);
    }
    if (whyWrongKoJson.present) {
      map['why_wrong_ko_json'] = Variable<String>(
        $ExplanationsTable.$converterwhyWrongKoJson.toSql(whyWrongKoJson.value),
      );
    }
    if (vocabNotesJson.present) {
      map['vocab_notes_json'] = Variable<String>(vocabNotesJson.value);
    }
    if (structureNotesKo.present) {
      map['structure_notes_ko'] = Variable<String>(structureNotesKo.value);
    }
    if (glossKoJson.present) {
      map['gloss_ko_json'] = Variable<String>(glossKoJson.value);
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
    return (StringBuffer('ExplanationsCompanion(')
          ..write('id: $id, ')
          ..write('questionId: $questionId, ')
          ..write('evidenceSentenceIdsJson: $evidenceSentenceIdsJson, ')
          ..write('whyCorrectKo: $whyCorrectKo, ')
          ..write('whyWrongKoJson: $whyWrongKoJson, ')
          ..write('vocabNotesJson: $vocabNotesJson, ')
          ..write('structureNotesKo: $structureNotesKo, ')
          ..write('glossKoJson: $glossKoJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DailySessionsTable extends DailySessions
    with TableInfo<$DailySessionsTable, DailySession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailySessionsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _dayKeyMeta = const VerificationMeta('dayKey');
  @override
  late final GeneratedColumn<int> dayKey = GeneratedColumn<int>(
    'day_key',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (day_key BETWEEN 19000101 AND 29991231)',
  );
  static const VerificationMeta _trackMeta = const VerificationMeta('track');
  @override
  late final GeneratedColumn<String> track = GeneratedColumn<String>(
    'track',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 2,
      maxTextLength: 2,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT \'M3\' CHECK (track IN (\'M3\', \'H1\', \'H2\', \'H3\'))',
    defaultValue: const CustomExpression('\'M3\''),
  );
  static const VerificationMeta _plannedItemsMeta = const VerificationMeta(
    'plannedItems',
  );
  @override
  late final GeneratedColumn<int> plannedItems = GeneratedColumn<int>(
    'planned_items',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _completedItemsMeta = const VerificationMeta(
    'completedItems',
  );
  @override
  late final GeneratedColumn<int> completedItems = GeneratedColumn<int>(
    'completed_items',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    dayKey,
    track,
    plannedItems,
    completedItems,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailySession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('day_key')) {
      context.handle(
        _dayKeyMeta,
        dayKey.isAcceptableOrUnknown(data['day_key']!, _dayKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dayKeyMeta);
    }
    if (data.containsKey('track')) {
      context.handle(
        _trackMeta,
        track.isAcceptableOrUnknown(data['track']!, _trackMeta),
      );
    }
    if (data.containsKey('planned_items')) {
      context.handle(
        _plannedItemsMeta,
        plannedItems.isAcceptableOrUnknown(
          data['planned_items']!,
          _plannedItemsMeta,
        ),
      );
    }
    if (data.containsKey('completed_items')) {
      context.handle(
        _completedItemsMeta,
        completedItems.isAcceptableOrUnknown(
          data['completed_items']!,
          _completedItemsMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {dayKey, track},
  ];
  @override
  DailySession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailySession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      dayKey: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_key'],
      )!,
      track: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track'],
      )!,
      plannedItems: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}planned_items'],
      )!,
      completedItems: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_items'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DailySessionsTable createAlias(String alias) {
    return $DailySessionsTable(attachedDatabase, alias);
  }
}

class DailySession extends DataClass implements Insertable<DailySession> {
  final int id;
  final int dayKey;
  final String track;
  final int plannedItems;
  final int completedItems;
  final DateTime createdAt;
  const DailySession({
    required this.id,
    required this.dayKey,
    required this.track,
    required this.plannedItems,
    required this.completedItems,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['day_key'] = Variable<int>(dayKey);
    map['track'] = Variable<String>(track);
    map['planned_items'] = Variable<int>(plannedItems);
    map['completed_items'] = Variable<int>(completedItems);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DailySessionsCompanion toCompanion(bool nullToAbsent) {
    return DailySessionsCompanion(
      id: Value(id),
      dayKey: Value(dayKey),
      track: Value(track),
      plannedItems: Value(plannedItems),
      completedItems: Value(completedItems),
      createdAt: Value(createdAt),
    );
  }

  factory DailySession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailySession(
      id: serializer.fromJson<int>(json['id']),
      dayKey: serializer.fromJson<int>(json['dayKey']),
      track: serializer.fromJson<String>(json['track']),
      plannedItems: serializer.fromJson<int>(json['plannedItems']),
      completedItems: serializer.fromJson<int>(json['completedItems']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'dayKey': serializer.toJson<int>(dayKey),
      'track': serializer.toJson<String>(track),
      'plannedItems': serializer.toJson<int>(plannedItems),
      'completedItems': serializer.toJson<int>(completedItems),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DailySession copyWith({
    int? id,
    int? dayKey,
    String? track,
    int? plannedItems,
    int? completedItems,
    DateTime? createdAt,
  }) => DailySession(
    id: id ?? this.id,
    dayKey: dayKey ?? this.dayKey,
    track: track ?? this.track,
    plannedItems: plannedItems ?? this.plannedItems,
    completedItems: completedItems ?? this.completedItems,
    createdAt: createdAt ?? this.createdAt,
  );
  DailySession copyWithCompanion(DailySessionsCompanion data) {
    return DailySession(
      id: data.id.present ? data.id.value : this.id,
      dayKey: data.dayKey.present ? data.dayKey.value : this.dayKey,
      track: data.track.present ? data.track.value : this.track,
      plannedItems: data.plannedItems.present
          ? data.plannedItems.value
          : this.plannedItems,
      completedItems: data.completedItems.present
          ? data.completedItems.value
          : this.completedItems,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailySession(')
          ..write('id: $id, ')
          ..write('dayKey: $dayKey, ')
          ..write('track: $track, ')
          ..write('plannedItems: $plannedItems, ')
          ..write('completedItems: $completedItems, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, dayKey, track, plannedItems, completedItems, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailySession &&
          other.id == this.id &&
          other.dayKey == this.dayKey &&
          other.track == this.track &&
          other.plannedItems == this.plannedItems &&
          other.completedItems == this.completedItems &&
          other.createdAt == this.createdAt);
}

class DailySessionsCompanion extends UpdateCompanion<DailySession> {
  final Value<int> id;
  final Value<int> dayKey;
  final Value<String> track;
  final Value<int> plannedItems;
  final Value<int> completedItems;
  final Value<DateTime> createdAt;
  const DailySessionsCompanion({
    this.id = const Value.absent(),
    this.dayKey = const Value.absent(),
    this.track = const Value.absent(),
    this.plannedItems = const Value.absent(),
    this.completedItems = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  DailySessionsCompanion.insert({
    this.id = const Value.absent(),
    required int dayKey,
    this.track = const Value.absent(),
    this.plannedItems = const Value.absent(),
    this.completedItems = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : dayKey = Value(dayKey);
  static Insertable<DailySession> custom({
    Expression<int>? id,
    Expression<int>? dayKey,
    Expression<String>? track,
    Expression<int>? plannedItems,
    Expression<int>? completedItems,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dayKey != null) 'day_key': dayKey,
      if (track != null) 'track': track,
      if (plannedItems != null) 'planned_items': plannedItems,
      if (completedItems != null) 'completed_items': completedItems,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  DailySessionsCompanion copyWith({
    Value<int>? id,
    Value<int>? dayKey,
    Value<String>? track,
    Value<int>? plannedItems,
    Value<int>? completedItems,
    Value<DateTime>? createdAt,
  }) {
    return DailySessionsCompanion(
      id: id ?? this.id,
      dayKey: dayKey ?? this.dayKey,
      track: track ?? this.track,
      plannedItems: plannedItems ?? this.plannedItems,
      completedItems: completedItems ?? this.completedItems,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (dayKey.present) {
      map['day_key'] = Variable<int>(dayKey.value);
    }
    if (track.present) {
      map['track'] = Variable<String>(track.value);
    }
    if (plannedItems.present) {
      map['planned_items'] = Variable<int>(plannedItems.value);
    }
    if (completedItems.present) {
      map['completed_items'] = Variable<int>(completedItems.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailySessionsCompanion(')
          ..write('id: $id, ')
          ..write('dayKey: $dayKey, ')
          ..write('track: $track, ')
          ..write('plannedItems: $plannedItems, ')
          ..write('completedItems: $completedItems, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $DailySessionItemsTable extends DailySessionItems
    with TableInfo<$DailySessionItemsTable, DailySessionItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailySessionItemsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES daily_sessions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (order_index BETWEEN 0 AND 5)',
  );
  static const VerificationMeta _questionIdMeta = const VerificationMeta(
    'questionId',
  );
  @override
  late final GeneratedColumn<String> questionId = GeneratedColumn<String>(
    'question_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES questions (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [id, sessionId, orderIndex, questionId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_session_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailySessionItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    if (data.containsKey('question_id')) {
      context.handle(
        _questionIdMeta,
        questionId.isAcceptableOrUnknown(data['question_id']!, _questionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_questionIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {sessionId, orderIndex},
    {sessionId, questionId},
  ];
  @override
  DailySessionItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailySessionItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_id'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      questionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question_id'],
      )!,
    );
  }

  @override
  $DailySessionItemsTable createAlias(String alias) {
    return $DailySessionItemsTable(attachedDatabase, alias);
  }
}

class DailySessionItem extends DataClass
    implements Insertable<DailySessionItem> {
  final int id;
  final int sessionId;
  final int orderIndex;
  final String questionId;
  const DailySessionItem({
    required this.id,
    required this.sessionId,
    required this.orderIndex,
    required this.questionId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<int>(sessionId);
    map['order_index'] = Variable<int>(orderIndex);
    map['question_id'] = Variable<String>(questionId);
    return map;
  }

  DailySessionItemsCompanion toCompanion(bool nullToAbsent) {
    return DailySessionItemsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      orderIndex: Value(orderIndex),
      questionId: Value(questionId),
    );
  }

  factory DailySessionItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailySessionItem(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<int>(json['sessionId']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      questionId: serializer.fromJson<String>(json['questionId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<int>(sessionId),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'questionId': serializer.toJson<String>(questionId),
    };
  }

  DailySessionItem copyWith({
    int? id,
    int? sessionId,
    int? orderIndex,
    String? questionId,
  }) => DailySessionItem(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    orderIndex: orderIndex ?? this.orderIndex,
    questionId: questionId ?? this.questionId,
  );
  DailySessionItem copyWithCompanion(DailySessionItemsCompanion data) {
    return DailySessionItem(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      questionId: data.questionId.present
          ? data.questionId.value
          : this.questionId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailySessionItem(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('questionId: $questionId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sessionId, orderIndex, questionId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailySessionItem &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.orderIndex == this.orderIndex &&
          other.questionId == this.questionId);
}

class DailySessionItemsCompanion extends UpdateCompanion<DailySessionItem> {
  final Value<int> id;
  final Value<int> sessionId;
  final Value<int> orderIndex;
  final Value<String> questionId;
  const DailySessionItemsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.questionId = const Value.absent(),
  });
  DailySessionItemsCompanion.insert({
    this.id = const Value.absent(),
    required int sessionId,
    required int orderIndex,
    required String questionId,
  }) : sessionId = Value(sessionId),
       orderIndex = Value(orderIndex),
       questionId = Value(questionId);
  static Insertable<DailySessionItem> custom({
    Expression<int>? id,
    Expression<int>? sessionId,
    Expression<int>? orderIndex,
    Expression<String>? questionId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (orderIndex != null) 'order_index': orderIndex,
      if (questionId != null) 'question_id': questionId,
    });
  }

  DailySessionItemsCompanion copyWith({
    Value<int>? id,
    Value<int>? sessionId,
    Value<int>? orderIndex,
    Value<String>? questionId,
  }) {
    return DailySessionItemsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      orderIndex: orderIndex ?? this.orderIndex,
      questionId: questionId ?? this.questionId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (questionId.present) {
      map['question_id'] = Variable<String>(questionId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailySessionItemsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('questionId: $questionId')
          ..write(')'))
        .toString();
  }
}

class $UserSettingsTable extends UserSettings
    with TableInfo<$UserSettingsTable, UserSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT \'STUDENT\' CHECK (role IN (\'STUDENT\', \'PARENT\'))',
    defaultValue: const CustomExpression('\'STUDENT\''),
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 0),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _birthDateMeta = const VerificationMeta(
    'birthDate',
  );
  @override
  late final GeneratedColumn<String> birthDate = GeneratedColumn<String>(
    'birth_date',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 0,
      maxTextLength: 10,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT \'\' CHECK (birth_date = \'\' OR birth_date GLOB \'[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\')',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _trackMeta = const VerificationMeta('track');
  @override
  late final GeneratedColumn<String> track = GeneratedColumn<String>(
    'track',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT \'M3\' CHECK (track IN (\'M3\', \'H1\', \'H2\', \'H3\'))',
    defaultValue: const CustomExpression('\'M3\''),
  );
  static const VerificationMeta _notificationsEnabledMeta =
      const VerificationMeta('notificationsEnabled');
  @override
  late final GeneratedColumn<bool> notificationsEnabled = GeneratedColumn<bool>(
    'notifications_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("notifications_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _studyReminderEnabledMeta =
      const VerificationMeta('studyReminderEnabled');
  @override
  late final GeneratedColumn<bool> studyReminderEnabled = GeneratedColumn<bool>(
    'study_reminder_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("study_reminder_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    role,
    displayName,
    birthDate,
    track,
    notificationsEnabled,
    studyReminderEnabled,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('birth_date')) {
      context.handle(
        _birthDateMeta,
        birthDate.isAcceptableOrUnknown(data['birth_date']!, _birthDateMeta),
      );
    }
    if (data.containsKey('track')) {
      context.handle(
        _trackMeta,
        track.isAcceptableOrUnknown(data['track']!, _trackMeta),
      );
    }
    if (data.containsKey('notifications_enabled')) {
      context.handle(
        _notificationsEnabledMeta,
        notificationsEnabled.isAcceptableOrUnknown(
          data['notifications_enabled']!,
          _notificationsEnabledMeta,
        ),
      );
    }
    if (data.containsKey('study_reminder_enabled')) {
      context.handle(
        _studyReminderEnabledMeta,
        studyReminderEnabled.isAcceptableOrUnknown(
          data['study_reminder_enabled']!,
          _studyReminderEnabledMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserSetting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      birthDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}birth_date'],
      )!,
      track: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track'],
      )!,
      notificationsEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}notifications_enabled'],
      )!,
      studyReminderEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}study_reminder_enabled'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $UserSettingsTable createAlias(String alias) {
    return $UserSettingsTable(attachedDatabase, alias);
  }
}

class UserSetting extends DataClass implements Insertable<UserSetting> {
  final int id;
  final String role;
  final String displayName;
  final String birthDate;
  final String track;
  final bool notificationsEnabled;
  final bool studyReminderEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  const UserSetting({
    required this.id,
    required this.role,
    required this.displayName,
    required this.birthDate,
    required this.track,
    required this.notificationsEnabled,
    required this.studyReminderEnabled,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['role'] = Variable<String>(role);
    map['display_name'] = Variable<String>(displayName);
    map['birth_date'] = Variable<String>(birthDate);
    map['track'] = Variable<String>(track);
    map['notifications_enabled'] = Variable<bool>(notificationsEnabled);
    map['study_reminder_enabled'] = Variable<bool>(studyReminderEnabled);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UserSettingsCompanion toCompanion(bool nullToAbsent) {
    return UserSettingsCompanion(
      id: Value(id),
      role: Value(role),
      displayName: Value(displayName),
      birthDate: Value(birthDate),
      track: Value(track),
      notificationsEnabled: Value(notificationsEnabled),
      studyReminderEnabled: Value(studyReminderEnabled),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserSetting(
      id: serializer.fromJson<int>(json['id']),
      role: serializer.fromJson<String>(json['role']),
      displayName: serializer.fromJson<String>(json['displayName']),
      birthDate: serializer.fromJson<String>(json['birthDate']),
      track: serializer.fromJson<String>(json['track']),
      notificationsEnabled: serializer.fromJson<bool>(
        json['notificationsEnabled'],
      ),
      studyReminderEnabled: serializer.fromJson<bool>(
        json['studyReminderEnabled'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'role': serializer.toJson<String>(role),
      'displayName': serializer.toJson<String>(displayName),
      'birthDate': serializer.toJson<String>(birthDate),
      'track': serializer.toJson<String>(track),
      'notificationsEnabled': serializer.toJson<bool>(notificationsEnabled),
      'studyReminderEnabled': serializer.toJson<bool>(studyReminderEnabled),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserSetting copyWith({
    int? id,
    String? role,
    String? displayName,
    String? birthDate,
    String? track,
    bool? notificationsEnabled,
    bool? studyReminderEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => UserSetting(
    id: id ?? this.id,
    role: role ?? this.role,
    displayName: displayName ?? this.displayName,
    birthDate: birthDate ?? this.birthDate,
    track: track ?? this.track,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    studyReminderEnabled: studyReminderEnabled ?? this.studyReminderEnabled,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UserSetting copyWithCompanion(UserSettingsCompanion data) {
    return UserSetting(
      id: data.id.present ? data.id.value : this.id,
      role: data.role.present ? data.role.value : this.role,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      birthDate: data.birthDate.present ? data.birthDate.value : this.birthDate,
      track: data.track.present ? data.track.value : this.track,
      notificationsEnabled: data.notificationsEnabled.present
          ? data.notificationsEnabled.value
          : this.notificationsEnabled,
      studyReminderEnabled: data.studyReminderEnabled.present
          ? data.studyReminderEnabled.value
          : this.studyReminderEnabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserSetting(')
          ..write('id: $id, ')
          ..write('role: $role, ')
          ..write('displayName: $displayName, ')
          ..write('birthDate: $birthDate, ')
          ..write('track: $track, ')
          ..write('notificationsEnabled: $notificationsEnabled, ')
          ..write('studyReminderEnabled: $studyReminderEnabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    role,
    displayName,
    birthDate,
    track,
    notificationsEnabled,
    studyReminderEnabled,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserSetting &&
          other.id == this.id &&
          other.role == this.role &&
          other.displayName == this.displayName &&
          other.birthDate == this.birthDate &&
          other.track == this.track &&
          other.notificationsEnabled == this.notificationsEnabled &&
          other.studyReminderEnabled == this.studyReminderEnabled &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class UserSettingsCompanion extends UpdateCompanion<UserSetting> {
  final Value<int> id;
  final Value<String> role;
  final Value<String> displayName;
  final Value<String> birthDate;
  final Value<String> track;
  final Value<bool> notificationsEnabled;
  final Value<bool> studyReminderEnabled;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const UserSettingsCompanion({
    this.id = const Value.absent(),
    this.role = const Value.absent(),
    this.displayName = const Value.absent(),
    this.birthDate = const Value.absent(),
    this.track = const Value.absent(),
    this.notificationsEnabled = const Value.absent(),
    this.studyReminderEnabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  UserSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.role = const Value.absent(),
    this.displayName = const Value.absent(),
    this.birthDate = const Value.absent(),
    this.track = const Value.absent(),
    this.notificationsEnabled = const Value.absent(),
    this.studyReminderEnabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  static Insertable<UserSetting> custom({
    Expression<int>? id,
    Expression<String>? role,
    Expression<String>? displayName,
    Expression<String>? birthDate,
    Expression<String>? track,
    Expression<bool>? notificationsEnabled,
    Expression<bool>? studyReminderEnabled,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (role != null) 'role': role,
      if (displayName != null) 'display_name': displayName,
      if (birthDate != null) 'birth_date': birthDate,
      if (track != null) 'track': track,
      if (notificationsEnabled != null)
        'notifications_enabled': notificationsEnabled,
      if (studyReminderEnabled != null)
        'study_reminder_enabled': studyReminderEnabled,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  UserSettingsCompanion copyWith({
    Value<int>? id,
    Value<String>? role,
    Value<String>? displayName,
    Value<String>? birthDate,
    Value<String>? track,
    Value<bool>? notificationsEnabled,
    Value<bool>? studyReminderEnabled,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return UserSettingsCompanion(
      id: id ?? this.id,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      birthDate: birthDate ?? this.birthDate,
      track: track ?? this.track,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      studyReminderEnabled: studyReminderEnabled ?? this.studyReminderEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (birthDate.present) {
      map['birth_date'] = Variable<String>(birthDate.value);
    }
    if (track.present) {
      map['track'] = Variable<String>(track.value);
    }
    if (notificationsEnabled.present) {
      map['notifications_enabled'] = Variable<bool>(notificationsEnabled.value);
    }
    if (studyReminderEnabled.present) {
      map['study_reminder_enabled'] = Variable<bool>(
        studyReminderEnabled.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserSettingsCompanion(')
          ..write('id: $id, ')
          ..write('role: $role, ')
          ..write('displayName: $displayName, ')
          ..write('birthDate: $birthDate, ')
          ..write('track: $track, ')
          ..write('notificationsEnabled: $notificationsEnabled, ')
          ..write('studyReminderEnabled: $studyReminderEnabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $SharedReportsTable extends SharedReports
    with TableInfo<$SharedReportsTable, SharedReport> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SharedReportsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 2),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, source, payloadJson, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shared_reports';
  @override
  VerificationContext validateIntegrity(
    Insertable<SharedReport> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SharedReport map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SharedReport(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SharedReportsTable createAlias(String alias) {
    return $SharedReportsTable(attachedDatabase, alias);
  }
}

class SharedReport extends DataClass implements Insertable<SharedReport> {
  final int id;
  final String source;
  final String payloadJson;
  final DateTime createdAt;
  const SharedReport({
    required this.id,
    required this.source,
    required this.payloadJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source'] = Variable<String>(source);
    map['payload_json'] = Variable<String>(payloadJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SharedReportsCompanion toCompanion(bool nullToAbsent) {
    return SharedReportsCompanion(
      id: Value(id),
      source: Value(source),
      payloadJson: Value(payloadJson),
      createdAt: Value(createdAt),
    );
  }

  factory SharedReport.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SharedReport(
      id: serializer.fromJson<int>(json['id']),
      source: serializer.fromJson<String>(json['source']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'source': serializer.toJson<String>(source),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SharedReport copyWith({
    int? id,
    String? source,
    String? payloadJson,
    DateTime? createdAt,
  }) => SharedReport(
    id: id ?? this.id,
    source: source ?? this.source,
    payloadJson: payloadJson ?? this.payloadJson,
    createdAt: createdAt ?? this.createdAt,
  );
  SharedReport copyWithCompanion(SharedReportsCompanion data) {
    return SharedReport(
      id: data.id.present ? data.id.value : this.id,
      source: data.source.present ? data.source.value : this.source,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SharedReport(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, source, payloadJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SharedReport &&
          other.id == this.id &&
          other.source == this.source &&
          other.payloadJson == this.payloadJson &&
          other.createdAt == this.createdAt);
}

class SharedReportsCompanion extends UpdateCompanion<SharedReport> {
  final Value<int> id;
  final Value<String> source;
  final Value<String> payloadJson;
  final Value<DateTime> createdAt;
  const SharedReportsCompanion({
    this.id = const Value.absent(),
    this.source = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SharedReportsCompanion.insert({
    this.id = const Value.absent(),
    required String source,
    required String payloadJson,
    this.createdAt = const Value.absent(),
  }) : source = Value(source),
       payloadJson = Value(payloadJson);
  static Insertable<SharedReport> custom({
    Expression<int>? id,
    Expression<String>? source,
    Expression<String>? payloadJson,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (source != null) 'source': source,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SharedReportsCompanion copyWith({
    Value<int>? id,
    Value<String>? source,
    Value<String>? payloadJson,
    Value<DateTime>? createdAt,
  }) {
    return SharedReportsCompanion(
      id: id ?? this.id,
      source: source ?? this.source,
      payloadJson: payloadJson ?? this.payloadJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SharedReportsCompanion(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AttemptsTable extends Attempts with TableInfo<$AttemptsTable, Attempt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttemptsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _questionIdMeta = const VerificationMeta(
    'questionId',
  );
  @override
  late final GeneratedColumn<String> questionId = GeneratedColumn<String>(
    'question_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES questions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
    'session_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES daily_sessions (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _userAnswerJsonMeta = const VerificationMeta(
    'userAnswerJson',
  );
  @override
  late final GeneratedColumn<String> userAnswerJson = GeneratedColumn<String>(
    'user_answer_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isCorrectMeta = const VerificationMeta(
    'isCorrect',
  );
  @override
  late final GeneratedColumn<bool> isCorrect = GeneratedColumn<bool>(
    'is_correct',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_correct" IN (0, 1))',
    ),
  );
  static const VerificationMeta _responseTimeMsMeta = const VerificationMeta(
    'responseTimeMs',
  );
  @override
  late final GeneratedColumn<int> responseTimeMs = GeneratedColumn<int>(
    'response_time_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attemptedAtMeta = const VerificationMeta(
    'attemptedAt',
  );
  @override
  late final GeneratedColumn<DateTime> attemptedAt = GeneratedColumn<DateTime>(
    'attempted_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    questionId,
    sessionId,
    userAnswerJson,
    isCorrect,
    responseTimeMs,
    attemptedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attempts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Attempt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('question_id')) {
      context.handle(
        _questionIdMeta,
        questionId.isAcceptableOrUnknown(data['question_id']!, _questionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_questionIdMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    }
    if (data.containsKey('user_answer_json')) {
      context.handle(
        _userAnswerJsonMeta,
        userAnswerJson.isAcceptableOrUnknown(
          data['user_answer_json']!,
          _userAnswerJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_userAnswerJsonMeta);
    }
    if (data.containsKey('is_correct')) {
      context.handle(
        _isCorrectMeta,
        isCorrect.isAcceptableOrUnknown(data['is_correct']!, _isCorrectMeta),
      );
    } else if (isInserting) {
      context.missing(_isCorrectMeta);
    }
    if (data.containsKey('response_time_ms')) {
      context.handle(
        _responseTimeMsMeta,
        responseTimeMs.isAcceptableOrUnknown(
          data['response_time_ms']!,
          _responseTimeMsMeta,
        ),
      );
    }
    if (data.containsKey('attempted_at')) {
      context.handle(
        _attemptedAtMeta,
        attemptedAt.isAcceptableOrUnknown(
          data['attempted_at']!,
          _attemptedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Attempt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Attempt(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      questionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question_id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_id'],
      ),
      userAnswerJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_answer_json'],
      )!,
      isCorrect: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_correct'],
      )!,
      responseTimeMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}response_time_ms'],
      ),
      attemptedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}attempted_at'],
      )!,
    );
  }

  @override
  $AttemptsTable createAlias(String alias) {
    return $AttemptsTable(attachedDatabase, alias);
  }
}

class Attempt extends DataClass implements Insertable<Attempt> {
  final int id;
  final String questionId;
  final int? sessionId;
  final String userAnswerJson;
  final bool isCorrect;
  final int? responseTimeMs;
  final DateTime attemptedAt;
  const Attempt({
    required this.id,
    required this.questionId,
    this.sessionId,
    required this.userAnswerJson,
    required this.isCorrect,
    this.responseTimeMs,
    required this.attemptedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['question_id'] = Variable<String>(questionId);
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<int>(sessionId);
    }
    map['user_answer_json'] = Variable<String>(userAnswerJson);
    map['is_correct'] = Variable<bool>(isCorrect);
    if (!nullToAbsent || responseTimeMs != null) {
      map['response_time_ms'] = Variable<int>(responseTimeMs);
    }
    map['attempted_at'] = Variable<DateTime>(attemptedAt);
    return map;
  }

  AttemptsCompanion toCompanion(bool nullToAbsent) {
    return AttemptsCompanion(
      id: Value(id),
      questionId: Value(questionId),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      userAnswerJson: Value(userAnswerJson),
      isCorrect: Value(isCorrect),
      responseTimeMs: responseTimeMs == null && nullToAbsent
          ? const Value.absent()
          : Value(responseTimeMs),
      attemptedAt: Value(attemptedAt),
    );
  }

  factory Attempt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Attempt(
      id: serializer.fromJson<int>(json['id']),
      questionId: serializer.fromJson<String>(json['questionId']),
      sessionId: serializer.fromJson<int?>(json['sessionId']),
      userAnswerJson: serializer.fromJson<String>(json['userAnswerJson']),
      isCorrect: serializer.fromJson<bool>(json['isCorrect']),
      responseTimeMs: serializer.fromJson<int?>(json['responseTimeMs']),
      attemptedAt: serializer.fromJson<DateTime>(json['attemptedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'questionId': serializer.toJson<String>(questionId),
      'sessionId': serializer.toJson<int?>(sessionId),
      'userAnswerJson': serializer.toJson<String>(userAnswerJson),
      'isCorrect': serializer.toJson<bool>(isCorrect),
      'responseTimeMs': serializer.toJson<int?>(responseTimeMs),
      'attemptedAt': serializer.toJson<DateTime>(attemptedAt),
    };
  }

  Attempt copyWith({
    int? id,
    String? questionId,
    Value<int?> sessionId = const Value.absent(),
    String? userAnswerJson,
    bool? isCorrect,
    Value<int?> responseTimeMs = const Value.absent(),
    DateTime? attemptedAt,
  }) => Attempt(
    id: id ?? this.id,
    questionId: questionId ?? this.questionId,
    sessionId: sessionId.present ? sessionId.value : this.sessionId,
    userAnswerJson: userAnswerJson ?? this.userAnswerJson,
    isCorrect: isCorrect ?? this.isCorrect,
    responseTimeMs: responseTimeMs.present
        ? responseTimeMs.value
        : this.responseTimeMs,
    attemptedAt: attemptedAt ?? this.attemptedAt,
  );
  Attempt copyWithCompanion(AttemptsCompanion data) {
    return Attempt(
      id: data.id.present ? data.id.value : this.id,
      questionId: data.questionId.present
          ? data.questionId.value
          : this.questionId,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      userAnswerJson: data.userAnswerJson.present
          ? data.userAnswerJson.value
          : this.userAnswerJson,
      isCorrect: data.isCorrect.present ? data.isCorrect.value : this.isCorrect,
      responseTimeMs: data.responseTimeMs.present
          ? data.responseTimeMs.value
          : this.responseTimeMs,
      attemptedAt: data.attemptedAt.present
          ? data.attemptedAt.value
          : this.attemptedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Attempt(')
          ..write('id: $id, ')
          ..write('questionId: $questionId, ')
          ..write('sessionId: $sessionId, ')
          ..write('userAnswerJson: $userAnswerJson, ')
          ..write('isCorrect: $isCorrect, ')
          ..write('responseTimeMs: $responseTimeMs, ')
          ..write('attemptedAt: $attemptedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    questionId,
    sessionId,
    userAnswerJson,
    isCorrect,
    responseTimeMs,
    attemptedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Attempt &&
          other.id == this.id &&
          other.questionId == this.questionId &&
          other.sessionId == this.sessionId &&
          other.userAnswerJson == this.userAnswerJson &&
          other.isCorrect == this.isCorrect &&
          other.responseTimeMs == this.responseTimeMs &&
          other.attemptedAt == this.attemptedAt);
}

class AttemptsCompanion extends UpdateCompanion<Attempt> {
  final Value<int> id;
  final Value<String> questionId;
  final Value<int?> sessionId;
  final Value<String> userAnswerJson;
  final Value<bool> isCorrect;
  final Value<int?> responseTimeMs;
  final Value<DateTime> attemptedAt;
  const AttemptsCompanion({
    this.id = const Value.absent(),
    this.questionId = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.userAnswerJson = const Value.absent(),
    this.isCorrect = const Value.absent(),
    this.responseTimeMs = const Value.absent(),
    this.attemptedAt = const Value.absent(),
  });
  AttemptsCompanion.insert({
    this.id = const Value.absent(),
    required String questionId,
    this.sessionId = const Value.absent(),
    required String userAnswerJson,
    required bool isCorrect,
    this.responseTimeMs = const Value.absent(),
    this.attemptedAt = const Value.absent(),
  }) : questionId = Value(questionId),
       userAnswerJson = Value(userAnswerJson),
       isCorrect = Value(isCorrect);
  static Insertable<Attempt> custom({
    Expression<int>? id,
    Expression<String>? questionId,
    Expression<int>? sessionId,
    Expression<String>? userAnswerJson,
    Expression<bool>? isCorrect,
    Expression<int>? responseTimeMs,
    Expression<DateTime>? attemptedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (questionId != null) 'question_id': questionId,
      if (sessionId != null) 'session_id': sessionId,
      if (userAnswerJson != null) 'user_answer_json': userAnswerJson,
      if (isCorrect != null) 'is_correct': isCorrect,
      if (responseTimeMs != null) 'response_time_ms': responseTimeMs,
      if (attemptedAt != null) 'attempted_at': attemptedAt,
    });
  }

  AttemptsCompanion copyWith({
    Value<int>? id,
    Value<String>? questionId,
    Value<int?>? sessionId,
    Value<String>? userAnswerJson,
    Value<bool>? isCorrect,
    Value<int?>? responseTimeMs,
    Value<DateTime>? attemptedAt,
  }) {
    return AttemptsCompanion(
      id: id ?? this.id,
      questionId: questionId ?? this.questionId,
      sessionId: sessionId ?? this.sessionId,
      userAnswerJson: userAnswerJson ?? this.userAnswerJson,
      isCorrect: isCorrect ?? this.isCorrect,
      responseTimeMs: responseTimeMs ?? this.responseTimeMs,
      attemptedAt: attemptedAt ?? this.attemptedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (questionId.present) {
      map['question_id'] = Variable<String>(questionId.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (userAnswerJson.present) {
      map['user_answer_json'] = Variable<String>(userAnswerJson.value);
    }
    if (isCorrect.present) {
      map['is_correct'] = Variable<bool>(isCorrect.value);
    }
    if (responseTimeMs.present) {
      map['response_time_ms'] = Variable<int>(responseTimeMs.value);
    }
    if (attemptedAt.present) {
      map['attempted_at'] = Variable<DateTime>(attemptedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttemptsCompanion(')
          ..write('id: $id, ')
          ..write('questionId: $questionId, ')
          ..write('sessionId: $sessionId, ')
          ..write('userAnswerJson: $userAnswerJson, ')
          ..write('isCorrect: $isCorrect, ')
          ..write('responseTimeMs: $responseTimeMs, ')
          ..write('attemptedAt: $attemptedAt')
          ..write(')'))
        .toString();
  }
}

class $VocabMasterTable extends VocabMaster
    with TableInfo<$VocabMasterTable, VocabMasterData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VocabMasterTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lemmaMeta = const VerificationMeta('lemma');
  @override
  late final GeneratedColumn<String> lemma = GeneratedColumn<String>(
    'lemma',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _posMeta = const VerificationMeta('pos');
  @override
  late final GeneratedColumn<String> pos = GeneratedColumn<String>(
    'pos',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _meaningMeta = const VerificationMeta(
    'meaning',
  );
  @override
  late final GeneratedColumn<String> meaning = GeneratedColumn<String>(
    'meaning',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exampleMeta = const VerificationMeta(
    'example',
  );
  @override
  late final GeneratedColumn<String> example = GeneratedColumn<String>(
    'example',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ipaMeta = const VerificationMeta('ipa');
  @override
  late final GeneratedColumn<String> ipa = GeneratedColumn<String>(
    'ipa',
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    lemma,
    pos,
    meaning,
    example,
    ipa,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vocab_master';
  @override
  VerificationContext validateIntegrity(
    Insertable<VocabMasterData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('lemma')) {
      context.handle(
        _lemmaMeta,
        lemma.isAcceptableOrUnknown(data['lemma']!, _lemmaMeta),
      );
    } else if (isInserting) {
      context.missing(_lemmaMeta);
    }
    if (data.containsKey('pos')) {
      context.handle(
        _posMeta,
        pos.isAcceptableOrUnknown(data['pos']!, _posMeta),
      );
    }
    if (data.containsKey('meaning')) {
      context.handle(
        _meaningMeta,
        meaning.isAcceptableOrUnknown(data['meaning']!, _meaningMeta),
      );
    } else if (isInserting) {
      context.missing(_meaningMeta);
    }
    if (data.containsKey('example')) {
      context.handle(
        _exampleMeta,
        example.isAcceptableOrUnknown(data['example']!, _exampleMeta),
      );
    }
    if (data.containsKey('ipa')) {
      context.handle(
        _ipaMeta,
        ipa.isAcceptableOrUnknown(data['ipa']!, _ipaMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VocabMasterData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VocabMasterData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      lemma: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lemma'],
      )!,
      pos: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pos'],
      ),
      meaning: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meaning'],
      )!,
      example: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}example'],
      ),
      ipa: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ipa'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $VocabMasterTable createAlias(String alias) {
    return $VocabMasterTable(attachedDatabase, alias);
  }
}

class VocabMasterData extends DataClass implements Insertable<VocabMasterData> {
  final String id;
  final String lemma;
  final String? pos;
  final String meaning;
  final String? example;
  final String? ipa;
  final DateTime createdAt;
  const VocabMasterData({
    required this.id,
    required this.lemma,
    this.pos,
    required this.meaning,
    this.example,
    this.ipa,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['lemma'] = Variable<String>(lemma);
    if (!nullToAbsent || pos != null) {
      map['pos'] = Variable<String>(pos);
    }
    map['meaning'] = Variable<String>(meaning);
    if (!nullToAbsent || example != null) {
      map['example'] = Variable<String>(example);
    }
    if (!nullToAbsent || ipa != null) {
      map['ipa'] = Variable<String>(ipa);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  VocabMasterCompanion toCompanion(bool nullToAbsent) {
    return VocabMasterCompanion(
      id: Value(id),
      lemma: Value(lemma),
      pos: pos == null && nullToAbsent ? const Value.absent() : Value(pos),
      meaning: Value(meaning),
      example: example == null && nullToAbsent
          ? const Value.absent()
          : Value(example),
      ipa: ipa == null && nullToAbsent ? const Value.absent() : Value(ipa),
      createdAt: Value(createdAt),
    );
  }

  factory VocabMasterData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VocabMasterData(
      id: serializer.fromJson<String>(json['id']),
      lemma: serializer.fromJson<String>(json['lemma']),
      pos: serializer.fromJson<String?>(json['pos']),
      meaning: serializer.fromJson<String>(json['meaning']),
      example: serializer.fromJson<String?>(json['example']),
      ipa: serializer.fromJson<String?>(json['ipa']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'lemma': serializer.toJson<String>(lemma),
      'pos': serializer.toJson<String?>(pos),
      'meaning': serializer.toJson<String>(meaning),
      'example': serializer.toJson<String?>(example),
      'ipa': serializer.toJson<String?>(ipa),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  VocabMasterData copyWith({
    String? id,
    String? lemma,
    Value<String?> pos = const Value.absent(),
    String? meaning,
    Value<String?> example = const Value.absent(),
    Value<String?> ipa = const Value.absent(),
    DateTime? createdAt,
  }) => VocabMasterData(
    id: id ?? this.id,
    lemma: lemma ?? this.lemma,
    pos: pos.present ? pos.value : this.pos,
    meaning: meaning ?? this.meaning,
    example: example.present ? example.value : this.example,
    ipa: ipa.present ? ipa.value : this.ipa,
    createdAt: createdAt ?? this.createdAt,
  );
  VocabMasterData copyWithCompanion(VocabMasterCompanion data) {
    return VocabMasterData(
      id: data.id.present ? data.id.value : this.id,
      lemma: data.lemma.present ? data.lemma.value : this.lemma,
      pos: data.pos.present ? data.pos.value : this.pos,
      meaning: data.meaning.present ? data.meaning.value : this.meaning,
      example: data.example.present ? data.example.value : this.example,
      ipa: data.ipa.present ? data.ipa.value : this.ipa,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VocabMasterData(')
          ..write('id: $id, ')
          ..write('lemma: $lemma, ')
          ..write('pos: $pos, ')
          ..write('meaning: $meaning, ')
          ..write('example: $example, ')
          ..write('ipa: $ipa, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, lemma, pos, meaning, example, ipa, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VocabMasterData &&
          other.id == this.id &&
          other.lemma == this.lemma &&
          other.pos == this.pos &&
          other.meaning == this.meaning &&
          other.example == this.example &&
          other.ipa == this.ipa &&
          other.createdAt == this.createdAt);
}

class VocabMasterCompanion extends UpdateCompanion<VocabMasterData> {
  final Value<String> id;
  final Value<String> lemma;
  final Value<String?> pos;
  final Value<String> meaning;
  final Value<String?> example;
  final Value<String?> ipa;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const VocabMasterCompanion({
    this.id = const Value.absent(),
    this.lemma = const Value.absent(),
    this.pos = const Value.absent(),
    this.meaning = const Value.absent(),
    this.example = const Value.absent(),
    this.ipa = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VocabMasterCompanion.insert({
    required String id,
    required String lemma,
    this.pos = const Value.absent(),
    required String meaning,
    this.example = const Value.absent(),
    this.ipa = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       lemma = Value(lemma),
       meaning = Value(meaning);
  static Insertable<VocabMasterData> custom({
    Expression<String>? id,
    Expression<String>? lemma,
    Expression<String>? pos,
    Expression<String>? meaning,
    Expression<String>? example,
    Expression<String>? ipa,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lemma != null) 'lemma': lemma,
      if (pos != null) 'pos': pos,
      if (meaning != null) 'meaning': meaning,
      if (example != null) 'example': example,
      if (ipa != null) 'ipa': ipa,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VocabMasterCompanion copyWith({
    Value<String>? id,
    Value<String>? lemma,
    Value<String?>? pos,
    Value<String>? meaning,
    Value<String?>? example,
    Value<String?>? ipa,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return VocabMasterCompanion(
      id: id ?? this.id,
      lemma: lemma ?? this.lemma,
      pos: pos ?? this.pos,
      meaning: meaning ?? this.meaning,
      example: example ?? this.example,
      ipa: ipa ?? this.ipa,
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
    if (lemma.present) {
      map['lemma'] = Variable<String>(lemma.value);
    }
    if (pos.present) {
      map['pos'] = Variable<String>(pos.value);
    }
    if (meaning.present) {
      map['meaning'] = Variable<String>(meaning.value);
    }
    if (example.present) {
      map['example'] = Variable<String>(example.value);
    }
    if (ipa.present) {
      map['ipa'] = Variable<String>(ipa.value);
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
    return (StringBuffer('VocabMasterCompanion(')
          ..write('id: $id, ')
          ..write('lemma: $lemma, ')
          ..write('pos: $pos, ')
          ..write('meaning: $meaning, ')
          ..write('example: $example, ')
          ..write('ipa: $ipa, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VocabUserTable extends VocabUser
    with TableInfo<$VocabUserTable, VocabUserData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VocabUserTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _vocabIdMeta = const VerificationMeta(
    'vocabId',
  );
  @override
  late final GeneratedColumn<String> vocabId = GeneratedColumn<String>(
    'vocab_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vocab_master (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _familiarityMeta = const VerificationMeta(
    'familiarity',
  );
  @override
  late final GeneratedColumn<int> familiarity = GeneratedColumn<int>(
    'familiarity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isBookmarkedMeta = const VerificationMeta(
    'isBookmarked',
  );
  @override
  late final GeneratedColumn<bool> isBookmarked = GeneratedColumn<bool>(
    'is_bookmarked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_bookmarked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
    'last_seen_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    vocabId,
    familiarity,
    isBookmarked,
    lastSeenAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vocab_user';
  @override
  VerificationContext validateIntegrity(
    Insertable<VocabUserData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('vocab_id')) {
      context.handle(
        _vocabIdMeta,
        vocabId.isAcceptableOrUnknown(data['vocab_id']!, _vocabIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vocabIdMeta);
    }
    if (data.containsKey('familiarity')) {
      context.handle(
        _familiarityMeta,
        familiarity.isAcceptableOrUnknown(
          data['familiarity']!,
          _familiarityMeta,
        ),
      );
    }
    if (data.containsKey('is_bookmarked')) {
      context.handle(
        _isBookmarkedMeta,
        isBookmarked.isAcceptableOrUnknown(
          data['is_bookmarked']!,
          _isBookmarkedMeta,
        ),
      );
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {vocabId},
  ];
  @override
  VocabUserData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VocabUserData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      vocabId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vocab_id'],
      )!,
      familiarity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}familiarity'],
      )!,
      isBookmarked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_bookmarked'],
      )!,
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $VocabUserTable createAlias(String alias) {
    return $VocabUserTable(attachedDatabase, alias);
  }
}

class VocabUserData extends DataClass implements Insertable<VocabUserData> {
  final int id;
  final String vocabId;
  final int familiarity;
  final bool isBookmarked;
  final DateTime? lastSeenAt;
  final DateTime updatedAt;
  const VocabUserData({
    required this.id,
    required this.vocabId,
    required this.familiarity,
    required this.isBookmarked,
    this.lastSeenAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['vocab_id'] = Variable<String>(vocabId);
    map['familiarity'] = Variable<int>(familiarity);
    map['is_bookmarked'] = Variable<bool>(isBookmarked);
    if (!nullToAbsent || lastSeenAt != null) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  VocabUserCompanion toCompanion(bool nullToAbsent) {
    return VocabUserCompanion(
      id: Value(id),
      vocabId: Value(vocabId),
      familiarity: Value(familiarity),
      isBookmarked: Value(isBookmarked),
      lastSeenAt: lastSeenAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeenAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory VocabUserData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VocabUserData(
      id: serializer.fromJson<int>(json['id']),
      vocabId: serializer.fromJson<String>(json['vocabId']),
      familiarity: serializer.fromJson<int>(json['familiarity']),
      isBookmarked: serializer.fromJson<bool>(json['isBookmarked']),
      lastSeenAt: serializer.fromJson<DateTime?>(json['lastSeenAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'vocabId': serializer.toJson<String>(vocabId),
      'familiarity': serializer.toJson<int>(familiarity),
      'isBookmarked': serializer.toJson<bool>(isBookmarked),
      'lastSeenAt': serializer.toJson<DateTime?>(lastSeenAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  VocabUserData copyWith({
    int? id,
    String? vocabId,
    int? familiarity,
    bool? isBookmarked,
    Value<DateTime?> lastSeenAt = const Value.absent(),
    DateTime? updatedAt,
  }) => VocabUserData(
    id: id ?? this.id,
    vocabId: vocabId ?? this.vocabId,
    familiarity: familiarity ?? this.familiarity,
    isBookmarked: isBookmarked ?? this.isBookmarked,
    lastSeenAt: lastSeenAt.present ? lastSeenAt.value : this.lastSeenAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  VocabUserData copyWithCompanion(VocabUserCompanion data) {
    return VocabUserData(
      id: data.id.present ? data.id.value : this.id,
      vocabId: data.vocabId.present ? data.vocabId.value : this.vocabId,
      familiarity: data.familiarity.present
          ? data.familiarity.value
          : this.familiarity,
      isBookmarked: data.isBookmarked.present
          ? data.isBookmarked.value
          : this.isBookmarked,
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VocabUserData(')
          ..write('id: $id, ')
          ..write('vocabId: $vocabId, ')
          ..write('familiarity: $familiarity, ')
          ..write('isBookmarked: $isBookmarked, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    vocabId,
    familiarity,
    isBookmarked,
    lastSeenAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VocabUserData &&
          other.id == this.id &&
          other.vocabId == this.vocabId &&
          other.familiarity == this.familiarity &&
          other.isBookmarked == this.isBookmarked &&
          other.lastSeenAt == this.lastSeenAt &&
          other.updatedAt == this.updatedAt);
}

class VocabUserCompanion extends UpdateCompanion<VocabUserData> {
  final Value<int> id;
  final Value<String> vocabId;
  final Value<int> familiarity;
  final Value<bool> isBookmarked;
  final Value<DateTime?> lastSeenAt;
  final Value<DateTime> updatedAt;
  const VocabUserCompanion({
    this.id = const Value.absent(),
    this.vocabId = const Value.absent(),
    this.familiarity = const Value.absent(),
    this.isBookmarked = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  VocabUserCompanion.insert({
    this.id = const Value.absent(),
    required String vocabId,
    this.familiarity = const Value.absent(),
    this.isBookmarked = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : vocabId = Value(vocabId);
  static Insertable<VocabUserData> custom({
    Expression<int>? id,
    Expression<String>? vocabId,
    Expression<int>? familiarity,
    Expression<bool>? isBookmarked,
    Expression<DateTime>? lastSeenAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (vocabId != null) 'vocab_id': vocabId,
      if (familiarity != null) 'familiarity': familiarity,
      if (isBookmarked != null) 'is_bookmarked': isBookmarked,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  VocabUserCompanion copyWith({
    Value<int>? id,
    Value<String>? vocabId,
    Value<int>? familiarity,
    Value<bool>? isBookmarked,
    Value<DateTime?>? lastSeenAt,
    Value<DateTime>? updatedAt,
  }) {
    return VocabUserCompanion(
      id: id ?? this.id,
      vocabId: vocabId ?? this.vocabId,
      familiarity: familiarity ?? this.familiarity,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (vocabId.present) {
      map['vocab_id'] = Variable<String>(vocabId.value);
    }
    if (familiarity.present) {
      map['familiarity'] = Variable<int>(familiarity.value);
    }
    if (isBookmarked.present) {
      map['is_bookmarked'] = Variable<bool>(isBookmarked.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VocabUserCompanion(')
          ..write('id: $id, ')
          ..write('vocabId: $vocabId, ')
          ..write('familiarity: $familiarity, ')
          ..write('isBookmarked: $isBookmarked, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $VocabSrsStateTable extends VocabSrsState
    with TableInfo<$VocabSrsStateTable, VocabSrsStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VocabSrsStateTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _vocabIdMeta = const VerificationMeta(
    'vocabId',
  );
  @override
  late final GeneratedColumn<String> vocabId = GeneratedColumn<String>(
    'vocab_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vocab_master (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<DateTime> dueAt = GeneratedColumn<DateTime>(
    'due_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _intervalDaysMeta = const VerificationMeta(
    'intervalDays',
  );
  @override
  late final GeneratedColumn<int> intervalDays = GeneratedColumn<int>(
    'interval_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _easeFactorMeta = const VerificationMeta(
    'easeFactor',
  );
  @override
  late final GeneratedColumn<double> easeFactor = GeneratedColumn<double>(
    'ease_factor',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(2.5),
  );
  static const VerificationMeta _repetitionMeta = const VerificationMeta(
    'repetition',
  );
  @override
  late final GeneratedColumn<int> repetition = GeneratedColumn<int>(
    'repetition',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lapsesMeta = const VerificationMeta('lapses');
  @override
  late final GeneratedColumn<int> lapses = GeneratedColumn<int>(
    'lapses',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _suspendedMeta = const VerificationMeta(
    'suspended',
  );
  @override
  late final GeneratedColumn<bool> suspended = GeneratedColumn<bool>(
    'suspended',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("suspended" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    vocabId,
    dueAt,
    intervalDays,
    easeFactor,
    repetition,
    lapses,
    suspended,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vocab_srs_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<VocabSrsStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('vocab_id')) {
      context.handle(
        _vocabIdMeta,
        vocabId.isAcceptableOrUnknown(data['vocab_id']!, _vocabIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vocabIdMeta);
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    }
    if (data.containsKey('interval_days')) {
      context.handle(
        _intervalDaysMeta,
        intervalDays.isAcceptableOrUnknown(
          data['interval_days']!,
          _intervalDaysMeta,
        ),
      );
    }
    if (data.containsKey('ease_factor')) {
      context.handle(
        _easeFactorMeta,
        easeFactor.isAcceptableOrUnknown(data['ease_factor']!, _easeFactorMeta),
      );
    }
    if (data.containsKey('repetition')) {
      context.handle(
        _repetitionMeta,
        repetition.isAcceptableOrUnknown(data['repetition']!, _repetitionMeta),
      );
    }
    if (data.containsKey('lapses')) {
      context.handle(
        _lapsesMeta,
        lapses.isAcceptableOrUnknown(data['lapses']!, _lapsesMeta),
      );
    }
    if (data.containsKey('suspended')) {
      context.handle(
        _suspendedMeta,
        suspended.isAcceptableOrUnknown(data['suspended']!, _suspendedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {vocabId},
  ];
  @override
  VocabSrsStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VocabSrsStateData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      vocabId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vocab_id'],
      )!,
      dueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_at'],
      )!,
      intervalDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interval_days'],
      )!,
      easeFactor: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ease_factor'],
      )!,
      repetition: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}repetition'],
      )!,
      lapses: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lapses'],
      )!,
      suspended: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}suspended'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $VocabSrsStateTable createAlias(String alias) {
    return $VocabSrsStateTable(attachedDatabase, alias);
  }
}

class VocabSrsStateData extends DataClass
    implements Insertable<VocabSrsStateData> {
  final int id;
  final String vocabId;
  final DateTime dueAt;
  final int intervalDays;
  final double easeFactor;
  final int repetition;
  final int lapses;
  final bool suspended;
  final DateTime updatedAt;
  const VocabSrsStateData({
    required this.id,
    required this.vocabId,
    required this.dueAt,
    required this.intervalDays,
    required this.easeFactor,
    required this.repetition,
    required this.lapses,
    required this.suspended,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['vocab_id'] = Variable<String>(vocabId);
    map['due_at'] = Variable<DateTime>(dueAt);
    map['interval_days'] = Variable<int>(intervalDays);
    map['ease_factor'] = Variable<double>(easeFactor);
    map['repetition'] = Variable<int>(repetition);
    map['lapses'] = Variable<int>(lapses);
    map['suspended'] = Variable<bool>(suspended);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  VocabSrsStateCompanion toCompanion(bool nullToAbsent) {
    return VocabSrsStateCompanion(
      id: Value(id),
      vocabId: Value(vocabId),
      dueAt: Value(dueAt),
      intervalDays: Value(intervalDays),
      easeFactor: Value(easeFactor),
      repetition: Value(repetition),
      lapses: Value(lapses),
      suspended: Value(suspended),
      updatedAt: Value(updatedAt),
    );
  }

  factory VocabSrsStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VocabSrsStateData(
      id: serializer.fromJson<int>(json['id']),
      vocabId: serializer.fromJson<String>(json['vocabId']),
      dueAt: serializer.fromJson<DateTime>(json['dueAt']),
      intervalDays: serializer.fromJson<int>(json['intervalDays']),
      easeFactor: serializer.fromJson<double>(json['easeFactor']),
      repetition: serializer.fromJson<int>(json['repetition']),
      lapses: serializer.fromJson<int>(json['lapses']),
      suspended: serializer.fromJson<bool>(json['suspended']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'vocabId': serializer.toJson<String>(vocabId),
      'dueAt': serializer.toJson<DateTime>(dueAt),
      'intervalDays': serializer.toJson<int>(intervalDays),
      'easeFactor': serializer.toJson<double>(easeFactor),
      'repetition': serializer.toJson<int>(repetition),
      'lapses': serializer.toJson<int>(lapses),
      'suspended': serializer.toJson<bool>(suspended),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  VocabSrsStateData copyWith({
    int? id,
    String? vocabId,
    DateTime? dueAt,
    int? intervalDays,
    double? easeFactor,
    int? repetition,
    int? lapses,
    bool? suspended,
    DateTime? updatedAt,
  }) => VocabSrsStateData(
    id: id ?? this.id,
    vocabId: vocabId ?? this.vocabId,
    dueAt: dueAt ?? this.dueAt,
    intervalDays: intervalDays ?? this.intervalDays,
    easeFactor: easeFactor ?? this.easeFactor,
    repetition: repetition ?? this.repetition,
    lapses: lapses ?? this.lapses,
    suspended: suspended ?? this.suspended,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  VocabSrsStateData copyWithCompanion(VocabSrsStateCompanion data) {
    return VocabSrsStateData(
      id: data.id.present ? data.id.value : this.id,
      vocabId: data.vocabId.present ? data.vocabId.value : this.vocabId,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      intervalDays: data.intervalDays.present
          ? data.intervalDays.value
          : this.intervalDays,
      easeFactor: data.easeFactor.present
          ? data.easeFactor.value
          : this.easeFactor,
      repetition: data.repetition.present
          ? data.repetition.value
          : this.repetition,
      lapses: data.lapses.present ? data.lapses.value : this.lapses,
      suspended: data.suspended.present ? data.suspended.value : this.suspended,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VocabSrsStateData(')
          ..write('id: $id, ')
          ..write('vocabId: $vocabId, ')
          ..write('dueAt: $dueAt, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('easeFactor: $easeFactor, ')
          ..write('repetition: $repetition, ')
          ..write('lapses: $lapses, ')
          ..write('suspended: $suspended, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    vocabId,
    dueAt,
    intervalDays,
    easeFactor,
    repetition,
    lapses,
    suspended,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VocabSrsStateData &&
          other.id == this.id &&
          other.vocabId == this.vocabId &&
          other.dueAt == this.dueAt &&
          other.intervalDays == this.intervalDays &&
          other.easeFactor == this.easeFactor &&
          other.repetition == this.repetition &&
          other.lapses == this.lapses &&
          other.suspended == this.suspended &&
          other.updatedAt == this.updatedAt);
}

class VocabSrsStateCompanion extends UpdateCompanion<VocabSrsStateData> {
  final Value<int> id;
  final Value<String> vocabId;
  final Value<DateTime> dueAt;
  final Value<int> intervalDays;
  final Value<double> easeFactor;
  final Value<int> repetition;
  final Value<int> lapses;
  final Value<bool> suspended;
  final Value<DateTime> updatedAt;
  const VocabSrsStateCompanion({
    this.id = const Value.absent(),
    this.vocabId = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.intervalDays = const Value.absent(),
    this.easeFactor = const Value.absent(),
    this.repetition = const Value.absent(),
    this.lapses = const Value.absent(),
    this.suspended = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  VocabSrsStateCompanion.insert({
    this.id = const Value.absent(),
    required String vocabId,
    this.dueAt = const Value.absent(),
    this.intervalDays = const Value.absent(),
    this.easeFactor = const Value.absent(),
    this.repetition = const Value.absent(),
    this.lapses = const Value.absent(),
    this.suspended = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : vocabId = Value(vocabId);
  static Insertable<VocabSrsStateData> custom({
    Expression<int>? id,
    Expression<String>? vocabId,
    Expression<DateTime>? dueAt,
    Expression<int>? intervalDays,
    Expression<double>? easeFactor,
    Expression<int>? repetition,
    Expression<int>? lapses,
    Expression<bool>? suspended,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (vocabId != null) 'vocab_id': vocabId,
      if (dueAt != null) 'due_at': dueAt,
      if (intervalDays != null) 'interval_days': intervalDays,
      if (easeFactor != null) 'ease_factor': easeFactor,
      if (repetition != null) 'repetition': repetition,
      if (lapses != null) 'lapses': lapses,
      if (suspended != null) 'suspended': suspended,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  VocabSrsStateCompanion copyWith({
    Value<int>? id,
    Value<String>? vocabId,
    Value<DateTime>? dueAt,
    Value<int>? intervalDays,
    Value<double>? easeFactor,
    Value<int>? repetition,
    Value<int>? lapses,
    Value<bool>? suspended,
    Value<DateTime>? updatedAt,
  }) {
    return VocabSrsStateCompanion(
      id: id ?? this.id,
      vocabId: vocabId ?? this.vocabId,
      dueAt: dueAt ?? this.dueAt,
      intervalDays: intervalDays ?? this.intervalDays,
      easeFactor: easeFactor ?? this.easeFactor,
      repetition: repetition ?? this.repetition,
      lapses: lapses ?? this.lapses,
      suspended: suspended ?? this.suspended,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (vocabId.present) {
      map['vocab_id'] = Variable<String>(vocabId.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<DateTime>(dueAt.value);
    }
    if (intervalDays.present) {
      map['interval_days'] = Variable<int>(intervalDays.value);
    }
    if (easeFactor.present) {
      map['ease_factor'] = Variable<double>(easeFactor.value);
    }
    if (repetition.present) {
      map['repetition'] = Variable<int>(repetition.value);
    }
    if (lapses.present) {
      map['lapses'] = Variable<int>(lapses.value);
    }
    if (suspended.present) {
      map['suspended'] = Variable<bool>(suspended.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VocabSrsStateCompanion(')
          ..write('id: $id, ')
          ..write('vocabId: $vocabId, ')
          ..write('dueAt: $dueAt, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('easeFactor: $easeFactor, ')
          ..write('repetition: $repetition, ')
          ..write('lapses: $lapses, ')
          ..write('suspended: $suspended, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ContentPacksTable contentPacks = $ContentPacksTable(this);
  late final $PassagesTable passages = $PassagesTable(this);
  late final $ScriptsTable scripts = $ScriptsTable(this);
  late final $QuestionsTable questions = $QuestionsTable(this);
  late final $ExplanationsTable explanations = $ExplanationsTable(this);
  late final $DailySessionsTable dailySessions = $DailySessionsTable(this);
  late final $DailySessionItemsTable dailySessionItems =
      $DailySessionItemsTable(this);
  late final $UserSettingsTable userSettings = $UserSettingsTable(this);
  late final $SharedReportsTable sharedReports = $SharedReportsTable(this);
  late final $AttemptsTable attempts = $AttemptsTable(this);
  late final $VocabMasterTable vocabMaster = $VocabMasterTable(this);
  late final $VocabUserTable vocabUser = $VocabUserTable(this);
  late final $VocabSrsStateTable vocabSrsState = $VocabSrsStateTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    contentPacks,
    passages,
    scripts,
    questions,
    explanations,
    dailySessions,
    dailySessionItems,
    userSettings,
    sharedReports,
    attempts,
    vocabMaster,
    vocabUser,
    vocabSrsState,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'content_packs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('passages', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'content_packs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('scripts', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'passages',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('questions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'scripts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('questions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'questions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('explanations', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'daily_sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('daily_session_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'questions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('daily_session_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'questions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('attempts', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'daily_sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('attempts', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'vocab_master',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('vocab_user', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'vocab_master',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('vocab_srs_state', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$ContentPacksTableCreateCompanionBuilder =
    ContentPacksCompanion Function({
      required String id,
      required int version,
      required String locale,
      required String title,
      Value<String?> description,
      required String checksum,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$ContentPacksTableUpdateCompanionBuilder =
    ContentPacksCompanion Function({
      Value<String> id,
      Value<int> version,
      Value<String> locale,
      Value<String> title,
      Value<String?> description,
      Value<String> checksum,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$ContentPacksTableReferences
    extends BaseReferences<_$AppDatabase, $ContentPacksTable, ContentPack> {
  $$ContentPacksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PassagesTable, List<Passage>> _passagesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.passages,
    aliasName: $_aliasNameGenerator(db.contentPacks.id, db.passages.packId),
  );

  $$PassagesTableProcessedTableManager get passagesRefs {
    final manager = $$PassagesTableTableManager(
      $_db,
      $_db.passages,
    ).filter((f) => f.packId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_passagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ScriptsTable, List<Script>> _scriptsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.scripts,
    aliasName: $_aliasNameGenerator(db.contentPacks.id, db.scripts.packId),
  );

  $$ScriptsTableProcessedTableManager get scriptsRefs {
    final manager = $$ScriptsTableTableManager(
      $_db,
      $_db.scripts,
    ).filter((f) => f.packId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_scriptsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ContentPacksTableFilterComposer
    extends Composer<_$AppDatabase, $ContentPacksTable> {
  $$ContentPacksTableFilterComposer({
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

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locale => $composableBuilder(
    column: $table.locale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checksum => $composableBuilder(
    column: $table.checksum,
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

  Expression<bool> passagesRefs(
    Expression<bool> Function($$PassagesTableFilterComposer f) f,
  ) {
    final $$PassagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.passages,
      getReferencedColumn: (t) => t.packId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PassagesTableFilterComposer(
            $db: $db,
            $table: $db.passages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> scriptsRefs(
    Expression<bool> Function($$ScriptsTableFilterComposer f) f,
  ) {
    final $$ScriptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scripts,
      getReferencedColumn: (t) => t.packId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScriptsTableFilterComposer(
            $db: $db,
            $table: $db.scripts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ContentPacksTableOrderingComposer
    extends Composer<_$AppDatabase, $ContentPacksTable> {
  $$ContentPacksTableOrderingComposer({
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

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locale => $composableBuilder(
    column: $table.locale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checksum => $composableBuilder(
    column: $table.checksum,
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

class $$ContentPacksTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContentPacksTable> {
  $$ContentPacksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get locale =>
      $composableBuilder(column: $table.locale, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get checksum =>
      $composableBuilder(column: $table.checksum, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> passagesRefs<T extends Object>(
    Expression<T> Function($$PassagesTableAnnotationComposer a) f,
  ) {
    final $$PassagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.passages,
      getReferencedColumn: (t) => t.packId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PassagesTableAnnotationComposer(
            $db: $db,
            $table: $db.passages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> scriptsRefs<T extends Object>(
    Expression<T> Function($$ScriptsTableAnnotationComposer a) f,
  ) {
    final $$ScriptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scripts,
      getReferencedColumn: (t) => t.packId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScriptsTableAnnotationComposer(
            $db: $db,
            $table: $db.scripts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ContentPacksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ContentPacksTable,
          ContentPack,
          $$ContentPacksTableFilterComposer,
          $$ContentPacksTableOrderingComposer,
          $$ContentPacksTableAnnotationComposer,
          $$ContentPacksTableCreateCompanionBuilder,
          $$ContentPacksTableUpdateCompanionBuilder,
          (ContentPack, $$ContentPacksTableReferences),
          ContentPack,
          PrefetchHooks Function({bool passagesRefs, bool scriptsRefs})
        > {
  $$ContentPacksTableTableManager(_$AppDatabase db, $ContentPacksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContentPacksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContentPacksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContentPacksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> locale = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> checksum = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContentPacksCompanion(
                id: id,
                version: version,
                locale: locale,
                title: title,
                description: description,
                checksum: checksum,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int version,
                required String locale,
                required String title,
                Value<String?> description = const Value.absent(),
                required String checksum,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContentPacksCompanion.insert(
                id: id,
                version: version,
                locale: locale,
                title: title,
                description: description,
                checksum: checksum,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ContentPacksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({passagesRefs = false, scriptsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (passagesRefs) db.passages,
                if (scriptsRefs) db.scripts,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (passagesRefs)
                    await $_getPrefetchedData<
                      ContentPack,
                      $ContentPacksTable,
                      Passage
                    >(
                      currentTable: table,
                      referencedTable: $$ContentPacksTableReferences
                          ._passagesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ContentPacksTableReferences(
                            db,
                            table,
                            p0,
                          ).passagesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.packId == item.id),
                      typedResults: items,
                    ),
                  if (scriptsRefs)
                    await $_getPrefetchedData<
                      ContentPack,
                      $ContentPacksTable,
                      Script
                    >(
                      currentTable: table,
                      referencedTable: $$ContentPacksTableReferences
                          ._scriptsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ContentPacksTableReferences(
                            db,
                            table,
                            p0,
                          ).scriptsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.packId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ContentPacksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ContentPacksTable,
      ContentPack,
      $$ContentPacksTableFilterComposer,
      $$ContentPacksTableOrderingComposer,
      $$ContentPacksTableAnnotationComposer,
      $$ContentPacksTableCreateCompanionBuilder,
      $$ContentPacksTableUpdateCompanionBuilder,
      (ContentPack, $$ContentPacksTableReferences),
      ContentPack,
      PrefetchHooks Function({bool passagesRefs, bool scriptsRefs})
    >;
typedef $$PassagesTableCreateCompanionBuilder =
    PassagesCompanion Function({
      required String id,
      required String packId,
      Value<String?> title,
      required List<Sentence> sentencesJson,
      required int orderIndex,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$PassagesTableUpdateCompanionBuilder =
    PassagesCompanion Function({
      Value<String> id,
      Value<String> packId,
      Value<String?> title,
      Value<List<Sentence>> sentencesJson,
      Value<int> orderIndex,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$PassagesTableReferences
    extends BaseReferences<_$AppDatabase, $PassagesTable, Passage> {
  $$PassagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ContentPacksTable _packIdTable(_$AppDatabase db) =>
      db.contentPacks.createAlias(
        $_aliasNameGenerator(db.passages.packId, db.contentPacks.id),
      );

  $$ContentPacksTableProcessedTableManager get packId {
    final $_column = $_itemColumn<String>('pack_id')!;

    final manager = $$ContentPacksTableTableManager(
      $_db,
      $_db.contentPacks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_packIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$QuestionsTable, List<Question>>
  _questionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.questions,
    aliasName: $_aliasNameGenerator(db.passages.id, db.questions.passageId),
  );

  $$QuestionsTableProcessedTableManager get questionsRefs {
    final manager = $$QuestionsTableTableManager(
      $_db,
      $_db.questions,
    ).filter((f) => f.passageId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_questionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PassagesTableFilterComposer
    extends Composer<_$AppDatabase, $PassagesTable> {
  $$PassagesTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<Sentence>, List<Sentence>, String>
  get sentencesJson => $composableBuilder(
    column: $table.sentencesJson,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ContentPacksTableFilterComposer get packId {
    final $$ContentPacksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.packId,
      referencedTable: $db.contentPacks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContentPacksTableFilterComposer(
            $db: $db,
            $table: $db.contentPacks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> questionsRefs(
    Expression<bool> Function($$QuestionsTableFilterComposer f) f,
  ) {
    final $$QuestionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.passageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableFilterComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PassagesTableOrderingComposer
    extends Composer<_$AppDatabase, $PassagesTable> {
  $$PassagesTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sentencesJson => $composableBuilder(
    column: $table.sentencesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ContentPacksTableOrderingComposer get packId {
    final $$ContentPacksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.packId,
      referencedTable: $db.contentPacks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContentPacksTableOrderingComposer(
            $db: $db,
            $table: $db.contentPacks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PassagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PassagesTable> {
  $$PassagesTableAnnotationComposer({
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

  GeneratedColumnWithTypeConverter<List<Sentence>, String> get sentencesJson =>
      $composableBuilder(
        column: $table.sentencesJson,
        builder: (column) => column,
      );

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ContentPacksTableAnnotationComposer get packId {
    final $$ContentPacksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.packId,
      referencedTable: $db.contentPacks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContentPacksTableAnnotationComposer(
            $db: $db,
            $table: $db.contentPacks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> questionsRefs<T extends Object>(
    Expression<T> Function($$QuestionsTableAnnotationComposer a) f,
  ) {
    final $$QuestionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.passageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableAnnotationComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PassagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PassagesTable,
          Passage,
          $$PassagesTableFilterComposer,
          $$PassagesTableOrderingComposer,
          $$PassagesTableAnnotationComposer,
          $$PassagesTableCreateCompanionBuilder,
          $$PassagesTableUpdateCompanionBuilder,
          (Passage, $$PassagesTableReferences),
          Passage,
          PrefetchHooks Function({bool packId, bool questionsRefs})
        > {
  $$PassagesTableTableManager(_$AppDatabase db, $PassagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PassagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PassagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PassagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> packId = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<List<Sentence>> sentencesJson = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PassagesCompanion(
                id: id,
                packId: packId,
                title: title,
                sentencesJson: sentencesJson,
                orderIndex: orderIndex,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String packId,
                Value<String?> title = const Value.absent(),
                required List<Sentence> sentencesJson,
                required int orderIndex,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PassagesCompanion.insert(
                id: id,
                packId: packId,
                title: title,
                sentencesJson: sentencesJson,
                orderIndex: orderIndex,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PassagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({packId = false, questionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (questionsRefs) db.questions],
              addJoins:
                  <
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
                    if (packId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.packId,
                                referencedTable: $$PassagesTableReferences
                                    ._packIdTable(db),
                                referencedColumn: $$PassagesTableReferences
                                    ._packIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (questionsRefs)
                    await $_getPrefetchedData<
                      Passage,
                      $PassagesTable,
                      Question
                    >(
                      currentTable: table,
                      referencedTable: $$PassagesTableReferences
                          ._questionsRefsTable(db),
                      managerFromTypedResult: (p0) => $$PassagesTableReferences(
                        db,
                        table,
                        p0,
                      ).questionsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.passageId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PassagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PassagesTable,
      Passage,
      $$PassagesTableFilterComposer,
      $$PassagesTableOrderingComposer,
      $$PassagesTableAnnotationComposer,
      $$PassagesTableCreateCompanionBuilder,
      $$PassagesTableUpdateCompanionBuilder,
      (Passage, $$PassagesTableReferences),
      Passage,
      PrefetchHooks Function({bool packId, bool questionsRefs})
    >;
typedef $$ScriptsTableCreateCompanionBuilder =
    ScriptsCompanion Function({
      required String id,
      required String packId,
      required List<Sentence> sentencesJson,
      required List<Turn> turnsJson,
      required TtsPlan ttsPlanJson,
      required int orderIndex,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$ScriptsTableUpdateCompanionBuilder =
    ScriptsCompanion Function({
      Value<String> id,
      Value<String> packId,
      Value<List<Sentence>> sentencesJson,
      Value<List<Turn>> turnsJson,
      Value<TtsPlan> ttsPlanJson,
      Value<int> orderIndex,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$ScriptsTableReferences
    extends BaseReferences<_$AppDatabase, $ScriptsTable, Script> {
  $$ScriptsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ContentPacksTable _packIdTable(_$AppDatabase db) => db.contentPacks
      .createAlias($_aliasNameGenerator(db.scripts.packId, db.contentPacks.id));

  $$ContentPacksTableProcessedTableManager get packId {
    final $_column = $_itemColumn<String>('pack_id')!;

    final manager = $$ContentPacksTableTableManager(
      $_db,
      $_db.contentPacks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_packIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$QuestionsTable, List<Question>>
  _questionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.questions,
    aliasName: $_aliasNameGenerator(db.scripts.id, db.questions.scriptId),
  );

  $$QuestionsTableProcessedTableManager get questionsRefs {
    final manager = $$QuestionsTableTableManager(
      $_db,
      $_db.questions,
    ).filter((f) => f.scriptId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_questionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ScriptsTableFilterComposer
    extends Composer<_$AppDatabase, $ScriptsTable> {
  $$ScriptsTableFilterComposer({
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

  ColumnWithTypeConverterFilters<List<Sentence>, List<Sentence>, String>
  get sentencesJson => $composableBuilder(
    column: $table.sentencesJson,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<Turn>, List<Turn>, String>
  get turnsJson => $composableBuilder(
    column: $table.turnsJson,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<TtsPlan, TtsPlan, String> get ttsPlanJson =>
      $composableBuilder(
        column: $table.ttsPlanJson,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ContentPacksTableFilterComposer get packId {
    final $$ContentPacksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.packId,
      referencedTable: $db.contentPacks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContentPacksTableFilterComposer(
            $db: $db,
            $table: $db.contentPacks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> questionsRefs(
    Expression<bool> Function($$QuestionsTableFilterComposer f) f,
  ) {
    final $$QuestionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.scriptId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableFilterComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ScriptsTableOrderingComposer
    extends Composer<_$AppDatabase, $ScriptsTable> {
  $$ScriptsTableOrderingComposer({
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

  ColumnOrderings<String> get sentencesJson => $composableBuilder(
    column: $table.sentencesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get turnsJson => $composableBuilder(
    column: $table.turnsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ttsPlanJson => $composableBuilder(
    column: $table.ttsPlanJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ContentPacksTableOrderingComposer get packId {
    final $$ContentPacksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.packId,
      referencedTable: $db.contentPacks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContentPacksTableOrderingComposer(
            $db: $db,
            $table: $db.contentPacks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ScriptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScriptsTable> {
  $$ScriptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<Sentence>, String> get sentencesJson =>
      $composableBuilder(
        column: $table.sentencesJson,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<List<Turn>, String> get turnsJson =>
      $composableBuilder(column: $table.turnsJson, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TtsPlan, String> get ttsPlanJson =>
      $composableBuilder(
        column: $table.ttsPlanJson,
        builder: (column) => column,
      );

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ContentPacksTableAnnotationComposer get packId {
    final $$ContentPacksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.packId,
      referencedTable: $db.contentPacks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContentPacksTableAnnotationComposer(
            $db: $db,
            $table: $db.contentPacks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> questionsRefs<T extends Object>(
    Expression<T> Function($$QuestionsTableAnnotationComposer a) f,
  ) {
    final $$QuestionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.scriptId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableAnnotationComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ScriptsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScriptsTable,
          Script,
          $$ScriptsTableFilterComposer,
          $$ScriptsTableOrderingComposer,
          $$ScriptsTableAnnotationComposer,
          $$ScriptsTableCreateCompanionBuilder,
          $$ScriptsTableUpdateCompanionBuilder,
          (Script, $$ScriptsTableReferences),
          Script,
          PrefetchHooks Function({bool packId, bool questionsRefs})
        > {
  $$ScriptsTableTableManager(_$AppDatabase db, $ScriptsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScriptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScriptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScriptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> packId = const Value.absent(),
                Value<List<Sentence>> sentencesJson = const Value.absent(),
                Value<List<Turn>> turnsJson = const Value.absent(),
                Value<TtsPlan> ttsPlanJson = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScriptsCompanion(
                id: id,
                packId: packId,
                sentencesJson: sentencesJson,
                turnsJson: turnsJson,
                ttsPlanJson: ttsPlanJson,
                orderIndex: orderIndex,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String packId,
                required List<Sentence> sentencesJson,
                required List<Turn> turnsJson,
                required TtsPlan ttsPlanJson,
                required int orderIndex,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScriptsCompanion.insert(
                id: id,
                packId: packId,
                sentencesJson: sentencesJson,
                turnsJson: turnsJson,
                ttsPlanJson: ttsPlanJson,
                orderIndex: orderIndex,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ScriptsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({packId = false, questionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (questionsRefs) db.questions],
              addJoins:
                  <
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
                    if (packId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.packId,
                                referencedTable: $$ScriptsTableReferences
                                    ._packIdTable(db),
                                referencedColumn: $$ScriptsTableReferences
                                    ._packIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (questionsRefs)
                    await $_getPrefetchedData<Script, $ScriptsTable, Question>(
                      currentTable: table,
                      referencedTable: $$ScriptsTableReferences
                          ._questionsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ScriptsTableReferences(db, table, p0).questionsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.scriptId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ScriptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScriptsTable,
      Script,
      $$ScriptsTableFilterComposer,
      $$ScriptsTableOrderingComposer,
      $$ScriptsTableAnnotationComposer,
      $$ScriptsTableCreateCompanionBuilder,
      $$ScriptsTableUpdateCompanionBuilder,
      (Script, $$ScriptsTableReferences),
      Script,
      PrefetchHooks Function({bool packId, bool questionsRefs})
    >;
typedef $$QuestionsTableCreateCompanionBuilder =
    QuestionsCompanion Function({
      required String id,
      required String skill,
      required String typeTag,
      required String track,
      required int difficulty,
      Value<String?> passageId,
      Value<String?> scriptId,
      required String prompt,
      required OptionMap optionsJson,
      required String answerKey,
      required int orderIndex,
      Value<int> rowid,
    });
typedef $$QuestionsTableUpdateCompanionBuilder =
    QuestionsCompanion Function({
      Value<String> id,
      Value<String> skill,
      Value<String> typeTag,
      Value<String> track,
      Value<int> difficulty,
      Value<String?> passageId,
      Value<String?> scriptId,
      Value<String> prompt,
      Value<OptionMap> optionsJson,
      Value<String> answerKey,
      Value<int> orderIndex,
      Value<int> rowid,
    });

final class $$QuestionsTableReferences
    extends BaseReferences<_$AppDatabase, $QuestionsTable, Question> {
  $$QuestionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PassagesTable _passageIdTable(_$AppDatabase db) =>
      db.passages.createAlias(
        $_aliasNameGenerator(db.questions.passageId, db.passages.id),
      );

  $$PassagesTableProcessedTableManager? get passageId {
    final $_column = $_itemColumn<String>('passage_id');
    if ($_column == null) return null;
    final manager = $$PassagesTableTableManager(
      $_db,
      $_db.passages,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_passageIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ScriptsTable _scriptIdTable(_$AppDatabase db) => db.scripts
      .createAlias($_aliasNameGenerator(db.questions.scriptId, db.scripts.id));

  $$ScriptsTableProcessedTableManager? get scriptId {
    final $_column = $_itemColumn<String>('script_id');
    if ($_column == null) return null;
    final manager = $$ScriptsTableTableManager(
      $_db,
      $_db.scripts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_scriptIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ExplanationsTable, List<Explanation>>
  _explanationsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.explanations,
    aliasName: $_aliasNameGenerator(
      db.questions.id,
      db.explanations.questionId,
    ),
  );

  $$ExplanationsTableProcessedTableManager get explanationsRefs {
    final manager = $$ExplanationsTableTableManager(
      $_db,
      $_db.explanations,
    ).filter((f) => f.questionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_explanationsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DailySessionItemsTable, List<DailySessionItem>>
  _dailySessionItemsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.dailySessionItems,
        aliasName: $_aliasNameGenerator(
          db.questions.id,
          db.dailySessionItems.questionId,
        ),
      );

  $$DailySessionItemsTableProcessedTableManager get dailySessionItemsRefs {
    final manager = $$DailySessionItemsTableTableManager(
      $_db,
      $_db.dailySessionItems,
    ).filter((f) => f.questionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _dailySessionItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AttemptsTable, List<Attempt>> _attemptsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.attempts,
    aliasName: $_aliasNameGenerator(db.questions.id, db.attempts.questionId),
  );

  $$AttemptsTableProcessedTableManager get attemptsRefs {
    final manager = $$AttemptsTableTableManager(
      $_db,
      $_db.attempts,
    ).filter((f) => f.questionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_attemptsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$QuestionsTableFilterComposer
    extends Composer<_$AppDatabase, $QuestionsTable> {
  $$QuestionsTableFilterComposer({
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

  ColumnFilters<String> get skill => $composableBuilder(
    column: $table.skill,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get typeTag => $composableBuilder(
    column: $table.typeTag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get track => $composableBuilder(
    column: $table.track,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prompt => $composableBuilder(
    column: $table.prompt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<OptionMap, OptionMap, String>
  get optionsJson => $composableBuilder(
    column: $table.optionsJson,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get answerKey => $composableBuilder(
    column: $table.answerKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  $$PassagesTableFilterComposer get passageId {
    final $$PassagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.passageId,
      referencedTable: $db.passages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PassagesTableFilterComposer(
            $db: $db,
            $table: $db.passages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ScriptsTableFilterComposer get scriptId {
    final $$ScriptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scriptId,
      referencedTable: $db.scripts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScriptsTableFilterComposer(
            $db: $db,
            $table: $db.scripts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> explanationsRefs(
    Expression<bool> Function($$ExplanationsTableFilterComposer f) f,
  ) {
    final $$ExplanationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.explanations,
      getReferencedColumn: (t) => t.questionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExplanationsTableFilterComposer(
            $db: $db,
            $table: $db.explanations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> dailySessionItemsRefs(
    Expression<bool> Function($$DailySessionItemsTableFilterComposer f) f,
  ) {
    final $$DailySessionItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dailySessionItems,
      getReferencedColumn: (t) => t.questionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DailySessionItemsTableFilterComposer(
            $db: $db,
            $table: $db.dailySessionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> attemptsRefs(
    Expression<bool> Function($$AttemptsTableFilterComposer f) f,
  ) {
    final $$AttemptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attempts,
      getReferencedColumn: (t) => t.questionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttemptsTableFilterComposer(
            $db: $db,
            $table: $db.attempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$QuestionsTableOrderingComposer
    extends Composer<_$AppDatabase, $QuestionsTable> {
  $$QuestionsTableOrderingComposer({
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

  ColumnOrderings<String> get skill => $composableBuilder(
    column: $table.skill,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get typeTag => $composableBuilder(
    column: $table.typeTag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get track => $composableBuilder(
    column: $table.track,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prompt => $composableBuilder(
    column: $table.prompt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get optionsJson => $composableBuilder(
    column: $table.optionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answerKey => $composableBuilder(
    column: $table.answerKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  $$PassagesTableOrderingComposer get passageId {
    final $$PassagesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.passageId,
      referencedTable: $db.passages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PassagesTableOrderingComposer(
            $db: $db,
            $table: $db.passages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ScriptsTableOrderingComposer get scriptId {
    final $$ScriptsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scriptId,
      referencedTable: $db.scripts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScriptsTableOrderingComposer(
            $db: $db,
            $table: $db.scripts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$QuestionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $QuestionsTable> {
  $$QuestionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get skill =>
      $composableBuilder(column: $table.skill, builder: (column) => column);

  GeneratedColumn<String> get typeTag =>
      $composableBuilder(column: $table.typeTag, builder: (column) => column);

  GeneratedColumn<String> get track =>
      $composableBuilder(column: $table.track, builder: (column) => column);

  GeneratedColumn<int> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => column,
  );

  GeneratedColumn<String> get prompt =>
      $composableBuilder(column: $table.prompt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<OptionMap, String> get optionsJson =>
      $composableBuilder(
        column: $table.optionsJson,
        builder: (column) => column,
      );

  GeneratedColumn<String> get answerKey =>
      $composableBuilder(column: $table.answerKey, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  $$PassagesTableAnnotationComposer get passageId {
    final $$PassagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.passageId,
      referencedTable: $db.passages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PassagesTableAnnotationComposer(
            $db: $db,
            $table: $db.passages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ScriptsTableAnnotationComposer get scriptId {
    final $$ScriptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scriptId,
      referencedTable: $db.scripts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScriptsTableAnnotationComposer(
            $db: $db,
            $table: $db.scripts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> explanationsRefs<T extends Object>(
    Expression<T> Function($$ExplanationsTableAnnotationComposer a) f,
  ) {
    final $$ExplanationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.explanations,
      getReferencedColumn: (t) => t.questionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExplanationsTableAnnotationComposer(
            $db: $db,
            $table: $db.explanations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> dailySessionItemsRefs<T extends Object>(
    Expression<T> Function($$DailySessionItemsTableAnnotationComposer a) f,
  ) {
    final $$DailySessionItemsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.dailySessionItems,
          getReferencedColumn: (t) => t.questionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DailySessionItemsTableAnnotationComposer(
                $db: $db,
                $table: $db.dailySessionItems,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> attemptsRefs<T extends Object>(
    Expression<T> Function($$AttemptsTableAnnotationComposer a) f,
  ) {
    final $$AttemptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attempts,
      getReferencedColumn: (t) => t.questionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttemptsTableAnnotationComposer(
            $db: $db,
            $table: $db.attempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$QuestionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QuestionsTable,
          Question,
          $$QuestionsTableFilterComposer,
          $$QuestionsTableOrderingComposer,
          $$QuestionsTableAnnotationComposer,
          $$QuestionsTableCreateCompanionBuilder,
          $$QuestionsTableUpdateCompanionBuilder,
          (Question, $$QuestionsTableReferences),
          Question,
          PrefetchHooks Function({
            bool passageId,
            bool scriptId,
            bool explanationsRefs,
            bool dailySessionItemsRefs,
            bool attemptsRefs,
          })
        > {
  $$QuestionsTableTableManager(_$AppDatabase db, $QuestionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuestionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuestionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuestionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> skill = const Value.absent(),
                Value<String> typeTag = const Value.absent(),
                Value<String> track = const Value.absent(),
                Value<int> difficulty = const Value.absent(),
                Value<String?> passageId = const Value.absent(),
                Value<String?> scriptId = const Value.absent(),
                Value<String> prompt = const Value.absent(),
                Value<OptionMap> optionsJson = const Value.absent(),
                Value<String> answerKey = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuestionsCompanion(
                id: id,
                skill: skill,
                typeTag: typeTag,
                track: track,
                difficulty: difficulty,
                passageId: passageId,
                scriptId: scriptId,
                prompt: prompt,
                optionsJson: optionsJson,
                answerKey: answerKey,
                orderIndex: orderIndex,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String skill,
                required String typeTag,
                required String track,
                required int difficulty,
                Value<String?> passageId = const Value.absent(),
                Value<String?> scriptId = const Value.absent(),
                required String prompt,
                required OptionMap optionsJson,
                required String answerKey,
                required int orderIndex,
                Value<int> rowid = const Value.absent(),
              }) => QuestionsCompanion.insert(
                id: id,
                skill: skill,
                typeTag: typeTag,
                track: track,
                difficulty: difficulty,
                passageId: passageId,
                scriptId: scriptId,
                prompt: prompt,
                optionsJson: optionsJson,
                answerKey: answerKey,
                orderIndex: orderIndex,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$QuestionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                passageId = false,
                scriptId = false,
                explanationsRefs = false,
                dailySessionItemsRefs = false,
                attemptsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (explanationsRefs) db.explanations,
                    if (dailySessionItemsRefs) db.dailySessionItems,
                    if (attemptsRefs) db.attempts,
                  ],
                  addJoins:
                      <
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
                        if (passageId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.passageId,
                                    referencedTable: $$QuestionsTableReferences
                                        ._passageIdTable(db),
                                    referencedColumn: $$QuestionsTableReferences
                                        ._passageIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (scriptId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.scriptId,
                                    referencedTable: $$QuestionsTableReferences
                                        ._scriptIdTable(db),
                                    referencedColumn: $$QuestionsTableReferences
                                        ._scriptIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (explanationsRefs)
                        await $_getPrefetchedData<
                          Question,
                          $QuestionsTable,
                          Explanation
                        >(
                          currentTable: table,
                          referencedTable: $$QuestionsTableReferences
                              ._explanationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$QuestionsTableReferences(
                                db,
                                table,
                                p0,
                              ).explanationsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.questionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (dailySessionItemsRefs)
                        await $_getPrefetchedData<
                          Question,
                          $QuestionsTable,
                          DailySessionItem
                        >(
                          currentTable: table,
                          referencedTable: $$QuestionsTableReferences
                              ._dailySessionItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$QuestionsTableReferences(
                                db,
                                table,
                                p0,
                              ).dailySessionItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.questionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (attemptsRefs)
                        await $_getPrefetchedData<
                          Question,
                          $QuestionsTable,
                          Attempt
                        >(
                          currentTable: table,
                          referencedTable: $$QuestionsTableReferences
                              ._attemptsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$QuestionsTableReferences(
                                db,
                                table,
                                p0,
                              ).attemptsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.questionId == item.id,
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

typedef $$QuestionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QuestionsTable,
      Question,
      $$QuestionsTableFilterComposer,
      $$QuestionsTableOrderingComposer,
      $$QuestionsTableAnnotationComposer,
      $$QuestionsTableCreateCompanionBuilder,
      $$QuestionsTableUpdateCompanionBuilder,
      (Question, $$QuestionsTableReferences),
      Question,
      PrefetchHooks Function({
        bool passageId,
        bool scriptId,
        bool explanationsRefs,
        bool dailySessionItemsRefs,
        bool attemptsRefs,
      })
    >;
typedef $$ExplanationsTableCreateCompanionBuilder =
    ExplanationsCompanion Function({
      required String id,
      required String questionId,
      required List<String> evidenceSentenceIdsJson,
      required String whyCorrectKo,
      required OptionMap whyWrongKoJson,
      Value<String?> vocabNotesJson,
      Value<String?> structureNotesKo,
      Value<String?> glossKoJson,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$ExplanationsTableUpdateCompanionBuilder =
    ExplanationsCompanion Function({
      Value<String> id,
      Value<String> questionId,
      Value<List<String>> evidenceSentenceIdsJson,
      Value<String> whyCorrectKo,
      Value<OptionMap> whyWrongKoJson,
      Value<String?> vocabNotesJson,
      Value<String?> structureNotesKo,
      Value<String?> glossKoJson,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$ExplanationsTableReferences
    extends BaseReferences<_$AppDatabase, $ExplanationsTable, Explanation> {
  $$ExplanationsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $QuestionsTable _questionIdTable(_$AppDatabase db) =>
      db.questions.createAlias(
        $_aliasNameGenerator(db.explanations.questionId, db.questions.id),
      );

  $$QuestionsTableProcessedTableManager get questionId {
    final $_column = $_itemColumn<String>('question_id')!;

    final manager = $$QuestionsTableTableManager(
      $_db,
      $_db.questions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_questionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ExplanationsTableFilterComposer
    extends Composer<_$AppDatabase, $ExplanationsTable> {
  $$ExplanationsTableFilterComposer({
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

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get evidenceSentenceIdsJson => $composableBuilder(
    column: $table.evidenceSentenceIdsJson,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get whyCorrectKo => $composableBuilder(
    column: $table.whyCorrectKo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<OptionMap, OptionMap, String>
  get whyWrongKoJson => $composableBuilder(
    column: $table.whyWrongKoJson,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get vocabNotesJson => $composableBuilder(
    column: $table.vocabNotesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get structureNotesKo => $composableBuilder(
    column: $table.structureNotesKo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get glossKoJson => $composableBuilder(
    column: $table.glossKoJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$QuestionsTableFilterComposer get questionId {
    final $$QuestionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.questionId,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableFilterComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExplanationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ExplanationsTable> {
  $$ExplanationsTableOrderingComposer({
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

  ColumnOrderings<String> get evidenceSentenceIdsJson => $composableBuilder(
    column: $table.evidenceSentenceIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get whyCorrectKo => $composableBuilder(
    column: $table.whyCorrectKo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get whyWrongKoJson => $composableBuilder(
    column: $table.whyWrongKoJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vocabNotesJson => $composableBuilder(
    column: $table.vocabNotesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get structureNotesKo => $composableBuilder(
    column: $table.structureNotesKo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get glossKoJson => $composableBuilder(
    column: $table.glossKoJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$QuestionsTableOrderingComposer get questionId {
    final $$QuestionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.questionId,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableOrderingComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExplanationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExplanationsTable> {
  $$ExplanationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String>
  get evidenceSentenceIdsJson => $composableBuilder(
    column: $table.evidenceSentenceIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get whyCorrectKo => $composableBuilder(
    column: $table.whyCorrectKo,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<OptionMap, String> get whyWrongKoJson =>
      $composableBuilder(
        column: $table.whyWrongKoJson,
        builder: (column) => column,
      );

  GeneratedColumn<String> get vocabNotesJson => $composableBuilder(
    column: $table.vocabNotesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get structureNotesKo => $composableBuilder(
    column: $table.structureNotesKo,
    builder: (column) => column,
  );

  GeneratedColumn<String> get glossKoJson => $composableBuilder(
    column: $table.glossKoJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$QuestionsTableAnnotationComposer get questionId {
    final $$QuestionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.questionId,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableAnnotationComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExplanationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExplanationsTable,
          Explanation,
          $$ExplanationsTableFilterComposer,
          $$ExplanationsTableOrderingComposer,
          $$ExplanationsTableAnnotationComposer,
          $$ExplanationsTableCreateCompanionBuilder,
          $$ExplanationsTableUpdateCompanionBuilder,
          (Explanation, $$ExplanationsTableReferences),
          Explanation,
          PrefetchHooks Function({bool questionId})
        > {
  $$ExplanationsTableTableManager(_$AppDatabase db, $ExplanationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExplanationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExplanationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExplanationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> questionId = const Value.absent(),
                Value<List<String>> evidenceSentenceIdsJson =
                    const Value.absent(),
                Value<String> whyCorrectKo = const Value.absent(),
                Value<OptionMap> whyWrongKoJson = const Value.absent(),
                Value<String?> vocabNotesJson = const Value.absent(),
                Value<String?> structureNotesKo = const Value.absent(),
                Value<String?> glossKoJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExplanationsCompanion(
                id: id,
                questionId: questionId,
                evidenceSentenceIdsJson: evidenceSentenceIdsJson,
                whyCorrectKo: whyCorrectKo,
                whyWrongKoJson: whyWrongKoJson,
                vocabNotesJson: vocabNotesJson,
                structureNotesKo: structureNotesKo,
                glossKoJson: glossKoJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String questionId,
                required List<String> evidenceSentenceIdsJson,
                required String whyCorrectKo,
                required OptionMap whyWrongKoJson,
                Value<String?> vocabNotesJson = const Value.absent(),
                Value<String?> structureNotesKo = const Value.absent(),
                Value<String?> glossKoJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExplanationsCompanion.insert(
                id: id,
                questionId: questionId,
                evidenceSentenceIdsJson: evidenceSentenceIdsJson,
                whyCorrectKo: whyCorrectKo,
                whyWrongKoJson: whyWrongKoJson,
                vocabNotesJson: vocabNotesJson,
                structureNotesKo: structureNotesKo,
                glossKoJson: glossKoJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ExplanationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({questionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
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
                    if (questionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.questionId,
                                referencedTable: $$ExplanationsTableReferences
                                    ._questionIdTable(db),
                                referencedColumn: $$ExplanationsTableReferences
                                    ._questionIdTable(db)
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

typedef $$ExplanationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExplanationsTable,
      Explanation,
      $$ExplanationsTableFilterComposer,
      $$ExplanationsTableOrderingComposer,
      $$ExplanationsTableAnnotationComposer,
      $$ExplanationsTableCreateCompanionBuilder,
      $$ExplanationsTableUpdateCompanionBuilder,
      (Explanation, $$ExplanationsTableReferences),
      Explanation,
      PrefetchHooks Function({bool questionId})
    >;
typedef $$DailySessionsTableCreateCompanionBuilder =
    DailySessionsCompanion Function({
      Value<int> id,
      required int dayKey,
      Value<String> track,
      Value<int> plannedItems,
      Value<int> completedItems,
      Value<DateTime> createdAt,
    });
typedef $$DailySessionsTableUpdateCompanionBuilder =
    DailySessionsCompanion Function({
      Value<int> id,
      Value<int> dayKey,
      Value<String> track,
      Value<int> plannedItems,
      Value<int> completedItems,
      Value<DateTime> createdAt,
    });

final class $$DailySessionsTableReferences
    extends BaseReferences<_$AppDatabase, $DailySessionsTable, DailySession> {
  $$DailySessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$DailySessionItemsTable, List<DailySessionItem>>
  _dailySessionItemsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.dailySessionItems,
        aliasName: $_aliasNameGenerator(
          db.dailySessions.id,
          db.dailySessionItems.sessionId,
        ),
      );

  $$DailySessionItemsTableProcessedTableManager get dailySessionItemsRefs {
    final manager = $$DailySessionItemsTableTableManager(
      $_db,
      $_db.dailySessionItems,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _dailySessionItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AttemptsTable, List<Attempt>> _attemptsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.attempts,
    aliasName: $_aliasNameGenerator(db.dailySessions.id, db.attempts.sessionId),
  );

  $$AttemptsTableProcessedTableManager get attemptsRefs {
    final manager = $$AttemptsTableTableManager(
      $_db,
      $_db.attempts,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_attemptsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DailySessionsTableFilterComposer
    extends Composer<_$AppDatabase, $DailySessionsTable> {
  $$DailySessionsTableFilterComposer({
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

  ColumnFilters<int> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get track => $composableBuilder(
    column: $table.track,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plannedItems => $composableBuilder(
    column: $table.plannedItems,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedItems => $composableBuilder(
    column: $table.completedItems,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> dailySessionItemsRefs(
    Expression<bool> Function($$DailySessionItemsTableFilterComposer f) f,
  ) {
    final $$DailySessionItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dailySessionItems,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DailySessionItemsTableFilterComposer(
            $db: $db,
            $table: $db.dailySessionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> attemptsRefs(
    Expression<bool> Function($$AttemptsTableFilterComposer f) f,
  ) {
    final $$AttemptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attempts,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttemptsTableFilterComposer(
            $db: $db,
            $table: $db.attempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DailySessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $DailySessionsTable> {
  $$DailySessionsTableOrderingComposer({
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

  ColumnOrderings<int> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get track => $composableBuilder(
    column: $table.track,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plannedItems => $composableBuilder(
    column: $table.plannedItems,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedItems => $composableBuilder(
    column: $table.completedItems,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DailySessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailySessionsTable> {
  $$DailySessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get dayKey =>
      $composableBuilder(column: $table.dayKey, builder: (column) => column);

  GeneratedColumn<String> get track =>
      $composableBuilder(column: $table.track, builder: (column) => column);

  GeneratedColumn<int> get plannedItems => $composableBuilder(
    column: $table.plannedItems,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completedItems => $composableBuilder(
    column: $table.completedItems,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> dailySessionItemsRefs<T extends Object>(
    Expression<T> Function($$DailySessionItemsTableAnnotationComposer a) f,
  ) {
    final $$DailySessionItemsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.dailySessionItems,
          getReferencedColumn: (t) => t.sessionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DailySessionItemsTableAnnotationComposer(
                $db: $db,
                $table: $db.dailySessionItems,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> attemptsRefs<T extends Object>(
    Expression<T> Function($$AttemptsTableAnnotationComposer a) f,
  ) {
    final $$AttemptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attempts,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttemptsTableAnnotationComposer(
            $db: $db,
            $table: $db.attempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DailySessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DailySessionsTable,
          DailySession,
          $$DailySessionsTableFilterComposer,
          $$DailySessionsTableOrderingComposer,
          $$DailySessionsTableAnnotationComposer,
          $$DailySessionsTableCreateCompanionBuilder,
          $$DailySessionsTableUpdateCompanionBuilder,
          (DailySession, $$DailySessionsTableReferences),
          DailySession,
          PrefetchHooks Function({
            bool dailySessionItemsRefs,
            bool attemptsRefs,
          })
        > {
  $$DailySessionsTableTableManager(_$AppDatabase db, $DailySessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailySessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailySessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailySessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> dayKey = const Value.absent(),
                Value<String> track = const Value.absent(),
                Value<int> plannedItems = const Value.absent(),
                Value<int> completedItems = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => DailySessionsCompanion(
                id: id,
                dayKey: dayKey,
                track: track,
                plannedItems: plannedItems,
                completedItems: completedItems,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int dayKey,
                Value<String> track = const Value.absent(),
                Value<int> plannedItems = const Value.absent(),
                Value<int> completedItems = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => DailySessionsCompanion.insert(
                id: id,
                dayKey: dayKey,
                track: track,
                plannedItems: plannedItems,
                completedItems: completedItems,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DailySessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({dailySessionItemsRefs = false, attemptsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (dailySessionItemsRefs) db.dailySessionItems,
                    if (attemptsRefs) db.attempts,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (dailySessionItemsRefs)
                        await $_getPrefetchedData<
                          DailySession,
                          $DailySessionsTable,
                          DailySessionItem
                        >(
                          currentTable: table,
                          referencedTable: $$DailySessionsTableReferences
                              ._dailySessionItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DailySessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).dailySessionItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (attemptsRefs)
                        await $_getPrefetchedData<
                          DailySession,
                          $DailySessionsTable,
                          Attempt
                        >(
                          currentTable: table,
                          referencedTable: $$DailySessionsTableReferences
                              ._attemptsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DailySessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).attemptsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
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

typedef $$DailySessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DailySessionsTable,
      DailySession,
      $$DailySessionsTableFilterComposer,
      $$DailySessionsTableOrderingComposer,
      $$DailySessionsTableAnnotationComposer,
      $$DailySessionsTableCreateCompanionBuilder,
      $$DailySessionsTableUpdateCompanionBuilder,
      (DailySession, $$DailySessionsTableReferences),
      DailySession,
      PrefetchHooks Function({bool dailySessionItemsRefs, bool attemptsRefs})
    >;
typedef $$DailySessionItemsTableCreateCompanionBuilder =
    DailySessionItemsCompanion Function({
      Value<int> id,
      required int sessionId,
      required int orderIndex,
      required String questionId,
    });
typedef $$DailySessionItemsTableUpdateCompanionBuilder =
    DailySessionItemsCompanion Function({
      Value<int> id,
      Value<int> sessionId,
      Value<int> orderIndex,
      Value<String> questionId,
    });

final class $$DailySessionItemsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $DailySessionItemsTable,
          DailySessionItem
        > {
  $$DailySessionItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DailySessionsTable _sessionIdTable(_$AppDatabase db) =>
      db.dailySessions.createAlias(
        $_aliasNameGenerator(
          db.dailySessionItems.sessionId,
          db.dailySessions.id,
        ),
      );

  $$DailySessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<int>('session_id')!;

    final manager = $$DailySessionsTableTableManager(
      $_db,
      $_db.dailySessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $QuestionsTable _questionIdTable(_$AppDatabase db) =>
      db.questions.createAlias(
        $_aliasNameGenerator(db.dailySessionItems.questionId, db.questions.id),
      );

  $$QuestionsTableProcessedTableManager get questionId {
    final $_column = $_itemColumn<String>('question_id')!;

    final manager = $$QuestionsTableTableManager(
      $_db,
      $_db.questions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_questionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DailySessionItemsTableFilterComposer
    extends Composer<_$AppDatabase, $DailySessionItemsTable> {
  $$DailySessionItemsTableFilterComposer({
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

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  $$DailySessionsTableFilterComposer get sessionId {
    final $$DailySessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.dailySessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DailySessionsTableFilterComposer(
            $db: $db,
            $table: $db.dailySessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$QuestionsTableFilterComposer get questionId {
    final $$QuestionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.questionId,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableFilterComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DailySessionItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $DailySessionItemsTable> {
  $$DailySessionItemsTableOrderingComposer({
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

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  $$DailySessionsTableOrderingComposer get sessionId {
    final $$DailySessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.dailySessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DailySessionsTableOrderingComposer(
            $db: $db,
            $table: $db.dailySessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$QuestionsTableOrderingComposer get questionId {
    final $$QuestionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.questionId,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableOrderingComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DailySessionItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailySessionItemsTable> {
  $$DailySessionItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  $$DailySessionsTableAnnotationComposer get sessionId {
    final $$DailySessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.dailySessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DailySessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.dailySessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$QuestionsTableAnnotationComposer get questionId {
    final $$QuestionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.questionId,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableAnnotationComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DailySessionItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DailySessionItemsTable,
          DailySessionItem,
          $$DailySessionItemsTableFilterComposer,
          $$DailySessionItemsTableOrderingComposer,
          $$DailySessionItemsTableAnnotationComposer,
          $$DailySessionItemsTableCreateCompanionBuilder,
          $$DailySessionItemsTableUpdateCompanionBuilder,
          (DailySessionItem, $$DailySessionItemsTableReferences),
          DailySessionItem,
          PrefetchHooks Function({bool sessionId, bool questionId})
        > {
  $$DailySessionItemsTableTableManager(
    _$AppDatabase db,
    $DailySessionItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailySessionItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailySessionItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailySessionItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> sessionId = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<String> questionId = const Value.absent(),
              }) => DailySessionItemsCompanion(
                id: id,
                sessionId: sessionId,
                orderIndex: orderIndex,
                questionId: questionId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int sessionId,
                required int orderIndex,
                required String questionId,
              }) => DailySessionItemsCompanion.insert(
                id: id,
                sessionId: sessionId,
                orderIndex: orderIndex,
                questionId: questionId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DailySessionItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false, questionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
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
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable:
                                    $$DailySessionItemsTableReferences
                                        ._sessionIdTable(db),
                                referencedColumn:
                                    $$DailySessionItemsTableReferences
                                        ._sessionIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (questionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.questionId,
                                referencedTable:
                                    $$DailySessionItemsTableReferences
                                        ._questionIdTable(db),
                                referencedColumn:
                                    $$DailySessionItemsTableReferences
                                        ._questionIdTable(db)
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

typedef $$DailySessionItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DailySessionItemsTable,
      DailySessionItem,
      $$DailySessionItemsTableFilterComposer,
      $$DailySessionItemsTableOrderingComposer,
      $$DailySessionItemsTableAnnotationComposer,
      $$DailySessionItemsTableCreateCompanionBuilder,
      $$DailySessionItemsTableUpdateCompanionBuilder,
      (DailySessionItem, $$DailySessionItemsTableReferences),
      DailySessionItem,
      PrefetchHooks Function({bool sessionId, bool questionId})
    >;
typedef $$UserSettingsTableCreateCompanionBuilder =
    UserSettingsCompanion Function({
      Value<int> id,
      Value<String> role,
      Value<String> displayName,
      Value<String> birthDate,
      Value<String> track,
      Value<bool> notificationsEnabled,
      Value<bool> studyReminderEnabled,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$UserSettingsTableUpdateCompanionBuilder =
    UserSettingsCompanion Function({
      Value<int> id,
      Value<String> role,
      Value<String> displayName,
      Value<String> birthDate,
      Value<String> track,
      Value<bool> notificationsEnabled,
      Value<bool> studyReminderEnabled,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$UserSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $UserSettingsTable> {
  $$UserSettingsTableFilterComposer({
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

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get track => $composableBuilder(
    column: $table.track,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get notificationsEnabled => $composableBuilder(
    column: $table.notificationsEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get studyReminderEnabled => $composableBuilder(
    column: $table.studyReminderEnabled,
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

class $$UserSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $UserSettingsTable> {
  $$UserSettingsTableOrderingComposer({
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

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get track => $composableBuilder(
    column: $table.track,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get notificationsEnabled => $composableBuilder(
    column: $table.notificationsEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get studyReminderEnabled => $composableBuilder(
    column: $table.studyReminderEnabled,
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

class $$UserSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserSettingsTable> {
  $$UserSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get birthDate =>
      $composableBuilder(column: $table.birthDate, builder: (column) => column);

  GeneratedColumn<String> get track =>
      $composableBuilder(column: $table.track, builder: (column) => column);

  GeneratedColumn<bool> get notificationsEnabled => $composableBuilder(
    column: $table.notificationsEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get studyReminderEnabled => $composableBuilder(
    column: $table.studyReminderEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UserSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserSettingsTable,
          UserSetting,
          $$UserSettingsTableFilterComposer,
          $$UserSettingsTableOrderingComposer,
          $$UserSettingsTableAnnotationComposer,
          $$UserSettingsTableCreateCompanionBuilder,
          $$UserSettingsTableUpdateCompanionBuilder,
          (
            UserSetting,
            BaseReferences<_$AppDatabase, $UserSettingsTable, UserSetting>,
          ),
          UserSetting,
          PrefetchHooks Function()
        > {
  $$UserSettingsTableTableManager(_$AppDatabase db, $UserSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> birthDate = const Value.absent(),
                Value<String> track = const Value.absent(),
                Value<bool> notificationsEnabled = const Value.absent(),
                Value<bool> studyReminderEnabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => UserSettingsCompanion(
                id: id,
                role: role,
                displayName: displayName,
                birthDate: birthDate,
                track: track,
                notificationsEnabled: notificationsEnabled,
                studyReminderEnabled: studyReminderEnabled,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> birthDate = const Value.absent(),
                Value<String> track = const Value.absent(),
                Value<bool> notificationsEnabled = const Value.absent(),
                Value<bool> studyReminderEnabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => UserSettingsCompanion.insert(
                id: id,
                role: role,
                displayName: displayName,
                birthDate: birthDate,
                track: track,
                notificationsEnabled: notificationsEnabled,
                studyReminderEnabled: studyReminderEnabled,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserSettingsTable,
      UserSetting,
      $$UserSettingsTableFilterComposer,
      $$UserSettingsTableOrderingComposer,
      $$UserSettingsTableAnnotationComposer,
      $$UserSettingsTableCreateCompanionBuilder,
      $$UserSettingsTableUpdateCompanionBuilder,
      (
        UserSetting,
        BaseReferences<_$AppDatabase, $UserSettingsTable, UserSetting>,
      ),
      UserSetting,
      PrefetchHooks Function()
    >;
typedef $$SharedReportsTableCreateCompanionBuilder =
    SharedReportsCompanion Function({
      Value<int> id,
      required String source,
      required String payloadJson,
      Value<DateTime> createdAt,
    });
typedef $$SharedReportsTableUpdateCompanionBuilder =
    SharedReportsCompanion Function({
      Value<int> id,
      Value<String> source,
      Value<String> payloadJson,
      Value<DateTime> createdAt,
    });

class $$SharedReportsTableFilterComposer
    extends Composer<_$AppDatabase, $SharedReportsTable> {
  $$SharedReportsTableFilterComposer({
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

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SharedReportsTableOrderingComposer
    extends Composer<_$AppDatabase, $SharedReportsTable> {
  $$SharedReportsTableOrderingComposer({
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

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SharedReportsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SharedReportsTable> {
  $$SharedReportsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SharedReportsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SharedReportsTable,
          SharedReport,
          $$SharedReportsTableFilterComposer,
          $$SharedReportsTableOrderingComposer,
          $$SharedReportsTableAnnotationComposer,
          $$SharedReportsTableCreateCompanionBuilder,
          $$SharedReportsTableUpdateCompanionBuilder,
          (
            SharedReport,
            BaseReferences<_$AppDatabase, $SharedReportsTable, SharedReport>,
          ),
          SharedReport,
          PrefetchHooks Function()
        > {
  $$SharedReportsTableTableManager(_$AppDatabase db, $SharedReportsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SharedReportsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SharedReportsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SharedReportsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SharedReportsCompanion(
                id: id,
                source: source,
                payloadJson: payloadJson,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String source,
                required String payloadJson,
                Value<DateTime> createdAt = const Value.absent(),
              }) => SharedReportsCompanion.insert(
                id: id,
                source: source,
                payloadJson: payloadJson,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SharedReportsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SharedReportsTable,
      SharedReport,
      $$SharedReportsTableFilterComposer,
      $$SharedReportsTableOrderingComposer,
      $$SharedReportsTableAnnotationComposer,
      $$SharedReportsTableCreateCompanionBuilder,
      $$SharedReportsTableUpdateCompanionBuilder,
      (
        SharedReport,
        BaseReferences<_$AppDatabase, $SharedReportsTable, SharedReport>,
      ),
      SharedReport,
      PrefetchHooks Function()
    >;
typedef $$AttemptsTableCreateCompanionBuilder =
    AttemptsCompanion Function({
      Value<int> id,
      required String questionId,
      Value<int?> sessionId,
      required String userAnswerJson,
      required bool isCorrect,
      Value<int?> responseTimeMs,
      Value<DateTime> attemptedAt,
    });
typedef $$AttemptsTableUpdateCompanionBuilder =
    AttemptsCompanion Function({
      Value<int> id,
      Value<String> questionId,
      Value<int?> sessionId,
      Value<String> userAnswerJson,
      Value<bool> isCorrect,
      Value<int?> responseTimeMs,
      Value<DateTime> attemptedAt,
    });

final class $$AttemptsTableReferences
    extends BaseReferences<_$AppDatabase, $AttemptsTable, Attempt> {
  $$AttemptsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $QuestionsTable _questionIdTable(_$AppDatabase db) =>
      db.questions.createAlias(
        $_aliasNameGenerator(db.attempts.questionId, db.questions.id),
      );

  $$QuestionsTableProcessedTableManager get questionId {
    final $_column = $_itemColumn<String>('question_id')!;

    final manager = $$QuestionsTableTableManager(
      $_db,
      $_db.questions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_questionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $DailySessionsTable _sessionIdTable(_$AppDatabase db) =>
      db.dailySessions.createAlias(
        $_aliasNameGenerator(db.attempts.sessionId, db.dailySessions.id),
      );

  $$DailySessionsTableProcessedTableManager? get sessionId {
    final $_column = $_itemColumn<int>('session_id');
    if ($_column == null) return null;
    final manager = $$DailySessionsTableTableManager(
      $_db,
      $_db.dailySessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AttemptsTableFilterComposer
    extends Composer<_$AppDatabase, $AttemptsTable> {
  $$AttemptsTableFilterComposer({
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

  ColumnFilters<String> get userAnswerJson => $composableBuilder(
    column: $table.userAnswerJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCorrect => $composableBuilder(
    column: $table.isCorrect,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get responseTimeMs => $composableBuilder(
    column: $table.responseTimeMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get attemptedAt => $composableBuilder(
    column: $table.attemptedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$QuestionsTableFilterComposer get questionId {
    final $$QuestionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.questionId,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableFilterComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DailySessionsTableFilterComposer get sessionId {
    final $$DailySessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.dailySessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DailySessionsTableFilterComposer(
            $db: $db,
            $table: $db.dailySessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttemptsTableOrderingComposer
    extends Composer<_$AppDatabase, $AttemptsTable> {
  $$AttemptsTableOrderingComposer({
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

  ColumnOrderings<String> get userAnswerJson => $composableBuilder(
    column: $table.userAnswerJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCorrect => $composableBuilder(
    column: $table.isCorrect,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get responseTimeMs => $composableBuilder(
    column: $table.responseTimeMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get attemptedAt => $composableBuilder(
    column: $table.attemptedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$QuestionsTableOrderingComposer get questionId {
    final $$QuestionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.questionId,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableOrderingComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DailySessionsTableOrderingComposer get sessionId {
    final $$DailySessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.dailySessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DailySessionsTableOrderingComposer(
            $db: $db,
            $table: $db.dailySessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttemptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttemptsTable> {
  $$AttemptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userAnswerJson => $composableBuilder(
    column: $table.userAnswerJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCorrect =>
      $composableBuilder(column: $table.isCorrect, builder: (column) => column);

  GeneratedColumn<int> get responseTimeMs => $composableBuilder(
    column: $table.responseTimeMs,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get attemptedAt => $composableBuilder(
    column: $table.attemptedAt,
    builder: (column) => column,
  );

  $$QuestionsTableAnnotationComposer get questionId {
    final $$QuestionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.questionId,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableAnnotationComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DailySessionsTableAnnotationComposer get sessionId {
    final $$DailySessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.dailySessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DailySessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.dailySessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttemptsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttemptsTable,
          Attempt,
          $$AttemptsTableFilterComposer,
          $$AttemptsTableOrderingComposer,
          $$AttemptsTableAnnotationComposer,
          $$AttemptsTableCreateCompanionBuilder,
          $$AttemptsTableUpdateCompanionBuilder,
          (Attempt, $$AttemptsTableReferences),
          Attempt,
          PrefetchHooks Function({bool questionId, bool sessionId})
        > {
  $$AttemptsTableTableManager(_$AppDatabase db, $AttemptsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttemptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttemptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttemptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> questionId = const Value.absent(),
                Value<int?> sessionId = const Value.absent(),
                Value<String> userAnswerJson = const Value.absent(),
                Value<bool> isCorrect = const Value.absent(),
                Value<int?> responseTimeMs = const Value.absent(),
                Value<DateTime> attemptedAt = const Value.absent(),
              }) => AttemptsCompanion(
                id: id,
                questionId: questionId,
                sessionId: sessionId,
                userAnswerJson: userAnswerJson,
                isCorrect: isCorrect,
                responseTimeMs: responseTimeMs,
                attemptedAt: attemptedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String questionId,
                Value<int?> sessionId = const Value.absent(),
                required String userAnswerJson,
                required bool isCorrect,
                Value<int?> responseTimeMs = const Value.absent(),
                Value<DateTime> attemptedAt = const Value.absent(),
              }) => AttemptsCompanion.insert(
                id: id,
                questionId: questionId,
                sessionId: sessionId,
                userAnswerJson: userAnswerJson,
                isCorrect: isCorrect,
                responseTimeMs: responseTimeMs,
                attemptedAt: attemptedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AttemptsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({questionId = false, sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
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
                    if (questionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.questionId,
                                referencedTable: $$AttemptsTableReferences
                                    ._questionIdTable(db),
                                referencedColumn: $$AttemptsTableReferences
                                    ._questionIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable: $$AttemptsTableReferences
                                    ._sessionIdTable(db),
                                referencedColumn: $$AttemptsTableReferences
                                    ._sessionIdTable(db)
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

typedef $$AttemptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttemptsTable,
      Attempt,
      $$AttemptsTableFilterComposer,
      $$AttemptsTableOrderingComposer,
      $$AttemptsTableAnnotationComposer,
      $$AttemptsTableCreateCompanionBuilder,
      $$AttemptsTableUpdateCompanionBuilder,
      (Attempt, $$AttemptsTableReferences),
      Attempt,
      PrefetchHooks Function({bool questionId, bool sessionId})
    >;
typedef $$VocabMasterTableCreateCompanionBuilder =
    VocabMasterCompanion Function({
      required String id,
      required String lemma,
      Value<String?> pos,
      required String meaning,
      Value<String?> example,
      Value<String?> ipa,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$VocabMasterTableUpdateCompanionBuilder =
    VocabMasterCompanion Function({
      Value<String> id,
      Value<String> lemma,
      Value<String?> pos,
      Value<String> meaning,
      Value<String?> example,
      Value<String?> ipa,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$VocabMasterTableReferences
    extends BaseReferences<_$AppDatabase, $VocabMasterTable, VocabMasterData> {
  $$VocabMasterTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$VocabUserTable, List<VocabUserData>>
  _vocabUserRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.vocabUser,
    aliasName: $_aliasNameGenerator(db.vocabMaster.id, db.vocabUser.vocabId),
  );

  $$VocabUserTableProcessedTableManager get vocabUserRefs {
    final manager = $$VocabUserTableTableManager(
      $_db,
      $_db.vocabUser,
    ).filter((f) => f.vocabId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_vocabUserRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$VocabSrsStateTable, List<VocabSrsStateData>>
  _vocabSrsStateRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.vocabSrsState,
    aliasName: $_aliasNameGenerator(
      db.vocabMaster.id,
      db.vocabSrsState.vocabId,
    ),
  );

  $$VocabSrsStateTableProcessedTableManager get vocabSrsStateRefs {
    final manager = $$VocabSrsStateTableTableManager(
      $_db,
      $_db.vocabSrsState,
    ).filter((f) => f.vocabId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_vocabSrsStateRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$VocabMasterTableFilterComposer
    extends Composer<_$AppDatabase, $VocabMasterTable> {
  $$VocabMasterTableFilterComposer({
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

  ColumnFilters<String> get lemma => $composableBuilder(
    column: $table.lemma,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pos => $composableBuilder(
    column: $table.pos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get meaning => $composableBuilder(
    column: $table.meaning,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get example => $composableBuilder(
    column: $table.example,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ipa => $composableBuilder(
    column: $table.ipa,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> vocabUserRefs(
    Expression<bool> Function($$VocabUserTableFilterComposer f) f,
  ) {
    final $$VocabUserTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.vocabUser,
      getReferencedColumn: (t) => t.vocabId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VocabUserTableFilterComposer(
            $db: $db,
            $table: $db.vocabUser,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> vocabSrsStateRefs(
    Expression<bool> Function($$VocabSrsStateTableFilterComposer f) f,
  ) {
    final $$VocabSrsStateTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.vocabSrsState,
      getReferencedColumn: (t) => t.vocabId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VocabSrsStateTableFilterComposer(
            $db: $db,
            $table: $db.vocabSrsState,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VocabMasterTableOrderingComposer
    extends Composer<_$AppDatabase, $VocabMasterTable> {
  $$VocabMasterTableOrderingComposer({
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

  ColumnOrderings<String> get lemma => $composableBuilder(
    column: $table.lemma,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pos => $composableBuilder(
    column: $table.pos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meaning => $composableBuilder(
    column: $table.meaning,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get example => $composableBuilder(
    column: $table.example,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ipa => $composableBuilder(
    column: $table.ipa,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VocabMasterTableAnnotationComposer
    extends Composer<_$AppDatabase, $VocabMasterTable> {
  $$VocabMasterTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get lemma =>
      $composableBuilder(column: $table.lemma, builder: (column) => column);

  GeneratedColumn<String> get pos =>
      $composableBuilder(column: $table.pos, builder: (column) => column);

  GeneratedColumn<String> get meaning =>
      $composableBuilder(column: $table.meaning, builder: (column) => column);

  GeneratedColumn<String> get example =>
      $composableBuilder(column: $table.example, builder: (column) => column);

  GeneratedColumn<String> get ipa =>
      $composableBuilder(column: $table.ipa, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> vocabUserRefs<T extends Object>(
    Expression<T> Function($$VocabUserTableAnnotationComposer a) f,
  ) {
    final $$VocabUserTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.vocabUser,
      getReferencedColumn: (t) => t.vocabId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VocabUserTableAnnotationComposer(
            $db: $db,
            $table: $db.vocabUser,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> vocabSrsStateRefs<T extends Object>(
    Expression<T> Function($$VocabSrsStateTableAnnotationComposer a) f,
  ) {
    final $$VocabSrsStateTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.vocabSrsState,
      getReferencedColumn: (t) => t.vocabId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VocabSrsStateTableAnnotationComposer(
            $db: $db,
            $table: $db.vocabSrsState,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VocabMasterTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VocabMasterTable,
          VocabMasterData,
          $$VocabMasterTableFilterComposer,
          $$VocabMasterTableOrderingComposer,
          $$VocabMasterTableAnnotationComposer,
          $$VocabMasterTableCreateCompanionBuilder,
          $$VocabMasterTableUpdateCompanionBuilder,
          (VocabMasterData, $$VocabMasterTableReferences),
          VocabMasterData,
          PrefetchHooks Function({bool vocabUserRefs, bool vocabSrsStateRefs})
        > {
  $$VocabMasterTableTableManager(_$AppDatabase db, $VocabMasterTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VocabMasterTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VocabMasterTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VocabMasterTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> lemma = const Value.absent(),
                Value<String?> pos = const Value.absent(),
                Value<String> meaning = const Value.absent(),
                Value<String?> example = const Value.absent(),
                Value<String?> ipa = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VocabMasterCompanion(
                id: id,
                lemma: lemma,
                pos: pos,
                meaning: meaning,
                example: example,
                ipa: ipa,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String lemma,
                Value<String?> pos = const Value.absent(),
                required String meaning,
                Value<String?> example = const Value.absent(),
                Value<String?> ipa = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VocabMasterCompanion.insert(
                id: id,
                lemma: lemma,
                pos: pos,
                meaning: meaning,
                example: example,
                ipa: ipa,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$VocabMasterTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({vocabUserRefs = false, vocabSrsStateRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (vocabUserRefs) db.vocabUser,
                    if (vocabSrsStateRefs) db.vocabSrsState,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (vocabUserRefs)
                        await $_getPrefetchedData<
                          VocabMasterData,
                          $VocabMasterTable,
                          VocabUserData
                        >(
                          currentTable: table,
                          referencedTable: $$VocabMasterTableReferences
                              ._vocabUserRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$VocabMasterTableReferences(
                                db,
                                table,
                                p0,
                              ).vocabUserRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.vocabId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (vocabSrsStateRefs)
                        await $_getPrefetchedData<
                          VocabMasterData,
                          $VocabMasterTable,
                          VocabSrsStateData
                        >(
                          currentTable: table,
                          referencedTable: $$VocabMasterTableReferences
                              ._vocabSrsStateRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$VocabMasterTableReferences(
                                db,
                                table,
                                p0,
                              ).vocabSrsStateRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.vocabId == item.id,
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

typedef $$VocabMasterTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VocabMasterTable,
      VocabMasterData,
      $$VocabMasterTableFilterComposer,
      $$VocabMasterTableOrderingComposer,
      $$VocabMasterTableAnnotationComposer,
      $$VocabMasterTableCreateCompanionBuilder,
      $$VocabMasterTableUpdateCompanionBuilder,
      (VocabMasterData, $$VocabMasterTableReferences),
      VocabMasterData,
      PrefetchHooks Function({bool vocabUserRefs, bool vocabSrsStateRefs})
    >;
typedef $$VocabUserTableCreateCompanionBuilder =
    VocabUserCompanion Function({
      Value<int> id,
      required String vocabId,
      Value<int> familiarity,
      Value<bool> isBookmarked,
      Value<DateTime?> lastSeenAt,
      Value<DateTime> updatedAt,
    });
typedef $$VocabUserTableUpdateCompanionBuilder =
    VocabUserCompanion Function({
      Value<int> id,
      Value<String> vocabId,
      Value<int> familiarity,
      Value<bool> isBookmarked,
      Value<DateTime?> lastSeenAt,
      Value<DateTime> updatedAt,
    });

final class $$VocabUserTableReferences
    extends BaseReferences<_$AppDatabase, $VocabUserTable, VocabUserData> {
  $$VocabUserTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $VocabMasterTable _vocabIdTable(_$AppDatabase db) =>
      db.vocabMaster.createAlias(
        $_aliasNameGenerator(db.vocabUser.vocabId, db.vocabMaster.id),
      );

  $$VocabMasterTableProcessedTableManager get vocabId {
    final $_column = $_itemColumn<String>('vocab_id')!;

    final manager = $$VocabMasterTableTableManager(
      $_db,
      $_db.vocabMaster,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_vocabIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$VocabUserTableFilterComposer
    extends Composer<_$AppDatabase, $VocabUserTable> {
  $$VocabUserTableFilterComposer({
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

  ColumnFilters<int> get familiarity => $composableBuilder(
    column: $table.familiarity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isBookmarked => $composableBuilder(
    column: $table.isBookmarked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$VocabMasterTableFilterComposer get vocabId {
    final $$VocabMasterTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vocabId,
      referencedTable: $db.vocabMaster,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VocabMasterTableFilterComposer(
            $db: $db,
            $table: $db.vocabMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VocabUserTableOrderingComposer
    extends Composer<_$AppDatabase, $VocabUserTable> {
  $$VocabUserTableOrderingComposer({
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

  ColumnOrderings<int> get familiarity => $composableBuilder(
    column: $table.familiarity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isBookmarked => $composableBuilder(
    column: $table.isBookmarked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$VocabMasterTableOrderingComposer get vocabId {
    final $$VocabMasterTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vocabId,
      referencedTable: $db.vocabMaster,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VocabMasterTableOrderingComposer(
            $db: $db,
            $table: $db.vocabMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VocabUserTableAnnotationComposer
    extends Composer<_$AppDatabase, $VocabUserTable> {
  $$VocabUserTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get familiarity => $composableBuilder(
    column: $table.familiarity,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isBookmarked => $composableBuilder(
    column: $table.isBookmarked,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$VocabMasterTableAnnotationComposer get vocabId {
    final $$VocabMasterTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vocabId,
      referencedTable: $db.vocabMaster,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VocabMasterTableAnnotationComposer(
            $db: $db,
            $table: $db.vocabMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VocabUserTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VocabUserTable,
          VocabUserData,
          $$VocabUserTableFilterComposer,
          $$VocabUserTableOrderingComposer,
          $$VocabUserTableAnnotationComposer,
          $$VocabUserTableCreateCompanionBuilder,
          $$VocabUserTableUpdateCompanionBuilder,
          (VocabUserData, $$VocabUserTableReferences),
          VocabUserData,
          PrefetchHooks Function({bool vocabId})
        > {
  $$VocabUserTableTableManager(_$AppDatabase db, $VocabUserTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VocabUserTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VocabUserTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VocabUserTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> vocabId = const Value.absent(),
                Value<int> familiarity = const Value.absent(),
                Value<bool> isBookmarked = const Value.absent(),
                Value<DateTime?> lastSeenAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => VocabUserCompanion(
                id: id,
                vocabId: vocabId,
                familiarity: familiarity,
                isBookmarked: isBookmarked,
                lastSeenAt: lastSeenAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String vocabId,
                Value<int> familiarity = const Value.absent(),
                Value<bool> isBookmarked = const Value.absent(),
                Value<DateTime?> lastSeenAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => VocabUserCompanion.insert(
                id: id,
                vocabId: vocabId,
                familiarity: familiarity,
                isBookmarked: isBookmarked,
                lastSeenAt: lastSeenAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$VocabUserTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({vocabId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
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
                    if (vocabId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.vocabId,
                                referencedTable: $$VocabUserTableReferences
                                    ._vocabIdTable(db),
                                referencedColumn: $$VocabUserTableReferences
                                    ._vocabIdTable(db)
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

typedef $$VocabUserTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VocabUserTable,
      VocabUserData,
      $$VocabUserTableFilterComposer,
      $$VocabUserTableOrderingComposer,
      $$VocabUserTableAnnotationComposer,
      $$VocabUserTableCreateCompanionBuilder,
      $$VocabUserTableUpdateCompanionBuilder,
      (VocabUserData, $$VocabUserTableReferences),
      VocabUserData,
      PrefetchHooks Function({bool vocabId})
    >;
typedef $$VocabSrsStateTableCreateCompanionBuilder =
    VocabSrsStateCompanion Function({
      Value<int> id,
      required String vocabId,
      Value<DateTime> dueAt,
      Value<int> intervalDays,
      Value<double> easeFactor,
      Value<int> repetition,
      Value<int> lapses,
      Value<bool> suspended,
      Value<DateTime> updatedAt,
    });
typedef $$VocabSrsStateTableUpdateCompanionBuilder =
    VocabSrsStateCompanion Function({
      Value<int> id,
      Value<String> vocabId,
      Value<DateTime> dueAt,
      Value<int> intervalDays,
      Value<double> easeFactor,
      Value<int> repetition,
      Value<int> lapses,
      Value<bool> suspended,
      Value<DateTime> updatedAt,
    });

final class $$VocabSrsStateTableReferences
    extends
        BaseReferences<_$AppDatabase, $VocabSrsStateTable, VocabSrsStateData> {
  $$VocabSrsStateTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $VocabMasterTable _vocabIdTable(_$AppDatabase db) =>
      db.vocabMaster.createAlias(
        $_aliasNameGenerator(db.vocabSrsState.vocabId, db.vocabMaster.id),
      );

  $$VocabMasterTableProcessedTableManager get vocabId {
    final $_column = $_itemColumn<String>('vocab_id')!;

    final manager = $$VocabMasterTableTableManager(
      $_db,
      $_db.vocabMaster,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_vocabIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$VocabSrsStateTableFilterComposer
    extends Composer<_$AppDatabase, $VocabSrsStateTable> {
  $$VocabSrsStateTableFilterComposer({
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

  ColumnFilters<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get easeFactor => $composableBuilder(
    column: $table.easeFactor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repetition => $composableBuilder(
    column: $table.repetition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lapses => $composableBuilder(
    column: $table.lapses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get suspended => $composableBuilder(
    column: $table.suspended,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$VocabMasterTableFilterComposer get vocabId {
    final $$VocabMasterTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vocabId,
      referencedTable: $db.vocabMaster,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VocabMasterTableFilterComposer(
            $db: $db,
            $table: $db.vocabMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VocabSrsStateTableOrderingComposer
    extends Composer<_$AppDatabase, $VocabSrsStateTable> {
  $$VocabSrsStateTableOrderingComposer({
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

  ColumnOrderings<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get easeFactor => $composableBuilder(
    column: $table.easeFactor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repetition => $composableBuilder(
    column: $table.repetition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lapses => $composableBuilder(
    column: $table.lapses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get suspended => $composableBuilder(
    column: $table.suspended,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$VocabMasterTableOrderingComposer get vocabId {
    final $$VocabMasterTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vocabId,
      referencedTable: $db.vocabMaster,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VocabMasterTableOrderingComposer(
            $db: $db,
            $table: $db.vocabMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VocabSrsStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $VocabSrsStateTable> {
  $$VocabSrsStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => column,
  );

  GeneratedColumn<double> get easeFactor => $composableBuilder(
    column: $table.easeFactor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get repetition => $composableBuilder(
    column: $table.repetition,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lapses =>
      $composableBuilder(column: $table.lapses, builder: (column) => column);

  GeneratedColumn<bool> get suspended =>
      $composableBuilder(column: $table.suspended, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$VocabMasterTableAnnotationComposer get vocabId {
    final $$VocabMasterTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vocabId,
      referencedTable: $db.vocabMaster,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VocabMasterTableAnnotationComposer(
            $db: $db,
            $table: $db.vocabMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VocabSrsStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VocabSrsStateTable,
          VocabSrsStateData,
          $$VocabSrsStateTableFilterComposer,
          $$VocabSrsStateTableOrderingComposer,
          $$VocabSrsStateTableAnnotationComposer,
          $$VocabSrsStateTableCreateCompanionBuilder,
          $$VocabSrsStateTableUpdateCompanionBuilder,
          (VocabSrsStateData, $$VocabSrsStateTableReferences),
          VocabSrsStateData,
          PrefetchHooks Function({bool vocabId})
        > {
  $$VocabSrsStateTableTableManager(_$AppDatabase db, $VocabSrsStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VocabSrsStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VocabSrsStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VocabSrsStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> vocabId = const Value.absent(),
                Value<DateTime> dueAt = const Value.absent(),
                Value<int> intervalDays = const Value.absent(),
                Value<double> easeFactor = const Value.absent(),
                Value<int> repetition = const Value.absent(),
                Value<int> lapses = const Value.absent(),
                Value<bool> suspended = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => VocabSrsStateCompanion(
                id: id,
                vocabId: vocabId,
                dueAt: dueAt,
                intervalDays: intervalDays,
                easeFactor: easeFactor,
                repetition: repetition,
                lapses: lapses,
                suspended: suspended,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String vocabId,
                Value<DateTime> dueAt = const Value.absent(),
                Value<int> intervalDays = const Value.absent(),
                Value<double> easeFactor = const Value.absent(),
                Value<int> repetition = const Value.absent(),
                Value<int> lapses = const Value.absent(),
                Value<bool> suspended = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => VocabSrsStateCompanion.insert(
                id: id,
                vocabId: vocabId,
                dueAt: dueAt,
                intervalDays: intervalDays,
                easeFactor: easeFactor,
                repetition: repetition,
                lapses: lapses,
                suspended: suspended,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$VocabSrsStateTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({vocabId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
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
                    if (vocabId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.vocabId,
                                referencedTable: $$VocabSrsStateTableReferences
                                    ._vocabIdTable(db),
                                referencedColumn: $$VocabSrsStateTableReferences
                                    ._vocabIdTable(db)
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

typedef $$VocabSrsStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VocabSrsStateTable,
      VocabSrsStateData,
      $$VocabSrsStateTableFilterComposer,
      $$VocabSrsStateTableOrderingComposer,
      $$VocabSrsStateTableAnnotationComposer,
      $$VocabSrsStateTableCreateCompanionBuilder,
      $$VocabSrsStateTableUpdateCompanionBuilder,
      (VocabSrsStateData, $$VocabSrsStateTableReferences),
      VocabSrsStateData,
      PrefetchHooks Function({bool vocabId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ContentPacksTableTableManager get contentPacks =>
      $$ContentPacksTableTableManager(_db, _db.contentPacks);
  $$PassagesTableTableManager get passages =>
      $$PassagesTableTableManager(_db, _db.passages);
  $$ScriptsTableTableManager get scripts =>
      $$ScriptsTableTableManager(_db, _db.scripts);
  $$QuestionsTableTableManager get questions =>
      $$QuestionsTableTableManager(_db, _db.questions);
  $$ExplanationsTableTableManager get explanations =>
      $$ExplanationsTableTableManager(_db, _db.explanations);
  $$DailySessionsTableTableManager get dailySessions =>
      $$DailySessionsTableTableManager(_db, _db.dailySessions);
  $$DailySessionItemsTableTableManager get dailySessionItems =>
      $$DailySessionItemsTableTableManager(_db, _db.dailySessionItems);
  $$UserSettingsTableTableManager get userSettings =>
      $$UserSettingsTableTableManager(_db, _db.userSettings);
  $$SharedReportsTableTableManager get sharedReports =>
      $$SharedReportsTableTableManager(_db, _db.sharedReports);
  $$AttemptsTableTableManager get attempts =>
      $$AttemptsTableTableManager(_db, _db.attempts);
  $$VocabMasterTableTableManager get vocabMaster =>
      $$VocabMasterTableTableManager(_db, _db.vocabMaster);
  $$VocabUserTableTableManager get vocabUser =>
      $$VocabUserTableTableManager(_db, _db.vocabUser);
  $$VocabSrsStateTableTableManager get vocabSrsState =>
      $$VocabSrsStateTableTableManager(_db, _db.vocabSrsState);
}
