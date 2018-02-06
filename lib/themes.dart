import 'package:flutter/material.dart';

class Themes {
  static final ThemeData kIOSTheme = new ThemeData(
      primarySwatch: Colors.orange,
      primaryColor: Colors.grey[100],
      primaryColorBrightness: Brightness.light);

  static final ThemeData kDefaultTheme = new ThemeData(
      primaryColor: Colors.purple, accentColor: Colors.orangeAccent[400]);

  static double getElevation(BuildContext context) =>
      isiOS(context) ? 0.0 : 4.0;

  static bool isiOS(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.iOS;
}
