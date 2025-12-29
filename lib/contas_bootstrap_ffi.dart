import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> configureContasDatabaseIfNeeded() async {
  final isDesktop = defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;

  if (!isDesktop) return;

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}
