/// 配置模块接口。
///
/// 每个模块负责将自身相关的配置/数据片段导出为 JSON，
/// 以及从 JSON 导入并写回现有存储。
abstract class ConfigModule {
  /// 模块唯一 ID（用于备份文件 key）。
  String get id;

  /// UI 展示名称。
  String get name;

  /// UI 简短描述。
  String get description;

  /// 模块自身 schema 版本。
  int get version;

  /// 是否为敏感模块（账号/鉴权等），默认 false。
  bool get isSensitive => false;

  /// 是否默认参与备份。
  bool get enabledByDefault => true;

  /// 导出模块数据。
  ///
  /// [includeSensitive] 为 false 时，敏感模块可返回空数据或抛出异常。
  Future<Map<String, dynamic>> exportData({bool includeSensitive = false});

  /// 导入模块数据。
  ///
  /// [merge]=true 表示与本地数据合并（upsert/部分覆盖），
  /// [merge]=false 表示完全替换该模块相关配置。
  Future<void> importData(Map<String, dynamic> data, {required bool merge});

  /// 从旧版本迁移到当前版本（默认不变）。
  Map<String, dynamic> migrateData(int fromVersion, Map<String, dynamic> data) {
    return data;
  }

  /// 导入完成后的钩子（默认无操作）。
  Future<void> afterImport() async {}
}

