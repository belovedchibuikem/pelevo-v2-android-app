import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Debug catalog navigation only. Release stays false.
final catalogPreviewProvider = Provider<bool>((ref) => false);
