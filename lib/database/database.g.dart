// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $BilibiliVideosTable extends BilibiliVideos
    with TableInfo<$BilibiliVideosTable, BilibiliVideo> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BilibiliVideosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _bvidMeta = const VerificationMeta('bvid');
  @override
  late final GeneratedColumn<String> bvid = GeneratedColumn<String>(
      'bvid', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _aidMeta = const VerificationMeta('aid');
  @override
  late final GeneratedColumn<int> aid = GeneratedColumn<int>(
      'aid', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _cidMeta = const VerificationMeta('cid');
  @override
  late final GeneratedColumn<int> cid = GeneratedColumn<int>(
      'cid', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _coverUrlMeta =
      const VerificationMeta('coverUrl');
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
      'cover_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _durationMeta =
      const VerificationMeta('duration');
  @override
  late final GeneratedColumn<int> duration = GeneratedColumn<int>(
      'duration', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
      'author', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _authorMidMeta =
      const VerificationMeta('authorMid');
  @override
  late final GeneratedColumn<int> authorMid = GeneratedColumn<int>(
      'author_mid', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _publishDateMeta =
      const VerificationMeta('publishDate');
  @override
  late final GeneratedColumn<DateTime> publishDate = GeneratedColumn<DateTime>(
      'publish_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isMultiPageMeta =
      const VerificationMeta('isMultiPage');
  @override
  late final GeneratedColumn<bool> isMultiPage = GeneratedColumn<bool>(
      'is_multi_page', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_multi_page" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _pageCountMeta =
      const VerificationMeta('pageCount');
  @override
  late final GeneratedColumn<int> pageCount = GeneratedColumn<int>(
      'page_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        bvid,
        aid,
        cid,
        title,
        coverUrl,
        duration,
        author,
        authorMid,
        publishDate,
        description,
        isMultiPage,
        pageCount,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bilibili_videos';
  @override
  VerificationContext validateIntegrity(Insertable<BilibiliVideo> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('bvid')) {
      context.handle(
          _bvidMeta, bvid.isAcceptableOrUnknown(data['bvid']!, _bvidMeta));
    } else if (isInserting) {
      context.missing(_bvidMeta);
    }
    if (data.containsKey('aid')) {
      context.handle(
          _aidMeta, aid.isAcceptableOrUnknown(data['aid']!, _aidMeta));
    } else if (isInserting) {
      context.missing(_aidMeta);
    }
    if (data.containsKey('cid')) {
      context.handle(
          _cidMeta, cid.isAcceptableOrUnknown(data['cid']!, _cidMeta));
    } else if (isInserting) {
      context.missing(_cidMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('cover_url')) {
      context.handle(_coverUrlMeta,
          coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta));
    }
    if (data.containsKey('duration')) {
      context.handle(_durationMeta,
          duration.isAcceptableOrUnknown(data['duration']!, _durationMeta));
    } else if (isInserting) {
      context.missing(_durationMeta);
    }
    if (data.containsKey('author')) {
      context.handle(_authorMeta,
          author.isAcceptableOrUnknown(data['author']!, _authorMeta));
    } else if (isInserting) {
      context.missing(_authorMeta);
    }
    if (data.containsKey('author_mid')) {
      context.handle(_authorMidMeta,
          authorMid.isAcceptableOrUnknown(data['author_mid']!, _authorMidMeta));
    } else if (isInserting) {
      context.missing(_authorMidMeta);
    }
    if (data.containsKey('publish_date')) {
      context.handle(
          _publishDateMeta,
          publishDate.isAcceptableOrUnknown(
              data['publish_date']!, _publishDateMeta));
    } else if (isInserting) {
      context.missing(_publishDateMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('is_multi_page')) {
      context.handle(
          _isMultiPageMeta,
          isMultiPage.isAcceptableOrUnknown(
              data['is_multi_page']!, _isMultiPageMeta));
    }
    if (data.containsKey('page_count')) {
      context.handle(_pageCountMeta,
          pageCount.isAcceptableOrUnknown(data['page_count']!, _pageCountMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BilibiliVideo map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BilibiliVideo(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      bvid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bvid'])!,
      aid: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}aid'])!,
      cid: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}cid'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      coverUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cover_url']),
      duration: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration'])!,
      author: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}author'])!,
      authorMid: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}author_mid'])!,
      publishDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}publish_date'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      isMultiPage: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_multi_page'])!,
      pageCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}page_count'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $BilibiliVideosTable createAlias(String alias) {
    return $BilibiliVideosTable(attachedDatabase, alias);
  }
}

class BilibiliVideo extends DataClass implements Insertable<BilibiliVideo> {
  final int id;
  final String bvid;
  final int aid;
  final int cid;
  final String title;
  final String? coverUrl;
  final int duration;
  final String author;
  final int authorMid;
  final DateTime publishDate;
  final String? description;
  final bool isMultiPage;
  final int pageCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  const BilibiliVideo(
      {required this.id,
      required this.bvid,
      required this.aid,
      required this.cid,
      required this.title,
      this.coverUrl,
      required this.duration,
      required this.author,
      required this.authorMid,
      required this.publishDate,
      this.description,
      required this.isMultiPage,
      required this.pageCount,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['bvid'] = Variable<String>(bvid);
    map['aid'] = Variable<int>(aid);
    map['cid'] = Variable<int>(cid);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    map['duration'] = Variable<int>(duration);
    map['author'] = Variable<String>(author);
    map['author_mid'] = Variable<int>(authorMid);
    map['publish_date'] = Variable<DateTime>(publishDate);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['is_multi_page'] = Variable<bool>(isMultiPage);
    map['page_count'] = Variable<int>(pageCount);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BilibiliVideosCompanion toCompanion(bool nullToAbsent) {
    return BilibiliVideosCompanion(
      id: Value(id),
      bvid: Value(bvid),
      aid: Value(aid),
      cid: Value(cid),
      title: Value(title),
      coverUrl: coverUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverUrl),
      duration: Value(duration),
      author: Value(author),
      authorMid: Value(authorMid),
      publishDate: Value(publishDate),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      isMultiPage: Value(isMultiPage),
      pageCount: Value(pageCount),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory BilibiliVideo.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BilibiliVideo(
      id: serializer.fromJson<int>(json['id']),
      bvid: serializer.fromJson<String>(json['bvid']),
      aid: serializer.fromJson<int>(json['aid']),
      cid: serializer.fromJson<int>(json['cid']),
      title: serializer.fromJson<String>(json['title']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      duration: serializer.fromJson<int>(json['duration']),
      author: serializer.fromJson<String>(json['author']),
      authorMid: serializer.fromJson<int>(json['authorMid']),
      publishDate: serializer.fromJson<DateTime>(json['publishDate']),
      description: serializer.fromJson<String?>(json['description']),
      isMultiPage: serializer.fromJson<bool>(json['isMultiPage']),
      pageCount: serializer.fromJson<int>(json['pageCount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bvid': serializer.toJson<String>(bvid),
      'aid': serializer.toJson<int>(aid),
      'cid': serializer.toJson<int>(cid),
      'title': serializer.toJson<String>(title),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'duration': serializer.toJson<int>(duration),
      'author': serializer.toJson<String>(author),
      'authorMid': serializer.toJson<int>(authorMid),
      'publishDate': serializer.toJson<DateTime>(publishDate),
      'description': serializer.toJson<String?>(description),
      'isMultiPage': serializer.toJson<bool>(isMultiPage),
      'pageCount': serializer.toJson<int>(pageCount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  BilibiliVideo copyWith(
          {int? id,
          String? bvid,
          int? aid,
          int? cid,
          String? title,
          Value<String?> coverUrl = const Value.absent(),
          int? duration,
          String? author,
          int? authorMid,
          DateTime? publishDate,
          Value<String?> description = const Value.absent(),
          bool? isMultiPage,
          int? pageCount,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      BilibiliVideo(
        id: id ?? this.id,
        bvid: bvid ?? this.bvid,
        aid: aid ?? this.aid,
        cid: cid ?? this.cid,
        title: title ?? this.title,
        coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
        duration: duration ?? this.duration,
        author: author ?? this.author,
        authorMid: authorMid ?? this.authorMid,
        publishDate: publishDate ?? this.publishDate,
        description: description.present ? description.value : this.description,
        isMultiPage: isMultiPage ?? this.isMultiPage,
        pageCount: pageCount ?? this.pageCount,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  BilibiliVideo copyWithCompanion(BilibiliVideosCompanion data) {
    return BilibiliVideo(
      id: data.id.present ? data.id.value : this.id,
      bvid: data.bvid.present ? data.bvid.value : this.bvid,
      aid: data.aid.present ? data.aid.value : this.aid,
      cid: data.cid.present ? data.cid.value : this.cid,
      title: data.title.present ? data.title.value : this.title,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      duration: data.duration.present ? data.duration.value : this.duration,
      author: data.author.present ? data.author.value : this.author,
      authorMid: data.authorMid.present ? data.authorMid.value : this.authorMid,
      publishDate:
          data.publishDate.present ? data.publishDate.value : this.publishDate,
      description:
          data.description.present ? data.description.value : this.description,
      isMultiPage:
          data.isMultiPage.present ? data.isMultiPage.value : this.isMultiPage,
      pageCount: data.pageCount.present ? data.pageCount.value : this.pageCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BilibiliVideo(')
          ..write('id: $id, ')
          ..write('bvid: $bvid, ')
          ..write('aid: $aid, ')
          ..write('cid: $cid, ')
          ..write('title: $title, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('duration: $duration, ')
          ..write('author: $author, ')
          ..write('authorMid: $authorMid, ')
          ..write('publishDate: $publishDate, ')
          ..write('description: $description, ')
          ..write('isMultiPage: $isMultiPage, ')
          ..write('pageCount: $pageCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      bvid,
      aid,
      cid,
      title,
      coverUrl,
      duration,
      author,
      authorMid,
      publishDate,
      description,
      isMultiPage,
      pageCount,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BilibiliVideo &&
          other.id == this.id &&
          other.bvid == this.bvid &&
          other.aid == this.aid &&
          other.cid == this.cid &&
          other.title == this.title &&
          other.coverUrl == this.coverUrl &&
          other.duration == this.duration &&
          other.author == this.author &&
          other.authorMid == this.authorMid &&
          other.publishDate == this.publishDate &&
          other.description == this.description &&
          other.isMultiPage == this.isMultiPage &&
          other.pageCount == this.pageCount &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BilibiliVideosCompanion extends UpdateCompanion<BilibiliVideo> {
  final Value<int> id;
  final Value<String> bvid;
  final Value<int> aid;
  final Value<int> cid;
  final Value<String> title;
  final Value<String?> coverUrl;
  final Value<int> duration;
  final Value<String> author;
  final Value<int> authorMid;
  final Value<DateTime> publishDate;
  final Value<String?> description;
  final Value<bool> isMultiPage;
  final Value<int> pageCount;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const BilibiliVideosCompanion({
    this.id = const Value.absent(),
    this.bvid = const Value.absent(),
    this.aid = const Value.absent(),
    this.cid = const Value.absent(),
    this.title = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.duration = const Value.absent(),
    this.author = const Value.absent(),
    this.authorMid = const Value.absent(),
    this.publishDate = const Value.absent(),
    this.description = const Value.absent(),
    this.isMultiPage = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  BilibiliVideosCompanion.insert({
    this.id = const Value.absent(),
    required String bvid,
    required int aid,
    required int cid,
    required String title,
    this.coverUrl = const Value.absent(),
    required int duration,
    required String author,
    required int authorMid,
    required DateTime publishDate,
    this.description = const Value.absent(),
    this.isMultiPage = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : bvid = Value(bvid),
        aid = Value(aid),
        cid = Value(cid),
        title = Value(title),
        duration = Value(duration),
        author = Value(author),
        authorMid = Value(authorMid),
        publishDate = Value(publishDate);
  static Insertable<BilibiliVideo> custom({
    Expression<int>? id,
    Expression<String>? bvid,
    Expression<int>? aid,
    Expression<int>? cid,
    Expression<String>? title,
    Expression<String>? coverUrl,
    Expression<int>? duration,
    Expression<String>? author,
    Expression<int>? authorMid,
    Expression<DateTime>? publishDate,
    Expression<String>? description,
    Expression<bool>? isMultiPage,
    Expression<int>? pageCount,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bvid != null) 'bvid': bvid,
      if (aid != null) 'aid': aid,
      if (cid != null) 'cid': cid,
      if (title != null) 'title': title,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (duration != null) 'duration': duration,
      if (author != null) 'author': author,
      if (authorMid != null) 'author_mid': authorMid,
      if (publishDate != null) 'publish_date': publishDate,
      if (description != null) 'description': description,
      if (isMultiPage != null) 'is_multi_page': isMultiPage,
      if (pageCount != null) 'page_count': pageCount,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  BilibiliVideosCompanion copyWith(
      {Value<int>? id,
      Value<String>? bvid,
      Value<int>? aid,
      Value<int>? cid,
      Value<String>? title,
      Value<String?>? coverUrl,
      Value<int>? duration,
      Value<String>? author,
      Value<int>? authorMid,
      Value<DateTime>? publishDate,
      Value<String?>? description,
      Value<bool>? isMultiPage,
      Value<int>? pageCount,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt}) {
    return BilibiliVideosCompanion(
      id: id ?? this.id,
      bvid: bvid ?? this.bvid,
      aid: aid ?? this.aid,
      cid: cid ?? this.cid,
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
      duration: duration ?? this.duration,
      author: author ?? this.author,
      authorMid: authorMid ?? this.authorMid,
      publishDate: publishDate ?? this.publishDate,
      description: description ?? this.description,
      isMultiPage: isMultiPage ?? this.isMultiPage,
      pageCount: pageCount ?? this.pageCount,
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
    if (bvid.present) {
      map['bvid'] = Variable<String>(bvid.value);
    }
    if (aid.present) {
      map['aid'] = Variable<int>(aid.value);
    }
    if (cid.present) {
      map['cid'] = Variable<int>(cid.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (duration.present) {
      map['duration'] = Variable<int>(duration.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (authorMid.present) {
      map['author_mid'] = Variable<int>(authorMid.value);
    }
    if (publishDate.present) {
      map['publish_date'] = Variable<DateTime>(publishDate.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (isMultiPage.present) {
      map['is_multi_page'] = Variable<bool>(isMultiPage.value);
    }
    if (pageCount.present) {
      map['page_count'] = Variable<int>(pageCount.value);
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
    return (StringBuffer('BilibiliVideosCompanion(')
          ..write('id: $id, ')
          ..write('bvid: $bvid, ')
          ..write('aid: $aid, ')
          ..write('cid: $cid, ')
          ..write('title: $title, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('duration: $duration, ')
          ..write('author: $author, ')
          ..write('authorMid: $authorMid, ')
          ..write('publishDate: $publishDate, ')
          ..write('description: $description, ')
          ..write('isMultiPage: $isMultiPage, ')
          ..write('pageCount: $pageCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $BilibiliFavoritesTable extends BilibiliFavorites
    with TableInfo<$BilibiliFavoritesTable, BilibiliFavorite> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BilibiliFavoritesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _remoteIdMeta =
      const VerificationMeta('remoteId');
  @override
  late final GeneratedColumn<int> remoteId = GeneratedColumn<int>(
      'remote_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _coverUrlMeta =
      const VerificationMeta('coverUrl');
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
      'cover_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _mediaCountMeta =
      const VerificationMeta('mediaCount');
  @override
  late final GeneratedColumn<int> mediaCount = GeneratedColumn<int>(
      'media_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
      'synced_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _isAddedToLibraryMeta =
      const VerificationMeta('isAddedToLibrary');
  @override
  late final GeneratedColumn<bool> isAddedToLibrary = GeneratedColumn<bool>(
      'is_added_to_library', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_added_to_library" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isLocalMeta =
      const VerificationMeta('isLocal');
  @override
  late final GeneratedColumn<bool> isLocal = GeneratedColumn<bool>(
      'is_local', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_local" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        remoteId,
        title,
        description,
        coverUrl,
        mediaCount,
        syncedAt,
        createdAt,
        isAddedToLibrary,
        isLocal
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bilibili_favorites';
  @override
  VerificationContext validateIntegrity(Insertable<BilibiliFavorite> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('remote_id')) {
      context.handle(_remoteIdMeta,
          remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta));
    } else if (isInserting) {
      context.missing(_remoteIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('cover_url')) {
      context.handle(_coverUrlMeta,
          coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta));
    }
    if (data.containsKey('media_count')) {
      context.handle(
          _mediaCountMeta,
          mediaCount.isAcceptableOrUnknown(
              data['media_count']!, _mediaCountMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('is_added_to_library')) {
      context.handle(
          _isAddedToLibraryMeta,
          isAddedToLibrary.isAcceptableOrUnknown(
              data['is_added_to_library']!, _isAddedToLibraryMeta));
    }
    if (data.containsKey('is_local')) {
      context.handle(_isLocalMeta,
          isLocal.isAcceptableOrUnknown(data['is_local']!, _isLocalMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BilibiliFavorite map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BilibiliFavorite(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      remoteId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}remote_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      coverUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cover_url']),
      mediaCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}media_count'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}synced_at'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      isAddedToLibrary: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}is_added_to_library'])!,
      isLocal: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_local'])!,
    );
  }

  @override
  $BilibiliFavoritesTable createAlias(String alias) {
    return $BilibiliFavoritesTable(attachedDatabase, alias);
  }
}

class BilibiliFavorite extends DataClass
    implements Insertable<BilibiliFavorite> {
  final int id;
  final int remoteId;
  final String title;
  final String? description;
  final String? coverUrl;
  final int mediaCount;
  final DateTime syncedAt;
  final DateTime createdAt;
  final bool isAddedToLibrary;
  final bool isLocal;
  const BilibiliFavorite(
      {required this.id,
      required this.remoteId,
      required this.title,
      this.description,
      this.coverUrl,
      required this.mediaCount,
      required this.syncedAt,
      required this.createdAt,
      required this.isAddedToLibrary,
      required this.isLocal});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['remote_id'] = Variable<int>(remoteId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    map['media_count'] = Variable<int>(mediaCount);
    map['synced_at'] = Variable<DateTime>(syncedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['is_added_to_library'] = Variable<bool>(isAddedToLibrary);
    map['is_local'] = Variable<bool>(isLocal);
    return map;
  }

  BilibiliFavoritesCompanion toCompanion(bool nullToAbsent) {
    return BilibiliFavoritesCompanion(
      id: Value(id),
      remoteId: Value(remoteId),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      coverUrl: coverUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverUrl),
      mediaCount: Value(mediaCount),
      syncedAt: Value(syncedAt),
      createdAt: Value(createdAt),
      isAddedToLibrary: Value(isAddedToLibrary),
      isLocal: Value(isLocal),
    );
  }

  factory BilibiliFavorite.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BilibiliFavorite(
      id: serializer.fromJson<int>(json['id']),
      remoteId: serializer.fromJson<int>(json['remoteId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      mediaCount: serializer.fromJson<int>(json['mediaCount']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      isAddedToLibrary: serializer.fromJson<bool>(json['isAddedToLibrary']),
      isLocal: serializer.fromJson<bool>(json['isLocal']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'remoteId': serializer.toJson<int>(remoteId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'mediaCount': serializer.toJson<int>(mediaCount),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'isAddedToLibrary': serializer.toJson<bool>(isAddedToLibrary),
      'isLocal': serializer.toJson<bool>(isLocal),
    };
  }

  BilibiliFavorite copyWith(
          {int? id,
          int? remoteId,
          String? title,
          Value<String?> description = const Value.absent(),
          Value<String?> coverUrl = const Value.absent(),
          int? mediaCount,
          DateTime? syncedAt,
          DateTime? createdAt,
          bool? isAddedToLibrary,
          bool? isLocal}) =>
      BilibiliFavorite(
        id: id ?? this.id,
        remoteId: remoteId ?? this.remoteId,
        title: title ?? this.title,
        description: description.present ? description.value : this.description,
        coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
        mediaCount: mediaCount ?? this.mediaCount,
        syncedAt: syncedAt ?? this.syncedAt,
        createdAt: createdAt ?? this.createdAt,
        isAddedToLibrary: isAddedToLibrary ?? this.isAddedToLibrary,
        isLocal: isLocal ?? this.isLocal,
      );
  BilibiliFavorite copyWithCompanion(BilibiliFavoritesCompanion data) {
    return BilibiliFavorite(
      id: data.id.present ? data.id.value : this.id,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      title: data.title.present ? data.title.value : this.title,
      description:
          data.description.present ? data.description.value : this.description,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      mediaCount:
          data.mediaCount.present ? data.mediaCount.value : this.mediaCount,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      isAddedToLibrary: data.isAddedToLibrary.present
          ? data.isAddedToLibrary.value
          : this.isAddedToLibrary,
      isLocal: data.isLocal.present ? data.isLocal.value : this.isLocal,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BilibiliFavorite(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('mediaCount: $mediaCount, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('isAddedToLibrary: $isAddedToLibrary, ')
          ..write('isLocal: $isLocal')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, remoteId, title, description, coverUrl,
      mediaCount, syncedAt, createdAt, isAddedToLibrary, isLocal);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BilibiliFavorite &&
          other.id == this.id &&
          other.remoteId == this.remoteId &&
          other.title == this.title &&
          other.description == this.description &&
          other.coverUrl == this.coverUrl &&
          other.mediaCount == this.mediaCount &&
          other.syncedAt == this.syncedAt &&
          other.createdAt == this.createdAt &&
          other.isAddedToLibrary == this.isAddedToLibrary &&
          other.isLocal == this.isLocal);
}

class BilibiliFavoritesCompanion extends UpdateCompanion<BilibiliFavorite> {
  final Value<int> id;
  final Value<int> remoteId;
  final Value<String> title;
  final Value<String?> description;
  final Value<String?> coverUrl;
  final Value<int> mediaCount;
  final Value<DateTime> syncedAt;
  final Value<DateTime> createdAt;
  final Value<bool> isAddedToLibrary;
  final Value<bool> isLocal;
  const BilibiliFavoritesCompanion({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.mediaCount = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isAddedToLibrary = const Value.absent(),
    this.isLocal = const Value.absent(),
  });
  BilibiliFavoritesCompanion.insert({
    this.id = const Value.absent(),
    required int remoteId,
    required String title,
    this.description = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.mediaCount = const Value.absent(),
    required DateTime syncedAt,
    this.createdAt = const Value.absent(),
    this.isAddedToLibrary = const Value.absent(),
    this.isLocal = const Value.absent(),
  })  : remoteId = Value(remoteId),
        title = Value(title),
        syncedAt = Value(syncedAt);
  static Insertable<BilibiliFavorite> custom({
    Expression<int>? id,
    Expression<int>? remoteId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? coverUrl,
    Expression<int>? mediaCount,
    Expression<DateTime>? syncedAt,
    Expression<DateTime>? createdAt,
    Expression<bool>? isAddedToLibrary,
    Expression<bool>? isLocal,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (remoteId != null) 'remote_id': remoteId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (mediaCount != null) 'media_count': mediaCount,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (isAddedToLibrary != null) 'is_added_to_library': isAddedToLibrary,
      if (isLocal != null) 'is_local': isLocal,
    });
  }

  BilibiliFavoritesCompanion copyWith(
      {Value<int>? id,
      Value<int>? remoteId,
      Value<String>? title,
      Value<String?>? description,
      Value<String?>? coverUrl,
      Value<int>? mediaCount,
      Value<DateTime>? syncedAt,
      Value<DateTime>? createdAt,
      Value<bool>? isAddedToLibrary,
      Value<bool>? isLocal}) {
    return BilibiliFavoritesCompanion(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      title: title ?? this.title,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      mediaCount: mediaCount ?? this.mediaCount,
      syncedAt: syncedAt ?? this.syncedAt,
      createdAt: createdAt ?? this.createdAt,
      isAddedToLibrary: isAddedToLibrary ?? this.isAddedToLibrary,
      isLocal: isLocal ?? this.isLocal,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<int>(remoteId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (mediaCount.present) {
      map['media_count'] = Variable<int>(mediaCount.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (isAddedToLibrary.present) {
      map['is_added_to_library'] = Variable<bool>(isAddedToLibrary.value);
    }
    if (isLocal.present) {
      map['is_local'] = Variable<bool>(isLocal.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BilibiliFavoritesCompanion(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('mediaCount: $mediaCount, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('isAddedToLibrary: $isAddedToLibrary, ')
          ..write('isLocal: $isLocal')
          ..write(')'))
        .toString();
  }
}

class $SongsTable extends Songs with TableInfo<$SongsTable, Song> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SongsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
      'artist', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
      'album', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _lyricsMeta = const VerificationMeta('lyrics');
  @override
  late final GeneratedColumn<String> lyrics = GeneratedColumn<String>(
      'lyrics', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _bitrateMeta =
      const VerificationMeta('bitrate');
  @override
  late final GeneratedColumn<int> bitrate = GeneratedColumn<int>(
      'bitrate', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _sampleRateMeta =
      const VerificationMeta('sampleRate');
  @override
  late final GeneratedColumn<int> sampleRate = GeneratedColumn<int>(
      'sample_rate', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _durationMeta =
      const VerificationMeta('duration');
  @override
  late final GeneratedColumn<int> duration = GeneratedColumn<int>(
      'duration', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _albumArtPathMeta =
      const VerificationMeta('albumArtPath');
  @override
  late final GeneratedColumn<String> albumArtPath = GeneratedColumn<String>(
      'album_art_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _dateAddedMeta =
      const VerificationMeta('dateAdded');
  @override
  late final GeneratedColumn<DateTime> dateAdded = GeneratedColumn<DateTime>(
      'date_added', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _isFavoriteMeta =
      const VerificationMeta('isFavorite');
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
      'is_favorite', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_favorite" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _lastPlayedTimeMeta =
      const VerificationMeta('lastPlayedTime');
  @override
  late final GeneratedColumn<DateTime> lastPlayedTime =
      GeneratedColumn<DateTime>('last_played_time', aliasedName, false,
          type: DriftSqlType.dateTime,
          requiredDuringInsert: false,
          defaultValue: currentDateAndTime);
  static const VerificationMeta _playedCountMeta =
      const VerificationMeta('playedCount');
  @override
  late final GeneratedColumn<int> playedCount = GeneratedColumn<int>(
      'played_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('local'));
  static const VerificationMeta _bvidMeta = const VerificationMeta('bvid');
  @override
  late final GeneratedColumn<String> bvid = GeneratedColumn<String>(
      'bvid', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cidMeta = const VerificationMeta('cid');
  @override
  late final GeneratedColumn<int> cid = GeneratedColumn<int>(
      'cid', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _pageNumberMeta =
      const VerificationMeta('pageNumber');
  @override
  late final GeneratedColumn<int> pageNumber = GeneratedColumn<int>(
      'page_number', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _bilibiliVideoIdMeta =
      const VerificationMeta('bilibiliVideoId');
  @override
  late final GeneratedColumn<int> bilibiliVideoId = GeneratedColumn<int>(
      'bilibili_video_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES bilibili_videos (id) ON DELETE SET NULL'));
  static const VerificationMeta _bilibiliFavoriteIdMeta =
      const VerificationMeta('bilibiliFavoriteId');
  @override
  late final GeneratedColumn<int> bilibiliFavoriteId = GeneratedColumn<int>(
      'bilibili_favorite_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES bilibili_favorites (id) ON DELETE SET NULL'));
  static const VerificationMeta _downloadedQualitiesMeta =
      const VerificationMeta('downloadedQualities');
  @override
  late final GeneratedColumn<String> downloadedQualities =
      GeneratedColumn<String>('downloaded_qualities', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _currentQualityMeta =
      const VerificationMeta('currentQuality');
  @override
  late final GeneratedColumn<int> currentQuality = GeneratedColumn<int>(
      'current_quality', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        artist,
        album,
        filePath,
        lyrics,
        bitrate,
        sampleRate,
        duration,
        albumArtPath,
        dateAdded,
        isFavorite,
        lastPlayedTime,
        playedCount,
        source,
        bvid,
        cid,
        pageNumber,
        bilibiliVideoId,
        bilibiliFavoriteId,
        downloadedQualities,
        currentQuality
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'songs';
  @override
  VerificationContext validateIntegrity(Insertable<Song> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(_artistMeta,
          artist.isAcceptableOrUnknown(data['artist']!, _artistMeta));
    }
    if (data.containsKey('album')) {
      context.handle(
          _albumMeta, album.isAcceptableOrUnknown(data['album']!, _albumMeta));
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('lyrics')) {
      context.handle(_lyricsMeta,
          lyrics.isAcceptableOrUnknown(data['lyrics']!, _lyricsMeta));
    }
    if (data.containsKey('bitrate')) {
      context.handle(_bitrateMeta,
          bitrate.isAcceptableOrUnknown(data['bitrate']!, _bitrateMeta));
    }
    if (data.containsKey('sample_rate')) {
      context.handle(
          _sampleRateMeta,
          sampleRate.isAcceptableOrUnknown(
              data['sample_rate']!, _sampleRateMeta));
    }
    if (data.containsKey('duration')) {
      context.handle(_durationMeta,
          duration.isAcceptableOrUnknown(data['duration']!, _durationMeta));
    }
    if (data.containsKey('album_art_path')) {
      context.handle(
          _albumArtPathMeta,
          albumArtPath.isAcceptableOrUnknown(
              data['album_art_path']!, _albumArtPathMeta));
    }
    if (data.containsKey('date_added')) {
      context.handle(_dateAddedMeta,
          dateAdded.isAcceptableOrUnknown(data['date_added']!, _dateAddedMeta));
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
          _isFavoriteMeta,
          isFavorite.isAcceptableOrUnknown(
              data['is_favorite']!, _isFavoriteMeta));
    }
    if (data.containsKey('last_played_time')) {
      context.handle(
          _lastPlayedTimeMeta,
          lastPlayedTime.isAcceptableOrUnknown(
              data['last_played_time']!, _lastPlayedTimeMeta));
    }
    if (data.containsKey('played_count')) {
      context.handle(
          _playedCountMeta,
          playedCount.isAcceptableOrUnknown(
              data['played_count']!, _playedCountMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('bvid')) {
      context.handle(
          _bvidMeta, bvid.isAcceptableOrUnknown(data['bvid']!, _bvidMeta));
    }
    if (data.containsKey('cid')) {
      context.handle(
          _cidMeta, cid.isAcceptableOrUnknown(data['cid']!, _cidMeta));
    }
    if (data.containsKey('page_number')) {
      context.handle(
          _pageNumberMeta,
          pageNumber.isAcceptableOrUnknown(
              data['page_number']!, _pageNumberMeta));
    }
    if (data.containsKey('bilibili_video_id')) {
      context.handle(
          _bilibiliVideoIdMeta,
          bilibiliVideoId.isAcceptableOrUnknown(
              data['bilibili_video_id']!, _bilibiliVideoIdMeta));
    }
    if (data.containsKey('bilibili_favorite_id')) {
      context.handle(
          _bilibiliFavoriteIdMeta,
          bilibiliFavoriteId.isAcceptableOrUnknown(
              data['bilibili_favorite_id']!, _bilibiliFavoriteIdMeta));
    }
    if (data.containsKey('downloaded_qualities')) {
      context.handle(
          _downloadedQualitiesMeta,
          downloadedQualities.isAcceptableOrUnknown(
              data['downloaded_qualities']!, _downloadedQualitiesMeta));
    }
    if (data.containsKey('current_quality')) {
      context.handle(
          _currentQualityMeta,
          currentQuality.isAcceptableOrUnknown(
              data['current_quality']!, _currentQualityMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Song map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Song(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      artist: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}artist']),
      album: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}album']),
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path'])!,
      lyrics: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}lyrics']),
      bitrate: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}bitrate']),
      sampleRate: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sample_rate']),
      duration: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration']),
      albumArtPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}album_art_path']),
      dateAdded: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date_added'])!,
      isFavorite: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_favorite'])!,
      lastPlayedTime: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_played_time'])!,
      playedCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}played_count'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      bvid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bvid']),
      cid: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}cid']),
      pageNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}page_number']),
      bilibiliVideoId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}bilibili_video_id']),
      bilibiliFavoriteId: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}bilibili_favorite_id']),
      downloadedQualities: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}downloaded_qualities']),
      currentQuality: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}current_quality']),
    );
  }

  @override
  $SongsTable createAlias(String alias) {
    return $SongsTable(attachedDatabase, alias);
  }
}

class Song extends DataClass implements Insertable<Song> {
  final int id;
  final String title;
  final String? artist;
  final String? album;
  final String filePath;
  final String? lyrics;
  final int? bitrate;
  final int? sampleRate;
  final int? duration;
  final String? albumArtPath;
  final DateTime dateAdded;
  final bool isFavorite;
  final DateTime lastPlayedTime;
  final int playedCount;
  final String source;
  final String? bvid;
  final int? cid;
  final int? pageNumber;
  final int? bilibiliVideoId;
  final int? bilibiliFavoriteId;
  final String? downloadedQualities;
  final int? currentQuality;
  const Song(
      {required this.id,
      required this.title,
      this.artist,
      this.album,
      required this.filePath,
      this.lyrics,
      this.bitrate,
      this.sampleRate,
      this.duration,
      this.albumArtPath,
      required this.dateAdded,
      required this.isFavorite,
      required this.lastPlayedTime,
      required this.playedCount,
      required this.source,
      this.bvid,
      this.cid,
      this.pageNumber,
      this.bilibiliVideoId,
      this.bilibiliFavoriteId,
      this.downloadedQualities,
      this.currentQuality});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || artist != null) {
      map['artist'] = Variable<String>(artist);
    }
    if (!nullToAbsent || album != null) {
      map['album'] = Variable<String>(album);
    }
    map['file_path'] = Variable<String>(filePath);
    if (!nullToAbsent || lyrics != null) {
      map['lyrics'] = Variable<String>(lyrics);
    }
    if (!nullToAbsent || bitrate != null) {
      map['bitrate'] = Variable<int>(bitrate);
    }
    if (!nullToAbsent || sampleRate != null) {
      map['sample_rate'] = Variable<int>(sampleRate);
    }
    if (!nullToAbsent || duration != null) {
      map['duration'] = Variable<int>(duration);
    }
    if (!nullToAbsent || albumArtPath != null) {
      map['album_art_path'] = Variable<String>(albumArtPath);
    }
    map['date_added'] = Variable<DateTime>(dateAdded);
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['last_played_time'] = Variable<DateTime>(lastPlayedTime);
    map['played_count'] = Variable<int>(playedCount);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || bvid != null) {
      map['bvid'] = Variable<String>(bvid);
    }
    if (!nullToAbsent || cid != null) {
      map['cid'] = Variable<int>(cid);
    }
    if (!nullToAbsent || pageNumber != null) {
      map['page_number'] = Variable<int>(pageNumber);
    }
    if (!nullToAbsent || bilibiliVideoId != null) {
      map['bilibili_video_id'] = Variable<int>(bilibiliVideoId);
    }
    if (!nullToAbsent || bilibiliFavoriteId != null) {
      map['bilibili_favorite_id'] = Variable<int>(bilibiliFavoriteId);
    }
    if (!nullToAbsent || downloadedQualities != null) {
      map['downloaded_qualities'] = Variable<String>(downloadedQualities);
    }
    if (!nullToAbsent || currentQuality != null) {
      map['current_quality'] = Variable<int>(currentQuality);
    }
    return map;
  }

  SongsCompanion toCompanion(bool nullToAbsent) {
    return SongsCompanion(
      id: Value(id),
      title: Value(title),
      artist:
          artist == null && nullToAbsent ? const Value.absent() : Value(artist),
      album:
          album == null && nullToAbsent ? const Value.absent() : Value(album),
      filePath: Value(filePath),
      lyrics:
          lyrics == null && nullToAbsent ? const Value.absent() : Value(lyrics),
      bitrate: bitrate == null && nullToAbsent
          ? const Value.absent()
          : Value(bitrate),
      sampleRate: sampleRate == null && nullToAbsent
          ? const Value.absent()
          : Value(sampleRate),
      duration: duration == null && nullToAbsent
          ? const Value.absent()
          : Value(duration),
      albumArtPath: albumArtPath == null && nullToAbsent
          ? const Value.absent()
          : Value(albumArtPath),
      dateAdded: Value(dateAdded),
      isFavorite: Value(isFavorite),
      lastPlayedTime: Value(lastPlayedTime),
      playedCount: Value(playedCount),
      source: Value(source),
      bvid: bvid == null && nullToAbsent ? const Value.absent() : Value(bvid),
      cid: cid == null && nullToAbsent ? const Value.absent() : Value(cid),
      pageNumber: pageNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(pageNumber),
      bilibiliVideoId: bilibiliVideoId == null && nullToAbsent
          ? const Value.absent()
          : Value(bilibiliVideoId),
      bilibiliFavoriteId: bilibiliFavoriteId == null && nullToAbsent
          ? const Value.absent()
          : Value(bilibiliFavoriteId),
      downloadedQualities: downloadedQualities == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadedQualities),
      currentQuality: currentQuality == null && nullToAbsent
          ? const Value.absent()
          : Value(currentQuality),
    );
  }

  factory Song.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Song(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String?>(json['artist']),
      album: serializer.fromJson<String?>(json['album']),
      filePath: serializer.fromJson<String>(json['filePath']),
      lyrics: serializer.fromJson<String?>(json['lyrics']),
      bitrate: serializer.fromJson<int?>(json['bitrate']),
      sampleRate: serializer.fromJson<int?>(json['sampleRate']),
      duration: serializer.fromJson<int?>(json['duration']),
      albumArtPath: serializer.fromJson<String?>(json['albumArtPath']),
      dateAdded: serializer.fromJson<DateTime>(json['dateAdded']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      lastPlayedTime: serializer.fromJson<DateTime>(json['lastPlayedTime']),
      playedCount: serializer.fromJson<int>(json['playedCount']),
      source: serializer.fromJson<String>(json['source']),
      bvid: serializer.fromJson<String?>(json['bvid']),
      cid: serializer.fromJson<int?>(json['cid']),
      pageNumber: serializer.fromJson<int?>(json['pageNumber']),
      bilibiliVideoId: serializer.fromJson<int?>(json['bilibiliVideoId']),
      bilibiliFavoriteId: serializer.fromJson<int?>(json['bilibiliFavoriteId']),
      downloadedQualities:
          serializer.fromJson<String?>(json['downloadedQualities']),
      currentQuality: serializer.fromJson<int?>(json['currentQuality']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String?>(artist),
      'album': serializer.toJson<String?>(album),
      'filePath': serializer.toJson<String>(filePath),
      'lyrics': serializer.toJson<String?>(lyrics),
      'bitrate': serializer.toJson<int?>(bitrate),
      'sampleRate': serializer.toJson<int?>(sampleRate),
      'duration': serializer.toJson<int?>(duration),
      'albumArtPath': serializer.toJson<String?>(albumArtPath),
      'dateAdded': serializer.toJson<DateTime>(dateAdded),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'lastPlayedTime': serializer.toJson<DateTime>(lastPlayedTime),
      'playedCount': serializer.toJson<int>(playedCount),
      'source': serializer.toJson<String>(source),
      'bvid': serializer.toJson<String?>(bvid),
      'cid': serializer.toJson<int?>(cid),
      'pageNumber': serializer.toJson<int?>(pageNumber),
      'bilibiliVideoId': serializer.toJson<int?>(bilibiliVideoId),
      'bilibiliFavoriteId': serializer.toJson<int?>(bilibiliFavoriteId),
      'downloadedQualities': serializer.toJson<String?>(downloadedQualities),
      'currentQuality': serializer.toJson<int?>(currentQuality),
    };
  }

  Song copyWith(
          {int? id,
          String? title,
          Value<String?> artist = const Value.absent(),
          Value<String?> album = const Value.absent(),
          String? filePath,
          Value<String?> lyrics = const Value.absent(),
          Value<int?> bitrate = const Value.absent(),
          Value<int?> sampleRate = const Value.absent(),
          Value<int?> duration = const Value.absent(),
          Value<String?> albumArtPath = const Value.absent(),
          DateTime? dateAdded,
          bool? isFavorite,
          DateTime? lastPlayedTime,
          int? playedCount,
          String? source,
          Value<String?> bvid = const Value.absent(),
          Value<int?> cid = const Value.absent(),
          Value<int?> pageNumber = const Value.absent(),
          Value<int?> bilibiliVideoId = const Value.absent(),
          Value<int?> bilibiliFavoriteId = const Value.absent(),
          Value<String?> downloadedQualities = const Value.absent(),
          Value<int?> currentQuality = const Value.absent()}) =>
      Song(
        id: id ?? this.id,
        title: title ?? this.title,
        artist: artist.present ? artist.value : this.artist,
        album: album.present ? album.value : this.album,
        filePath: filePath ?? this.filePath,
        lyrics: lyrics.present ? lyrics.value : this.lyrics,
        bitrate: bitrate.present ? bitrate.value : this.bitrate,
        sampleRate: sampleRate.present ? sampleRate.value : this.sampleRate,
        duration: duration.present ? duration.value : this.duration,
        albumArtPath:
            albumArtPath.present ? albumArtPath.value : this.albumArtPath,
        dateAdded: dateAdded ?? this.dateAdded,
        isFavorite: isFavorite ?? this.isFavorite,
        lastPlayedTime: lastPlayedTime ?? this.lastPlayedTime,
        playedCount: playedCount ?? this.playedCount,
        source: source ?? this.source,
        bvid: bvid.present ? bvid.value : this.bvid,
        cid: cid.present ? cid.value : this.cid,
        pageNumber: pageNumber.present ? pageNumber.value : this.pageNumber,
        bilibiliVideoId: bilibiliVideoId.present
            ? bilibiliVideoId.value
            : this.bilibiliVideoId,
        bilibiliFavoriteId: bilibiliFavoriteId.present
            ? bilibiliFavoriteId.value
            : this.bilibiliFavoriteId,
        downloadedQualities: downloadedQualities.present
            ? downloadedQualities.value
            : this.downloadedQualities,
        currentQuality:
            currentQuality.present ? currentQuality.value : this.currentQuality,
      );
  Song copyWithCompanion(SongsCompanion data) {
    return Song(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      album: data.album.present ? data.album.value : this.album,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      lyrics: data.lyrics.present ? data.lyrics.value : this.lyrics,
      bitrate: data.bitrate.present ? data.bitrate.value : this.bitrate,
      sampleRate:
          data.sampleRate.present ? data.sampleRate.value : this.sampleRate,
      duration: data.duration.present ? data.duration.value : this.duration,
      albumArtPath: data.albumArtPath.present
          ? data.albumArtPath.value
          : this.albumArtPath,
      dateAdded: data.dateAdded.present ? data.dateAdded.value : this.dateAdded,
      isFavorite:
          data.isFavorite.present ? data.isFavorite.value : this.isFavorite,
      lastPlayedTime: data.lastPlayedTime.present
          ? data.lastPlayedTime.value
          : this.lastPlayedTime,
      playedCount:
          data.playedCount.present ? data.playedCount.value : this.playedCount,
      source: data.source.present ? data.source.value : this.source,
      bvid: data.bvid.present ? data.bvid.value : this.bvid,
      cid: data.cid.present ? data.cid.value : this.cid,
      pageNumber:
          data.pageNumber.present ? data.pageNumber.value : this.pageNumber,
      bilibiliVideoId: data.bilibiliVideoId.present
          ? data.bilibiliVideoId.value
          : this.bilibiliVideoId,
      bilibiliFavoriteId: data.bilibiliFavoriteId.present
          ? data.bilibiliFavoriteId.value
          : this.bilibiliFavoriteId,
      downloadedQualities: data.downloadedQualities.present
          ? data.downloadedQualities.value
          : this.downloadedQualities,
      currentQuality: data.currentQuality.present
          ? data.currentQuality.value
          : this.currentQuality,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Song(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('filePath: $filePath, ')
          ..write('lyrics: $lyrics, ')
          ..write('bitrate: $bitrate, ')
          ..write('sampleRate: $sampleRate, ')
          ..write('duration: $duration, ')
          ..write('albumArtPath: $albumArtPath, ')
          ..write('dateAdded: $dateAdded, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('lastPlayedTime: $lastPlayedTime, ')
          ..write('playedCount: $playedCount, ')
          ..write('source: $source, ')
          ..write('bvid: $bvid, ')
          ..write('cid: $cid, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('bilibiliVideoId: $bilibiliVideoId, ')
          ..write('bilibiliFavoriteId: $bilibiliFavoriteId, ')
          ..write('downloadedQualities: $downloadedQualities, ')
          ..write('currentQuality: $currentQuality')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        title,
        artist,
        album,
        filePath,
        lyrics,
        bitrate,
        sampleRate,
        duration,
        albumArtPath,
        dateAdded,
        isFavorite,
        lastPlayedTime,
        playedCount,
        source,
        bvid,
        cid,
        pageNumber,
        bilibiliVideoId,
        bilibiliFavoriteId,
        downloadedQualities,
        currentQuality
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Song &&
          other.id == this.id &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.album == this.album &&
          other.filePath == this.filePath &&
          other.lyrics == this.lyrics &&
          other.bitrate == this.bitrate &&
          other.sampleRate == this.sampleRate &&
          other.duration == this.duration &&
          other.albumArtPath == this.albumArtPath &&
          other.dateAdded == this.dateAdded &&
          other.isFavorite == this.isFavorite &&
          other.lastPlayedTime == this.lastPlayedTime &&
          other.playedCount == this.playedCount &&
          other.source == this.source &&
          other.bvid == this.bvid &&
          other.cid == this.cid &&
          other.pageNumber == this.pageNumber &&
          other.bilibiliVideoId == this.bilibiliVideoId &&
          other.bilibiliFavoriteId == this.bilibiliFavoriteId &&
          other.downloadedQualities == this.downloadedQualities &&
          other.currentQuality == this.currentQuality);
}

class SongsCompanion extends UpdateCompanion<Song> {
  final Value<int> id;
  final Value<String> title;
  final Value<String?> artist;
  final Value<String?> album;
  final Value<String> filePath;
  final Value<String?> lyrics;
  final Value<int?> bitrate;
  final Value<int?> sampleRate;
  final Value<int?> duration;
  final Value<String?> albumArtPath;
  final Value<DateTime> dateAdded;
  final Value<bool> isFavorite;
  final Value<DateTime> lastPlayedTime;
  final Value<int> playedCount;
  final Value<String> source;
  final Value<String?> bvid;
  final Value<int?> cid;
  final Value<int?> pageNumber;
  final Value<int?> bilibiliVideoId;
  final Value<int?> bilibiliFavoriteId;
  final Value<String?> downloadedQualities;
  final Value<int?> currentQuality;
  const SongsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.filePath = const Value.absent(),
    this.lyrics = const Value.absent(),
    this.bitrate = const Value.absent(),
    this.sampleRate = const Value.absent(),
    this.duration = const Value.absent(),
    this.albumArtPath = const Value.absent(),
    this.dateAdded = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.lastPlayedTime = const Value.absent(),
    this.playedCount = const Value.absent(),
    this.source = const Value.absent(),
    this.bvid = const Value.absent(),
    this.cid = const Value.absent(),
    this.pageNumber = const Value.absent(),
    this.bilibiliVideoId = const Value.absent(),
    this.bilibiliFavoriteId = const Value.absent(),
    this.downloadedQualities = const Value.absent(),
    this.currentQuality = const Value.absent(),
  });
  SongsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    required String filePath,
    this.lyrics = const Value.absent(),
    this.bitrate = const Value.absent(),
    this.sampleRate = const Value.absent(),
    this.duration = const Value.absent(),
    this.albumArtPath = const Value.absent(),
    this.dateAdded = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.lastPlayedTime = const Value.absent(),
    this.playedCount = const Value.absent(),
    this.source = const Value.absent(),
    this.bvid = const Value.absent(),
    this.cid = const Value.absent(),
    this.pageNumber = const Value.absent(),
    this.bilibiliVideoId = const Value.absent(),
    this.bilibiliFavoriteId = const Value.absent(),
    this.downloadedQualities = const Value.absent(),
    this.currentQuality = const Value.absent(),
  })  : title = Value(title),
        filePath = Value(filePath);
  static Insertable<Song> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? album,
    Expression<String>? filePath,
    Expression<String>? lyrics,
    Expression<int>? bitrate,
    Expression<int>? sampleRate,
    Expression<int>? duration,
    Expression<String>? albumArtPath,
    Expression<DateTime>? dateAdded,
    Expression<bool>? isFavorite,
    Expression<DateTime>? lastPlayedTime,
    Expression<int>? playedCount,
    Expression<String>? source,
    Expression<String>? bvid,
    Expression<int>? cid,
    Expression<int>? pageNumber,
    Expression<int>? bilibiliVideoId,
    Expression<int>? bilibiliFavoriteId,
    Expression<String>? downloadedQualities,
    Expression<int>? currentQuality,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (filePath != null) 'file_path': filePath,
      if (lyrics != null) 'lyrics': lyrics,
      if (bitrate != null) 'bitrate': bitrate,
      if (sampleRate != null) 'sample_rate': sampleRate,
      if (duration != null) 'duration': duration,
      if (albumArtPath != null) 'album_art_path': albumArtPath,
      if (dateAdded != null) 'date_added': dateAdded,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (lastPlayedTime != null) 'last_played_time': lastPlayedTime,
      if (playedCount != null) 'played_count': playedCount,
      if (source != null) 'source': source,
      if (bvid != null) 'bvid': bvid,
      if (cid != null) 'cid': cid,
      if (pageNumber != null) 'page_number': pageNumber,
      if (bilibiliVideoId != null) 'bilibili_video_id': bilibiliVideoId,
      if (bilibiliFavoriteId != null)
        'bilibili_favorite_id': bilibiliFavoriteId,
      if (downloadedQualities != null)
        'downloaded_qualities': downloadedQualities,
      if (currentQuality != null) 'current_quality': currentQuality,
    });
  }

  SongsCompanion copyWith(
      {Value<int>? id,
      Value<String>? title,
      Value<String?>? artist,
      Value<String?>? album,
      Value<String>? filePath,
      Value<String?>? lyrics,
      Value<int?>? bitrate,
      Value<int?>? sampleRate,
      Value<int?>? duration,
      Value<String?>? albumArtPath,
      Value<DateTime>? dateAdded,
      Value<bool>? isFavorite,
      Value<DateTime>? lastPlayedTime,
      Value<int>? playedCount,
      Value<String>? source,
      Value<String?>? bvid,
      Value<int?>? cid,
      Value<int?>? pageNumber,
      Value<int?>? bilibiliVideoId,
      Value<int?>? bilibiliFavoriteId,
      Value<String?>? downloadedQualities,
      Value<int?>? currentQuality}) {
    return SongsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      filePath: filePath ?? this.filePath,
      lyrics: lyrics ?? this.lyrics,
      bitrate: bitrate ?? this.bitrate,
      sampleRate: sampleRate ?? this.sampleRate,
      duration: duration ?? this.duration,
      albumArtPath: albumArtPath ?? this.albumArtPath,
      dateAdded: dateAdded ?? this.dateAdded,
      isFavorite: isFavorite ?? this.isFavorite,
      lastPlayedTime: lastPlayedTime ?? this.lastPlayedTime,
      playedCount: playedCount ?? this.playedCount,
      source: source ?? this.source,
      bvid: bvid ?? this.bvid,
      cid: cid ?? this.cid,
      pageNumber: pageNumber ?? this.pageNumber,
      bilibiliVideoId: bilibiliVideoId ?? this.bilibiliVideoId,
      bilibiliFavoriteId: bilibiliFavoriteId ?? this.bilibiliFavoriteId,
      downloadedQualities: downloadedQualities ?? this.downloadedQualities,
      currentQuality: currentQuality ?? this.currentQuality,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (lyrics.present) {
      map['lyrics'] = Variable<String>(lyrics.value);
    }
    if (bitrate.present) {
      map['bitrate'] = Variable<int>(bitrate.value);
    }
    if (sampleRate.present) {
      map['sample_rate'] = Variable<int>(sampleRate.value);
    }
    if (duration.present) {
      map['duration'] = Variable<int>(duration.value);
    }
    if (albumArtPath.present) {
      map['album_art_path'] = Variable<String>(albumArtPath.value);
    }
    if (dateAdded.present) {
      map['date_added'] = Variable<DateTime>(dateAdded.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (lastPlayedTime.present) {
      map['last_played_time'] = Variable<DateTime>(lastPlayedTime.value);
    }
    if (playedCount.present) {
      map['played_count'] = Variable<int>(playedCount.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (bvid.present) {
      map['bvid'] = Variable<String>(bvid.value);
    }
    if (cid.present) {
      map['cid'] = Variable<int>(cid.value);
    }
    if (pageNumber.present) {
      map['page_number'] = Variable<int>(pageNumber.value);
    }
    if (bilibiliVideoId.present) {
      map['bilibili_video_id'] = Variable<int>(bilibiliVideoId.value);
    }
    if (bilibiliFavoriteId.present) {
      map['bilibili_favorite_id'] = Variable<int>(bilibiliFavoriteId.value);
    }
    if (downloadedQualities.present) {
      map['downloaded_qualities'] = Variable<String>(downloadedQualities.value);
    }
    if (currentQuality.present) {
      map['current_quality'] = Variable<int>(currentQuality.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SongsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('filePath: $filePath, ')
          ..write('lyrics: $lyrics, ')
          ..write('bitrate: $bitrate, ')
          ..write('sampleRate: $sampleRate, ')
          ..write('duration: $duration, ')
          ..write('albumArtPath: $albumArtPath, ')
          ..write('dateAdded: $dateAdded, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('lastPlayedTime: $lastPlayedTime, ')
          ..write('playedCount: $playedCount, ')
          ..write('source: $source, ')
          ..write('bvid: $bvid, ')
          ..write('cid: $cid, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('bilibiliVideoId: $bilibiliVideoId, ')
          ..write('bilibiliFavoriteId: $bilibiliFavoriteId, ')
          ..write('downloadedQualities: $downloadedQualities, ')
          ..write('currentQuality: $currentQuality')
          ..write(')'))
        .toString();
  }
}

class $BilibiliAudioCacheTable extends BilibiliAudioCache
    with TableInfo<$BilibiliAudioCacheTable, BilibiliAudioCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BilibiliAudioCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _bvidMeta = const VerificationMeta('bvid');
  @override
  late final GeneratedColumn<String> bvid = GeneratedColumn<String>(
      'bvid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _cidMeta = const VerificationMeta('cid');
  @override
  late final GeneratedColumn<int> cid = GeneratedColumn<int>(
      'cid', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _qualityMeta =
      const VerificationMeta('quality');
  @override
  late final GeneratedColumn<int> quality = GeneratedColumn<int>(
      'quality', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _localFilePathMeta =
      const VerificationMeta('localFilePath');
  @override
  late final GeneratedColumn<String> localFilePath = GeneratedColumn<String>(
      'local_file_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fileSizeMeta =
      const VerificationMeta('fileSize');
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
      'file_size', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _lastAccessTimeMeta =
      const VerificationMeta('lastAccessTime');
  @override
  late final GeneratedColumn<DateTime> lastAccessTime =
      GeneratedColumn<DateTime>('last_access_time', aliasedName, false,
          type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _downloadedAtMeta =
      const VerificationMeta('downloadedAt');
  @override
  late final GeneratedColumn<DateTime> downloadedAt = GeneratedColumn<DateTime>(
      'downloaded_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        bvid,
        cid,
        quality,
        localFilePath,
        fileSize,
        lastAccessTime,
        downloadedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bilibili_audio_cache';
  @override
  VerificationContext validateIntegrity(
      Insertable<BilibiliAudioCacheData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('bvid')) {
      context.handle(
          _bvidMeta, bvid.isAcceptableOrUnknown(data['bvid']!, _bvidMeta));
    } else if (isInserting) {
      context.missing(_bvidMeta);
    }
    if (data.containsKey('cid')) {
      context.handle(
          _cidMeta, cid.isAcceptableOrUnknown(data['cid']!, _cidMeta));
    } else if (isInserting) {
      context.missing(_cidMeta);
    }
    if (data.containsKey('quality')) {
      context.handle(_qualityMeta,
          quality.isAcceptableOrUnknown(data['quality']!, _qualityMeta));
    } else if (isInserting) {
      context.missing(_qualityMeta);
    }
    if (data.containsKey('local_file_path')) {
      context.handle(
          _localFilePathMeta,
          localFilePath.isAcceptableOrUnknown(
              data['local_file_path']!, _localFilePathMeta));
    } else if (isInserting) {
      context.missing(_localFilePathMeta);
    }
    if (data.containsKey('file_size')) {
      context.handle(_fileSizeMeta,
          fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta));
    } else if (isInserting) {
      context.missing(_fileSizeMeta);
    }
    if (data.containsKey('last_access_time')) {
      context.handle(
          _lastAccessTimeMeta,
          lastAccessTime.isAcceptableOrUnknown(
              data['last_access_time']!, _lastAccessTimeMeta));
    } else if (isInserting) {
      context.missing(_lastAccessTimeMeta);
    }
    if (data.containsKey('downloaded_at')) {
      context.handle(
          _downloadedAtMeta,
          downloadedAt.isAcceptableOrUnknown(
              data['downloaded_at']!, _downloadedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {bvid, cid, quality},
      ];
  @override
  BilibiliAudioCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BilibiliAudioCacheData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      bvid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bvid'])!,
      cid: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}cid'])!,
      quality: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}quality'])!,
      localFilePath: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}local_file_path'])!,
      fileSize: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}file_size'])!,
      lastAccessTime: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_access_time'])!,
      downloadedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}downloaded_at'])!,
    );
  }

  @override
  $BilibiliAudioCacheTable createAlias(String alias) {
    return $BilibiliAudioCacheTable(attachedDatabase, alias);
  }
}

class BilibiliAudioCacheData extends DataClass
    implements Insertable<BilibiliAudioCacheData> {
  final int id;
  final String bvid;
  final int cid;
  final int quality;
  final String localFilePath;
  final int fileSize;
  final DateTime lastAccessTime;
  final DateTime downloadedAt;
  const BilibiliAudioCacheData(
      {required this.id,
      required this.bvid,
      required this.cid,
      required this.quality,
      required this.localFilePath,
      required this.fileSize,
      required this.lastAccessTime,
      required this.downloadedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['bvid'] = Variable<String>(bvid);
    map['cid'] = Variable<int>(cid);
    map['quality'] = Variable<int>(quality);
    map['local_file_path'] = Variable<String>(localFilePath);
    map['file_size'] = Variable<int>(fileSize);
    map['last_access_time'] = Variable<DateTime>(lastAccessTime);
    map['downloaded_at'] = Variable<DateTime>(downloadedAt);
    return map;
  }

  BilibiliAudioCacheCompanion toCompanion(bool nullToAbsent) {
    return BilibiliAudioCacheCompanion(
      id: Value(id),
      bvid: Value(bvid),
      cid: Value(cid),
      quality: Value(quality),
      localFilePath: Value(localFilePath),
      fileSize: Value(fileSize),
      lastAccessTime: Value(lastAccessTime),
      downloadedAt: Value(downloadedAt),
    );
  }

  factory BilibiliAudioCacheData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BilibiliAudioCacheData(
      id: serializer.fromJson<int>(json['id']),
      bvid: serializer.fromJson<String>(json['bvid']),
      cid: serializer.fromJson<int>(json['cid']),
      quality: serializer.fromJson<int>(json['quality']),
      localFilePath: serializer.fromJson<String>(json['localFilePath']),
      fileSize: serializer.fromJson<int>(json['fileSize']),
      lastAccessTime: serializer.fromJson<DateTime>(json['lastAccessTime']),
      downloadedAt: serializer.fromJson<DateTime>(json['downloadedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bvid': serializer.toJson<String>(bvid),
      'cid': serializer.toJson<int>(cid),
      'quality': serializer.toJson<int>(quality),
      'localFilePath': serializer.toJson<String>(localFilePath),
      'fileSize': serializer.toJson<int>(fileSize),
      'lastAccessTime': serializer.toJson<DateTime>(lastAccessTime),
      'downloadedAt': serializer.toJson<DateTime>(downloadedAt),
    };
  }

  BilibiliAudioCacheData copyWith(
          {int? id,
          String? bvid,
          int? cid,
          int? quality,
          String? localFilePath,
          int? fileSize,
          DateTime? lastAccessTime,
          DateTime? downloadedAt}) =>
      BilibiliAudioCacheData(
        id: id ?? this.id,
        bvid: bvid ?? this.bvid,
        cid: cid ?? this.cid,
        quality: quality ?? this.quality,
        localFilePath: localFilePath ?? this.localFilePath,
        fileSize: fileSize ?? this.fileSize,
        lastAccessTime: lastAccessTime ?? this.lastAccessTime,
        downloadedAt: downloadedAt ?? this.downloadedAt,
      );
  BilibiliAudioCacheData copyWithCompanion(BilibiliAudioCacheCompanion data) {
    return BilibiliAudioCacheData(
      id: data.id.present ? data.id.value : this.id,
      bvid: data.bvid.present ? data.bvid.value : this.bvid,
      cid: data.cid.present ? data.cid.value : this.cid,
      quality: data.quality.present ? data.quality.value : this.quality,
      localFilePath: data.localFilePath.present
          ? data.localFilePath.value
          : this.localFilePath,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      lastAccessTime: data.lastAccessTime.present
          ? data.lastAccessTime.value
          : this.lastAccessTime,
      downloadedAt: data.downloadedAt.present
          ? data.downloadedAt.value
          : this.downloadedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BilibiliAudioCacheData(')
          ..write('id: $id, ')
          ..write('bvid: $bvid, ')
          ..write('cid: $cid, ')
          ..write('quality: $quality, ')
          ..write('localFilePath: $localFilePath, ')
          ..write('fileSize: $fileSize, ')
          ..write('lastAccessTime: $lastAccessTime, ')
          ..write('downloadedAt: $downloadedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, bvid, cid, quality, localFilePath,
      fileSize, lastAccessTime, downloadedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BilibiliAudioCacheData &&
          other.id == this.id &&
          other.bvid == this.bvid &&
          other.cid == this.cid &&
          other.quality == this.quality &&
          other.localFilePath == this.localFilePath &&
          other.fileSize == this.fileSize &&
          other.lastAccessTime == this.lastAccessTime &&
          other.downloadedAt == this.downloadedAt);
}

class BilibiliAudioCacheCompanion
    extends UpdateCompanion<BilibiliAudioCacheData> {
  final Value<int> id;
  final Value<String> bvid;
  final Value<int> cid;
  final Value<int> quality;
  final Value<String> localFilePath;
  final Value<int> fileSize;
  final Value<DateTime> lastAccessTime;
  final Value<DateTime> downloadedAt;
  const BilibiliAudioCacheCompanion({
    this.id = const Value.absent(),
    this.bvid = const Value.absent(),
    this.cid = const Value.absent(),
    this.quality = const Value.absent(),
    this.localFilePath = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.lastAccessTime = const Value.absent(),
    this.downloadedAt = const Value.absent(),
  });
  BilibiliAudioCacheCompanion.insert({
    this.id = const Value.absent(),
    required String bvid,
    required int cid,
    required int quality,
    required String localFilePath,
    required int fileSize,
    required DateTime lastAccessTime,
    this.downloadedAt = const Value.absent(),
  })  : bvid = Value(bvid),
        cid = Value(cid),
        quality = Value(quality),
        localFilePath = Value(localFilePath),
        fileSize = Value(fileSize),
        lastAccessTime = Value(lastAccessTime);
  static Insertable<BilibiliAudioCacheData> custom({
    Expression<int>? id,
    Expression<String>? bvid,
    Expression<int>? cid,
    Expression<int>? quality,
    Expression<String>? localFilePath,
    Expression<int>? fileSize,
    Expression<DateTime>? lastAccessTime,
    Expression<DateTime>? downloadedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bvid != null) 'bvid': bvid,
      if (cid != null) 'cid': cid,
      if (quality != null) 'quality': quality,
      if (localFilePath != null) 'local_file_path': localFilePath,
      if (fileSize != null) 'file_size': fileSize,
      if (lastAccessTime != null) 'last_access_time': lastAccessTime,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
    });
  }

  BilibiliAudioCacheCompanion copyWith(
      {Value<int>? id,
      Value<String>? bvid,
      Value<int>? cid,
      Value<int>? quality,
      Value<String>? localFilePath,
      Value<int>? fileSize,
      Value<DateTime>? lastAccessTime,
      Value<DateTime>? downloadedAt}) {
    return BilibiliAudioCacheCompanion(
      id: id ?? this.id,
      bvid: bvid ?? this.bvid,
      cid: cid ?? this.cid,
      quality: quality ?? this.quality,
      localFilePath: localFilePath ?? this.localFilePath,
      fileSize: fileSize ?? this.fileSize,
      lastAccessTime: lastAccessTime ?? this.lastAccessTime,
      downloadedAt: downloadedAt ?? this.downloadedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bvid.present) {
      map['bvid'] = Variable<String>(bvid.value);
    }
    if (cid.present) {
      map['cid'] = Variable<int>(cid.value);
    }
    if (quality.present) {
      map['quality'] = Variable<int>(quality.value);
    }
    if (localFilePath.present) {
      map['local_file_path'] = Variable<String>(localFilePath.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (lastAccessTime.present) {
      map['last_access_time'] = Variable<DateTime>(lastAccessTime.value);
    }
    if (downloadedAt.present) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BilibiliAudioCacheCompanion(')
          ..write('id: $id, ')
          ..write('bvid: $bvid, ')
          ..write('cid: $cid, ')
          ..write('quality: $quality, ')
          ..write('localFilePath: $localFilePath, ')
          ..write('fileSize: $fileSize, ')
          ..write('lastAccessTime: $lastAccessTime, ')
          ..write('downloadedAt: $downloadedAt')
          ..write(')'))
        .toString();
  }
}

class $DownloadTasksTable extends DownloadTasks
    with TableInfo<$DownloadTasksTable, DownloadTask> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _bvidMeta = const VerificationMeta('bvid');
  @override
  late final GeneratedColumn<String> bvid = GeneratedColumn<String>(
      'bvid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _cidMeta = const VerificationMeta('cid');
  @override
  late final GeneratedColumn<int> cid = GeneratedColumn<int>(
      'cid', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _qualityMeta =
      const VerificationMeta('quality');
  @override
  late final GeneratedColumn<int> quality = GeneratedColumn<int>(
      'quality', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
      'artist', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _coverUrlMeta =
      const VerificationMeta('coverUrl');
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
      'cover_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _durationMeta =
      const VerificationMeta('duration');
  @override
  late final GeneratedColumn<int> duration = GeneratedColumn<int>(
      'duration', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _progressMeta =
      const VerificationMeta('progress');
  @override
  late final GeneratedColumn<int> progress = GeneratedColumn<int>(
      'progress', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _downloadedBytesMeta =
      const VerificationMeta('downloadedBytes');
  @override
  late final GeneratedColumn<int> downloadedBytes = GeneratedColumn<int>(
      'downloaded_bytes', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _totalBytesMeta =
      const VerificationMeta('totalBytes');
  @override
  late final GeneratedColumn<int> totalBytes = GeneratedColumn<int>(
      'total_bytes', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _localPathMeta =
      const VerificationMeta('localPath');
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
      'local_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _errorMessageMeta =
      const VerificationMeta('errorMessage');
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
      'error_message', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _completedAtMeta =
      const VerificationMeta('completedAt');
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
      'completed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        bvid,
        cid,
        quality,
        title,
        artist,
        coverUrl,
        duration,
        status,
        progress,
        downloadedBytes,
        totalBytes,
        localPath,
        errorMessage,
        createdAt,
        completedAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_tasks';
  @override
  VerificationContext validateIntegrity(Insertable<DownloadTask> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('bvid')) {
      context.handle(
          _bvidMeta, bvid.isAcceptableOrUnknown(data['bvid']!, _bvidMeta));
    } else if (isInserting) {
      context.missing(_bvidMeta);
    }
    if (data.containsKey('cid')) {
      context.handle(
          _cidMeta, cid.isAcceptableOrUnknown(data['cid']!, _cidMeta));
    } else if (isInserting) {
      context.missing(_cidMeta);
    }
    if (data.containsKey('quality')) {
      context.handle(_qualityMeta,
          quality.isAcceptableOrUnknown(data['quality']!, _qualityMeta));
    } else if (isInserting) {
      context.missing(_qualityMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(_artistMeta,
          artist.isAcceptableOrUnknown(data['artist']!, _artistMeta));
    }
    if (data.containsKey('cover_url')) {
      context.handle(_coverUrlMeta,
          coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta));
    }
    if (data.containsKey('duration')) {
      context.handle(_durationMeta,
          duration.isAcceptableOrUnknown(data['duration']!, _durationMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('progress')) {
      context.handle(_progressMeta,
          progress.isAcceptableOrUnknown(data['progress']!, _progressMeta));
    }
    if (data.containsKey('downloaded_bytes')) {
      context.handle(
          _downloadedBytesMeta,
          downloadedBytes.isAcceptableOrUnknown(
              data['downloaded_bytes']!, _downloadedBytesMeta));
    }
    if (data.containsKey('total_bytes')) {
      context.handle(
          _totalBytesMeta,
          totalBytes.isAcceptableOrUnknown(
              data['total_bytes']!, _totalBytesMeta));
    }
    if (data.containsKey('local_path')) {
      context.handle(_localPathMeta,
          localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta));
    }
    if (data.containsKey('error_message')) {
      context.handle(
          _errorMessageMeta,
          errorMessage.isAcceptableOrUnknown(
              data['error_message']!, _errorMessageMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('completed_at')) {
      context.handle(
          _completedAtMeta,
          completedAt.isAcceptableOrUnknown(
              data['completed_at']!, _completedAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {bvid, cid, quality},
      ];
  @override
  DownloadTask map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadTask(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      bvid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bvid'])!,
      cid: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}cid'])!,
      quality: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}quality'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      artist: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}artist']),
      coverUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cover_url']),
      duration: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      progress: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}progress'])!,
      downloadedBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}downloaded_bytes'])!,
      totalBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_bytes']),
      localPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_path']),
      errorMessage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}error_message']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      completedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}completed_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $DownloadTasksTable createAlias(String alias) {
    return $DownloadTasksTable(attachedDatabase, alias);
  }
}

class DownloadTask extends DataClass implements Insertable<DownloadTask> {
  final int id;
  final String bvid;
  final int cid;
  final int quality;
  final String title;
  final String? artist;
  final String? coverUrl;
  final int? duration;
  final String status;
  final int progress;
  final int downloadedBytes;
  final int? totalBytes;
  final String? localPath;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime updatedAt;
  const DownloadTask(
      {required this.id,
      required this.bvid,
      required this.cid,
      required this.quality,
      required this.title,
      this.artist,
      this.coverUrl,
      this.duration,
      required this.status,
      required this.progress,
      required this.downloadedBytes,
      this.totalBytes,
      this.localPath,
      this.errorMessage,
      required this.createdAt,
      this.completedAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['bvid'] = Variable<String>(bvid);
    map['cid'] = Variable<int>(cid);
    map['quality'] = Variable<int>(quality);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || artist != null) {
      map['artist'] = Variable<String>(artist);
    }
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    if (!nullToAbsent || duration != null) {
      map['duration'] = Variable<int>(duration);
    }
    map['status'] = Variable<String>(status);
    map['progress'] = Variable<int>(progress);
    map['downloaded_bytes'] = Variable<int>(downloadedBytes);
    if (!nullToAbsent || totalBytes != null) {
      map['total_bytes'] = Variable<int>(totalBytes);
    }
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DownloadTasksCompanion toCompanion(bool nullToAbsent) {
    return DownloadTasksCompanion(
      id: Value(id),
      bvid: Value(bvid),
      cid: Value(cid),
      quality: Value(quality),
      title: Value(title),
      artist:
          artist == null && nullToAbsent ? const Value.absent() : Value(artist),
      coverUrl: coverUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverUrl),
      duration: duration == null && nullToAbsent
          ? const Value.absent()
          : Value(duration),
      status: Value(status),
      progress: Value(progress),
      downloadedBytes: Value(downloadedBytes),
      totalBytes: totalBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(totalBytes),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      createdAt: Value(createdAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DownloadTask.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadTask(
      id: serializer.fromJson<int>(json['id']),
      bvid: serializer.fromJson<String>(json['bvid']),
      cid: serializer.fromJson<int>(json['cid']),
      quality: serializer.fromJson<int>(json['quality']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String?>(json['artist']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      duration: serializer.fromJson<int?>(json['duration']),
      status: serializer.fromJson<String>(json['status']),
      progress: serializer.fromJson<int>(json['progress']),
      downloadedBytes: serializer.fromJson<int>(json['downloadedBytes']),
      totalBytes: serializer.fromJson<int?>(json['totalBytes']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bvid': serializer.toJson<String>(bvid),
      'cid': serializer.toJson<int>(cid),
      'quality': serializer.toJson<int>(quality),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String?>(artist),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'duration': serializer.toJson<int?>(duration),
      'status': serializer.toJson<String>(status),
      'progress': serializer.toJson<int>(progress),
      'downloadedBytes': serializer.toJson<int>(downloadedBytes),
      'totalBytes': serializer.toJson<int?>(totalBytes),
      'localPath': serializer.toJson<String?>(localPath),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DownloadTask copyWith(
          {int? id,
          String? bvid,
          int? cid,
          int? quality,
          String? title,
          Value<String?> artist = const Value.absent(),
          Value<String?> coverUrl = const Value.absent(),
          Value<int?> duration = const Value.absent(),
          String? status,
          int? progress,
          int? downloadedBytes,
          Value<int?> totalBytes = const Value.absent(),
          Value<String?> localPath = const Value.absent(),
          Value<String?> errorMessage = const Value.absent(),
          DateTime? createdAt,
          Value<DateTime?> completedAt = const Value.absent(),
          DateTime? updatedAt}) =>
      DownloadTask(
        id: id ?? this.id,
        bvid: bvid ?? this.bvid,
        cid: cid ?? this.cid,
        quality: quality ?? this.quality,
        title: title ?? this.title,
        artist: artist.present ? artist.value : this.artist,
        coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
        duration: duration.present ? duration.value : this.duration,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        downloadedBytes: downloadedBytes ?? this.downloadedBytes,
        totalBytes: totalBytes.present ? totalBytes.value : this.totalBytes,
        localPath: localPath.present ? localPath.value : this.localPath,
        errorMessage:
            errorMessage.present ? errorMessage.value : this.errorMessage,
        createdAt: createdAt ?? this.createdAt,
        completedAt: completedAt.present ? completedAt.value : this.completedAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  DownloadTask copyWithCompanion(DownloadTasksCompanion data) {
    return DownloadTask(
      id: data.id.present ? data.id.value : this.id,
      bvid: data.bvid.present ? data.bvid.value : this.bvid,
      cid: data.cid.present ? data.cid.value : this.cid,
      quality: data.quality.present ? data.quality.value : this.quality,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      duration: data.duration.present ? data.duration.value : this.duration,
      status: data.status.present ? data.status.value : this.status,
      progress: data.progress.present ? data.progress.value : this.progress,
      downloadedBytes: data.downloadedBytes.present
          ? data.downloadedBytes.value
          : this.downloadedBytes,
      totalBytes:
          data.totalBytes.present ? data.totalBytes.value : this.totalBytes,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      completedAt:
          data.completedAt.present ? data.completedAt.value : this.completedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadTask(')
          ..write('id: $id, ')
          ..write('bvid: $bvid, ')
          ..write('cid: $cid, ')
          ..write('quality: $quality, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('duration: $duration, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('localPath: $localPath, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      bvid,
      cid,
      quality,
      title,
      artist,
      coverUrl,
      duration,
      status,
      progress,
      downloadedBytes,
      totalBytes,
      localPath,
      errorMessage,
      createdAt,
      completedAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadTask &&
          other.id == this.id &&
          other.bvid == this.bvid &&
          other.cid == this.cid &&
          other.quality == this.quality &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.coverUrl == this.coverUrl &&
          other.duration == this.duration &&
          other.status == this.status &&
          other.progress == this.progress &&
          other.downloadedBytes == this.downloadedBytes &&
          other.totalBytes == this.totalBytes &&
          other.localPath == this.localPath &&
          other.errorMessage == this.errorMessage &&
          other.createdAt == this.createdAt &&
          other.completedAt == this.completedAt &&
          other.updatedAt == this.updatedAt);
}

class DownloadTasksCompanion extends UpdateCompanion<DownloadTask> {
  final Value<int> id;
  final Value<String> bvid;
  final Value<int> cid;
  final Value<int> quality;
  final Value<String> title;
  final Value<String?> artist;
  final Value<String?> coverUrl;
  final Value<int?> duration;
  final Value<String> status;
  final Value<int> progress;
  final Value<int> downloadedBytes;
  final Value<int?> totalBytes;
  final Value<String?> localPath;
  final Value<String?> errorMessage;
  final Value<DateTime> createdAt;
  final Value<DateTime?> completedAt;
  final Value<DateTime> updatedAt;
  const DownloadTasksCompanion({
    this.id = const Value.absent(),
    this.bvid = const Value.absent(),
    this.cid = const Value.absent(),
    this.quality = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.duration = const Value.absent(),
    this.status = const Value.absent(),
    this.progress = const Value.absent(),
    this.downloadedBytes = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.localPath = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  DownloadTasksCompanion.insert({
    this.id = const Value.absent(),
    required String bvid,
    required int cid,
    required int quality,
    required String title,
    this.artist = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.duration = const Value.absent(),
    required String status,
    this.progress = const Value.absent(),
    this.downloadedBytes = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.localPath = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : bvid = Value(bvid),
        cid = Value(cid),
        quality = Value(quality),
        title = Value(title),
        status = Value(status);
  static Insertable<DownloadTask> custom({
    Expression<int>? id,
    Expression<String>? bvid,
    Expression<int>? cid,
    Expression<int>? quality,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? coverUrl,
    Expression<int>? duration,
    Expression<String>? status,
    Expression<int>? progress,
    Expression<int>? downloadedBytes,
    Expression<int>? totalBytes,
    Expression<String>? localPath,
    Expression<String>? errorMessage,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? completedAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bvid != null) 'bvid': bvid,
      if (cid != null) 'cid': cid,
      if (quality != null) 'quality': quality,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (duration != null) 'duration': duration,
      if (status != null) 'status': status,
      if (progress != null) 'progress': progress,
      if (downloadedBytes != null) 'downloaded_bytes': downloadedBytes,
      if (totalBytes != null) 'total_bytes': totalBytes,
      if (localPath != null) 'local_path': localPath,
      if (errorMessage != null) 'error_message': errorMessage,
      if (createdAt != null) 'created_at': createdAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  DownloadTasksCompanion copyWith(
      {Value<int>? id,
      Value<String>? bvid,
      Value<int>? cid,
      Value<int>? quality,
      Value<String>? title,
      Value<String?>? artist,
      Value<String?>? coverUrl,
      Value<int?>? duration,
      Value<String>? status,
      Value<int>? progress,
      Value<int>? downloadedBytes,
      Value<int?>? totalBytes,
      Value<String?>? localPath,
      Value<String?>? errorMessage,
      Value<DateTime>? createdAt,
      Value<DateTime?>? completedAt,
      Value<DateTime>? updatedAt}) {
    return DownloadTasksCompanion(
      id: id ?? this.id,
      bvid: bvid ?? this.bvid,
      cid: cid ?? this.cid,
      quality: quality ?? this.quality,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      coverUrl: coverUrl ?? this.coverUrl,
      duration: duration ?? this.duration,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      localPath: localPath ?? this.localPath,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bvid.present) {
      map['bvid'] = Variable<String>(bvid.value);
    }
    if (cid.present) {
      map['cid'] = Variable<int>(cid.value);
    }
    if (quality.present) {
      map['quality'] = Variable<int>(quality.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (duration.present) {
      map['duration'] = Variable<int>(duration.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (progress.present) {
      map['progress'] = Variable<int>(progress.value);
    }
    if (downloadedBytes.present) {
      map['downloaded_bytes'] = Variable<int>(downloadedBytes.value);
    }
    if (totalBytes.present) {
      map['total_bytes'] = Variable<int>(totalBytes.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadTasksCompanion(')
          ..write('id: $id, ')
          ..write('bvid: $bvid, ')
          ..write('cid: $cid, ')
          ..write('quality: $quality, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('duration: $duration, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('localPath: $localPath, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('updatedAt: $updatedAt')
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
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _defaultPlayQualityMeta =
      const VerificationMeta('defaultPlayQuality');
  @override
  late final GeneratedColumn<int> defaultPlayQuality = GeneratedColumn<int>(
      'default_play_quality', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(30232));
  static const VerificationMeta _defaultDownloadQualityMeta =
      const VerificationMeta('defaultDownloadQuality');
  @override
  late final GeneratedColumn<int> defaultDownloadQuality = GeneratedColumn<int>(
      'default_download_quality', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(30280));
  static const VerificationMeta _autoSelectQualityMeta =
      const VerificationMeta('autoSelectQuality');
  @override
  late final GeneratedColumn<bool> autoSelectQuality = GeneratedColumn<bool>(
      'auto_select_quality', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("auto_select_quality" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _wifiOnlyDownloadMeta =
      const VerificationMeta('wifiOnlyDownload');
  @override
  late final GeneratedColumn<bool> wifiOnlyDownload = GeneratedColumn<bool>(
      'wifi_only_download', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("wifi_only_download" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _maxConcurrentDownloadsMeta =
      const VerificationMeta('maxConcurrentDownloads');
  @override
  late final GeneratedColumn<int> maxConcurrentDownloads = GeneratedColumn<int>(
      'max_concurrent_downloads', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(3));
  static const VerificationMeta _autoRetryFailedMeta =
      const VerificationMeta('autoRetryFailed');
  @override
  late final GeneratedColumn<bool> autoRetryFailed = GeneratedColumn<bool>(
      'auto_retry_failed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("auto_retry_failed" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _autoCacheSizeGBMeta =
      const VerificationMeta('autoCacheSizeGB');
  @override
  late final GeneratedColumn<int> autoCacheSizeGB = GeneratedColumn<int>(
      'auto_cache_size_g_b', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(5));
  static const VerificationMeta _downloadDirectoryMeta =
      const VerificationMeta('downloadDirectory');
  @override
  late final GeneratedColumn<String> downloadDirectory =
      GeneratedColumn<String>('download_directory', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        defaultPlayQuality,
        defaultDownloadQuality,
        autoSelectQuality,
        wifiOnlyDownload,
        maxConcurrentDownloads,
        autoRetryFailed,
        autoCacheSizeGB,
        downloadDirectory,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_settings';
  @override
  VerificationContext validateIntegrity(Insertable<UserSetting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('default_play_quality')) {
      context.handle(
          _defaultPlayQualityMeta,
          defaultPlayQuality.isAcceptableOrUnknown(
              data['default_play_quality']!, _defaultPlayQualityMeta));
    }
    if (data.containsKey('default_download_quality')) {
      context.handle(
          _defaultDownloadQualityMeta,
          defaultDownloadQuality.isAcceptableOrUnknown(
              data['default_download_quality']!, _defaultDownloadQualityMeta));
    }
    if (data.containsKey('auto_select_quality')) {
      context.handle(
          _autoSelectQualityMeta,
          autoSelectQuality.isAcceptableOrUnknown(
              data['auto_select_quality']!, _autoSelectQualityMeta));
    }
    if (data.containsKey('wifi_only_download')) {
      context.handle(
          _wifiOnlyDownloadMeta,
          wifiOnlyDownload.isAcceptableOrUnknown(
              data['wifi_only_download']!, _wifiOnlyDownloadMeta));
    }
    if (data.containsKey('max_concurrent_downloads')) {
      context.handle(
          _maxConcurrentDownloadsMeta,
          maxConcurrentDownloads.isAcceptableOrUnknown(
              data['max_concurrent_downloads']!, _maxConcurrentDownloadsMeta));
    }
    if (data.containsKey('auto_retry_failed')) {
      context.handle(
          _autoRetryFailedMeta,
          autoRetryFailed.isAcceptableOrUnknown(
              data['auto_retry_failed']!, _autoRetryFailedMeta));
    }
    if (data.containsKey('auto_cache_size_g_b')) {
      context.handle(
          _autoCacheSizeGBMeta,
          autoCacheSizeGB.isAcceptableOrUnknown(
              data['auto_cache_size_g_b']!, _autoCacheSizeGBMeta));
    }
    if (data.containsKey('download_directory')) {
      context.handle(
          _downloadDirectoryMeta,
          downloadDirectory.isAcceptableOrUnknown(
              data['download_directory']!, _downloadDirectoryMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserSetting(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      defaultPlayQuality: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}default_play_quality'])!,
      defaultDownloadQuality: attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}default_download_quality'])!,
      autoSelectQuality: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}auto_select_quality'])!,
      wifiOnlyDownload: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}wifi_only_download'])!,
      maxConcurrentDownloads: attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}max_concurrent_downloads'])!,
      autoRetryFailed: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}auto_retry_failed'])!,
      autoCacheSizeGB: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}auto_cache_size_g_b'])!,
      downloadDirectory: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}download_directory']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $UserSettingsTable createAlias(String alias) {
    return $UserSettingsTable(attachedDatabase, alias);
  }
}

class UserSetting extends DataClass implements Insertable<UserSetting> {
  final int id;
  final int defaultPlayQuality;
  final int defaultDownloadQuality;
  final bool autoSelectQuality;
  final bool wifiOnlyDownload;
  final int maxConcurrentDownloads;
  final bool autoRetryFailed;
  final int autoCacheSizeGB;
  final String? downloadDirectory;
  final DateTime createdAt;
  final DateTime updatedAt;
  const UserSetting(
      {required this.id,
      required this.defaultPlayQuality,
      required this.defaultDownloadQuality,
      required this.autoSelectQuality,
      required this.wifiOnlyDownload,
      required this.maxConcurrentDownloads,
      required this.autoRetryFailed,
      required this.autoCacheSizeGB,
      this.downloadDirectory,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['default_play_quality'] = Variable<int>(defaultPlayQuality);
    map['default_download_quality'] = Variable<int>(defaultDownloadQuality);
    map['auto_select_quality'] = Variable<bool>(autoSelectQuality);
    map['wifi_only_download'] = Variable<bool>(wifiOnlyDownload);
    map['max_concurrent_downloads'] = Variable<int>(maxConcurrentDownloads);
    map['auto_retry_failed'] = Variable<bool>(autoRetryFailed);
    map['auto_cache_size_g_b'] = Variable<int>(autoCacheSizeGB);
    if (!nullToAbsent || downloadDirectory != null) {
      map['download_directory'] = Variable<String>(downloadDirectory);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UserSettingsCompanion toCompanion(bool nullToAbsent) {
    return UserSettingsCompanion(
      id: Value(id),
      defaultPlayQuality: Value(defaultPlayQuality),
      defaultDownloadQuality: Value(defaultDownloadQuality),
      autoSelectQuality: Value(autoSelectQuality),
      wifiOnlyDownload: Value(wifiOnlyDownload),
      maxConcurrentDownloads: Value(maxConcurrentDownloads),
      autoRetryFailed: Value(autoRetryFailed),
      autoCacheSizeGB: Value(autoCacheSizeGB),
      downloadDirectory: downloadDirectory == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadDirectory),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserSetting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserSetting(
      id: serializer.fromJson<int>(json['id']),
      defaultPlayQuality: serializer.fromJson<int>(json['defaultPlayQuality']),
      defaultDownloadQuality:
          serializer.fromJson<int>(json['defaultDownloadQuality']),
      autoSelectQuality: serializer.fromJson<bool>(json['autoSelectQuality']),
      wifiOnlyDownload: serializer.fromJson<bool>(json['wifiOnlyDownload']),
      maxConcurrentDownloads:
          serializer.fromJson<int>(json['maxConcurrentDownloads']),
      autoRetryFailed: serializer.fromJson<bool>(json['autoRetryFailed']),
      autoCacheSizeGB: serializer.fromJson<int>(json['autoCacheSizeGB']),
      downloadDirectory:
          serializer.fromJson<String?>(json['downloadDirectory']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'defaultPlayQuality': serializer.toJson<int>(defaultPlayQuality),
      'defaultDownloadQuality': serializer.toJson<int>(defaultDownloadQuality),
      'autoSelectQuality': serializer.toJson<bool>(autoSelectQuality),
      'wifiOnlyDownload': serializer.toJson<bool>(wifiOnlyDownload),
      'maxConcurrentDownloads': serializer.toJson<int>(maxConcurrentDownloads),
      'autoRetryFailed': serializer.toJson<bool>(autoRetryFailed),
      'autoCacheSizeGB': serializer.toJson<int>(autoCacheSizeGB),
      'downloadDirectory': serializer.toJson<String?>(downloadDirectory),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserSetting copyWith(
          {int? id,
          int? defaultPlayQuality,
          int? defaultDownloadQuality,
          bool? autoSelectQuality,
          bool? wifiOnlyDownload,
          int? maxConcurrentDownloads,
          bool? autoRetryFailed,
          int? autoCacheSizeGB,
          Value<String?> downloadDirectory = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      UserSetting(
        id: id ?? this.id,
        defaultPlayQuality: defaultPlayQuality ?? this.defaultPlayQuality,
        defaultDownloadQuality:
            defaultDownloadQuality ?? this.defaultDownloadQuality,
        autoSelectQuality: autoSelectQuality ?? this.autoSelectQuality,
        wifiOnlyDownload: wifiOnlyDownload ?? this.wifiOnlyDownload,
        maxConcurrentDownloads:
            maxConcurrentDownloads ?? this.maxConcurrentDownloads,
        autoRetryFailed: autoRetryFailed ?? this.autoRetryFailed,
        autoCacheSizeGB: autoCacheSizeGB ?? this.autoCacheSizeGB,
        downloadDirectory: downloadDirectory.present
            ? downloadDirectory.value
            : this.downloadDirectory,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  UserSetting copyWithCompanion(UserSettingsCompanion data) {
    return UserSetting(
      id: data.id.present ? data.id.value : this.id,
      defaultPlayQuality: data.defaultPlayQuality.present
          ? data.defaultPlayQuality.value
          : this.defaultPlayQuality,
      defaultDownloadQuality: data.defaultDownloadQuality.present
          ? data.defaultDownloadQuality.value
          : this.defaultDownloadQuality,
      autoSelectQuality: data.autoSelectQuality.present
          ? data.autoSelectQuality.value
          : this.autoSelectQuality,
      wifiOnlyDownload: data.wifiOnlyDownload.present
          ? data.wifiOnlyDownload.value
          : this.wifiOnlyDownload,
      maxConcurrentDownloads: data.maxConcurrentDownloads.present
          ? data.maxConcurrentDownloads.value
          : this.maxConcurrentDownloads,
      autoRetryFailed: data.autoRetryFailed.present
          ? data.autoRetryFailed.value
          : this.autoRetryFailed,
      autoCacheSizeGB: data.autoCacheSizeGB.present
          ? data.autoCacheSizeGB.value
          : this.autoCacheSizeGB,
      downloadDirectory: data.downloadDirectory.present
          ? data.downloadDirectory.value
          : this.downloadDirectory,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserSetting(')
          ..write('id: $id, ')
          ..write('defaultPlayQuality: $defaultPlayQuality, ')
          ..write('defaultDownloadQuality: $defaultDownloadQuality, ')
          ..write('autoSelectQuality: $autoSelectQuality, ')
          ..write('wifiOnlyDownload: $wifiOnlyDownload, ')
          ..write('maxConcurrentDownloads: $maxConcurrentDownloads, ')
          ..write('autoRetryFailed: $autoRetryFailed, ')
          ..write('autoCacheSizeGB: $autoCacheSizeGB, ')
          ..write('downloadDirectory: $downloadDirectory, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      defaultPlayQuality,
      defaultDownloadQuality,
      autoSelectQuality,
      wifiOnlyDownload,
      maxConcurrentDownloads,
      autoRetryFailed,
      autoCacheSizeGB,
      downloadDirectory,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserSetting &&
          other.id == this.id &&
          other.defaultPlayQuality == this.defaultPlayQuality &&
          other.defaultDownloadQuality == this.defaultDownloadQuality &&
          other.autoSelectQuality == this.autoSelectQuality &&
          other.wifiOnlyDownload == this.wifiOnlyDownload &&
          other.maxConcurrentDownloads == this.maxConcurrentDownloads &&
          other.autoRetryFailed == this.autoRetryFailed &&
          other.autoCacheSizeGB == this.autoCacheSizeGB &&
          other.downloadDirectory == this.downloadDirectory &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class UserSettingsCompanion extends UpdateCompanion<UserSetting> {
  final Value<int> id;
  final Value<int> defaultPlayQuality;
  final Value<int> defaultDownloadQuality;
  final Value<bool> autoSelectQuality;
  final Value<bool> wifiOnlyDownload;
  final Value<int> maxConcurrentDownloads;
  final Value<bool> autoRetryFailed;
  final Value<int> autoCacheSizeGB;
  final Value<String?> downloadDirectory;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const UserSettingsCompanion({
    this.id = const Value.absent(),
    this.defaultPlayQuality = const Value.absent(),
    this.defaultDownloadQuality = const Value.absent(),
    this.autoSelectQuality = const Value.absent(),
    this.wifiOnlyDownload = const Value.absent(),
    this.maxConcurrentDownloads = const Value.absent(),
    this.autoRetryFailed = const Value.absent(),
    this.autoCacheSizeGB = const Value.absent(),
    this.downloadDirectory = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  UserSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.defaultPlayQuality = const Value.absent(),
    this.defaultDownloadQuality = const Value.absent(),
    this.autoSelectQuality = const Value.absent(),
    this.wifiOnlyDownload = const Value.absent(),
    this.maxConcurrentDownloads = const Value.absent(),
    this.autoRetryFailed = const Value.absent(),
    this.autoCacheSizeGB = const Value.absent(),
    this.downloadDirectory = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  static Insertable<UserSetting> custom({
    Expression<int>? id,
    Expression<int>? defaultPlayQuality,
    Expression<int>? defaultDownloadQuality,
    Expression<bool>? autoSelectQuality,
    Expression<bool>? wifiOnlyDownload,
    Expression<int>? maxConcurrentDownloads,
    Expression<bool>? autoRetryFailed,
    Expression<int>? autoCacheSizeGB,
    Expression<String>? downloadDirectory,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (defaultPlayQuality != null)
        'default_play_quality': defaultPlayQuality,
      if (defaultDownloadQuality != null)
        'default_download_quality': defaultDownloadQuality,
      if (autoSelectQuality != null) 'auto_select_quality': autoSelectQuality,
      if (wifiOnlyDownload != null) 'wifi_only_download': wifiOnlyDownload,
      if (maxConcurrentDownloads != null)
        'max_concurrent_downloads': maxConcurrentDownloads,
      if (autoRetryFailed != null) 'auto_retry_failed': autoRetryFailed,
      if (autoCacheSizeGB != null) 'auto_cache_size_g_b': autoCacheSizeGB,
      if (downloadDirectory != null) 'download_directory': downloadDirectory,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  UserSettingsCompanion copyWith(
      {Value<int>? id,
      Value<int>? defaultPlayQuality,
      Value<int>? defaultDownloadQuality,
      Value<bool>? autoSelectQuality,
      Value<bool>? wifiOnlyDownload,
      Value<int>? maxConcurrentDownloads,
      Value<bool>? autoRetryFailed,
      Value<int>? autoCacheSizeGB,
      Value<String?>? downloadDirectory,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt}) {
    return UserSettingsCompanion(
      id: id ?? this.id,
      defaultPlayQuality: defaultPlayQuality ?? this.defaultPlayQuality,
      defaultDownloadQuality:
          defaultDownloadQuality ?? this.defaultDownloadQuality,
      autoSelectQuality: autoSelectQuality ?? this.autoSelectQuality,
      wifiOnlyDownload: wifiOnlyDownload ?? this.wifiOnlyDownload,
      maxConcurrentDownloads:
          maxConcurrentDownloads ?? this.maxConcurrentDownloads,
      autoRetryFailed: autoRetryFailed ?? this.autoRetryFailed,
      autoCacheSizeGB: autoCacheSizeGB ?? this.autoCacheSizeGB,
      downloadDirectory: downloadDirectory ?? this.downloadDirectory,
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
    if (defaultPlayQuality.present) {
      map['default_play_quality'] = Variable<int>(defaultPlayQuality.value);
    }
    if (defaultDownloadQuality.present) {
      map['default_download_quality'] =
          Variable<int>(defaultDownloadQuality.value);
    }
    if (autoSelectQuality.present) {
      map['auto_select_quality'] = Variable<bool>(autoSelectQuality.value);
    }
    if (wifiOnlyDownload.present) {
      map['wifi_only_download'] = Variable<bool>(wifiOnlyDownload.value);
    }
    if (maxConcurrentDownloads.present) {
      map['max_concurrent_downloads'] =
          Variable<int>(maxConcurrentDownloads.value);
    }
    if (autoRetryFailed.present) {
      map['auto_retry_failed'] = Variable<bool>(autoRetryFailed.value);
    }
    if (autoCacheSizeGB.present) {
      map['auto_cache_size_g_b'] = Variable<int>(autoCacheSizeGB.value);
    }
    if (downloadDirectory.present) {
      map['download_directory'] = Variable<String>(downloadDirectory.value);
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
          ..write('defaultPlayQuality: $defaultPlayQuality, ')
          ..write('defaultDownloadQuality: $defaultDownloadQuality, ')
          ..write('autoSelectQuality: $autoSelectQuality, ')
          ..write('wifiOnlyDownload: $wifiOnlyDownload, ')
          ..write('maxConcurrentDownloads: $maxConcurrentDownloads, ')
          ..write('autoRetryFailed: $autoRetryFailed, ')
          ..write('autoCacheSizeGB: $autoCacheSizeGB, ')
          ..write('downloadDirectory: $downloadDirectory, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$MusicDatabase extends GeneratedDatabase {
  _$MusicDatabase(QueryExecutor e) : super(e);
  $MusicDatabaseManager get managers => $MusicDatabaseManager(this);
  late final $BilibiliVideosTable bilibiliVideos = $BilibiliVideosTable(this);
  late final $BilibiliFavoritesTable bilibiliFavorites =
      $BilibiliFavoritesTable(this);
  late final $SongsTable songs = $SongsTable(this);
  late final $BilibiliAudioCacheTable bilibiliAudioCache =
      $BilibiliAudioCacheTable(this);
  late final $DownloadTasksTable downloadTasks = $DownloadTasksTable(this);
  late final $UserSettingsTable userSettings = $UserSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        bilibiliVideos,
        bilibiliFavorites,
        songs,
        bilibiliAudioCache,
        downloadTasks,
        userSettings
      ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('bilibili_videos',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('songs', kind: UpdateKind.update),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('bilibili_favorites',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('songs', kind: UpdateKind.update),
            ],
          ),
        ],
      );
}

typedef $$BilibiliVideosTableCreateCompanionBuilder = BilibiliVideosCompanion
    Function({
  Value<int> id,
  required String bvid,
  required int aid,
  required int cid,
  required String title,
  Value<String?> coverUrl,
  required int duration,
  required String author,
  required int authorMid,
  required DateTime publishDate,
  Value<String?> description,
  Value<bool> isMultiPage,
  Value<int> pageCount,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$BilibiliVideosTableUpdateCompanionBuilder = BilibiliVideosCompanion
    Function({
  Value<int> id,
  Value<String> bvid,
  Value<int> aid,
  Value<int> cid,
  Value<String> title,
  Value<String?> coverUrl,
  Value<int> duration,
  Value<String> author,
  Value<int> authorMid,
  Value<DateTime> publishDate,
  Value<String?> description,
  Value<bool> isMultiPage,
  Value<int> pageCount,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

final class $$BilibiliVideosTableReferences extends BaseReferences<
    _$MusicDatabase, $BilibiliVideosTable, BilibiliVideo> {
  $$BilibiliVideosTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SongsTable, List<Song>> _songsRefsTable(
          _$MusicDatabase db) =>
      MultiTypedResultKey.fromTable(db.songs,
          aliasName: $_aliasNameGenerator(
              db.bilibiliVideos.id, db.songs.bilibiliVideoId));

  $$SongsTableProcessedTableManager get songsRefs {
    final manager = $$SongsTableTableManager($_db, $_db.songs).filter(
        (f) => f.bilibiliVideoId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_songsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$BilibiliVideosTableFilterComposer
    extends Composer<_$MusicDatabase, $BilibiliVideosTable> {
  $$BilibiliVideosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bvid => $composableBuilder(
      column: $table.bvid, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get aid => $composableBuilder(
      column: $table.aid, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cid => $composableBuilder(
      column: $table.cid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get coverUrl => $composableBuilder(
      column: $table.coverUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get duration => $composableBuilder(
      column: $table.duration, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get author => $composableBuilder(
      column: $table.author, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get authorMid => $composableBuilder(
      column: $table.authorMid, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get publishDate => $composableBuilder(
      column: $table.publishDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isMultiPage => $composableBuilder(
      column: $table.isMultiPage, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pageCount => $composableBuilder(
      column: $table.pageCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> songsRefs(
      Expression<bool> Function($$SongsTableFilterComposer f) f) {
    final $$SongsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.songs,
        getReferencedColumn: (t) => t.bilibiliVideoId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SongsTableFilterComposer(
              $db: $db,
              $table: $db.songs,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$BilibiliVideosTableOrderingComposer
    extends Composer<_$MusicDatabase, $BilibiliVideosTable> {
  $$BilibiliVideosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bvid => $composableBuilder(
      column: $table.bvid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get aid => $composableBuilder(
      column: $table.aid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cid => $composableBuilder(
      column: $table.cid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get coverUrl => $composableBuilder(
      column: $table.coverUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get duration => $composableBuilder(
      column: $table.duration, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get author => $composableBuilder(
      column: $table.author, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get authorMid => $composableBuilder(
      column: $table.authorMid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get publishDate => $composableBuilder(
      column: $table.publishDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isMultiPage => $composableBuilder(
      column: $table.isMultiPage, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pageCount => $composableBuilder(
      column: $table.pageCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$BilibiliVideosTableAnnotationComposer
    extends Composer<_$MusicDatabase, $BilibiliVideosTable> {
  $$BilibiliVideosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bvid =>
      $composableBuilder(column: $table.bvid, builder: (column) => column);

  GeneratedColumn<int> get aid =>
      $composableBuilder(column: $table.aid, builder: (column) => column);

  GeneratedColumn<int> get cid =>
      $composableBuilder(column: $table.cid, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<int> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<int> get authorMid =>
      $composableBuilder(column: $table.authorMid, builder: (column) => column);

  GeneratedColumn<DateTime> get publishDate => $composableBuilder(
      column: $table.publishDate, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<bool> get isMultiPage => $composableBuilder(
      column: $table.isMultiPage, builder: (column) => column);

  GeneratedColumn<int> get pageCount =>
      $composableBuilder(column: $table.pageCount, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> songsRefs<T extends Object>(
      Expression<T> Function($$SongsTableAnnotationComposer a) f) {
    final $$SongsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.songs,
        getReferencedColumn: (t) => t.bilibiliVideoId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SongsTableAnnotationComposer(
              $db: $db,
              $table: $db.songs,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$BilibiliVideosTableTableManager extends RootTableManager<
    _$MusicDatabase,
    $BilibiliVideosTable,
    BilibiliVideo,
    $$BilibiliVideosTableFilterComposer,
    $$BilibiliVideosTableOrderingComposer,
    $$BilibiliVideosTableAnnotationComposer,
    $$BilibiliVideosTableCreateCompanionBuilder,
    $$BilibiliVideosTableUpdateCompanionBuilder,
    (BilibiliVideo, $$BilibiliVideosTableReferences),
    BilibiliVideo,
    PrefetchHooks Function({bool songsRefs})> {
  $$BilibiliVideosTableTableManager(
      _$MusicDatabase db, $BilibiliVideosTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BilibiliVideosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BilibiliVideosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BilibiliVideosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> bvid = const Value.absent(),
            Value<int> aid = const Value.absent(),
            Value<int> cid = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> coverUrl = const Value.absent(),
            Value<int> duration = const Value.absent(),
            Value<String> author = const Value.absent(),
            Value<int> authorMid = const Value.absent(),
            Value<DateTime> publishDate = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<bool> isMultiPage = const Value.absent(),
            Value<int> pageCount = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              BilibiliVideosCompanion(
            id: id,
            bvid: bvid,
            aid: aid,
            cid: cid,
            title: title,
            coverUrl: coverUrl,
            duration: duration,
            author: author,
            authorMid: authorMid,
            publishDate: publishDate,
            description: description,
            isMultiPage: isMultiPage,
            pageCount: pageCount,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String bvid,
            required int aid,
            required int cid,
            required String title,
            Value<String?> coverUrl = const Value.absent(),
            required int duration,
            required String author,
            required int authorMid,
            required DateTime publishDate,
            Value<String?> description = const Value.absent(),
            Value<bool> isMultiPage = const Value.absent(),
            Value<int> pageCount = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              BilibiliVideosCompanion.insert(
            id: id,
            bvid: bvid,
            aid: aid,
            cid: cid,
            title: title,
            coverUrl: coverUrl,
            duration: duration,
            author: author,
            authorMid: authorMid,
            publishDate: publishDate,
            description: description,
            isMultiPage: isMultiPage,
            pageCount: pageCount,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$BilibiliVideosTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({songsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (songsRefs) db.songs],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (songsRefs)
                    await $_getPrefetchedData<BilibiliVideo,
                            $BilibiliVideosTable, Song>(
                        currentTable: table,
                        referencedTable:
                            $$BilibiliVideosTableReferences._songsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$BilibiliVideosTableReferences(db, table, p0)
                                .songsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.bilibiliVideoId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$BilibiliVideosTableProcessedTableManager = ProcessedTableManager<
    _$MusicDatabase,
    $BilibiliVideosTable,
    BilibiliVideo,
    $$BilibiliVideosTableFilterComposer,
    $$BilibiliVideosTableOrderingComposer,
    $$BilibiliVideosTableAnnotationComposer,
    $$BilibiliVideosTableCreateCompanionBuilder,
    $$BilibiliVideosTableUpdateCompanionBuilder,
    (BilibiliVideo, $$BilibiliVideosTableReferences),
    BilibiliVideo,
    PrefetchHooks Function({bool songsRefs})>;
typedef $$BilibiliFavoritesTableCreateCompanionBuilder
    = BilibiliFavoritesCompanion Function({
  Value<int> id,
  required int remoteId,
  required String title,
  Value<String?> description,
  Value<String?> coverUrl,
  Value<int> mediaCount,
  required DateTime syncedAt,
  Value<DateTime> createdAt,
  Value<bool> isAddedToLibrary,
  Value<bool> isLocal,
});
typedef $$BilibiliFavoritesTableUpdateCompanionBuilder
    = BilibiliFavoritesCompanion Function({
  Value<int> id,
  Value<int> remoteId,
  Value<String> title,
  Value<String?> description,
  Value<String?> coverUrl,
  Value<int> mediaCount,
  Value<DateTime> syncedAt,
  Value<DateTime> createdAt,
  Value<bool> isAddedToLibrary,
  Value<bool> isLocal,
});

final class $$BilibiliFavoritesTableReferences extends BaseReferences<
    _$MusicDatabase, $BilibiliFavoritesTable, BilibiliFavorite> {
  $$BilibiliFavoritesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SongsTable, List<Song>> _songsRefsTable(
          _$MusicDatabase db) =>
      MultiTypedResultKey.fromTable(db.songs,
          aliasName: $_aliasNameGenerator(
              db.bilibiliFavorites.id, db.songs.bilibiliFavoriteId));

  $$SongsTableProcessedTableManager get songsRefs {
    final manager = $$SongsTableTableManager($_db, $_db.songs).filter(
        (f) => f.bilibiliFavoriteId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_songsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$BilibiliFavoritesTableFilterComposer
    extends Composer<_$MusicDatabase, $BilibiliFavoritesTable> {
  $$BilibiliFavoritesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get coverUrl => $composableBuilder(
      column: $table.coverUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get mediaCount => $composableBuilder(
      column: $table.mediaCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isAddedToLibrary => $composableBuilder(
      column: $table.isAddedToLibrary,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isLocal => $composableBuilder(
      column: $table.isLocal, builder: (column) => ColumnFilters(column));

  Expression<bool> songsRefs(
      Expression<bool> Function($$SongsTableFilterComposer f) f) {
    final $$SongsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.songs,
        getReferencedColumn: (t) => t.bilibiliFavoriteId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SongsTableFilterComposer(
              $db: $db,
              $table: $db.songs,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$BilibiliFavoritesTableOrderingComposer
    extends Composer<_$MusicDatabase, $BilibiliFavoritesTable> {
  $$BilibiliFavoritesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get coverUrl => $composableBuilder(
      column: $table.coverUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get mediaCount => $composableBuilder(
      column: $table.mediaCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isAddedToLibrary => $composableBuilder(
      column: $table.isAddedToLibrary,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isLocal => $composableBuilder(
      column: $table.isLocal, builder: (column) => ColumnOrderings(column));
}

class $$BilibiliFavoritesTableAnnotationComposer
    extends Composer<_$MusicDatabase, $BilibiliFavoritesTable> {
  $$BilibiliFavoritesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<int> get mediaCount => $composableBuilder(
      column: $table.mediaCount, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get isAddedToLibrary => $composableBuilder(
      column: $table.isAddedToLibrary, builder: (column) => column);

  GeneratedColumn<bool> get isLocal =>
      $composableBuilder(column: $table.isLocal, builder: (column) => column);

  Expression<T> songsRefs<T extends Object>(
      Expression<T> Function($$SongsTableAnnotationComposer a) f) {
    final $$SongsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.songs,
        getReferencedColumn: (t) => t.bilibiliFavoriteId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SongsTableAnnotationComposer(
              $db: $db,
              $table: $db.songs,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$BilibiliFavoritesTableTableManager extends RootTableManager<
    _$MusicDatabase,
    $BilibiliFavoritesTable,
    BilibiliFavorite,
    $$BilibiliFavoritesTableFilterComposer,
    $$BilibiliFavoritesTableOrderingComposer,
    $$BilibiliFavoritesTableAnnotationComposer,
    $$BilibiliFavoritesTableCreateCompanionBuilder,
    $$BilibiliFavoritesTableUpdateCompanionBuilder,
    (BilibiliFavorite, $$BilibiliFavoritesTableReferences),
    BilibiliFavorite,
    PrefetchHooks Function({bool songsRefs})> {
  $$BilibiliFavoritesTableTableManager(
      _$MusicDatabase db, $BilibiliFavoritesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BilibiliFavoritesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BilibiliFavoritesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BilibiliFavoritesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> remoteId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String?> coverUrl = const Value.absent(),
            Value<int> mediaCount = const Value.absent(),
            Value<DateTime> syncedAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<bool> isAddedToLibrary = const Value.absent(),
            Value<bool> isLocal = const Value.absent(),
          }) =>
              BilibiliFavoritesCompanion(
            id: id,
            remoteId: remoteId,
            title: title,
            description: description,
            coverUrl: coverUrl,
            mediaCount: mediaCount,
            syncedAt: syncedAt,
            createdAt: createdAt,
            isAddedToLibrary: isAddedToLibrary,
            isLocal: isLocal,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int remoteId,
            required String title,
            Value<String?> description = const Value.absent(),
            Value<String?> coverUrl = const Value.absent(),
            Value<int> mediaCount = const Value.absent(),
            required DateTime syncedAt,
            Value<DateTime> createdAt = const Value.absent(),
            Value<bool> isAddedToLibrary = const Value.absent(),
            Value<bool> isLocal = const Value.absent(),
          }) =>
              BilibiliFavoritesCompanion.insert(
            id: id,
            remoteId: remoteId,
            title: title,
            description: description,
            coverUrl: coverUrl,
            mediaCount: mediaCount,
            syncedAt: syncedAt,
            createdAt: createdAt,
            isAddedToLibrary: isAddedToLibrary,
            isLocal: isLocal,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$BilibiliFavoritesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({songsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (songsRefs) db.songs],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (songsRefs)
                    await $_getPrefetchedData<BilibiliFavorite,
                            $BilibiliFavoritesTable, Song>(
                        currentTable: table,
                        referencedTable: $$BilibiliFavoritesTableReferences
                            ._songsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$BilibiliFavoritesTableReferences(db, table, p0)
                                .songsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.bilibiliFavoriteId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$BilibiliFavoritesTableProcessedTableManager = ProcessedTableManager<
    _$MusicDatabase,
    $BilibiliFavoritesTable,
    BilibiliFavorite,
    $$BilibiliFavoritesTableFilterComposer,
    $$BilibiliFavoritesTableOrderingComposer,
    $$BilibiliFavoritesTableAnnotationComposer,
    $$BilibiliFavoritesTableCreateCompanionBuilder,
    $$BilibiliFavoritesTableUpdateCompanionBuilder,
    (BilibiliFavorite, $$BilibiliFavoritesTableReferences),
    BilibiliFavorite,
    PrefetchHooks Function({bool songsRefs})>;
typedef $$SongsTableCreateCompanionBuilder = SongsCompanion Function({
  Value<int> id,
  required String title,
  Value<String?> artist,
  Value<String?> album,
  required String filePath,
  Value<String?> lyrics,
  Value<int?> bitrate,
  Value<int?> sampleRate,
  Value<int?> duration,
  Value<String?> albumArtPath,
  Value<DateTime> dateAdded,
  Value<bool> isFavorite,
  Value<DateTime> lastPlayedTime,
  Value<int> playedCount,
  Value<String> source,
  Value<String?> bvid,
  Value<int?> cid,
  Value<int?> pageNumber,
  Value<int?> bilibiliVideoId,
  Value<int?> bilibiliFavoriteId,
  Value<String?> downloadedQualities,
  Value<int?> currentQuality,
});
typedef $$SongsTableUpdateCompanionBuilder = SongsCompanion Function({
  Value<int> id,
  Value<String> title,
  Value<String?> artist,
  Value<String?> album,
  Value<String> filePath,
  Value<String?> lyrics,
  Value<int?> bitrate,
  Value<int?> sampleRate,
  Value<int?> duration,
  Value<String?> albumArtPath,
  Value<DateTime> dateAdded,
  Value<bool> isFavorite,
  Value<DateTime> lastPlayedTime,
  Value<int> playedCount,
  Value<String> source,
  Value<String?> bvid,
  Value<int?> cid,
  Value<int?> pageNumber,
  Value<int?> bilibiliVideoId,
  Value<int?> bilibiliFavoriteId,
  Value<String?> downloadedQualities,
  Value<int?> currentQuality,
});

final class $$SongsTableReferences
    extends BaseReferences<_$MusicDatabase, $SongsTable, Song> {
  $$SongsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BilibiliVideosTable _bilibiliVideoIdTable(_$MusicDatabase db) =>
      db.bilibiliVideos.createAlias(
          $_aliasNameGenerator(db.songs.bilibiliVideoId, db.bilibiliVideos.id));

  $$BilibiliVideosTableProcessedTableManager? get bilibiliVideoId {
    final $_column = $_itemColumn<int>('bilibili_video_id');
    if ($_column == null) return null;
    final manager = $$BilibiliVideosTableTableManager($_db, $_db.bilibiliVideos)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bilibiliVideoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $BilibiliFavoritesTable _bilibiliFavoriteIdTable(_$MusicDatabase db) =>
      db.bilibiliFavorites.createAlias($_aliasNameGenerator(
          db.songs.bilibiliFavoriteId, db.bilibiliFavorites.id));

  $$BilibiliFavoritesTableProcessedTableManager? get bilibiliFavoriteId {
    final $_column = $_itemColumn<int>('bilibili_favorite_id');
    if ($_column == null) return null;
    final manager =
        $$BilibiliFavoritesTableTableManager($_db, $_db.bilibiliFavorites)
            .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bilibiliFavoriteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$SongsTableFilterComposer
    extends Composer<_$MusicDatabase, $SongsTable> {
  $$SongsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get album => $composableBuilder(
      column: $table.album, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lyrics => $composableBuilder(
      column: $table.lyrics, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get bitrate => $composableBuilder(
      column: $table.bitrate, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sampleRate => $composableBuilder(
      column: $table.sampleRate, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get duration => $composableBuilder(
      column: $table.duration, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get albumArtPath => $composableBuilder(
      column: $table.albumArtPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get dateAdded => $composableBuilder(
      column: $table.dateAdded, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastPlayedTime => $composableBuilder(
      column: $table.lastPlayedTime,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get playedCount => $composableBuilder(
      column: $table.playedCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bvid => $composableBuilder(
      column: $table.bvid, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cid => $composableBuilder(
      column: $table.cid, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pageNumber => $composableBuilder(
      column: $table.pageNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get downloadedQualities => $composableBuilder(
      column: $table.downloadedQualities,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get currentQuality => $composableBuilder(
      column: $table.currentQuality,
      builder: (column) => ColumnFilters(column));

  $$BilibiliVideosTableFilterComposer get bilibiliVideoId {
    final $$BilibiliVideosTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bilibiliVideoId,
        referencedTable: $db.bilibiliVideos,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BilibiliVideosTableFilterComposer(
              $db: $db,
              $table: $db.bilibiliVideos,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$BilibiliFavoritesTableFilterComposer get bilibiliFavoriteId {
    final $$BilibiliFavoritesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bilibiliFavoriteId,
        referencedTable: $db.bilibiliFavorites,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BilibiliFavoritesTableFilterComposer(
              $db: $db,
              $table: $db.bilibiliFavorites,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SongsTableOrderingComposer
    extends Composer<_$MusicDatabase, $SongsTable> {
  $$SongsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get album => $composableBuilder(
      column: $table.album, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lyrics => $composableBuilder(
      column: $table.lyrics, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get bitrate => $composableBuilder(
      column: $table.bitrate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sampleRate => $composableBuilder(
      column: $table.sampleRate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get duration => $composableBuilder(
      column: $table.duration, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get albumArtPath => $composableBuilder(
      column: $table.albumArtPath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get dateAdded => $composableBuilder(
      column: $table.dateAdded, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastPlayedTime => $composableBuilder(
      column: $table.lastPlayedTime,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get playedCount => $composableBuilder(
      column: $table.playedCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bvid => $composableBuilder(
      column: $table.bvid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cid => $composableBuilder(
      column: $table.cid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pageNumber => $composableBuilder(
      column: $table.pageNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get downloadedQualities => $composableBuilder(
      column: $table.downloadedQualities,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get currentQuality => $composableBuilder(
      column: $table.currentQuality,
      builder: (column) => ColumnOrderings(column));

  $$BilibiliVideosTableOrderingComposer get bilibiliVideoId {
    final $$BilibiliVideosTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bilibiliVideoId,
        referencedTable: $db.bilibiliVideos,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BilibiliVideosTableOrderingComposer(
              $db: $db,
              $table: $db.bilibiliVideos,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$BilibiliFavoritesTableOrderingComposer get bilibiliFavoriteId {
    final $$BilibiliFavoritesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bilibiliFavoriteId,
        referencedTable: $db.bilibiliFavorites,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BilibiliFavoritesTableOrderingComposer(
              $db: $db,
              $table: $db.bilibiliFavorites,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SongsTableAnnotationComposer
    extends Composer<_$MusicDatabase, $SongsTable> {
  $$SongsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get lyrics =>
      $composableBuilder(column: $table.lyrics, builder: (column) => column);

  GeneratedColumn<int> get bitrate =>
      $composableBuilder(column: $table.bitrate, builder: (column) => column);

  GeneratedColumn<int> get sampleRate => $composableBuilder(
      column: $table.sampleRate, builder: (column) => column);

  GeneratedColumn<int> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<String> get albumArtPath => $composableBuilder(
      column: $table.albumArtPath, builder: (column) => column);

  GeneratedColumn<DateTime> get dateAdded =>
      $composableBuilder(column: $table.dateAdded, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => column);

  GeneratedColumn<DateTime> get lastPlayedTime => $composableBuilder(
      column: $table.lastPlayedTime, builder: (column) => column);

  GeneratedColumn<int> get playedCount => $composableBuilder(
      column: $table.playedCount, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get bvid =>
      $composableBuilder(column: $table.bvid, builder: (column) => column);

  GeneratedColumn<int> get cid =>
      $composableBuilder(column: $table.cid, builder: (column) => column);

  GeneratedColumn<int> get pageNumber => $composableBuilder(
      column: $table.pageNumber, builder: (column) => column);

  GeneratedColumn<String> get downloadedQualities => $composableBuilder(
      column: $table.downloadedQualities, builder: (column) => column);

  GeneratedColumn<int> get currentQuality => $composableBuilder(
      column: $table.currentQuality, builder: (column) => column);

  $$BilibiliVideosTableAnnotationComposer get bilibiliVideoId {
    final $$BilibiliVideosTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bilibiliVideoId,
        referencedTable: $db.bilibiliVideos,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BilibiliVideosTableAnnotationComposer(
              $db: $db,
              $table: $db.bilibiliVideos,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$BilibiliFavoritesTableAnnotationComposer get bilibiliFavoriteId {
    final $$BilibiliFavoritesTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.bilibiliFavoriteId,
            referencedTable: $db.bilibiliFavorites,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$BilibiliFavoritesTableAnnotationComposer(
                  $db: $db,
                  $table: $db.bilibiliFavorites,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return composer;
  }
}

class $$SongsTableTableManager extends RootTableManager<
    _$MusicDatabase,
    $SongsTable,
    Song,
    $$SongsTableFilterComposer,
    $$SongsTableOrderingComposer,
    $$SongsTableAnnotationComposer,
    $$SongsTableCreateCompanionBuilder,
    $$SongsTableUpdateCompanionBuilder,
    (Song, $$SongsTableReferences),
    Song,
    PrefetchHooks Function({bool bilibiliVideoId, bool bilibiliFavoriteId})> {
  $$SongsTableTableManager(_$MusicDatabase db, $SongsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SongsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SongsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SongsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> artist = const Value.absent(),
            Value<String?> album = const Value.absent(),
            Value<String> filePath = const Value.absent(),
            Value<String?> lyrics = const Value.absent(),
            Value<int?> bitrate = const Value.absent(),
            Value<int?> sampleRate = const Value.absent(),
            Value<int?> duration = const Value.absent(),
            Value<String?> albumArtPath = const Value.absent(),
            Value<DateTime> dateAdded = const Value.absent(),
            Value<bool> isFavorite = const Value.absent(),
            Value<DateTime> lastPlayedTime = const Value.absent(),
            Value<int> playedCount = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<String?> bvid = const Value.absent(),
            Value<int?> cid = const Value.absent(),
            Value<int?> pageNumber = const Value.absent(),
            Value<int?> bilibiliVideoId = const Value.absent(),
            Value<int?> bilibiliFavoriteId = const Value.absent(),
            Value<String?> downloadedQualities = const Value.absent(),
            Value<int?> currentQuality = const Value.absent(),
          }) =>
              SongsCompanion(
            id: id,
            title: title,
            artist: artist,
            album: album,
            filePath: filePath,
            lyrics: lyrics,
            bitrate: bitrate,
            sampleRate: sampleRate,
            duration: duration,
            albumArtPath: albumArtPath,
            dateAdded: dateAdded,
            isFavorite: isFavorite,
            lastPlayedTime: lastPlayedTime,
            playedCount: playedCount,
            source: source,
            bvid: bvid,
            cid: cid,
            pageNumber: pageNumber,
            bilibiliVideoId: bilibiliVideoId,
            bilibiliFavoriteId: bilibiliFavoriteId,
            downloadedQualities: downloadedQualities,
            currentQuality: currentQuality,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String title,
            Value<String?> artist = const Value.absent(),
            Value<String?> album = const Value.absent(),
            required String filePath,
            Value<String?> lyrics = const Value.absent(),
            Value<int?> bitrate = const Value.absent(),
            Value<int?> sampleRate = const Value.absent(),
            Value<int?> duration = const Value.absent(),
            Value<String?> albumArtPath = const Value.absent(),
            Value<DateTime> dateAdded = const Value.absent(),
            Value<bool> isFavorite = const Value.absent(),
            Value<DateTime> lastPlayedTime = const Value.absent(),
            Value<int> playedCount = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<String?> bvid = const Value.absent(),
            Value<int?> cid = const Value.absent(),
            Value<int?> pageNumber = const Value.absent(),
            Value<int?> bilibiliVideoId = const Value.absent(),
            Value<int?> bilibiliFavoriteId = const Value.absent(),
            Value<String?> downloadedQualities = const Value.absent(),
            Value<int?> currentQuality = const Value.absent(),
          }) =>
              SongsCompanion.insert(
            id: id,
            title: title,
            artist: artist,
            album: album,
            filePath: filePath,
            lyrics: lyrics,
            bitrate: bitrate,
            sampleRate: sampleRate,
            duration: duration,
            albumArtPath: albumArtPath,
            dateAdded: dateAdded,
            isFavorite: isFavorite,
            lastPlayedTime: lastPlayedTime,
            playedCount: playedCount,
            source: source,
            bvid: bvid,
            cid: cid,
            pageNumber: pageNumber,
            bilibiliVideoId: bilibiliVideoId,
            bilibiliFavoriteId: bilibiliFavoriteId,
            downloadedQualities: downloadedQualities,
            currentQuality: currentQuality,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$SongsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {bilibiliVideoId = false, bilibiliFavoriteId = false}) {
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
                if (bilibiliVideoId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.bilibiliVideoId,
                    referencedTable:
                        $$SongsTableReferences._bilibiliVideoIdTable(db),
                    referencedColumn:
                        $$SongsTableReferences._bilibiliVideoIdTable(db).id,
                  ) as T;
                }
                if (bilibiliFavoriteId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.bilibiliFavoriteId,
                    referencedTable:
                        $$SongsTableReferences._bilibiliFavoriteIdTable(db),
                    referencedColumn:
                        $$SongsTableReferences._bilibiliFavoriteIdTable(db).id,
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

typedef $$SongsTableProcessedTableManager = ProcessedTableManager<
    _$MusicDatabase,
    $SongsTable,
    Song,
    $$SongsTableFilterComposer,
    $$SongsTableOrderingComposer,
    $$SongsTableAnnotationComposer,
    $$SongsTableCreateCompanionBuilder,
    $$SongsTableUpdateCompanionBuilder,
    (Song, $$SongsTableReferences),
    Song,
    PrefetchHooks Function({bool bilibiliVideoId, bool bilibiliFavoriteId})>;
typedef $$BilibiliAudioCacheTableCreateCompanionBuilder
    = BilibiliAudioCacheCompanion Function({
  Value<int> id,
  required String bvid,
  required int cid,
  required int quality,
  required String localFilePath,
  required int fileSize,
  required DateTime lastAccessTime,
  Value<DateTime> downloadedAt,
});
typedef $$BilibiliAudioCacheTableUpdateCompanionBuilder
    = BilibiliAudioCacheCompanion Function({
  Value<int> id,
  Value<String> bvid,
  Value<int> cid,
  Value<int> quality,
  Value<String> localFilePath,
  Value<int> fileSize,
  Value<DateTime> lastAccessTime,
  Value<DateTime> downloadedAt,
});

class $$BilibiliAudioCacheTableFilterComposer
    extends Composer<_$MusicDatabase, $BilibiliAudioCacheTable> {
  $$BilibiliAudioCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bvid => $composableBuilder(
      column: $table.bvid, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cid => $composableBuilder(
      column: $table.cid, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get quality => $composableBuilder(
      column: $table.quality, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localFilePath => $composableBuilder(
      column: $table.localFilePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get fileSize => $composableBuilder(
      column: $table.fileSize, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastAccessTime => $composableBuilder(
      column: $table.lastAccessTime,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get downloadedAt => $composableBuilder(
      column: $table.downloadedAt, builder: (column) => ColumnFilters(column));
}

class $$BilibiliAudioCacheTableOrderingComposer
    extends Composer<_$MusicDatabase, $BilibiliAudioCacheTable> {
  $$BilibiliAudioCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bvid => $composableBuilder(
      column: $table.bvid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cid => $composableBuilder(
      column: $table.cid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get quality => $composableBuilder(
      column: $table.quality, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localFilePath => $composableBuilder(
      column: $table.localFilePath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get fileSize => $composableBuilder(
      column: $table.fileSize, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastAccessTime => $composableBuilder(
      column: $table.lastAccessTime,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get downloadedAt => $composableBuilder(
      column: $table.downloadedAt,
      builder: (column) => ColumnOrderings(column));
}

class $$BilibiliAudioCacheTableAnnotationComposer
    extends Composer<_$MusicDatabase, $BilibiliAudioCacheTable> {
  $$BilibiliAudioCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bvid =>
      $composableBuilder(column: $table.bvid, builder: (column) => column);

  GeneratedColumn<int> get cid =>
      $composableBuilder(column: $table.cid, builder: (column) => column);

  GeneratedColumn<int> get quality =>
      $composableBuilder(column: $table.quality, builder: (column) => column);

  GeneratedColumn<String> get localFilePath => $composableBuilder(
      column: $table.localFilePath, builder: (column) => column);

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAccessTime => $composableBuilder(
      column: $table.lastAccessTime, builder: (column) => column);

  GeneratedColumn<DateTime> get downloadedAt => $composableBuilder(
      column: $table.downloadedAt, builder: (column) => column);
}

class $$BilibiliAudioCacheTableTableManager extends RootTableManager<
    _$MusicDatabase,
    $BilibiliAudioCacheTable,
    BilibiliAudioCacheData,
    $$BilibiliAudioCacheTableFilterComposer,
    $$BilibiliAudioCacheTableOrderingComposer,
    $$BilibiliAudioCacheTableAnnotationComposer,
    $$BilibiliAudioCacheTableCreateCompanionBuilder,
    $$BilibiliAudioCacheTableUpdateCompanionBuilder,
    (
      BilibiliAudioCacheData,
      BaseReferences<_$MusicDatabase, $BilibiliAudioCacheTable,
          BilibiliAudioCacheData>
    ),
    BilibiliAudioCacheData,
    PrefetchHooks Function()> {
  $$BilibiliAudioCacheTableTableManager(
      _$MusicDatabase db, $BilibiliAudioCacheTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BilibiliAudioCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BilibiliAudioCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BilibiliAudioCacheTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> bvid = const Value.absent(),
            Value<int> cid = const Value.absent(),
            Value<int> quality = const Value.absent(),
            Value<String> localFilePath = const Value.absent(),
            Value<int> fileSize = const Value.absent(),
            Value<DateTime> lastAccessTime = const Value.absent(),
            Value<DateTime> downloadedAt = const Value.absent(),
          }) =>
              BilibiliAudioCacheCompanion(
            id: id,
            bvid: bvid,
            cid: cid,
            quality: quality,
            localFilePath: localFilePath,
            fileSize: fileSize,
            lastAccessTime: lastAccessTime,
            downloadedAt: downloadedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String bvid,
            required int cid,
            required int quality,
            required String localFilePath,
            required int fileSize,
            required DateTime lastAccessTime,
            Value<DateTime> downloadedAt = const Value.absent(),
          }) =>
              BilibiliAudioCacheCompanion.insert(
            id: id,
            bvid: bvid,
            cid: cid,
            quality: quality,
            localFilePath: localFilePath,
            fileSize: fileSize,
            lastAccessTime: lastAccessTime,
            downloadedAt: downloadedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BilibiliAudioCacheTableProcessedTableManager = ProcessedTableManager<
    _$MusicDatabase,
    $BilibiliAudioCacheTable,
    BilibiliAudioCacheData,
    $$BilibiliAudioCacheTableFilterComposer,
    $$BilibiliAudioCacheTableOrderingComposer,
    $$BilibiliAudioCacheTableAnnotationComposer,
    $$BilibiliAudioCacheTableCreateCompanionBuilder,
    $$BilibiliAudioCacheTableUpdateCompanionBuilder,
    (
      BilibiliAudioCacheData,
      BaseReferences<_$MusicDatabase, $BilibiliAudioCacheTable,
          BilibiliAudioCacheData>
    ),
    BilibiliAudioCacheData,
    PrefetchHooks Function()>;
typedef $$DownloadTasksTableCreateCompanionBuilder = DownloadTasksCompanion
    Function({
  Value<int> id,
  required String bvid,
  required int cid,
  required int quality,
  required String title,
  Value<String?> artist,
  Value<String?> coverUrl,
  Value<int?> duration,
  required String status,
  Value<int> progress,
  Value<int> downloadedBytes,
  Value<int?> totalBytes,
  Value<String?> localPath,
  Value<String?> errorMessage,
  Value<DateTime> createdAt,
  Value<DateTime?> completedAt,
  Value<DateTime> updatedAt,
});
typedef $$DownloadTasksTableUpdateCompanionBuilder = DownloadTasksCompanion
    Function({
  Value<int> id,
  Value<String> bvid,
  Value<int> cid,
  Value<int> quality,
  Value<String> title,
  Value<String?> artist,
  Value<String?> coverUrl,
  Value<int?> duration,
  Value<String> status,
  Value<int> progress,
  Value<int> downloadedBytes,
  Value<int?> totalBytes,
  Value<String?> localPath,
  Value<String?> errorMessage,
  Value<DateTime> createdAt,
  Value<DateTime?> completedAt,
  Value<DateTime> updatedAt,
});

class $$DownloadTasksTableFilterComposer
    extends Composer<_$MusicDatabase, $DownloadTasksTable> {
  $$DownloadTasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bvid => $composableBuilder(
      column: $table.bvid, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cid => $composableBuilder(
      column: $table.cid, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get quality => $composableBuilder(
      column: $table.quality, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get coverUrl => $composableBuilder(
      column: $table.coverUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get duration => $composableBuilder(
      column: $table.duration, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get progress => $composableBuilder(
      column: $table.progress, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get downloadedBytes => $composableBuilder(
      column: $table.downloadedBytes,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalBytes => $composableBuilder(
      column: $table.totalBytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$DownloadTasksTableOrderingComposer
    extends Composer<_$MusicDatabase, $DownloadTasksTable> {
  $$DownloadTasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bvid => $composableBuilder(
      column: $table.bvid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cid => $composableBuilder(
      column: $table.cid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get quality => $composableBuilder(
      column: $table.quality, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get coverUrl => $composableBuilder(
      column: $table.coverUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get duration => $composableBuilder(
      column: $table.duration, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get progress => $composableBuilder(
      column: $table.progress, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get downloadedBytes => $composableBuilder(
      column: $table.downloadedBytes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalBytes => $composableBuilder(
      column: $table.totalBytes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$DownloadTasksTableAnnotationComposer
    extends Composer<_$MusicDatabase, $DownloadTasksTable> {
  $$DownloadTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bvid =>
      $composableBuilder(column: $table.bvid, builder: (column) => column);

  GeneratedColumn<int> get cid =>
      $composableBuilder(column: $table.cid, builder: (column) => column);

  GeneratedColumn<int> get quality =>
      $composableBuilder(column: $table.quality, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<int> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<int> get downloadedBytes => $composableBuilder(
      column: $table.downloadedBytes, builder: (column) => column);

  GeneratedColumn<int> get totalBytes => $composableBuilder(
      column: $table.totalBytes, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DownloadTasksTableTableManager extends RootTableManager<
    _$MusicDatabase,
    $DownloadTasksTable,
    DownloadTask,
    $$DownloadTasksTableFilterComposer,
    $$DownloadTasksTableOrderingComposer,
    $$DownloadTasksTableAnnotationComposer,
    $$DownloadTasksTableCreateCompanionBuilder,
    $$DownloadTasksTableUpdateCompanionBuilder,
    (
      DownloadTask,
      BaseReferences<_$MusicDatabase, $DownloadTasksTable, DownloadTask>
    ),
    DownloadTask,
    PrefetchHooks Function()> {
  $$DownloadTasksTableTableManager(
      _$MusicDatabase db, $DownloadTasksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadTasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadTasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> bvid = const Value.absent(),
            Value<int> cid = const Value.absent(),
            Value<int> quality = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> artist = const Value.absent(),
            Value<String?> coverUrl = const Value.absent(),
            Value<int?> duration = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> progress = const Value.absent(),
            Value<int> downloadedBytes = const Value.absent(),
            Value<int?> totalBytes = const Value.absent(),
            Value<String?> localPath = const Value.absent(),
            Value<String?> errorMessage = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              DownloadTasksCompanion(
            id: id,
            bvid: bvid,
            cid: cid,
            quality: quality,
            title: title,
            artist: artist,
            coverUrl: coverUrl,
            duration: duration,
            status: status,
            progress: progress,
            downloadedBytes: downloadedBytes,
            totalBytes: totalBytes,
            localPath: localPath,
            errorMessage: errorMessage,
            createdAt: createdAt,
            completedAt: completedAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String bvid,
            required int cid,
            required int quality,
            required String title,
            Value<String?> artist = const Value.absent(),
            Value<String?> coverUrl = const Value.absent(),
            Value<int?> duration = const Value.absent(),
            required String status,
            Value<int> progress = const Value.absent(),
            Value<int> downloadedBytes = const Value.absent(),
            Value<int?> totalBytes = const Value.absent(),
            Value<String?> localPath = const Value.absent(),
            Value<String?> errorMessage = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              DownloadTasksCompanion.insert(
            id: id,
            bvid: bvid,
            cid: cid,
            quality: quality,
            title: title,
            artist: artist,
            coverUrl: coverUrl,
            duration: duration,
            status: status,
            progress: progress,
            downloadedBytes: downloadedBytes,
            totalBytes: totalBytes,
            localPath: localPath,
            errorMessage: errorMessage,
            createdAt: createdAt,
            completedAt: completedAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DownloadTasksTableProcessedTableManager = ProcessedTableManager<
    _$MusicDatabase,
    $DownloadTasksTable,
    DownloadTask,
    $$DownloadTasksTableFilterComposer,
    $$DownloadTasksTableOrderingComposer,
    $$DownloadTasksTableAnnotationComposer,
    $$DownloadTasksTableCreateCompanionBuilder,
    $$DownloadTasksTableUpdateCompanionBuilder,
    (
      DownloadTask,
      BaseReferences<_$MusicDatabase, $DownloadTasksTable, DownloadTask>
    ),
    DownloadTask,
    PrefetchHooks Function()>;
typedef $$UserSettingsTableCreateCompanionBuilder = UserSettingsCompanion
    Function({
  Value<int> id,
  Value<int> defaultPlayQuality,
  Value<int> defaultDownloadQuality,
  Value<bool> autoSelectQuality,
  Value<bool> wifiOnlyDownload,
  Value<int> maxConcurrentDownloads,
  Value<bool> autoRetryFailed,
  Value<int> autoCacheSizeGB,
  Value<String?> downloadDirectory,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$UserSettingsTableUpdateCompanionBuilder = UserSettingsCompanion
    Function({
  Value<int> id,
  Value<int> defaultPlayQuality,
  Value<int> defaultDownloadQuality,
  Value<bool> autoSelectQuality,
  Value<bool> wifiOnlyDownload,
  Value<int> maxConcurrentDownloads,
  Value<bool> autoRetryFailed,
  Value<int> autoCacheSizeGB,
  Value<String?> downloadDirectory,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

class $$UserSettingsTableFilterComposer
    extends Composer<_$MusicDatabase, $UserSettingsTable> {
  $$UserSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get defaultPlayQuality => $composableBuilder(
      column: $table.defaultPlayQuality,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get defaultDownloadQuality => $composableBuilder(
      column: $table.defaultDownloadQuality,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get autoSelectQuality => $composableBuilder(
      column: $table.autoSelectQuality,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get wifiOnlyDownload => $composableBuilder(
      column: $table.wifiOnlyDownload,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get maxConcurrentDownloads => $composableBuilder(
      column: $table.maxConcurrentDownloads,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get autoRetryFailed => $composableBuilder(
      column: $table.autoRetryFailed,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get autoCacheSizeGB => $composableBuilder(
      column: $table.autoCacheSizeGB,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get downloadDirectory => $composableBuilder(
      column: $table.downloadDirectory,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$UserSettingsTableOrderingComposer
    extends Composer<_$MusicDatabase, $UserSettingsTable> {
  $$UserSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get defaultPlayQuality => $composableBuilder(
      column: $table.defaultPlayQuality,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get defaultDownloadQuality => $composableBuilder(
      column: $table.defaultDownloadQuality,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get autoSelectQuality => $composableBuilder(
      column: $table.autoSelectQuality,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get wifiOnlyDownload => $composableBuilder(
      column: $table.wifiOnlyDownload,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get maxConcurrentDownloads => $composableBuilder(
      column: $table.maxConcurrentDownloads,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get autoRetryFailed => $composableBuilder(
      column: $table.autoRetryFailed,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get autoCacheSizeGB => $composableBuilder(
      column: $table.autoCacheSizeGB,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get downloadDirectory => $composableBuilder(
      column: $table.downloadDirectory,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$UserSettingsTableAnnotationComposer
    extends Composer<_$MusicDatabase, $UserSettingsTable> {
  $$UserSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get defaultPlayQuality => $composableBuilder(
      column: $table.defaultPlayQuality, builder: (column) => column);

  GeneratedColumn<int> get defaultDownloadQuality => $composableBuilder(
      column: $table.defaultDownloadQuality, builder: (column) => column);

  GeneratedColumn<bool> get autoSelectQuality => $composableBuilder(
      column: $table.autoSelectQuality, builder: (column) => column);

  GeneratedColumn<bool> get wifiOnlyDownload => $composableBuilder(
      column: $table.wifiOnlyDownload, builder: (column) => column);

  GeneratedColumn<int> get maxConcurrentDownloads => $composableBuilder(
      column: $table.maxConcurrentDownloads, builder: (column) => column);

  GeneratedColumn<bool> get autoRetryFailed => $composableBuilder(
      column: $table.autoRetryFailed, builder: (column) => column);

  GeneratedColumn<int> get autoCacheSizeGB => $composableBuilder(
      column: $table.autoCacheSizeGB, builder: (column) => column);

  GeneratedColumn<String> get downloadDirectory => $composableBuilder(
      column: $table.downloadDirectory, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UserSettingsTableTableManager extends RootTableManager<
    _$MusicDatabase,
    $UserSettingsTable,
    UserSetting,
    $$UserSettingsTableFilterComposer,
    $$UserSettingsTableOrderingComposer,
    $$UserSettingsTableAnnotationComposer,
    $$UserSettingsTableCreateCompanionBuilder,
    $$UserSettingsTableUpdateCompanionBuilder,
    (
      UserSetting,
      BaseReferences<_$MusicDatabase, $UserSettingsTable, UserSetting>
    ),
    UserSetting,
    PrefetchHooks Function()> {
  $$UserSettingsTableTableManager(_$MusicDatabase db, $UserSettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> defaultPlayQuality = const Value.absent(),
            Value<int> defaultDownloadQuality = const Value.absent(),
            Value<bool> autoSelectQuality = const Value.absent(),
            Value<bool> wifiOnlyDownload = const Value.absent(),
            Value<int> maxConcurrentDownloads = const Value.absent(),
            Value<bool> autoRetryFailed = const Value.absent(),
            Value<int> autoCacheSizeGB = const Value.absent(),
            Value<String?> downloadDirectory = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              UserSettingsCompanion(
            id: id,
            defaultPlayQuality: defaultPlayQuality,
            defaultDownloadQuality: defaultDownloadQuality,
            autoSelectQuality: autoSelectQuality,
            wifiOnlyDownload: wifiOnlyDownload,
            maxConcurrentDownloads: maxConcurrentDownloads,
            autoRetryFailed: autoRetryFailed,
            autoCacheSizeGB: autoCacheSizeGB,
            downloadDirectory: downloadDirectory,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> defaultPlayQuality = const Value.absent(),
            Value<int> defaultDownloadQuality = const Value.absent(),
            Value<bool> autoSelectQuality = const Value.absent(),
            Value<bool> wifiOnlyDownload = const Value.absent(),
            Value<int> maxConcurrentDownloads = const Value.absent(),
            Value<bool> autoRetryFailed = const Value.absent(),
            Value<int> autoCacheSizeGB = const Value.absent(),
            Value<String?> downloadDirectory = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              UserSettingsCompanion.insert(
            id: id,
            defaultPlayQuality: defaultPlayQuality,
            defaultDownloadQuality: defaultDownloadQuality,
            autoSelectQuality: autoSelectQuality,
            wifiOnlyDownload: wifiOnlyDownload,
            maxConcurrentDownloads: maxConcurrentDownloads,
            autoRetryFailed: autoRetryFailed,
            autoCacheSizeGB: autoCacheSizeGB,
            downloadDirectory: downloadDirectory,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$UserSettingsTableProcessedTableManager = ProcessedTableManager<
    _$MusicDatabase,
    $UserSettingsTable,
    UserSetting,
    $$UserSettingsTableFilterComposer,
    $$UserSettingsTableOrderingComposer,
    $$UserSettingsTableAnnotationComposer,
    $$UserSettingsTableCreateCompanionBuilder,
    $$UserSettingsTableUpdateCompanionBuilder,
    (
      UserSetting,
      BaseReferences<_$MusicDatabase, $UserSettingsTable, UserSetting>
    ),
    UserSetting,
    PrefetchHooks Function()>;

class $MusicDatabaseManager {
  final _$MusicDatabase _db;
  $MusicDatabaseManager(this._db);
  $$BilibiliVideosTableTableManager get bilibiliVideos =>
      $$BilibiliVideosTableTableManager(_db, _db.bilibiliVideos);
  $$BilibiliFavoritesTableTableManager get bilibiliFavorites =>
      $$BilibiliFavoritesTableTableManager(_db, _db.bilibiliFavorites);
  $$SongsTableTableManager get songs =>
      $$SongsTableTableManager(_db, _db.songs);
  $$BilibiliAudioCacheTableTableManager get bilibiliAudioCache =>
      $$BilibiliAudioCacheTableTableManager(_db, _db.bilibiliAudioCache);
  $$DownloadTasksTableTableManager get downloadTasks =>
      $$DownloadTasksTableTableManager(_db, _db.downloadTasks);
  $$UserSettingsTableTableManager get userSettings =>
      $$UserSettingsTableTableManager(_db, _db.userSettings);
}
