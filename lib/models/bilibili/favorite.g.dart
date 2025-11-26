// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorite.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BilibiliFavorite _$BilibiliFavoriteFromJson(Map<String, dynamic> json) =>
    BilibiliFavorite(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
      cover: json['cover'] as String?,
      intro: json['intro'] as String?,
      mediaCount: (json['media_count'] as num).toInt(),
      favState: (json['fav_state'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$BilibiliFavoriteToJson(BilibiliFavorite instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'cover': instance.cover,
      'intro': instance.intro,
      'media_count': instance.mediaCount,
      'fav_state': instance.favState,
    };

BilibiliFavoriteItem _$BilibiliFavoriteItemFromJson(
        Map<String, dynamic> json) =>
    BilibiliFavoriteItem(
      id: (json['id'] as num).toInt(),
      bvid: json['bvid'] as String,
      cid: (json['cid'] as num?)?.toInt(),
      title: json['title'] as String,
      cover: json['cover'] as String,
      intro: json['intro'] as String?,
      duration: (json['duration'] as num?)?.toInt(),
      upper: json['upper'] == null
          ? null
          : BilibiliFavoriteUploader.fromJson(
              json['upper'] as Map<String, dynamic>),
      pubdate: (json['pubdate'] as num?)?.toInt(),
      pubtime: (json['pubtime'] as num?)?.toInt(),
      page: (json['page'] as num?)?.toInt(),
      type: (json['type'] as num?)?.toInt(),
      attr: (json['attr'] as num?)?.toInt(),
      cnt_info: json['cnt_info'] == null
          ? null
          : BilibiliVideoCountInfo.fromJson(
              json['cnt_info'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$BilibiliFavoriteItemToJson(
        BilibiliFavoriteItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'bvid': instance.bvid,
      'cid': instance.cid,
      'title': instance.title,
      'cover': instance.cover,
      'intro': instance.intro,
      'duration': instance.duration,
      'upper': instance.upper,
      'pubdate': instance.pubdate,
      'pubtime': instance.pubtime,
      'page': instance.page,
      'type': instance.type,
      'attr': instance.attr,
      'cnt_info': instance.cnt_info,
    };

BilibiliFavoriteUploader _$BilibiliFavoriteUploaderFromJson(
        Map<String, dynamic> json) =>
    BilibiliFavoriteUploader(
      mid: (json['mid'] as num).toInt(),
      name: json['name'] as String,
      face: json['face'] as String?,
    );

Map<String, dynamic> _$BilibiliFavoriteUploaderToJson(
        BilibiliFavoriteUploader instance) =>
    <String, dynamic>{
      'mid': instance.mid,
      'name': instance.name,
      'face': instance.face,
    };

BilibiliVideoCountInfo _$BilibiliVideoCountInfoFromJson(
        Map<String, dynamic> json) =>
    BilibiliVideoCountInfo(
      play: (json['play'] as num?)?.toInt(),
      like: (json['like'] as num?)?.toInt(),
      danmaku: (json['danmaku'] as num?)?.toInt(),
      collect: (json['collect'] as num?)?.toInt(),
      coin: (json['coin'] as num?)?.toInt(),
      share: (json['share'] as num?)?.toInt(),
      reply: (json['reply'] as num?)?.toInt(),
    );

Map<String, dynamic> _$BilibiliVideoCountInfoToJson(
        BilibiliVideoCountInfo instance) =>
    <String, dynamic>{
      'play': instance.play,
      'like': instance.like,
      'danmaku': instance.danmaku,
      'collect': instance.collect,
      'coin': instance.coin,
      'share': instance.share,
      'reply': instance.reply,
    };

BilibiliFavoriteInfo _$BilibiliFavoriteInfoFromJson(
        Map<String, dynamic> json) =>
    BilibiliFavoriteInfo(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
      cover: json['cover'] as String,
      intro: json['intro'] as String,
      mediaCount: (json['media_count'] as num).toInt(),
      upper: BilibiliFavoriteUploader.fromJson(
          json['upper'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$BilibiliFavoriteInfoToJson(
        BilibiliFavoriteInfo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'cover': instance.cover,
      'intro': instance.intro,
      'media_count': instance.mediaCount,
      'upper': instance.upper,
    };

BilibiliFavoriteContents _$BilibiliFavoriteContentsFromJson(
        Map<String, dynamic> json) =>
    BilibiliFavoriteContents(
      info: BilibiliFavoriteInfo.fromJson(json['info'] as Map<String, dynamic>),
      medias: (json['medias'] as List<dynamic>?)
          ?.map((e) => BilibiliFavoriteItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasMore: json['has_more'] as bool,
    );

Map<String, dynamic> _$BilibiliFavoriteContentsToJson(
        BilibiliFavoriteContents instance) =>
    <String, dynamic>{
      'info': instance.info,
      'medias': instance.medias,
      'has_more': instance.hasMore,
    };
