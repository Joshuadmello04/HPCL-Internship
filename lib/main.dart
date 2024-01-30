import 'package:flutter/material.dart';
//import 'package:hpcl_meter_reading_app/sqldb.dart';
//import 'imagescan.dart';
import 'login.dart'; // Import your login page file


Future<void> main() async {

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HPCL Meter Reading App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: LoginPage(), // Set the login page as the initial screen
    );
  }
}

// You can keep your other classes (HomePage, RegistrationPage, etc.) in separate files
