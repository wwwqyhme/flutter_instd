import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'links_provider.dart';
import 'permission.dart';

class InstdGridView extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _InstdGridViewState();
  }
}

class _InstdGridViewState extends State<InstdGridView> {
  final SliverGridDelegate _gridViewDelegate =
      SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 1,
          crossAxisSpacing: 1,
          childAspectRatio: 1);

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadableLinksProvider>(
        builder: (context, provider, child) {
      int size = provider.size;
      List<DownloadableLink> links = provider.items;
      return GridView.builder(
          gridDelegate: _gridViewDelegate,
          itemCount: size,
          itemBuilder: (context, index) {
            if (index >= size) return null;
            DownloadableLink downloadableLink = links[index];
            return GestureDetector(
                child: Stack(
                    alignment: AlignmentDirectional.bottomEnd,
                    children: <Widget>[
                      Container(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height,
                        child: Image.network(
                          downloadableLink.link.thumbnailUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) =>
                              progress == null
                                  ? child
                                  : Center(child: CircularProgressIndicator()),
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(Icons.broken_image),
                        ),
                      ),
                      _StatusWidget(
                          downloadableLink,
                          (link) => FractionallySizedBox(
                                heightFactor:
                                    link.percent == -1 ? 0 : link.percent / 100,
                                child: Container(
                                  color: Colors.green.withOpacity(0.5),
                                ),
                              )),
                      _StatusWidget(downloadableLink,
                          (link) => _createDownloadStatusWidget(link)),
                      Visibility(
                        visible: downloadableLink.link.video,
                        child: Positioned(
                          top: 5,
                          left: 5,
                          child: Icon(Icons.video_call_rounded,
                              color: Colors.white),
                        ),
                      )
                    ]),
                onTap: () async {
                  if (downloadableLink.isComplete) return;
                  if (downloadableLink.isStart) {
                    downloadableLink.cancel();
                    return;
                  }
                  if (await requestStoragePermission(context)) {
                    downloadableLink.start();
                  }
                });
          });
    });
  }

  Widget _createDownloadStatusWidget(DownloadableLink link) {
    Widget child = link.isFail
        ? Icon(Icons.error, color: Colors.red)
        : link.isComplete
            ? Icon(Icons.file_download_done, color: Colors.white)
            : link.isStart
                ? Icon(Icons.stop, color: Colors.orange)
                : Icon(Icons.file_download, color: Colors.white);
    return Positioned(
      right: 5,
      top: 5,
      child: child,
    );
  }
}

typedef StatusWidgetBuilder = Widget Function(DownloadableLink link);

class _StatusWidget extends StatefulWidget {
  final DownloadableLink _link;
  final StatusWidgetBuilder _builder;
  _StatusWidget(this._link, this._builder);
  @override
  State<StatefulWidget> createState() => _StatusWidgetState();
}

class _StatusWidgetState extends State<_StatusWidget> {
  void _listener() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget._link.addListener(_listener);
  }

  @override
  void dispose() {
    super.dispose();
    widget._link.removeListener(_listener);
  }

  @override
  Widget build(BuildContext context) {
    return widget._builder(widget._link);
  }
}
