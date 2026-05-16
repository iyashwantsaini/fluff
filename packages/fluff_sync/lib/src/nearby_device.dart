import 'package:meta/meta.dart';

enum NearbyDeviceKind { phone, tablet, laptop, desktop, tv }

@immutable
class NearbyDevice {
  NearbyDevice({
    required this.id,
    required this.name,
    required this.kind,
    required this.address,
    DateTime? lastSeen,
    this.paired = false,
  }) : lastSeen = lastSeen ?? DateTime.now() {
    if (id.isEmpty) throw ArgumentError.value(id, 'id');
    if (name.isEmpty) throw ArgumentError.value(name, 'name');
    if (address.isEmpty) throw ArgumentError.value(address, 'address');
  }

  final String id;
  final String name;
  final NearbyDeviceKind kind;
  final String address;
  final DateTime lastSeen;
  final bool paired;

  NearbyDevice copyWith({bool? paired, DateTime? lastSeen}) {
    return NearbyDevice(
      id: id,
      name: name,
      kind: kind,
      address: address,
      paired: paired ?? this.paired,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
