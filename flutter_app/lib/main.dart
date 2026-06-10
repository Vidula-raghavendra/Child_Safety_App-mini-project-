import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'services/notification_service.dart';
import 'screens/home_screen.dart';
import 'screens/parent_dashboard.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  await Supabase.initialize(
    url: 'https://ncojeblquxsulfaclbhl.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5jb2plYmxxdXhzdWxmYWNsYmhsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU3MTIxMDksImV4cCI6MjA5MTI4ODEwOX0.7s09mLxUFBS22FLCQZXFk3bFGZTVyNwJt7HYnmVBtrk',
  );
  await NotificationService.instance.init();

  runApp(const SafeNestApp());
}

final supabase = Supabase.instance.client;

class SafeNestApp extends StatelessWidget {
  const SafeNestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeNest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFAF9F7),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFC9A96E),
          surface: Color(0xFFFFFFFF),
          onPrimary: Color(0xFF1A1410),
          onSurface: Color(0xFF0F0E0B),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFFFAF9F7),
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F0E0B),
          ),
          iconTheme: const IconThemeData(color: Color(0xFF6B6560)),
        ),
        dividerColor: const Color(0xFFEAE6E0),
        cardColor: const Color(0xFFFFFFFF),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFFFFFF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFEAE6E0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFEAE6E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFC9A96E), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          hintStyle: GoogleFonts.inter(fontSize: 15, color: const Color(0xFFB0A9A0)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC9A96E),
            foregroundColor: const Color(0xFF1A1410),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            minimumSize: const Size(double.infinity, 54),
            textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final session = snapshot.data!.session;
          if (session != null) {
            return FutureBuilder<Map<String, dynamic>?>(
              future: supabase
                  .from('users')
                  .select('role, full_name')
                  .eq('id', session.user.id)
                  .maybeSingle(),
              builder: (context, userSnap) {
                if (userSnap.connectionState == ConnectionState.waiting) {
                  return const _SplashScreen();
                }
                final role = userSnap.data?['role'] as String? ?? 'child';
                final name = userSnap.data?['full_name'] as String? ?? session.user.email ?? 'User';
                if (role == 'parent') {
                  return ParentDashboard(displayName: name);
                }
                return HomeScreen(role: role, displayName: name);
              },
            );
          }
        }

        // Not logged in — check onboarding flag
        return FutureBuilder<SharedPreferences>(
          future: SharedPreferences.getInstance(),
          builder: (context, prefsSnap) {
            if (prefsSnap.connectionState == ConnectionState.waiting) {
              return const _SplashScreen();
            }
            final prefs = prefsSnap.data;
            final done = prefs?.getBool('onboarding_done') ?? false;
            if (done) {
              return const LoginScreen();
            }
            return const OnboardingScreen();
          },
        );
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFFAF9F7),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined, size: 36, color: Color(0xFFC9A96E)),
            SizedBox(height: 20),
            Text('SafeNest',
                style: TextStyle(
                    color: Color(0xFF0F0E0B),
                    fontSize: 22,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 3)),
          ],
        ),
      ),
    );
  }
}
