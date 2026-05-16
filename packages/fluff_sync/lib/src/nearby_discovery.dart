import 'dart:async';

import 'nearby_device.dart';

/// Web-slice discovery: holds a seed list of [NearbyDevice]s and
/// exposes a broadcast `changes` stream. The Phase 7.1 work swaps
/// the body for real `multicast_dns` discovery and TLS Wi-Fi
/// Direct pairing; consumers don't change.
class NearbyDiscovery {
  NearbyDiscovery({Iterable<NearbyDevice> seed = const []}) {
    for (final d in seed) {
      _devices[d.id] = d;
    }
  }

  final Map<String, NearbyDevice> _devices = {};
  final StreamController<List<NearbyDevice>> _events =
      StreamController<List<NearbyDevice>>.broadcast();

  List<NearbyDevice> get devices {
    final list = _devices.values.toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Stream<List<NearbyDevice>> get changes => _events.stream;

  void announce(NearbyDevice device) {
    _devices[device.id] = device;
    _emit();
  }

  bool forget(String id) {
    final removed = _devices.remove(id) != null;
    if (removed) _emit();
    return removed;
  }

  NearbyDevice? pair(String id) {
    final current = _devices[id];
    if (current == null) return null;
    final next = current.copyWith(paired: true);
    _devices[id] = next;
    _emit();
    return next;
  }

  NearbyDevice? unpair(String id) {
    final current = _devices[id];
    if (current == null) return null;
    final next = current.copyWith(paired: false);
    _devices[id] = next;
    _emit();
    return next;
  }

  NearbyDevice? byId(String id) => _devices[id];

  Future<void> dispose() => _events.close();

  void _emit() => _events.add(devices);
}

/// Convenience seed used by the demo UI.
List<NearbyDevice> defaultSeedNearbyDevices() => [
  NearbyDevice(
    id: 'dev-pixel',
    name: "Yash's Pixel",
    kind: NearbyDeviceKind.phone,
    address: '192.168.1.42',
    paired: true,
  ),
  NearbyDevice(
    id: 'dev-laptop',
    name: 'Studio MacBook',
    kind: NearbyDeviceKind.laptop,
    address: '192.168.1.18',
  ),
  NearbyDevice(
    id: 'dev-tv',
    name: 'Living-room TV',
    kind: NearbyDeviceKind.tv,
    address: '192.168.1.31',
  ),
];
