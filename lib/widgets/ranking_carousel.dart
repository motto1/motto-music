import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:motto_music/models/bilibili/video.dart';
import 'package:motto_music/services/bilibili/api_service.dart';
import 'package:motto_music/services/bilibili/api_client.dart';
import 'package:motto_music/services/bilibili/cookie_manager.dart';
import 'package:motto_music/animations/page_transitions.dart';
import 'package:motto_music/views/bilibili/video_detail_page.dart';
import 'package:http/http.dart' as http;

/// Apple Music风格的排行榜卡片轮播
class RankingCarousel extends StatefulWidget {
  const RankingCarousel({super.key});

  @override
  State<RankingCarousel> createState() => _RankingCarouselState();
}

class _RankingCarouselState extends State<RankingCarousel> {
  late final BilibiliApiService _apiService;
  late ScrollController _scrollController;
  List<BilibiliVideo> _videos = [];
  bool _isLoading = true;

  // 缓存提取的颜色
  final Map<String, Color> _colorCache = {};

  // 卡片尺寸
  static const double _cardHeight = 320.0;
  static const double _horizontalPadding = 20.0;
  static const double _cardSpacing = 12.0;

  double _cardWidth = 0;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cardWidth = _getCardWidth(context);
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
        // 预加载颜色
        for (final video in _videos) {
          _extractDominantColor(video.pic);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 计算卡片宽度：屏幕可显示1又1/3个卡片
  double _getCardWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - _horizontalPadding;
    return (availableWidth / 1.35) - _cardSpacing;
  }

  // 从图片URL提取主色调
  Future<void> _extractDominantColor(String imageUrl) async {
    if (_colorCache.containsKey(imageUrl)) return;

    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final codec = await ui.instantiateImageCodec(response.bodyBytes);
        final frame = await codec.getNextFrame();
        final image = frame.image;

        // 取图片底部中间区域的像素来获取颜色
        final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (byteData != null) {
          final width = image.width;
          final height = image.height;

          // 采样底部区域
          int r = 0, g = 0, b = 0;
          int sampleCount = 0;

          for (int y = (height * 0.8).toInt(); y < height; y += 2) {
            for (int x = (width * 0.3).toInt(); x < (width * 0.7).toInt(); x += 2) {
              final offset = (y * width + x) * 4;
              if (offset + 2 < byteData.lengthInBytes) {
                r += byteData.getUint8(offset);
                g += byteData.getUint8(offset + 1);
                b += byteData.getUint8(offset + 2);
                sampleCount++;
              }
            }
          }

          if (sampleCount > 0) {
            final color = Color.fromRGBO(
              (r / sampleCount).round(),
              (g / sampleCount).round(),
              (b / sampleCount).round(),
              1.0,
            );

            if (mounted) {
              setState(() {
                _colorCache[imageUrl] = color;
              });
            }
          }
        }
        image.dispose();
      }
    } catch (e) {
      // 提取失败时使用默认黑色
    }
  }

  // 获取缓存的颜色或默认黑色
  Color _getGradientColor(String imageUrl) {
    return _colorCache[imageUrl] ?? Colors.black;
  }

  // 获取边框颜色（比主色深一点）
  Color _getBorderColor(String imageUrl) {
    final baseColor = _getGradientColor(imageUrl);
    // 将颜色变暗
    final hsl = HSLColor.fromColor(baseColor);
    return hsl.withLightness((hsl.lightness * 0.6).clamp(0.0, 1.0)).toColor();
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
    final itemExtent = cardWidth + _cardSpacing;

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
        // 卡片列表 - 使用ListView + 自定义吸附
        SizedBox(
          height: _cardHeight,
          child: NotificationListener<ScrollEndNotification>(
            onNotification: (notification) {
              _snapToCard(itemExtent);
              return true;
            },
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: _horizontalPadding, right: _horizontalPadding),
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
        ),
      ],
    );
  }

  // 吸附到最近的卡片
  void _snapToCard(double itemExtent) {
    final offset = _scrollController.offset;
    final index = (offset / itemExtent).round();
    final targetOffset = (index * itemExtent).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Widget _buildCard(BilibiliVideo video, int index, double cardWidth) {
    final gradientColor = _getGradientColor(video.pic);
    final borderColor = _getBorderColor(video.pic);

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
          border: Border.all(
            color: borderColor.withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColor.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14.5),
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
              // 底部渐变遮罩 - 使用封面颜色
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 110,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        gradientColor.withValues(alpha: 0.85),
                        gradientColor,
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                ),
              ),
              // 排名数字 - 更小的字号
              Positioned(
                top: 10,
                left: 12,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 6,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),
              // 标题
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Text(
                  video.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
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
