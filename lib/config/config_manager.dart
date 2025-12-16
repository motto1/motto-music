import 'backup_format.dart';
import 'config_module.dart';

/// 配置备份/导入导出管理器。
///
/// 负责按模块编排导出与导入流程，不直接关心模块内部存储细节。
class ConfigManager {
  ConfigManager(this._modules);

  final List<ConfigModule> _modules;

  List<ConfigModule> get modules => List.unmodifiable(_modules);

  ConfigModule? getModule(String id) {
    for (final m in _modules) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// 导出备份对象。
  Future<BackupFile> exportBackup({
    Set<String>? moduleIds,
    bool includeSensitive = false,
    String appId = 'motto_music',
  }) async {
    final selectedIds = moduleIds ??
        _modules
            .where((m) =>
                m.enabledByDefault || (includeSensitive && m.isSensitive))
            .map((m) => m.id)
            .toSet();

    final modules = <String, ModuleBackup>{};
    for (final module in _modules) {
      if (!selectedIds.contains(module.id)) continue;
      if (module.isSensitive && !includeSensitive) continue;
      final data = await module.exportData(includeSensitive: includeSensitive);
      modules[module.id] = ModuleBackup(version: module.version, data: data);
    }

    return BackupFile(
      appId: appId,
      backupVersion: kBackupFormatVersion,
      createdAt: DateTime.now().toUtc(),
      modules: modules,
    );
  }

  /// 导出 JSON 字符串。
  Future<String> exportBackupJsonString({
    Set<String>? moduleIds,
    bool includeSensitive = false,
    bool pretty = true,
    String appId = 'motto_music',
  }) async {
    final backup = await exportBackup(
      moduleIds: moduleIds,
      includeSensitive: includeSensitive,
      appId: appId,
    );
    return backup.toJsonString(pretty: pretty);
  }

  /// 从备份对象导入。
  ///
  /// [merge] 为 true 表示合并写入；false 表示替换模块。
  Future<void> importBackup(
    BackupFile backup, {
    bool merge = true,
    Set<String>? moduleIds,
    bool includeSensitive = false,
  }) async {
    if (backup.backupVersion > kBackupFormatVersion) {
      throw ConfigBackupException(
        '不支持的备份格式版本: ${backup.backupVersion}',
      );
    }

    final selectedIds = moduleIds ?? backup.modules.keys.toSet();

    for (final id in selectedIds) {
      final module = getModule(id);
      final moduleBackup = backup.modules[id];
      if (module == null || moduleBackup == null) continue;
      if (module.isSensitive && !includeSensitive) continue;

      final fromVersion = moduleBackup.version;
      var data = moduleBackup.data;
      if (fromVersion < module.version) {
        data = module.migrateData(fromVersion, data);
      }
      await module.importData(data, merge: merge);
    }

    for (final id in selectedIds) {
      final module = getModule(id);
      if (module == null) continue;
      if (module.isSensitive && !includeSensitive) continue;
      await module.afterImport();
    }
  }

  /// 从 JSON Map 导入。
  Future<void> importBackupFromJson(
    Map<String, dynamic> json, {
    bool merge = true,
    Set<String>? moduleIds,
    bool includeSensitive = false,
  }) async {
    final backup = BackupFile.fromJson(json);
    await importBackup(
      backup,
      merge: merge,
      moduleIds: moduleIds,
      includeSensitive: includeSensitive,
    );
  }

  /// 从 JSON 字符串导入。
  Future<void> importBackupFromJsonString(
    String jsonString, {
    bool merge = true,
    Set<String>? moduleIds,
    bool includeSensitive = false,
  }) async {
    final backup = BackupFile.fromJsonString(jsonString);
    await importBackup(
      backup,
      merge: merge,
      moduleIds: moduleIds,
      includeSensitive: includeSensitive,
    );
  }
}

class ConfigBackupException implements Exception {
  ConfigBackupException(this.message);
  final String message;
  @override
  String toString() => 'ConfigBackupException: $message';
}
