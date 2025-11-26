import 'package:flutter/foundation.dart';

/// Bilibili 合集相关数据模型

/// 合集基本信息
class BilibiliCollection {
  final int id;              // 合集ID
  final String title;        // 合集标题
  final String cover;        // 合集封面
  final int mid;             // UP主ID
  final String upName;       // UP主名称
  final int mediaCount;      // 视频数量
  final String intro;        // 合集简介
  
  BilibiliCollection({
    required this.id,
    required this.title,
    required this.cover,
    required this.mid,
    required this.upName,
    required this.mediaCount,
    required this.intro,
  });
  
  factory BilibiliCollection.fromJson(Map<String, dynamic> json) {
    return BilibiliCollection(
      id: json['id'] as int? ?? json['season_id'] as int? ?? 0,
      title: json['title'] as String? ?? json['name'] as String? ?? '',
      cover: json['cover'] as String? ?? '',
      mid: json['mid'] as int? ?? 0,
      upName: json['upper']?['name'] as String? ?? '',
      mediaCount: json['media_count'] as int? ?? json['total'] as int? ?? 0,
      intro: json['intro'] as String? ?? json['description'] as String? ?? '',
    );
  }
}

/// 合集视频项
class BilibiliCollectionItem {
  final String bvid;         // 视频BV号
  final int aid;             // 视频AV号
  final int cid;             // 视频CID
  final String title;        // 视频标题
  final String cover;        // 视频封面
  final int duration;        // 视频时长（秒）
  final String upName;       // UP主名称
  final int pubdate;         // 发布时间戳
  final int view;            // 播放量
  final int like;            // 点赞量
  
  BilibiliCollectionItem({
    required this.bvid,
    required this.aid,
    required this.cid,
    required this.title,
    required this.cover,
    required this.duration,
    required this.upName,
    required this.pubdate,
    this.view = 0,
    this.like = 0,
  });
  
  factory BilibiliCollectionItem.fromJson(Map<String, dynamic> json) {
    // 提取统计数据
    final stat = json['stat'] as Map<String, dynamic>?;
    
    return BilibiliCollectionItem(
      bvid: json['bvid'] as String? ?? '',
      aid: json['aid'] as int? ?? 0,
      cid: json['cid'] as int? ?? json['page']?['cid'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      cover: json['pic'] as String? ?? json['cover'] as String? ?? '',
      duration: json['duration'] as int? ?? json['page']?['duration'] as int? ?? 0,
      upName: json['owner']?['name'] as String? ?? json['author'] as String? ?? '',
      pubdate: json['pubtime'] as int? ?? json['pubdate'] as int? ?? 0,
      view: stat?['view'] as int? ?? 0,
      like: stat?['like'] as int? ?? 0,
    );
  }
  
  /// 复制并修改部分字段
  BilibiliCollectionItem copyWith({
    String? bvid,
    int? aid,
    int? cid,
    String? title,
    String? cover,
    int? duration,
    String? upName,
    int? pubdate,
    int? view,
    int? like,
  }) {
    return BilibiliCollectionItem(
      bvid: bvid ?? this.bvid,
      aid: aid ?? this.aid,
      cid: cid ?? this.cid,
      title: title ?? this.title,
      cover: cover ?? this.cover,
      duration: duration ?? this.duration,
      upName: upName ?? this.upName,
      pubdate: pubdate ?? this.pubdate,
      view: view ?? this.view,
      like: like ?? this.like,
    );
  }
}

/// 合集内容（包含合集信息和视频列表）
class BilibiliCollectionContents {
  final BilibiliCollection info;
  final List<BilibiliCollectionItem> items;
  final bool hasMore;
  
  BilibiliCollectionContents({
    required this.info,
    required this.items,
    required this.hasMore,
  });
  
  factory BilibiliCollectionContents.fromJson(Map<String, dynamic> json) {
    // 支持多种API响应格式
    final meta = json['meta'] as Map<String, dynamic>? ?? json;
    final archives = json['archives'] as List<dynamic>? ?? json['list'] as List<dynamic>? ?? [];
    
    return BilibiliCollectionContents(
      info: BilibiliCollection.fromJson(meta),
      items: archives
          .map((item) => BilibiliCollectionItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      hasMore: json['has_more'] as bool? ?? json['has_next'] as bool? ?? false,
    );
  }
}
