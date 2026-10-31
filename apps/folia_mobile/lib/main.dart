import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'app/folia_app.dart';

// Immutable programs load once; each optical surface owns its own shader instance.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final programs = await Future.wait([
    ui.FragmentProgram.fromAsset('shaders/monet_word.frag'),
    ui.FragmentProgram.fromAsset('shaders/liquid_glass.frag'),
  ]);
  runApp(FoliaApp(words: programs[0], glass: programs[1]));
}
