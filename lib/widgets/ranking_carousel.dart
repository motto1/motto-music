import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:motto_music/models/bilibili/video.dart';
import 'package:motto_music/services/bilibili/api_service.dart';
import 'package:motto_music/services/bilibili/api_client.dart';
import 'package:motto_music/services/bilibili/cookie_manager.dart';
import 'package:motto_music/animations/page_transitions.dart';
import 'package:motto_music/views/bilibili/music_ranking_page.dart';
import 'package:motto_music/views/bilibili/video_detail_page.dart';
import 'package:http/http.dart' as http;

/// 自定义吸附滚动物理效果
class SnappingScrollPhysics extends ScrollPhysics {
  final double itemExtent;

  const SnappingScrollPhysics({required this.itemExtent, super.parent});

  @override
  SnappingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SnappingScrollPhysics(
      itemExtent: itemExtent,
      parent: buildParent(ancestor),
    );
  }

  double _getTargetPixels(ScrollMetrics position, Tolerance tolerance, double velocity) {
    double page = position.pixels / itemExtent;
    if (velocity < -tolerance.velocity) {
      page -= 0.5;
    } else if (velocity > tolerance.velocity) {
      page += 0.5;
    }
    return (page.roundToDouble() * itemExtent).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final currentTolerance = toleranceFor(position);
    final double target = _getTargetPixels(position, currentTolerance, velocity);
    if (target == position.pixels) {
      return null;
    }
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: currentTolerance,
    );
  }
}

/// Apple Music风格的音乐索引卡片轮播
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
      final videos = await _apiService.getZoneRankList(
        cateId: 3,
        order: 'click',
        page: 1,
        pageSize: 10,
      );
      if (mounted) {
        setState(() {
          _videos = videos;
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

  // 获取边框颜色（比主色深一点，降低20%亮度）
  Color _getBorderColor(String imageUrl) {
    final baseColor = _getGradientColor(imageUrl);
    final hsl = HSLColor.fromColor(baseColor);
    return hsl.withLightness((hsl.lightness * 0.8).clamp(0.0, 1.0)).toColor();
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
                    '音乐分区 · 热门',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    NamidaPageRoute(
                      page: const MusicRankingPage(
                        title: '热门音乐',
                        zoneTid: 3,
                        order: 'click',
                      ),
                      type: PageTransitionType.slideUp,
                    ),
                  );
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
        // 卡片列表 - 使用自定义吸附物理效果
        SizedBox(
          height: _cardHeight,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: _horizontalPadding, right: _horizontalPadding),
            physics: SnappingScrollPhysics(itemExtent: itemExtent),
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
    final gradientColor = _getGradientColor(video.pic);
    final borderColor = _getBorderColor(video.pic);
    const double infoAreaHeight = 85.0;

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
            width: 0.8,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14.5),
          child: Column(
            children: [
              // 封面区域
              Expanded(
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
                    // 底部过渡渐变（极短，只做过渡）
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              gradientColor.withValues(alpha: 0.0),
                              gradientColor,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // 排名数字
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
                  ],
                ),
              ),
              // 纯色信息区域 - 垂直渐变效果
              Container(
                height: infoAreaHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      gradientColor,
                      HSLColor.fromColor(gradientColor)
                          .withLightness((HSLColor.fromColor(gradientColor).lightness * 0.7).clamp(0.0, 1.0))
                          .toColor(),
                    ],
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Text(
                  video.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                  maxLines: 3,
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
