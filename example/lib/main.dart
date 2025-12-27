import 'package:flutter/material.dart';
import 'splash_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moussa Upadter Example',
      debugShowCheckedModeBanner: false,
      home: const SplashPage(),
    );
  }
}
