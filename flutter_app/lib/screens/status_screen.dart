import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../services/zone_monitor.dart';

class StatusScreen extends StatefulWidget {
  final String role;
  const StatusScreen({super.key, required this.role});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  bool _isSharing = false;
  String? _locationError;
  List<Map<String, dynamic>> _sharedLocations = [];
  bool _loadingHistory = true;

  // Pairing state — null = still checking
  bool? _isPaired;

  @override
  void initState() {
    super.initState();
    _checkPairingAndLoad();
  }

  Future<void> _checkPairingAndLoad() async {
    if (widget.role != 'child') {
      // Parents don't need the pairing check on this screen
      setState(() => _isPaired = true);
      return;
    }
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
      final paired = link != null;
      setState(() => _isPaired = paired);
      if (paired) {
        _loadLocationHistory();
        ZoneMonitor().start();
      }
    } catch (_) {
      setState(() => _isPaired = false);
    }
  }

  Future<void> _loadLocationHistory() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      final data = await supabase
          .from('location_shares')
          .select('id, latitude, longitude, created_at')
          .eq('child_id', userId)
          .order('created_at', ascending: false)
          .limit(10);
      if (mounted) {
        setState(() {
          _sharedLocations = List<Map<String, dynamic>>.from(data);
          _loadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _getLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });
    try {
      final status = await Permission.location.request();
      if (!status.isGranted) {
        setState(() {
          _locationError = 'Location permission denied. Please enable it in Settings.';
          _isLoadingLocation = false;
        });
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() {
        _locationError = 'Could not get location. Make sure GPS is enabled.';
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _shareLocation() async {
    if (_currentPosition == null) {
      await _getLocation();
      if (_currentPosition == null) return;
    }
    setState(() => _isSharing = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      // Fetch all parent IDs for this child
      final links = await supabase
          .from('family_links')
          .select('parent_id')
          .eq('child_id', userId);

      if (links.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No parent linked yet', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        return;
      }

      // Insert one row per parent so each parent can see it
      for (final link in links) {
        await supabase.from('location_shares').insert({
          'child_id': userId,
          'parent_id': link['parent_id'],
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location shared with parent(s)', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        _loadLocationHistory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to share location'),
            backgroundColor: Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('MMM d, h:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Still checking pairing status
    if (_isPaired == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Not paired — show a clear waiting screen
    if (_isPaired == false) {
      return _UnpairedScreen();
    }

    return RefreshIndicator(
      onRefresh: _loadLocationHistory,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Location', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
            Text('Share your current position with your parent', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6B7280))),
            const SizedBox(height: 20),

            // Location Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF3F4F6)),
              ),
              child: Column(
                children: [
                  if (_currentPosition != null) ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.location_on_rounded, color: Color(0xFF059669), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Location found', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF059669), fontSize: 14)),
                              Text(
                                '${_currentPosition!.latitude.toStringAsFixed(5)}, ${_currentPosition!.longitude.toStringAsFixed(5)}',
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF6B7280)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    Icon(Icons.location_searching_rounded, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 10),
                    Text('No location yet', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text('Tap below to get your current location', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFD1D5DB))),
                    const SizedBox(height: 16),
                  ],
                  if (_locationError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_locationError!, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFDC2626)))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoadingLocation ? null : _getLocation,
                          icon: _isLoadingLocation
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.my_location_rounded, size: 16),
                          label: Text(_isLoadingLocation ? 'Getting…' : 'Get Location'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (_isSharing || _currentPosition == null) ? null : _shareLocation,
                          icon: _isSharing
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.share_location_rounded, size: 16),
                          label: Text(_isSharing ? 'Sharing…' : 'Share'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text('Shared History', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
            const SizedBox(height: 10),
            if (_loadingHistory)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (_sharedLocations.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Icon(Icons.location_off_outlined, size: 40, color: Colors.grey.shade200),
                    const SizedBox(height: 8),
                    Text('No location history', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF9CA3AF))),
                  ],
                ),
              )
            else
              ..._sharedLocations.map((loc) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF3F4F6)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF059669)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${(loc['latitude'] as double).toStringAsFixed(4)}, ${(loc['longitude'] as double).toStringAsFixed(4)}',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF111827)),
                          ),
                          Text(
                            _formatTime(loc['created_at']),
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF9CA3AF)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
          ],
        ),
      ),
    );
  }
}

class _UnpairedScreen extends StatelessWidget {
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
              'Not linked to a parent yet',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF111827)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Ask your parent to link your account in their SafeNest app using your username.',
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
                      'Location sharing and zone monitoring will be enabled once your parent links your account.',
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
