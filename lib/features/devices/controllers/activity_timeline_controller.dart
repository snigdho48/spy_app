import 'package:flutter/foundation.dart';
import 'package:spy_love/features/devices/models/activity_item.dart';
import 'package:spy_love/features/devices/models/device_model.dart';
import 'package:spy_love/features/devices/repositories/event_repository.dart';
import 'package:spy_love/features/alerts/repositories/alert_repository.dart';

/// Drives the unified per-device activity timeline. Prefers the server-side
/// merged feed (`/events/activity/`, paginated via opaque cursor). If that
/// endpoint is not yet deployed (404) it transparently falls back to a
/// one-shot client-side merge of the existing per-feed endpoints + alerts.
class ActivityTimelineController extends ChangeNotifier {
  ActivityTimelineController(this._device, this._events, this._alerts);

  final DeviceModel _device;
  final EventRepository _events;
  final AlertRepository _alerts;

  static const int _pageSize = 50;

  final List<ActivityItem> _items = [];
  final Set<ActivityCategory> _activeFilters = {};

  bool _loading = false;
  bool _loadingMore = false;
  bool _accessDenied = false;
  bool _usedFallback = false;
  String? _error;
  String? _cursor;
  bool _hasMore = false;
  bool _disposed = false;

  DeviceModel get device => _device;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get accessDenied => _accessDenied;
  bool get hasError => _error != null;
  String? get error => _error;
  bool get hasMore => _hasMore;
  bool get usedFallback => _usedFallback;
  Set<ActivityCategory> get activeFilters => Set.unmodifiable(_activeFilters);

  /// Items after applying the active category filters (reverse-chronological).
  List<ActivityItem> get items {
    if (_activeFilters.isEmpty) return List.unmodifiable(_items);
    return _items
        .where((i) => _activeFilters.contains(i.category))
        .toList(growable: false);
  }

  bool get isEmpty => !_loading && _error == null && items.isEmpty;

  /// Day buckets (local time), newest first, each already reverse-chronological.
  List<ActivityDay> get grouped {
    final buckets = <DateTime, List<ActivityItem>>{};
    for (final item in items) {
      final local = item.timestamp.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      buckets.putIfAbsent(day, () => []).add(item);
    }
    final days = buckets.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final d in days) ActivityDay(day: d, items: buckets[d]!)];
  }

  List<String> get _filterIds =>
      _activeFilters.map((c) => c.id).toList(growable: false);

  Future<void> load() => _loadFirst();

  Future<void> refresh() => _loadFirst(background: true);

  void toggleFilter(ActivityCategory category) {
    if (!_activeFilters.add(category)) _activeFilters.remove(category);
    notifyListeners();
    // Server path re-queries with the new filter; fallback filters in memory.
    if (!_usedFallback) _loadFirst(background: true);
  }

  void clearFilters() {
    if (_activeFilters.isEmpty) return;
    _activeFilters.clear();
    notifyListeners();
    if (!_usedFallback) _loadFirst(background: true);
  }

  Future<void> _loadFirst({bool background = false}) async {
    _loading = !background;
    _error = null;
    _accessDenied = false;
    if (!background) notifyListeners();

    final outcome = await _events.activity(
      deviceId: _device.id,
      types: _filterIds,
      limit: _pageSize,
    );

    if (_disposed) return;

    if (outcome.accessDenied) {
      _items.clear();
      _accessDenied = true;
      _cursor = null;
      _hasMore = false;
      _finish();
      return;
    }
    if (outcome.unavailable) {
      await _loadFallback();
      return;
    }
    if (outcome.page == null) {
      _error = outcome.error ?? 'Could not load activity';
      _finish();
      return;
    }

    _usedFallback = false;
    _items
      ..clear()
      ..addAll(outcome.page!.items);
    _cursor = outcome.page!.nextCursor;
    _hasMore = outcome.page!.hasNext;
    _finish();
  }

  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore || _usedFallback || _cursor == null) return;
    _loadingMore = true;
    notifyListeners();

    final outcome = await _events.activity(
      deviceId: _device.id,
      types: _filterIds,
      cursor: _cursor,
      limit: _pageSize,
    );
    if (_disposed) return;

    if (outcome.page != null) {
      _items.addAll(outcome.page!.items);
      _cursor = outcome.page!.nextCursor;
      _hasMore = outcome.page!.hasNext;
    } else {
      _hasMore = false;
    }
    _loadingMore = false;
    notifyListeners();
  }

  /// One-shot client-side merge used when the server endpoint is absent.
  Future<void> _loadFallback() async {
    _usedFallback = true;
    final merged = <ActivityItem>[];

    final eventsResult = await _events.listAllEvents(
      deviceId: _device.id,
      maxPages: 5,
      pageSize: 100,
      loader: false,
    );
    if (_disposed) return;
    eventsResult.fold((events) {
      for (final e in events) {
        merged.add(
          ActivityItem(
            id: e.id,
            source: 'event',
            category: ActivityCategory.fromEventType(e.eventType),
            eventType: e.eventType,
            timestamp: e.eventTimestamp,
            payload: e.payload,
          ),
        );
      }
    }, (_) {});

    final alertsResult = await _alerts.list(
      deviceId: _device.id,
      pageSize: 100,
      loader: false,
    );
    if (_disposed) return;
    alertsResult.fold((page) {
      for (final a in page.alerts) {
        merged.add(
          ActivityItem(
            id: a.id,
            source: 'alert',
            category: ActivityCategory.alerts,
            eventType: a.rawType,
            timestamp: a.createdAt,
            payload: a.metadata,
            title: a.title,
            body: a.body,
            severity: a.severity.name,
          ),
        );
      }
    }, (_) {});

    merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _items
      ..clear()
      ..addAll(merged);
    _cursor = null;
    _hasMore = false;
    _finish();
  }

  void _finish() {
    _loading = false;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// One day's worth of timeline items.
class ActivityDay {
  const ActivityDay({required this.day, required this.items});
  final DateTime day;
  final List<ActivityItem> items;
}
