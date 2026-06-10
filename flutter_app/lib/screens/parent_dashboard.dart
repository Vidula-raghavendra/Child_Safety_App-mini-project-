import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../services/notification_service.dart';
import 'emergency_contacts_screen.dart';
import 'link_child_screen.dart';
import 'safe_zones_screen.dart';

class ParentDashboard extends StatefulWidget {
  final String displayName;
  const ParentDashboard({super.key, required this.displayName});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _children = [];
  List<Map<String, dynamic>> _alerts = [];
  bool _loadingChildren = true;
  bool _loadingAlerts = true;
  RealtimeChannel? _alertsChannel;
  String _alertFilter = 'All';
  Timer? _refreshTimer;

  String get _firstName => widget.displayName.split(' ').first;

  @override
  void initState() {
    super.initState();
    _loadChildren();
    _loadAlerts();
    _subscribeRealtime();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadChildren();
    });
  }

  @override
  void dispose() {
    _alertsChannel?.unsubscribe();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadChildren() async {
    if (!mounted) return;
    setState(() => _loadingChildren = true);
    try {
      final parentId = supabase.auth.currentUser!.id;
      final links = await supabase.from('family_links').select('child_id').eq('parent_id', parentId);
      final childIds = (links as List).map((l) => l['child_id'] as String).toList();
      if (childIds.isEmpty) {
        if (mounted) setState(() { _children = []; _loadingChildren = false; });
        return;
      }
      final users = await supabase.from('users').select('id, full_name, email').inFilter('id', childIds);
      final List<Map<String, dynamic>> enriched = [];
      for (final u in users as List) {
        // Live location — updated every 30s by the child app
        final liveLocation = await supabase
            .from('live_locations')
            .select('latitude, longitude, updated_at')
            .eq('child_id', u['id'])
            .maybeSingle();
        // Last SOS for status badge
        final lastAlert = await supabase
            .from('sos_alerts')
            .select('latitude, longitude, timestamp, is_active')
            .eq('user_id', u['id'])
            .order('timestamp', ascending: false)
            .limit(1)
            .maybeSingle();
        final lastZoneEvent = await supabase
            .from('zone_events')
            .select('event_type, created_at, zone_id, safe_zones(name)')
            .eq('child_id', u['id'])
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        final lastCheckin = await supabase
            .from('check_ins')
            .select('note, created_at')
            .eq('child_id', u['id'])
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        enriched.add({
          ...u,
          'live_location': liveLocation,
          'last_location': lastAlert,
          'last_zone_event': lastZoneEvent,
          'last_checkin': lastCheckin,
        });
      }
      if (mounted) setState(() { _children = enriched; _loadingChildren = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingChildren = false);
    }
  }

  Future<void> _loadAlerts() async {
    if (!mounted) return;
    setState(() => _loadingAlerts = true);
    try {
      final parentId = supabase.auth.currentUser!.id;
      // Ensure children loaded so childMap is available
      if (_children.isEmpty) await _loadChildren();

      final zoneEvents = await supabase
          .from('zone_events')
          .select('id, event_type, created_at, child_id, safe_zones(name), latitude, longitude')
          .eq('parent_id', parentId)
          .order('created_at', ascending: false)
          .limit(30);
      // sos_alerts now has parent_id — filter by it so we only see our family's alerts
      final sosAlerts = await supabase
          .from('sos_alerts')
          .select('alert_id, timestamp, is_active, user_id, parent_id, latitude, longitude')
          .eq('parent_id', parentId)
          .order('timestamp', ascending: false)
          .limit(20);
      final checkIns = await supabase
          .from('check_ins')
          .select('id, note, status, created_at, child_id')
          .eq('parent_id', parentId)
          .order('created_at', ascending: false)
          .limit(20);

      final childMap = { for (final c in _children) c['id'] as String: (c['full_name'] as String?) ?? 'Child' };
      final List<Map<String, dynamic>> combined = [];
      for (final e in zoneEvents as List) {
        combined.add({'type': 'zone', ...e, 'timestamp': e['created_at'], 'child_name': childMap[e['child_id']] ?? 'Child'});
      }
      for (final s in sosAlerts as List) {
        combined.add({'type': 'sos', ...s, 'timestamp': s['timestamp'], 'child_name': childMap[s['user_id']] ?? 'Child'});
      }
      for (final c in checkIns as List) {
        combined.add({'type': 'checkin', ...c, 'timestamp': c['created_at'], 'child_name': childMap[c['child_id']] ?? 'Child'});
      }
      combined.sort((a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''));
      if (mounted) setState(() { _alerts = combined.take(50).toList(); _loadingAlerts = false; });
    } catch (e) {
      if (mounted) setState(() => _loadingAlerts = false);
    }
  }

  void _subscribeRealtime() {
    final parentId = supabase.auth.currentUser!.id;
    _alertsChannel = supabase
        .channel('parent_alerts_$parentId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'zone_events',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'parent_id', value: parentId),
          callback: (payload) {
            _showInAppAlert(payload.newRecord);
            _loadAlerts();
            _loadChildren();
          })
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'sos_alerts',
          callback: (payload) {
            _showSosAlert(payload.newRecord);
            _loadAlerts();
            _loadChildren();
          })
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'check_ins',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'parent_id', value: parentId),
          callback: (payload) {
            _showCheckInAlert(payload.newRecord);
            _loadAlerts();
            _loadChildren();
          })
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'live_locations',
          callback: (payload) { _loadChildren(); })
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'live_locations',
          callback: (payload) { _loadChildren(); })
        .subscribe();
  }

  void _showInAppAlert(Map<String, dynamic> record) {
    if (!mounted) return;
    final type = record['event_type'] as String? ?? 'event';
    final zoneName = record['safe_zones']?['name'] as String? ?? 'zone';
    final childName = _childNameFromId(record['child_id'] as String?);

    // Push notification
    NotificationService.instance.showZoneAlert(
      childName: childName, eventType: type, zoneName: zoneName);

    // In-app banner
    final color = type == 'missing' ? const Color(0xFFDC2626) : type == 'exited' ? const Color(0xFFF59E0B) : const Color(0xFF059669);
    final icon = type == 'missing' ? Icons.warning_amber_rounded : type == 'exited' ? Icons.logout_rounded : Icons.login_rounded;
    final msg = type == 'missing' ? '$childName is MISSING from $zoneName!' : type == 'exited' ? '$childName left $zoneName' : '$childName entered $zoneName';
    if (type == 'missing') HapticFeedback.heavyImpact();
    _showSnack(msg, color, icon, duration: type == 'missing' ? 10 : 5);
  }

  void _showSosAlert(Map<String, dynamic> record) {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    final childName = _childNameFromId(record['user_id'] as String?);
    final lat = (record['latitude'] as num?)?.toDouble() ?? 0.0;
    final lng = (record['longitude'] as num?)?.toDouble() ?? 0.0;

    // Push notification
    NotificationService.instance.showSOS(childName: childName, lat: lat, lng: lng);

    // Full-screen urgency overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (_) => _SosUrgencyDialog(childName: childName, lat: lat, lng: lng),
    );
  }

  void _showCheckInAlert(Map<String, dynamic> record) {
    if (!mounted) return;
    final childName = _childNameFromId(record['child_id'] as String?);
    final status = record['status'] as String? ?? 'Checked in';
    NotificationService.instance.showCheckIn(childName: childName, status: status);
    _showSnack('$childName: $status', const Color(0xFF4B9B6F), Icons.check_circle_outline_rounded);
  }

  String _childNameFromId(String? id) {
    if (id == null) return 'Child';
    for (final c in _children) {
      if (c['id'] == id) return (c['full_name'] as String?) ?? 'Child';
    }
    return 'Child';
  }

  void _showSnack(String msg, Color color, IconData icon, {int duration = 5}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white))),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: duration),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(12),
    ));
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return DateFormat('MMM d').format(dt);
    } catch (_) { return ''; }
  }

  bool get _hasUrgentAlerts => _alerts.any((a) => a['type'] == 'sos' || (a['type'] == 'zone' && a['event_type'] == 'missing'));

  int get _urgentCount => _alerts.where((a) => a['type'] == 'sos' || (a['type'] == 'zone' && a['event_type'] == 'missing')).length;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildOverviewPage(),
      _buildAlertsPage(),
      _buildChildrenPage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F7),
      body: pages[_selectedIndex],
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAF9F7),
        border: Border(top: BorderSide(color: Color(0xFFEAE6E0), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              _buildNavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Overview', index: 0),
              _buildNavItem(icon: Icons.notifications_none_rounded, activeIcon: Icons.notifications_rounded, label: 'Alerts', index: 1, badge: _hasUrgentAlerts ? _urgentCount : 0),
              _buildNavItem(icon: Icons.people_outline_rounded, activeIcon: Icons.people_rounded, label: 'Children', index: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required IconData activeIcon, required String label, required int index, int badge = 0}) {
    final isSelected = index == _selectedIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEEF2FF) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(isSelected ? activeIcon : icon, size: 22, color: isSelected ? const Color(0xFFC9A96E) : const Color(0xFFB0A9A0)),
                ),
                if (badge > 0)
                  Positioned(
                    top: 0, right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, color: isSelected ? const Color(0xFFC9A96E) : const Color(0xFFB0A9A0))),
          ],
        ),
      ),
    );
  }

  // ── Overview Page ─────────────────────────────────────────────────────────

  Widget _buildOverviewPage() {
    final safeCount = _children.where((c) {
      final hasSos = c['last_location']?['is_active'] == true;
      final isMissing = c['last_zone_event']?['event_type'] == 'missing';
      return !hasSos && !isMissing;
    }).length;
    final sosCount = _children.where((c) => c['last_location']?['is_active'] == true).length;
    final missingCount = _children.where((c) => c['last_zone_event']?['event_type'] == 'missing').length;
    final recentAlerts = _alerts.take(5).toList();

    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Container(
            color: const Color(0xFFFAF9F7),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_greeting(), style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFB0A9A0), fontWeight: FontWeight.w500, letterSpacing: 0.5)),
                              const SizedBox(height: 2),
                              Text(_firstName, style: GoogleFonts.dmSerifDisplay(fontSize: 30, color: const Color(0xFF0F0E0B))),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => const LinkChildScreen()));
                            _loadChildren();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: const Color(0xFFEAE6E0), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE0DBD4))),
                            child: const Icon(Icons.person_add_outlined, color: Color(0xFF6B6560), size: 18),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async => await supabase.auth.signOut(),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: const Color(0xFFEAE6E0), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE0DBD4))),
                            child: const Icon(Icons.logout_rounded, color: Color(0xFF6B6560), size: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Stats row
                    Row(
                      children: [
                        _StatPill(label: 'Safe', count: safeCount, color: const Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        if (sosCount > 0) ...[
                          _StatPill(label: 'SOS', count: sosCount, color: const Color(0xFFEF4444)),
                          const SizedBox(width: 8),
                        ],
                        if (missingCount > 0) ...[
                          _StatPill(label: 'Missing', count: missingCount, color: const Color(0xFFF59E0B)),
                          const SizedBox(width: 8),
                        ],
                        _StatPill(label: 'Total', count: _children.length, color: Colors.white.withValues(alpha: 0.4)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Quick action cards
                Row(
                  children: [
                    Expanded(child: _QuickActionCard(
                      icon: Icons.people_outline_rounded,
                      label: 'Children',
                      value: '${_children.length}',
                      color: const Color(0xFFC9A96E),
                      onTap: () => setState(() => _selectedIndex = 2),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _QuickActionCard(
                      icon: Icons.notifications_none_rounded,
                      label: 'Alerts Today',
                      value: '${_alerts.where((a) {
                        final ts = a['timestamp'] as String?;
                        if (ts == null) return false;
                        try {
                          return DateTime.now().difference(DateTime.parse(ts)).inHours < 24;
                        } catch(_) { return false; }
                      }).length}',
                      color: _hasUrgentAlerts ? const Color(0xFFEF4444) : const Color(0xFF4B9B6F),
                      onTap: () => setState(() => _selectedIndex = 1),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _QuickActionCard(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Check-ins',
                      value: '${_alerts.where((a) => a['type'] == 'checkin').length}',
                      color: const Color(0xFF7B6FA0),
                      onTap: () => setState(() => _selectedIndex = 1),
                    )),
                  ],
                ),
                const SizedBox(height: 20),

                // Children status strip
                if (_loadingChildren)
                  const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                else if (_children.isEmpty)
                  _EmptyState(
                    icon: Icons.child_care_rounded,
                    title: 'No children linked yet',
                    subtitle: 'Tap the person+ icon to add a child',
                    action: 'Link Child',
                    onAction: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const LinkChildScreen()));
                      _loadChildren();
                    },
                  )
                else ...[
                  // Zone-out banners for children not at expected safe zone
                  ..._children.where((c) {
                    return c['last_zone_event']?['event_type'] == 'missing';
                  }).map((c) {
                    final name = (c['full_name'] as String?) ?? 'Child';
                    final zoneName = c['last_zone_event']?['safe_zones']?['name'] as String? ?? 'safe zone';
                    final liveLoc = c['live_location'] as Map<String, dynamic>?;
                    return _MissingZoneBanner(
                      childName: name,
                      zoneName: zoneName,
                      liveLoc: liveLoc,
                      onDismiss: () {
                        // Mark locally dismissed
                        setState(() {
                          c['last_zone_event'] = null;
                        });
                      },
                      onAlertContacts: () {
                        final childId = c['id'] as String;
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => EmergencyContactsScreen(childId: childId, childName: name),
                        ));
                      },
                    );
                  }),

                  // Live map section — always visible when children have location
                  ..._children.where((c) {
                    final loc = c['live_location'] ?? c['last_location'];
                    if (loc == null) return false;
                    final lat = (loc['latitude'] as num?)?.toDouble() ?? 0;
                    final lng = (loc['longitude'] as num?)?.toDouble() ?? 0;
                    return lat != 0 || lng != 0;
                  }).map((c) {
                    final name = (c['full_name'] as String?) ?? 'Child';
                    final loc = (c['live_location'] ?? c['last_location']) as Map<String, dynamic>;
                    final lat = (loc['latitude'] as num).toDouble();
                    final lng = (loc['longitude'] as num).toDouble();
                    final isLive = c['live_location'] != null;
                    final updatedAt = isLive ? (loc['updated_at'] as String?) : (loc['timestamp'] as String?);
                    final zoneEvent = c['last_zone_event'] as Map<String, dynamic>?;
                    final zoneEventType = zoneEvent?['event_type'] as String?;
                    return _LiveMapCard(
                      childName: name,
                      lat: lat,
                      lng: lng,
                      isLive: isLive,
                      updatedAt: _formatTime(updatedAt),
                      zoneEventType: zoneEventType,
                      zoneName: zoneEvent?['safe_zones']?['name'] as String?,
                    );
                  }),

                  const SizedBox(height: 4),
                  _SectionHeader(title: 'Children', action: 'See all', onAction: () => setState(() => _selectedIndex = 2)),
                  const SizedBox(height: 10),
                  ..._children.map((c) => _ChildStatusRow(
                    child: c,
                    formatTime: _formatTime,
                    onZonesTap: () async {
                      final name = (c['full_name'] as String?) ?? (c['email'] as String).split('@').first;
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => SafeZonesScreen(childId: c['id'] as String, childName: name)));
                      _loadChildren();
                    },
                  )),
                ],

                const SizedBox(height: 20),

                // Recent activity
                _SectionHeader(title: 'Recent Activity', action: 'See all', onAction: () => setState(() => _selectedIndex = 1)),
                const SizedBox(height: 12),
                if (_loadingAlerts)
                  const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                else if (recentAlerts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: const Color(0xFFFFFFFF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEAE6E0))),
                    child: Text('No activity yet', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFB0A9A0))),
                  )
                else
                  ...recentAlerts.map((a) => _AlertRow(alert: a, formatTime: _formatTime)),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Alerts Page ───────────────────────────────────────────────────────────

  Widget _buildAlertsPage() {
    final filters = ['All', 'SOS', 'Zone', 'Missing', 'Check-ins'];
    List<Map<String, dynamic>> filtered = _alerts;
    if (_alertFilter == 'SOS') {
      filtered = _alerts.where((a) => a['type'] == 'sos').toList();
    } else if (_alertFilter == 'Zone') {
      filtered = _alerts.where((a) => a['type'] == 'zone' && a['event_type'] != 'missing').toList();
    } else if (_alertFilter == 'Missing') {
      filtered = _alerts.where((a) => a['type'] == 'zone' && a['event_type'] == 'missing').toList();
    } else if (_alertFilter == 'Check-ins') {
      filtered = _alerts.where((a) => a['type'] == 'checkin').toList();
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Row(
              children: [
                Expanded(child: Text('Alerts', style: GoogleFonts.dmSerifDisplay(fontSize: 30, color: const Color(0xFF0F0E0B)))),
                if (_hasUrgentAlerts)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: const Color(0xFFFFF0F0), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFFECACA))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 13),
                      const SizedBox(width: 4),
                      Text('$_urgentCount urgent', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFEF4444))),
                    ]),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Filter chips
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: filters.map((f) {
                final selected = f == _alertFilter;
                return GestureDetector(
                  onTap: () => setState(() => _alertFilter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFC9A96E) : const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: selected ? const Color(0xFFC9A96E) : const Color(0xFFEAE6E0)),
                    ),
                    child: Text(f, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: selected ? const Color(0xFF1A1410) : const Color(0xFF6B6560))),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loadingAlerts
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const _EmptyState(icon: Icons.notifications_off_outlined, title: 'No alerts', subtitle: 'Everything looks quiet')
                    : RefreshIndicator(
                        onRefresh: _loadAlerts,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _AlertRow(alert: filtered[i], formatTime: _formatTime),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ── Children Page ─────────────────────────────────────────────────────────

  Widget _buildChildrenPage() {
    final allSafe = _children.isNotEmpty && _children.every((c) {
      final hasSos = c['last_location']?['is_active'] == true;
      final isMissing = c['last_zone_event']?['event_type'] == 'missing';
      return !hasSos && !isMissing;
    });

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Row(
              children: [
                Expanded(child: Text('Children', style: GoogleFonts.dmSerifDisplay(fontSize: 30, color: const Color(0xFF0F0E0B)))),
                GestureDetector(
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const LinkChildScreen()));
                    _loadChildren();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC9A96E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.add_rounded, color: Color(0xFF1A1410), size: 14),
                      const SizedBox(width: 4),
                      Text('Link', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1A1410))),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!_loadingChildren && _children.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: allSafe ? const Color(0xFFF0FDF4) : const Color(0xFFFFF0F0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: allSafe ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(allSafe ? Icons.check_rounded : Icons.warning_amber_rounded,
                      color: allSafe ? const Color(0xFF4B9B6F) : const Color(0xFFEF4444), size: 14),
                  const SizedBox(width: 8),
                  Text(
                    allSafe
                        ? '${_children.length} ${_children.length == 1 ? 'child' : 'children'} — all safe'
                        : 'Attention required',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: allSafe ? const Color(0xFF4B9B6F) : const Color(0xFFEF4444)),
                  ),
                ]),
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: _loadingChildren
                ? const Center(child: CircularProgressIndicator())
                : _children.isEmpty
                    ? _EmptyState(
                        icon: Icons.child_care_rounded,
                        title: 'No children linked',
                        subtitle: 'Tap Link to add a child account',
                        action: 'Link Child',
                        onAction: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => const LinkChildScreen()));
                          _loadChildren();
                        },
                      )
                    : RefreshIndicator(
                        onRefresh: _loadChildren,
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: _children.map((c) => _ChildCard(
                            child: c,
                            formatTime: _formatTime,
                            onZonesTap: () async {
                              final name = (c['full_name'] as String?) ?? (c['email'] as String).split('@').first;
                              await Navigator.push(context, MaterialPageRoute(
                                builder: (_) => SafeZonesScreen(childId: c['id'] as String, childName: name),
                              ));
                              _loadChildren();
                            },
                            onContactsTap: () {
                              final name = (c['full_name'] as String?) ?? (c['email'] as String).split('@').first;
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => EmergencyContactsScreen(childId: c['id'] as String, childName: name),
                              ));
                            },
                          )).toList(),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }
}

// ─── Stat Pill ────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatPill({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$count', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: color.withValues(alpha: 0.7), fontWeight: FontWeight.w400)),
      ]),
    );
  }
}

// ─── Quick Action Card ────────────────────────────────────────────────────────

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({required this.icon, required this.label, required this.value, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEAE6E0)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: const Color(0xFF0F0E0B))),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFB0A9A0), fontWeight: FontWeight.w400)),
        ]),
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const _SectionHeader({required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF6B6560))),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFC9A96E), fontWeight: FontWeight.w500)),
          ),
      ],
    );
  }
}

// ─── Child Status Row (compact) ───────────────────────────────────────────────

class _ChildStatusRow extends StatelessWidget {
  final Map<String, dynamic> child;
  final String Function(String?) formatTime;
  final VoidCallback onZonesTap;

  const _ChildStatusRow({required this.child, required this.formatTime, required this.onZonesTap});

  @override
  Widget build(BuildContext context) {
    final name = (child['full_name'] as String?) ?? (child['email'] as String).split('@').first;
    final liveLoc = child['live_location'] as Map<String, dynamic>?;
    final lastLoc = child['last_location'] as Map<String, dynamic>?;
    final lastZone = child['last_zone_event'] as Map<String, dynamic>?;
    final lastCheckin = child['last_checkin'] as Map<String, dynamic>?;
    final hasActiveSos = lastLoc?['is_active'] == true;
    final zoneEventType = lastZone?['event_type'] as String?;
    final isMissing = zoneEventType == 'missing';

    String statusLabel;
    Color statusColor;

    if (hasActiveSos) {
      statusLabel = 'SOS';
      statusColor = const Color(0xFFDC2626);
    } else if (isMissing) {
      statusLabel = 'Missing';
      statusColor = const Color(0xFFF59E0B);
    } else {
      statusLabel = 'Safe';
      statusColor = const Color(0xFF4B9B6F);
    }

    return GestureDetector(
      onTap: onZonesTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEAE6E0)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEAE6E0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE0DBD4)),
              ),
              child: Center(child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFFC9A96E)),
              )),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0F0E0B))),
                const SizedBox(height: 2),
                if (liveLoc != null)
                  Row(children: [
                    Container(width: 5, height: 5,
                        decoration: const BoxDecoration(color: Color(0xFF4B9B6F), shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text('Live · ${formatTime(liveLoc['updated_at'] as String?)}',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF4B9B6F), fontWeight: FontWeight.w500)),
                  ])
                else if (lastCheckin != null)
                  Text('${lastCheckin['note'] ?? 'Check-in'} · ${formatTime(lastCheckin['created_at'])}',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFB0A9A0)))
                else if (lastLoc != null)
                  Text('Last seen ${formatTime(lastLoc['timestamp'] ?? lastLoc['created_at'])}',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFB0A9A0)))
                else
                  Text('No activity yet', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFD0C9C0))),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Text(statusLabel, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: statusColor)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Alert Row ────────────────────────────────────────────────────────────────

class _AlertRow extends StatelessWidget {
  final Map<String, dynamic> alert;
  final String Function(String?) formatTime;
  const _AlertRow({required this.alert, required this.formatTime});

  @override
  Widget build(BuildContext context) {
    final type = alert['type'] as String;
    final childName = alert['child_name'] as String? ?? 'Child';
    final ts = formatTime(alert['timestamp'] as String?);
    final lat = (alert['latitude'] as num?)?.toDouble();
    final lng = (alert['longitude'] as num?)?.toDouble();
    final hasLoc = lat != null && lng != null && (lat != 0 || lng != 0);

    if (type == 'sos') {
      return _SosAlertCard(alert: alert, childName: childName, ts: ts, lat: lat, lng: lng, hasLoc: hasLoc);
    }
    if (type == 'zone') {
      return _ZoneAlertCard(alert: alert, childName: childName, ts: ts, hasLoc: hasLoc, lat: lat, lng: lng, formatTime: formatTime);
    }
    // checkin
    final status = alert['status'] as String? ?? alert['note'] as String? ?? 'Checked in';
    final note = alert['note'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEAE6E0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF4B9B6F), size: 18),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$childName checked in', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF0F0E0B))),
            Text(status, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF4B9B6F))),
            if (note != null && note.isNotEmpty)
              Text(note, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFB0A9A0))),
          ])),
          Text(ts, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFB0A9A0))),
        ]),
      ),
    );
  }
}

class _SosAlertCard extends StatelessWidget {
  final Map<String, dynamic> alert;
  final String childName, ts;
  final double? lat, lng;
  final bool hasLoc;
  const _SosAlertCard({required this.alert, required this.childName, required this.ts, required this.lat, required this.lng, required this.hasLoc});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF7F0000), Color(0xFFDC2626)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        boxShadow: const [BoxShadow(color: Color(0x40DC2626), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.sos_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('SOS ALERT', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white60, letterSpacing: 2)),
                Text(childName, style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
              ])),
              Text(ts, style: GoogleFonts.inter(fontSize: 11, color: Colors.white60)),
            ]),
          ),
          if (hasLoc) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(children: [
                const Icon(Icons.location_on_rounded, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Text('${lat!.toStringAsFixed(4)}, ${lng!.toStringAsFixed(4)}',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500)),
              ]),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
              child: SizedBox(
                height: 120,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(lat!, lng!),
                    initialZoom: 15,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                  ),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.safenest'),
                    MarkerLayer(markers: [Marker(point: LatLng(lat!, lng!), width: 36, height: 36,
                        child: const Icon(Icons.location_pin, color: Color(0xFFDC2626), size: 36))]),
                  ],
                ),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text('Location unavailable', style: GoogleFonts.inter(fontSize: 12, color: Colors.white54)),
            ),
        ],
      ),
    );
  }
}

class _ZoneAlertCard extends StatelessWidget {
  final Map<String, dynamic> alert;
  final String childName, ts;
  final double? lat, lng;
  final bool hasLoc;
  final String Function(String?) formatTime;
  const _ZoneAlertCard({required this.alert, required this.childName, required this.ts, required this.hasLoc, required this.lat, required this.lng, required this.formatTime});

  @override
  Widget build(BuildContext context) {
    final et = alert['event_type'] as String? ?? '';
    final zoneName = alert['safe_zones']?['name'] as String? ?? 'zone';
    Color accent;
    IconData icon;
    String title, subtitle;
    switch (et) {
      case 'missing':
        accent = const Color(0xFFF59E0B); icon = Icons.warning_amber_rounded;
        title = 'Missing from zone'; subtitle = '$childName is outside "$zoneName"';
        break;
      case 'exited':
        accent = const Color(0xFFEF4444); icon = Icons.logout_rounded;
        title = 'Left safe zone'; subtitle = '$childName left "$zoneName"';
        break;
      default:
        accent = const Color(0xFF059669); icon = Icons.login_rounded;
        title = 'Entered safe zone'; subtitle = '$childName arrived at "$zoneName"';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
            child: Row(children: [
              Icon(icon, color: accent, size: 16),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF0F0E0B))),
                Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFB0A9A0))),
              ])),
              Text(ts, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFB0A9A0))),
            ]),
          ),
          if (hasLoc)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: SizedBox(
                height: 100,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(lat!, lng!),
                    initialZoom: 15,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                  ),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.safenest'),
                    MarkerLayer(markers: [Marker(point: LatLng(lat!, lng!), width: 32, height: 32,
                        child: Icon(Icons.location_pin, color: accent, size: 32))]),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Child Card (full detail) ─────────────────────────────────────────────────

class _ChildCard extends StatelessWidget {
  final Map<String, dynamic> child;
  final String Function(String?) formatTime;
  final VoidCallback onZonesTap;
  final VoidCallback onContactsTap;

  const _ChildCard({required this.child, required this.formatTime, required this.onZonesTap, required this.onContactsTap});

  @override
  Widget build(BuildContext context) {
    final name = (child['full_name'] as String?) ?? (child['email'] as String).split('@').first;
    final liveLoc = child['live_location'] as Map<String, dynamic>?;
    final lastLoc = child['last_location'] as Map<String, dynamic>?;
    final lastZone = child['last_zone_event'] as Map<String, dynamic>?;
    final lastCheckin = child['last_checkin'] as Map<String, dynamic>?;
    final hasActiveSos = lastLoc?['is_active'] == true;
    final zoneEventType = lastZone?['event_type'] as String?;
    final isMissing = zoneEventType == 'missing';
    final mapLoc = liveLoc ?? lastLoc;

    Color statusColor;
    String statusLabel;

    if (hasActiveSos) {
      statusLabel = 'SOS';
      statusColor = const Color(0xFFDC2626);
    } else if (isMissing) {
      statusLabel = 'Missing';
      statusColor = const Color(0xFFF59E0B);
    } else {
      statusLabel = 'Safe';
      statusColor = const Color(0xFF4B9B6F);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEAE6E0)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAE6E0),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE0DBD4)),
                  ),
                  child: Center(child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFFC9A96E)),
                  )),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15, color: const Color(0xFF0F0E0B))),
                    const SizedBox(height: 2),
                    if (liveLoc != null)
                      Row(children: [
                        Container(width: 5, height: 5,
                            decoration: const BoxDecoration(color: Color(0xFF4B9B6F), shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text('Live · ${formatTime(liveLoc['updated_at'] as String?)}',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF4B9B6F), fontWeight: FontWeight.w500)),
                      ])
                    else if (lastCheckin != null)
                      Text('${lastCheckin['note'] ?? 'Check-in'} · ${formatTime(lastCheckin['created_at'])}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFB0A9A0)))
                    else if (lastLoc != null)
                      Text('Last seen ${formatTime(lastLoc['timestamp'] ?? lastLoc['created_at'])}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFB0A9A0)))
                    else
                      Text('No activity yet', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFD0C9C0))),
                    if (lastZone?['safe_zones']?['name'] != null)
                      Text('${_zoneLabel(zoneEventType)} ${lastZone!['safe_zones']['name']}', style: GoogleFonts.inter(fontSize: 11, color: _zoneColor(zoneEventType))),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(statusLabel, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: statusColor)),
                ),
              ],
            ),
          ),

          if (mapLoc != null && (mapLoc['latitude'] as double? ?? 0) != 0)
            Stack(
              children: [
                SizedBox(
                  height: 130,
                  child: ClipRRect(
                    borderRadius: BorderRadius.zero,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(mapLoc['latitude'] as double, mapLoc['longitude'] as double),
                        initialZoom: 15,
                        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                      ),
                      children: [
                        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.safenest'),
                        MarkerLayer(markers: [
                          Marker(
                            point: LatLng(mapLoc['latitude'] as double, mapLoc['longitude'] as double),
                            width: 32, height: 32,
                            child: const Icon(Icons.location_pin, color: Color(0xFFC9A96E), size: 32),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
                // Live badge — only show when using live_location
                if (liveLoc != null)
                  Positioned(
                    top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 6)],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 6, height: 6,
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text(
                          liveLoc['updated_at'] != null
                              ? 'Live · ${formatTime(liveLoc['updated_at'] as String?)}'
                              : 'Live',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ]),
                    ),
                  ),
              ],
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onZonesTap,
                    child: Container(
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F4F0),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE0DBD4)),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.radar_rounded, size: 14, color: Color(0xFF6B6560)),
                        const SizedBox(width: 6),
                        Text('Safe Zones', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF6B6560))),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: onContactsTap,
                    child: Container(
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F4F0),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE0DBD4)),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.contacts_outlined, size: 14, color: Color(0xFF6B6560)),
                        const SizedBox(width: 6),
                        Text('Contacts', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF6B6560))),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _zoneLabel(String? type) {
    switch (type) {
      case 'entered': return 'In';
      case 'exited': return 'Left';
      case 'missing': return 'Missing from';
      default: return '';
    }
  }

  Color _zoneColor(String? type) {
    switch (type) {
      case 'entered': return const Color(0xFF059669);
      case 'exited': return const Color(0xFFF59E0B);
      case 'missing': return const Color(0xFFDC2626);
      default: return const Color(0xFF6B7280);
    }
  }
}

// ─── SOS Urgency Full-Screen Dialog ──────────────────────────────────────────

class _SosUrgencyDialog extends StatefulWidget {
  final String childName;
  final double lat;
  final double lng;
  const _SosUrgencyDialog({required this.childName, required this.lat, required this.lng});

  @override
  State<_SosUrgencyDialog> createState() => _SosUrgencyDialogState();
}

class _SosUrgencyDialogState extends State<_SosUrgencyDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _scale = Tween(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final hasLocation = widget.lat != 0 || widget.lng != 0;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [Color(0xFF7F0000), Color(0xFFDC2626)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pulsing SOS icon
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Transform.scale(
                  scale: _scale.value,
                  child: Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                    ),
                    child: const Icon(Icons.sos_rounded, color: Colors.white, size: 52),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('SOS ALERT', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white60, letterSpacing: 3)),
              const SizedBox(height: 6),
              Text(widget.childName, style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Needs help immediately!', style: GoogleFonts.inter(fontSize: 16, color: Colors.white.withValues(alpha: 0.85))),
              if (hasLocation) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.location_on_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.lat.toStringAsFixed(5)}, ${widget.lng.toStringAsFixed(5)}',
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
                // Inline mini map
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 140,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(widget.lat, widget.lng),
                        initialZoom: 15,
                        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                      ),
                      children: [
                        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.safenest'),
                        MarkerLayer(markers: [
                          Marker(
                            point: LatLng(widget.lat, widget.lng),
                            width: 40, height: 40,
                            child: const Icon(Icons.location_pin, color: Color(0xFFDC2626), size: 40),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFDC2626),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  child: const Text('I\'ve seen this — Open App'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? action;
  final VoidCallback? onAction;

  const _EmptyState({required this.icon, required this.title, required this.subtitle, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 32, color: const Color(0xFFD0C9C0)),
          const SizedBox(height: 16),
          Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: const Color(0xFFB0A9A0))),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFD0C9C0))),
          if (action != null && onAction != null) ...[
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFC9A96E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(action!, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1A1410))),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ─── Live Map Card ────────────────────────────────────────────────────────────

class _LiveMapCard extends StatelessWidget {
  final String childName;
  final double lat;
  final double lng;
  final bool isLive;
  final String updatedAt;
  final String? zoneEventType;
  final String? zoneName;

  const _LiveMapCard({
    required this.childName,
    required this.lat,
    required this.lng,
    required this.isLive,
    required this.updatedAt,
    this.zoneEventType,
    this.zoneName,
  });

  @override
  Widget build(BuildContext context) {
    final isMissing = zoneEventType == 'missing';
    final isInZone = zoneEventType == 'entered';
    final borderColor = isMissing
        ? const Color(0xFFF59E0B)
        : isInZone
            ? const Color(0xFF4B9B6F)
            : const Color(0xFFEAE6E0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: isMissing ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isLive ? const Color(0xFF4B9B6F) : const Color(0xFFB0A9A0),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  childName,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F0E0B)),
                ),
                const SizedBox(width: 6),
                Text(
                  isLive ? 'Live · $updatedAt' : 'Last seen $updatedAt',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isLive
                          ? const Color(0xFF4B9B6F)
                          : const Color(0xFFB0A9A0)),
                ),
                const Spacer(),
                if (zoneName != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isMissing
                          ? const Color(0xFFFEF3C7)
                          : isInZone
                              ? const Color(0xFFF0FDF4)
                              : const Color(0xFFF5F4F0),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                          color: isMissing
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                              : isInZone
                                  ? const Color(0xFF4B9B6F).withValues(alpha: 0.4)
                                  : const Color(0xFFE0DBD4)),
                    ),
                    child: Text(
                      isMissing
                          ? 'Outside $zoneName'
                          : isInZone
                              ? 'In $zoneName'
                              : zoneName!,
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: isMissing
                              ? const Color(0xFFF59E0B)
                              : isInZone
                                  ? const Color(0xFF4B9B6F)
                                  : const Color(0xFFB0A9A0)),
                    ),
                  ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(13)),
            child: SizedBox(
              height: 160,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(lat, lng),
                  initialZoom: 15,
                  interactionOptions:
                      const InteractionOptions(flags: InteractiveFlag.none),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.safenest',
                  ),
                  MarkerLayer(markers: [
                    Marker(
                      point: LatLng(lat, lng),
                      width: 32,
                      height: 32,
                      child: Icon(
                        Icons.location_pin,
                        color: isMissing
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFFC9A96E),
                        size: 32,
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Missing Zone Banner ──────────────────────────────────────────────────────

class _MissingZoneBanner extends StatelessWidget {
  final String childName;
  final String zoneName;
  final Map<String, dynamic>? liveLoc;
  final VoidCallback onDismiss;
  final VoidCallback onAlertContacts;

  const _MissingZoneBanner({
    required this.childName,
    required this.zoneName,
    required this.liveLoc,
    required this.onDismiss,
    required this.onAlertContacts,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFF59E0B), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$childName is not at $zoneName',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F0E0B)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'They were expected to be at this zone. Please verify their whereabouts.',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF6B6560),
                            height: 1.5),
                      ),
                      if (liveLoc != null) ...[
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.location_on_outlined,
                              size: 12, color: Color(0xFFB0A9A0)),
                          const SizedBox(width: 4),
                          Text(
                            '${(liveLoc!['latitude'] as num).toStringAsFixed(4)}, ${(liveLoc!['longitude'] as num).toStringAsFixed(4)}',
                            style: GoogleFonts.inter(
                                fontSize: 11, color: const Color(0xFFB0A9A0)),
                          ),
                        ]),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 1,
            color: const Color(0xFFFEF3C7),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onDismiss,
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: const Color(0xFFE0DBD4)),
                      ),
                      child: Text('Dismiss',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFFB0A9A0),
                              fontWeight: FontWeight.w500)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => _VerifyDialog(childName: childName),
                      );
                    },
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAE6E0),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: const Color(0xFFE0DBD4)),
                      ),
                      child: Text('I\'ll verify',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF0F0E0B),
                              fontWeight: FontWeight.w500)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: onAlertContacts,
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                      ),
                      child: Text('Alert contacts',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFFF59E0B),
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Verify Dialog ────────────────────────────────────────────────────────────

class _VerifyDialog extends StatelessWidget {
  final String childName;
  const _VerifyDialog({required this.childName});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFFFFFFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Verify $childName',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F0E0B))),
            const SizedBox(height: 10),
            Text(
              'Check in with $childName directly — call, message, or contact their school/guardian to confirm their location.',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF6B6560),
                  height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC9A96E),
                  foregroundColor: const Color(0xFF1A1410),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9)),
                ),
                child: Text('Got it',
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1410))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
