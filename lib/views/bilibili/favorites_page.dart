import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:drift/drift.dart' show Value;
import 'package:provider/provider.dart';
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
import 'package:motto_music/views/bilibili/global_search_page.dart';
import 'package:motto_music/views/bilibili/user_videos_page.dart';
import 'package:motto_music/utils/theme_utils.dart';
import 'package:motto_music/utils/bilibili_song_utils.dart';
import 'package:motto_music/router/router.dart';
import 'package:motto_music/contants/app_contants.dart';
import 'package:motto_music/animations/page_transitions.dart';
import 'package:motto_music/main.dart'; // 导入以访问全局播放器 Key
import 'package:motto_music/widgets/apple_music_card.dart';
import 'package:motto_music/widgets/animated_list_item.dart';
import 'package:motto_music/views/bilibili/download_management_page.dart';
import 'package:motto_music/views/bilibili/bilibili_settings_page.dart';
import 'package:motto_music/services/bilibili/download_manager.dart';

/// Bilibili 收藏夹列表页面
class BilibiliFavoritesPage extends StatefulWidget {
  const BilibiliFavoritesPage({super.key});

  @override
  State<BilibiliFavoritesPage> createState() => _BilibiliFavoritesPageState();
}

class _BilibiliFavoritesPageState extends State<BilibiliFavoritesPage> {
  late final BilibiliApiService _apiService;
  late final db.MusicDatabase _db;
  late final TextEditingController _searchController;
  final _pageCache = PageCacheService();

  bool _isLoading = false;
  bool _isLoggedIn = false;
  List<api.BilibiliFavorite>? _favorites;
  List<api.BilibiliFavorite>? _filteredFavorites;
  String? _errorMessage;
  String _searchQuery = '';
  String? _userAvatarUrl;

  @override
  void initState() {
    super.initState();
    
    _db = db.MusicDatabase.database;
    final cookieManager = CookieManager();
    final apiClient = BilibiliApiClient(cookieManager);
    _apiService = BilibiliApiService(apiClient);
    _searchController = TextEditingController();
    
    _checkLoginAndLoadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 检查登录状态并加载数据
  Future<void> _checkLoginAndLoadData() async {
    final cookieManager = CookieManager();
    final isLoggedIn = await cookieManager.isLoggedIn();
    
    setState(() {
      _isLoggedIn = isLoggedIn;
    });
    
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
            }

            // 后台刷新用户信息
            _apiService.getCurrentUserInfo().then((userInfo) {
              if (mounted) {
                setState(() {
                  _userAvatarUrl = userInfo.face;
                });
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
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredFavorites = _favorites;
      }
    });
  }

  /// 清除搜索
  void _clearSearch() {
    _searchController.clear();
    _filterFavorites('');
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

  /// 显示搜索结果的歌曲菜单
  Future<void> _showSearchResultSongMenu(db.Song song) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部把手
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 歌曲信息
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: song.albumArtPath != null
                        ? CachedNetworkImage(
                            imageUrl: song.albumArtPath!,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 56,
                            height: 56,
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.music_note),
                          ),
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
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          song.artist ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
            // 菜单项
            if (song.bilibiliFavoriteId != null) ...[
              ListTile(
                leading: const Icon(Icons.remove_circle_outline),
                title: const Text('从收藏夹移除'),
                onTap: () {
                  Navigator.pop(context);
                  _removeSearchSongFromFavorite(song);
                },
              ),
            ],
            ListTile(
              leading: Icon(
                song.isFavorite ? Icons.favorite : Icons.favorite_border,
              ),
              title: Text(song.isFavorite ? '取消喜欢' : '喜欢'),
              onTap: () {
                Navigator.pop(context);
                _toggleSearchSongFavorite(song);
              },
            ),
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: const Text('插播'),
              onTap: () {
                Navigator.pop(context);
                _playSearchSongNext(song);
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('添加到播放列表'),
              onTap: () {
                Navigator.pop(context);
                _addSearchSongToPlaylist(song);
              },
            ),
            if (song.artist != null && song.artist!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('查看制作人员'),
                onTap: () {
                  Navigator.pop(context);
                  _viewSearchSongCreator(song);
                },
              ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
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
      playerProvider.addToPlaylist(song);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已添加到播放列表')),
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
      playerProvider.addToPlaylist(song);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已添加到播放列表')),
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
          _isLoggedIn = false;
          _userAvatarUrl = null;
          _favorites = null;
          _filteredFavorites = null;
        });
        
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
        backgroundColor: Theme.of(context).brightness == Brightness.dark 
            ? ThemeUtils.backgroundColor(context)
            : const Color(0xFFF2F2F7),
        body: CustomScrollView(
          slivers: [
            // 整合的液态玻璃头部容器（AppBar + 搜索框）
            SliverToBoxAdapter(
              child: _buildHeaderWithSearch(),
            ),
            
            // 内容
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).size.height - 200,
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建整合的头部（AppBar + 搜索框）
  Widget _buildHeaderWithSearch() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    
    return Container(
      decoration: BoxDecoration(
        // 只有下方两个角圆角
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        // 增强发光效果（浅色模式更明显）
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.blue.withOpacity(0.15)
                : Colors.blue.withOpacity(0.2), // 浅色模式增强
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
          if (!isDark) // 浅色模式额外阴影层
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
                // 状态栏占位
                SizedBox(height: statusBarHeight),
                
                // AppBar 部分
                SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.arrow_back_ios, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: '返回',
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Bilibili音乐库',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_userAvatarUrl != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: GestureDetector(
                            onTap: _showLogoutDialog,
                            child: CircleAvatar(
                              radius: 18,
                              backgroundImage: CachedNetworkImageProvider(_userAvatarUrl!),
                            ),
                          ),
                        ),
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(CupertinoIcons.search, size: 20),
                          onPressed: () {
                            Navigator.of(context).push(
                              NamidaPageRoute(
                                page: const GlobalSearchPage(),
                                type: PageTransitionType.slideLeft,
                              ),
                            );
                          },
                          tooltip: '智能搜索',
                        ),
                      ),
                      // 下载管理按钮（带徽章）
                      if (_isLoggedIn)
                        Consumer<DownloadManager>(
                          builder: (context, downloadManager, child) {
                            final downloadingCount = downloadManager.downloadingCount;
                            return Stack(
                              children: [
                                SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(CupertinoIcons.arrow_down_circle, size: 20),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        NamidaPageRoute(
                                          page: const DownloadManagementPage(),
                                          type: PageTransitionType.slideLeft,
                                        ),
                                      );
                                    },
                                    tooltip: '下载管理',
                                  ),
                                ),
                                if (downloadingCount > 0)
                                  Positioned(
                                    right: 4,
                                    top: 4,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 16,
                                        minHeight: 16,
                                      ),
                                      child: Text(
                                        downloadingCount > 99 ? '99+' : '$downloadingCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      if (_isLoggedIn)
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(CupertinoIcons.gear_alt, size: 20),
                            onPressed: () {
                              Navigator.of(context).push(
                                NamidaPageRoute(
                                  page: const BilibiliSettingsPage(),
                                  type: PageTransitionType.slideLeft,
                                ),
                              );
                            },
                            tooltip: 'Bilibili 设置',
                          ),
                        ),
                    ],
                  ),
                ),
                
                // 搜索框部分
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    children: [
                      // iOS 风格搜索框
                      Expanded(
                        child: Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1C1C1E)
                                : const Color(0xFFE5E5EA),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Icon(
                                  CupertinoIcons.search,
                                  size: 18,
                                  color: isDark
                                      ? Colors.white.withOpacity(0.5)
                                      : Colors.black.withOpacity(0.5),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: (query) => _filterFavorites(query),
                                    style: TextStyle(
                                      fontSize: 17,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '搜索',
                                      hintStyle: TextStyle(
                                        fontSize: 17,
                                        color: isDark
                                            ? Colors.white.withOpacity(0.3)
                                            : Colors.black.withOpacity(0.3),
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 0,
                                      ),
                                      isDense: true,
                                    ),
                                    textAlignVertical: TextAlignVertical.center,
                                  ),
                                ),
                              ),
                              if (_searchQuery.isNotEmpty)
                                IconButton(
                                  icon: Icon(
                                    CupertinoIcons.xmark_circle_fill,
                                    size: 18,
                                    color: isDark
                                        ? Colors.white.withOpacity(0.5)
                                        : Colors.black.withOpacity(0.5),
                                  ),
                                  onPressed: _clearSearch,
                                  tooltip: '清除',
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(),
                                ),
                            ],
                          ),
                        ),
                      ),
                      
                      // 添加收藏夹按钮
                      if (_isLoggedIn) ...[
                        const SizedBox(width: 12),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _showAddFavoriteDialog,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF3B30),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    // 未登录状态
    if (!_isLoggedIn) {
      return _buildNotLoggedInView();
    }
    
    // 加载中
    if (_isLoading && _favorites == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    // 加载出错
    if (_errorMessage != null && _favorites == null) {
      return _buildErrorView();
    }
    
    // 已登录时，始终显示列表视图（包括搜索框和添加按钮）
    // 即使列表为空，也要显示UI让用户可以添加
    return _buildFavoritesList();
  }

  /// 构建未登录视图
  Widget _buildNotLoggedInView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_circle,
              size: 80,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 24),
            const Text(
              '请先登录 Bilibili 账号',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _navigateToLogin,
              icon: const Icon(Icons.login),
              label: const Text('登录'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
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

  /// 构建收藏夹列表
  Widget _buildFavoritesList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      // 统一的背景色，防止BackdropFilter模糊到不同颜色
      color: isDark 
          ? ThemeUtils.backgroundColor(context)
          : const Color(0xFFF2F2F7),
      child: Column(
        children: [
          // 列表（添加clipBehavior防止阴影溢出）
          Expanded(
            child: ClipRect(
              child: _searchQuery.isNotEmpty
                  ? _buildSearchResults()
                  : (_filteredFavorites == null || _filteredFavorites!.isEmpty
                      ? _buildEmptyView()
                      : RefreshIndicator(
                          onRefresh: _refreshFavorites,
                          child: _wrapWithoutStretch(
                            ListView.builder(
                              padding: const EdgeInsets.only(bottom: 100),
                              itemCount: _filteredFavorites!.length,
                              clipBehavior: Clip.none, // 允许阴影显示但不溢出父容器
                              itemBuilder: (context, index) {
                                final favorite = _filteredFavorites![index];
                                return AnimatedListItem(
                                  index: index,
                                  child: _buildFavoriteCard(
                                    favorite,
                                    isFirst: index == 0,
                                  ),
                                );
                              },
                            ),
                          ),
                        )),
            ),
          ),
        ],
      ),
    );
  }

  /// 禁用 Material StretchingOverscrollIndicator 防止叠加变色
  Widget _wrapWithoutStretch(Widget child) {
    return NotificationListener<OverscrollIndicatorNotification>(
      onNotification: (notification) {
        notification.disallowIndicator();
        return true;
      },
      child: child,
    );
  }

  /// 构建搜索结果（显示匹配的歌曲）
  Widget _buildSearchResults() {
    return FutureBuilder<List<db.Song>>(
      future: _searchSongsInFavorites(_searchQuery),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final songs = snapshot.data ?? [];
        
        if (songs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '未找到匹配的歌曲',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        return _wrapWithoutStretch(
          ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return Column(
                children: [
                  InkWell(
                    onTap: () async {
                      final playerProvider = context.read<PlayerProvider>();
                      await playerProvider.playSong(song, playlist: songs, index: index);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          // 封面
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: song.albumArtPath != null
                                ? CachedNetworkImage(
                                    imageUrl: song.albumArtPath!,
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      width: 64,
                                      height: 64,
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      width: 64,
                                      height: 64,
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      child: const Icon(Icons.music_note, size: 28),
                                    ),
                                  )
                                : Container(
                                    width: 64,
                                    height: 64,
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    child: const Icon(Icons.music_note, size: 28),
                                  ),
                          ),
                          const SizedBox(width: 16),
                          // 信息
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
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                    height: 1.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // 三点菜单
                          IconButton(
                            icon: Icon(
                              Icons.more_vert,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
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
                  // 分隔线
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 96,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// 搜索所有收藏夹内的歌曲
  Future<List<db.Song>> _searchSongsInFavorites(String query) async {
    if (query.isEmpty) return [];
    
    final queryLower = query.toLowerCase();
    final allSongs = <db.Song>[];
    
    for (final favorite in _favorites ?? []) {
      final dbFav = await _db.getBilibiliFavoriteByRemoteId(favorite.id);
      if (dbFav == null) continue;
      
      if (dbFav.isLocal) {
        // 本地收藏夹：从数据库查询
        final songs = await (_db.select(_db.songs)
              ..where((s) => s.bilibiliFavoriteId.equals(dbFav.id)))
            .get();
        final matched = songs.where((s) => s.title.toLowerCase().contains(queryLower)).toList();
        allSongs.addAll(matched);
      } else {
        // 在线收藏夹：从API获取并展开分P
        try {
          final contents = await _apiService.getFavoriteContentsWithInfo(favorite.id, 1);
          for (final item in contents.medias ?? []) {
            final pages = await _apiService.getVideoPages(item.bvid);
            for (final page in pages) {
              if (page.part.toLowerCase().contains(queryLower)) {
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
          }
        } catch (e) {
          debugPrint('搜索在线收藏夹失败: $e');
        }
      }
    }
    
    return allSongs;
  }

  /// 构建收藏夹卡片
  Widget _buildFavoriteCard(api.BilibiliFavorite favorite,
      {required bool isFirst}) {
    return FutureBuilder<db.BilibiliFavorite?>(
      future: _db.getBilibiliFavoriteByRemoteId(favorite.id),
      builder: (context, snapshot) {
        final isLocal = snapshot.data?.isLocal ?? false;
        final subtitle = isLocal ? 'Bilibili 本地收藏夹' : 'Bilibili';
        
        return AppleMusicCard(
          title: favorite.title,
          subtitle: subtitle,
          coverUrl: favorite.cover,
          itemCount: favorite.mediaCount,
          margin: EdgeInsets.fromLTRB(16, isFirst ? 16 : 8, 16, 8),
          onTap: () => _navigateToFavoriteDetail(favorite),
          onLongPress: () => _showRemoveDialog(favorite),
        );
      },
    );
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
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.search,
                            size: 20,
                            color: isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: _filterFavorites,
                            style: TextStyle(fontSize: 17, color: isDark ? Colors.white : Colors.black),
                            decoration: InputDecoration(
                              hintText: '搜索收藏夹',
                              hintStyle: TextStyle(
                                fontSize: 17,
                                color: isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.3),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                              isDense: true,
                            ),
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: Icon(
                              Icons.cancel,
                              size: 18,
                              color: isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5),
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _filterFavorites('');
                            },
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
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
                                      ? CachedNetworkImage(
                                          imageUrl: favorite.cover!,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(
                                            width: 60,
                                            height: 60,
                                            color: isDark
                                                ? Colors.white.withOpacity(0.1)
                                                : Colors.black.withOpacity(0.05),
                                            child: const Center(
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) => Container(
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
                          ? CachedNetworkImage(
                              imageUrl: favorite.cover!,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 60,
                                height: 60,
                                color: isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.05),
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
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
