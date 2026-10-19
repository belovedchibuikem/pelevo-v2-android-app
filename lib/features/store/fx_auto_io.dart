import 'dart:io';

bool get fxAutoFetchEnabled => Platform.environment['FLUTTER_TEST'] != 'true';
