import 'package:flutter/widgets.dart';

typedef PelevoScreenBuilder = Widget Function(BuildContext context);

@immutable
class PelevoScreenSpec {
  const PelevoScreenSpec({
    required this.id,
    required this.section,
    required this.title,
    required this.builder,
    this.state,
  });

  final String id;
  final String section;
  final String title;
  final String? state;
  final PelevoScreenBuilder builder;
}
