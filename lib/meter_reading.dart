import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:hpclmeterreading/image_cropping.dart';


class DatabaseHelper {
  static const dbName = "myDatabase.db";
  static const dbVersion = 1;
  static const dbTable = "myTable";

  static const columnLast = "LastMeterReading";
  static const columnImages = "Images";
  static const columnBPNumber = "BPNumber";
  static const columnCustomerName = "CustomerName";
  static const columnCustomerAddress = "CustomerAddress";
  static const columnMeterNumber = "MeterNumber";
  static const columnMeterReading = "MeterReading";

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  late Database _database;

  Future<Database> get database async {
    print('Database is not initialized. Initializing...');
    _database = await _initializeDatabase();

    if (_database != null && _database.isOpen) {
      return _database;
    } else {
      print('Failed to initialize the database.');
      throw Exception('Failed to initialize the database.');
    }
  }

  Future<Database> _initializeDatabase() async {
    try {
      Directory directory = await getApplicationDocumentsDirectory();
      String path = join(directory.path, dbName);
      _database = await openDatabase(path, version: dbVersion, onCreate: _onCreateDB);

      List<Map<String, dynamic>> result = await _database.query(dbTable);
      print("Contents of $dbTable after opening the database:");
      print(result);

      print('Database initialized successfully.');

      return _database;
    } catch (e) {
      print('Error initializing database: $e');
      throw Exception('Error initializing database: $e');
    }
  }

  Future<void> _onCreateDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $dbTable (
        $columnLast INTEGER,
        $columnImages TEXT,
        $columnBPNumber TEXT,
        $columnCustomerName TEXT,
        $columnCustomerAddress TEXT,
        $columnMeterNumber TEXT,
        $columnMeterReading REAL
      )
    ''');
  }

  Future<void> insertMeterReading(Map<String, dynamic> row) async {
    Database db = await instance.database;
    try {
      await db.insert(dbTable, row);
      print("Row inserted successfully");
      List<Map<String, dynamic>> result = await db.query(dbTable);
      print("Contents of $dbTable:");
      print(result);
    } catch (e) {
      print('Error inserting row: $e');
    }
  }

  Future<Map<String, dynamic>?> getMeterReadingByHPNumber(String meternum) async {
    Database db = await instance.database;
    try {
      var result = await db.query(dbTable, where: "$columnMeterNumber = ?", whereArgs: [meternum]);
      print('Query executed successfully. Result: $result');

      if (result.isNotEmpty) {
        print('Returning result: ${result.first}');
        return result.first;
      } else {
        print('No data found for Meter Number: $meternum');
        return null;
      }
    } catch (e) {
      print('Error during query: $e');
      return null;
    }
  }
}

class MeterReadingPage extends StatefulWidget {
  @override
  _MeterReadingPageState createState() => _MeterReadingPageState();
}

class _MeterReadingPageState extends State<MeterReadingPage> {
  //TextDetector textDetector = GoogleMlKit.vision.textDetector();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late BuildContext dialogContext;
  late BuildContext scaffoldContext;
  TextEditingController _bpNumberController = TextEditingController();
  TextEditingController _customerNameController = TextEditingController();
  TextEditingController _customerAddressController = TextEditingController();
  TextEditingController _meterNumberController = TextEditingController();
  TextEditingController _meterReadingController = TextEditingController();

  String _imagePath = '';
  int? _previousReading;
  File? _pickedImageFromCamera;
  File? _pickedImageFromGallery;
  File? _croppedImage;
  String _extractedText = '';

  @override
  Widget build(BuildContext context) {
    scaffoldContext = context;
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text(
          'Meter Reading Page',
          style: TextStyle(
            fontFamily: 'Quicksand',
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInputField(
                _bpNumberController,
                'BP Number',
                onChanged: (value) async {
                  await _fetchMeterDataByBPNumber(value);
                },
              ),
              SizedBox(height: 16.0),
              _buildReadOnlyField(_customerNameController, 'Customer Name'),
              SizedBox(height: 16.0),
              _buildReadOnlyField(_meterNumberController, 'Meter Number'),
              SizedBox(height: 16.0),
              _buildReadOnlyField(_customerAddressController, 'Customer Address'),
              SizedBox(height: 16.0),
                _buildPreviousReadingField(_previousReading as double?),
              SizedBox(height: 16.0),
              _buildInputField(
                _meterReadingController,
                'Meter Reading',
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 16.0),
              _buildImageContainer(),
              SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: () {
                  _submitReading();
                },
                child: Text('Submit Reading'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(
      TextEditingController controller,
      String labelText, {
        int maxLines = 1,
        TextInputType keyboardType = TextInputType.text,
        Future<void> Function(String)? onChanged,
      }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: (value) async {
        if (onChanged != null) {
          await onChanged(value);
        }
      },
      decoration: InputDecoration(
        labelText: labelText,
      ),
    );
  }

  Widget _buildReadOnlyField(TextEditingController controller, String labelText) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      style: TextStyle(
        fontFamily: 'Quicksand',
        fontSize: 16,
      ),
      decoration: InputDecoration(
        border: OutlineInputBorder(),
        labelText: labelText,
        disabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
        ),
      ),
    );
  }
  double? _fetchedPreviousReading;
  String? _fetchedDatabyHP;

  Future<double?> _fetchPreviousReading() async {
    String meterNumber = _meterNumberController.text;

    if (meterNumber.isNotEmpty) {
      Map<String, dynamic>? meterReadingData =
      await DatabaseHelper.instance.getMeterReadingByHPNumber(meterNumber);

      if (meterReadingData != null &&
          meterReadingData.containsKey(DatabaseHelper.columnMeterReading)) {
        setState(() {
          _fetchedPreviousReading = meterReadingData[DatabaseHelper.columnMeterReading]?.toDouble();
        });
      } else {
        print('No data found for Meter Number: $meterNumber');
        _fetchedPreviousReading = null;
      }
      _buildPreviousReadingField(_fetchedPreviousReading);
    }
    return null;
  }

  Widget _buildPreviousReadingField(double? previousReading) {
    print('Previous Reading: $previousReading');

    // Check if _fetchedPreviousReading is null and fetch it
    if (_fetchedPreviousReading == null) {
      _fetchPreviousReading();
    }

    return TextFormField(
      initialValue: '$_fetchedPreviousReading',
      readOnly: true,
      style: const TextStyle(
        fontFamily: 'Quicksand',
        fontSize: 16,
      ),
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        labelText: 'Previous Reading',
        disabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
        ),
      ),
    );
  }

  Future<void> _fetchMeterDataByBPNumber(String data) async {
    String bpNumber = _bpNumberController.text;

    if (bpNumber.isNotEmpty) {
      Map<String, dynamic>? meterData =
      await DatabaseHelper.instance.getMeterReadingByHPNumber(bpNumber);

      if (meterData != null) {
        // Update the state with the fetched data
        setState(() {
          _customerNameController.text =
              meterData[DatabaseHelper.columnCustomerName] ?? '';
          _meterNumberController.text =
              meterData[DatabaseHelper.columnMeterNumber] ?? '';
          _customerAddressController.text =
              meterData[DatabaseHelper.columnCustomerAddress] ?? '';
          _fetchedPreviousReading =
              meterData[DatabaseHelper.columnMeterReading]?.toDouble();
        });
      } else {
        // Handle the case where no data is found for the entered BP number.
        // You can clear the values or show a message.
        setState(() {
          _customerNameController.text = '';
          _meterNumberController.text = '';
          _customerAddressController.text = '';
          _fetchedPreviousReading = null;
        });
        print('No data found for BP Number: $bpNumber');
      }
    }
  }


//<----------------------------Image Dealing Section----------------------------->
  Widget _buildImageContainer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _croppedImage != null ? Image(image: FileImage(_croppedImage!)) : (_pickedImageFromGallery != null || _pickedImageFromCamera != null
            ? Image(image: FileImage(_pickedImageFromGallery ?? _pickedImageFromCamera!)) : const Icon(Icons.photo, size: 100, color: Colors.grey)),
        ElevatedButton(
          onPressed: () async {
            await _pickImage();
            /*if (_pickedImageFromGallery != null || _pickedImageFromCamera != null) {
              await _cropImage(_pickedImageFromGallery ?? _pickedImageFromCamera!);
            }*/
          },

          child: Text('Take Photo'),
        ),
      ],
    );
  }
  Future<void> _pickImage() async {
    await showDialog(
      context: scaffoldContext,
      builder: (BuildContext context) {
        dialogContext = context;
        return AlertDialog(
          title: Text('Pick an Image'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo Library'),
                onTap: () async {
                  Navigator.of(dialogContext).pop();
                  final pickedFile =
                  await ImagePicker().pickImage(source: ImageSource.gallery);
                  if (pickedFile != null) {
                    setState(() {
                      _navigateToImageCropper(File(pickedFile.path));
                      _pickedImageFromGallery = File(pickedFile.path);
                      //_croppedImage=_pickedImageFromGallery;
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () async {
                  Navigator.of(dialogContext).pop();
                  final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
                  if (pickedFile != null) {
                    setState(() {
                      _navigateToImageCropper(File(pickedFile.path));
                      _pickedImageFromCamera = File(pickedFile.path);
                      // _croppedImage= _pickedImageFromCamera;
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );

  }

  void _navigateToImageCropper(File imagepath) async {
    final croppedImage = await Navigator.push<File>(
      scaffoldContext,
      MaterialPageRoute(
        builder: (context) => ImageCropperPage(imageFile: imagepath),
      ),
    );
    // Handle the cropped image, e.g., pass it to OCR
    if (croppedImage != null) {
      setState(() {
        _croppedImage = croppedImage;
      });
    }
    try {
      /*if (_pickedImageFromGallery != null || _pickedImageFromCamera != null)     {
        await _cropImage(_pickedImageFromGallery ?? _pickedImageFromCamera!);
       }*/
      // Call text recognition immediately after setting the _croppedImage state
      if (_croppedImage != null) {
        await getTextFromCroppedImage(_croppedImage!);
      }
      else {
        print("No cropped image available.");
      }
    } catch (e) {
      print('Error during image processing: $e');
    }
  }

  Future<void> getTextFromCroppedImage(File croppedImage) async {
    String scannedText = await _processCroppedImage(croppedImage);
    // Now you can use the scanned text as needed in your MeterReadingPage class
    print('Scanned Text: $scannedText');
    setState(() {
      _extractedText = scannedText;
      _meterReadingController.text = _extractedText;//populates the field
    });
  }

  Future<String> _processCroppedImage(File croppedFile) async {
    try {
      final inputImage = InputImage.fromFilePath(croppedFile.path);
      final TextRecognizer textRecognizer = GoogleMlKit.vision.textRecognizer();
      final RecognizedText recognisedText = await textRecognizer.processImage(inputImage);

      String extractedText = '';

      for (TextBlock block in recognisedText.blocks) {
        for (TextLine line in block.lines) {
          for (TextElement element in line.elements) {
            extractedText = extractedText + ' ' + element.text;
          }
          extractedText = extractedText + '\n';
        }
      }
      print('Extracted Text: $extractedText');
      return extractedText;
    } catch (e) {
      print('Error during text recognition: $e');
      return ''; // Return an empty string or handle the error as needed
    }
  }

  /*Future<void> _cropImage(File image) async   {
    print('Start cropping...');
    final List<PlatformUiSettings> uiSettingsList = Platform.isAndroid?
    [
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

    try {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatioPresets: [
          CropAspectRatioPreset.square,
          CropAspectRatioPreset.ratio3x2,
          CropAspectRatioPreset.original,
          CropAspectRatioPreset.ratio4x3,
          CropAspectRatioPreset.ratio16x9,
        ],
        uiSettings: uiSettingsList,
      );
      print('After cropImage...');
      if (croppedFile != null) {
        await _processCroppedImage(File(croppedFile.path));
      }
    }
    catch(e)
    {
      print('Error cropping image: $e');
    }
  }*/

  /*Future<String?> _processCroppedImage(File croppedFile) async {
    TextRecognizer textRecognizer = GoogleMlKit.vision.textRecognizer();
    try {
      RecognizedText recognizedText =
      await textRecognizer.processImage(InputImage.fromFilePath(croppedFile.path));
      String extractedText = recognizedText.text;

      print('Extracted Text: $extractedText');
      return extractedText;
    } catch (e) {
      print('Error processing image: $e');
      return null;
    } finally {
      await textRecognizer.close();
    }
  }*/


  void _submitReading() {
    String bpNumber = _bpNumberController.text;
    String customerName = _customerNameController.text;
    String customerAddress = _customerAddressController.text;
    String meterNumber = _meterNumberController.text;
    double meterReading = double.tryParse(_meterReadingController.text) ?? 0;

    _fetchPreviousReading().then((_) {
      if (_scaffoldKey != null && _scaffoldKey.currentState != null) {
        showDialog(
          context: _scaffoldKey.currentState!.context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Meter Reading Confirmation'),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('BP Number: $bpNumber'),
                  Text('Customer Name: $customerName'),
                  Text('Customer Address: $customerAddress'),
                  Text('Meter Number: $meterNumber'),
                  Text('Previous Reading: $_fetchedPreviousReading'),
                  Text('Current Reading: $meterReading'),
                  // Display the cropped image
                  _croppedImage != null ? Image(image: FileImage(_croppedImage!)) : Container(),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    DatabaseHelper.instance.insertMeterReading({
                      DatabaseHelper.columnLast: _fetchedPreviousReading ?? 0,
                      DatabaseHelper.columnImages: _croppedImage?.path ?? '',
                      DatabaseHelper.columnBPNumber: bpNumber,
                      DatabaseHelper.columnCustomerName: customerName,
                      DatabaseHelper.columnCustomerAddress: customerAddress,
                      DatabaseHelper.columnMeterNumber: meterNumber,
                      DatabaseHelper.columnMeterReading: meterReading,
                    });

                    // Clear the cropped image
                    setState(() {
                      _croppedImage = null;
                    });

                    // Print the entire contents of the table after inserting data
                    List<Map<String, dynamic>> result =
                    await DatabaseHelper.instance.database.then((db) => db.query(DatabaseHelper.dbTable));
                    print("Contents of ${DatabaseHelper.dbTable}:");
                    print(result);
                    _resetFields();
                  },
                  child: Text('Submit'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Edit'),
                ),
              ],
            );
          },
        );
      } else {
        print('Scaffold key is null or disposed.');
      }
    });
  }

  void _resetFields() {
    _bpNumberController.clear();
    _customerNameController.clear();
    _customerAddressController.clear();
    _meterNumberController.clear();
    _meterReadingController.clear();
    setState(() {
      _imagePath = '';
      _pickedImageFromGallery = null;
      _pickedImageFromCamera = null;
      _croppedImage = null;
    });
  }
}

