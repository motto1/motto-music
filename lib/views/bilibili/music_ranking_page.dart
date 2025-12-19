import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:motto_music/models/bilibili/video.dart';
import 'package:motto_music/services/bilibili/api_service.dart';
import 'package:motto_music/services/bilibili/api_client.dart';
import 'package:motto_music/services/bilibili/cookie_manager.dart';
import 'package:motto_music/utils/theme_utils.dart';
import 'package:motto_music/animations/page_transitions.dart';
import 'package:motto_music/views/bilibili/video_detail_page.dart';

/// B站音乐排行榜页面 - Apple Music风格
class MusicRankingPage extends StatefulWidget {
  const MusicRankingPage({super.key});

  @override
  State<MusicRankingPage> createState() => _MusicRankingPageState();
}

class _MusicRankingPageState extends State<MusicRankingPage> {
  late final BilibiliApiService _apiService;
  List<BilibiliVideo> _videos = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedCategoryIndex = 0;

  // 分类标签
  final List<String> _categories = [
    '全部音乐',
    '原创音乐',
    '翻唱',
    'VOCALOID',
    '演奏',
  ];

  @override
  void initState() {
    super.initState();
    final cookieManager = CookieManager();
    final apiClient = BilibiliApiClient(cookieManager);
    _apiService = BilibiliApiService(apiClient);
    _loadRanking();
  }

  Future<void> _loadRanking() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final videos = await _apiService.getMusicRanking();
      if (mounted) {
        setState(() {
          _videos = videos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '加载失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = ThemeUtils.backgroundColor(context);
    final textColor = ThemeUtils.textColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部标题区域
            _buildHeader(textColor),
            // 分类标签栏
            _buildCategoryTabs(isDark),
            // 排行榜列表
            Expanded(
              child: _buildContent(textColor, isDark),
            ),
          ],
        ),
      ),
    );
  }

  /// 顶部标题区域
  Widget _buildHeader(Color textColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
      child: Row(
        children: [
          // 返回按钮
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_rounded,
              color: textColor,
              size: 20,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          // 标题和副标题
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '排行榜',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '每天更新',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // 刷新按钮
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: textColor,
              size: 22,
            ),
            onPressed: _loadRanking,
          ),
        ],
      ),
    );
  }

  /// 分类标签栏
  Widget _buildCategoryTabs(bool isDark) {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(top: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final isSelected = index == _selectedCategoryIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategoryIndex = index;
                });
                // 可以在这里根据分类加载不同数据
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFE91E63)
                      : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.15)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    _categories[index],
                    style: TextStyle(
                      color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 内容区域
  Widget _buildContent(Color textColor, bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRanking,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 16, bottom: 100),
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        return _buildRankingItem(_videos[index], index + 1, textColor, isDark);
      },
    );
  }

  /// 排行榜列表项
  Widget _buildRankingItem(BilibiliVideo video, int rank, Color textColor, bool isDark) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          NamidaPageRoute(
            page: VideoDetailPage(bvid: video.bvid),
            type: PageTransitionType.slideUp,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // 排名数字
            SizedBox(
              width: 32,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _getRankColor(rank),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 封面图片
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7.5),
                child: CachedNetworkImage(
                  imageUrl: video.pic,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    child: const Icon(Icons.music_note, color: Colors.grey, size: 24),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    child: const Icon(Icons.broken_image, color: Colors.grey, size: 24),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 歌曲信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    video.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    video.owner.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            // 更多按钮
            IconButton(
              icon: Icon(
                Icons.more_horiz,
                color: Colors.grey,
                size: 20,
              ),
              onPressed: () {
                _showMoreOptions(video);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 获取排名颜色
  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFE91E63); // 粉红色
      case 2:
        return const Color(0xFFE91E63);
      case 3:
        return const Color(0xFFE91E63);
      default:
        return Colors.grey;
    }
  }

  /// 显示更多选项
  void _showMoreOptions(BilibiliVideo video) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeUtils.backgroundColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.play_arrow_rounded),
                title: const Text('播放'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    NamidaPageRoute(
                      page: VideoDetailPage(bvid: video.bvid),
                      type: PageTransitionType.slideUp,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.favorite_border_rounded),
                title: const Text('添加到收藏'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: 实现收藏功能
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('分享'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: 实现分享功能
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
