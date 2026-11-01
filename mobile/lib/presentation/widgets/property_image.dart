import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/services/replica_controller.dart';
import '../../data/services/replica_store.dart';

class PropertyImage extends StatelessWidget {
  const PropertyImage(
    this.url, {
    required this.height,
    this.fit = BoxFit.cover,
    this.errorBuilder,
    super.key,
  });
  final String url;
  final double height;
  final BoxFit fit;
  final ImageErrorWidgetBuilder? errorBuilder;
  @override
  Widget build(BuildContext context) {
    final store = context.watch<ReplicaStore?>();
    Widget placeholder() => SizedBox(
      height: height,
      child: const Center(child: Icon(Icons.home_outlined, size: 48)),
    );
    Widget network() => store?.online == false
        ? placeholder()
        : Image.network(
            url,
            height: height,
            fit: fit,
            errorBuilder: errorBuilder ?? (_, _, _) => placeholder(),
          );
    if (store?.account == null) return network();
    return FutureBuilder<File?>(
      future: ReplicaController.imageFile(store!.account!, url),
      builder: (c, snapshot) {
        final file = snapshot.data;
        if (file != null && file.existsSync())
          return Image.file(
            file,
            height: height,
            fit: fit,
            errorBuilder: (_, _, _) => placeholder(),
          );
        return network();
      },
    );
  }
}
