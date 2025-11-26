import 'package:just_audio/just_audio.dart';

/// 全局音频源注册中心
/// 用于在 Provider 层构建的 AudioVideoSource 与 AudioHandler 之间传递引用
class AudioSourceRegistry {
  static final Map<String, AudioVideoSource> _sources = {};

  /// 注册音频源
  static void register(String id, AudioVideoSource source) {
    _sources[id] = source;
  }

  /// 获取并移除音频源（防止内存泄漏）
  static AudioVideoSource? take(String id) {
    return _sources.remove(id);
  }

  /// 清空全部注册信息（调试/重置时使用）
  static void clear() {
    _sources.clear();
  }
}
