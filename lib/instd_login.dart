import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_cookie_manager/webview_cookie_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';

class InstagramLoginRoute extends StatefulWidget {
  @override
  InstagramLoginRouteState createState() => InstagramLoginRouteState();
}

class InstagramLoginRouteState extends State<InstagramLoginRoute> {
  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) WebView.platform = SurfaceAndroidWebView();
  }

  @override
  Widget build(BuildContext context) {
    WebviewCookieManager().clearCookies();
    return WebView(
        javascriptMode: JavascriptMode.unrestricted,
        initialUrl: 'https://www.instagram.com/accounts/login/',
        navigationDelegate: (navigation) async {
          List<Cookie> cookies =
              await WebviewCookieManager().getCookies('https://instagram.com');

          for (var cookie in cookies) {
            if (cookie.name == 'ds_user_id') {
              Navigator.pop(context, true);
              return NavigationDecision.prevent;
            }
          }

          return NavigationDecision.navigate;
        });
  }
}
