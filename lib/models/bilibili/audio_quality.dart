import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Bilibili 音频质量枚举
///
/// 定义了 Bilibili 平台支持的音质等级：
/// - Dolby: 杜比全景声（126360，会员专属）
/// - FLAC: FLAC无损（30251，通过 dash.flac 检测）
/// - HiRes: Hi-Res无损（30251，会员专属）
/// - Extreme: 极高音质 320kbps（30280）
/// - High: 高音质 128kbps（30232）
/// - Standard: 标准音质 64kbps（30216）
enum BilibiliAudioQuality {
  dolby(126360, '杜比', '杜比全景声', '~15MB/首', Colors.indigo, 1000),
  flac(30251, 'FLAC', 'FLAC无损', '~30MB/首', Colors.purple, 800),
  hiRes(30251, 'Hi-Res', 'Hi-Res无损', '~20MB/首', Colors.deepPurple, 800),
  extreme(30280, '极高', '320kbps', '~10MB/首', Colors.blue, 320),
  high(30232, '高音质', '128kbps', '~5MB/首', Colors.lightBlue, 128),
  standard(30216, '标准', '64kbps', '~3MB/首', Colors.green, 64);

  /// Bilibili API 音质 ID
  final int id;

  /// 显示名称
  final String name;

  /// 音质描述
  final String description;

  /// 预估文件大小
  final String estimatedSize;

  /// 主题颜色
  final Color color;

  /// 比特率
  final int bitrate;

  const BilibiliAudioQuality(
    this.id,
    this.name,
    this.description,
    this.estimatedSize,
    this.color,
    this.bitrate,
  );

  /// 用于兼容旧代码的 displayName
  String get displayName {
    switch (this) {
      case BilibiliAudioQuality.standard:
        return '标准音质';
      case BilibiliAudioQuality.high:
        return '高音质';
      case BilibiliAudioQuality.extreme:
        return '极高音质';
      case BilibiliAudioQuality.dolby:
        return '杜比全景声';
      case BilibiliAudioQuality.hiRes:
        return 'Hi-Res无损';
      case BilibiliAudioQuality.flac:
        return 'FLAC无损';
    }
  }

  /// 根据音质 ID 获取枚举值
  static BilibiliAudioQuality fromId(int id) {
    return values.firstWhere(
      (q) => q.id == id,
      orElse: () => BilibiliAudioQuality.high,
    );
  }

  /// 根据网络类型推荐音质
  ///
  /// - WiFi/以太网: 推荐极高音质 320kbps
  /// - 移动网络: 推荐高音质 128kbps
  /// - 其他: 推荐标准音质 64kbps
  static BilibiliAudioQuality recommendForNetwork(ConnectivityResult connectivity) {
    switch (connectivity) {
      case ConnectivityResult.wifi:
      case ConnectivityResult.ethernet:
        return BilibiliAudioQuality.extreme;
      case ConnectivityResult.mobile:
        return BilibiliAudioQuality.high;
      default:
        return BilibiliAudioQuality.standard;
    }
  }

  /// 获取音质图标
  IconData getIcon() {
    switch (this) {
      case BilibiliAudioQuality.dolby:
        return Icons.surround_sound_rounded;
      case BilibiliAudioQuality.flac:
        return Icons.high_quality_rounded;
      case BilibiliAudioQuality.hiRes:
        return Icons.high_quality;
      case BilibiliAudioQuality.extreme:
        return Icons.headset_rounded;
      case BilibiliAudioQuality.high:
        return Icons.headphones_rounded;
      case BilibiliAudioQuality.standard:
        return Icons.music_note_rounded;
    }
  }

  /// 获取带颜色的音质标签
  Widget getBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        name,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
