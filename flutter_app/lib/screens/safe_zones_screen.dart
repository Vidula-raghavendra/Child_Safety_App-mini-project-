import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import 'add_zone_screen.dart';

class SafeZonesScreen extends StatefulWidget {
  final String childId;
  final String childName;

  const SafeZonesScreen({super.key, required this.childId, required this.childName});

  @override
  State<SafeZonesScreen> createState() => _SafeZonesScreenState();
}

class _SafeZonesScreenState extends State<SafeZonesScreen> {
  List<Map<String, dynamic>> _zones = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await supabase
          .from('safe_zones')
          .select()
          .eq('parent_id', supabase.auth.currentUser!.id)
          .eq('child_id', widget.childId)
          .order('created_at', ascending: false);
      if (mounted) setState(() { _zones = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Zone?', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text('This zone and its alert history will be removed.', style: GoogleFonts.inter()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    await supabase.from('safe_zones').delete().eq('id', id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.childName}\'s Zones'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Zone',
            onPressed: () async {
              final result = await Navigator.push<bool>(context, MaterialPageRoute(
                builder: (_) => AddZoneScreen(childId: widget.childId, childName: widget.childName),
              ));
              if (result == true) _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _zones.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map_outlined, size: 56, color: Colors.grey.shade200),
                      const SizedBox(height: 12),
                      Text('No safe zones yet', style: GoogleFonts.inter(color: const Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      Text('Tap + to create one', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFD1D5DB))),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _zones.length,
                    itemBuilder: (_, i) {
                      final z = _zones[i];
                      final hasTime = z['required_from'] != null && z['required_until'] != null;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF3F4F6)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.radar_rounded, color: Color(0xFF4F46E5), size: 22),
                          ),
                          title: Text(z['name'] ?? 'Zone', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('Radius: ${z['radius_meters']}m', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280))),
                              if (hasTime)
                                Text('Required: ${z['required_from']?.substring(0, 5)} – ${z['required_until']?.substring(0, 5)}',
                                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF4F46E5))),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF6B7280)),
                                onPressed: () async {
                                  final result = await Navigator.push<bool>(context, MaterialPageRoute(
                                    builder: (_) => AddZoneScreen(childId: widget.childId, childName: widget.childName, existing: z),
                                  ));
                                  if (result == true) _load();
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                                onPressed: () => _delete(z['id'] as int),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
