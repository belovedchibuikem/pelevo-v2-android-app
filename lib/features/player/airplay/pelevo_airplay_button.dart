import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const pelevoAirPlayViewType = 'pelevo/airplay_route_picker';

bool get pelevoAirPlayAvailable =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Native iOS [AVRoutePickerView] so listeners can send audio to AirPlay speakers.
class PelevoAirPlayRoutePicker extends StatelessWidget {
  const PelevoAirPlayRoutePicker({
    super.key,
    this.size = 36,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    if (!pelevoAirPlayAvailable) {
      return SizedBox(
        width: size,
        height: size,
        child: Icon(
          Icons.airplay_rounded,
          size: size * 0.7,
          color: Theme.of(context).iconTheme.color,
        ),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: const UiKitView(
        viewType: pelevoAirPlayViewType,
        layoutDirection: TextDirection.ltr,
        creationParamsCodec: StandardMessageCodec(),
      ),
    );
  }
}
