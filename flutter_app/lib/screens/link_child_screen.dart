import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';

class LinkChildScreen extends StatefulWidget {
  const LinkChildScreen({super.key});

  @override
  State<LinkChildScreen> createState() => _LinkChildScreenState();
}

class _LinkChildScreenState extends State<LinkChildScreen> {
  final _usernameController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) return;
    setState(() { _isLoading = true; _error = null; _success = null; });

    try {
      final fakeEmail = '${username.toLowerCase().replaceAll(' ', '_')}@safenest.app';

      // Find user with that email
      final result = await supabase
          .from('users')
          .select('id, full_name, role')
          .eq('email', fakeEmail)
          .maybeSingle();

      if (result == null) {
        setState(() { _error = 'No user found with username "$username"'; });
        return;
      }
      if (result['role'] != 'child') {
        setState(() { _error = 'That user is not registered as a child.'; });
        return;
      }

      final parentId = supabase.auth.currentUser!.id;
      final childId = result['id'] as String;

      if (childId == parentId) {
        setState(() { _error = 'You cannot link yourself.'; });
        return;
      }

      await supabase.from('family_links').upsert({
        'parent_id': parentId,
        'child_id': childId,
      });

      setState(() {
        _success = 'Linked to ${result['full_name'] ?? username} successfully!';
        _usernameController.clear();
      });
    } catch (e) {
      setState(() { _error = 'Something went wrong. Try again.'; });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Link a Child'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF4F46E5), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Enter the child\'s username they used when signing up.',
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF3730A3)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text('Child\'s Username', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
            const SizedBox(height: 8),
            TextField(
              controller: _usernameController,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: 'e.g. john_doe',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFECACA))),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFDC2626)))),
                ]),
              ),
            ],
            if (_success != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFBBF7D0))),
                child: Row(children: [
                  const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF059669), size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_success!, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF059669)))),
                ]),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _link,
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Link Child'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
