import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'client_shell.dart';

// Root assembly does not own feature behavior, playback time or raster caches.
class FoliaApp extends StatelessWidget {
  const FoliaApp({super.key, required this.words, required this.glass});
  final ui.FragmentProgram words, glass;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Folia Next',
    debugShowCheckedModeBanner: false,
    supportedLocales: const [Locale('en'), Locale('zh'), Locale('id')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff355d69)),
      useMaterial3: true,
    ),
    home: ClientShell(words: words, glass: glass),
  );
}
