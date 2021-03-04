import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'links_provider.dart';
import 'instd_view.dart';
import 'package:provider/provider.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import 'instd_login.dart';
import 'instd_api.dart';
import 'permission.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Instd',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        routes: {
          'login': (context) => InstagramLoginRoute(),
          '/': (context) => MyHomePage(title: 'Instd')
        });
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var _controller = TextEditingController();
  String _lastUrl;
  bool _deleteAfterDownloadComplete = false;

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text('Instd'),
      ),
      body: ChangeNotifierProvider(
          create: (context) => DownloadableLinksProvider(),
          child: Column(children: <Widget>[
            _ClipboardReadWidget((context, data) {
              if (data != _lastUrl) _parse(context, data);
            }),
            Container(
              child: Padding(
                padding: EdgeInsets.only(left: 20, right: 20, bottom: 10),
                child: Builder(builder: (context) {
                  return _ClearableTextField(_controller, (value) {
                    _parse(context, value);
                  });
                }),
              ),
            ),
            Consumer<DownloadableLinksProvider>(
                builder: (context, provider, child) {
              return Visibility(
                child: Padding(
                    padding: EdgeInsets.only(left: 20, right: 10),
                    child: Row(children: [
                      Text('下载完成后从界面删除'),
                      Builder(builder: (context) {
                        return Checkbox(
                          value: _deleteAfterDownloadComplete,
                          onChanged: (value) {
                            _deleteAfterDownloadComplete = value;
                            if (!provider.setDeleteAfterComplete(value)) {
                              (context as Element).markNeedsBuild();
                            }
                          },
                        );
                      }),
                      Spacer(),
                      Builder(builder: (context) {
                        return TextButton(
                          onPressed: () async {
                            if (await requestStoragePermission(context)) {
                              provider.downloadAll();
                            }
                          },
                          child: Text('全部下载'),
                        );
                      }),
                    ])),
                visible: !provider.isEmpty,
              );
            }),
            Container(
                child: Expanded(
                    flex: 1,
                    child: Padding(
                      padding: EdgeInsets.only(left: 20, right: 20, bottom: 20),
                      child: InstdGridView(),
                    )))
          ])),
    );
  }

  void _parse(BuildContext context, String url) {
    ParsedUrl parsedUrl = InstdApi.parseUrl(url);
    if (parsedUrl == null) {
      _controller.text = '';
      _alertError('无效的地址');
      return;
    }
    AlertDialog alert = AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          Container(
              margin: EdgeInsets.only(left: 7), child: Text("正在获取图片|视频...")),
        ],
      ),
    );
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return WillPopScope(onWillPop: () async => false, child: alert);
      },
    );
    _lastUrl = url;
    InstdApi().parse(url).then((value) {
      Navigator.pop(context);
      _controller.text = '';
      Provider.of<DownloadableLinksProvider>(context, listen: false).add(value);
    }).catchError((e) {
      Navigator.pop(context);
      if (e is DioError) {
        _alertError('网络异常');
      } else if (e is ResourceNotFoundException) {
        String message = '帖子不存在';
        _alertError(message);
      } else if (e is AuthenticationException) {
        Navigator.pushNamed(context, "login").then((value) {
          if (value != true)
            _alertError('登录失败');
          else if (_lastUrl != null) _parse(context, _lastUrl);
        });
      } else {
        _alertError('系统异常');
        debugPrint(e.toString());
      }
    });
  }

  void _alertError(String message) {
    AlertDialog alert = AlertDialog(
      content: Row(
        children: [
          Icon(Icons.error),
          Container(margin: EdgeInsets.only(left: 7), child: Text(message)),
        ],
      ),
    );
    showDialog(
      context: context,
      builder: (context) {
        return alert;
      },
    );
  }
}

typedef ClipbardDataCallback = void Function(BuildContext context, String data);

class _ClipboardReadWidget extends StatefulWidget {
  final ClipbardDataCallback _callback;
  _ClipboardReadWidget(this._callback);
  @override
  State<StatefulWidget> createState() => _ClipboardReadWidgetState();
}

class _ClipboardReadWidgetState extends State<_ClipboardReadWidget>
    with WidgetsBindingObserver {
  var _focusNode = FocusNode();

  void _focusListener() async {
    if (_focusNode.hasFocus) {
      _readFromClipboard();
    }
  }

  Future<bool> _readFromClipboard() async {
    ClipboardData clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData != null) {
      if (InstdApi.parseUrl(clipboardData.text) != null)
        widget._callback(context, clipboardData.text);
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focusNode.addListener(_focusListener);
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.removeListener(_focusListener);
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      if (!await _readFromClipboard()) {
        FocusScope.of(context).requestFocus(_focusNode);
      }
    }
    if (state == AppLifecycleState.inactive) {
      _focusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox.shrink();
}

class _ClearableTextField extends StatefulWidget {
  final TextEditingController _controller;
  final ValueChanged<String> _onSubmitted;

  _ClearableTextField(this._controller, this._onSubmitted);

  @override
  State<StatefulWidget> createState() {
    return _ClearableTextFieldState();
  }
}

class _ClearableTextFieldState extends State<_ClearableTextField> {
  bool _visible = false;

  void _changeListener() {
    setState(() {
      _visible = widget._controller.text != '';
    });
  }

  @override
  void initState() {
    super.initState();
    widget._controller.addListener(_changeListener);
  }

  @override
  void dispose() {
    super.dispose();
    widget._controller.removeListener(_changeListener);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
        controller: widget._controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: '地址',
          suffixIcon: Visibility(
              visible: _visible,
              child: IconButton(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                padding: EdgeInsets.only(top: 15),
                onPressed: () {
                  widget._controller.text = '';
                  setState(() {
                    _visible = false;
                  });
                },
                icon: Icon(Icons.clear),
              )),
        ),
        onSubmitted: widget._onSubmitted);
  }
}
