import 'package:flutter/foundation.dart';

@immutable
class TelemetrySnapshot {
  const TelemetrySnapshot({
    required this.deviceId,
    required this.batteryPct,
    required this.charging,
    required this.networkType,
    required this.storageFree,
    required this.storageTotal,
    required this.ramFree,
    required this.ramTotal,
    required this.metrics,
    this.capturedAt,
    this.updatedAt,
  });

  final String deviceId;
  final int? batteryPct;
  final bool charging;
  final String networkType;
  final int? storageFree;
  final int? storageTotal;
  final int? ramFree;
  final int? ramTotal;
  final Map<String, dynamic> metrics;
  final DateTime? capturedAt;
  final DateTime? updatedAt;

  bool get isLowBattery =>
      batteryPct != null && batteryPct! <= 20 && !charging;

  double? get storageUsedFraction {
    final free = storageFree;
    final total = storageTotal;
    if (free == null || total == null || total <= 0) return null;
    return ((total - free) / total).clamp(0.0, 1.0);
  }

  String? get storageLabel {
    final free = storageFree;
    final total = storageTotal;
    if (free == null || total == null) return null;
    return '${_fmtBytes(total - free)} / ${_fmtBytes(total)}';
  }

  String? get ramLabel {
    final free = ramFree;
    final total = ramTotal;
    if (free == null || total == null) return null;
    return '${_fmtBytes(free)} free of ${_fmtBytes(total)}';
  }

  static String _fmtBytes(int bytes) {
    if (bytes >= 1 << 30) {
      return '${(bytes / (1 << 30)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1 << 20) {
      return '${(bytes / (1 << 20)).toStringAsFixed(0)} MB';
    }
    return '$bytes B';
  }

  factory TelemetrySnapshot.fromJson(Map<String, dynamic> json) {
    return TelemetrySnapshot(
      deviceId: json['device_id']?.toString() ?? '',
      batteryPct: (json['battery_pct'] as num?)?.round(),
      charging: json['charging'] as bool? ?? false,
      networkType: json['network_type']?.toString() ?? '',
      storageFree: (json['storage_free'] as num?)?.toInt(),
      storageTotal: (json['storage_total'] as num?)?.toInt(),
      ramFree: (json['ram_free'] as num?)?.toInt(),
      ramTotal: (json['ram_total'] as num?)?.toInt(),
      metrics: (json['metrics'] as Map?)?.cast<String, dynamic>() ?? const {},
      capturedAt: json['captured_at'] != null
          ? DateTime.tryParse(json['captured_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }
}
