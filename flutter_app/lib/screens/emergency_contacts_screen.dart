import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';

class EmergencyContactsScreen extends StatefulWidget {
  final String childId;
  final String childName;
  const EmergencyContactsScreen({super.key, required this.childId, required this.childName});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  List<Map<String, dynamic>> _contacts = [];
  bool _loading = true;

  static const _iconOptions = [
    ('parent', Icons.family_restroom_rounded, 'Parent'),
    ('school', Icons.school_rounded, 'School'),
    ('guardian', Icons.supervisor_account_rounded, 'Guardian'),
    ('police', Icons.local_police_rounded, 'Police'),
    ('doctor', Icons.local_hospital_rounded, 'Doctor'),
    ('person', Icons.person_rounded, 'Other'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await supabase
          .from('emergency_contacts')
          .select()
          .eq('child_id', widget.childId)
          .order('display_order');
      if (mounted) setState(() { _contacts = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(int id) async {
    try {
      await supabase.from('emergency_contacts').delete().eq('id', id);
      await _load();
    } catch (_) {}
  }

  void _openForm({Map<String, dynamic>? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContactForm(
        childId: widget.childId,
        existing: existing,
        displayOrder: existing != null ? (existing['display_order'] as int? ?? 0) : _contacts.length,
        onSaved: _load,
      ),
    );
  }

  IconData _iconFor(String? name) {
    for (final o in _iconOptions) { if (o.$1 == name) return o.$2; }
    return Icons.person_rounded;
  }

  Color _colorFor(String? name) {
    return switch (name) {
      'parent' => const Color(0xFF4F46E5),
      'school' => const Color(0xFF0891B2),
      'guardian' => const Color(0xFF7C3AED),
      'police' => const Color(0xFF1D4ED8),
      'doctor' => const Color(0xFF059669),
      _ => const Color(0xFF6B7280),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Emergency Contacts', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700)),
            Text(widget.childName, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add contact',
            onPressed: () => _openForm(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
              ? _EmptyState(onAdd: () => _openForm())
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _contacts.length,
                  onReorder: _reorder,
                  itemBuilder: (_, i) {
                    final c = _contacts[i];
                    final color = _colorFor(c['icon_name'] as String?);
                    return Dismissible(
                      key: ValueKey(c['id']),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.delete_rounded, color: Colors.white),
                      ),
                      onDismissed: (_) => _delete(c['id'] as int),
                      child: Container(
                        key: ValueKey('tile_${c['id']}'),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                            child: Icon(_iconFor(c['icon_name'] as String?), color: color, size: 22),
                          ),
                          title: Text(c['label'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: const Color(0xFF111827))),
                          subtitle: Text(c['phone'] as String, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6B7280))),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF9CA3AF)),
                                onPressed: () => _openForm(existing: c),
                              ),
                              const Icon(Icons.drag_handle_rounded, color: Color(0xFFD1D5DB)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: _contacts.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add_rounded),
              label: Text('Add Contact', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    setState(() {
      final item = _contacts.removeAt(oldIndex);
      _contacts.insert(newIndex, item);
    });
    // Persist new order
    for (int i = 0; i < _contacts.length; i++) {
      await supabase
          .from('emergency_contacts')
          .update({'display_order': i})
          .eq('id', _contacts[i]['id'] as int);
    }
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(24)),
              child: const Icon(Icons.contacts_rounded, size: 40, color: Color(0xFF4F46E5)),
            ),
            const SizedBox(height: 20),
            Text('No emergency contacts', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
            const SizedBox(height: 8),
            Text(
              "Add school, parent, and guardian numbers so your child can call them with one tap.",
              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add First Contact'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactForm extends StatefulWidget {
  final String childId;
  final Map<String, dynamic>? existing;
  final int displayOrder;
  final VoidCallback onSaved;

  const _ContactForm({required this.childId, this.existing, required this.displayOrder, required this.onSaved});

  @override
  State<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<_ContactForm> {
  final _labelController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedIcon = 'parent';
  bool _saving = false;
  final _formKey = GlobalKey<FormState>();

  static const _iconOptions = [
    ('parent', Icons.family_restroom_rounded, 'Parent'),
    ('school', Icons.school_rounded, 'School'),
    ('guardian', Icons.supervisor_account_rounded, 'Guardian'),
    ('police', Icons.local_police_rounded, 'Police'),
    ('doctor', Icons.local_hospital_rounded, 'Doctor'),
    ('person', Icons.person_rounded, 'Other'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _labelController.text = widget.existing!['label'] as String? ?? '';
      _phoneController.text = widget.existing!['phone'] as String? ?? '';
      _selectedIcon = widget.existing!['icon_name'] as String? ?? 'parent';
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final data = {
        'child_id': widget.childId,
        'label': _labelController.text.trim(),
        'phone': _phoneController.text.trim(),
        'icon_name': _selectedIcon,
        'display_order': widget.displayOrder,
      };
      if (widget.existing != null) {
        await supabase.from('emergency_contacts').update(data).eq('id', widget.existing!['id'] as int);
      } else {
        await supabase.from('emergency_contacts').insert(data);
      }
      HapticFeedback.mediumImpact();
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              Text(isEdit ? 'Edit Contact' : 'Add Contact',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
              const SizedBox(height: 20),

              // Icon type picker
              Text('Type', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF374151))),
              const SizedBox(height: 8),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _iconOptions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final opt = _iconOptions[i];
                    final selected = _selectedIcon == opt.$1;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIcon = opt.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 64,
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFFEEF2FF) : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? const Color(0xFF4F46E5) : const Color(0xFFE5E7EB),
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(opt.$2, size: 22, color: selected ? const Color(0xFF4F46E5) : const Color(0xFF9CA3AF)),
                            const SizedBox(height: 4),
                            Text(opt.$3, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                                color: selected ? const Color(0xFF4F46E5) : const Color(0xFF9CA3AF))),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              Text('Label', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF374151))),
              const SizedBox(height: 6),
              TextFormField(
                controller: _labelController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'e.g. Mum, School Office, Grandma'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),

              Text('Phone Number', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF374151))),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: '+91 98765 43210',
                  prefixIcon: Icon(Icons.phone_outlined, size: 18),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (v.trim().length < 7) return 'Enter a valid phone number';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(isEdit ? 'Save Changes' : 'Add Contact'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
