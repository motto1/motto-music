import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:motto_music/database/database.dart';
import 'package:motto_music/models/bilibili/audio_quality.dart';
import 'package:motto_music/models/download_progress_event.dart';
import 'package:motto_music/services/bilibili/download_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 下载管理器 Provider
///
/// 提供下载功能的状态管理和UI接口：
/// - 下载任务列表管理
/// - 下载进度监听
/// - 用户设置管理
/// - 批量操作支持
class DownloadManager with ChangeNotifier {
  final MusicDatabase _database;
  final BilibiliDownloadService _downloadService;

  /// 所有下载任务
  List<DownloadTask> _allTasks = [];

  /// 下载进度事件（最新的）
  final Map<int, DownloadProgressEvent> _progressEvents = {};

  /// 用户设置
  UserSetting? _userSettings;

  /// 网络连接状态（connectivity_plus 返回列表）
  List<ConnectivityResult> _connectivity = [ConnectivityResult.wifi];

  /// 进度监听订阅
  StreamSubscription<DownloadProgressEvent>? _progressSubscription;

  /// 是否正在加载
  bool _isLoading = false;

  DownloadManager(this._database, this._downloadService) {
    _init();
  }

  // ========== Getters ==========

  /// 所有任务
  List<DownloadTask> get allTasks => _allTasks;

  /// 正在下载的任务
  List<DownloadTask> get downloadingTasks =>
      _allTasks.where((t) => t.status == 'downloading' || t.status == 'pending').toList();

  /// 已完成的任务
  List<DownloadTask> get completedTasks =>
      _allTasks.where((t) => t.status == 'completed').toList();

  /// 失败的任务
  List<DownloadTask> get failedTasks =>
      _allTasks.where((t) => t.status == 'failed').toList();

  /// 已暂停的任务
  List<DownloadTask> get pausedTasks =>
      _allTasks.where((t) => t.status == 'paused').toList();

  /// 正在下载的任务数量
  int get downloadingCount => downloadingTasks.length;

  /// 已完成的任务数量
  int get completedCount => completedTasks.length;

  /// 失败的任务数量
  int get failedCount => failedTasks.length;

  /// 用户设置
  UserSetting? get userSettings => _userSettings;

  /// 是否正在加载
  bool get isLoading => _isLoading;

  /// 当前下载目录（若未设置则返回默认目录）
  Future<String> getCurrentDownloadDirectory() async {
    final customPath = _userSettings?.downloadDirectory;
    if (customPath != null && customPath.isNotEmpty) {
      await _ensureDirectoryExists(customPath);
      return customPath;
    }

    final defaultPath = await _resolveDefaultDownloadDirectory();
    await _ensureDirectoryExists(defaultPath);
    return defaultPath;
  }

  Future<void> _ensureDirectoryExists(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  Future<String> _resolveDefaultDownloadDirectory() async {
    if (Platform.isAndroid) {
      final dirs = await getExternalStorageDirectories(type: StorageDirectory.music);
      if (dirs != null && dirs.isNotEmpty) {
        final base = dirs.first;
        return p.join(base.path, 'MottoMusic', 'Bilibili');
      }
      final fallback = await getExternalStorageDirectory();
      if (fallback != null) {
        return p.join(fallback.path, 'MottoMusic', 'Bilibili');
      }
    }

    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, 'downloads', 'bilibili');
  }

  /// 获取任务进度
  DownloadProgressEvent? getProgress(int taskId) => _progressEvents[taskId];

  /// 获取任务进度百分比
  int getProgressPercentage(int taskId) {
    final progress = _progressEvents[taskId];
    return progress?.progress ?? 0;
  }

  // ========== 初始化 ==========

  Future<void> _init() async {
    // 监听下载进度
    _progressSubscription = _downloadService.progressStream.listen((event) {
      _progressEvents[event.taskId] = event;

      // 如果是状态变更（完成、失败等），刷新任务列表
      if (event.type == DownloadEventType.completed ||
          event.type == DownloadEventType.failed ||
          event.type == DownloadEventType.cancelled) {
        refreshTasks();
      } else {
        // 仅通知UI更新进度
        notifyListeners();
      }
    });

    // 监听网络变化
    Connectivity().onConnectivityChanged.listen((result) {
      _connectivity = result;
      notifyListeners();
    });

    // 加载初始数据
    await Future.wait([
      _loadUserSettings(),
      refreshTasks(),
    ]);

    // 同步下载服务配置
    if (_userSettings != null) {
      _downloadService.setMaxConcurrentDownloads(_userSettings!.maxConcurrentDownloads);
      _downloadService.setAutoRetry(_userSettings!.autoRetryFailed);
    }
  }

  /// 加载用户设置
  Future<void> _loadUserSettings() async {
    _userSettings = await _database.getUserSettings();
    notifyListeners();
  }

  /// 刷新任务列表
  Future<void> refreshTasks() async {
    _isLoading = true;
    notifyListeners();

    try {
      _allTasks = await _database.getAllDownloadTasks();
    } catch (e) {
      print('❌ 刷新任务列表失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 检查网络限制
  bool _checkNetworkRestriction() {
    if (_userSettings?.wifiOnlyDownload != true) {
      return true; // 没有限制
    }

    // 检查是否有 WiFi 或以太网连接
    return _connectivity.contains(ConnectivityResult.wifi) ||
        _connectivity.contains(ConnectivityResult.ethernet);
  }

  /// 获取当前主要网络类型
  ConnectivityResult _getPrimaryConnectivity() {
    if (_connectivity.isEmpty) {
      return ConnectivityResult.none;
    }

    // 优先级：WiFi > 以太网 > 移动网络 > 其他
    if (_connectivity.contains(ConnectivityResult.wifi)) {
      return ConnectivityResult.wifi;
    }
    if (_connectivity.contains(ConnectivityResult.ethernet)) {
      return ConnectivityResult.ethernet;
    }
    if (_connectivity.contains(ConnectivityResult.mobile)) {
      return ConnectivityResult.mobile;
    }

    return _connectivity.first;
  }

  // ========== 下载操作 ==========

  /// 下载单首歌曲
  ///
  /// 如果未指定音质，则使用用户默认下载音质
  Future<void> downloadSong({
    required Song song,
    BilibiliAudioQuality? quality,
  }) async {
    // 检查是否为 Bilibili 歌曲
    if (song.source != 'bilibili' || song.bvid == null || song.cid == null) {
      throw Exception('仅支持下载 Bilibili 歌曲');
    }

    // 检查网络限制
    if (!_checkNetworkRestriction()) {
      throw Exception('当前设置仅允许在 WiFi 下下载');
    }

    // 选择音质
    final downloadQuality = quality ??
        (_userSettings != null
            ? BilibiliAudioQuality.fromId(_userSettings!.defaultDownloadQuality)
            : BilibiliAudioQuality.flac);

    try {
      await _downloadService.addDownloadTask(
        bvid: song.bvid!,
        cid: song.cid!,
        title: song.title,
        quality: downloadQuality,
        artist: song.artist,
        coverUrl: song.albumArtPath,
        duration: song.duration,
      );

      await refreshTasks();
    } catch (e) {
      rethrow;
    }
  }

  /// 批量下载歌曲列表
  ///
  /// [songs] 歌曲列表（按此顺序下载）
  /// [quality] 音质（所有歌曲使用相同音质）
  Future<void> batchDownload({
    required List<Song> songs,
    required BilibiliAudioQuality quality,
  }) async {
    // 检查网络限制
    if (!_checkNetworkRestriction()) {
      throw Exception('当前设置仅允许在 WiFi 下下载');
    }

    int successCount = 0;
    int skipCount = 0;
    int failCount = 0;

    for (final song in songs) {
      // 跳过非 Bilibili 歌曲
      if (song.source != 'bilibili' || song.bvid == null || song.cid == null) {
        skipCount++;
        continue;
      }

      try {
        await _downloadService.addDownloadTask(
          bvid: song.bvid!,
          cid: song.cid!,
          title: song.title,
          quality: quality,
          artist: song.artist,
          coverUrl: song.albumArtPath,
          duration: song.duration,
        );
        successCount++;
      } catch (e) {
        print('⚠️ 添加任务失败 (${song.title}): $e');
        failCount++;
      }
    }

    await refreshTasks();

    print('✅ 批量下载已添加: 成功 $successCount，跳过 $skipCount，失败 $failCount');
  }

  /// 暂停下载
  Future<void> pauseDownload(int taskId) async {
    try {
      await _downloadService.pauseDownload(taskId);
      await refreshTasks();
    } catch (e) {
      print('❌ 暂停下载失败: $e');
      rethrow;
    }
  }

  /// 恢复下载
  Future<void> resumeDownload(int taskId) async {
    // 检查网络限制
    if (!_checkNetworkRestriction()) {
      throw Exception('当前设置仅允许在 WiFi 下下载');
    }

    try {
      await _downloadService.resumeDownload(taskId);
      await refreshTasks();
    } catch (e) {
      print('❌ 恢复下载失败: $e');
      rethrow;
    }
  }

  /// 取消下载
  Future<void> cancelDownload(int taskId) async {
    try {
      await _downloadService.cancelDownload(taskId);
      await refreshTasks();
    } catch (e) {
      print('❌ 取消下载失败: $e');
      rethrow;
    }
  }

  /// 删除任务
  Future<void> deleteTask(int taskId) async {
    try {
      await _downloadService.deleteDownloadTask(taskId);
      await refreshTasks();
    } catch (e) {
      print('❌ 删除任务失败: $e');
      rethrow;
    }
  }

  /// 重试失败的任务
  Future<void> retryFailedTask(int taskId) async {
    // 检查网络限制
    if (!_checkNetworkRestriction()) {
      throw Exception('当前设置仅允许在 WiFi 下下载');
    }

    try {
      await _downloadService.retryFailedTask(taskId);
      await refreshTasks();
    } catch (e) {
      print('❌ 重试任务失败: $e');
      rethrow;
    }
  }

  // ========== 批量操作 ==========

  /// 暂停所有下载
  Future<void> pauseAll() async {
    final tasks = downloadingTasks;
    for (final task in tasks) {
      if (task.status == 'downloading') {
        await pauseDownload(task.id);
      }
    }
  }

  /// 恢复所有下载
  Future<void> resumeAll() async {
    final tasks = pausedTasks;
    for (final task in tasks) {
      await resumeDownload(task.id);
    }
  }

  /// 重试所有失败的任务
  Future<void> retryAllFailed() async {
    final tasks = failedTasks;
    for (final task in tasks) {
      await retryFailedTask(task.id);
    }
  }

  /// 清空已完成的任务记录
  Future<void> clearCompleted() async {
    try {
      await _downloadService.clearCompletedTasks();
      await refreshTasks();
    } catch (e) {
      print('❌ 清空已完成任务失败: $e');
      rethrow;
    }
  }

  // ========== 设置管理 ==========

  /// 更新默认播放音质
  Future<void> setDefaultPlayQuality(BilibiliAudioQuality quality) async {
    if (_userSettings == null) return;

    await _database.updateUserSettings(
      _userSettings!.copyWith(
        defaultPlayQuality: quality.id,
      ),
    );

    await _loadUserSettings();
  }

  /// 更新默认下载音质
  Future<void> setDefaultDownloadQuality(BilibiliAudioQuality quality) async {
    if (_userSettings == null) return;

    await _database.updateUserSettings(
      _userSettings!.copyWith(
        defaultDownloadQuality: quality.id,
      ),
    );

    await _loadUserSettings();
  }

  /// 设置是否自动选择音质
  Future<void> setAutoSelectQuality(bool enabled) async {
    if (_userSettings == null) return;

    await _database.updateUserSettings(
      _userSettings!.copyWith(
        autoSelectQuality: enabled,
      ),
    );

    await _loadUserSettings();
  }

  /// 设置仅 WiFi 下载
  Future<void> setWifiOnlyDownload(bool enabled) async {
    if (_userSettings == null) return;

    await _database.updateUserSettings(
      _userSettings!.copyWith(
        wifiOnlyDownload: enabled,
      ),
    );

    await _loadUserSettings();
  }

  /// 设置最大并发下载数
  Future<void> setMaxConcurrentDownloads(int count) async {
    if (_userSettings == null) return;

    final validCount = count.clamp(1, 5);

    await _database.updateUserSettings(
      _userSettings!.copyWith(
        maxConcurrentDownloads: validCount,
      ),
    );

    // 同步到下载服务
    _downloadService.setMaxConcurrentDownloads(validCount);

    await _loadUserSettings();
  }

  /// 设置自动重试失败任务
  Future<void> setAutoRetryFailed(bool enabled) async {
    if (_userSettings == null) return;

    await _database.updateUserSettings(
      _userSettings!.copyWith(
        autoRetryFailed: enabled,
      ),
    );

    // 同步到下载服务
    _downloadService.setAutoRetry(enabled);

    await _loadUserSettings();
  }

  /// 设置自动缓存空间限制
  Future<void> setAutoCacheSizeGB(int sizeGB) async {
    if (_userSettings == null) return;

    await _database.updateUserSettings(
      _userSettings!.copyWith(
        autoCacheSizeGB: sizeGB,
      ),
    );

    await _loadUserSettings();
  }

  /// 设置自定义下载目录
  Future<void> setDownloadDirectory(String? path) async {
    if (_userSettings == null) return;

    await _database.updateUserSettings(
      _userSettings!.copyWith(
        downloadDirectory: Value(path),
      ),
    );

    await _loadUserSettings();
  }

  // ========== 工具方法 ==========

  /// 获取推荐音质（基于网络类型）
  BilibiliAudioQuality getRecommendedQuality() {
    if (_userSettings?.autoSelectQuality == true) {
      return BilibiliAudioQuality.recommendForNetwork(_getPrimaryConnectivity());
    }
    return _userSettings != null
        ? BilibiliAudioQuality.fromId(_userSettings!.defaultDownloadQuality)
        : BilibiliAudioQuality.flac;
  }

  /// 检查是否可以下载（网络限制）
  bool canDownload() {
    return _checkNetworkRestriction();
  }

  /// 获取下载统计信息
  Map<String, int> getStatistics() {
    return {
      'total': _allTasks.length,
      'downloading': downloadingCount,
      'completed': completedCount,
      'failed': failedCount,
      'paused': pausedTasks.length,
    };
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }
}
