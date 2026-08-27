import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import '../screens/sky_screen.dart';

class SkyMapApp extends StatelessWidget {
  const SkyMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sky Map',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const SkyScreen(),
    );
  }
}