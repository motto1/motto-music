import 'package:dio/dio.dart';
import 'cookie_manager.dart';
import 'bilibili_exception.dart';

/// Bilibili API 客户端
/// 
/// 负责与 Bilibili API 进行通信，自动处理 Cookie 注入和响应解析
class BilibiliApiClient {
  static const String baseUrl = 'https://api.bilibili.com';
  
  final Dio _dio;
  final CookieManager _cookieManager;
  
  BilibiliApiClient(this._cookieManager) : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 BiliApp/6.66.0',
      'Referer': 'https://www.bilibili.com',
      'Origin': 'https://www.bilibili.com',
      'Accept-Encoding': 'gzip',
    },
  )) {
    // 添加拦截器，自动注入 Cookie
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        options.headers['Accept-Encoding'] = 'gzip';

        final cookie = await _cookieManager.getCookieString();
        if (cookie.isNotEmpty) {
          options.headers['Cookie'] = cookie;
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        // 可以在这里添加统一的错误处理逻辑
        return handler.next(error);
      },
    ));
  }
  
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? params,
    String? fullUrl,
  }) async {
    try {
      final url = fullUrl ?? path;
      print('🌐 发起 GET 请求: $url');
      if (params != null && params.isNotEmpty) {
        print('📋 请求参数: $params');
      }
      
      // 打印请求头信息
      final cookie = await _cookieManager.getCookieString();
      print('🍪 Cookie: ${cookie.isNotEmpty ? cookie : "(空)"}');
      print('📱 User-Agent: ${_dio.options.headers['User-Agent']}');
      print('🔗 Referer: ${_dio.options.headers['Referer']}');
      
      final response = await _dio.get<Map<String, dynamic>>(
        url,
        queryParameters: params,
      );
      
      print('✅ 请求成功: HTTP ${response.statusCode}');
      
      return _handleResponse<T>(response);
    } on DioException catch (e) {
      print('❌ 请求失败: ${e.type}, ${e.message}');
      if (e.response != null) {
        print('   响应状态码: ${e.response!.statusCode}');
        print('   响应数据: ${e.response!.data}');
      }
      throw _handleDioException(e);
    }
  }
  
  Future<T> post<T>(
    String path, {
    Map<String, dynamic>? data,
    String? fullUrl,
    Map<String, dynamic>? headers,
  }) async {
    try {
      print('🌐 发起 POST 请求: ${fullUrl ?? path}');
      if (data != null && data.isNotEmpty) {
        print('📋 请求数据: $data');
      }
      
      // 打印请求头信息
      final cookie = await _cookieManager.getCookieString();
      print('🍪 Cookie: ${cookie.isNotEmpty ? cookie : "(空)"}');
      print('📱 User-Agent: ${_dio.options.headers['User-Agent']}');
      
      final options = Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: headers,
      );

      final response = await _dio.post<Map<String, dynamic>>(
        fullUrl ?? path,
        data: data,
        options: options,
      );
      
      print('✅ POST 请求成功: HTTP ${response.statusCode}');
      
      return _handleResponse<T>(response);
    } on DioException catch (e) {
      print('❌ POST 请求失败: ${e.type}, ${e.message}');
      if (e.response != null) {
        print('   响应状态码: ${e.response!.statusCode}');
        print('   响应数据: ${e.response!.data}');
      }
      throw _handleDioException(e);
    }
  }
  
  /// 带 CSRF 的 POST 请求
  /// 
  /// 自动从 Cookie 中提取 CSRF token 并添加到请求数据中
  Future<T> postWithCsrf<T>(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? headers,
  }) async {
    final csrf = await _cookieManager.getCsrfToken();
    
    if (csrf == null || csrf.isEmpty) {
      throw BilibiliApiException(
        message: '未找到 CSRF Token，请先登录',
        type: BilibiliApiExceptionType.notLoggedIn,
      );
    }
    
    final dataWithCsrf = Map<String, dynamic>.from(data ?? {});
    dataWithCsrf['csrf'] = csrf;
    
    return post<T>(path, data: dataWithCsrf, headers: headers);
  }
  
  /// 处理 Bilibili API 响应
  /// 
  /// Bilibili API 统一返回格式:
  /// {
  ///   "code": 0,           // 0 表示成功
  ///   "message": "success",
  ///   "data": {...}        // 实际数据
  /// }
  T _handleResponse<T>(Response<Map<String, dynamic>> response) {
    final data = response.data;
    
    if (data == null) {
      print('❌ API 返回数据为空');
      throw BilibiliApiException(
        message: 'API 返回数据为空',
        type: BilibiliApiExceptionType.parseError,
      );
    }
    
    final code = data['code'] as int?;
    final message = data['message']?.toString() ?? '';
    
    print('📦 API 响应: code=$code, message=$message');
    
    // 对于导航接口，未登录时返回 -101，但仍然有数据
    if (code != 0 && code != -101) {
      print('❌ API 返回错误: code=$code, message=$message');
      throw BilibiliApiException(
        message: message.isNotEmpty ? message : 'API 错误',
        code: code,
        rawData: data['data'],
        type: _getExceptionTypeFromCode(code),
      );
    }
    
    return data['data'] as T;
  }
  
  /// 处理 Dio 异常
  BilibiliApiException _handleDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return BilibiliApiException(
          message: '网络请求超时',
          type: BilibiliApiExceptionType.networkError,
        );
        
      case DioExceptionType.badResponse:
        return BilibiliApiException(
          message: 'HTTP ${error.response?.statusCode}: ${error.response?.statusMessage ?? ""}',
          code: error.response?.statusCode,
          type: BilibiliApiExceptionType.httpError,
        );
        
      case DioExceptionType.cancel:
        return BilibiliApiException(
          message: '请求已取消',
          type: BilibiliApiExceptionType.networkError,
        );
        
      default:
        return BilibiliApiException(
          message: error.message ?? '网络请求失败',
          type: BilibiliApiExceptionType.networkError,
        );
    }
  }
  
  /// 根据错误代码判断异常类型
  BilibiliApiExceptionType _getExceptionTypeFromCode(int? code) {
    if (code == null) return BilibiliApiExceptionType.unknown;
    
    switch (code) {
      case -101:  // 账号未登录
      case -111:  // csrf 校验失败
        return BilibiliApiExceptionType.notLoggedIn;
        
      case -352:  // 风控校验失败
      case -799:  // 请求过于频繁
        return BilibiliApiExceptionType.apiError;
        
      default:
        return BilibiliApiExceptionType.apiError;
    }
  }

  /// 获取重定向后的URL（用于解析 b23.tv 短链）
  /// 
  /// [shortUrl] 短链接
  /// 
  /// 返回重定向后的真实URL
  Future<String> getRedirectUrl(String shortUrl) async {
    try {
      // 创建一个不跟随重定向的 Dio 实例
      final dioNoRedirect = Dio(BaseOptions(
        followRedirects: false,
        validateStatus: (status) => status! < 400,
      ));

      final response = await dioNoRedirect.get(shortUrl);
      
      // 从响应头中获取 Location 字段
      final location = response.headers.value('location');
      
      if (location != null && location.isNotEmpty) {
        return location;
      }
      
      // 如果没有重定向，返回原URL
      return shortUrl;
      
    } on DioException catch (e) {
      // 如果是302/301重定向，从响应头中获取Location
      if (e.response != null && 
          (e.response!.statusCode == 302 || e.response!.statusCode == 301)) {
        final location = e.response!.headers.value('location');
        if (location != null && location.isNotEmpty) {
          return location;
        }
      }
      
      throw BilibiliApiException(
        message: '获取重定向URL失败: ${e.message}',
        type: BilibiliApiExceptionType.networkError,
      );
    }
  }
}
