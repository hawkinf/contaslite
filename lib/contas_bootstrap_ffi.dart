import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool _contasDatabaseConfigured = false;

Future<void> configureContasDatabaseIfNeeded() async {
  final isDesktop = defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;

  if (!isDesktop) return;
  if (_contasDatabaseConfigured) return;

  sqfliteFfiInit();

  final oldDatabasesPath = await databaseFactoryFfi.getDatabasesPath();

  final documentsDir = await getApplicationDocumentsDirectory();
  final newDatabasesPath = p.join(documentsDir.path, 'ContasLite', 'Database');
  await Directory(newDatabasesPath).create(recursive: true);

  await databaseFactoryFfi.setDatabasesPath(newDatabasesPath);
  databaseFactory = databaseFactoryFfi;
  debugPrint('🗄️ Banco de dados (desktop): $newDatabasesPath');

  final oldDbFile = File(p.join(oldDatabasesPath, 'finance_v62.db'));
  final newDbFile = File(p.join(newDatabasesPath, 'finance_v62.db'));
  if (oldDbFile.path != newDbFile.path &&
      await oldDbFile.exists() &&
      !await newDbFile.exists()) {
    await oldDbFile.copy(newDbFile.path);
    debugPrint('🗄️ Banco migrado de: ${oldDbFile.path}');
  }

  _contasDatabaseConfigured = true;
}
