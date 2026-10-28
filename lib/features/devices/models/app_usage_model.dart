import 'package:flutter/foundation.dart';

@immutable
class AppUsageEntry {
  const AppUsageEntry({
    required this.package,
    required this.appName,
    required this.foregroundMs,
    required this.launches,
  });

  final String package;
  final String appName;
  final int foregroundMs;
  final int launches;

  String get displayName =>
      appName.trim().isEmpty ? package : appName.trim();

  Duration get foreground => Duration(milliseconds: foregroundMs);

  factory AppUsageEntry.fromJson(Map<String, dynamic> json) {
    return AppUsageEntry(
      package: json['package']?.toString() ?? '',
      appName: json['app_name']?.toString() ?? '',
      foregroundMs: (json['foreground_ms'] as num?)?.toInt() ?? 0,
      launches: (json['launches'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
class AppUsageSnapshot {
  const AppUsageSnapshot({
    required this.deviceId,
    required this.from,
    required this.to,
    required this.appCount,
    required this.results,
  });

  final String deviceId;
  final DateTime? from;
  final DateTime? to;
  final int appCount;
  final List<AppUsageEntry> results;

  int get totalForegroundMs =>
      results.fold(0, (sum, e) => sum + e.foregroundMs);

  factory AppUsageSnapshot.fromJson(Map<String, dynamic> json) {
    final results = (json['results'] as List<dynamic>? ?? const [])
        .map((e) => AppUsageEntry.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.foregroundMs.compareTo(a.foregroundMs));
    return AppUsageSnapshot(
      deviceId: json['device_id']?.toString() ?? '',
      from: json['from'] != null
          ? DateTime.tryParse(json['from'].toString())
          : null,
      to: json['to'] != null ? DateTime.tryParse(json['to'].toString()) : null,
      appCount: (json['app_count'] as num?)?.toInt() ?? results.length,
      results: results,
    );
  }
}

/// Preset ranges for the Usage tab. [custom] uses the controller's custom
/// from/to when set; otherwise falls back to the last 7 days.
enum UsageRange {
  today('Today'),
  week('Last 7 days'),
  custom('Custom');

  const UsageRange(this.label);
  final String label;
}

String formatForeground(Duration d) {
  if (d.inHours >= 1) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
  if (d.inMinutes >= 1) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return s == 0 ? '${m}m' : '${m}m ${s}s';
  }
  return '${d.inSeconds}s';
}
