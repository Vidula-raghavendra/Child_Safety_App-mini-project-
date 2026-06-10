import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../services/zone_monitor.dart';
import 'report_screen.dart';
import 'status_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final String role;
  final String displayName;
  const HomeScreen({super.key, required this.role, required this.displayName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  // null = checking, false = not paired, true = paired
  bool? _isPaired;

  @override
  void initState() {
    super.initState();
    if (widget.role == 'child') {
      _checkPairing();
    } else {
      _isPaired = true;
    }
  }

  Future<void> _checkPairing() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _isPaired = false);
      return;
    }
    try {
      final link = await supabase
          .from('family_links')
          .select('parent_id')
          .eq('child_id', userId)
          .limit(1)
          .maybeSingle();
      if (mounted) {
        setState(() => _isPaired = link != null);
        if (link != null) ZoneMonitor().start();
      }
    } catch (_) {
      if (mounted) setState(() => _isPaired = false);
    }
  }

  String get _firstName => widget.displayName.split(' ').first;

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while pairing check is in progress
    if (_isPaired == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Unpaired child — block the full UI
    if (_isPaired == false) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton(onPressed: _signOut, child: const Text('Sign out')),
              ),
              Expanded(child: _UnpairedHomeScreen(firstName: _firstName)),
            ],
          ),
        ),
      );
    }

    final pages = [
      _ChildHome(firstName: _firstName, onSignOut: _signOut),
      StatusScreen(role: widget.role),
      _HistoryPage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      body: pages[_selectedIndex],
      bottomNavigationBar: _BottomNav(
        selectedIndex: _selectedIndex,
        onSelect: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}

// ─── Bottom Nav ───────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  const _BottomNav({required this.selectedIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x12000000), blurRadius: 20, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home', index: 0, selected: selectedIndex, onTap: onSelect),
              _NavItem(icon: Icons.share_location_outlined, activeIcon: Icons.share_location_rounded, label: 'Share', index: 1, selected: selectedIndex, onTap: onSelect),
              _NavItem(icon: Icons.history_rounded, activeIcon: Icons.history_rounded, label: 'History', index: 2, selected: selectedIndex, onTap: onSelect),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final int index, selected;
  final ValueChanged<int> onTap;
  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.index, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = index == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFEEF2FF) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(isSelected ? activeIcon : icon, size: 22, color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }
}

// ─── Child Home ───────────────────────────────────────────────────────────────

class _UnpairedHomeScreen extends StatelessWidget {
  final String firstName;
  const _UnpairedHomeScreen({required this.firstName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.link_off_rounded, size: 40, color: Color(0xFFF97316)),
            ),
            const SizedBox(height: 20),
            Text(
              'Hi $firstName!',
              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF111827)),
            ),
            const SizedBox(height: 8),
            Text(
              'Your account isn\'t linked to a parent yet.',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF374151)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Ask your parent to open SafeNest and link your account using your username. Once linked, all features will be available.',
              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFFF97316), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Zone monitoring, location sharing, SOS alerts, and check-ins are disabled until you\'re linked.',
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChildHome extends StatefulWidget {
  final String firstName;
  final VoidCallback onSignOut;
  const _ChildHome({required this.firstName, required this.onSignOut});

  @override
  State<_ChildHome> createState() => _ChildHomeState();
}

class _ChildHomeState extends State<_ChildHome> with TickerProviderStateMixin {
  Position? _position;
  List<Map<String, dynamic>> _zones = [];
  List<Map<String, dynamic>> _contacts = [];
  bool _loadingContacts = true;
  Timer? _locationTimer;
  Timer? _liveLocTimer;
  StreamSubscription<AccelerometerEvent>? _shakeSub;
  DateTime? _lastShakeTriggered;
  bool _sosSending = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  late AnimationController _sosController;
  late Animation<double> _sosAnim;

  // Shake detection accumulator
  double _shakeAccum = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _sosController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _sosAnim = Tween<double>(begin: 1.0, end: 1.06).animate(CurvedAnimation(parent: _sosController, curve: Curves.easeInOut));
    _initLocation();
    _loadZones();
    _loadContacts();
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshAndPushLocation());
    _startShakeDetection();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _liveLocTimer?.cancel();
    _shakeSub?.cancel();
    _pulseController.dispose();
    _sosController.dispose();
    super.dispose();
  }

  // ── Location ────────────────────────────────────────────────────────────────

  Future<void> _initLocation() async {
    try {
      final status = await Permission.location.request();
      if (!status.isGranted) return;
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 8));
      if (mounted) setState(() => _position = pos);
      _pushLiveLocation(pos);
    } catch (_) {}
  }

  Future<void> _refreshAndPushLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 5));
      if (mounted) setState(() => _position = pos);
      _pushLiveLocation(pos);
    } catch (_) {}
  }

  // Push location to live_locations table so parent sees it in real-time
  Future<void> _pushLiveLocation(Position pos) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await supabase.from('live_locations').upsert({
        'child_id': userId,
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'child_id');
    } catch (_) {}
  }

  // ── Data ────────────────────────────────────────────────────────────────────

  Future<void> _loadZones() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      final data = await supabase
          .from('safe_zones')
          .select('id, name, latitude, longitude, radius_meters')
          .eq('child_id', userId);
      if (mounted) setState(() => _zones = List<Map<String, dynamic>>.from(data));
    } catch (_) {}
  }

  Future<void> _loadContacts() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data = await supabase
          .from('emergency_contacts')
          .select('id, label, phone, icon_name')
          .eq('child_id', userId)
          .order('display_order', ascending: true);
      if (mounted) {
        setState(() {
          _contacts = List<Map<String, dynamic>>.from(data);
          _loadingContacts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingContacts = false);
    }
  }

  // ── SOS ─────────────────────────────────────────────────────────────────────

  Future<void> _triggerSOS({bool viaSMS = false}) async {
    if (_sosSending) return;
    setState(() => _sosSending = true);
    HapticFeedback.heavyImpact();

    final userId = supabase.auth.currentUser?.id;
    final lat = _position?.latitude ?? 0.0;
    final lng = _position?.longitude ?? 0.0;

    // Always try to write to DB (works when online)
    if (userId != null) {
      try {
        final links = await supabase.from('family_links').select('parent_id').eq('child_id', userId);
        for (final link in links as List) {
          await supabase.from('sos_alerts').insert({
            'user_id': userId,
            'parent_id': link['parent_id'],
            'latitude': lat,
            'longitude': lng,
            'is_active': true,
          });
        }
      } catch (_) {}
    }

    if (viaSMS) {
      // Offline fallback — open SMS app pre-filled with SOS message to first parent contact
      final parentPhone = _contacts
          .where((c) => (c['label'] as String? ?? '').toLowerCase().contains('parent') ||
                        (c['label'] as String? ?? '').toLowerCase().contains('mom') ||
                        (c['label'] as String? ?? '').toLowerCase().contains('dad'))
          .map((c) => c['phone'] as String?)
          .where((p) => p != null && p.isNotEmpty)
          .firstOrNull;
      final phone = parentPhone ?? '';
      final msg = Uri.encodeComponent(
        'SOS! I need help! My location: https://maps.google.com/?q=$lat,$lng',
      );
      final smsUri = Uri.parse('sms:$phone?body=$msg');
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      }
    }

    if (mounted) {
      setState(() => _sosSending = false);
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(viaSMS ? 'SMS SOS sent!' : 'SOS alert sent to parent!',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
        ]),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ));
    }
  }

  // Hold SOS 3s → fake call screen (plausible deniability in a threat situation)
  // while silently sending the SOS alert
  Future<void> _triggerFakeCall() async {
    _triggerSOS(); // silent SOS in background
    if (mounted) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _FakeCallScreen()));
    }
  }

  // ── Shake detection ─────────────────────────────────────────────────────────

  void _startShakeDetection() {
    _shakeSub = accelerometerEventStream().listen((event) {
      final mag = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      // Gravity is ~9.8; shake adds delta above that
      final delta = (mag - 9.8).abs();
      if (delta > 12) {
        _shakeAccum += delta;
        if (_shakeAccum > 60) {
          _shakeAccum = 0;
          final now = DateTime.now();
          if (_lastShakeTriggered == null ||
              now.difference(_lastShakeTriggered!).inSeconds > 30) {
            _lastShakeTriggered = now;
            _triggerSOS();
          }
        }
      } else {
        _shakeAccum = (_shakeAccum - 5).clamp(0, double.infinity);
      }
    });
  }

  // ── Calls ───────────────────────────────────────────────────────────────────

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch phone call')),
      );
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  bool _isInZone(Map<String, dynamic> zone) {
    if (_position == null) return false;
    final d = _haversine(_position!.latitude, _position!.longitude,
        zone['latitude'] as double, zone['longitude'] as double);
    return d <= (zone['radius_meters'] as int);
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  bool get _isSafe => _position != null && _zones.isNotEmpty && _zones.any(_isInZone);

  Color get _statusColor {
    if (_position == null) return const Color(0xFF94A3B8);
    if (_zones.isEmpty) return const Color(0xFF4F46E5);
    return _isSafe ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
  }

  String get _statusText {
    if (_position == null) return 'Locating you…';
    if (_zones.isEmpty) return 'No zones set';
    return _isSafe ? 'You\'re Safe ✓' : 'Outside Safe Zone';
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _showCheckIn() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _CheckInSheet(position: _position, onDone: () {}),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top bar ──────────────────────────────────────────────────
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_greeting(), style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6B7280))),
                  Text(widget.firstName, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: const Color(0xFF111827))),
                ])),
                GestureDetector(
                  onTap: widget.onSignOut,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8)]),
                    child: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFF6B7280)),
                  ),
                ),
              ]),

              const SizedBox(height: 20),

              // ── Status orb ───────────────────────────────────────────────
              Center(
                child: AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, child) => Transform.scale(scale: _pulseAnim.value, child: child),
                  child: Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _statusColor.withValues(alpha: 0.15),
                      border: Border.all(color: _statusColor, width: 3),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(_isSafe ? Icons.shield_rounded : Icons.location_searching_rounded,
                          color: _statusColor, size: 36),
                      const SizedBox(height: 4),
                      Text(_isSafe ? 'SAFE' : (_position == null ? '…' : 'ALERT'),
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _statusColor)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(child: Text(_statusText,
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF374151)))),
              if (_zones.isNotEmpty) ...[
                const SizedBox(height: 6),
                Center(child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: _zones.map((z) {
                      final inside = _isInZone(z);
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: inside ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(inside ? Icons.check_circle_rounded : Icons.circle_outlined,
                              size: 11, color: inside ? const Color(0xFF059669) : const Color(0xFF9CA3AF)),
                          const SizedBox(width: 4),
                          Text(z['name'] ?? '', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600,
                              color: inside ? const Color(0xFF15803D) : const Color(0xFF6B7280))),
                        ]),
                      );
                    }).toList(),
                  ),
                )),
              ],

              const SizedBox(height: 28),

              // ── Big SOS button ───────────────────────────────────────────
              Center(
                child: Column(children: [
                  Text('EMERGENCY', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800,
                      letterSpacing: 2, color: const Color(0xFF9CA3AF))),
                  const SizedBox(height: 10),
                  // Online SOS — tap-and-hold
                  GestureDetector(
                    onLongPress: _triggerSOS,
                    onLongPressStart: (_) => HapticFeedback.mediumImpact(),
                    child: AnimatedBuilder(
                      animation: _sosAnim,
                      builder: (_, child) => Transform.scale(scale: _sosSending ? 0.96 : _sosAnim.value, child: child),
                      child: Container(
                        width: 140, height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(colors: [Color(0xFFFF3B3B), Color(0xFFDC2626)]),
                          boxShadow: [BoxShadow(color: const Color(0xFFDC2626).withValues(alpha: 0.45), blurRadius: 32, spreadRadius: 4)],
                        ),
                        child: _sosSending
                            ? const Center(child: SizedBox(width: 32, height: 32,
                                child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)))
                            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                const Icon(Icons.sos_rounded, color: Colors.white, size: 40),
                                Text('HOLD', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700,
                                    color: Colors.white70, letterSpacing: 2)),
                              ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Hold 1 second to send SOS', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF9CA3AF))),
                  const SizedBox(height: 4),
                  Text('Shake phone anytime to trigger silently', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFB0B7C3))),
                ]),
              ),

              const SizedBox(height: 16),

              // ── Offline SMS SOS ──────────────────────────────────────────
              GestureDetector(
                onTap: () => _triggerSOS(viaSMS: true),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C2E),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Color(0x20000000), blurRadius: 12, offset: Offset(0, 4))],
                  ),
                  child: Row(children: [
                    const Icon(Icons.sms_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('SMS SOS — No Internet Needed', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                      Text('Opens SMS to parent with your location', style: GoogleFonts.inter(fontSize: 11, color: Colors.white54)),
                    ])),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
                  ]),
                ),
              ),

              const SizedBox(height: 24),

              // ── Fake call panic mode ─────────────────────────────────────
              GestureDetector(
                onTap: _triggerFakeCall,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3))],
                  ),
                  child: Row(children: [
                    Container(padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF4F46E5), size: 20)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Fake Call', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
                      Text('Escape a situation — sends silent SOS + fake call', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF6B7280))),
                    ])),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFD1D5DB), size: 14),
                  ]),
                ),
              ),

              const SizedBox(height: 24),

              // ── Emergency contacts ───────────────────────────────────────
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Emergency Contacts', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF111827))),
                GestureDetector(
                  onTap: _loadContacts,
                  child: Text('Refresh', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF4F46E5), fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 12),
              if (_loadingContacts)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
              else if (_contacts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF3F4F6))),
                  child: Column(children: [
                    const Icon(Icons.contacts_rounded, size: 36, color: Color(0xFFD1D5DB)),
                    const SizedBox(height: 8),
                    Text('No emergency contacts set', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text('Ask your parent to add contacts in the app', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFD1D5DB))),
                  ]),
                )
              else
                ..._contacts.map((c) => _ContactTile(contact: c, onCall: _call)),

              const SizedBox(height: 24),

              // ── Quick actions row ────────────────────────────────────────
              Row(children: [
                Expanded(child: _QuickActionCard(
                  icon: Icons.check_circle_rounded,
                  label: 'Check In',
                  color: const Color(0xFF4F46E5),
                  onTap: _showCheckIn,
                )),
                const SizedBox(width: 12),
                Expanded(child: _QuickActionCard(
                  icon: Icons.flag_rounded,
                  label: 'Report',
                  color: const Color(0xFFF59E0B),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportScreen())),
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Contact Tile ─────────────────────────────────────────────────────────────

class _ContactTile extends StatelessWidget {
  final Map<String, dynamic> contact;
  final Future<void> Function(String) onCall;
  const _ContactTile({required this.contact, required this.onCall});

  static const _iconMap = {
    'parent': Icons.family_restroom_rounded,
    'school': Icons.school_rounded,
    'guardian': Icons.supervisor_account_rounded,
    'police': Icons.local_police_rounded,
    'doctor': Icons.medical_services_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final label = contact['label'] as String? ?? 'Contact';
    final phone = contact['phone'] as String? ?? '';
    final iconName = contact['icon_name'] as String? ?? 'guardian';
    final icon = _iconMap[iconName] ?? Icons.person_rounded;
    final colors = {
      'parent': const Color(0xFF4F46E5),
      'school': const Color(0xFF059669),
      'guardian': const Color(0xFFF59E0B),
      'police': const Color(0xFF0EA5E9),
      'doctor': const Color(0xFFEF4444),
    };
    final color = colors[iconName] ?? const Color(0xFF4F46E5);

    return GestureDetector(
      onTap: () => onCall(phone),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3))],
        ),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
            Text(phone.isEmpty ? 'No number set' : phone,
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280))),
          ])),
          const DecoratedBox(
            decoration: BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.phone_rounded, color: Color(0xFF059669), size: 18),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Quick Action Card ────────────────────────────────────────────────────────

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickActionCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 3))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
        ]),
      ),
    );
  }
}

// ─── Fake Call Screen ─────────────────────────────────────────────────────────

class _FakeCallScreen extends StatefulWidget {
  const _FakeCallScreen();

  @override
  State<_FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<_FakeCallScreen> {
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _elapsed {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(children: [
            const SizedBox(height: 60),
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2C2C2E),
                border: Border.all(color: const Color(0xFF48484A), width: 2),
              ),
              child: const Icon(Icons.person_rounded, color: Colors.white54, size: 44),
            ),
            const SizedBox(height: 20),
            Text('Mom', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: 6),
            Text(_elapsed, style: GoogleFonts.inter(fontSize: 16, color: Colors.white54)),
            const Spacer(),
            // Call controls row
            const Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _CallControl(icon: Icons.mic_off_rounded, label: 'mute', color: Color(0xFF2C2C2E)),
              _CallControl(icon: Icons.volume_up_rounded, label: 'speaker', color: Color(0xFF2C2C2E)),
              _CallControl(icon: Icons.dialpad_rounded, label: 'keypad', color: Color(0xFF2C2C2E)),
            ]),
            const SizedBox(height: 32),
            const Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _CallControl(icon: Icons.videocam_rounded, label: 'FaceTime', color: Color(0xFF2C2C2E)),
              _CallControl(icon: Icons.person_add_rounded, label: 'add call', color: Color(0xFF2C2C2E)),
              _CallControl(icon: Icons.signal_cellular_alt_rounded, label: 'signal', color: Color(0xFF2C2C2E)),
            ]),
            const SizedBox(height: 40),
            // End call
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 72, height: 72,
                decoration: const BoxDecoration(color: Color(0xFFFF3B30), shape: BoxShape.circle),
                child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 32),
              ),
            ),
            const SizedBox(height: 48),
          ]),
        ),
      ),
    );
  }
}

class _CallControl extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _CallControl({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 60, height: 60,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
      const SizedBox(height: 6),
      Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.white54)),
    ]);
  }
}

// ─── Check-in Sheet ───────────────────────────────────────────────────────────

class _CheckInSheet extends StatefulWidget {
  final Position? position;
  final VoidCallback onDone;
  const _CheckInSheet({required this.position, required this.onDone});

  @override
  State<_CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends State<_CheckInSheet> {
  static const _statuses = [
    {'emoji': '🏠', 'label': 'At Home'},
    {'emoji': '🏫', 'label': 'At School'},
    {'emoji': '🚌', 'label': 'On the Way'},
    {'emoji': '⚽', 'label': 'At Practice'},
    {'emoji': '👥', 'label': 'With Friends'},
    {'emoji': '🛒', 'label': 'Shopping'},
    {'emoji': '🍔', 'label': 'Getting Food'},
    {'emoji': '📚', 'label': 'At Library'},
  ];

  String? _selected;
  final _noteController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_selected == null) return;
    setState(() => _isSending = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      // Fetch all parents linked to this child so each gets the check-in
      final links = await supabase
          .from('family_links')
          .select('parent_id')
          .eq('child_id', userId);
      for (final link in links) {
        await supabase.from('check_ins').insert({
          'child_id': userId,
          'parent_id': link['parent_id'],
          'status': _selected,
          'note': _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          'latitude': widget.position?.latitude,
          'longitude': widget.position?.longitude,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
      HapticFeedback.mediumImpact();
      if (mounted) {
        Navigator.pop(context);
        widget.onDone();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            Text(_selected!.split(' ').first, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text('Check-in sent!', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
          ]),
          backgroundColor: const Color(0xFF4F46E5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ));
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text('Where are you?', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
          Text('Let your family know you\'re okay', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
          const SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.88,
            physics: const NeverScrollableScrollPhysics(),
            children: _statuses.map((s) {
              final label = '${s['emoji']} ${s['label']}';
              final isSelected = _selected == label;
              return GestureDetector(
                onTap: () => setState(() => _selected = label),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0), width: isSelected ? 2 : 1),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(s['emoji']!, style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 4),
                    Text(s['label']!, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B))),
                  ]),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              hintText: 'Add a note (optional)…',
              hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _selected == null || _isSending ? null : _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE2E8F0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              child: _isSending
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Send Check-in'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Activity Row ─────────────────────────────────────────────────────────────

class _ActivityRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final String Function(String?) formatTime;
  const _ActivityRow({required this.item, required this.formatTime});

  @override
  Widget build(BuildContext context) {
    final kind = item['kind'] as String;
    Color accentColor;
    Color iconBg;
    IconData icon;
    String title;
    String subtitle;

    switch (kind) {
      case 'sos':
        accentColor = const Color(0xFFEF4444);
        iconBg = const Color(0xFFFEE2E2);
        icon = Icons.sos_rounded;
        title = 'SOS Alert sent';
        subtitle = item['is_active'] == true ? 'Still active' : 'Resolved';
        break;
      case 'zone':
        final et = item['event_type'] as String? ?? '';
        accentColor = et == 'entered' ? const Color(0xFF10B981) : et == 'missing' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
        iconBg = et == 'entered' ? const Color(0xFFDCFCE7) : et == 'missing' ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7);
        icon = et == 'entered' ? Icons.login_rounded : et == 'missing' ? Icons.warning_amber_rounded : Icons.logout_rounded;
        title = et == 'entered' ? 'Entered safe zone' : et == 'missing' ? 'Missing from zone' : 'Left safe zone';
        subtitle = item['safe_zones']?['name'] ?? '';
        break;
      default:
        accentColor = const Color(0xFF4F46E5);
        iconBg = const Color(0xFFEEF2FF);
        icon = Icons.flag_rounded;
        title = 'Incident reported';
        subtitle = item['report_type'] as String? ?? '';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: accentColor, width: 3)),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 16, color: accentColor)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
            if (subtitle.isNotEmpty) Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
          ])),
          Text(formatTime(item['timestamp'] as String?), style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
        ]),
      ),
    );
  }
}

// ─── History Page ─────────────────────────────────────────────────────────────

class _HistoryPage extends StatefulWidget {
  @override
  State<_HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<_HistoryPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      final reports = await supabase.from('reports').select('description, status, timestamp, report_type').eq('user_id', userId).order('timestamp', ascending: false).limit(20);
      final alerts = await supabase.from('sos_alerts').select('timestamp, is_active').eq('user_id', userId).order('timestamp', ascending: false).limit(10);
      final zones = await supabase.from('zone_events').select('event_type, timestamp, safe_zones(name)').eq('child_id', userId).order('timestamp', ascending: false).limit(20);
      final checkins = await supabase.from('check_ins').select('status, note, timestamp').eq('child_id', userId).order('timestamp', ascending: false).limit(10);

      final combined = <Map<String, dynamic>>[];
      for (final r in reports as List) { combined.add({'kind': 'report', ...r}); }
      for (final a in alerts as List) { combined.add({'kind': 'sos', ...a}); }
      for (final z in zones as List) { combined.add({'kind': 'zone', ...z}); }
      for (final c in checkins as List) { combined.add({'kind': 'checkin', ...c}); }
      combined.sort((a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''));
      if (mounted) setState(() { _items = combined; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try { return DateFormat('MMM d, h:mm a').format(DateTime.parse(iso).toLocal()); }
    catch (_) { return ''; }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'All') return _items;
    return _items.where((i) => i['kind'] == _filter.toLowerCase()).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ['All', 'Checkin', 'Zone', 'SOS', 'Report'];
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Text('History', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: filters.map((f) {
                final selected = f == _filter;
                return GestureDetector(
                  onTap: () => setState(() => _filter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF4F46E5) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: selected ? const [BoxShadow(color: Color(0x404F46E5), blurRadius: 8, offset: Offset(0, 3))] : null,
                    ),
                    child: Text(f, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : const Color(0xFF6B7280))),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle), child: Icon(Icons.history_outlined, size: 36, color: Colors.grey.shade300)),
                        const SizedBox(height: 14),
                        Text('No history yet', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text('Your events will appear here', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13)),
                      ]))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final item = _filtered[i];
                            if (item['kind'] == 'checkin') {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: const Border(left: BorderSide(color: Color(0xFF4F46E5), width: 3)),
                                  boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 2))],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(13),
                                  child: Row(children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)),
                                      child: Text(item['status'].toString().split(' ').first, style: const TextStyle(fontSize: 18)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(item['status'] ?? '', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                                      if ((item['note'] ?? '').isNotEmpty) Text(item['note'], style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                    ])),
                                    Text(_formatTime(item['timestamp'] as String?), style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                                  ]),
                                ),
                              );
                            }
                            return _ActivityRow(item: item, formatTime: _formatTime);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
