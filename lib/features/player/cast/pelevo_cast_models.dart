/// A Cast-capable receiver discovered on the local network.
class PelevoCastDevice {
  const PelevoCastDevice({
    required this.id,
    required this.name,
    this.model,
  });

  final String id;
  final String name;
  final String? model;
}

/// Snapshot of the Google Cast session used by the player UI.
class PelevoCastSnapshot {
  const PelevoCastSnapshot({
    required this.supported,
    required this.ready,
    required this.connected,
    required this.playing,
    this.discovering = false,
    this.permissionDenied = false,
    this.deviceName,
    this.statusMessage,
    this.devices = const [],
  });

  final bool supported;
  final bool ready;
  final bool connected;
  final bool playing;
  final bool discovering;
  final bool permissionDenied;
  final String? deviceName;
  final String? statusMessage;
  final List<PelevoCastDevice> devices;

  static const unsupported = PelevoCastSnapshot(
    supported: false,
    ready: false,
    connected: false,
    playing: false,
  );

  PelevoCastSnapshot copyWith({
    bool? supported,
    bool? ready,
    bool? connected,
    bool? playing,
    bool? discovering,
    bool? permissionDenied,
    String? deviceName,
    String? statusMessage,
    List<PelevoCastDevice>? devices,
    bool clearDeviceName = false,
    bool clearStatusMessage = false,
  }) => PelevoCastSnapshot(
    supported: supported ?? this.supported,
    ready: ready ?? this.ready,
    connected: connected ?? this.connected,
    playing: playing ?? this.playing,
    discovering: discovering ?? this.discovering,
    permissionDenied: permissionDenied ?? this.permissionDenied,
    deviceName: clearDeviceName ? null : (deviceName ?? this.deviceName),
    statusMessage:
        clearStatusMessage ? null : (statusMessage ?? this.statusMessage),
    devices: devices ?? this.devices,
  );
}
