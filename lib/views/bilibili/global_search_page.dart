import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:motto_music/models/bilibili/search_strategy.dart';
import 'package:motto_music/services/bilibili/api_service.dart';
import 'package:motto_music/services/bilibili/api_client.dart';
import 'package:motto_music/services/bilibili/cookie_manager.dart';
import 'package:motto_music/services/bilibili/url_parser_service.dart';
import 'package:motto_music/views/bilibili/global_search_result_page.dart';
import 'package:motto_music/views/bilibili/video_detail_page.dart';
import 'package:motto_music/views/bilibili/favorite_detail_page.dart';
import 'package:motto_music/views/bilibili/collection_detail_page.dart';
import 'package:motto_music/views/bilibili/user_videos_page.dart';
import 'package:motto_music/utils/theme_utils.dart';
import 'package:motto_music/widgets/show_aware_page.dart';
import 'package:motto_music/animations/page_transitions.dart';
import 'package:motto_music/widgets/apple_music_card.dart';

/// 全局智能搜索页面
/// 
/// 支持多种输入格式：
/// - BV号: BV1xx4y1x7xx
/// - AV号: av12345678
/// - b23.tv短链: https://b23.tv/xxxxx
/// - 完整URL: 收藏夹/合集/UP主链接
/// - 关键词: 任意搜索词
class GlobalSearchPage extends StatefulWidget {
  final String? initialQuery;
  
  const GlobalSearchPage({super.key, this.initialQuery});

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> with ShowAwarePage {
  late final TextEditingController _searchController;
  late final BilibiliUrlParserService _urlParser;
  late final BilibiliApiService _apiService;
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    
    _searchController = TextEditingController(text: widget.initialQuery);
    
    // 初始化服务
    final cookieManager = CookieManager();
    final apiClient = BilibiliApiClient(cookieManager);
    _apiService = BilibiliApiService(apiClient);
    _urlParser = BilibiliUrlParserService(_apiService);
  }

  @override
  void onPageShow() {
    // 如果有初始查询，自动执行搜索
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _handleSearch();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 处理搜索
  Future<void> _handleSearch() async {
    final query = _searchController.text.trim();
    
    if (query.isEmpty) {
      setState(() {
        _errorMessage = '请输入搜索内容';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 匹配搜索策略
      final strategy = await _urlParser.matchSearchStrategy(query);
      
      if (mounted) {
        setState(() => _isLoading = false);
        
        // 根据策略导航
        await _navigateWithStrategy(strategy);
      }
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '搜索失败: $e';
        });
      }
    }
  }

  /// 根据搜索策略导航到对应页面
  Future<void> _navigateWithStrategy(SearchStrategy strategy) async {
    debugPrint('导航策略: ${strategy.type}, bvid=${strategy.bvid}, id=${strategy.id}, mid=${strategy.mid}');
    
    if (!mounted) {
      debugPrint('组件已卸载，取消导航');
      return;
    }

    switch (strategy.type) {
      case SearchStrategyType.bvid:
        // 跳转到视频详情页
        if (strategy.bvid != null) {
          debugPrint('导航到视频详情页: ${strategy.bvid}');
          await Navigator.of(context).push(
            NamidaPageRoute(
              page: VideoDetailPage(
                bvid: strategy.bvid!,
                title: '视频详情',
              ),
              type: PageTransitionType.slideLeft,
            ),
          );
        } else {
          debugPrint('BV号为空，无法导航');
        }
        break;
        
      case SearchStrategyType.favorite:
        // 跳转到收藏夹详情页
        if (strategy.id != null) {
          final favoriteId = int.tryParse(strategy.id!);
          if (favoriteId != null) {
            debugPrint('导航到收藏夹详情页: $favoriteId');
            await Navigator.of(context).push(
              NamidaPageRoute(
                page: FavoriteDetailPage(
                  favoriteId: favoriteId,
                  title: '收藏夹',
                ),
                type: PageTransitionType.slideLeft,
              ),
            );
          } else {
            debugPrint('收藏夹ID解析失败: ${strategy.id}');
            _showMessage('收藏夹ID格式错误');
          }
        } else {
          debugPrint('收藏夹ID为空，无法导航');
        }
        break;
        
      case SearchStrategyType.collection:
        // 跳转到合集详情页
        if (strategy.id != null) {
          final collectionId = int.tryParse(strategy.id!);
          final mid = strategy.mid != null ? int.tryParse(strategy.mid!) : null;
          
          if (collectionId != null) {
            debugPrint('导航到合集详情页: collectionId=$collectionId, mid=$mid');
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
          } else {
            debugPrint('合集ID解析失败: ${strategy.id}');
            _showMessage('合集ID格式错误');
          }
        } else {
          debugPrint('合集ID为空，无法导航');
          _showMessage('无法获取合集信息');
        }
        break;
        
      case SearchStrategyType.uploader:
        // 跳转到UP主页面
        if (strategy.mid != null) {
          final mid = int.tryParse(strategy.mid!);
          if (mid != null) {
            debugPrint('导航到UP主页面: mid=$mid');
            await Navigator.of(context).push(
              NamidaPageRoute(
                page: UserVideosPage(
                  mid: mid,
                  userName: 'UP主',  // 默认名称，页面内会加载真实信息
                ),
                type: PageTransitionType.slideLeft,
              ),
            );
          } else {
            debugPrint('UP主ID解析失败: ${strategy.mid}');
            _showMessage('UP主ID格式错误');
          }
        } else {
          debugPrint('UP主ID为空，无法导航');
          _showMessage('无法获取UP主信息');
        }
        break;
        
      case SearchStrategyType.search:
        // 跳转到全局搜索结果页
        if (strategy.query != null && strategy.query!.isNotEmpty) {
          debugPrint('导航到搜索结果页: ${strategy.query}');
          await Navigator.of(context).push(
            NamidaPageRoute(
              page: GlobalSearchResultPage(query: strategy.query!),
              type: PageTransitionType.slideLeft,
            ),
          );
        } else {
          debugPrint('搜索关键词为空');
        }
        break;
        
      case SearchStrategyType.b23ResolveError:
        _showMessage('b23.tv短链解析失败: ${strategy.error}');
        break;
        
      case SearchStrategyType.b23NoBvidError:
        _showMessage('短链解析成功，但未找到可识别内容\n解析结果: ${strategy.resolvedUrl}');
        break;
        
      case SearchStrategyType.avParseError:
        _showMessage('AV号解析失败');
        break;
        
      case SearchStrategyType.invalidUrlNoCtype:
        _showMessage('链接缺少必要参数，请检查是否复制完整');
        break;
    }
  }

  /// 显示消息提示
  void _showMessage(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.white.withOpacity(0.9),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isDark 
            ? const Color(0xFF2C2C2E).withOpacity(0.95)
            : const Color(0xFF3A3A3C).withOpacity(0.95),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: const Duration(seconds: 3),
        elevation: 8,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.blue.withOpacity(0.15)
                : Colors.blue.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
          if (!isDark)
            BoxShadow(
              color: Colors.blue.withOpacity(0.08),
              blurRadius: 30,
              spreadRadius: 2,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? ThemeUtils.backgroundColor(context).withOpacity(0.97)
                  : Colors.white.withOpacity(0.95),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.12)
                    : Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                SizedBox(height: statusBarHeight),
                SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: '返回',
                      ),
                      const Expanded(
                        child: Text(
                          '智能搜索',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.history, size: 20),
                        onPressed: () {
                          // TODO: 历史记录
                        },
                        tooltip: '历史记录',
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  child: _buildSearchField(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Icon(
            Icons.search,
            size: 20,
            color: isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _handleSearch(),
              style: TextStyle(
                fontSize: 17,
                color: isDark ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                hintText: '输入BV/AV号、链接或关键词',
                hintStyle: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white.withOpacity(0.35) : Colors.black.withOpacity(0.35),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                isDense: true,
              ),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.0),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.send, size: 20),
              onPressed: _handleSearch,
              tooltip: '搜索',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _wrapWithoutStretch(Widget child) {
    return NotificationListener<OverscrollIndicatorNotification>(
      onNotification: (notification) {
        notification.disallowIndicator();
        return true;
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeUtils.backgroundColor(context),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: _wrapWithoutStretch(
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null) _buildErrorBanner(),
                    _buildUsageGuide(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建使用说明
  Widget _buildUsageGuide() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white.withOpacity(0.85) : Colors.black87;
    final secondaryColor = isDark ? Colors.white.withOpacity(0.6) : Colors.black54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 20),
          child: Text(
            '支持的输入格式',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: secondaryColor,
              letterSpacing: 0.3,
            ),
          ),
        ),
        _buildHintItem(
          emoji: '🎬',
          title: 'BV / AV 视频号',
          description: '输入 BV1xx4y1x7xx 或 av12345678，直接跳转播放',
          textColor: textColor,
          secondaryColor: secondaryColor,
        ),
        _buildHintItem(
          emoji: '⭐',
          title: '收藏夹 / 合集链接',
          description: '粘贴完整链接，智能识别并打开',
          textColor: textColor,
          secondaryColor: secondaryColor,
        ),
        _buildHintItem(
          emoji: '👤',
          title: 'UP 主主页',
          description: '分享 UP 主链接，查看全部视频',
          textColor: textColor,
          secondaryColor: secondaryColor,
        ),
        _buildHintItem(
          emoji: '🔗',
          title: 'b23.tv 短链',
          description: '自动解析真实目标，支持番剧、视频、收藏夹',
          textColor: textColor,
          secondaryColor: secondaryColor,
        ),
        _buildHintItem(
          emoji: '🔍',
          title: '关键词搜索',
          description: '任意关键词，全站搜索结果',
          textColor: textColor,
          secondaryColor: secondaryColor,
        ),
      ],
    );
  }

  Widget _buildHintItem({
    required String emoji,
    required String title,
    required String description,
    required Color textColor,
    required Color secondaryColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: secondaryColor,
                    height: 1.4,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark 
            ? const Color(0xFF3A2A2A).withOpacity(0.5)
            : const Color(0xFFFFE5E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.red.withOpacity(0.3)
              : Colors.red.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: isDark ? Colors.red.shade300 : Colors.red.shade700,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '搜索失败',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _errorMessage ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark 
                        ? Colors.white.withOpacity(0.7)
                        : Colors.black.withOpacity(0.6),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: isDark ? Colors.red.shade300 : Colors.red.shade700,
              size: 20,
            ),
            onPressed: _handleSearch,
            tooltip: '重试',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
