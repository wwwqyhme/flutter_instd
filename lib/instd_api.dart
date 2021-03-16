import 'dart:io';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as path;
import 'package:webview_cookie_manager/webview_cookie_manager.dart';

class InstdApi {
  static const APP_ID = '1217981644879628';
  static const String USER_AGENT =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.75 Safari/537.36";

  final Dio _dio;
  factory InstdApi() {
    if (_instance == null) {
      Dio dio = Dio(BaseOptions(headers: {
        HttpHeaders.userAgentHeader: USER_AGENT,
        'x-ig-app-id': APP_ID
      }));
      dio.interceptors.add(_AuthenticationInterceptor());
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

    if (parsedUrl.type == 'story') {
      return _getStory(parsedUrl);
    }
    return [];
  }

  Future<List<Link>> _getStory(ParsedUrl parsedUrl) async {
    String username = parsedUrl.params[0];
    String userId = await _getUserId(username);
    String url =
        'https://i.instagram.com/api/v1/feed/reels_media/?reel_ids=$userId';
    Response<String> response = await _dio.get(url);
    var jsonData = json.decode(response.data);
    String status = jsonData['status'];
    if (status != 'ok') throw Exception('stories解析失败:$response.data');
    var userReel = jsonData['reels'][userId] ??
        (throw ResourceNotFoundException('用户没有快拍'));
    List items = userReel['items'];
    List<Link> links = [];
    for (Map item in items) {
      links.add(_getBestLink(item));
    }
    return links;
  }

  Link _getBestLink(Map item) {
    List images = _getImageVersions(item);
    String thumbnail = images[images.length - 1]['url'];
    for (String key in item.keys) {
      if (key.startsWith('video_versions')) {
        return Link(item[key][0]['url'], true, thumbnail);
      }
    }
    return Link(images[0]['url'], false, thumbnail);
  }

  List _getImageVersions(Map item) {
    for (String key in item.keys) {
      if (key.startsWith('image_versions')) {
        return item[key]['candidates'];
      }
    }
    throw Exception('解析失败，没有符合条件的资源:$item');
  }

  Future<String> _getUserId(String username) async {
    String url = 'https://www.instagram.com/$username/?__a=1';
    Response<String> response;
    try {
      response = await _dio.get(url);
    } on DioError catch (e) {
      if (e.response != null && e.response.statusCode == 404)
        throw ResourceNotFoundException('用户不存在');
      rethrow;
    }
    String data = response.data;
    if (_needLogin(data)) {
      throw AuthenticationException();
    }
    var jsonData = json.decode(data);
    return jsonData['graphql']['user']['id'];
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
        throw ResourceNotFoundException('帖子不存在');
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
      return ParsedUrl(url, "post", [path]);
    }
    if (path.startsWith("/stories/")) {
      path = path.substring(9);
      int index = path.indexOf('/');
      if (index != -1) {
        path = path.substring(0, index);
      }
      return ParsedUrl(url, "story", [path]);
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

class ParsedUrl with EquatableMixin {
  final String url;
  final String type;
  final List<String> params;

  ParsedUrl(this.url, this.type, this.params);

  @override
  List<Object> get props => [type, params];
}

class Link with EquatableMixin {
  final String url;
  final bool video;
  String thumbnailUrl;
  get name => _getFileName();

  Link(this.url, this.video, this.thumbnailUrl);

  String _getFileName() {
    String basename = path.basename(File(url).path);
    return basename.indexOf('?') > -1 ? basename.split('?')[0] : basename;
  }

  @override
  List<Object> get props => [name];
}

class AuthenticationException implements Exception {}

class ResourceNotFoundException implements Exception {
  final String message;
  ResourceNotFoundException(this.message);
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
