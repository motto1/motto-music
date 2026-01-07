import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:ui';
import 'package:motto_music/database/database.dart' as db;
import 'package:motto_music/models/bilibili/favorite.dart' as api;
import 'package:motto_music/services/bilibili/api_service.dart';
import 'package:motto_music/services/bilibili/api_client.dart';
import 'package:motto_music/services/bilibili/cookie_manager.dart';
import 'package:motto_music/services/player_provider.dart';
import 'package:motto_music/services/cache/page_cache_service.dart';
import 'package:motto_music/views/bilibili/login_page.dart';
import 'package:motto_music/views/bilibili/favorite_detail_page.dart';
import 'package:motto_music/views/bilibili/user_videos_page.dart';
import 'package:motto_music/utils/theme_utils.dart';
import 'package:motto_music/utils/bilibili_song_utils.dart';
import 'package:motto_music/router/router.dart';
import 'package:motto_music/contants/app_contants.dart';
import 'package:motto_music/animations/page_transitions.dart';
import 'package:motto_music/main.dart'; // 导入以访问全局播放器 Key
import 'package:motto_music/services/bilibili/download_manager.dart';
import 'package:motto_music/widgets/unified_cover_image.dart';
import 'package:motto_music/models/bilibili/audio_quality.dart';
import 'package:motto_music/widgets/audio_quality_section.dart';
import 'package:motto_music/widgets/show_aware_page.dart';
import 'package:motto_music/widgets/global_top_bar.dart';
import 'package:motto_music/router/route_observer.dart';
import 'package:motto_music/widgets/motto_search_field.dart';

/// Bilibili 收藏夹列表页面
class BilibiliFavoritesPage extends StatefulWidget {
  const BilibiliFavoritesPage({super.key});

  @override
  State<BilibiliFavoritesPage> createState() => _BilibiliFavoritesPageState();
}

class _BilibiliFavoritesPageState extends State<BilibiliFavoritesPage>
    with ShowAwarePage, RouteAware {
  late final BilibiliApiService _apiService;
  late final db.MusicDatabase _db;
  late final ScrollController _scrollController;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  Timer? _searchDebounce;
  final _pageCache = PageCacheService();

  static const Color _accentColor = Color(0xFFE84C4C);
  static const double _collapseDistance = 64.0;

  double _collapseProgress = 0.0;
  bool _isLoading = false;
  bool _isSearching = false;
  bool _isCheckingLogin = true;
  bool _isLoggedIn = false;
  List<api.BilibiliFavorite>? _favorites;
  List<api.BilibiliFavorite>? _filteredFavorites;
  List<db.Song> _searchResults = [];
  String? _errorMessage;
  String? _searchError;
  String _searchQuery = '';
  String? _userAvatarUrl;
  bool _isSelectionMode = false;
  final Set<int> _selectedFavoriteIds = <int>{};

  @override
  void initState() {
    super.initState();

    _db = db.MusicDatabase.database;
    final cookieManager = CookieManager();
    final apiClient = BilibiliApiClient(cookieManager);
    _apiService = BilibiliApiService(apiClient);
    _scrollController = ScrollController();
    _scrollController.addListener(_handleScroll);
    _searchController = TextEditingController(text: _searchQuery);
    _searchFocusNode = FocusNode();

    _checkLoginAndLoadData();
  }

  @override
  void onPageShow() {
    _applyTopBarStyle();
  }

  void _applyTopBarStyle() {
    _applyTopBarStyleWithProgress(_collapseProgress);
  }

  void _applyTopBarStyleWithProgress(double progress) {
    final barProgress = Curves.easeOutCubic.transform(
      ((progress - 0.08) / 0.72).clamp(0.0, 1.0),
    );
    final titleOpacity = Curves.easeOutCubic.transform(
      ((progress - 0.18) / 0.52).clamp(0.0, 1.0),
    );
    GlobalTopBarController.instance.set(
      GlobalTopBarStyle(
        source: 'bilibili-library',
        title: '专辑',
        showBackButton: true,
        centerTitle: false,
        opacity: barProgress,
        titleOpacity: titleOpacity,
        titleTranslateY: (1 - titleOpacity) * 6,
        translateY: 0.0,
        showDivider: progress > 0.28,
        backIconColor: _accentColor,
        onBack: () => Navigator.of(context).pop(),
        trailing: _buildTopBarTrailing(),
      ),
    );
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final progress = (offset / _collapseDistance).clamp(0.0, 1.0);
    if ((progress - _collapseProgress).abs() > 0.01) {
      setState(() {
        _collapseProgress = progress;
      });
    }
    _applyTopBarStyleWithProgress(progress);
  }

  Widget _buildTopBarTrailing() {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: const Icon(
          Icons.menu_rounded,
          size: 22,
          color: _accentColor,
        ),
        onPressed: _showPageMenu,
        tooltip: '更多',
      ),
    );
  }

  void _scheduleSearch(String value) {
    final query = value.trim();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      _filterFavorites(query);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _filterFavorites('');
    _searchFocusNode.requestFocus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    _applyTopBarStyle();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// 检查登录状态并加载数据
  Future<void> _checkLoginAndLoadData() async {
    if (!mounted) return;

    if (!_isCheckingLogin) {
      setState(() {
        _isCheckingLogin = true;
      });
    }

    final cookieManager = CookieManager();
    final isLoggedIn = await cookieManager.isLoggedIn();

    if (!mounted) return;

    setState(() {
      _isLoggedIn = isLoggedIn;
      _isCheckingLogin = false;
    });
    _applyTopBarStyle();

    if (isLoggedIn) {
      await _loadFavorites();
    }
  }

  /// 加载收藏夹(在线+本地)
  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 尝试获取用户信息(仅用于头像)
      try {
        // 先从缓存读取用户信息
        final cookieManager = CookieManager();
        final userId = await cookieManager.getUserId();
        if (userId != null) {
          final userMid = int.tryParse(userId);
          if (userMid != null) {
            final cachedUser = await _pageCache.getCachedUserInfo(userMid);
            if (cachedUser != null && mounted) {
              setState(() {
                _userAvatarUrl = cachedUser.face;
              });
              _applyTopBarStyle();
            }

            // 后台刷新用户信息
            _apiService.getCurrentUserInfo().then((userInfo) {
              if (mounted) {
                setState(() {
                  _userAvatarUrl = userInfo.face;
                });
                _applyTopBarStyle();
                // 更新缓存
                _pageCache.cacheUserInfo(userInfo);
              }
            }).catchError((e) {
              debugPrint('后台刷新用户信息失败: $e');
            });
          }
        }
      } catch (e) {
        debugPrint('获取用户信息失败(不影响加载): $e');
      }

      // 从数据库加载已添加的收藏夹（在线+本地）
      final dbFavorites = await _db.getAllBilibiliFavorites();
      final addedFavorites = dbFavorites.where((f) => f.isAddedToLibrary).toList();

      // 转换为 API 模型
      final favorites = addedFavorites.map((dbFav) => api.BilibiliFavorite(
        id: dbFav.remoteId,
        title: dbFav.title,
        cover: dbFav.coverUrl,
        intro: dbFav.description,
        mediaCount: dbFav.mediaCount,
        favState: 0,
      )).toList();

      if (mounted) {
        setState(() {
          _favorites = favorites;
          _filteredFavorites = favorites;
          _isLoading = false;
        });
        _filterFavorites(_searchQuery);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  /// 搜索收藏夹内的歌曲
  Future<void> _filterFavorites(String query) async {
    final trimmed = query.trim();
    setState(() {
      _searchQuery = trimmed;
      _searchError = null;
      if (trimmed.isEmpty) {
        _filteredFavorites = _favorites;
        _searchResults = [];
        _isSearching = false;
      }
    });
    if (trimmed.isNotEmpty) {
      await _runSearch(trimmed);
    }
  }

  Future<void> _runSearch(String query) async {
    setState(() {
      _isSearching = true;
      _searchResults = [];
    });
    try {
      final results = await _searchSongsInFavorites(query);
      if (!mounted || _searchQuery != query) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted || _searchQuery != query) return;
      setState(() {
        _searchError = e.toString();
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  /// 批量获取所有收藏夹的封面信息
  Future<List<api.BilibiliFavorite>> _fetchAllFavoriteCovers(
    List<api.BilibiliFavorite> favorites,
  ) async {
    if (favorites.isEmpty) return favorites;
    
    debugPrint('开始批量获取 ${favorites.length} 个收藏夹的封面...');
    
    // 并发请求所有收藏夹的第一页内容以获取封面
    final futures = favorites.map((fav) async {
      try {
        // 请求第一页内容（获取 info 中的封面）
        debugPrint('正在获取收藏夹 ${fav.title} (ID: ${fav.id}) 的封面...');
        final contents = await _apiService.getFavoriteContentsWithInfo(fav.id, 1);
        
        debugPrint('✓ 收藏夹 ${fav.title} 封面: ${contents.info.cover}');
        
        // 返回包含封面的收藏夹对象
        return api.BilibiliFavorite(
          id: fav.id,
          title: fav.title,
          cover: contents.info.cover,  // 使用API返回的封面
          intro: contents.info.intro,  // 更新简介
          mediaCount: contents.info.mediaCount,  // 使用最新的数量
          favState: fav.favState,
        );
      } catch (e) {
        // 如果获取失败，尝试从数据库读取
        debugPrint('✗ 获取收藏夹 ${fav.title} 封面失败: $e');
        final dbFav = await _db.getBilibiliFavoriteByRemoteId(fav.id);
        if (dbFav?.coverUrl != null) {
          debugPrint('  从数据库读取封面: ${dbFav!.coverUrl}');
        } else {
          debugPrint('  数据库中也没有封面');
        }
        return api.BilibiliFavorite(
          id: fav.id,
          title: fav.title,
          cover: dbFav?.coverUrl,  // 使用数据库中的封面
          intro: fav.intro,
          mediaCount: fav.mediaCount,
          favState: fav.favState,
        );
      }
    }).toList();
    
    // 等待所有请求完成（并发执行，速度快）
    final result = await Future.wait(futures);
    debugPrint('批量获取封面完成，共 ${result.length} 个收藏夹');
    return result;
  }

  /// 同步收藏夹到数据库
  Future<void> _syncFavoritesToDatabase(List<api.BilibiliFavorite> favorites) async {
    final favoritesData = favorites.map((fav) => 
      db.BilibiliFavoritesCompanion.insert(
        remoteId: fav.id,
        title: fav.title,
        description: Value(fav.intro),
        coverUrl: Value(fav.cover),
        mediaCount: Value(fav.mediaCount),
        syncedAt: DateTime.now(),
      )
    ).toList();
    
    await _db.insertBilibiliFavorites(favoritesData);
  }

  /// 跳转到登录页面
  Future<void> _navigateToLogin() async {
    final result = await Navigator.of(context).push<bool>(
      NamidaPageRoute(
        page: const BilibiliLoginPage(),
        type: PageTransitionType.slideLeft,
      ),
    );
    
    if (result == true && mounted) {
      // 登录成功，重新加载数据
      await _checkLoginAndLoadData();
    }
  }

  /// 刷新收藏夹
  Future<void> _refreshFavorites() async {
    await _loadFavorites();
  }

  /// 显示添加收藏夹对话框
  Future<void> _showAddFavoriteDialog() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _AddFavoriteBottomSheet(
        apiService: _apiService,
        onAdd: _addFavoriteToLibrary,
        onCreateLocal: _createLocalFavorite,
      ),
    );
  }

  /// 创建本地收藏夹
  Future<void> _createLocalFavorite(String title, String? description) async {
    try {
      // 生成本地收藏夹ID（负数表示本地）
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final localId = -timestamp;
      
      // 保存到数据库
      await _db.insertBilibiliFavorite(
        db.BilibiliFavoritesCompanion.insert(
          remoteId: localId,
          title: title,
          description: Value(description),
          coverUrl: const Value(null),
          mediaCount: const Value(0),
          syncedAt: DateTime.now(),
          isAddedToLibrary: const Value(true),
          isLocal: const Value(true),
        ),
      );
      
      await _pageCache.clearFavoritesCache();
      // 刷新列表
      await _loadFavorites();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已创建本地收藏夹: $title')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e')),
        );
      }
    }
  }

  /// 添加收藏夹到音乐库
  Future<void> _addFavoriteToLibrary(api.BilibiliFavorite favorite) async {
    try {
      // 获取封面
      final contents = await _apiService.getFavoriteContentsWithInfo(favorite.id, 1);
      
      // 保存到数据库（在线收藏夹）
      await _db.insertBilibiliFavorite(
        db.BilibiliFavoritesCompanion.insert(
          remoteId: favorite.id,
          title: favorite.title,
          description: Value(contents.info.intro),
          coverUrl: Value(contents.info.cover),
          mediaCount: Value(contents.info.mediaCount),
          syncedAt: DateTime.now(),
          isAddedToLibrary: const Value(true),
          isLocal: const Value(false),
        ),
      );
      
      await _pageCache.clearFavoritesCache();
      // 刷新列表
      await _loadFavorites();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已添加: ${favorite.title}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e')),
        );
      }
    }
  }

  /// 显示移除收藏夹确认对话框
  Future<void> _showRemoveDialog(api.BilibiliFavorite favorite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除收藏夹'),
        content: Text('确定要从音乐库移除"${favorite.title}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _removeFavoriteFromLibrary(favorite);
    }
  }

  /// 从音乐库移除收藏夹
  Future<void> _removeFavoriteFromLibrary(api.BilibiliFavorite favorite) async {
    try {
      final dbFav = await _db.getBilibiliFavoriteByRemoteId(favorite.id);
      if (dbFav != null) {
        await _db.updateBilibiliFavorite(
          dbFav.copyWith(isAddedToLibrary: false),
        );
        
        await _pageCache.clearFavoritesCache();
        await _loadFavorites();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已移除: ${favorite.title}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('移除失败: $e')),
        );
      }
    }
  }

  /// 显示搜索结果的歌曲菜单（样式对齐收藏夹详情页的 3 点菜单）
  Future<void> _showSearchResultSongMenu(db.Song song) async {
    final currentSong = song;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.white.withOpacity(0.5),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.2)
                      : Colors.white.withOpacity(0.6),
                  width: 1.5,
                ),
              ),
              child: ListView(
                controller: scrollController,
                children: [
                  // 顶部拖动把手
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.2)
                            : Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),

                  // 歌曲信息
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        UnifiedCoverImage(
                          coverPath: currentSong.albumArtPath,
                          width: 56,
                          height: 56,
                          borderRadius: 8,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentSong.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currentSong.artist ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.6),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // 与收藏夹详情页对齐的菜单项
                  if (currentSong.bilibiliFavoriteId != null)
                    ListTile(
                      leading: const Icon(Icons.remove_circle_outline),
                      title: const Text('从收藏夹移除'),
                      onTap: () {
                        Navigator.pop(context);
                        _removeSearchSongFromFavorite(currentSong);
                      },
                    ),
                  ListTile(
                    leading: Icon(
                      currentSong.isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border,
                    ),
                    title: Text(currentSong.isFavorite ? '取消喜欢' : '喜欢'),
                    onTap: () {
                      Navigator.pop(context);
                      _toggleSearchSongFavorite(currentSong);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.play_circle_outline),
                    title: const Text('插播'),
                    onTap: () {
                      Navigator.pop(context);
                      _playSearchSongNext(currentSong);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.playlist_add),
                    title: const Text('添加到播放列表'),
                    onTap: () {
                      Navigator.pop(context);
                      _addSearchSongToPlaylist(currentSong);
                    },
                  ),

                  // Bilibili 音质与下载区域（与收藏夹详情页保持一致）
                  if (currentSong.source == 'bilibili' && currentSong.bvid != null)
                    AudioQualitySection(song: currentSong),

                  if (currentSong.artist != null && currentSong.artist!.isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: const Text('查看制作人员'),
                      onTap: () {
                        Navigator.pop(context);
                        _viewSearchSongCreator(currentSong);
                      },
                    ),

                  // 底部留白
                  SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 从收藏夹移除搜索结果的歌曲
  Future<void> _removeSearchSongFromFavorite(db.Song song) async {
    try {
      if (song.bilibiliFavoriteId != null) {
        await (_db.delete(_db.songs)..where((s) => s.id.equals(song.id))).go();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已从收藏夹移除')),
          );
          // 刷新搜索结果
          _filterFavorites(_searchQuery);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('移除失败: $e')),
        );
      }
    }
  }

  /// 切换搜索结果歌曲的喜欢状态
  Future<void> _toggleSearchSongFavorite(db.Song song) async {
    try {
      final targetStatus = !song.isFavorite;
      final updatedSong = song.copyWith(isFavorite: targetStatus);

      if (song.id < 0) {
        final filePath = song.filePath.isNotEmpty
            ? song.filePath
            : buildBilibiliFilePath(
                bvid: song.bvid,
                cid: song.cid,
                pageNumber: song.pageNumber,
              );
        final existingSong = await _db.getSongByPath(filePath) ??
            ((song.bvid != null && song.cid != null)
                ? await _db.getSongByBvidAndCid(song.bvid!, song.cid!)
                : null);

        if (existingSong != null) {
          await _db.updateSong(
            existingSong.copyWith(isFavorite: targetStatus),
          );
        } else {
          await _db.insertSong(
            updatedSong.copyWith(filePath: filePath).toCompanion(false),
          );
        }
      } else {
        await _db.updateSong(updatedSong);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(targetStatus ? '已添加到喜欢' : '已取消喜欢')),
        );
        setState(() {
          _filterFavorites(_searchQuery);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  /// 插播搜索结果的歌曲
  Future<void> _playSearchSongNext(db.Song song) async {
    try {
      final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
      debugPrint(
        '[BilibiliFavoritesPage] ⏭ 插播搜索结果请求: songId=${song.id}, '
        'title=${song.title}, currentSongId=${playerProvider.currentSong?.id}, '
        'playlistLength=${playerProvider.playlist.length}',
      );
      await playerProvider.insertNext(song);

      if (mounted) {
        debugPrint(
          '[BilibiliFavoritesPage] ⏭ 插播搜索结果完成: currentSongId=${playerProvider.currentSong?.id}, '
          'playlistLength=${playerProvider.playlist.length}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  /// 添加搜索结果歌曲到播放列表
  Future<void> _addSearchSongToPlaylist(db.Song song) async {
    try {
      final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
      await playerProvider.addToPlaylist(song);
      
      if (mounted) {
        debugPrint(
          '[BilibiliFavoritesPage] ➕ 添加搜索结果到播放列表完成: songId=${song.id}, title=${song.title}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  /// 查看搜索结果歌曲的制作人员
  void _viewSearchSongCreator(db.Song song) {
    // 需要从API获取UP主的mid
    // 这里暂时只显示名称，实际使用需要扩展Song模型存储mid
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('制作人员: ${song.artist}')),
    );
  }

  /// 显示退出登录确认对话框
  Future<void> _showLogoutDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出 Bilibili 账号吗？\n退出后将无法同步收藏夹。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _handleLogout();
    }
  }

  /// 处理退出登录
  Future<void> _handleLogout() async {
    try {
      final cookieManager = CookieManager();
      await cookieManager.clearCookie();
      
      if (mounted) {
        setState(() {
          _isCheckingLogin = false;
          _isLoggedIn = false;
          _userAvatarUrl = null;
          _favorites = null;
          _filteredFavorites = null;
        });
        _applyTopBarStyle();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已退出登录')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('退出失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final bottomSpacerHeight = keyboardVisible ? 16.0 : 120.0;
    const topBarHeight = 52.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // 优先检查全局播放器是否全屏
          final playerKey = GlobalPlayerManager.playerKey;
          final playerState = playerKey?.currentState;
          final percentage = playerState?.percentage ?? -1;
          
          debugPrint('[BilibiliFavoritesPage PopScope] 播放器展开百分比: ${(percentage * 100).toStringAsFixed(1)}%');
          
          if (playerState != null && percentage >= 0.9) {
            // 播放器全屏，优先缩小播放器
            debugPrint('[BilibiliFavoritesPage PopScope] ✓ 拦截返回，缩小播放器');
            playerState.animateToState(false);
            return;
          }
          
          // 播放器非全屏，正常返回上一页
          debugPrint('[BilibiliFavoritesPage PopScope] → 返回上一页');
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? ThemeUtils.backgroundColor(context)
            : const Color(0xFFFFFFFF),
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _refreshFavorites,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(height: topPadding + topBarHeight + 1),
                  ),
                  SliverToBoxAdapter(
                    child: _buildLargeTitle(),
                  ),
                  SliverToBoxAdapter(
                    child: _buildSearchField(),
                  ),
                  SliverToBoxAdapter(
                    child: _buildActionButtons(),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 12),
                  ),
                  ..._buildContentSlivers(),
                  SliverToBoxAdapter(
                    child: SizedBox(height: bottomSpacerHeight),
                  ),
                ],
              ),
            ),
            if (_isSelectionMode)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: EdgeInsets.only(bottom: keyboardVisible ? 0 : 120),
                  child: _buildSelectionBar(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLargeTitle() {
    final eased = Curves.easeOutCubic.transform(_collapseProgress);
    final opacity = (1 - eased).clamp(0.0, 1.0);
    final translateY = -14 * eased;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Transform.translate(
        offset: Offset(0, translateY),
        child: Opacity(
          opacity: opacity,
          child: const Text(
            '专辑',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              height: 1.05,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: MottoSearchField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              hintText: '在专辑中搜索',
              onChanged: (value) {
                setState(() {});
                _scheduleSearch(value);
              },
              onSubmitted: (value) => _filterFavorites(value),
              onClear: _clearSearch,
            ),
          ),
          if (_isLoggedIn) ...[
            const SizedBox(width: 12),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showAddFavoriteDialog,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: _accentColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: Icons.play_arrow_rounded,
              label: '播放',
              onTap: () => _playAllFavorites(shuffle: false),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              icon: Icons.shuffle_rounded,
              label: '随机播放',
              onTap: () => _playAllFavorites(shuffle: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F2);
    final textColor = _accentColor;
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: textColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _playAllFavorites({required bool shuffle}) async {
    final favorites = _filteredFavorites ?? _favorites ?? const [];
    if (favorites.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暂无可播放的收藏夹')),
        );
      }
      return;
    }

    try {
      final songs = await _collectSongsForFavorites(favorites);
      if (!mounted) return;
      if (songs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到可播放的歌曲')),
        );
        return;
      }

      final playerProvider = context.read<PlayerProvider>();
      await playerProvider.playSong(
        songs.first,
        playlist: songs,
        index: 0,
        shuffle: shuffle,
        playNow: true,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放失败: $e')),
        );
      }
    }
  }

  List<Widget> _buildContentSlivers() {
    if (_isCheckingLogin) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (!_isLoggedIn) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildNotLoggedInView(),
        ),
      ];
    }

    if (_isLoading && _favorites == null) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (_errorMessage != null && _favorites == null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildErrorView(),
        ),
      ];
    }

    if (_searchQuery.isNotEmpty) {
      return _buildSearchResultSlivers();
    }

    if (_filteredFavorites == null || _filteredFavorites!.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildEmptyView(),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        sliver: _buildFavoritesSliverList(),
      ),
    ];
  }

  SliverGrid _buildFavoritesSliverList() {
    final favorites = _filteredFavorites ?? const [];
    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final favorite = favorites[index];
          return _buildAlbumCard(favorite);
        },
        childCount: favorites.length,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 20,
        childAspectRatio: 0.78,
      ),
    );
  }

  Widget _buildAlbumCard(api.BilibiliFavorite favorite) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = Colors.black.withValues(alpha: isDark ? 0.18 : 0.12);
    final isSelected = _selectedFavoriteIds.contains(favorite.id);
    final showSelection = _isSelectionMode;
    final subtitle = (favorite.intro ?? '').trim().isEmpty
        ? 'Bilibili'
        : favorite.intro!.trim();

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showSelection
          ? _toggleFavoriteSelection(favorite)
          : _navigateToFavoriteDetail(favorite),
      onLongPress: () => showSelection
          ? _toggleFavoriteSelection(favorite)
          : _showRemoveDialog(favorite),
      child: AnimatedOpacity(
        opacity: showSelection && !isSelected ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.maxWidth;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: size,
                  height: size,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        UnifiedCoverImage(
                          coverPath: favorite.cover,
                          width: size,
                          height: size,
                          borderRadius: 0,
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor, width: 0.8),
                            ),
                          ),
                        ),
                        if (showSelection)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? _accentColor
                                    : (isDark
                                        ? Colors.black.withOpacity(0.35)
                                        : Colors.white.withOpacity(0.9)),
                                border: Border.all(
                                  color: isSelected
                                      ? _accentColor
                                      : (isDark
                                          ? Colors.white.withOpacity(0.6)
                                          : Colors.black.withOpacity(0.2)),
                                  width: 1,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  favorite.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: ThemeUtils.select(
                      context,
                      light: Colors.grey.shade600,
                      dark: Colors.grey.shade400,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildSearchResultSlivers() {
    if (_isSearching) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (_searchError != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Text(
              '搜索失败：$_searchError',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ];
    }

    if (_searchResults.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Text(
              '未找到匹配的歌曲',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final song = _searchResults[index];
            return _buildSearchResultItem(song, index);
          },
          childCount: _searchResults.length,
        ),
      ),
    ];
  }

  Widget _buildSearchResultItem(db.Song song, int index) {
    return Column(
      children: [
        InkWell(
          onTap: () async {
            final playerProvider = context.read<PlayerProvider>();
            await playerProvider.playSong(
              song,
              playlist: _searchResults,
              index: index,
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                UnifiedCoverImage(
                  coverPath: song.albumArtPath,
                  width: 64,
                  height: 64,
                  borderRadius: 6,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song.artist ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5),
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.more_vert,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5),
                    size: 20,
                  ),
                  onPressed: () => _showSearchResultSongMenu(song),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
              ],
            ),
          ),
        ),
        Divider(
          height: 1,
          thickness: 0.5,
          indent: 96,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
        ),
      ],
    );
  }

  /// 构建未登录视图
  Widget _buildNotLoggedInView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Bilibili 粉色图标
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFB7299), // Bilibili Pink
                    Color(0xFF23ADE5), // Bilibili Blue
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFB7299).withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.account_circle,
                size: 50,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 32),

            const Text(
              '请先登录 Bilibili 账号',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              '登录后即可同步收藏夹和下载音乐',
              style: TextStyle(
                fontSize: 14,
                color: isDark
                  ? Colors.white.withOpacity(0.5)
                  : Colors.black.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 48),

            // Apple 风格登录按钮
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _navigateToLogin,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF), // Apple 系统蓝
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF007AFF).withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.login_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      SizedBox(width: 12),
                      Text(
                        '登录',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建错误视图
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            const Text(
              '加载失败',
              style: TextStyle(fontSize: 18),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshFavorites,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建空视图
  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无添加的收藏夹',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击右下角按钮添加收藏夹',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<db.Song>> _collectSongsForFavorites(
    List<api.BilibiliFavorite> favorites,
  ) async {
    if (favorites.isEmpty) return [];
    return _loadSongsForFavorites(
      favorites: favorites,
      query: null,
    );
  }

  /// 搜索所有收藏夹内的歌曲（按关键字过滤）
  Future<List<db.Song>> _searchSongsInFavorites(String query) async {
    if (query.isEmpty) return [];
    final sourceFavorites = List<api.BilibiliFavorite>.from(_favorites ?? const []);
    if (sourceFavorites.isEmpty) return [];
    return _loadSongsForFavorites(
      favorites: sourceFavorites,
      query: query,
    );
  }

  /// 根据收藏夹列表加载歌曲，支持可选关键字过滤
  Future<List<db.Song>> _loadSongsForFavorites({
    required List<api.BilibiliFavorite> favorites,
    String? query,
  }) async {
    final queryLower = query?.toLowerCase();
    final allSongs = <db.Song>[];
    
    for (final favorite in favorites) {
      final dbFav = await _db.getBilibiliFavoriteByRemoteId(favorite.id);
      if (dbFav == null) continue;
      
      if (dbFav.isLocal) {
        // 本地收藏夹：从数据库查询
        final songs = await (_db.select(_db.songs)
              ..where((s) => s.bilibiliFavoriteId.equals(dbFav.id)))
            .get();
        if (queryLower == null || queryLower.isEmpty) {
          allSongs.addAll(songs);
        } else {
          final matched = songs
              .where((s) => s.title.toLowerCase().contains(queryLower))
              .toList();
          allSongs.addAll(matched);
        }
      } else {
        // 在线收藏夹：从API获取并展开分P
        try {
          final contents = await _apiService.getFavoriteContentsWithInfo(favorite.id, 1);
          for (final item in contents.medias ?? []) {
            if ((item.bvid ?? '').isEmpty) continue;
            final pages = await _pageCache.getOrFetchVideoPages(
              item.bvid!,
              () => _apiService.getVideoPages(item.bvid!),
            );
            for (final page in pages) {
              final partLower = page.part.toLowerCase();
              if (queryLower != null &&
                  queryLower.isNotEmpty &&
                  !partLower.contains(queryLower)) {
                continue;
              }
              allSongs.add(db.Song(
                id: -(page.cid),
                title: page.part,
                artist: item.upper?.name,
                album: item.title,
                filePath: buildBilibiliFilePath(
                  bvid: item.bvid,
                  cid: page.cid,
                  pageNumber: page.page,
                ),
                duration: page.duration,
                albumArtPath: item.cover,
                dateAdded: DateTime.now(),
                isFavorite: false,
                lastPlayedTime: DateTime.now(),
                playedCount: 0,
                source: 'bilibili',
                bvid: item.bvid,
                cid: page.cid,
                pageNumber: page.page,
              ));
            }
          }
        } catch (e) {
          debugPrint('搜索在线收藏夹失败: $e');
        }
      }
    }
    
    return allSongs;
  }

  /// 跳转到收藏夹详情
  void _navigateToFavoriteDetail(api.BilibiliFavorite favorite) {
    Navigator.of(context).push(
      NamidaPageRoute(
        page: FavoriteDetailPage(
          favoriteId: favorite.id,
          title: favorite.title,
        ),
        type: PageTransitionType.slideLeft,
      ),
    );
  }

  /// 根据收藏夹批量下载歌曲
  Future<void> _confirmAndDownloadFavorites(
      List<api.BilibiliFavorite> favorites) async {
    if (favorites.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前没有可下载的收藏夹')),
        );
      }
      return;
    }

    final estimatedCount =
        favorites.fold<int>(0, (sum, f) => sum + (f.mediaCount));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('批量下载收藏夹'),
        content: Text(
          '将为 ${favorites.length} 个收藏夹'
          '${estimatedCount > 0 ? '（约 $estimatedCount 首歌曲）' : ''} 添加下载任务。\n'
          '这可能会消耗较多网络流量和存储空间，是否继续？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('继续'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final songs = await _collectSongsForFavorites(favorites);
      if (songs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未找到可下载的歌曲')),
          );
        }
        return;
      }

      final downloadManager = context.read<DownloadManager>();
      final defaultQualityId =
          downloadManager.userSettings?.defaultDownloadQuality ??
              BilibiliAudioQuality.flac.id;
      final quality = BilibiliAudioQuality.fromId(defaultQualityId);

      await downloadManager.batchDownload(
        songs: songs,
        quality: quality,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已为 ${songs.length} 首歌曲创建下载任务')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('批量下载失败: $e')),
        );
      }
    }
  }

  /// 页面级更多操作菜单
  void _showPageMenu() {
    if (!_isLoggedIn) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final canDownloadAll =
            _filteredFavorites != null && _filteredFavorites!.isNotEmpty;
        final inSearchMode = _searchQuery.isNotEmpty;

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isLoggedIn)
                ListTile(
                  leading: const Icon(Icons.add_circle_outline),
                  title: const Text('新建收藏夹'),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddFavoriteDialog();
                  },
                ),
              ListTile(
                leading: Icon(
                  _isSelectionMode
                      ? Icons.check_box_outline_blank
                      : Icons.check_box,
                ),
                title: Text(
                  _isSelectionMode ? '退出多选模式' : '多选下载收藏夹内的音乐',
                ),
                onTap: () {
                  Navigator.pop(context);
                  if (_isSelectionMode) {
                    _exitSelectionMode();
                  } else {
                    _enterSelectionMode();
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_for_offline_outlined),
                title: const Text('下载当前列表中所有收藏夹'),
                enabled: canDownloadAll && !inSearchMode,
                onTap: canDownloadAll && !inSearchMode
                    ? () {
                        Navigator.pop(context);
                        final favorites = List<api.BilibiliFavorite>.from(
                          _filteredFavorites ?? const [],
                        );
                        _confirmAndDownloadFavorites(favorites);
                      }
                    : null,
              ),
              if (inSearchMode)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    '当前处于搜索结果视图，批量下载仅在收藏夹列表视图可用。',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                  ),
                ),
              if (_userAvatarUrl != null)
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('退出登录'),
                  onTap: () {
                    Navigator.pop(context);
                    _showLogoutDialog();
                  },
                ),
              SizedBox(
                height: MediaQuery.of(context).padding.bottom + 120,
              ),
            ],
          ),
        );
      },
    );
  }

  void _enterSelectionMode({api.BilibiliFavorite? initialFavorite}) {
    if (!_isLoggedIn) return;
    setState(() {
      _isSelectionMode = true;
      _selectedFavoriteIds.clear();
      if (initialFavorite != null) {
        _selectedFavoriteIds.add(initialFavorite.id);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedFavoriteIds.clear();
    });
  }

  void _toggleFavoriteSelection(api.BilibiliFavorite favorite) {
    if (!_isSelectionMode) {
      _enterSelectionMode(initialFavorite: favorite);
      return;
    }
    setState(() {
      if (_selectedFavoriteIds.contains(favorite.id)) {
        _selectedFavoriteIds.remove(favorite.id);
      } else {
        _selectedFavoriteIds.add(favorite.id);
      }
    });
  }

  void _selectAllVisibleFavorites() {
    final list = _filteredFavorites ?? _favorites ?? [];
    if (list.isEmpty) return;
    setState(() {
      _isSelectionMode = true;
      _selectedFavoriteIds
        ..clear()
        ..addAll(list.map((f) => f.id));
    });
  }

  void _clearSelectionOnly() {
    setState(() {
      _selectedFavoriteIds.clear();
    });
  }

  List<api.BilibiliFavorite> _getSelectedFavorites() {
    final list = _favorites ?? [];
    if (_selectedFavoriteIds.isEmpty) return const [];
    return list.where((f) => _selectedFavoriteIds.contains(f.id)).toList();
  }

  Future<void> _downloadSelectedFavorites() async {
    final selected = _getSelectedFavorites();
    if (selected.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先选择要下载的收藏夹')),
        );
      }
      return;
    }
    await _confirmAndDownloadFavorites(selected);
  }

  Widget _buildSelectionBar() {
    final selectedCount = _selectedFavoriteIds.length;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(
              '已选 $selectedCount 个收藏夹',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.7),
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: _selectAllVisibleFavorites,
              child: const Text('全选'),
            ),
            TextButton(
              onPressed:
                  selectedCount > 0 ? _clearSelectionOnly : null,
              child: const Text('清空'),
            ),
            const SizedBox(width: 4),
            FilledButton(
              onPressed:
                  selectedCount > 0 ? _downloadSelectedFavorites : null,
              child: const Text('下载所选'),
            ),
            const SizedBox(width: 4),
            TextButton(
              onPressed: _exitSelectionMode,
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 添加收藏夹底部弹窗
class _AddFavoriteBottomSheet extends StatefulWidget {
  final BilibiliApiService apiService;
  final Future<void> Function(api.BilibiliFavorite) onAdd;
  final Future<void> Function(String title, String? description) onCreateLocal;

  const _AddFavoriteBottomSheet({
    required this.apiService,
    required this.onAdd,
    required this.onCreateLocal,
  });

  @override
  State<_AddFavoriteBottomSheet> createState() => _AddFavoriteBottomSheetState();
}

class _AddFavoriteBottomSheetState extends State<_AddFavoriteBottomSheet> {
  bool _isLoading = true;
  List<api.BilibiliFavorite>? _favorites;
  List<api.BilibiliFavorite>? _filteredFavorites;
  final _searchController = TextEditingController();
  final _pageCache = PageCacheService();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 获取用户ID
      final cookieManager = CookieManager();
      final userId = await cookieManager.getUserId();
      if (userId == null) {
        throw Exception('未找到用户ID，请重新登录');
      }

      final userMid = int.tryParse(userId);
      if (userMid == null) {
        throw Exception('用户ID格式错误');
      }

      // 1. 先从缓存读取
      final cachedFavorites = await _pageCache.getCachedFavoritesList(userMid);
      if (cachedFavorites != null && cachedFavorites.isNotEmpty) {
        debugPrint('🎯 收藏夹列表缓存命中: ${cachedFavorites.length} 个');

        // 过滤掉已添加的收藏夹
        final database = db.MusicDatabase.database;
        final dbFavorites = await database.getAllBilibiliFavorites();
        final addedIds = dbFavorites.where((f) => f.isAddedToLibrary).map((f) => f.remoteId).toSet();
        final availableFavorites = cachedFavorites.where((f) => !addedIds.contains(f.id)).toList();

        if (mounted) {
          setState(() {
            _favorites = availableFavorites;
            _filteredFavorites = availableFavorites;
            _isLoading = false;
          });
        }

        // 后台刷新数据（不阻塞UI）
        _refreshFavoritesInBackground(userMid);
        return;
      }

      // 2. 缓存未命中，从API加载
      debugPrint('📡 收藏夹列表缓存未命中，从API加载...');
      await _loadFavoritesFromApi(userMid);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// 从API加载收藏夹列表并缓存
  Future<void> _loadFavoritesFromApi(int userMid) async {
    final userInfo = await widget.apiService.getUserInfo(userMid);
    final allFavorites = await widget.apiService.getFavoritePlaylists(userInfo.mid);

    // 为每个收藏夹获取封面
    final favoritesWithCover = <api.BilibiliFavorite>[];
    for (final favorite in allFavorites) {
      try {
        final contents = await widget.apiService.getFavoriteContentsWithInfo(favorite.id, 1);
        final favoriteWithCover = api.BilibiliFavorite(
          id: favorite.id,
          title: favorite.title,
          cover: contents.info.cover,
          intro: favorite.intro,
          mediaCount: favorite.mediaCount,
          favState: favorite.favState,
        );
        favoritesWithCover.add(favoriteWithCover);
      } catch (e) {
        debugPrint('获取收藏夹 ${favorite.id} 封面失败: $e');
        favoritesWithCover.add(favorite);
      }
    }

    // 缓存收藏夹列表
    await _pageCache.cacheFavoritesList(userMid, favoritesWithCover);

    // 过滤已添加的
    final database = db.MusicDatabase.database;
    final dbFavorites = await database.getAllBilibiliFavorites();
    final addedIds = dbFavorites.where((f) => f.isAddedToLibrary).map((f) => f.remoteId).toSet();
    final availableFavorites = favoritesWithCover.where((f) => !addedIds.contains(f.id)).toList();

    if (mounted) {
      setState(() {
        _favorites = availableFavorites;
        _filteredFavorites = availableFavorites;
        _isLoading = false;
      });
    }
  }

  /// 后台刷新收藏夹数据
  Future<void> _refreshFavoritesInBackground(int userMid) async {
    try {
      debugPrint('🔄 后台刷新收藏夹列表...');
      await _loadFavoritesFromApi(userMid);
      debugPrint('✅ 后台刷新完成');
    } catch (e) {
      debugPrint('⚠️ 后台刷新失败: $e');
    }
  }

  void _filterFavorites(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredFavorites = _favorites;
      } else {
        _filteredFavorites = _favorites?.where((f) {
          return f.title.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _showCreateLocalDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          title: const Text('创建本地收藏夹'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: '收藏夹名称',
                  hintText: '请输入名称',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: '简介（可选）',
                  hintText: '请输入简介',
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入收藏夹名称')),
                  );
                  return;
                }
                Navigator.pop(context);
                Navigator.pop(context); // 关闭底部弹窗
                await widget.onCreateLocal(title, descController.text.trim());
              },
              child: const Text('创建'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.white.withOpacity(0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.2)
                    : Colors.white.withOpacity(0.6),
                width: 1.5,
              ),
            ),
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.zero,
              physics: const ClampingScrollPhysics(),
              children: [
                // 顶部把手
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.2)
                          : Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                
                // 标题栏
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Text(
                        '添加收藏夹',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 22),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                
                // 创建本地收藏夹按钮
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showCreateLocalDialog,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.15)
                                : Colors.black.withOpacity(0.12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.create_new_folder_outlined,
                              size: 20,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '创建本地收藏夹',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                // 分隔线
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.2))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '或添加在线收藏夹',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5),
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.2))),
                    ],
                  ),
                ),
                
                // 搜索框
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: MottoSearchField(
                    controller: _searchController,
                    hintText: '搜索收藏夹',
                    onChanged: _filterFavorites,
                  ),
                ),
                
                // 内容区域
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(48.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red.withOpacity(0.7)),
                        const SizedBox(height: 16),
                        Text('加载失败: $_errorMessage', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadFavorites,
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  )
                else if (_filteredFavorites == null || _filteredFavorites!.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(48.0),
                    child: Center(
                      child: Text(
                        _searchController.text.isEmpty ? '所有收藏夹已添加' : '未找到匹配的收藏夹',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5),
                        ),
                      ),
                    ),
                  )
                else
                  // 收藏夹列表
                  ...List.generate(_filteredFavorites!.length, (index) {
                    final favorite = _filteredFavorites![index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            Navigator.pop(context);
                            await widget.onAdd(favorite);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.black.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.08),
                              ),
                            ),
                            child: Row(
                              children: [
                                // 封面
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: favorite.cover != null && favorite.cover!.isNotEmpty
                                      ? UnifiedCoverImage(
                                          coverPath: favorite.cover,
                                          width: 60,
                                          height: 60,
                                          borderRadius: 0,
                                          fit: BoxFit.cover,
                                          isDark: isDark,
                                          placeholder: Container(
                                            width: 60,
                                            height: 60,
                                            color: isDark
                                                ? Colors.white.withOpacity(0.1)
                                                : Colors.black.withOpacity(0.05),
                                            child: const Center(
                                              child:
                                                  CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          ),
                                          errorWidget: Container(
                                            width: 60,
                                            height: 60,
                                            color: isDark
                                                ? Colors.white.withOpacity(0.1)
                                                : Colors.black.withOpacity(0.05),
                                            child: Icon(
                                              Icons.folder_outlined,
                                              size: 30,
                                              color: isDark
                                                  ? Colors.white.withOpacity(0.3)
                                                  : Colors.black.withOpacity(0.3),
                                            ),
                                          ),
                                        )
                                      : Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? Colors.white.withOpacity(0.1)
                                                : Colors.black.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.folder_outlined,
                                            size: 30,
                                            color: isDark
                                                ? Colors.white.withOpacity(0.3)
                                                : Colors.black.withOpacity(0.3),
                                          ),
                                        ),
                                ),
                                
                                const SizedBox(width: 12),
                                
                                // 标题和信息
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        favorite.title,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${favorite.mediaCount} 个视频',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isDark
                                              ? Colors.white.withOpacity(0.6)
                                              : Colors.black.withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // 添加按钮
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF3B30),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFF3B30).withOpacity(0.3),
                                        blurRadius: 8,
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                
                SizedBox(height: bottomPadding + 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.withOpacity(0.7)),
              const SizedBox(height: 16),
              Text('加载失败: $_errorMessage', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadFavorites,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_filteredFavorites == null || _filteredFavorites!.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty ? '所有收藏夹已添加' : '未找到匹配的收藏夹',
          style: TextStyle(
            fontSize: 16,
            color: isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5),
          ),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _filteredFavorites!.length,
      itemBuilder: (context, index) {
        final favorite = _filteredFavorites![index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                Navigator.pop(context);
                await widget.onAdd(favorite);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.08),
                  ),
                ),
                child: Row(
                  children: [
                    // 封面
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: favorite.cover != null && favorite.cover!.isNotEmpty
                          ? UnifiedCoverImage(
                              coverPath: favorite.cover,
                              width: 60,
                              height: 60,
                              borderRadius: 0,
                              fit: BoxFit.cover,
                              isDark: isDark,
                              placeholder: Container(
                                width: 60,
                                height: 60,
                                color: isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.05),
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: Container(
                                width: 60,
                                height: 60,
                                color: isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.05),
                                child: Icon(
                                  Icons.folder_outlined,
                                  size: 30,
                                  color: isDark
                                      ? Colors.white.withOpacity(0.3)
                                      : Colors.black.withOpacity(0.3),
                                ),
                              ),
                            )
                          : Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.folder_outlined,
                                size: 30,
                                color: isDark
                                    ? Colors.white.withOpacity(0.3)
                                    : Colors.black.withOpacity(0.3),
                              ),
                            ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // 标题和信息
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            favorite.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${favorite.mediaCount} 个视频',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? Colors.white.withOpacity(0.6)
                                  : Colors.black.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // 添加按钮
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF3B30).withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
