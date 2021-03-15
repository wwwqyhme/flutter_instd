import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

typedef DialogRoutePredicate = bool Function(DialogRoute route);

class Util {
  static const LOADING_MASK_LABEL = 'loadingMask';
  static Future<bool> requestStoragePermission(BuildContext context) async {
    if (!await Permission.storage.request().isGranted) {
      if (await Permission.storage.status.isPermanentlyDenied) {
        openAppSettings();
      } else {
        AlertDialog alert = AlertDialog(
          content: new Row(
            children: [
              Icon(Icons.error),
              Container(
                  margin: EdgeInsets.only(left: 7), child: Text("请授予文件写入权限")),
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
      return false;
    }
    return true;
  }

  static void loadingDialog(BuildContext context, {String message}) {
    closeDialogs(context);
    AlertDialog alert = AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          Container(
              margin: EdgeInsets.only(left: 7), child: Text(message ?? '正在加载')),
        ],
      ),
    );
    showDialog(
      barrierLabel: LOADING_MASK_LABEL,
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return WillPopScope(onWillPop: () async => false, child: alert);
      },
    );
  }

  static void closeLoadingDialogIfNotClosed(BuildContext context) {
    closeDialogIfNotClosed(
        context, (route) => route.barrierLabel == LOADING_MASK_LABEL);
  }

  static void confirm(BuildContext context, VoidCallback onYes,
      {String title, String content, VoidCallback onNo}) {
    if (title == null && content == null) throw '标题或者内容至少一项不为空';
    _ConfirmDialog(context, onYes, title: title, content: content, onNo: onNo)
        .show();
  }

  static void alertError(BuildContext context, String message) {
    closeDialogs(context);
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

  static void closeDialogs(BuildContext context,
      {bool useRootNavigator = true}) {
    closeDialogIfNotClosed(context, (route) => true,
        useRootNavigator: useRootNavigator);
  }

  static void closeDialogIfNotClosed(
      BuildContext context, DialogRoutePredicate predicate,
      {bool useRootNavigator = true}) {
    bool isClosed = false;
    Navigator.of(context, rootNavigator: useRootNavigator).popUntil((route) {
      if (isClosed) return true;
      if (route is DialogRoute && predicate(route)) {
        return false;
      }
      isClosed = true;
      return true;
    });
  }
}

class _ConfirmDialog {
  static const CONFIRM_LABEL = 'confirm';

  final String title;
  final String content;
  final VoidCallback onYes;
  final VoidCallback onNo;
  final BuildContext context;
  bool clicked = false;
  _ConfirmDialog(this.context, this.onYes,
      {this.title, this.content, this.onNo});

  void show() {
    Util.closeDialogs(context);
    AlertDialog alert = AlertDialog(
      title: Visibility(
        visible: title != null,
        child: Text(title ?? ''),
      ),
      content: Visibility(
        visible: content != null,
        child: Text(content ?? ''),
      ),
      actions: <Widget>[
        new TextButton(
          onPressed: () {
            clicked = true;
            Util.closeDialogIfNotClosed(
                context, (route) => route.barrierLabel == CONFIRM_LABEL);
            if (onNo != null) onNo();
          },
          child: Text('否'),
        ),
        TextButton(
          onPressed: () {
            clicked = true;
            Util.closeDialogIfNotClosed(
                context, (route) => route.barrierLabel == CONFIRM_LABEL);
            onYes();
          },
          child: Text('是'),
        ),
      ],
    );

    showDialog(
      barrierLabel: CONFIRM_LABEL,
      barrierDismissible: true,
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    ).then((value) {
      if (!clicked && onNo != null) onNo();
    });
  }
}
