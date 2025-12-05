import 'dart:math';

/// Bilibili 响度均衡参数
///
/// 基于 EBU R128 标准的响度信息
class LoudnessInfo {
  /// 实际响度 (LUFS)
  final double measuredI;

  /// 目标响度 (LUFS)
  final double targetI;

  /// 真峰值 (dBTP)
  final double measuredTp;

  /// 响度范围 (LU)
  final double measuredLra;

  /// 目标偏移 (dB)
  final double targetOffset;

  /// 多场景参数
  final Map<String, String>? multiSceneArgs;

  LoudnessInfo({
    required this.measuredI,
    required this.targetI,
    required this.measuredTp,
    this.measuredLra = 0,
    this.targetOffset = 0,
    this.multiSceneArgs,
  });

  /// 根据场景获取目标响度
  double getTargetForScene(String scene) {
    if (multiSceneArgs == null) return targetI;

    final target = switch (scene) {
      'high_dynamic' => multiSceneArgs!['high_dynamic_target_i'],
      'undersized' => multiSceneArgs!['undersized_target_i'],
      _ => multiSceneArgs!['normal_target_i'],
    };

    return double.tryParse(target ?? '-14') ?? targetI;
  }

  /// 根据音频特性自动选择最佳场景
  ///
  /// 判断依据：
  /// 1. 动态范围（LRA）- 区分古典/流行
  /// 2. 实际响度（measured_i）- 区分响度大小
  String getAutoScene() {
    // 优先级1：大动态范围（古典音乐、交响乐）
    // LRA > 15 LU 表示动态范围很大
    if (measuredLra > 15.0) {
      return 'high_dynamic'; // 保留动态细节
    }

    // 优先级2：极低响度（轻音乐、ASMR、白噪音）
    // measured_i < -20 LUFS 表示原始响度很低
    if (measuredI < -20.0) {
      return 'undersized'; // 提升响度
    }

    // 优先级3：中等动态 + 低响度（民谣、轻摇滚）
    // 综合判断
    if (measuredLra > 10.0 && measuredI < -16.0) {
      return 'undersized'; // 轻微提升
    }

    // 默认：流行音乐、摇滚、电子等
    return 'normal';
  }

  /// 计算增益 (dB)
  double getGainDb({String? scene}) {
    final effectiveScene = scene ?? getAutoScene(); // 未指定时自动选择
    final target = getTargetForScene(effectiveScene) + targetOffset;
    return target - measuredI;
  }

  /// 计算线性增益倍数
  double getLinearGain({String? scene}) {
    final effectiveScene = scene ?? getAutoScene(); // 未指定时自动选择
    var gain = getGainDb(scene: effectiveScene).clamp(-12.0, 12.0);

    // 真峰值保护：防止削波
    if (measuredTp > -1.0) {
      gain -= (measuredTp + 1.0);
    }

    return pow(10, gain / 20).toDouble();
  }

  factory LoudnessInfo.fromJson(Map<String, dynamic> json) {
    Map<String, String>? multiScene;
    final multiSceneData = json['multi_scene_args'];
    if (multiSceneData != null && multiSceneData is Map) {
      multiScene = multiSceneData.map((k, v) => MapEntry(k.toString(), v.toString()));
    }

    return LoudnessInfo(
      measuredI: (json['measured_i'] as num?)?.toDouble() ?? -14.0,
      targetI: (json['target_i'] as num?)?.toDouble() ?? -14.0,
      measuredTp: (json['measured_tp'] as num?)?.toDouble() ?? -1.0,
      measuredLra: (json['measured_lra'] as num?)?.toDouble() ?? 0,
      targetOffset: (json['target_offset'] as num?)?.toDouble() ?? 0,
      multiSceneArgs: multiScene,
    );
  }

  Map<String, dynamic> toJson() => {
    'measured_i': measuredI,
    'target_i': targetI,
    'measured_tp': measuredTp,
    'measured_lra': measuredLra,
    'target_offset': targetOffset,
    if (multiSceneArgs != null) 'multi_scene_args': multiSceneArgs,
  };

  @override
  String toString() => 'LoudnessInfo(${measuredI.toStringAsFixed(1)}→${targetI.toStringAsFixed(1)}dB, gain:${getGainDb().toStringAsFixed(1)}dB, tp:${measuredTp.toStringAsFixed(1)}dB, scene:${getAutoScene()})';
}
