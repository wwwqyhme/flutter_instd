import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

Future<bool> requestStoragePermission(BuildContext context) async {
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
