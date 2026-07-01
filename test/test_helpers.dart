import 'dart:io';
import 'package:hive/hive.dart';

void initTestHive() {
  final tempDir = Directory.systemTemp.createTempSync('hive_test_');
  Hive.init(tempDir.path);
}
