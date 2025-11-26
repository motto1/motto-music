# BBPlayer 功能迁移到 LZF-Music 详细计划

> **文档版本**: v1.0  
> **创建日期**: 2025-11-06  
> **目标**: 将 BBPlayer 的 Bilibili 集成功能迁移到 LZF-Music Flutter 项目

---

## 📑 目录

1. [项目对比分析](#项目对比分析)
2. [迁移策略](#迁移策略)
3. [技术架构设计](#技术架构设计)
4. [实施计划](#实施计划)
5. [技术难点与解决方案](#技术难点与解决方案)
6. [风险评估](#风险评估)
7. [后续维护](#后续维护)

---

## 项目对比分析

### BBPlayer (源项目)

**技术栈**:
- **框架**: React Native 0.81.5 + Expo ~54.0.21
- **语言**: TypeScript 5.9.2
- **状态管理**: Zustand 5.0.8
- **数据请求**: React Query (@tanstack/react-query 5.90.5)
- **数据库**: Drizzle ORM 0.44.7 + expo-sqlite 16.0.8
- **播放器**: React Native Track Player 5.0.0-alpha0
- **UI 框架**: React Native Paper 5.14.5 (Material Design 3)

**核心功能模块**:

1. **用户认证**
   - 二维码登录 (`getLoginQrCode`, `pollQrCodeLoginStatus`)
   - Cookie 手动导入
   - 用户信息管理 (`getUserInfo`)

2. **内容管理**
   - 收藏夹列表 (`getFavoritePlaylists`)
   - 收藏夹内容浏览 (`getFavoriteListContents`)
   - 合集/追更列表 (`getCollectionsList`, `getCollectionAllContents`)
   - 多P视频支持 (`getPageList`)

3. **搜索功能**
   - 视频搜索 (`searchVideos`)
   - 热门搜索建议 (`getHotSearches`, `getSearchSuggestions`)
   - 收藏夹内搜索 (`searchFavoriteListContents`)
   - b23.tv 短链解析 (`getB23ResolvedUrl`)

4. **播放核心**
   - 音频流获取 (`getAudioStream`)
   - 多音质支持 (普通/Hi-Res/Dolby)
   - WBI 签名验证 (`getWbiEncodedParams`)
   - 流地址缓存管理

5. **高级功能**
   - 播放历史上报 (`reportPlaybackHistory`)
   - 稍后再看管理 (`getToViewVideoList`, `deleteToViewVideo`)
   - 收藏夹操作 (`dealFavoriteForOneVideo`, `batchDeleteFavoriteListContents`)
   - 视频点赞 (`thumbUpVideo`, `checkVideoIsThumbUp`)
   - 离线下载与缓存


**数据库设计** (Drizzle ORM):

```typescript
// 核心表结构
artists {
  id: integer (PK, auto)
  name: text
  avatarUrl: text
  signature: text
  source: 'bilibili' | 'local'
  remoteId: text (bilibili mid)
  createdAt, updatedAt
}

tracks {
  id: integer (PK, auto)
  uniqueKey: text (unique) // 基于 source 生成
  title: text
  artistId: integer (FK -> artists.id)
  coverUrl: text
  duration: integer
  playHistory: json (PlayRecord[])
  source: 'bilibili' | 'local'
  createdAt, updatedAt
}

playlists {
  id: integer (PK, auto)
  title: text
  authorId: integer (FK -> artists.id)
  description: text
  coverUrl: text
  itemCount: integer
  type: 'favorite' | 'collection' | 'multi_page' | 'local'
  remoteSyncId: integer // Bilibili 远程 ID
  createdAt, updatedAt
}
```


### LZF-Music (目标项目)

**技术栈**:
- **框架**: Flutter 3.3.0+
- **语言**: Dart
- **状态管理**: Provider 6.1.5
- **数据库**: Drift 2.28.0 + sqlite3_flutter_libs 0.5.0
- **播放器**: media_kit 1.1.11 + media_kit_libs_audio 1.0.7
- **平台管理**: window_manager 0.5.1, bitsdojo_window 0.1.6
- **系统集成**: audio_service 0.18.18

**现有功能**:
1. 本地音乐库管理
2. 播放器核心功能 (播放/暂停/上下曲/进度控制)
3. WebDAV 远程同步 (webdav_client 1.2.2)
4. 桌面/移动端自适应 UI
5. 音频元数据读取 (audio_metadata_reader)
6. 收藏/播放历史/播放计数
7. 自定义主题/颜色

**数据库结构** (Drift):

```dart
class Songs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get artist => text().nullable()();
  TextColumn get album => text().nullable()();
  TextColumn get filePath => text()();
  TextColumn get lyrics => text().nullable()();
  IntColumn get bitrate => integer().nullable()();
  IntColumn get sampleRate => integer().nullable()();
  IntColumn get duration => integer().nullable()();
  TextColumn get albumArtPath => text().nullable()();
  DateTimeColumn get dateAdded => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastPlayedTime => dateTime()();
  IntColumn get playedCount => integer().withDefault(const Constant(0))();
}
```


**技术差异对比**:

| 维度 | BBPlayer | LZF-Music | 迁移策略 |
|------|----------|-----------|---------|
| 编程语言 | TypeScript | Dart | 完全重写 |
| 网络请求 | fetch API | http/dio | 重新实现 |
| 错误处理 | neverthrow (Result模式) | try-catch + Future | 采用 Either 或 Result 模式 |
| 状态管理 | Zustand | Provider | 保持 Provider 或引入 Riverpod |
| 数据持久化 | MMKV (react-native-mmkv) | shared_preferences | 使用 shared_preferences |
| 数据库 | Drizzle ORM | Drift | 扩展现有 Drift 模型 |

---

## 迁移策略

### 总体原则

1. **保持现有架构稳定**: 不破坏 LZF-Music 现有功能
2. **渐进式集成**: 分阶段实施，每个阶段可独立测试
3. **代码复用**: 核心算法从 TypeScript 翻译为 Dart
4. **平台兼容**: 确保跨平台一致性 (Windows/Linux/macOS/Android/iOS)
5. **性能优先**: 优化网络请求和数据缓存

### 迁移方式

#### ❌ 不可行方案
- **直接移植代码**: TypeScript 和 Dart 语法差异大
- **使用 WebView 嵌入**: 性能差，体验不一致
- **FFI 调用 JS**: 复杂度高，维护困难

#### ✅ 推荐方案
**完全重写 + 算法翻译**

1. **API 层**: TypeScript API 逻辑 → Dart HTTP 客户端
2. **数据层**: Drizzle 模型 → Drift 模型扩展
3. **业务层**: React Hooks/Zustand → Dart Service 类
4. **UI 层**: React Native 组件 → Flutter Widget


---

## 技术架构设计

### 目录结构规划

```
lib/
├── services/
│   ├── bilibili/
│   │   ├── api_client.dart              # HTTP 客户端基类
│   │   ├── api_service.dart             # Bilibili API 服务
│   │   ├── wbi_signer.dart              # WBI 签名算法
│   │   ├── cookie_manager.dart          # Cookie 管理器
│   │   ├── stream_cache_manager.dart    # 音频流缓存管理
│   │   └── constants.dart               # API 常量配置
│   ├── audio_player_service.dart        # (扩展) 播放器服务
│   └── ...
├── models/
│   ├── bilibili/
│   │   ├── video.dart                   # 视频模型
│   │   ├── playlist.dart                # 收藏夹/合集模型
│   │   ├── user.dart                    # 用户信息模型
│   │   ├── audio_stream.dart            # 音频流模型
│   │   └── search_result.dart           # 搜索结果模型
│   └── ...
├── database/
│   ├── database.dart                    # (扩展) 数据库主文件
│   └── tables/
│       ├── bilibili_videos.dart         # Bilibili 视频表
│       ├── bilibili_favorites.dart      # Bilibili 收藏夹表
│       └── bilibili_stream_cache.dart   # 流缓存表
├── views/
│   ├── bilibili/
│   │   ├── login_page.dart              # 登录页
│   │   ├── favorites_page.dart          # 收藏夹列表
│   │   ├── search_page.dart             # 搜索页
│   │   ├── playlist_detail_page.dart    # 播放列表详情
│   │   └── user_profile_page.dart       # 用户主页
│   └── ...
├── widgets/
│   ├── bilibili/
│   │   ├── qr_code_login_dialog.dart    # 二维码登录弹窗
│   │   ├── video_card.dart              # 视频卡片
│   │   ├── favorite_card.dart           # 收藏夹卡片
│   │   └── stream_quality_selector.dart # 音质选择器
│   └── ...
├── utils/
│   ├── bilibili_utils.dart              # Bilibili 工具函数 (BV/AV转换等)
│   └── result.dart                      # Result 类型 (错误处理)
└── ...
```


### 核心模块设计

#### 1. API 客户端层

**文件**: `lib/services/bilibili/api_client.dart`

```dart
import 'package:dio/dio.dart';
import 'cookie_manager.dart';

class BilibiliApiClient {
  static const String baseUrl = 'https://api.bilibili.com';
  late final Dio _dio;
  final CookieManager _cookieManager;

  BilibiliApiClient(this._cookieManager) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0_1 like Mac OS X) AppleWebKit/605.1.15',
        'Referer': 'https://www.bilibili.com',
      },
    ));

    // 添加拦截器自动注入 Cookie
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final cookie = await _cookieManager.getCookieString();
        if (cookie.isNotEmpty) {
          options.headers['Cookie'] = cookie;
        }
        return handler.next(options);
      },
    ));
  }

  Future<T> get<T>(String path, {Map<String, dynamic>? params}) async {
    final response = await _dio.get(path, queryParameters: params);
    return _handleResponse<T>(response);
  }

  Future<T> post<T>(String path, {Map<String, dynamic>? data}) async {
    final response = await _dio.post(path, data: data);
    return _handleResponse<T>(response);
  }

  T _handleResponse<T>(Response response) {
    if (response.statusCode != 200) {
      throw BilibiliApiException('HTTP ${response.statusCode}');
    }
    
    final data = response.data as Map<String, dynamic>;
    if (data['code'] != 0) {
      throw BilibiliApiException(
        data['message'] ?? 'Unknown error',
        code: data['code'],
      );
    }
    
    return data['data'] as T;
  }
}

class BilibiliApiException implements Exception {
  final String message;
  final int? code;
  BilibiliApiException(this.message, {this.code});
  
  @override
  String toString() => 'BilibiliApiException: $message (code: $code)';
}
```

#### 2. WBI 签名算法

**文件**: `lib/services/bilibili/wbi_signer.dart`

```dart
import 'dart:convert';
import 'package:crypto/crypto.dart';

class WbiSigner {
  // WBI 混淆表 (与 BBPlayer 完全一致)
  static const List<int> mixinKeyEncTab = [
    46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, 27, 43, 5, 49,
    33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13, 37, 48, 7, 16, 24, 55, 40, 61,
    26, 17, 0, 1, 60, 51, 30, 4, 22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11, 36,
    20, 34, 44, 52,
  ];

  String _getMixinKey(String imgKey, String subKey) {
    final orig = imgKey + subKey;
    final mixed = mixinKeyEncTab.map((n) => orig[n]).join('');
    return mixed.substring(0, 32);
  }

  String encodeWbi(Map<String, dynamic> params, String imgKey, String subKey) {
    final mixinKey = _getMixinKey(imgKey, subKey);
    final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    // 添加 wts 字段
    params['wts'] = currentTime;
    
    // 按 key 排序参数
    final sortedKeys = params.keys.toList()..sort();
    final query = sortedKeys.map((key) {
      final value = params[key].toString().replaceAll(RegExp(r"[!'()*]"), '');
      return '${Uri.encodeComponent(key)}=${Uri.encodeComponent(value)}';
    }).join('&');
    
    // 计算 MD5 签名
    final wbiSign = md5.convert(utf8.encode(query + mixinKey)).toString();
    
    return '$query&w_rid=$wbiSign';
  }
}
```


#### 3. Cookie 管理器

**文件**: `lib/services/bilibili/cookie_manager.dart`

```dart
import 'package:shared_preferences/shared_preferences.dart';

class CookieManager {
  static const String _cookieKey = 'bilibili_cookie';
  
  // 保存 Cookie
  Future<void> saveCookie(Map<String, String> cookieMap) async {
    final prefs = await SharedPreferences.getInstance();
    final cookieJson = jsonEncode(cookieMap);
    await prefs.setString(_cookieKey, cookieJson);
  }
  
  // 获取 Cookie Map
  Future<Map<String, String>> getCookieMap() async {
    final prefs = await SharedPreferences.getInstance();
    final cookieJson = prefs.getString(_cookieKey);
    if (cookieJson == null) return {};
    
    return Map<String, String>.from(jsonDecode(cookieJson));
  }
  
  // 获取 Cookie 字符串 (用于 HTTP Header)
  Future<String> getCookieString() async {
    final cookieMap = await getCookieMap();
    return cookieMap.entries
        .map((e) => '${e.key}=${e.value}')
        .join('; ');
  }
  
  // 清除 Cookie
  Future<void> clearCookie() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cookieKey);
  }
  
  // 检查是否已登录
  Future<bool> isLoggedIn() async {
    final cookieMap = await getCookieMap();
    return cookieMap.containsKey('SESSDATA') && 
           cookieMap.containsKey('bili_jct');
  }
}
```


#### 4. Bilibili API 服务

**文件**: `lib/services/bilibili/api_service.dart`

```dart
class BilibiliApiService {
  final BilibiliApiClient _client;
  final WbiSigner _wbiSigner;
  
  BilibiliApiService(this._client, this._wbiSigner);
  
  // 获取用户信息
  Future<BilibiliUser> getUserInfo() async {
    final data = await _client.get('/x/space/myinfo');
    return BilibiliUser.fromJson(data);
  }
  
  // 获取收藏夹列表
  Future<List<BilibiliFavorite>> getFavorites(int userMid) async {
    final data = await _client.get(
      '/x/v3/fav/folder/created/list-all',
      params: {'up_mid': userMid.toString()},
    );
    final list = data['list'] as List?;
    if (list == null) return [];
    return list.map((e) => BilibiliFavorite.fromJson(e)).toList();
  }
  
  // 获取音频流
  Future<BilibiliAudioStream> getAudioStream({
    required String bvid,
    required int cid,
    int quality = 30280, // 默认高音质
  }) async {
    final params = await _wbiSigner.encodeWbi({
      'bvid': bvid,
      'cid': cid.toString(),
      'fnval': '4048',
      'fnver': '0',
      'fourk': '1',
      'qlt': quality.toString(),
    });
    
    final data = await _client.get('/x/player/wbi/playurl', params: params);
    return BilibiliAudioStream.fromJson(data);
  }
  
  // 搜索视频
  Future<BilibiliSearchResult> searchVideos(String keyword, int page) async {
    final params = await _wbiSigner.encodeWbi({
      'keyword': keyword,
      'search_type': 'video',
      'page': page.toString(),
    });
    
    final data = await _client.get('/x/web-interface/wbi/search/type', params: params);
    return BilibiliSearchResult.fromJson(data);
  }
}
```


#### 5. 数据库扩展

**文件**: `lib/database/database.dart` (扩展现有文件)

```dart
// 新增 Bilibili 视频表
class BilibiliVideos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bvid => text().unique()();
  IntColumn get cid => integer()();
  TextColumn get title => text()();
  TextColumn get coverUrl => text().nullable()();
  IntColumn get duration => integer()(); // 秒
  TextColumn get author => text()();
  IntColumn get authorMid => integer()();
  DateTimeColumn get publishDate => dateTime()();
  TextColumn get description => text().nullable()();
  BoolColumn get isMultiPage => boolean().withDefault(const Constant(false))();
  IntColumn get pageCount => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Bilibili 收藏夹表
class BilibiliFavorites extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get remoteId => integer().unique()(); // Bilibili 收藏夹 ID
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get coverUrl => text().nullable()();
  IntColumn get mediaCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get syncedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// 音频流缓存表
class BilibiliStreamCache extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bvid => text()();
  IntColumn get cid => integer()();
  TextColumn get streamUrl => text()();
  IntColumn get quality => integer()(); // 音质 ID
  DateTimeColumn get expiresAt => dateTime()(); // 流地址过期时间
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  
  // 联合唯一索引
  @override
  List<Set<Column>> get uniqueKeys => [
    {bvid, cid, quality},
  ];
}

// 扩展现有 Songs 表以支持 Bilibili 源
// 在现有 Songs 类中添加以下字段：
class Songs extends Table {
  // ... 现有字段 ...
  
  // 新增字段
  TextColumn get source => text().withDefault(const Constant('local'))(); // 'local' | 'bilibili'
  TextColumn get bvid => text().nullable()();
  IntColumn get cid => integer().nullable()();
  IntColumn get pageNumber => integer().nullable()(); // 分P序号
  IntColumn get bilibiliVideoId => integer().nullable()
      .references(BilibiliVideos, #id, onDelete: KeyAction.setNull)();
}
```


#### 6. 播放器集成

**文件**: `lib/services/audio_player_service.dart` (扩展现有服务)

```dart
class AudioPlayerService extends BaseAudioHandler with SeekHandler {
  // ... 现有代码 ...
  
  final BilibiliApiService _bilibiliApi;
  final StreamCacheManager _streamCache;
  
  // 播放 Bilibili 音频
  Future<void> playBilibiliTrack(String bvid, int cid, {int quality = 30280}) async {
    try {
      // 1. 检查缓存的流地址
      String? streamUrl = await _streamCache.getCachedStreamUrl(bvid, cid, quality);
      
      // 2. 如果缓存不存在或已过期，重新获取
      if (streamUrl == null) {
        final stream = await _bilibiliApi.getAudioStream(
          bvid: bvid,
          cid: cid,
          quality: quality,
        );
        streamUrl = stream.url;
        
        // 缓存流地址（有效期 60 分钟）
        await _streamCache.cacheStreamUrl(
          bvid: bvid,
          cid: cid,
          quality: quality,
          url: streamUrl,
          expiresAt: DateTime.now().add(const Duration(minutes: 60)),
        );
      }
      
      // 3. 使用 media_kit 播放（需要设置 HTTP Headers）
      await player.open(
        Media(streamUrl,
          httpHeaders: {
            'Referer': 'https://www.bilibili.com',
            'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0_1 like Mac OS X) AppleWebKit/605.1.15',
            'Cookie': await _cookieManager.getCookieString(),
          }
        ),
      );
    } catch (e) {
      debugPrint('播放 Bilibili 音频失败: $e');
      rethrow;
    }
  }
  
  // 检查并刷新流地址（在播放前或定时检查）
  Future<void> refreshStreamIfNeeded(String bvid, int cid, int quality) async {
    final isExpired = await _streamCache.isStreamExpired(bvid, cid, quality);
    if (isExpired) {
      await playBilibiliTrack(bvid, cid, quality: quality);
    }
  }
}
```


---

## 实施计划

### Phase 1: 基础设施搭建 (预计 1-2 周)

#### 目标
建立 Bilibili API 通信基础和核心算法

#### 任务清单

**1.1 创建项目结构**
- [ ] 创建 `lib/services/bilibili/` 目录
- [ ] 创建 `lib/models/bilibili/` 目录
- [ ] 创建 `lib/utils/bilibili_utils.dart`

**1.2 添加依赖包**

在 `pubspec.yaml` 中添加:
```yaml
dependencies:
  dio: ^5.4.0              # HTTP 客户端
  crypto: ^3.0.3           # MD5 签名
  json_annotation: ^4.8.1  # JSON 序列化

dev_dependencies:
  json_serializable: ^6.7.1
  build_runner: ^2.4.8
```

**1.3 实现核心模块**
- [ ] 实现 `BilibiliApiClient` (HTTP 客户端)
- [ ] 实现 `WbiSigner` (WBI 签名算法)
- [ ] 实现 `CookieManager` (Cookie 管理)
- [ ] 实现 BV/AV 号转换工具函数
- [ ] 编写单元测试验证算法正确性

**1.4 实现基础 API**
- [ ] 用户信息获取 (`getUserInfo`)
- [ ] 收藏夹列表 (`getFavoritePlaylists`)
- [ ] 视频详情 (`getVideoDetails`)

**验收标准**
- ✅ 成功调用 Bilibili API 获取数据
- ✅ WBI 签名算法通过测试
- ✅ Cookie 能正确存储和读取


### Phase 2: 数据层扩展 (预计 1 周)

#### 目标
扩展数据库以支持 Bilibili 数据存储

#### 任务清单

**2.1 数据库迁移**
- [ ] 在 `database.dart` 中添加新表定义
  - `BilibiliVideos`
  - `BilibiliFavorites`
  - `BilibiliStreamCache`
- [ ] 扩展 `Songs` 表添加 Bilibili 相关字段
- [ ] 更新 schema version 并编写迁移脚本
- [ ] 运行 `flutter pub run build_runner build`

**2.2 数据模型**
- [ ] 创建 `BilibiliVideo` 模型类 (`lib/models/bilibili/video.dart`)
- [ ] 创建 `BilibiliFavorite` 模型类
- [ ] 创建 `BilibiliAudioStream` 模型类
- [ ] 使用 `json_serializable` 生成序列化代码

**2.3 数据访问层**
- [ ] 实现 Bilibili 视频 CRUD 操作
- [ ] 实现收藏夹同步逻辑
- [ ] 实现流缓存管理 (`StreamCacheManager`)

**验收标准**
- ✅ 数据库成功迁移，无数据丢失
- ✅ 能够存储和查询 Bilibili 视频信息
- ✅ 流地址缓存机制正常工作

---

### Phase 3: 播放器集成 (预计 1 周)

#### 目标
让播放器支持播放 Bilibili 音频

#### 任务清单

**3.1 音频流获取**
- [ ] 实现 `getAudioStream` API
- [ ] 支持多音质选择 (普通/Hi-Res/Dolby)
- [ ] 实现流地址缓存和过期检查

**3.2 播放器扩展**
- [ ] 在 `AudioPlayerService` 中添加 `playBilibiliTrack` 方法
- [ ] 配置 media_kit 的 HTTP Headers (Referer, Cookie)
- [ ] 实现流地址自动刷新机制
- [ ] 处理播放错误和重试逻辑

**3.3 播放队列管理**
- [ ] 支持混合本地和 Bilibili 音乐播放
- [ ] 实现播放历史记录
- [ ] 支持播放进度保存

**验收标准**
- ✅ 成功播放 Bilibili 音频
- ✅ 音质切换正常
- ✅ 流地址过期时能自动刷新


### Phase 4: UI 功能实现 (预计 2-3 周)

#### 目标
实现用户界面和交互功能

#### 任务清单

**4.1 登录功能**
- [ ] 创建 `BilibiliLoginPage` (二维码登录)
- [ ] 实现 `QrCodeLoginDialog` 组件
- [ ] 实现 Cookie 手动输入功能
- [ ] 添加登录状态检测和显示

**4.2 内容浏览**
- [ ] 创建 `BilibiliFavoritesPage` (收藏夹列表页)
- [ ] 创建 `FavoriteCard` 组件
- [ ] 创建 `BilibiliPlaylistDetailPage` (收藏夹详情)
- [ ] 创建 `VideoCard` 组件
- [ ] 实现分页加载和下拉刷新

**4.3 搜索功能**
- [ ] 创建 `BilibiliSearchPage`
- [ ] 实现搜索建议和热门搜索
- [ ] 实现搜索历史记录
- [ ] 支持收藏夹内搜索

**4.4 播放控制**
- [ ] 在播放控制面板添加音质选择
- [ ] 显示 Bilibili 视频封面和信息
- [ ] 支持多P视频选集切换
- [ ] 添加 "在 Bilibili 打开" 功能

**4.5 导航集成**
- [ ] 在侧边栏/底部导航添加 "Bilibili" 入口
- [ ] 在设置页面添加 Bilibili 账号管理
- [ ] 添加 Bilibili 功能开关

**验收标准**
- ✅ 用户能够成功登录
- ✅ 能够浏览和播放收藏夹内容
- ✅ 搜索功能正常
- ✅ UI 适配桌面端和移动端

---

### Phase 5: 高级功能 (预计 1-2 周，可选)

#### 目标
实现增强功能和优化

#### 任务清单

**5.1 下载管理**
- [ ] 创建 `BilibiliDownloadService`
- [ ] 实现音频下载功能
- [ ] 支持批量下载
- [ ] 显示下载进度
- [ ] 支持断点续传

**5.2 歌词匹配**
- [ ] 实现网易云音乐 API 集成
- [ ] 自动匹配歌词
- [ ] 支持手动搜索和编辑歌词
- [ ] 实现歌词偏移调整

**5.3 播放历史同步**
- [ ] 实现播放进度上报到 Bilibili
- [ ] 同步观看历史
- [ ] 实现稍后再看功能

**5.4 性能优化**
- [ ] 实现图片缓存 (`cached_network_image`)
- [ ] 优化列表加载性能
- [ ] 减少网络请求次数
- [ ] 添加加载动画和骨架屏

**验收标准**
- ✅ 下载功能稳定可用
- ✅ 歌词匹配准确率高
- ✅ 应用流畅，无明显卡顿


---

## 技术难点与解决方案

### 难点 1: WBI 签名算法

**问题描述**:
Bilibili 实施了 WBI (Web Browser Interface) 签名机制作为反爬虫手段。所有需要登录权限的 API 都需要进行 WBI 签名。

**技术细节**:
1. 需要获取 `img_key` 和 `sub_key` (从导航接口获取)
2. 使用特定的混淆表对 key 进行编码
3. 将请求参数按字母顺序排序后与混淆 key 拼接
4. 计算 MD5 值作为 `w_rid` 参数

**解决方案**:
```dart
// 1. 获取 WBI keys (需要定期刷新)
class WbiKeyManager {
  String? _imgKey;
  String? _subKey;
  DateTime? _lastUpdate;
  
  Future<void> refreshKeys() async {
    final nav = await _client.get('/x/web-interface/nav');
    _imgKey = extractImgKey(nav['wbi_img']['img_url']);
    _subKey = extractSubKey(nav['wbi_img']['sub_url']);
    _lastUpdate = DateTime.now();
  }
  
  bool get needsRefresh =>
      _imgKey == null || 
      _subKey == null || 
      DateTime.now().difference(_lastUpdate!) > const Duration(hours: 24);
}

// 2. 使用 WBI 签名
final signer = WbiSigner();
if (keyManager.needsRefresh) {
  await keyManager.refreshKeys();
}
final signedParams = signer.encodeWbi(
  params, 
  keyManager.imgKey, 
  keyManager.subKey
);
```

**风险**: Bilibili 可能更新签名算法，需要持续关注并更新。


### 难点 2: 音频流地址过期问题

**问题描述**:
Bilibili 返回的音频流 URL 有效期约为 60 分钟。超时后需要重新获取。

**影响**:
- 长时间播放时流地址可能过期
- 用户暂停后恢复播放可能失败
- 播放队列中的歌曲流地址可能失效

**解决方案**:

**方案 1: 被动刷新 (推荐)**
```dart
class StreamCacheManager {
  // 在数据库中记录过期时间
  Future<String?> getCachedStreamUrl(String bvid, int cid, int quality) async {
    final cache = await db.query(
      'bilibili_stream_cache',
      where: 'bvid = ? AND cid = ? AND quality = ?',
      whereArgs: [bvid, cid, quality],
    );
    
    if (cache.isEmpty) return null;
    
    final expiresAt = DateTime.parse(cache.first['expiresAt']);
    
    // 提前 5 分钟判定为过期（安全边界）
    if (DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 5)))) {
      return null; // 视为过期
    }
    
    return cache.first['streamUrl'];
  }
}

// 播放前检查
Future<void> playBilibiliTrack(String bvid, int cid) async {
  String? url = await streamCache.getCachedStreamUrl(bvid, cid, quality);
  
  if (url == null) {
    // 重新获取
    final stream = await bilibiliApi.getAudioStream(bvid: bvid, cid: cid);
    url = stream.url;
    await streamCache.cacheStreamUrl(/* ... */);
  }
  
  await player.open(Media(url, httpHeaders: {...}));
}
```

**方案 2: 主动刷新 (可选)**
```dart
// 使用 Timer 定时检查即将过期的流地址
Timer.periodic(const Duration(minutes: 10), (timer) async {
  final expiringSoon = await db.query(
    'bilibili_stream_cache',
    where: 'expiresAt < ?',
    whereArgs: [DateTime.now().add(const Duration(minutes: 15)).toIso8601String()],
  );
  
  for (final cache in expiringSoon) {
    // 后台刷新流地址
    await refreshStreamUrl(cache['bvid'], cache['cid'], cache['quality']);
  }
});
```


### 难点 3: Cookie 管理与持久化

**问题描述**:
- Cookie 需要安全存储
- 需要在每个请求中自动注入
- Cookie 可能过期，需要检测并提示重新登录

**解决方案**:

**1. 安全存储**
```dart
// 使用 flutter_secure_storage 存储敏感 Cookie (可选)
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureCookieManager extends CookieManager {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  @override
  Future<void> saveCookie(Map<String, String> cookieMap) async {
    final cookieJson = jsonEncode(cookieMap);
    await _storage.write(key: 'bilibili_cookie', value: cookieJson);
  }
  
  @override
  Future<Map<String, String>> getCookieMap() async {
    final cookieJson = await _storage.read(key: 'bilibili_cookie');
    if (cookieJson == null) return {};
    return Map<String, String>.from(jsonDecode(cookieJson));
  }
}
```

**2. Cookie 过期检测**
```dart
class CookieValidator {
  // 检查 Cookie 是否有效
  static Future<bool> validateCookie(BilibiliApiClient client) async {
    try {
      await client.get('/x/space/myinfo');
      return true;
    } on BilibiliApiException catch (e) {
      // -101: 账号未登录
      if (e.code == -101) return false;
      rethrow;
    }
  }
}

// 在应用启动时检查
if (await cookieManager.isLoggedIn()) {
  final isValid = await CookieValidator.validateCookie(apiClient);
  if (!isValid) {
    // 提示用户重新登录
    showLoginDialog();
  }
}
```

**3. 自动注入机制**
已在 `BilibiliApiClient` 的拦截器中实现。


### 难点 4: 跨平台 HTTP Headers 设置

**问题描述**:
media_kit 在不同平台上设置 HTTP Headers 的方式可能不同，特别是 Referer 和 Cookie。

**解决方案**:

**1. 验证 media_kit 支持**
```dart
// 测试代码
final player = Player();
await player.open(
  Media('https://example.com/audio.m4s',
    httpHeaders: {
      'Referer': 'https://www.bilibili.com',
      'User-Agent': 'Mozilla/5.0...',
      'Cookie': 'SESSDATA=xxx;',
    }
  ),
);
```

**2. 平台特定处理**
```dart
class PlatformAudioPlayer {
  Future<void> playWithHeaders(String url, Map<String, String> headers) async {
    if (Platform.isAndroid || Platform.isIOS) {
      // 移动端：直接使用 media_kit
      await player.open(Media(url, httpHeaders: headers));
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // 桌面端：可能需要特殊处理
      await player.open(Media(url, httpHeaders: headers));
    }
  }
}
```

**3. Fallback 方案**
如果 media_kit 不支持自定义 Headers:
- 考虑使用本地代理服务器
- 或使用 `dio` 下载后播放本地文件


### 难点 5: TypeScript 到 Dart 的类型转换

**问题描述**:
BBPlayer 大量使用 TypeScript 的高级特性，需要正确映射到 Dart。

**类型对比表**:

| TypeScript | Dart | 备注 |
|------------|------|------|
| `Promise<T>` | `Future<T>` | 异步操作 |
| `T \| null` | `T?` | 可空类型 |
| `Result<T, E>` (neverthrow) | `Either<L, R>` (dartz) 或自定义 | 错误处理 |
| `type` | `typedef` 或 `class` | 类型别名 |
| `interface` | `abstract class` | 接口定义 |
| `enum` | `enum` | 枚举 |
| `Record<K, V>` | `Map<K, V>` | 键值对 |

**示例转换**:

```typescript
// TypeScript (BBPlayer)
interface BilibiliUser {
  mid: number
  name: string
  face?: string
}

type Result<T, E> = Ok<T> | Err<E>
```

```dart
// Dart (LZF-Music)
class BilibiliUser {
  final int mid;
  final String name;
  final String? face;
  
  BilibiliUser({
    required this.mid,
    required this.name,
    this.face,
  });
  
  factory BilibiliUser.fromJson(Map<String, dynamic> json) => BilibiliUser(
    mid: json['mid'] as int,
    name: json['name'] as String,
    face: json['face'] as String?,
  );
}

// 使用 dartz 或自定义 Result 类型
class Result<T, E> {
  final T? value;
  final E? error;
  
  bool get isOk => error == null;
  bool get isErr => error != null;
  
  Result.ok(T value) : value = value, error = null;
  Result.err(E error) : value = null, error = error;
}
```

---

## 风险评估

### 技术风险

| 风险项 | 可能性 | 影响 | 缓解措施 |
|--------|--------|------|---------|
| Bilibili API 变更 | 高 | 高 | 1. 监控 API 变化 2. 实现版本兼容层 3. 保持与社区同步 |
| WBI 签名算法更新 | 中 | 高 | 1. 关注 BBPlayer 更新 2. 快速响应算法变更 |
| media_kit Headers 支持不完善 | 低 | 中 | 1. 提前测试验证 2. 准备降级方案 |
| 跨平台兼容性问题 | 中 | 中 | 1. 多平台测试 2. 条件编译处理差异 |
| Cookie 过期导致播放失败 | 高 | 中 | 1. 实现自动检测 2. 友好的重新登录提示 |


### 合规风险

| 风险项 | 可能性 | 影响 | 缓解措施 |
|--------|--------|------|---------|
| 违反 Bilibili 服务条款 | 中 | 高 | 1. 严格遵守 API 调用频率限制 2. 不进行批量爬取 3. 仅用于个人使用 |
| 版权问题 | 低 | 高 | 1. 仅提供播放功能，不提供下载（或仅离线缓存） 2. 明确版权声明 |
| 用户隐私保护 | 低 | 中 | 1. 本地存储 Cookie 2. 不上传用户数据 3. 提供隐私政策 |

**法律免责声明**:
```
本应用仅供学习和个人使用。用户应遵守 Bilibili 服务条款。
开发者不对用户的任何不当使用行为负责。
所有音频内容版权归 Bilibili 及原作者所有。
```

---

## 后续维护

### 监控机制

**1. API 健康监控**
```dart
class BilibiliApiMonitor {
  // 定期测试关键 API
  Future<bool> checkApiHealth() async {
    try {
      await bilibiliApi.getUserInfo();
      return true;
    } catch (e) {
      // 记录错误，通知维护者
      logger.error('Bilibili API 异常: $e');
      return false;
    }
  }
}
```

**2. 版本更新检测**
- 关注 BBPlayer GitHub 仓库的更新
- 订阅 Bilibili 开发者社区公告
- 监控用户反馈的 API 错误

### 维护清单

**定期任务** (建议每月一次):
- [ ] 检查 WBI 签名算法是否有变化
- [ ] 验证关键 API 是否正常工作
- [ ] 检查依赖包更新 (`dio`, `drift`, `media_kit`)
- [ ] 审查用户反馈的 Bug
- [ ] 更新测试用例

**紧急响应** (当 API 失效时):
1. 快速定位问题 (WBI 算法变更? API 端点变更?)
2. 查看 BBPlayer 是否已修复
3. 应用修复并发布热更新
4. 通知用户临时解决方案


### 依赖更新策略

**Flutter/Dart 生态**:
```yaml
# 定期检查更新
flutter pub outdated

# 主要依赖包
dio: ^5.4.0              # HTTP 客户端 (保持最新)
drift: ^2.28.0           # 数据库 (跟随稳定版)
media_kit: ^1.1.11       # 播放器 (谨慎更新，测试兼容性)
provider: ^6.1.5         # 状态管理 (稳定)
```

**版本控制建议**:
- 锁定主版本号，小版本可以更新
- 更新前在测试分支验证
- 保持与 Flutter SDK 版本兼容

---

## 优先级与时间规划

### 功能优先级矩阵

| 功能 | 用户价值 | 实现难度 | 优先级 | 预计工时 |
|------|---------|---------|--------|---------|
| 基础 API 客户端 | 🔴 必须 | 中 | P0 | 3 天 |
| WBI 签名 | 🔴 必须 | 中 | P0 | 2 天 |
| Cookie 管理 | 🔴 必须 | 低 | P0 | 1 天 |
| 音频流获取 | 🔴 必须 | 中 | P0 | 2 天 |
| 播放器集成 | 🔴 必须 | 中 | P0 | 3 天 |
| 二维码登录 | 🟡 重要 | 中 | P1 | 2 天 |
| 收藏夹浏览 | 🟡 重要 | 低 | P1 | 3 天 |
| 搜索功能 | 🟡 重要 | 中 | P1 | 3 天 |
| 下载管理 | 🟢 可选 | 高 | P2 | 4 天 |
| 歌词匹配 | 🟢 可选 | 中 | P2 | 3 天 |
| 播放历史同步 | 🟢 可选 | 低 | P3 | 2 天 |

### 推荐实施顺序

**第 1-2 周: MVP (Minimum Viable Product)**
- ✅ API 客户端、WBI 签名、Cookie 管理
- ✅ 基础数据库扩展
- ✅ 音频流获取和播放
- **目标**: 能够播放 Bilibili 音频

**第 3 周: 用户认证**
- ✅ 二维码登录 UI
- ✅ Cookie 手动导入
- ✅ 登录状态管理
- **目标**: 用户能够登录账号

**第 4-5 周: 内容浏览**
- ✅ 收藏夹列表和详情页
- ✅ 视频卡片组件
- ✅ 分页加载
- **目标**: 浏览和播放收藏夹

**第 6 周: 搜索功能**
- ✅ 搜索页面
- ✅ 搜索建议
- ✅ 收藏夹内搜索
- **目标**: 快速找到想听的内容

**第 7-8 周: 高级功能 (可选)**
- ✅ 下载管理
- ✅ 歌词匹配
- ✅ 性能优化
- **目标**: 提升用户体验


---

## 测试策略

### 单元测试

**测试覆盖目标: 70%+**

```dart
// 示例: WBI 签名算法测试
void main() {
  group('WbiSigner Tests', () {
    final signer = WbiSigner();
    
    test('should encode params correctly', () {
      final params = {'keyword': '测试', 'page': '1'};
      final result = signer.encodeWbi(
        params,
        'test_img_key_1234567890123456',
        'test_sub_key_1234567890123456',
      );
      
      expect(result, contains('w_rid='));
      expect(result, contains('wts='));
    });
    
    test('should handle special characters', () {
      final params = {'keyword': "test!'()*"};
      final result = signer.encodeWbi(params, 'img', 'sub');
      
      // 特殊字符应被过滤
      expect(result, isNot(contains("'")));
      expect(result, isNot(contains('(')));
    });
  });
}
```

**需要测试的模块**:
- [ ] WBI 签名算法
- [ ] BV/AV 转换
- [ ] Cookie 管理
- [ ] 数据库操作
- [ ] 数据模型序列化

### 集成测试

```dart
void main() {
  testWidgets('Bilibili login flow test', (tester) async {
    await tester.pumpWidget(MyApp());
    
    // 1. 打开登录页
    await tester.tap(find.byIcon(Icons.login));
    await tester.pumpAndSettle();
    
    // 2. 显示二维码
    expect(find.byType(QrCodeLoginDialog), findsOneWidget);
    
    // 3. 模拟登录成功
    // ...
  });
}
```

### 平台测试矩阵

| 平台 | 优先级 | 测试内容 |
|------|--------|---------|
| Windows | P0 | 完整功能测试 |
| Android | P0 | 完整功能测试 |
| Linux | P1 | 核心功能测试 |
| macOS | P1 | 核心功能测试 |
| iOS | P2 | 基础功能验证 |


---

## 性能优化建议

### 网络优化

1. **请求缓存**
```dart
// 使用 dio_cache_interceptor 缓存 API 响应
final cacheOptions = CacheOptions(
  store: MemCacheStore(),
  maxStale: const Duration(hours: 1),
  policy: CachePolicy.request,
);

_dio.interceptors.add(DioCacheInterceptor(options: cacheOptions));
```

2. **图片缓存**
```dart
// 使用 cached_network_image
CachedNetworkImage(
  imageUrl: coverUrl,
  placeholder: (context, url) => const ShimmerPlaceholder(),
  errorWidget: (context, url, error) => const Icon(Icons.error),
  cacheManager: BilibiliCacheManager(),
)
```

3. **并发请求控制**
```dart
// 限制并发数，避免触发 API 限流
final limit = pLimit(3); // 最多 3 个并发请求

final results = await Future.wait(
  items.map((item) => limit(() => fetchData(item))),
);
```

### 数据库优化

1. **索引优化**
```dart
// 为常用查询字段添加索引
class BilibiliVideos extends Table {
  // ...
  @override
  List<Index> get indexes => [
    Index('bvid_cid_idx', columns: [bvid, cid]),
  ];
}
```

2. **批量操作**
```dart
// 使用事务批量插入
await db.transaction(() async {
  await db.batch((batch) {
    for (final video in videos) {
      batch.insert(bilibiliVideos, video);
    }
  });
});
```

### UI 优化

1. **列表性能**
```dart
// 使用 ListView.builder 懒加载
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return VideoCard(video: items[index]);
  },
);
```

2. **骨架屏**
```dart
// 加载时显示骨架屏而非空白
Shimmer.fromColors(
  baseColor: Colors.grey[300]!,
  highlightColor: Colors.grey[100]!,
  child: VideoCardSkeleton(),
)
```


---

## 总结与建议

### 关键成功因素

1. **✅ 算法准确性**: WBI 签名必须与 BBPlayer 保持一致
2. **✅ 稳定性**: 妥善处理网络异常和 API 变更
3. **✅ 用户体验**: 流畅的 UI 和清晰的错误提示
4. **✅ 维护性**: 代码结构清晰，便于后续更新
5. **✅ 合规性**: 遵守 Bilibili 服务条款

### 推荐开发流程

```
1. 搭建开发环境 (1 天)
   ↓
2. 实现并测试 API 客户端 (3-5 天)
   ↓
3. 验证播放器集成 (2-3 天)
   ↓
4. 开发基础 UI (5-7 天)
   ↓
5. 完整功能测试 (3-5 天)
   ↓
6. 性能优化和 Bug 修复 (3-5 天)
   ↓
7. 发布测试版本 (1 天)
```

**总预计开发时间: 6-8 周**

### 后续扩展方向

**短期 (3 个月内)**:
- [ ] 支持更多 Bilibili 功能 (合集、稍后再看)
- [ ] 实现离线下载
- [ ] 优化搜索体验

**中期 (6 个月内)**:
- [ ] 支持其他音乐平台 (网易云音乐、QQ音乐)
- [ ] 云端同步播放列表
- [ ] 社交分享功能

**长期 (1 年内)**:
- [ ] 桌面端 Widget/小组件
- [ ] 智能推荐算法
- [ ] 跨设备播放同步


---

## 参考资源

### 官方文档

- **Flutter**: https://flutter.dev/docs
- **Drift**: https://drift.simonbinder.eu/docs/
- **media_kit**: https://pub.dev/packages/media_kit
- **Dio**: https://pub.dev/packages/dio

### Bilibili 相关

- **BBPlayer GitHub**: https://github.com/yanyao2333/BBPlayer
- **Bilibili API 文档** (非官方): https://socialsisteryi.github.io/bilibili-API-collect/
- **WBI 签名说明**: https://github.com/SocialSisterYi/bilibili-API-collect/blob/master/docs/misc/sign/wbi.md

### 技术文章

- **Flutter 状态管理**: https://flutter.dev/docs/development/data-and-backend/state-mgmt
- **Drift 数据库迁移**: https://drift.simonbinder.eu/docs/advanced-features/migrations/
- **Flutter 跨平台开发**: https://flutter.dev/multi-platform

### 开源项目参考

1. **BBPlayer**: React Native 实现，本项目的主要参考
2. **AzusaPlayer**: https://github.com/lovegaoshi/azusa-player-mobile
3. **BiliSound**: https://github.com/bilisound/client-mobile

---

## 附录

### 附录 A: API 端点清单

**需要实现的主要 API**:

| 端点 | 用途 | 优先级 | 需要 WBI |
|------|------|--------|---------|
| `/x/space/myinfo` | 获取用户信息 | P0 | 否 |
| `/x/v3/fav/folder/created/list-all` | 收藏夹列表 | P0 | 否 |
| `/x/player/wbi/playurl` | 音频流地址 | P0 | 是 |
| `/x/player/pagelist` | 视频分P列表 | P0 | 否 |
| `/x/web-interface/view` | 视频详情 | P0 | 否 |
| `/x/web-interface/wbi/search/type` | 搜索视频 | P1 | 是 |
| `/x/v3/fav/resource/list` | 收藏夹内容 | P1 | 否 |
| `/x/space/wbi/arc/search` | UP主视频 | P1 | 是 |
| `/x/v3/fav/folder/collected/list` | 追更合集 | P1 | 否 |
| `/x/space/fav/season/list` | 合集详情 | P1 | 否 |
| `/x/passport-login/web/qrcode/generate` | 二维码登录 | P1 | 否 |
| `/x/v2/history` | 播放历史 | P2 | 否 |
| `/x/v2/history/report` | 上报历史 | P2 | 否 |


### 附录 B: 依赖包完整清单

```yaml
# pubspec.yaml

dependencies:
  flutter:
    sdk: flutter
  
  # 现有依赖 (保持)
  path: ^1.9.1
  file_picker: ^10.2.0
  drift: ^2.28.0
  sqlite3_flutter_libs: ^0.5.0
  audio_metadata_reader:
    git:
      url: https://github.com/GerryDush/audio_metadata_reader.git
      ref: v0.0.3
  path_provider: ^2.1.2
  provider: ^6.1.5
  media_kit: ^1.1.11
  media_kit_libs_audio: ^1.0.7
  window_manager: ^0.5.1
  shared_preferences: ^2.5.3
  url_launcher: ^6.3.2
  bitsdojo_window: ^0.1.6
  webdav_client: ^1.2.2
  audio_service: ^0.18.18
  audio_service_win:
     git:
      url: https://github.com/GerryDush/audio_service_win.git
      ref: main
  tray_manager: ^0.5.1
  crypto: ^3.0.0
  flutter_colorpicker: ^1.1.0
  flutter_acrylic: ^1.1.4

  # 新增 Bilibili 相关依赖
  dio: ^5.4.0                          # HTTP 客户端
  json_annotation: ^4.8.1              # JSON 序列化
  cached_network_image: ^3.3.0         # 图片缓存
  qr_flutter: ^4.1.0                   # 二维码生成
  flutter_secure_storage: ^9.0.0      # 安全存储 (可选)
  shimmer: ^3.0.0                      # 骨架屏动画
  
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  drift_dev: ^2.14.1
  build_runner: ^2.4.8
  json_serializable: ^6.7.1           # JSON 序列化代码生成
  mockito: ^5.4.4                      # 单元测试 Mock
```


### 附录 C: 常见问题 FAQ

**Q1: 为什么不使用 WebView 嵌入 BBPlayer？**  
A: WebView 会增加应用体积，性能较差，且无法与原生播放器深度集成。完全重写虽然工作量大，但能保证最佳的用户体验和性能。

**Q2: WBI 签名算法会经常变吗？**  
A: 根据社区经验，WBI 算法相对稳定，但 Bilibili 有权随时修改。建议关注 BBPlayer 的更新和社区讨论。

**Q3: 能否支持视频播放而非仅音频？**  
A: 技术上可行，但需要额外的视频解码和界面工作。当前计划聚焦音频播放，视频支持可作为未来扩展。

**Q4: 下载的音频是什么格式？**  
A: Bilibili 音频流通常为 M4S 格式 (DASH)，需要使用支持该格式的播放器。

**Q5: 如何处理版权问题？**  
A: 应用仅作为 Bilibili 的第三方客户端，不存储或分发受版权保护的内容。所有内容均从 Bilibili 官方服务器获取。用户需遵守 Bilibili 服务条款。

**Q6: Cookie 会过期吗？**  
A: 是的，Cookie 有效期通常为几个月。过期后需要重新登录。应用会检测 Cookie 失效并提示用户。

**Q7: 能否在没有登录的情况下使用？**  
A: 部分功能（如搜索、查看公开视频）可能无需登录，但收藏夹、历史记录等功能需要登录。

**Q8: 支持多账号切换吗？**  
A: 当前计划不支持多账号，但可以作为未来功能扩展。

---

### 附录 D: 变更记录

| 版本 | 日期 | 变更内容 | 作者 |
|------|------|---------|------|
| v1.0 | 2025-11-06 | 初始版本，完整迁移计划 | Claude |

---

## 结语

本文档提供了将 BBPlayer 的 Bilibili 功能迁移到 LZF-Music 的完整技术方案。通过分阶段实施，可以在保持现有功能稳定的前提下，逐步集成 Bilibili 音频播放能力。

关键要点：
1. **技术可行**: Flutter 生态提供了所有必需的工具和库
2. **架构清晰**: 分层设计，便于维护和扩展
3. **风险可控**: 识别了主要技术难点并提供解决方案
4. **时间合理**: 6-8 周可完成核心功能

**下一步行动**：
- [ ] 评审本方案，确认技术路线
- [ ] 准备开发环境
- [ ] 开始 Phase 1 实施

祝项目顺利！🚀

---

*文档结束*
