import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:webapp/colors.dart';
import 'package:webapp/config.dart';
import 'package:webapp/home_view.dart';
import 'package:webapp/locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  setupLocator();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeRight,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown
  ]);
  runApp(const LLMApp());
}

class LLMApp extends StatelessWidget {
  const LLMApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: uniBlue),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        fontFamily: "Roboto",
      ),
      home: const HomeView(),
    );
  }
}
