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
import 'util.dart';

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
  var controller = TextEditingController();
  String lastUrl;
  bool deleteAfterDownloadComplete = false;

  @override
  void dispose() {
    super.dispose();
    controller.dispose();
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
              if (data != lastUrl) parse(context, data);
            }),
            Container(
              child: Padding(
                padding: EdgeInsets.only(left: 20, right: 20, bottom: 10),
                child: Builder(builder: (context) {
                  return _ClearableTextField(controller, (value) {
                    parse(context, value);
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
                          value: deleteAfterDownloadComplete,
                          onChanged: (value) {
                            deleteAfterDownloadComplete = value;
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

  void parse(BuildContext context, String url) {
    ParsedUrl parsedUrl = InstdApi.parseUrl(url);
    if (parsedUrl == null) {
      controller.text = '';
      alertError('无效的地址');
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
    lastUrl = url;
    InstdApi().parse(url).then((value) {
      Navigator.pop(context);
      controller.text = '';
      Provider.of<DownloadableLinksProvider>(context, listen: false).add(value);
    }).catchError((e) {
      Navigator.pop(context);
      if (e is DioError) {
        alertError('网络异常');
      } else if (e is ResourceNotFoundException) {
        String message = '帖子不存在';
        alertError(message);
      } else if (e is AuthenticationException) {
        Navigator.pushNamed(context, "login").then((value) {
          if (value != true)
            alertError('登录失败');
          else if (lastUrl != null) parse(context, lastUrl);
        });
      } else {
        alertError('系统异常');
        debugPrint(e.toString());
      }
    });
  }

  void alertError(String message) {
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

typedef _ClipbardDataCallback = void Function(
    BuildContext context, String data);

class _ClipboardReadWidget extends StatefulWidget {
  final _ClipbardDataCallback callback;
  _ClipboardReadWidget(this.callback);
  @override
  State<StatefulWidget> createState() => _ClipboardReadWidgetState();
}

class _ClipboardReadWidgetState extends State<_ClipboardReadWidget>
    with WidgetsBindingObserver {
  FocusNode focusNode;

  void focusListener() async {
    if (focusNode.hasFocus) {
      readFromClipboard();
    }
  }

  Future<bool> readFromClipboard() async {
    ClipboardData clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData != null) {
      if (InstdApi.parseUrl(clipboardData.text) != null)
        widget.callback(context, clipboardData.text);
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    focusNode = FocusNode();
    focusNode.addListener(focusListener);
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
    focusNode.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      if (!await readFromClipboard()) {
        FocusScope.of(context).requestFocus(focusNode);
      }
    }
    if (state == AppLifecycleState.inactive) {
      focusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox.shrink();
}

class _ClearableTextField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  _ClearableTextField(this.controller, this.onSubmitted);

  @override
  State<StatefulWidget> createState() => _ClearableTextFieldState();
}

class _ClearableTextFieldState extends State<_ClearableTextField> {
  bool visible = false;

  void changeListener() {
    setState(() {
      visible = widget.controller.text != '';
    });
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(changeListener);
  }

  @override
  void dispose() {
    super.dispose();
    widget.controller.removeListener(changeListener);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
        controller: widget.controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: '地址',
          suffixIcon: Visibility(
              visible: visible,
              child: IconButton(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                padding: EdgeInsets.only(top: 15),
                onPressed: () {
                  widget.controller.text = '';
                  setState(() {
                    visible = false;
                  });
                },
                icon: Icon(Icons.clear),
              )),
        ),
        onSubmitted: widget.onSubmitted);
  }
}
