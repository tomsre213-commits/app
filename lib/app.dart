import 'package:flutter/material.dart';
import 'pages/splash/welcome_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lessee App',
      home: WelcomePage(),
    );
  }
}