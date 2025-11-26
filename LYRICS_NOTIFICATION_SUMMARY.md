# Android通知栏歌词功能实施总结

## 实施时间
2025年（具体日期由用户测试时填写）

## 功能概述
在Android通知栏中显示当前播放歌曲的歌词，样式为"当前句+下一句"（类似QQ音乐），支持实时逐字高亮。无歌词时自动隐藏歌词区域。仅Android平台。

## 已完成阶段

### ✅ Phase 1: 基础框架搭建
**状态：100%完成**

#### 1.1 Platform Channel通信层
- **文件**：`lib/services/lyrics_notification_service.dart`
- **功能**：Flutter到Android原生通信桥接
- **方法**：
  - `updateLyrics()` - 更新歌词
  - `updatePosition()` - 更新播放位置
  - `clearLyrics()` - 清除歌词
  - `setEnabled()` - 功能开关
  - `ping()` - 连接测试

#### 1.2 Android原生管理器
- **文件**：`android/app/src/main/kotlin/com/mottomusic/player/LyricsNotificationManager.kt`
- **功能**：
  - 歌词状态缓存
  - 节流更新机制（≤1次/秒）
  - ROM兼容性检测（vivo/OPPO/小米/华为）
  - 逐字高亮计算（SpannableString）

#### 1.3 自定义通知布局
- **文件**：`android/app/src/main/res/layout/notification_lyrics.xml`
- **布局结构**：
  - 封面图片（64x64dp）
  - 歌曲标题和艺术家
  - 当前句歌词（支持高亮）
  - 下一句歌词（半透明）
  - 控制按钮（上一首/播放暂停/下一首）

#### 1.4 MethodChannel注册
- **文件**：`android/app/src/main/kotlin/com/mottomusic/player/MainActivity.kt`
- **功能**：注册通道并转发调用到LyricsNotificationManager

---

### ✅ Phase 2: 播放流程集成
**状态：100%完成**

#### 2.1 MottoAudioHandler集成
- **文件**：`lib/services/audio_handler_service.dart`
- **修改**：
  - 导入`LyricsNotificationService`
  - 覆盖`onNotificationPositionUpdate()`回调
  - 每秒调用`updatePosition()`更新逐字高亮

#### 2.2 双定时器机制
- **文件**：`lib/core/basic_audio_handler.dart`
- **实现**：
  - **UI定时器**：200ms高刷新率（保持流畅）
  - **通知定时器**：1000ms低频（省电）
  - 新增`onNotificationPositionUpdate()`虚方法供子类覆盖

#### 2.3 歌词切换逻辑
- **文件**：`lib/services/player_provider.dart`
- **功能**：
  - 初始化`LyricsNotificationService`
  - 监听播放位置，调用`_updateNotificationLyrics()`
  - 根据时间戳查找当前句和下一句
  - 仅在歌词行变化时更新通知栏（节流）
  - 字级时间戳转换为Map格式传递

---

### ✅ Phase 3: 逐字高亮实现
**状态：80%完成（原生渲染待优化）**

#### 3.1 LRC解析增强
- **文件**：`lib/models/lyrics/lyric_models.dart`
- **新增**：
  - `CharTimestamp`类：字级时间戳数据结构
  - `LyricLine.charTimestamps`字段

- **文件**：`lib/utils/lyric_parser.dart`
- **支持格式**：
  1. **字级LRC**：`[00:10.50]<00:10.50>歌<00:10.80>词<00:11.10>内容`
  2. **标准LRC**：`[00:10.50]歌词内容`（自动均分估算）
- **算法**：
  - 有字级时间戳：直接解析
  - 无字级时间戳：根据当前行和下一行时间戳均分

#### 3.2 原生高亮渲染
- **文件**：`android/.../LyricsNotificationManager.kt`
- **功能**：
  - `buildHighlightedLyric()`方法计算高亮
  - 使用`SpannableString` + `ForegroundColorSpan`动态着色
  - 根据`currentPositionMs`计算高亮字符数

**⚠️ 待完成**：
- `updateNotificationInternal()`方法实际构建RemoteViews通知
- 与audio_service插件的集成（可能需要fork或绕过）

#### 3.3 性能优化
**已实现**：
- ✅ 节流机制：通知更新≤1次/秒
- ✅ 事件驱动：歌词行切换立即触发
- ✅ ROM检测：受限ROM自动降级
- ✅ 延迟更新：防止UI卡顿

**待优化**：
- RemoteViews缓存复用
- SpannableString池化

---

### ⏸️ Phase 4: 兼容性和优化
**状态：部分完成**

#### 4.1 ROM检测与降级（✅ 完成）
- **检测逻辑**：`detectRestrictedRom()`
- **受限ROM**：vivo、OPPO、小米（Android 10以下）
- **降级策略**：禁用逐字高亮，仅显示完整句子

#### 4.2 Android版本适配（❌ 待实现）
- Android 7.0-10: 标准RemoteViews
- Android 11-12: 适配MediaStyle约束
- Android 13+: POST_NOTIFICATIONS权限检查

#### 4.3 无歌词处理（✅ 完成）
- `loadLyrics()`失败时调用`clearLyrics()`
- `clearLyrics()`时隐藏TextView（visibility=GONE）
- 停止播放时自动清除

---

## 技术架构

### 数据流向
```
播放位置变化 (每200ms)
    ↓
PlayerProvider._updateNotificationLyrics()
    ├─ 查找当前歌词行
    ├─ 提取字级时间戳
    └─ 调用LyricsNotificationService.updateLyrics()
         ↓ MethodChannel
Android MottoAudioHandler.onNotificationPositionUpdate()
    └─ 调用LyricsNotificationService.updatePosition()
         ↓ MethodChannel
Android LyricsNotificationManager
    ├─ 节流控制（≤1次/秒）
    ├─ buildHighlightedLyric() (计算高亮)
    └─ updateNotificationInternal() [TODO: 实际渲染]
```

### 关键设计决策

1. **双定时器策略**：平衡UI流畅度和电量消耗
2. **事件驱动更新**：歌词行切换立即触发，避免延迟
3. **节流机制**：通知更新≤1次/秒，防止系统卡顿
4. **均分算法**：无字级时间戳时自动估算，提升兼容性
5. **ROM检测**：受限ROM自动降级，确保稳定性

---

## 文件清单

### 新建文件（5个）
1. `lib/services/lyrics_notification_service.dart` - Platform Channel桥接
2. `android/app/src/main/kotlin/com/mottomusic/player/LyricsNotificationManager.kt` - 核心管理器
3. `android/app/src/main/res/layout/notification_lyrics.xml` - 通知布局
4. （CharTimestamp类集成到lyric_models.dart）

### 修改文件（4个）
1. `lib/services/audio_handler_service.dart` - 覆盖位置更新回调
2. `lib/core/basic_audio_handler.dart` - 添加通知定时器
3. `android/app/src/main/kotlin/com/mottomusic/player/MainActivity.kt` - 注册MethodChannel
4. `lib/services/player_provider.dart` - 实现歌词切换逻辑

### 增强文件（2个）
1. `lib/models/lyrics/lyric_models.dart` - 添加CharTimestamp类
2. `lib/utils/lyric_parser.dart` - 支持字级时间戳解析

---

## 待完成任务

### 🔴 高优先级
1. **实际通知渲染**：完成`LyricsNotificationManager.updateNotificationInternal()`
   - 构建RemoteViews
   - 应用SpannableString高亮
   - 与audio_service集成（可能需要fork）
   - PendingIntent设置控制按钮

2. **Android版本适配**：
   - 检测Android版本
   - Android 13+请求POST_NOTIFICATIONS权限
   - 不同版本使用不同通知样式

3. **真机测试**：
   - vivo手机测试（用户设备）
   - 验证歌词同步准确性
   - 测试电量消耗

### 🟡 中优先级
4. **性能优化**：
   - RemoteViews对象池
   - SpannableString缓存
   - 省电模式适配

5. **用户设置**：
   - 设置页面添加开关
   - SharedPreferences持久化
   - 默认开启

### 🟢 低优先级
6. **折叠布局**：创建`notification_lyrics_compact.xml`
7. **锁屏优化**：独立的锁屏歌词布局
8. **翻译支持**：三行模式（原文+翻译+下一句）

---

## 已知问题

1. **audio_service插件冲突**：
   - 问题：audio_service可能已接管通知构建
   - 方案A：完全接管通知（绕过插件）
   - 方案B：扩展插件通知（fork修改）
   - 当前状态：框架完成，实际渲染待实现

2. **vivo ROM限制**：
   - 问题：vivo可能阻止自定义通知
   - 缓解：已实现ROM检测和降级
   - 需验证：真机测试

3. **电量消耗**：
   - 问题：高频更新可能耗电
   - 缓解：已实现节流（1次/秒）
   - 需验证：实际测试电量消耗

---

## 测试建议

### 功能测试
1. ✅ Platform Channel通信：调用`testConnection()`
2. ✅ 歌词解析：测试标准LRC和字级LRC
3. ✅ 歌词切换：播放时观察日志输出
4. ❌ 通知显示：需实现渲染逻辑后测试
5. ❌ 逐字高亮：需在vivo设备上验证

### 性能测试
1. 电量消耗：播放1小时，记录电量降幅
2. 内存占用：查看应用内存增量
3. UI流畅度：检查播放时是否卡顿

### 兼容性测试
- vivo手机（用户设备）
- Android 13+ (权限测试)
- Android 10以下 (降级测试)

---

## 使用方法

### 开发者
```dart
// 初始化（已自动在PlayerProvider中完成）
final lyricsService = LyricsNotificationService();
await lyricsService.init();

// 测试连接
final isConnected = await lyricsService.testConnection();
print('通知栏歌词服务：${isConnected ? "✅ 正常" : "❌ 异常"}');

// 功能开关
await lyricsService.setEnabled(true);  // 启用
await lyricsService.setEnabled(false); // 禁用
```

### 用户
1. 播放歌曲，歌词自动加载
2. 通知栏自动显示当前句和下一句
3. 实时高亮当前播放的字（如果LRC包含字级时间戳）
4. 无歌词时自动隐藏

---

## 贡献者
- Claude Code (Anthropic)
- 用户（需求提出和测试）

---

## 参考资料
- [audio_service插件文档](https://pub.dev/packages/audio_service)
- [Android RemoteViews指南](https://developer.android.com/develop/ui/views/notifications/custom-notification)
- [QQ音乐通知栏歌词参考]
