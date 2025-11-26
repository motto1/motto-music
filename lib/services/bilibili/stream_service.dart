import 'package:motto_music/services/bilibili/api_client.dart';
import 'package:motto_music/services/bilibili/bilibili_exception.dart';
import 'package:motto_music/models/bilibili/audio_quality.dart';

/// 音频流信息
class AudioStreamInfo {
  final String url;
  final BilibiliAudioQuality quality;
  final int size;           // 文件大小(字节)
  final int? actualBitrate; // 实际比特率(kbps),从API的bandwidth字段提取

  AudioStreamInfo({
    required this.url,
    required this.quality,
    required this.size,
    this.actualBitrate,     // 可选参数,无值时UI将回退到枚举的默认bitrate
  });
}

/// Bilibili 音频流服务
/// 
/// 负责获取 Bilibili 视频的音频流地址（不再处理缓存）
class BilibiliStreamService {
  final BilibiliApiClient _apiClient;
  
  BilibiliStreamService(this._apiClient);
  
  /// 获取音频流地址
  /// 
  /// 如果 quality 为 null，则自动选择最高可用音质
  Future<AudioStreamInfo> getAudioStream({
    required String bvid,
    required int cid,
    BilibiliAudioQuality? quality,
  }) async {
    final targetQuality = quality ?? BilibiliAudioQuality.flac;
    
    print('✅ 开始获取音频流（音质: ${targetQuality.displayName}）');
    print('  - BVID: $bvid');
    print('  - CID: $cid');
    
    return await _fetchAudioStreamFromApi(
      bvid: bvid,
      cid: cid,
      quality: targetQuality,
    );
  }
  
  /// 从 API 获取音频流地址
  Future<AudioStreamInfo> _fetchAudioStreamFromApi({
    required String bvid,
    required int cid,
    required BilibiliAudioQuality quality,
  }) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/x/player/wbi/playurl',
        params: {
          'bvid': bvid,
          'cid': cid.toString(),
          'fnval': '4048',       // 功能标志(4048=支持 DASH、杜比、Hi-Res)
          'fnver': '0',
          'fourk': '1',
          'qn': quality.id.toString(), // 音质参数
        },
      );
      
      // 调试：打印响应结构
      print('🔍 API 响应调试:');
      print('  - 响应类型: ${response.runtimeType}');
      print('  - 响应键: ${response.keys.toList()}');

      final dash = response['dash'] as Map<String, dynamic>?;
      final durl = response['durl'] as List<dynamic>?;

      // ========== 详细音质日志 ==========
      if (dash != null) {
        print('\n📊 可用音质详情:');

        // 检查杜比全景声
        final dolbyData = dash['dolby'];
        if (dolbyData != null && dolbyData is Map<String, dynamic>) {
          final dolbyAudio = dolbyData['audio'];
          if (dolbyAudio != null && dolbyAudio is List && dolbyAudio.isNotEmpty) {
            final dolbyStream = dolbyAudio.first as Map<String, dynamic>;
            print('  ✅ Dolby 杜比全景声:');
            print('     - ID: ${dolbyStream['id']}');
            print('     - Size: ${(dolbyStream['size'] ?? 0) / (1024 * 1024)} MB');
            print('     - Bitrate: ${dolbyStream['bandwidth']}');
          }
        } else {
          print('  ❌ Dolby: 不可用');
        }

        // 检查 Hi-Res/FLAC 无损
        final flacData = dash['flac'];
        if (flacData != null && flacData is Map<String, dynamic>) {
          final flacAudio = flacData['audio'];
          if (flacAudio != null && flacAudio is Map<String, dynamic>) {
            print('  ✅ Hi-Res/FLAC 无损:');
            print('     - ID: ${flacAudio['id']}');
            print('     - Size: ${(flacAudio['size'] ?? 0) / (1024 * 1024)} MB');
            print('     - Bitrate: ${flacAudio['bandwidth']}');
          }
        } else {
          print('  ❌ Hi-Res/FLAC: 不可用（需要会员）');
        }

        // 检查普通音频流
        final audioList = dash['audio'] as List<dynamic>?;
        if (audioList != null && audioList.isNotEmpty) {
          print('  ✅ 普通音频流列表 (${audioList.length} 个):');
          for (var i = 0; i < audioList.length; i++) {
            final audio = audioList[i] as Map<String, dynamic>;
            final audioId = audio['id'] as int;
            final size = (audio['size'] as int? ?? 0) / (1024 * 1024);
            final bandwidth = audio['bandwidth'] as int?;
            final codecid = audio['codecid'] as int?;

            print('     [$i] ID: $audioId | Size: ${size.toStringAsFixed(1)} MB | Bandwidth: $bandwidth | Codec: $codecid');
          }
        } else {
          print('  ❌ 普通音频流: 无可用流');
        }

        print('  📌 请求的音质 ID: ${quality.id}');
        print('========================================\n');
      }
      // ========== 日志结束 ==========

      // 处理老视频（没有 dash，只有 durl）
      if (dash == null) {
        if (durl == null || durl.isEmpty) {
          throw BilibiliApiException(
            type: BilibiliApiExceptionType.apiError,
            message: '请求到的流数据不包含 dash 或 durl 任一字段',
          );
        }

        print('⚠️ 老视频不存在 dash，回退到使用 durl 音频流');
        final durlUrl = durl.first['url'] as String;

        return AudioStreamInfo(
          url: durlUrl,
          quality: BilibiliAudioQuality.standard,
          size: 0,
        );
      }
      
      // 处理 DASH 格式
      // 优先级：dolby > flac (hi-res) > 指定音质 > 第一个可用音质
      
      // 1. 尝试杜比全景声
      final dolbyData = dash['dolby'];
      if (dolbyData != null && dolbyData is Map<String, dynamic>) {
        final dolbyAudio = dolbyData['audio'];
        if (dolbyAudio != null && dolbyAudio is List && dolbyAudio.isNotEmpty) {
          final dolbyStream = dolbyAudio.first as Map<String, dynamic>;
          print('优先使用 Dolby 音频流');
          
          final baseUrl = dolbyStream['baseUrl'] as String?;
          final backupUrl = dolbyStream['backupUrl'] as List<dynamic>?;
          final streamUrl = baseUrl ?? (backupUrl?.isNotEmpty == true ? backupUrl!.first as String : null);
          
          if (streamUrl != null) {
            final size = dolbyStream['size'] as int? ?? 0;
            final bandwidth = dolbyStream['bandwidth'] as int?;
            final actualBitrate = bandwidth != null ? (bandwidth / 1000).round() : null;
            
            return AudioStreamInfo(
              url: streamUrl,
              quality: BilibiliAudioQuality.dolby,
              size: size,
              actualBitrate: actualBitrate,
            );
          }
        }
      }
      
      // 2. 尝试 Hi-Res 无损
      final flacData = dash['flac'];
      if (flacData != null && flacData is Map<String, dynamic>) {
        final flacAudio = flacData['audio'];
        if (flacAudio != null && flacAudio is Map<String, dynamic>) {
          print('次级使用 Hi-Res 音频流');
          
          final baseUrl = flacAudio['baseUrl'] as String?;
          final backupUrl = flacAudio['backupUrl'] as List<dynamic>?;
          final streamUrl = baseUrl ?? (backupUrl?.isNotEmpty == true ? backupUrl!.first as String : null);
          
          if (streamUrl != null) {
            final size = flacAudio['size'] as int? ?? 0;
            final bandwidth = flacAudio['bandwidth'] as int?;
            final actualBitrate = bandwidth != null ? (bandwidth / 1000).round() : null;
            
            return AudioStreamInfo(
              url: streamUrl,
              quality: BilibiliAudioQuality.flac,
              size: size,
              actualBitrate: actualBitrate,
            );
          }
        }
      }
      
      // 3. 获取普通音频流列表
      final audioList = dash['audio'] as List<dynamic>?;
      if (audioList == null || audioList.isEmpty) {
        throw BilibiliApiException(
          type: BilibiliApiExceptionType.apiError,
          message: '未找到有效的音频流数据',
        );
      }

      // 查找匹配的音质
      Map<String, dynamic>? targetAudio;
      for (final audio in audioList) {
        final audioMap = audio as Map<String, dynamic>;
        final audioId = audioMap['id'] as int;

        if (audioId == quality.id) {
          targetAudio = audioMap;
          print('🎯 找到匹配的音质: ID=$audioId');
          break;
        }
      }

      // 如果找不到指定音质,使用第一个可用的
      if (targetAudio == null) {
        targetAudio = audioList.first as Map<String, dynamic>;
        final fallbackId = targetAudio['id'] as int;
        print('⚠️ 未找到请求的音质 ID=${quality.id}，回退到第一个可用音质 ID=$fallbackId');
      }

      final baseUrl = targetAudio['baseUrl'] as String?;
      final backupUrl = targetAudio['backupUrl'] as List<dynamic>?;

      // 优先使用 baseUrl，如果没有则使用 backupUrl
      String? streamUrl;
      if (baseUrl != null && baseUrl.isNotEmpty) {
        streamUrl = baseUrl;
      } else if (backupUrl != null && backupUrl.isNotEmpty) {
        streamUrl = backupUrl.first as String;
      }

      if (streamUrl == null || streamUrl.isEmpty) {
        throw BilibiliApiException(
          type: BilibiliApiExceptionType.apiError,
          message: '无可用的音频流地址',
        );
      }

      final size = targetAudio['size'] as int? ?? 0;
      final audioId = targetAudio['id'] as int;
      final bandwidth = targetAudio['bandwidth'] as int?;
      final actualBitrate = bandwidth != null ? (bandwidth / 1000).round() : null;

      // 确定实际音质
      BilibiliAudioQuality actualQuality = quality;
      for (final q in BilibiliAudioQuality.values) {
        if (q.id == audioId) {
          actualQuality = q;
          break;
        }
      }

      print('✅ 音频流获取成功');
      print('  - 实际音质: ${actualQuality.displayName} (ID=${actualQuality.id})');
      print('  - 枚举Bitrate: ${actualQuality.bitrate} kbps');
      print('  - 实际Bitrate: ${actualBitrate ?? "未知"} kbps (from API bandwidth)');
      print('  - 文件大小: ${(size / (1024 * 1024)).toStringAsFixed(2)} MB');
      print('  - URL: ${streamUrl.substring(0, 50)}...');
      
      return AudioStreamInfo(
        url: streamUrl,
        quality: actualQuality,
        size: size,
        actualBitrate: actualBitrate,
      );
    } catch (e) {
      if (e is BilibiliApiException) {
        rethrow;
      }
      throw BilibiliApiException(
        type: BilibiliApiExceptionType.apiError,
        message: '获取音频流失败: $e',
      );
    }
  }
  
  /// 获取视频的所有可用音质选项
  ///
  /// 返回包括 Dolby、FLAC 和普通音质在内的所有可用音质
  /// 获取视频可用音质列表（带详细信息）
  Future<List<AudioQualityStats>> getAvailableQualities({
    required String bvid,
    required int cid,
  }) async {
    print('========== 🔍 检测可用音质 ==========');
    print('  BVID: $bvid');
    print('  CID: $cid');

    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/x/player/wbi/playurl',
        params: {
          'bvid': bvid,
          'cid': cid.toString(),
          'fnval': '4048',       // 功能标志(4048=支持 DASH、杜比、Hi-Res)
          'fnver': '0',
          'fourk': '1',
          'qn': '127',           // 请求最高音质
        },
      );

      print('  ✅ API 请求成功');
      
      final dash = response['dash'] as Map<String, dynamic>?;

      if (dash == null) {
        print('  ⚠️ dash 为 null,这是老视频,只返回标准音质');
        // 老视频只有 durl,返回标准音质
        return [
          AudioQualityStats(
            quality: BilibiliAudioQuality.standard,
            bitrate: BilibiliAudioQuality.standard.bitrate,
            size: 0,
          )
        ];
      }

      print('  ✅ dash 存在,开始检测可用音质');
      final statsList = <AudioQualityStats>[];
      final addedQualities = <BilibiliAudioQuality>{};

      // 1. 检查 Dolby 杜比全景声
      final dolbyData = dash['dolby'];
      if (dolbyData != null && dolbyData is Map<String, dynamic>) {
        final dolbyAudio = dolbyData['audio'];
        if (dolbyAudio != null && dolbyAudio is List && dolbyAudio.isNotEmpty) {
          final stream = dolbyAudio.first as Map<String, dynamic>;
          final bandwidth = stream['bandwidth'] as int? ?? 0;
          final size = stream['size'] as int? ?? 0;
          
          statsList.add(AudioQualityStats(
            quality: BilibiliAudioQuality.dolby,
            bitrate: (bandwidth / 1000).round(),
            size: size,
          ));
          addedQualities.add(BilibiliAudioQuality.dolby);
          print('  ✅ Dolby 可用: ${(bandwidth / 1000).round()}kbps');
        }
      }

      // 2. 检查 Hi-Res/FLAC 无损
      final flacData = dash['flac'];
      if (flacData != null && flacData is Map<String, dynamic>) {
        final flacAudio = flacData['audio'];
        if (flacAudio != null && flacAudio is Map<String, dynamic>) {
          final bandwidth = flacAudio['bandwidth'] as int? ?? 0;
          final size = flacAudio['size'] as int? ?? 0;
          
          statsList.add(AudioQualityStats(
            quality: BilibiliAudioQuality.flac,
            bitrate: (bandwidth / 1000).round(),
            size: size,
          ));
          addedQualities.add(BilibiliAudioQuality.flac);
          print('  ✅ FLAC 可用: ${(bandwidth / 1000).round()}kbps');
        }
      }

      // 3. 检查普通音频流
      final audioList = dash['audio'] as List<dynamic>?;
      if (audioList != null && audioList.isNotEmpty) {
        for (final audio in audioList) {
          final audioMap = audio as Map<String, dynamic>;
          final audioId = audioMap['id'] as int;
          final bandwidth = audioMap['bandwidth'] as int? ?? 0;
          final size = audioMap['size'] as int? ?? 0;

          // 匹配音质 ID
          for (final quality in BilibiliAudioQuality.values) {
            if (quality.id == audioId && !addedQualities.contains(quality)) {
              statsList.add(AudioQualityStats(
                quality: quality,
                bitrate: (bandwidth / 1000).round(),
                size: size,
              ));
              addedQualities.add(quality);
              print('  ✅ ${quality.displayName} 可用: ${(bandwidth / 1000).round()}kbps');
              break;
            }
          }
        }
      }

      // 如果没有找到任何音质,返回标准音质
      if (statsList.isEmpty) {
        print('\n  ⚠️ 未找到任何可用音质,返回标准音质作为默认值');
        return [
          AudioQualityStats(
            quality: BilibiliAudioQuality.standard,
            bitrate: BilibiliAudioQuality.standard.bitrate,
            size: 0,
          )
        ];
      }

      // 按音质从高到低排序(bitrate 降序)
      statsList.sort((a, b) => b.bitrate.compareTo(a.bitrate));

      print('========== 🔍 音质检测完成 ==========\n');
      return statsList;
    } catch (e, stackTrace) {
      print('  ❌ 获取可用音质失败: $e');
      print(stackTrace);
      // 出错时返回标准音质
      return [
        AudioQualityStats(
          quality: BilibiliAudioQuality.standard,
          bitrate: BilibiliAudioQuality.standard.bitrate,
          size: 0,
        )
      ];
    }
  }
}

/// 音质统计信息
class AudioQualityStats {
  final BilibiliAudioQuality quality;
  final int bitrate; // kbps
  final int size;    // bytes

  AudioQualityStats({
    required this.quality,
    required this.bitrate,
    required this.size,
  });
}
