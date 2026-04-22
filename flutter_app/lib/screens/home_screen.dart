import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../models/user_profile.dart';
import '../widgets/sos_button.dart';
import 'report_screen.dart';
import 'status_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final firebase = Provider.of<FirebaseService>(context);
    final user = firebase.currentUser;

    return StreamBuilder<UserProfile?>(
      stream: firebase.streamProfile(user?.uid ?? ''),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        
        if (profile == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hello, ${profile.displayName}', 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                Text(profile.role == 'parent' ? 'Monitoring active' : 'Live sharing enabled', 
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            actions: [
              IconButton(onPressed: () {}, icon: const Icon(LucideIcons.bell)),
              const SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (profile.role == 'child')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: const Column(
                      children: [
                        Text('Emergency Help', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        SizedBox(height: 24),
                        SOSButton(),
                        SizedBox(height: 16),
                        Text('Press for 3 seconds to alert parent', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ],
                    ),
                  ),
                if (profile.role == 'parent')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.indigo.shade100),
                    ),
                    child: Column(
                      children: [
                        const Text('Child Location Status', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Icon(LucideIcons.map, size: 48, color: Colors.indigo.shade400),
                        const SizedBox(height: 12),
                        const Text('Live Tracking Enabled', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                const SizedBox(height: 32),
                const Text('Quick Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: LucideIcons.alertTriangle,
                        title: 'Report',
                        subtitle: 'Unsafe situation',
                        color: Colors.indigo,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportScreen())),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _ActionCard(
                        icon: LucideIcons.shield,
                        title: 'Status',
                        subtitle: 'Safety Check',
                        color: Colors.emerald,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StatusScreen())),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (i) => setState(() => _selectedIndex = i),
            items: const [
              BottomNavigationBarItem(icon: Icon(LucideIcons.shield), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(LucideIcons.mapPin), label: 'Location'),
              BottomNavigationBarItem(icon: Icon(LucideIcons.history), label: 'Alerts'),
            ],
          ),
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color.withOpacity(0.8))),
            Text(subtitle, style: TextStyle(fontSize: 10, color: color.withOpacity(0.6))),
          ],
        ),
      ),
    );
  }
}
