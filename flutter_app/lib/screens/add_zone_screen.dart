import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../main.dart';

class AddZoneScreen extends StatefulWidget {
  final String? childId;
  final String? childName;
  final Map<String, dynamic>? existing;

  const AddZoneScreen({super.key, this.childId, this.childName, this.existing});

  @override
  State<AddZoneScreen> createState() => _AddZoneScreenState();
}

class _AddZoneScreenState extends State<AddZoneScreen> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  final _mapController = MapController();
  final _searchFocusNode = FocusNode();

  LatLng _center = const LatLng(12.9716, 77.5946);
  LatLng? _pickedLocation;
  double _radius = 100;
  TimeOfDay? _requiredFrom;
  TimeOfDay? _requiredUntil;
  bool _isSaving = false;

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final z = widget.existing!;
      _nameController.text = z['name'] ?? '';
      _pickedLocation = LatLng(z['latitude'] as double, z['longitude'] as double);
      _center = _pickedLocation!;
      _radius = (z['radius_meters'] as int).toDouble();
      if (z['required_from'] != null) _requiredFrom = _parseTime(z['required_from']);
      if (z['required_until'] != null) _requiredUntil = _parseTime(z['required_until']);
    }
    _tryGetLocation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _tryGetLocation() async {
    try {
      final status = await Permission.location.request();
      if (!status.isGranted) return;
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
      if (mounted && _pickedLocation == null) {
        setState(() => _center = LatLng(pos.latitude, pos.longitude));
        _mapController.move(_center, 15);
      }
    } catch (_) {}
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() => _searchResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () => _doSearch(query.trim()));
  }

  Future<void> _doSearch(String query) async {
    setState(() => _isSearching = true);
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/search').replace(
        queryParameters: {'q': query, 'format': 'json', 'limit': '5', 'addressdetails': '1'},
      );
      final resp = await http.get(uri, headers: {'User-Agent': 'SafeNest/1.0'});
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List;
        if (mounted) {
          setState(() {
            _searchResults = data.cast<Map<String, dynamic>>();
            _isSearching = false;
          });
        }
      } else {
        if (mounted) setState(() => _isSearching = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _onSelectResult(Map<String, dynamic> result) {
    final lat = double.tryParse(result['lat'] as String? ?? '') ?? 0;
    final lng = double.tryParse(result['lon'] as String? ?? '') ?? 0;
    final latlng = LatLng(lat, lng);
    _searchFocusNode.unfocus();
    setState(() {
      _pickedLocation = latlng;
      _center = latlng;
      _searchResults = [];
      _searchController.clear();
    });
    _mapController.move(latlng, 15);
  }

  TimeOfDay? _parseTime(String t) {
    try {
      final parts = t.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a zone name')));
      return;
    }
    if (_pickedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please tap the map to set the zone center')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final parentId = supabase.auth.currentUser!.id;
      final data = {
        'parent_id': parentId,
        'child_id': widget.childId,
        'name': _nameController.text.trim(),
        'latitude': _pickedLocation!.latitude,
        'longitude': _pickedLocation!.longitude,
        'radius_meters': _radius.round(),
        'required_from': _requiredFrom != null ? _formatTimeOfDay(_requiredFrom!) : null,
        'required_until': _requiredUntil != null ? _formatTimeOfDay(_requiredUntil!) : null,
      };
      if (widget.existing != null) {
        await supabase.from('safe_zones').update(data).eq('id', widget.existing!['id'] as int);
      } else {
        await supabase.from('safe_zones').insert(data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.existing != null ? 'Edit Zone' : 'New Safe Zone',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17, color: const Color(0xFF0F172A)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF4F46E5))),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: const Color(0x14000000), blurRadius: 12, offset: const Offset(0, 2))],
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search for a location…',
                  hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                  prefixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchResults = []);
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),

          // Search results (between search bar and map, not overlaid)
          if (_searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: const Color(0x14000000), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: _searchResults.map((r) {
                  final displayName = r['display_name'] as String? ?? '';
                  final truncated = displayName.length > 60 ? '${displayName.substring(0, 60)}…' : displayName;
                  return InkWell(
                    onTap: () => _onSelectResult(r),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF4F46E5)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              truncated,
                              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // Map
          SizedBox(
            height: 240,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 15,
                    onTap: (_, latlng) {
                      setState(() {
                        _pickedLocation = latlng;
                        _searchResults = [];
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.safenest',
                    ),
                    if (_pickedLocation != null)
                      CircleLayer(circles: [
                        CircleMarker(
                          point: _pickedLocation!,
                          radius: _radius,
                          color: const Color(0x334F46E5),
                          borderColor: const Color(0xFF4F46E5),
                          borderStrokeWidth: 2,
                          useRadiusInMeter: true,
                        ),
                      ]),
                    if (_pickedLocation != null)
                      MarkerLayer(markers: [
                        Marker(
                          point: _pickedLocation!,
                          width: 32,
                          height: 32,
                          child: const Icon(Icons.location_pin, color: Color(0xFF4F46E5), size: 32),
                        ),
                      ]),
                  ],
                ),
                if (_pickedLocation == null && _searchResults.isEmpty)
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          'Tap on the map to set zone center',
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Zone settings
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.childName != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        const Icon(Icons.child_care_rounded, size: 16, color: Color(0xFF4F46E5)),
                        const SizedBox(width: 8),
                        Text(
                          'Zone for ${widget.childName}',
                          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF4F46E5), fontWeight: FontWeight.w500),
                        ),
                      ]),
                    ),

                  _SectionLabel('Zone Name'),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: 'e.g. School, Home, Park',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _SectionLabel('Radius: ${_radius.round()} meters'),
                  Slider(
                    value: _radius,
                    min: 50,
                    max: 1000,
                    divisions: 19,
                    activeColor: const Color(0xFF4F46E5),
                    onChanged: (v) => setState(() => _radius = v),
                  ),
                  const SizedBox(height: 20),

                  _SectionLabel('Required Time Window (optional)'),
                  Text(
                    'Child must be inside this zone during these hours.',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _TimePicker(
                        label: 'From',
                        time: _requiredFrom,
                        onPick: (t) => setState(() => _requiredFrom = t),
                        onClear: () => setState(() => _requiredFrom = null),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _TimePicker(
                        label: 'Until',
                        time: _requiredUntil,
                        onPick: (t) => setState(() => _requiredUntil = t),
                        onClear: () => setState(() => _requiredUntil = null),
                      )),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
    ),
  );
}

class _TimePicker extends StatelessWidget {
  final String label;
  final TimeOfDay? time;
  final ValueChanged<TimeOfDay> onPick;
  final VoidCallback onClear;

  const _TimePicker({required this.label, required this.time, required this.onPick, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: time ?? TimeOfDay.now());
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: time != null ? const Color(0xFF4F46E5) : const Color(0xFFE5E7EB),
            width: time != null ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.access_time_rounded,
              size: 16,
              color: time != null ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                time != null ? time!.format(context) : label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: time != null ? FontWeight.w600 : FontWeight.normal,
                  color: time != null ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
                ),
              ),
            ),
            if (time != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF94A3B8)),
              ),
          ],
        ),
      ),
    );
  }
}
