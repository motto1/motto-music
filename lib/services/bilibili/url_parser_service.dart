import 'package:flutter/foundation.dart';
import 'package:motto_music/models/bilibili/search_strategy.dart';
import 'package:motto_music/utils/bilibili_id_converter.dart';
import 'package:motto_music/services/bilibili/api_service.dart';

/// Bilibili URL 解析服务
/// 
/// 提供智能搜索功能，支持：
/// - BV/AV 号识别
/// - URL 解析（收藏夹、合集、UP主等）
/// - b23.tv 短链解析
/// - 关键词搜索
class BilibiliUrlParserService {
  final BilibiliApiService _apiService;

  // BV号正则表达式：匹配 BV + 10位字符
  static final RegExp _bvRegex = RegExp(
    r'(?<![A-Za-z0-9])(BV[0-9A-Za-z]{10})(?![A-Za-z0-9])',
    caseSensitive: false,
  );

  // AV号正则表达式：匹配 av + 数字
  static final RegExp _avRegex = RegExp(
    r'(?<![A-Za-z0-9])av(\d+)(?![A-Za-z0-9])',
    caseSensitive: false,
  );

  // 空间链接正则表达式：匹配 /space/<mid>
  static final RegExp _spaceRegex = RegExp(r'^/space/(\d+)(?:/|$)');

  BilibiliUrlParserService(this._apiService);

  /// 智能匹配搜索策略
  /// 
  /// 根据用户输入的内容，自动识别意图并返回对应的搜索策略
  /// 
  /// 支持的输入：
  /// - BV号: BV1xx4y1x7xx
  /// - AV号: av12345678
  /// - URL: 收藏夹/合集/UP主链接
  /// - b23.tv短链
  /// - 关键词: 任意文本
  Future<SearchStrategy> matchSearchStrategy(String raw) async {
    final query = raw.trim();

    if (query.isEmpty) {
      return SearchStrategy.search('');
    }

    // 1. 优先尝试提取BV号（避免被误判为URL）
    final bvMatch = _bvRegex.firstMatch(query);
    if (bvMatch != null) {
      final bvid = bvMatch.group(1)!; // 保持原始大小写
      // 确保BV前缀正确(保持原始大小写)
      final normalizedBvid = bvid.substring(0, 2).toUpperCase() + bvid.substring(2);
      debugPrint('匹配到 BV 号: $normalizedBvid');
      return SearchStrategy.bvid(normalizedBvid);
    }

    // 2. 尝试提取AV号
    final avMatch = _avRegex.firstMatch(query);
    if (avMatch != null) {
      final avidStr = avMatch.group(1)!;
      final avid = int.tryParse(avidStr);
      
      if (avid != null && BilibiliIdConverter.isValidAvid(avid)) {
        final bvid = BilibiliIdConverter.av2bv(avid); // av2bv 已经返回正确格式
        debugPrint('匹配到 AV 号: av$avid，转换为: $bvid');
        return SearchStrategy.bvid(bvid);
      } else {
        debugPrint('AV 号解析失败: $avidStr');
        return SearchStrategy.avParseError(query);
      }
    }

    // 3. 尝试作为URL解析（包括b23.tv短链）
    if (_looksLikeUrl(query)) {
      try {
        final strategy = await _parseUrl(query);
        if (strategy != null) {
          return strategy;
        }
      } catch (e) {
        debugPrint('URL解析失败: $e，继续尝试其他匹配方式');
      }
    }

    // 4. 默认作为关键词搜索
    debugPrint('默认关键词搜索: $query');
    return SearchStrategy.search(query);
  }
  /// 解析URL并返回对应的搜索策略
  /// 
  /// 支持的URL类型：
  /// - b23.tv 短链
  /// - 收藏夹链接
  /// - 合集链接
  /// - UP主空间链接
  /// - 包含BV/AV号的任意URL
  Future<SearchStrategy?> _parseUrl(String urlString) async {
    try {
      final uri = Uri.parse(_ensureProtocol(_cleanUrl(urlString)));

      // 1. 处理 b23.tv 短链
      if (uri.host.toLowerCase().endsWith('b23.tv')) {
        return await _resolveB23ShortUrl(uri);
      }

      // 2. 处理收藏夹/合集参数 (?ctype=11&fid=xxx)
      final ctype = uri.queryParameters['ctype'];
      final fid = uri.queryParameters['fid'];

      if (fid != null) {
        if (ctype == '21') {
          debugPrint('parseUrl: 主站合集 URL (ctype=21), fid=$fid');
          return SearchStrategy.collection(fid);
        } else if (ctype == '11') {
          debugPrint('parseUrl: 主站收藏夹 URL (ctype=11), fid=$fid');
          return SearchStrategy.favorite(fid);
        } else if (ctype == null) {
          // 缺少ctype参数，默认为收藏夹
          debugPrint('parseUrl: URL 缺少 ctype 参数，默认为收藏夹, fid=$fid');
          return SearchStrategy.favorite(fid);
        }
      }

      // 3. 处理 space.bilibili.com 域名
      if (uri.host == 'space.bilibili.com') {
        return _parseSpaceUrl(uri);
      }

      // 4. 处理 /space/<mid> 路径
      final spaceMatch = _spaceRegex.firstMatch(uri.path);
      if (spaceMatch != null) {
        final mid = spaceMatch.group(1)!;
        debugPrint('parseUrl: 匹配 /space/<mid>, mid=$mid');
        return SearchStrategy.uploader(mid);
      }

      // 5. 尝试从URL中提取BV号
      final bvMatch = _bvRegex.firstMatch(uri.toString());
      if (bvMatch != null) {
        final bvid = bvMatch.group(1)!; // 保持原始大小写
        final normalizedBvid = bvid.substring(0, 2).toUpperCase() + bvid.substring(2);
        debugPrint('parseUrl: URL 中匹配到 BV 号: $normalizedBvid');
        return SearchStrategy.bvid(normalizedBvid);
      }

      // 6. 尝试从URL中提取AV号
      final avMatch = _avRegex.firstMatch(uri.toString());
      if (avMatch != null) {
        final avidStr = avMatch.group(1)!;
        final avid = int.tryParse(avidStr);
        
        if (avid != null && BilibiliIdConverter.isValidAvid(avid)) {
          final bvid = BilibiliIdConverter.av2bv(avid);
          debugPrint('parseUrl: URL 中匹配到 AV 号: av$avid，转换为: $bvid');
          return SearchStrategy.bvid(bvid);
        } else {
          debugPrint('parseUrl: URL 中 AV 号解析失败: $avidStr');
          return SearchStrategy.avParseError(uri.toString());
        }
      }

      // 未识别的URL
      debugPrint('parseUrl: 未识别的 URL 类型: ${uri.toString()}');
      return null;
      
    } catch (e) {
      debugPrint('parseUrl 异常: $e');
      return null;
    }
  }

  /// 解析 space.bilibili.com 域名的URL
  /// 
  /// 支持：
  /// - space.bilibili.com/<mid> -> UP主
  /// - space.bilibili.com/<mid>/lists -> UP主
  /// - space.bilibili.com/<mid>/lists/<collectionId> -> 合集
  SearchStrategy? _parseSpaceUrl(Uri uri) {
    final pathSegments = uri.pathSegments;
    
    if (pathSegments.isEmpty) {
      return null;
    }

    final mid = pathSegments[0];

    // 检查是否包含 lists
    if (pathSegments.contains('lists')) {
      final listsIndex = pathSegments.indexOf('lists');
      
      // 如果 lists 后面有内容，认为是合集ID
      if (listsIndex + 1 < pathSegments.length) {
        final collectionId = pathSegments[listsIndex + 1];
        debugPrint('parseSpaceUrl: 匹配合集, collectionId=$collectionId, mid=$mid');
        return SearchStrategy.collection(collectionId, mid: mid);
      } else {
        // lists 后面没有内容，返回UP主
        debugPrint('parseSpaceUrl: 匹配 UP主（lists无ID）, mid=$mid');
        return SearchStrategy.uploader(mid);
      }
    }

    // 默认返回UP主
    debugPrint('parseSpaceUrl: 匹配 UP主, mid=$mid');
    return SearchStrategy.uploader(mid);
  }
  /// 解析 b23.tv 短链
  /// 
  /// 通过API获取短链的真实URL，然后递归解析
  Future<SearchStrategy> _resolveB23ShortUrl(Uri uri) async {
    try {
      debugPrint('开始解析 b23.tv 短链: ${uri.toString()}');
      
      // 调用API解析短链
      final resolvedUrl = await _apiService.resolveB23Url(uri.toString());
      
      debugPrint('b23.tv 短链解析成功: $resolvedUrl');

      // 尝试作为URL继续解析
      try {
        final resolvedUri = Uri.parse(resolvedUrl);
        final strategy = await _parseUrlToStrategy(resolvedUri);
        
        if (strategy != null) {
          debugPrint('b23.tv 短链解析后识别为: ${strategy.type}');
          return strategy;
        }
      } catch (e) {
        debugPrint('b23.tv 短链解析后URL解析失败: $e');
      }

      // 尝试从解析结果中提取BV号
      final bvMatch = _bvRegex.firstMatch(resolvedUrl);
      if (bvMatch != null) {
        final bvid = bvMatch.group(1)!; // 保持原始大小写
        final normalizedBvid = bvid.substring(0, 2).toUpperCase() + bvid.substring(2);
        debugPrint('b23.tv 短链解析后匹配到 BV 号: $normalizedBvid');
        return SearchStrategy.bvid(normalizedBvid);
      }

      // 无法识别解析结果
      debugPrint('b23.tv 短链解析后未找到可识别内容');
      return SearchStrategy.b23NoBvidError(uri.toString(), resolvedUrl);
      
    } catch (e) {
      debugPrint('b23.tv 短链解析失败: $e');
      return SearchStrategy.b23ResolveError(uri.toString(), e.toString());
    }
  }

  /// 解析URL并返回策略（不处理b23短链）
  /// 
  /// 这是一个内部方法，用于在b23短链解析后继续解析
  Future<SearchStrategy?> _parseUrlToStrategy(Uri uri) async {
    // 处理收藏夹/合集参数
    final ctype = uri.queryParameters['ctype'];
    final fid = uri.queryParameters['fid'];

    if (fid != null) {
      if (ctype == '21') {
        return SearchStrategy.collection(fid);
      } else if (ctype == '11') {
        return SearchStrategy.favorite(fid);
      } else if (ctype == null) {
        return SearchStrategy.favorite(fid);
      }
    }

    // 处理 space.bilibili.com
    if (uri.host == 'space.bilibili.com') {
      return _parseSpaceUrl(uri);
    }

    // 处理 /space/<mid>
    final spaceMatch = _spaceRegex.firstMatch(uri.path);
    if (spaceMatch != null) {
      return SearchStrategy.uploader(spaceMatch.group(1)!);
    }

    // 提取BV号
    final bvMatch = _bvRegex.firstMatch(uri.toString());
    if (bvMatch != null) {
      final bvid = bvMatch.group(1)!; // 保持原始大小写
      return SearchStrategy.bvid(bvid.substring(0, 2).toUpperCase() + bvid.substring(2));
    }

    // 提取AV号
    final avMatch = _avRegex.firstMatch(uri.toString());
    if (avMatch != null) {
      final avid = int.tryParse(avMatch.group(1)!);
      if (avid != null && BilibiliIdConverter.isValidAvid(avid)) {
        return SearchStrategy.bvid(BilibiliIdConverter.av2bv(avid));
      }
    }

    return null;
  }

  /// 清理URL字符串（移除末尾的标点符号）
  String _cleanUrl(String url) {
    return url.replaceAll(RegExp(r'[),.;!?，。！？）]+$'), '');
  }

  /// 确保URL包含协议头
  String _ensureProtocol(String url) {
    if (!url.toLowerCase().startsWith(RegExp(r'https?://'))) {
      return 'https://$url';
    }
    return url;
  }

  /// 判断字符串是否看起来像URL
  bool _looksLikeUrl(String text) {
    // 包含常见域名或协议
    if (text.contains('://') || 
        text.contains('bilibili.com') || 
        text.contains('b23.tv') ||
        text.contains('.com') ||
        text.contains('.tv') ||
        text.contains('.cn')) {
      return true;
    }

    // 尝试解析为URI
    try {
      final uri = Uri.parse(_ensureProtocol(text));
      return uri.hasScheme && uri.hasAuthority;
    } catch (e) {
      return false;
    }
  }
}
