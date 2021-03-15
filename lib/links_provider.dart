import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';

import 'instd_api.dart';

class DownloadableLinksProvider extends ChangeNotifier {
  final List<DownloadableLink> _links = [];
  bool _deleteAfterComplete = false;

  bool get isEmpty => _links.isEmpty;
  int get size => _links.length;
  UnmodifiableListView<DownloadableLink> get items =>
      UnmodifiableListView(_links);

  bool setDeleteAfterComplete(bool deleteAfterComplete) {
    _deleteAfterComplete = deleteAfterComplete;
    if (deleteAfterComplete) {
      return _removeComplete();
    }
    return false;
  }

  void add(List<Link> links) {
    bool notify = false;
    for (var link in links) {
      if (!_contain(link)) {
        notify = true;
        DownloadableLink downloadableLink = DownloadableLink(link);
        downloadableLink.addListener(() {
          if (_deleteAfterComplete && downloadableLink.isComplete) {
            _links.remove(downloadableLink);
            notifyListeners();
          }
        });
        _links.add(downloadableLink);
      }
    }
    if (!notify) return;
    notifyListeners();
  }

  void downloadAll() {
    for (var downloadableLink in _links) {
      if (downloadableLink.isComplete || downloadableLink.isStart) {
        continue;
      }
      downloadableLink.start();
    }
  }

  void delete(DownloadableLink link) {
    if (_links.remove(link)) notifyListeners();
  }

  bool _removeComplete() {
    int size = _links.length;
    _links.removeWhere((element) => element.isComplete);
    bool needNotify = size != _links.length;
    if (needNotify) notifyListeners();
    return needNotify;
  }

  bool _contain(Link link) {
    for (var downloadableLink in _links) {
      if (downloadableLink.link == link) {
        return true;
      }
    }
    return false;
  }
}

class DownloadableLink extends ChangeNotifier with EquatableMixin {
  final Link link;
  bool isStart = false;
  bool isComplete = false;
  bool isFail = false;
  double percent = -1;

  CancelToken _cancelToken;
  DownloadableLink(this.link);

  void start() {
    if (this.isStart || this.isComplete) return;
    this.isFail = false;
    this.isComplete = false;
    this.percent = -1;
    this._cancelToken = CancelToken();
    this.isStart = true;
    notifyListeners();
    getTemporaryDirectory()
        .then((dir) => InstdApi()
                .download(link, dir.path + '/' + link.getFileName(),
                    callback: (count, total) {
              if (total != -1) {
                if (!isStart) return;
                this.percent = total == -1 ? -1 : 100 * count / total;
                notifyListeners();
              }
            }, cancelToken: _cancelToken).then((value) {
              ImageGallerySaver.saveFile(dir.path + '/' + link.getFileName());
            }).then((value) {
              this.isComplete = true;
              this.isStart = false;
              this.isFail = false;
              this.percent = 100;
              this._cancelToken = null;
            }))
        .then((value) => notifyListeners())
        .catchError((e) => _markFailStatus(e));
  }

  void _markFailStatus(dynamic e) {
    this.isComplete = false;
    this.isStart = false;
    this._cancelToken = null;
    this.percent = -1;
    if (e is DioError) {
      if (e.type == DioErrorType.CANCEL) {
        this.isFail = false;
        notifyListeners();
        return;
      }
    }
    this.isFail = true;
    notifyListeners();
  }

  void cancel() {
    if (this._cancelToken != null) this._cancelToken.cancel();
  }

  @override
  List<Object> get props => [link, isStart, isComplete, isFail, percent];
}
