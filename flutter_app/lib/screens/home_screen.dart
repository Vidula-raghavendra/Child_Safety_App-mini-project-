import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../widgets/sos_button.dart';
import 'report_screen.dart';
import 'status_screen.dart';

class HomeScreen extends StatefulWidget {
  final String role;
  const HomeScreen({super.key, required this.role});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hello, ${widget.role == 'child' ? 'Alex' : 'Parent'}', 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const Text('You are currently safe', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
            // SOS Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Column(
                children: [
                  const Text('Emergency Help', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  const SOSButton(),
                  const SizedBox(height: 16),
                  const Text('Press for 3 seconds to alert', style: TextStyle(color: Colors.red, fontSize: 12)),
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
                    icon: LucideIcons.mapPin,
                    title: 'Location',
                    subtitle: 'Share live path',
                    color: Colors.emerald,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StatusScreen())),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Row(
              mainAxisAlignment: MainAxisAlignment.between,
              children: [
                Text('Recent Activity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text('See all', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 2,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(LucideIcons.history, color: Colors.grey),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Location shared', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('2 hours ago', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(LucideIcons.chevronRight, color: Colors.grey, size: 16),
                  ],
                ),
              ),
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
          BottomNavigationBarItem(icon: Icon(LucideIcons.history), label: 'History'),
        ],
      ),
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
