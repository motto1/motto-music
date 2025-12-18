import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:motto_music/models/bilibili/video.dart';
import 'package:motto_music/services/bilibili/api_service.dart';
import 'package:motto_music/services/bilibili/api_client.dart';
import 'package:motto_music/services/bilibili/cookie_manager.dart';
import 'package:motto_music/animations/page_transitions.dart';
import 'package:motto_music/views/bilibili/video_detail_page.dart';

/// Apple Music风格的排行榜卡片轮播
class RankingCarousel extends StatefulWidget {
  const RankingCarousel({super.key});

  @override
  State<RankingCarousel> createState() => _RankingCarouselState();
}

class _RankingCarouselState extends State<RankingCarousel> {
  late final BilibiliApiService _apiService;
  late final ScrollController _scrollController;
  List<BilibiliVideo> _videos = [];
  bool _isLoading = true;

  // 卡片尺寸
  static const double _cardHeight = 320.0;
  static const double _horizontalPadding = 20.0;
  static const double _cardSpacing = 12.0;

  @override
  void initState() {
    super.initState();
    final cookieManager = CookieManager();
    final apiClient = BilibiliApiClient(cookieManager);
    _apiService = BilibiliApiService(apiClient);
    _scrollController = ScrollController();

    _loadRanking();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadRanking() async {
    try {
      final videos = await _apiService.getMusicRanking();
      if (mounted) {
        setState(() {
          _videos = videos.take(10).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 计算卡片宽度：屏幕宽度 - 左右padding - 1/3卡片的空间
  double _getCardWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // 屏幕可显示1又1/3个卡片
    // 可用宽度 = 屏幕宽度 - 左padding
    // 卡片宽度 = 可用宽度 / 1.33 - spacing
    final availableWidth = screenWidth - _horizontalPadding;
    return (availableWidth / 1.35) - _cardSpacing;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        height: _cardHeight + 60,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_videos.isEmpty) {
      return const SizedBox.shrink();
    }

    final cardWidth = _getCardWidth(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题区域
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '热门音乐',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'B站音乐排行榜',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  // 导航到排行榜页面
                },
                child: Text(
                  '查看全部',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 卡片列表 - 使用ListView实现平移滑动
        SizedBox(
          height: _cardHeight,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: _horizontalPadding),
            physics: const BouncingScrollPhysics(),
            itemCount: _videos.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(right: _cardSpacing),
                child: _buildCard(_videos[index], index, cardWidth),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCard(BilibiliVideo video, int index, double cardWidth) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          NamidaPageRoute(
            page: VideoDetailPage(bvid: video.bvid),
            type: PageTransitionType.slideUp,
          ),
        );
      },
      child: Container(
        width: cardWidth,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 封面图
              CachedNetworkImage(
                imageUrl: video.pic,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[800],
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[800],
                  child: const Icon(Icons.music_note, color: Colors.white54, size: 48),
                ),
              ),
              // 底部纯色渐变遮罩
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 100,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.9),
                      ],
                    ),
                  ),
                ),
              ),
              // 排名数字 - 只显示数字，无容器
              Positioned(
                top: 12,
                left: 14,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 8,
                        offset: const Offset(1, 2),
                      ),
                    ],
                  ),
                ),
              ),
              // 标题 - 不显示作者
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Text(
                  video.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
