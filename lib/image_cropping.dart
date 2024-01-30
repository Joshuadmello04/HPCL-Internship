import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

class ImageCropperPage extends StatefulWidget {
  final File imageFile;

  ImageCropperPage({super.key, required this.imageFile});

  @override
  _ImageCropperPageState createState() => _ImageCropperPageState();
}

class _ImageCropperPageState extends State<ImageCropperPage> {
  late File _croppedFile;

  @override
  void initState() {
    super.initState();
    _croppedFile = widget.imageFile;
  }

  @override
  void dispose() {
    // Dispose of resources here if necessary
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Image Cropper'),
        actions: [
          IconButton(
            icon: Icon(Icons.check),
            onPressed: () {
              _onConfirmation();
            },
          ),
        ],
      ),
      body: Container(
        child: Column(
          children: [
            Expanded(
              child: Image.file(
                _croppedFile,
                fit: BoxFit.cover,
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _cropImage();
              },
              child: Text('Crop Image'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cropImage() async {
    print('Start cropping...');
    try {
      final List<PlatformUiSettings> uiSettingsList = Platform.isAndroid
          ? [
        AndroidUiSettings(
          toolbarTitle: 'Cropper',
          toolbarColor: Colors.deepOrange,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
      ]
          : [
        IOSUiSettings(
          title: 'Cropper',
          aspectRatioLockEnabled: false,
        ),
      ];
      print('Before cropImage...');
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: widget.imageFile.path,
        aspectRatioPresets: [
          CropAspectRatioPreset.square,
          CropAspectRatioPreset.ratio3x2,
          CropAspectRatioPreset.original,
          CropAspectRatioPreset.ratio4x3,
          CropAspectRatioPreset.ratio16x9,
        ],
        uiSettings: uiSettingsList,
      );

      if (croppedFile != null) {
        print('image has been cropped');
        setState(() {
          _croppedFile = File(croppedFile.path);
        });
      }
    } catch (e) {
      print('Error cropping image: $e');
      // Handle the error, possibly show a user-friendly message
    }
  }

  void _onConfirmation() {
    Navigator.pop(context, _croppedFile);
  }
}
