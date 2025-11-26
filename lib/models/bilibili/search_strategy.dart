/// Bilibili 搜索策略类型
enum SearchStrategyType {
  /// BV号（视频ID）
  bvid,
  
  /// 收藏夹ID
  favorite,
  
  /// 合集ID
  collection,
  
  /// UP主/作者
  uploader,
  
  /// 关键词搜索
  search,
  
  /// b23.tv短链解析错误
  b23ResolveError,
  
  /// b23.tv短链解析后未找到BV号
  b23NoBvidError,
  
  /// AV号解析错误
  avParseError,
  
  /// 无效URL（缺少ctype参数）
  invalidUrlNoCtype,
}

/// Bilibili 搜索策略模型
/// 
/// 用于表示智能搜索系统识别出的搜索意图和相关参数
class SearchStrategy {
  /// 策略类型
  final SearchStrategyType type;
  
  /// 收藏夹/合集ID
  final String? id;
  
  /// 视频BV号
  final String? bvid;
  
  /// UP主mid
  final String? mid;
  
  /// 搜索关键词
  final String? query;
  
  /// 错误信息
  final String? error;
  
  /// 解析后的URL（用于错误报告）
  final String? resolvedUrl;

  const SearchStrategy({
    required this.type,
    this.id,
    this.bvid,
    this.mid,
    this.query,
    this.error,
    this.resolvedUrl,
  });

  /// 创建BVID策略
  factory SearchStrategy.bvid(String bvid) {
    return SearchStrategy(type: SearchStrategyType.bvid, bvid: bvid);
  }

  /// 创建收藏夹策略
  factory SearchStrategy.favorite(String id) {
    return SearchStrategy(type: SearchStrategyType.favorite, id: id);
  }

  /// 创建合集策略
  factory SearchStrategy.collection(String id, {String? mid}) {
    return SearchStrategy(type: SearchStrategyType.collection, id: id, mid: mid);
  }

  /// 创建UP主策略
  factory SearchStrategy.uploader(String mid) {
    return SearchStrategy(type: SearchStrategyType.uploader, mid: mid);
  }

  /// 创建搜索策略
  factory SearchStrategy.search(String query) {
    return SearchStrategy(type: SearchStrategyType.search, query: query);
  }

  /// 创建b23解析错误策略
  factory SearchStrategy.b23ResolveError(String query, String error) {
    return SearchStrategy(
      type: SearchStrategyType.b23ResolveError,
      query: query,
      error: error,
    );
  }

  /// 创建b23无BV号错误策略
  factory SearchStrategy.b23NoBvidError(String query, String resolvedUrl) {
    return SearchStrategy(
      type: SearchStrategyType.b23NoBvidError,
      query: query,
      resolvedUrl: resolvedUrl,
    );
  }

  /// 创建AV解析错误策略
  factory SearchStrategy.avParseError(String query) {
    return SearchStrategy(
      type: SearchStrategyType.avParseError,
      query: query,
    );
  }

  /// 创建无效URL策略
  factory SearchStrategy.invalidUrlNoCtype() {
    return const SearchStrategy(type: SearchStrategyType.invalidUrlNoCtype);
  }

  @override
  String toString() {
    return 'SearchStrategy(type: $type, id: $id, bvid: $bvid, mid: $mid, query: $query, error: $error)';
  }
}
