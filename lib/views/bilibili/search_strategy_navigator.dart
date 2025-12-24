import 'package:flutter/material.dart';
import 'package:motto_music/animations/page_transitions.dart';
import 'package:motto_music/models/bilibili/search_strategy.dart';
import 'package:motto_music/views/bilibili/collection_detail_page.dart';
import 'package:motto_music/views/bilibili/favorite_detail_page.dart';
import 'package:motto_music/views/bilibili/user_videos_page.dart';
import 'package:motto_music/views/bilibili/video_detail_page.dart';

typedef SearchMessageHandler = void Function(String message);

Future<void> navigateBySearchStrategy(
  BuildContext context,
  SearchStrategy strategy, {
  required SearchMessageHandler showMessage,
}) async {
  switch (strategy.type) {
    case SearchStrategyType.bvid:
      if (strategy.bvid == null) return;
      await Navigator.of(context).push(
        NamidaPageRoute(
          page: VideoDetailPage(
            bvid: strategy.bvid!,
            title: '视频详情',
          ),
          type: PageTransitionType.slideLeft,
        ),
      );
      return;

    case SearchStrategyType.favorite:
      final favoriteId =
          strategy.id != null ? int.tryParse(strategy.id!) : null;
      if (favoriteId == null) {
        showMessage('收藏夹ID格式错误');
        return;
      }
      await Navigator.of(context).push(
        NamidaPageRoute(
          page: FavoriteDetailPage(
            favoriteId: favoriteId,
            title: '收藏夹',
          ),
          type: PageTransitionType.slideLeft,
        ),
      );
      return;

    case SearchStrategyType.collection:
      final collectionId =
          strategy.id != null ? int.tryParse(strategy.id!) : null;
      final mid = strategy.mid != null ? int.tryParse(strategy.mid!) : null;
      if (collectionId == null) {
        showMessage('合集ID格式错误');
        return;
      }
      await Navigator.of(context).push(
        NamidaPageRoute(
          page: CollectionDetailPage(
            collectionId: collectionId,
            mid: mid,
            title: '合集',
          ),
          type: PageTransitionType.slideLeft,
        ),
      );
      return;

    case SearchStrategyType.uploader:
      final mid = strategy.mid != null ? int.tryParse(strategy.mid!) : null;
      if (mid == null) {
        showMessage('UP主ID格式错误');
        return;
      }
      await Navigator.of(context).push(
        NamidaPageRoute(
          page: UserVideosPage(
            mid: mid,
            userName: 'UP主',
          ),
          type: PageTransitionType.slideLeft,
        ),
      );
      return;

    case SearchStrategyType.search:
      // 关键词搜索的结果展示由调用方（搜索页）自行处理，这里保持无副作用。
      return;

    case SearchStrategyType.b23ResolveError:
      showMessage('b23.tv短链解析失败: ${strategy.error}');
      return;

    case SearchStrategyType.b23NoBvidError:
      showMessage('短链解析成功，但未找到可识别内容\n解析结果: ${strategy.resolvedUrl}');
      return;

    case SearchStrategyType.avParseError:
      showMessage('AV号解析失败');
      return;

    case SearchStrategyType.invalidUrlNoCtype:
      showMessage('链接缺少必要参数，请检查是否复制完整');
      return;
  }
}
