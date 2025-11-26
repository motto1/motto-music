# 通知栏音乐控制功能增强实施计划（Android 平台）

## 目标描述

为 LZF-Music 的 **Android 平台**添加增强的通知栏控制功能，在现有的基础播放控制（播放/暂停、上一曲/下一曲）之上，增加以下自定义功能：

1. **喜欢/取消喜欢**按钮 - 快速标记当前播放歌曲为喜欢，动态更新图标
2. **展开歌词**按钮 - 在通知栏扩展视图中显示当前播放歌曲的实时歌词

项目已集成 `audio_service` (v0.18.18)，具备基础的通知栏控制框架。本次改动将：
- 利用 `audio_service` 的自定义 `MediaControl` 和 `MediaAction` 实现喜欢按钮
- 使用 Android 原生的 `MediaStyle` 扩展通知（Big Content View）显示歌词

## 技术方案

### 1. 喜欢按钮实现

**核心技术**：
- 使用 `audio_service` 的自定义 `MediaControl` 和 `MediaAction`
- 动态图标切换：根据 `Song.isFavorite` 状态显示 `favorite`（实心❤️）或 `favorite_border`（空心❤️）

**实现步骤**：
1. 在 `AudioPlayerService` 中添加 `onToggleFavorite` 回调
2. 在 `_createPlaybackState()` 中添加喜欢按钮的 `MediaControl`
3. 重写 `onCustomAction()` 处理 `toggleFavorite` action
4. 在 `PlayerProvider` 中实现喜欢逻辑，更新数据库和通知栏

### 2. 歌词显示实现

**核心挑战**：
`audio_service` 本身不支持自定义通知布局，需要通过平台通道（Platform Channel）调用 Android 原生代码。

**技术方案**：
- 使用 `MethodChannel` 与 Android 原生代码通信
- 在 Android 端使用 `NotificationCompat.Builder` 创建自定义通知布局
- 使用 `RemoteViews` 或 `MediaStyle.setBigContentView()` 显示歌词文本
- 监听歌词数据变化，实时更新通知内容

**实现步骤**：
1. 创建 `MethodChannel`（`lzf_music/notification_lyrics`）
2. 在 Kotlin 中实现自定义通知管理器
3. 在 Flutter 端通过 MethodChannel 发送歌词数据
4. Android 端更新通知的扩展视图


## 拟议变更

### Flutter 层 - 音频服务

#### [MODIFY] [audio_player_service.dart](file:///f:/bilibili_player/LZF-Music/lib/services/audio_player_service.dart)

**变更内容**：

1. **新增回调字段**
   ```dart
   Function()? onToggleFavorite;
   ```

2. **新增当前歌曲字段**
   ```dart
   Song? _currentSong;
   ```

3. **更新 `setCallbacks()` 方法**
   - 添加 `onToggleFavorite` 参数

4. **增强 `_createPlaybackState()` 方法**
   - 在 `controls` 列表中添加喜欢按钮
   - 按钮顺序：`[上一曲, 喜欢, 播放/暂停, 下一曲]`（4个按钮，Android 最多显示5个）
   - 喜欢按钮根据 `_currentSong?.isFavorite` 动态切换图标

5. **更新 `updateCurrentMediaItem()` 方法**
   - 保存 `_currentSong = song` 用于状态判断

6. **实现 `onCustomAction()` 方法**
   - 处理 `'toggleFavorite'` action，调用 `onToggleFavorite?.call()`

---

### Flutter 层 - 播放器逻辑

#### [MODIFY] [player_provider.dart](file:///f:/bilibili_player/LZF-Music/lib/services/player_provider.dart)

**变更内容**：

1. **在 `_setupAudioServiceCallbacks()` 中注册回调**
   ```dart
   _audioPlayerService.setCallbacks(
     // ... 现有回调 ...
     onToggleFavorite: _handleToggleFavorite,
   );
   ```

2. **实现 `_handleToggleFavorite()` 方法**
   - 获取当前歌曲
   - 切换 `isFavorite` 状态
   - 更新数据库：`MusicDatabase.database.updateSong(updatedSong)`
   - 更新播放器状态：`updateCurrentSong(updatedSong)`
   - 刷新通知栏：`_audioPlayerService.updateCurrentMediaItem(updatedSong)`

3. **新增歌词通道字段**
   ```dart
   static const MethodChannel _lyricsChannel = MethodChannel('lzf_music/notification_lyrics');
   ```

4. **在 `loadLyrics()` 中同步歌词到通知栏**
   - 加载歌词成功后，调用 `_updateNotificationLyrics(parsedLrc)`
   
5. **实现 `_updateNotificationLyrics()` 方法**
   - 监听 `positionStream`，根据时间戳匹配当前歌词行
   - 通过 `_lyricsChannel.invokeMethod('updateLyrics', {'currentLine': line})` 发送到 Android

---

### Flutter 层 - 平台通道

#### [NEW] [lyrics_notification_channel.dart](file:///f:/bilibili_player/LZF-Music/lib/services/lyrics_notification_channel.dart)

**新建文件**，封装歌词通知的平台通道逻辑：

- `LyricsNotificationChannel` 类
- `updateLyrics(String currentLine, String? nextLine)` 方法
- `clearLyrics()` 方法

---

### Android 层 - 原生代码

#### [MODIFY] [MainActivity.kt](file:///f:/bilibili_player/LZF-Music/android/app/src/main/kotlin/...)

**变更内容**：

1. **配置 MethodChannel**
   ```kotlin
   private val LYRICS_CHANNEL = "lzf_music/notification_lyrics"
   private lateinit var lyricsChannel: MethodChannel
   ```

2. **在 `configureFlutterEngine()` 中注册 MethodChannel**
   ```kotlin
   lyricsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LYRICS_CHANNEL)
   lyricsChannel.setMethodCallHandler { call, result ->
       when (call.method) {
           "updateLyrics" -> {
               val currentLine = call.argument<String>("currentLine")
               NotificationLyricsManager.updateLyrics(this, currentLine)
               result.success(null)
           }
           "clearLyrics" -> {
               NotificationLyricsManager.clearLyrics(this)
               result.success(null)
           }
           else -> result.notImplemented()
       }
   }
   ```

---

#### [NEW] [NotificationLyricsManager.kt](file:///f:/bilibili_player/LZF-Music/android/app/src/main/kotlin/.../NotificationLyricsManager.kt)

**新建文件**，管理通知栏歌词显示：

**核心功能**：
1. **拦截 audio_service 的通知**
   - 通过 `NotificationListenerService` 监听通知
   - 或直接修改 `audio_service` 插件生成的通知（推荐）

2. **创建扩展视图**
   ```kotlin
   fun updateNotification(context: Context, mediaMetadata: MediaMetadataCompat, currentLine: String?) {
       val builder = NotificationCompat.Builder(context, CHANNEL_ID)
           .setStyle(androidx.media.app.NotificationCompat.MediaStyle()
               .setMediaSession(mediaSession.sessionToken))
           .setContentTitle(mediaMetadata.title)
           .setContentText(mediaMetadata.artist)
           .setLargeIcon(cover)
       
       // 添加扩展视图显示歌词
       if (currentLine != null) {
           val bigContentView = RemoteViews(context.packageName, R.layout.notification_lyrics)
           bigContentView.setTextViewText(R.id.lyrics_text, currentLine)
           builder.setCustomBigContentView(bigContentView)
       }
       
       notificationManager.notify(NOTIFICATION_ID, builder.build())
   }
   ```

---

#### [NEW] [res/layout/notification_lyrics.xml](file:///f:/bilibili_player/LZF-Music/android/app/src/main/res/layout/notification_lyrics.xml)

**新建布局文件**，定义通知栏歌词展开视图：

```xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="wrap_content"
    android:orientation="vertical"
    android:padding="16dp">
    
    <!-- 媒体信息区域 -->
    <include layout="@layout/notification_media_controls" />
    
    <!-- 歌词显示区域 -->
    <TextView
        android:id="@+id/lyrics_text"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:textSize="14sp"
        android:textColor="#FFFFFF"
        android:gravity="center"
        android:paddingTop="12dp"
        android:paddingBottom="12dp"
        android:text="加载歌词中..." />
</LinearLayout>
```

---

### Android 配置

#### [MODIFY] [build.gradle](file:///f:/bilibili_player/LZF-Music/android/app/build.gradle)

**变更内容**（如需要）：
- 确保 `androidx.media:media` 依赖存在（通常 `audio_service` 已包含）

---

## 验证计划

### Android 平台手动测试

**测试环境**：
- Android 设备或模拟器（Android 7.0+）
- 编译命令：`flutter run -d <android-device>`

**测试步骤**：

#### 1. 喜欢按钮功能测试

1. 播放一首未标记喜欢的歌曲
2. 下拉通知栏，确认显示空心❤️图标
3. 点击空心❤️，观察：
   - 图标变为实心❤️
   - 应用内弹出"已添加到喜欢"提示
4. 再次点击实心❤️，验证图标变回空心，提示"已取消喜欢"
5. 返回应用曲库，确认歌曲喜欢状态同步

#### 2. 歌词展开功能测试

1. 播放一首有歌词的歌曲
2. 确认应用内歌词正常加载显示
3. 下拉通知栏，**正常状态**查看折叠视图（显示歌曲信息和控制按钮）
4. **下拉展开通知**，查看扩展视图：
   - 确认显示当前歌词行
   - 歌词文本居中、清晰可读
5. 播放过程中观察：
   - 歌词随播放进度实时更新
   - 切歌后歌词立即切换到新歌
6. 播放无歌词的歌曲，确认扩展视图显示"暂无歌词"或隐藏

#### 3. 组合测试

1. 在通知栏依次测试：播放、暂停、上一曲、下一曲、喜欢
2. 验证所有按钮功能正常，无冲突或延迟
3. 快速切歌，观察歌词和喜欢状态是否正确更新

#### 4. 边界场景测试

1. **应用被杀死**：划掉应用卡片，验证通知栏控制是否仍然响应
2. **快速连点**：快速点击喜欢按钮5次，确认无崩溃或状态错乱
3. **无歌词场景**：播放本地音乐文件（无歌词），确认通知栏不显示歌词或显示占位文本
4. **网络歌曲**：播放 Bilibili 音频，确认封面、歌词正常显示

### 验证通过标准

- [ ] 喜欢按钮功能完整，图标动态更新正确
- [ ] 通知栏扩展视图成功显示歌词
- [ ] 歌词随播放进度实时更新，无明显延迟（<200ms）
- [ ] 切歌时歌词立即切换
- [ ] 通知栏控制与应用内状态完全同步
- [ ] 无崩溃、无内存泄漏
