//import 'dart:html';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

class ImageScanner extends StatefulWidget {
  @override
  _ImageScannerState createState() => _ImageScannerState();
}

class _ImageScannerState extends State<ImageScanner> {
  bool hasImage = false;
  File? image;
  TextRecognizer textRecognizer = GoogleMlKit.vision.textRecognizer();
  String? imagePath;
  String scanText = '';

  Future getImage(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(source: source);
      if (image == null) return;

      final imageTemporary = File(image.path);
      setState(() {
        this.image = imageTemporary;
        imagePath = imageTemporary.path;
        debugPrint(imagePath!);
        hasImage = true;
        // Call the getText function when an image is selected
        getText(imagePath!);
      });
    } on PlatformException catch (e) {
      debugPrint('Failed to pick image: $e');
    }
  }

  Future getText(String path) async {
    final inputImage = InputImage.fromFilePath(path);
    final RecognizedText recognisedText = await textRecognizer.processImage(inputImage);
    String extractedText = '';

    for (TextBlock block in recognisedText.blocks) {
      for (TextLine line in block.lines) {
        for (TextElement element in line.elements) {
          extractedText = '$extractedText ${element.text}';
        }
        extractedText = '$extractedText\n';
      }
    }

    setState(() {
      scanText = extractedText;
    });
  }

  @override
  void dispose() {
    // Close the textDetector when the widget is disposed
    textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Image Scanner'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            hasImage
                ? Image.file(
              image!,
              width: 200,
              height: 200,
              fit: BoxFit.cover,
            )
                : Text('No Image Selected'),
            SizedBox(height: 20),
            Text('Scanned Text:'),
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
              ),
              child: Text(
                scanText,
                style: TextStyle(fontSize: 16),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Open the image picker when the button is pressed
                getImage(ImageSource.gallery);
              },
              child: Text('Pick Image'),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: ImageScanner(),
  ));
}
