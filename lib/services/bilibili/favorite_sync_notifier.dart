import 'package:flutter/foundation.dart';

/// 全局收藏夹变更通知器
///
/// 用于在不同页面之间广播“某个收藏夹的内容发生了变化”，
/// 例如播放器里向收藏夹添加/移除歌曲后，让收藏夹详情页自动刷新。
class FavoriteSyncNotifier extends ChangeNotifier {
  FavoriteSyncNotifier._internal();

  static final FavoriteSyncNotifier instance =
      FavoriteSyncNotifier._internal();

  int? _lastChangedRemoteFavoriteId;

  int? get lastChangedRemoteFavoriteId => _lastChangedRemoteFavoriteId;

  /// 标记某个远端收藏夹（remoteId）内容发生变更
  void notifyFavoriteChanged(int remoteFavoriteId) {
    _lastChangedRemoteFavoriteId = remoteFavoriteId;
    notifyListeners();
  }
}

