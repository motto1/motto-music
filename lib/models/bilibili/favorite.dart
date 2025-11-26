import 'package:json_annotation/json_annotation.dart';

part 'favorite.g.dart';

/// Bilibili 收藏夹信息
@JsonSerializable()
class BilibiliFavorite {
  /// 收藏夹 ID
  final int id;
  
  /// 收藏夹标题
  final String title;
  
  /// 收藏夹封面
  final String? cover;
  
  /// 收藏夹简介
  final String? intro;
  
  /// 媒体数量
  @JsonKey(name: 'media_count')
  final int mediaCount;
  
  /// 当前视频是否在此收藏夹中（仅在查询特定视频时有效）
  @JsonKey(name: 'fav_state', defaultValue: 0)
  final int favState;
  
  BilibiliFavorite({
    required this.id,
    required this.title,
    this.cover,
    this.intro,
    required this.mediaCount,
    this.favState = 0,
  });
  
  factory BilibiliFavorite.fromJson(Map<String, dynamic> json) => _$BilibiliFavoriteFromJson(json);
  
  Map<String, dynamic> toJson() => _$BilibiliFavoriteToJson(this);
  
  /// 目标视频是否在此收藏夹中
  bool get isFavorited => favState == 1;
  
  @override
  String toString() => 'BilibiliFavorite(id: $id, title: $title, count: $mediaCount)';
}

/// 收藏夹内容项
@JsonSerializable()
class BilibiliFavoriteItem {
  /// 视频 ID
  final int id;
  
  /// BV 号
  final String bvid;
  
  /// CID（视频分P编号，可选）
  final int? cid;
  
  /// 视频标题
  final String title;
  
  /// 封面图
  final String cover;
  
  /// 视频简介
  final String? intro;
  
  /// 视频时长（秒，可能为 null）
  final int? duration;
  
  /// UP主信息
  final BilibiliFavoriteUploader? upper;
  
  /// 发布时间（Unix 时间戳，可能为 null）
  final int? pubdate;
  
  /// 发布时间别名（兼容性字段）
  @JsonKey(name: 'pubtime')
  final int? pubtime;
  
  /// 分P数量（可能为 null）
  final int? page;
  
  /// 类型：2=视频稿件, 12=音频, 21=视频合集（可能为 null）
  final int? type;
  
  /// 失效状态：0=正常, 9=UP主删除, 1=其他原因删除（可能为 null）
  final int? attr;
  
  /// 统计信息（播放数、点赞数等）
  @JsonKey(name: 'cnt_info')
  final BilibiliVideoCountInfo? cnt_info;
  
  BilibiliFavoriteItem({
    required this.id,
    required this.bvid,
    this.cid,
    required this.title,
    required this.cover,
    this.intro,
    this.duration,
    this.upper,
    this.pubdate,
    this.pubtime,
    this.page,
    this.type,
    this.attr,
    this.cnt_info,
  });
  
  factory BilibiliFavoriteItem.fromJson(Map<String, dynamic> json) => _$BilibiliFavoriteItemFromJson(json);
  
  Map<String, dynamic> toJson() => _$BilibiliFavoriteItemToJson(this);
  
  /// 是否已失效
  bool get isInvalid => (attr ?? 0) != 0;
  
  /// 是否为视频稿件
  bool get isVideo => (type ?? 2) == 2;
  
  @override
  String toString() => 'BilibiliFavoriteItem(bvid: $bvid, title: $title)';
}

/// 收藏夹内容中的 UP主信息
@JsonSerializable()
class BilibiliFavoriteUploader {
  final int mid;
  final String name;
  final String? face;
  
  BilibiliFavoriteUploader({
    required this.mid,
    required this.name,
    this.face,
  });
  
  factory BilibiliFavoriteUploader.fromJson(Map<String, dynamic> json) => _$BilibiliFavoriteUploaderFromJson(json);
  
  Map<String, dynamic> toJson() => _$BilibiliFavoriteUploaderToJson(this);
}

/// 视频统计信息
@JsonSerializable()
class BilibiliVideoCountInfo {
  /// 播放数
  final int? play;
  
  /// 点赞数
  final int? like;
  
  /// 弹幕数
  final int? danmaku;
  
  /// 收藏数
  final int? collect;
  
  /// 投币数
  final int? coin;
  
  /// 分享数
  final int? share;
  
  /// 评论数
  final int? reply;
  
  BilibiliVideoCountInfo({
    this.play,
    this.like,
    this.danmaku,
    this.collect,
    this.coin,
    this.share,
    this.reply,
  });
  
  factory BilibiliVideoCountInfo.fromJson(Map<String, dynamic> json) => _$BilibiliVideoCountInfoFromJson(json);
  
  Map<String, dynamic> toJson() => _$BilibiliVideoCountInfoToJson(this);
}

/// 收藏夹详细信息（包含封面等完整信息）
@JsonSerializable()
class BilibiliFavoriteInfo {
  /// 收藏夹 ID
  final int id;
  
  /// 收藏夹标题
  final String title;
  
  /// 收藏夹封面
  final String cover;
  
  /// 收藏夹简介
  final String intro;
  
  /// 媒体数量
  @JsonKey(name: 'media_count')
  final int mediaCount;
  
  /// UP主信息
  final BilibiliFavoriteUploader upper;
  
  BilibiliFavoriteInfo({
    required this.id,
    required this.title,
    required this.cover,
    required this.intro,
    required this.mediaCount,
    required this.upper,
  });
  
  factory BilibiliFavoriteInfo.fromJson(Map<String, dynamic> json) => _$BilibiliFavoriteInfoFromJson(json);
  
  Map<String, dynamic> toJson() => _$BilibiliFavoriteInfoToJson(this);
}

/// 收藏夹内容响应（包含info和medias）
@JsonSerializable()
class BilibiliFavoriteContents {
  /// 收藏夹详细信息
  final BilibiliFavoriteInfo info;
  
  /// 收藏夹内容列表
  final List<BilibiliFavoriteItem>? medias;
  
  /// 是否还有更多
  @JsonKey(name: 'has_more')
  final bool hasMore;
  
  BilibiliFavoriteContents({
    required this.info,
    this.medias,
    required this.hasMore,
  });
  
  factory BilibiliFavoriteContents.fromJson(Map<String, dynamic> json) => _$BilibiliFavoriteContentsFromJson(json);
  
  Map<String, dynamic> toJson() => _$BilibiliFavoriteContentsToJson(this);
}
