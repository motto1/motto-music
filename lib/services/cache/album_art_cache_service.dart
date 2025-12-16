import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 统一的封面缓存服务，负责将远程图片写入本地并返回可离线使用的路径。
class AlbumArtCacheService {
  AlbumArtCacheService._();

  static final AlbumArtCacheService instance = AlbumArtCacheService._();

   /// 判断给定 URL 是否为需要携带 B 站 Header（包括 Cookie）的图片地址。
   ///
   /// 目前规则与内部 _needsBilibiliHeaders 保持一致：凡 host 命中 bilibili.com / hdslb.com
   /// 的图片地址，都会被认为需要附加 B 站特有的请求头。
   static bool isBilibiliImageUrl(String? url) {
     if (url == null || url.isEmpty) return false;
     final uri = Uri.tryParse(url);
     if (uri == null) return false;
     return instance._needsBilibiliHeaders(uri.host);
   }

  Directory? _cacheDir;

  /// 确保传入的封面路径可在离线环境使用：
  /// - 空值或已是本地文件则原样返回
  /// - 远程地址将下载到缓存目录并返回本地路径
  Future<String?> ensureLocalPath(
    String? path, {
    String? cookie,
  }) async {
    if (path == null || path.isEmpty) return path;
    if (!_isRemote(path)) return path;

    final file = await _resolveCacheFile(path);
    if (await file.exists()) {
      return file.path;
    }

    final uri = Uri.tryParse(path);
    if (uri == null) return path;

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      if (_needsBilibiliHeaders(uri.host)) {
        request.headers.set('Referer', 'https://www.bilibili.com');
        request.headers.set(
          'User-Agent',
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        );
        if (cookie != null && cookie.isNotEmpty) {
          request.headers.set('Cookie', cookie);
        }
      }

      final response = await request.close();
      if (response.statusCode == HttpStatus.ok) {
        final bytes = await consolidateHttpClientResponseBytes(response);
        await file.writeAsBytes(bytes);
        return file.path;
      }
    } catch (e) {
      // 静默失败，调用方可保留原路径
    } finally {
      client.close(force: true);
    }
    return path;
  }

  bool _isRemote(String path) =>
      path.startsWith('http://') || path.startsWith('https://');

  bool _needsBilibiliHeaders(String host) =>
      host.contains('bilibili.com') || host.contains('hdslb.com');

  Future<File> _resolveCacheFile(String url) async {
    final dir = await _ensureCacheDir();
    final uri = Uri.parse(url);
    final extension = _inferExtension(uri.path);
    final hash = sha1.convert(utf8.encode(url)).toString();
    return File(p.join(dir.path, '$hash$extension'));
  }

  Future<Directory> _ensureCacheDir() async {
    if (_cacheDir != null && await _cacheDir!.exists()) {
      return _cacheDir!;
    }
    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(supportDir.path, 'cover_cache'));
    await dir.create(recursive: true);
    _cacheDir = dir;
    return dir;
  }

  String _inferExtension(String path) {
    final ext = p.extension(path).toLowerCase();
    const allowed = {'.jpg', '.jpeg', '.png', '.webp'};
    if (allowed.contains(ext)) {
      return ext;
    }
    return '.jpg';
  }
}
