import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import 'common.dart';

class Explorer extends StatelessWidget {
  const Explorer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Explorer'), actions: [
        IconButton(
            onPressed: () {
              print('Should switch to camera app');
            },
            icon: const Icon(Icons.camera_alt))
      ]),
      body: SingleChildScrollView(
        child: Wrap(
            children: bookyDir.listSync().whereType<Directory>().map((dir) {
          final images = dir
              .listSync()
              .whereType<File>()
              .where((file) => path.extension(file.path) == '.jpg')
              .sorted((f1, f2) => f1.lastModifiedSync().compareTo(f2.lastModifiedSync()));
          return Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(path.basename(dir.path)),
                    Row(
                      children: images.map((img) => SizedBox(height: 100, child: Image.file(img))).toList(),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {},
              )
            ],
          );
        }).toList()),
      ),
    );
  }
}
