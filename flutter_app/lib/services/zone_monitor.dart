import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../main.dart';

class ZoneMonitor {
  static final ZoneMonitor _instance = ZoneMonitor._internal();
  factory ZoneMonitor() => _instance;
  ZoneMonitor._internal();

  Timer? _timer;
  // zone_id -> last known state: true = inside, false = outside
  final Map<int, bool> _lastState = {};
  // zone_id -> last time a 'missing' event was fired (to debounce)
  final Map<int, DateTime> _lastMissingFired = {};

  bool get isRunning => _timer != null && _timer!.isActive;

  void start() {
    if (isRunning) return;
    _checkZones(); // run immediately
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _checkZones());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _checkZones() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Verify child is paired with at least one parent before monitoring
    try {
      final link = await supabase
          .from('family_links')
          .select('parent_id')
          .eq('child_id', userId)
          .limit(1)
          .maybeSingle();
      if (link == null) return; // not paired — skip all monitoring
    } catch (_) {
      return;
    }

    // Get location
    Position? pos;
    try {
      final status = await Permission.location.status;
      if (!status.isGranted) return;
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
    } catch (_) {
      return;
    }

    // Fetch only zones explicitly assigned to this child
    List<dynamic> zones;
    try {
      zones = await supabase
          .from('safe_zones')
          .select('id, name, latitude, longitude, radius_meters, required_from, required_until, parent_id')
          .eq('child_id', userId);
    } catch (_) {
      return;
    }

    final now = DateTime.now();
    final nowTime = _timeOfDay(now);

    for (final zone in zones) {
      final zoneId = zone['id'] as int;
      final zoneLat = zone['latitude'] as double;
      final zoneLng = zone['longitude'] as double;
      final radius = zone['radius_meters'] as int;

      final distance = _haversineMeters(pos.latitude, pos.longitude, zoneLat, zoneLng);
      final isInside = distance <= radius;
      final wasInside = _lastState[zoneId];

      // Detect entry / exit
      if (wasInside == null) {
        // First check — just record state, no event
        _lastState[zoneId] = isInside;
      } else if (!wasInside && isInside) {
        _lastState[zoneId] = true;
        await _insertEvent(zoneId, userId, 'entered', pos);
      } else if (wasInside && !isInside) {
        _lastState[zoneId] = false;
        await _insertEvent(zoneId, userId, 'exited', pos);
      }

      // Missing check: if there's a required time window and child is outside zone
      final requiredFrom = zone['required_from'] as String?;
      final requiredUntil = zone['required_until'] as String?;
      if (requiredFrom != null && requiredUntil != null && !isInside) {
        final from = _parseTime(requiredFrom);
        final until = _parseTime(requiredUntil);
        if (from != null && until != null && _isBetween(nowTime, from, until)) {
          // Debounce: fire at most once every 10 minutes
          final lastFired = _lastMissingFired[zoneId];
          if (lastFired == null || now.difference(lastFired).inMinutes >= 10) {
            _lastMissingFired[zoneId] = now;
            await _insertEvent(zoneId, userId, 'missing', pos);
          }
        }
      }
    }
  }

  Future<void> _insertEvent(int zoneId, String childId, String type, Position pos) async {
    try {
      // Fetch all parent_ids linked to this child so the event is queryable per parent
      final links = await supabase
          .from('family_links')
          .select('parent_id')
          .eq('child_id', childId);
      for (final link in links) {
        await supabase.from('zone_events').insert({
          'zone_id': zoneId,
          'child_id': childId,
          'parent_id': link['parent_id'],
          'event_type': type,
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
    } catch (_) {}
  }

  double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _deg2rad(double deg) => deg * pi / 180;

  // Returns minutes since midnight
  int _timeOfDay(DateTime dt) => dt.hour * 60 + dt.minute;

  int? _parseTime(String t) {
    // Format: HH:MM:SS or HH:MM
    try {
      final parts = t.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    } catch (_) {
      return null;
    }
  }

  bool _isBetween(int now, int from, int until) {
    if (from <= until) return now >= from && now <= until;
    // Overnight range e.g. 22:00 - 06:00
    return now >= from || now <= until;
  }
}
