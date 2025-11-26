// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BilibiliVideo _$BilibiliVideoFromJson(Map<String, dynamic> json) =>
    BilibiliVideo(
      aid: (json['aid'] as num).toInt(),
      bvid: json['bvid'] as String,
      title: json['title'] as String,
      pic: json['pic'] as String,
      duration: (json['duration'] as num).toInt(),
      desc: json['desc'] as String?,
      owner: BilibiliUploader.fromJson(json['owner'] as Map<String, dynamic>),
      cid: (json['cid'] as num).toInt(),
      pubdate: (json['pubdate'] as num).toInt(),
      pages: (json['pages'] as List<dynamic>?)
          ?.map((e) => BilibiliVideoPage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$BilibiliVideoToJson(BilibiliVideo instance) =>
    <String, dynamic>{
      'aid': instance.aid,
      'bvid': instance.bvid,
      'title': instance.title,
      'pic': instance.pic,
      'duration': instance.duration,
      'desc': instance.desc,
      'owner': instance.owner,
      'cid': instance.cid,
      'pubdate': instance.pubdate,
      'pages': instance.pages,
    };

BilibiliUploader _$BilibiliUploaderFromJson(Map<String, dynamic> json) =>
    BilibiliUploader(
      mid: (json['mid'] as num).toInt(),
      name: json['name'] as String,
      face: json['face'] as String?,
    );

Map<String, dynamic> _$BilibiliUploaderToJson(BilibiliUploader instance) =>
    <String, dynamic>{
      'mid': instance.mid,
      'name': instance.name,
      'face': instance.face,
    };

BilibiliVideoPage _$BilibiliVideoPageFromJson(Map<String, dynamic> json) =>
    BilibiliVideoPage(
      cid: (json['cid'] as num).toInt(),
      page: (json['page'] as num).toInt(),
      part: json['part'] as String,
      duration: (json['duration'] as num).toInt(),
    );

Map<String, dynamic> _$BilibiliVideoPageToJson(BilibiliVideoPage instance) =>
    <String, dynamic>{
      'cid': instance.cid,
      'page': instance.page,
      'part': instance.part,
      'duration': instance.duration,
    };
