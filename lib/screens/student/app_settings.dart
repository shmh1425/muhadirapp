import 'package:flutter/foundation.dart';

class AppSettings {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  final ValueNotifier<bool> blurProfileImage = ValueNotifier<bool>(false);
  final ValueNotifier<int> rating = ValueNotifier<int>(0);
}
