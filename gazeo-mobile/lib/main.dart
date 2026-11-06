import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'routes/app_router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('[Firebase] Erreur initialisation : $e');
  }

  runApp(const GazeoApp());
}

class GazeoApp extends StatelessWidget {
  const GazeoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GAZEO - Gaz domestique Yaoundé',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: AppTheme.lightTheme,
    );
  }
}
