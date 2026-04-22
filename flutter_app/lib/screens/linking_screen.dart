import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../models/user_profile.dart';

class LinkingScreen extends StatefulWidget {
  final UserProfile profile;
  const LinkingScreen({super.key, required this.profile});

  @override
  State<LinkingScreen> createState() => _LinkingScreenState();
}

class _LinkingScreenState extends State<LinkingScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _status;

  @override
  Widget build(BuildContext context) {
    final firebase = Provider.of<FirebaseService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Secure Link')),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.lock, size: 64, color: Colors.indigo),
            const SizedBox(height: 24),
            Text(
              widget.profile.role == 'parent' 
                ? 'Generate Code for Child' 
                : 'Enter Code from Parent',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (widget.profile.role == 'parent') ...[
              if (widget.profile.linkingCode != null && widget.profile.linkingCode!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    widget.profile.linkingCode!,
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: 8, color: Colors.indigo),
                  ),
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : () async {
                  setState(() => _isLoading = true);
                  await firebase.generateLinkingCode(widget.profile.uid);
                  setState(() => _isLoading = false);
                },
                child: const Text('Generate New Code'),
              ),
            ] else ...[
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  hintText: '000000',
                  labelText: '6-Digit Code',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 12),
              ),
              const SizedBox(height: 24),
              if (_status != null) Text(_status!, style: const TextStyle(color: Colors.red)),
              ElevatedButton(
                onPressed: _isLoading ? null : () async {
                  setState(() => _isLoading = true);
                  final success = await firebase.linkAccounts(widget.profile.uid, _codeController.text);
                  if (!success) {
                    setState(() {
                      _status = 'Invalid code. Try again.';
                      _isLoading = false;
                    });
                  }
                },
                child: const Text('Pair Accounts'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
