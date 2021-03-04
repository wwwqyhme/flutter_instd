import 'dart:io';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as path;
import 'package:webview_cookie_manager/webview_cookie_manager.dart';

class InstdApi {
  final Dio _dio;
  factory InstdApi() {
    if (_instance == null) {
      Dio dio = Dio();
      dio.interceptors.add(_AuthenticationInterceptor());
      dio.interceptors.add(_UserAgentInterceptor());
      _instance = InstdApi._(dio);
    }
    return _instance;
  }

  InstdApi._(this._dio);

  static InstdApi _instance;

  Future download(Link link, String savePath,
      {ProgressCallback callback, CancelToken cancelToken}) {
    return _dio.download(link.url, savePath,
        onReceiveProgress: callback, cancelToken: cancelToken);
  }

  Future<List<Link>> parse(String url) async {
    ParsedUrl parsedUrl = parseUrl(url);
    if (parsedUrl == null) {
      return [];
    }
    if (parsedUrl.type == 'post') {
      return _getPost(parsedUrl);
    }
    return [];
  }

  Future<List<Link>> _getPost(ParsedUrl parsedUrl) async {
    String shortcode = parsedUrl.params[0];
    String url = 'https://www.instagram.com/p/$shortcode/?__a=1';
    Response<String> response;
    try {
      response = await _dio.get(url);
    } on DioError catch (e) {
      if (e.response == null) rethrow;
      if (e.response.statusCode == 404) {
        throw ResourceNotFoundException(parsedUrl);
      }
      rethrow;
    }
    String data = response.data;
    if (_needLogin(data)) {
      throw AuthenticationException();
    }
    var jsonData = json.decode(data);
    var media = jsonData['graphql']['shortcode_media'];
    List<Link> links = [];
    _parseLinks(media, links);
    return links;
  }

  static ParsedUrl parseUrl(String url) {
    Uri uri;
    try {
      uri = Uri.parse(url);
    } catch (e) {
      return null;
    }
    if (!uri.host.contains('instagram.com')) return null;
    String path = uri.path;
    if (path.startsWith("/p/") ||
        path.startsWith("/tv/") ||
        path.startsWith("/reel/")) {
      if (path.startsWith("/p/")) path = path.substring(3);
      if (path.startsWith("/tv/")) path = path.substring(4);
      if (path.startsWith("/reel/")) path = path.substring(6);
      int index = path.indexOf('/');
      if (index != -1) {
        path = path.substring(0, index);
      }
      return ParsedUrl("post", [path]);
    }

    return null;
  }

  bool _needLogin(String data) {
    return data.contains("\"viewerId\":null");
  }

  void _parseLinks(dynamic media, List<Link> collector) {
    String typeName = media['__typename'];
    if (typeName == 'GraphImage' || typeName == 'GraphVideo') {
      List displayResources = media['display_resources'];
      String thumbnailUrl = displayResources[0]["src"];
      if (typeName == 'GraphImage') {
        collector.add(Link(media['display_url'], false, thumbnailUrl));
      } else {
        collector.add(Link(media['video_url'], true, thumbnailUrl));
      }
    } else {
      List medias = media['edge_sidecar_to_children']['edges'];
      for (var media in medias) {
        _parseLinks(media['node'], collector);
      }
    }
  }
}

class ParsedUrl {
  final String type;
  final List<String> params;

  ParsedUrl(this.type, this.params);
}

class Link with EquatableMixin {
  final String url;
  final bool video;
  String thumbnailUrl;

  Link(this.url, this.video, this.thumbnailUrl);

  String getFileName() {
    String basename = path.basename(File(url).path);
    return basename.indexOf('?') > -1 ? basename.split('?')[0] : basename;
  }

  @override
  List<Object> get props => [url];
}

class AuthenticationException implements Exception {}

class ResourceNotFoundException implements Exception {
  final ParsedUrl parsedUrl;
  ResourceNotFoundException(this.parsedUrl);
}

class _UserAgentInterceptor extends Interceptor {
  static const String USER_AGENT =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.75 Safari/537.36";

  @override
  Future onRequest(RequestOptions options) async {
    options.headers[HttpHeaders.userAgentHeader] = USER_AGENT;
  }
}

class _AuthenticationInterceptor extends Interceptor {
  @override
  Future onRequest(RequestOptions options) async {
    var cookies =
        await WebviewCookieManager().getCookies('https://instagram.com');
    String cookie = getCookies(cookies);
    if (cookie.isNotEmpty) options.headers[HttpHeaders.cookieHeader] = cookie;
  }

  static String getCookies(List<Cookie> cookies) {
    return cookies.map((cookie) => "${cookie.name}=${cookie.value}").join('; ');
  }
}
