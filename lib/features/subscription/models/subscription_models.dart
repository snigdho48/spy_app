class SubscriptionInfo {
  const SubscriptionInfo({
    required this.planCode,
    required this.planName,
    required this.isActive,
    required this.priceMonthlyUsd,
    required this.maxDevices,
    required this.maxMembers,
    required this.eventRetentionDays,
    required this.features,
  });

  final String planCode;
  final String planName;
  final bool isActive;
  final double priceMonthlyUsd;
  final int maxDevices;
  final int maxMembers;
  final int eventRetentionDays;
  final List<String> features;

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    return SubscriptionInfo(
      planCode: json['plan_code'] as String? ?? 'free',
      planName: json['plan_name'] as String? ?? 'Free',
      isActive: json['is_active'] as bool? ?? false,
      priceMonthlyUsd: (json['price_monthly_usd'] as num?)?.toDouble() ?? 0,
      maxDevices: json['max_devices'] as int? ?? 2,
      maxMembers: json['max_members'] as int? ?? 2,
      eventRetentionDays: json['event_retention_days'] as int? ?? 7,
      features: (json['features'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.code,
    required this.name,
    required this.priceMonthlyUsd,
    required this.maxDevices,
    required this.maxMembers,
    required this.eventRetentionDays,
    required this.features,
  });

  final String code;
  final String name;
  final double priceMonthlyUsd;
  final int maxDevices;
  final int maxMembers;
  final int eventRetentionDays;
  final List<String> features;

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      code: json['code'] as String,
      name: json['name'] as String,
      priceMonthlyUsd: (json['price_monthly_usd'] as num).toDouble(),
      maxDevices: json['max_devices'] as int,
      maxMembers: json['max_members'] as int,
      eventRetentionDays: json['event_retention_days'] as int,
      features: (json['features'] as List<dynamic>)
          .map((e) => e.toString())
          .toList(),
    );
  }
}
