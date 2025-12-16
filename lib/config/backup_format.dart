import 'dart:convert';

/// 备份文件整体格式版本。
const int kBackupFormatVersion = 1;

/// 备份文件顶层结构。
class BackupFile {
  BackupFile({
    required this.appId,
    required this.backupVersion,
    required this.createdAt,
    required this.modules,
  });

  final String appId;
  final int backupVersion;
  final DateTime createdAt;
  final Map<String, ModuleBackup> modules;

  Map<String, dynamic> toJson() {
    return {
      'app': appId,
      'backupVersion': backupVersion,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'modules': modules.map((k, v) => MapEntry(k, v.toJson())),
    };
  }

  String toJsonString({bool pretty = false}) {
    final obj = toJson();
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(obj)
        : jsonEncode(obj);
  }

  static BackupFile fromJson(Map<String, dynamic> json) {
    final appId = json['app']?.toString() ?? '';
    final backupVersion = json['backupVersion'] is int
        ? json['backupVersion'] as int
        : int.tryParse(json['backupVersion']?.toString() ?? '') ?? 0;
    final createdAtStr = json['createdAt']?.toString();
    final createdAt = createdAtStr != null
        ? DateTime.tryParse(createdAtStr) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
        : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    final modulesJson = json['modules'] as Map<String, dynamic>? ?? const {};
    final modules = <String, ModuleBackup>{};
    for (final entry in modulesJson.entries) {
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        modules[entry.key] = ModuleBackup.fromJson(value);
      }
    }

    return BackupFile(
      appId: appId,
      backupVersion: backupVersion,
      createdAt: createdAt.toUtc(),
      modules: modules,
    );
  }

  static BackupFile fromJsonString(String jsonString) {
    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    return BackupFile.fromJson(decoded);
  }
}

/// 单模块备份结构。
class ModuleBackup {
  ModuleBackup({
    required this.version,
    required this.data,
  });

  final int version;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'data': data,
    };
  }

  static ModuleBackup fromJson(Map<String, dynamic> json) {
    final version = json['version'] is int
        ? json['version'] as int
        : int.tryParse(json['version']?.toString() ?? '') ?? 0;
    final dataJson = json['data'] as Map<String, dynamic>? ?? const {};
    return ModuleBackup(version: version, data: dataJson);
  }
}

