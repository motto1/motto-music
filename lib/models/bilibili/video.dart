import 'package:json_annotation/json_annotation.dart';

part 'video.g.dart';

/// Bilibili 视频信息
@JsonSerializable()
class BilibiliVideo {
  /// AV 号
  final int aid;

  /// BV 号
  final String bvid;

  /// 视频标题
  final String title;

  /// 封面图 URL
  final String pic;

  /// 视频时长（秒）
  final int duration;

  /// 视频简介
  final String? desc;

  /// UP主信息
  final BilibiliUploader owner;

  /// 第一个分P的 CID
  final int cid;

  /// 发布时间（Unix 时间戳）
  final int pubdate;

  /// 分P列表
  final List<BilibiliVideoPage>? pages;

  /// 播放量
  final int? view;

  /// 弹幕数
  final int? danmaku;

  /// 评论数
  final int? reply;

  /// 收藏数
  final int? favorite;

  /// 投币数
  final int? coin;

  /// 分享数
  final int? share;

  /// 点赞数
  final int? like;

  BilibiliVideo({
    required this.aid,
    required this.bvid,
    required this.title,
    required this.pic,
    required this.duration,
    this.desc,
    required this.owner,
    required this.cid,
    required this.pubdate,
    this.pages,
    this.view,
    this.danmaku,
    this.reply,
    this.favorite,
    this.coin,
    this.share,
    this.like,
  });
  
  factory BilibiliVideo.fromJson(Map<String, dynamic> json) => _$BilibiliVideoFromJson(json);
  
  Map<String, dynamic> toJson() => _$BilibiliVideoToJson(this);
  
  /// 是否为多P视频
  bool get isMultiPage => pages != null && pages!.length > 1;
  
  @override
  String toString() => 'BilibiliVideo(bvid: $bvid, title: $title)';
}

/// UP主信息
@JsonSerializable()
class BilibiliUploader {
  /// UP主 UID
  final int mid;
  
  /// UP主昵称
  final String name;
  
  /// UP主头像
  final String? face;
  
  BilibiliUploader({
    required this.mid,
    required this.name,
    this.face,
  });
  
  factory BilibiliUploader.fromJson(Map<String, dynamic> json) => _$BilibiliUploaderFromJson(json);
  
  Map<String, dynamic> toJson() => _$BilibiliUploaderToJson(this);
}

/// 视频分P信息
@JsonSerializable()
class BilibiliVideoPage {
  /// 分P的 CID
  final int cid;
  
  /// 分P序号（从1开始）
  final int page;
  
  /// 分P标题
  final String part;
  
  /// 分P时长（秒）
  final int duration;
  
  BilibiliVideoPage({
    required this.cid,
    required this.page,
    required this.part,
    required this.duration,
  });
  
  factory BilibiliVideoPage.fromJson(Map<String, dynamic> json) => _$BilibiliVideoPageFromJson(json);
  
  Map<String, dynamic> toJson() => _$BilibiliVideoPageToJson(this);
}
