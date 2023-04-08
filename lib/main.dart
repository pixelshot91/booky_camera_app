import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';

import 'common.dart' as common;

/// Camera example home widget.
class CameraExampleHome extends StatefulWidget {
  /// Default Constructor
  const CameraExampleHome({Key? key}) : super(key: key);

  @override
  State<CameraExampleHome> createState() {
    return _CameraExampleHomeState();
  }
}

/// Returns a suitable camera icon for [direction].
IconData getCameraLensIcon(CameraLensDirection direction) {
  switch (direction) {
    case CameraLensDirection.back:
      return Icons.camera_rear;
    case CameraLensDirection.front:
      return Icons.camera_front;
    case CameraLensDirection.external:
      return Icons.camera;
  }
  // This enum is from a different package, so a new value could be added at
  // any time. The example should keep working if that happens.
  // ignore: dead_code
  return Icons.camera;
}

void _logError(String code, String? message) {
  // ignore: avoid_print
  print('Error: $code${message == null ? '' : '\nError Message: $message'}');
}

class _CameraExampleHomeState extends State<CameraExampleHome> with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? controller;
  XFile? imageFile;
  String bundleName = DateTime.now().toIso8601String().replaceAll(':', '_');

  String get getBundlePath => '/storage/emulated/0/DCIM/booky/$bundleName';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _onNewCameraSelected(_cameras.first);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // #docregion AppLifecycle
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _onNewCameraSelected(cameraController.description);
    }
  }
  // #enddocregion AppLifecycle

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booky Camera app'), actions: [
        PopupMenuButton(
          itemBuilder: (_) => [
            PopupMenuItem(
                child: const Text('Change camera'),
                onTap: () async {
                  await Future.delayed(const Duration(seconds: 0), () async {
                    await showDialog(
                      context: context,
                      builder: (BuildContext _) => SimpleDialog(
                          title: const Text('Select camera'),
                          children: _cameras
                              .where((c) => c.lensDirection == CameraLensDirection.back)
                              .map((c) => SimpleDialogOption(
                                    onPressed: () => _onNewCameraSelected(c),
                                    child: Text('Camera ${c.name}'),
                                  ))
                              .toList()),
                    );
                  });
                })
          ],
        ),
      ]),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(1.0),
              child: Center(
                child: _cameraPreviewWidget(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(5.0),
            child: Row(
              children: <Widget>[
                _thumbnailWidget(),
                _addMetadataButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Display the preview from the camera (or a message if the preview is not available).
  Widget _cameraPreviewWidget() {
    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return const Text(
        'Tap a camera',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24.0,
          fontWeight: FontWeight.w900,
        ),
      );
    } else {
      return CameraPreview(
        controller!,
        child: GestureDetector(
          onTapDown: (TapDownDetails details) => _onTakePictureButtonPressed(),
        ),
      );
    }
  }

  /// Display the thumbnail of the captured image or video.
  Widget _thumbnailWidget() {
    final imageFile = this.imageFile;
    if (imageFile == null) {
      return Container();
    }

    try {
      final images = Directory(getBundlePath).listSync().where((file) => path.extension(file.path) == '.jpg');
      return Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: images
                .map((imgFile) => SizedBox(width: 64.0, height: 64.0, child: Image.file(File(imgFile.path))))
                .toList(),
          ),
        ),
      );
    } on PathNotFoundException catch (e) {
      showInSnackBar('PathNotFoundException: $e');
      return Text('$e');
    }
  }

  Widget _addMetadataButton() => IconButton(
      icon: const Icon(Icons.keyboard_arrow_right),
      onPressed: () => showDialog(
          context: context,
          builder: (BuildContext context) => MetadataWidget(
                bundlePath: getBundlePath,
              )));

  /// Display a row of toggle to select the camera (or a message if no camera is available).
  String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

  void showInSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
    if (controller == null) {
      return;
    }

    final CameraController cameraController = controller!;

    final Offset offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    cameraController.setExposurePoint(offset);
    cameraController.setFocusPoint(offset);
  }

  Future<void> _onNewCameraSelected(CameraDescription cameraDescription) async {
    final CameraController? oldController = controller;
    if (oldController != null) {
      // `controller` needs to be set to null before getting disposed,
      // to avoid a race condition when we use the controller that is being
      // disposed. This happens when camera permission dialog shows up,
      // which triggers `didChangeAppLifecycleState`, which disposes and
      // re-creates the controller.
      controller = null;
      await oldController.dispose();
    }

    final CameraController cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.max,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    controller = cameraController;

    // If the controller is updated then update the UI.
    cameraController.addListener(() {
      if (mounted) {
        setState(() {});
      }
      if (cameraController.value.hasError) {
        showInSnackBar('Camera error ${cameraController.value.errorDescription}');
      }
    });

    try {
      await cameraController.initialize();
    } on CameraException catch (e) {
      switch (e.code) {
        case 'CameraAccessDenied':
          showInSnackBar('You have denied camera access.');
          break;
        case 'CameraAccessDeniedWithoutPrompt':
          // iOS only
          showInSnackBar('Please go to Settings app to enable camera access.');
          break;
        case 'CameraAccessRestricted':
          // iOS only
          showInSnackBar('Camera access is restricted.');
          break;
        case 'AudioAccessDenied':
          showInSnackBar('You have denied audio access.');
          break;
        case 'AudioAccessDeniedWithoutPrompt':
          // iOS only
          showInSnackBar('Please go to Settings app to enable audio access.');
          break;
        case 'AudioAccessRestricted':
          // iOS only
          showInSnackBar('Audio access is restricted.');
          break;
        default:
          _showCameraException(e);
          break;
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _onTakePictureButtonPressed() {
    takePicture().then((XFile? file) async {
      if (mounted) {
        if (file != null) {
          GallerySaver.saveImage(file.path, albumName: "booky/$bundleName", toDcim: true).then((bool? success) {
            if (success != true) {
              showInSnackBar('Error when saving image');
            } else {
              setState(() {
                imageFile = file;
              });
            }
          });
        }
      }
    });
  }

  Future<void> onCaptureOrientationLockButtonPressed() async {
    try {
      if (controller != null) {
        final CameraController cameraController = controller!;
        if (cameraController.value.isCaptureOrientationLocked) {
          await cameraController.unlockCaptureOrientation();
          showInSnackBar('Capture orientation unlocked');
        } else {
          await cameraController.lockCaptureOrientation();
          showInSnackBar(
              'Capture orientation locked to ${cameraController.value.lockedCaptureOrientation.toString().split('.').last}');
        }
      }
    } on CameraException catch (e) {
      _showCameraException(e);
    }
  }

  Future<XFile?> takePicture() async {
    final CameraController? cameraController = controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      showInSnackBar('Error: select a camera first.');
      return null;
    }

    if (cameraController.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }

    try {
      final XFile file = await cameraController.takePicture();
      return file;
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
  }

  void _showCameraException(CameraException e) {
    _logError(e.code, e.description);
    showInSnackBar('Error: ${e.code}\n${e.description}');
  }
}

class MetadataWidget extends StatefulWidget {
  const MetadataWidget({required this.bundlePath});
  final String bundlePath;

  @override
  State<MetadataWidget> createState() => _MetadataWidgetState();
}

class _MetadataWidgetState extends State<MetadataWidget> {
  var metadata = common.Metadata();

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('Add the final metadata'),
      children: [
        TextFormField(
          initialValue: '',
          onChanged: (newText) => setState(() => metadata.weightGrams = int.parse(newText)),
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            icon: Icon(Icons.scale),
            labelText: 'Weight in grams',
          ),
          style: const TextStyle(fontSize: 20),
        ),
        DropdownButton<common.ItemState>(
            hint: const Text('Book state'),
            value: metadata.itemState,
            items: common.ItemState.values.map((s) => DropdownMenuItem(value: s, child: Text(s.loc))).toList(),
            onChanged: (state) => setState(() {
                  metadata.itemState = state;
                })),
        IconButton(
            icon: const Icon(Icons.save),
            onPressed: () async {
              final managePerm = await Permission.manageExternalStorage.request();
              print('managePerm = $managePerm');
              File(path.join(widget.bundlePath, 'metadata.json')).writeAsStringSync(jsonEncode(metadata.toJson()));
            })
      ],
    );
  }
}

/// CameraApp is the Main Application.
class CameraApp extends StatelessWidget {
  /// Default Constructor
  const CameraApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: CameraExampleHome(),
    );
  }
}

List<CameraDescription> _cameras = <CameraDescription>[];

Future<void> main() async {
  // Fetch the available cameras before initializing the app.
  try {
    WidgetsFlutterBinding.ensureInitialized();
    _cameras = await availableCameras();
  } on CameraException catch (e) {
    _logError(e.code, e.description);
  }
  runApp(const CameraApp());
}
