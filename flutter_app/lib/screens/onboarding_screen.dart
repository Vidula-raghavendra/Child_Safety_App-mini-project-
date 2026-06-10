import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import 'login_screen.dart';

// Design tokens
const _kBg = Color(0xFFFAF9F7);
const _kSurface = Color(0xFFFFFFFF);
const _kAccent = Color(0xFFC9A96E);
const _kAccentDim = Color(0xFFE8D5B0);
const _kText = Color(0xFF0F0E0B);
const _kTextMid = Color(0xFF6B6560);
const _kTextDim = Color(0xFFB0A9A0);
const _kLine = Color(0xFFEAE6E0);

TextStyle _display(double size) => GoogleFonts.dmSerifDisplay(
      fontSize: size,
      color: _kText,
      height: 1.15,
      letterSpacing: -0.5,
    );

TextStyle _body(double size, {Color? color, FontWeight weight = FontWeight.w400}) =>
    GoogleFonts.inter(
      fontSize: size,
      color: color ?? _kTextMid,
      fontWeight: weight,
      height: 1.55,
    );

// ── Subtle animated gradient orb (single, large, slow) ───────────────────────

class _AmbientGlow extends StatefulWidget {
  const _AmbientGlow();
  @override
  State<_AmbientGlow> createState() => _AmbientGlowState();
}

class _AmbientGlowState extends State<_AmbientGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        return CustomPaint(painter: _GlowPainter(t));
      },
    );
  }
}

class _GlowPainter extends CustomPainter {
  final double t;
  _GlowPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _kBg);

    // Single soft glow in top-right area, shifts slowly
    final cx = size.width * (0.7 + 0.1 * sin(t * pi));
    final cy = size.height * (0.2 + 0.08 * cos(t * pi));
    final r = size.width * 0.65;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFC9A96E).withValues(alpha: 0.07),
          const Color(0xFFC9A96E).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r, paint);
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.t != t;
}

// ── Thin horizontal rule ──────────────────────────────────────────────────────

class _Rule extends StatelessWidget {
  const _Rule();
  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        color: _kLine,
      );
}

// ── Progress dots ─────────────────────────────────────────────────────────────

class _ProgressDots extends StatelessWidget {
  final int total;
  final int current;
  const _ProgressDots({required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          width: active ? 24 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: active ? _kAccent : _kTextDim,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// ── Clean text field ──────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscure;
  final Widget? suffix;
  final TextCapitalization capitalization;
  final TextInputType? keyboardType;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.obscure = false,
    this.suffix,
    this.capitalization = TextCapitalization.none,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _body(11, color: _kTextDim, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          textCapitalization: capitalization,
          keyboardType: keyboardType,
          style: _body(15, color: _kText, weight: FontWeight.w400),
          cursorColor: _kAccent,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: _body(15, color: _kTextDim),
            suffixIcon: suffix,
            filled: true,
            fillColor: _kSurface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kLine),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kLine),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kAccent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Primary CTA button ────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kAccent,
          foregroundColor: const Color(0xFF1A1410),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          disabledBackgroundColor: _kAccentDim,
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF1A1410)),
              )
            : Text(label,
                style: _body(15, color: const Color(0xFF1A1410),
                    weight: FontWeight.w600)),
      ),
    );
  }
}

// ── Ghost back button ─────────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _BackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_back, size: 16, color: _kTextDim),
          const SizedBox(width: 6),
          Text('Back', style: _body(13, color: _kTextDim)),
        ],
      ),
    );
  }
}

// ── Main onboarding screen ────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  String _selectedRole = 'child';
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  final _ageController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeCtrl.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _ageController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_currentPage < 5) {
      _fadeCtrl.reset();
      _pageController.nextPage(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOutCubic);
      _fadeCtrl.forward();
    }
  }

  void _goPrev() {
    if (_currentPage > 0) {
      _fadeCtrl.reset();
      _pageController.previousPage(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOutCubic);
      _fadeCtrl.forward();
    }
  }

  Future<void> _finishOnboarding() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await supabase.functions.invoke('create-user', body: {
        'username': _usernameController.text.trim(),
        'password': _passwordController.text,
        'full_name': _nameController.text.trim(),
        'role': _selectedRole,
        'age': _ageController.text.trim().isEmpty
            ? null
            : _ageController.text.trim(),
        'emergency_contact_name':
            _emergencyNameController.text.trim().isEmpty
                ? null
                : _emergencyNameController.text.trim(),
        'emergency_contact_phone':
            _emergencyPhoneController.text.trim().isEmpty
                ? null
                : _emergencyPhoneController.text.trim(),
      });
      if (response.data?['error'] != null) {
        setState(() {
          _errorMessage = response.data['error'];
          _isLoading = false;
        });
        return;
      }
      final fakeEmail =
          '${_usernameController.text.trim().toLowerCase().replaceAll(' ', '_')}@safenest.app';
      await supabase.auth
          .signInWithPassword(email: fakeEmail, password: _passwordController.text);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_done', true);
    } catch (e) {
      final msg = e.toString();
      final m = RegExp(r'\{error:\s*([^}]+)\}').firstMatch(msg);
      setState(() {
        _errorMessage = m != null
            ? m.group(1)!.trim()
            : 'Something went wrong. Try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          const Positioned.fill(child: _AmbientGlow()),
          SafeArea(
            child: Column(
              children: [
                // Top bar: logo + step indicator
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                  child: Row(
                    children: [
                      Text('SafeNest',
                          style: _body(14,
                              color: _kAccent, weight: FontWeight.w600)),
                      const Spacer(),
                      if (_currentPage > 0)
                        _ProgressDots(total: 5, current: _currentPage - 1),
                    ],
                  ),
                ),
                const _Rule(),
                Expanded(
                  child: FadeTransition(
                    opacity: _fade,
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (i) =>
                          setState(() => _currentPage = i),
                      children: [
                        _Step1Welcome(
                          onGetStarted: _goNext,
                          onLogin: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LoginScreen()),
                          ),
                        ),
                        _Step2Role(
                          selected: _selectedRole,
                          onSelect: (r) =>
                              setState(() => _selectedRole = r),
                          onNext: _goNext,
                          onBack: _goPrev,
                        ),
                        _Step3Account(
                          nameController: _nameController,
                          usernameController: _usernameController,
                          passwordController: _passwordController,
                          obscurePassword: _obscurePassword,
                          onToggleObscure: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                          onNext: () {
                            if (_nameController.text.trim().isEmpty ||
                                _usernameController.text.trim().length < 3 ||
                                _passwordController.text.length < 8) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Please fill all fields correctly',
                                    style: _body(13, color: _kText),
                                  ),
                                  backgroundColor: const Color(0xFF2A1A1A),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                              return;
                            }
                            _goNext();
                          },
                          onBack: _goPrev,
                        ),
                        _Step4Info(
                          role: _selectedRole,
                          ageController: _ageController,
                          emergencyNameController: _emergencyNameController,
                          emergencyPhoneController: _emergencyPhoneController,
                          onNext: _goNext,
                          onBack: _goPrev,
                        ),
                        _Step5Permissions(
                          onNext: _goNext,
                          onSkip: _goNext,
                          onBack: _goPrev,
                        ),
                        _Step6AllSet(
                          name: _nameController.text.isEmpty
                              ? 'there'
                              : _nameController.text
                                  .trim()
                                  .split(' ')
                                  .first,
                          role: _selectedRole,
                          isLoading: _isLoading,
                          errorMessage: _errorMessage,
                          onFinish: _finishOnboarding,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 1: Welcome ───────────────────────────────────────────────────────────

class _Step1Welcome extends StatefulWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onLogin;
  const _Step1Welcome({required this.onGetStarted, required this.onLogin});

  @override
  State<_Step1Welcome> createState() => _Step1WelcomeState();
}

class _Step1WelcomeState extends State<_Step1Welcome>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat(reverse: true);
    _anim =
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 2),

          // Shield mark
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) {
              return Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _kAccent.withValues(alpha: 0.3 + 0.2 * _anim.value),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.shield_outlined,
                    color: _kAccent, size: 32),
              );
            },
          ),

          const SizedBox(height: 32),
          Text('Keep your\nfamily safe.', style: _display(44)),
          const SizedBox(height: 16),
          Text(
            'Real-time location. Automatic zone alerts.\nSilent SOS when words are impossible.',
            style: _body(15, color: _kTextMid),
          ),

          const Spacer(flex: 3),

          // Feature list
          ..._features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                          color: _kAccent, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 14),
                    Text(f, style: _body(14, color: _kTextMid)),
                  ],
                ),
              )),

          const SizedBox(height: 40),
          _PrimaryButton(
              label: 'Create an account', onPressed: widget.onGetStarted),
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              onTap: widget.onLogin,
              child: Text(
                'Sign in to existing account',
                style: _body(14, color: _kTextMid),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _features = [
  'Live location shared with family',
  'Safe zone enter and exit alerts',
  'One-tap and shake-to-SOS',
  'Works offline with SMS fallback',
];

// ── Step 2: Role ──────────────────────────────────────────────────────────────

class _Step2Role extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _Step2Role({
    required this.selected,
    required this.onSelect,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Who are you?', style: _display(36)),
          const SizedBox(height: 10),
          Text('This shapes your entire experience.',
              style: _body(15, color: _kTextMid)),
          const SizedBox(height: 40),
          _RoleCard(
            title: 'Parent',
            description: 'Monitor location, set safe zones, receive SOS alerts',
            icon: Icons.shield_outlined,
            selected: selected == 'parent',
            onTap: () => onSelect('parent'),
          ),
          const SizedBox(height: 14),
          _RoleCard(
            title: 'Child',
            description:
                'Share location, send SOS alerts, call emergency contacts',
            icon: Icons.person_outline_rounded,
            selected: selected == 'child',
            onTap: () => onSelect('child'),
          ),
          const Spacer(),
          _BottomNav(onBack: onBack, onNext: onNext),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: selected ? _kSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _kAccent : _kLine,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? _kAccent.withValues(alpha: 0.12)
                    : _kLine.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  color: selected ? _kAccent : _kTextDim, size: 22),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: _body(16,
                          color: selected ? _kText : _kTextMid,
                          weight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(description,
                      style: _body(12, color: _kTextDim)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? _kAccent : _kTextDim,
                  width: selected ? 5 : 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 3: Account ───────────────────────────────────────────────────────────

class _Step3Account extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _Step3Account({
    required this.nameController,
    required this.usernameController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create account', style: _display(36)),
          const SizedBox(height: 10),
          Text('Your data is private and never sold.',
              style: _body(15, color: _kTextMid)),
          const SizedBox(height: 36),
          _Field(
              controller: nameController,
              label: 'FULL NAME',
              hint: 'Enter your full name',
              capitalization: TextCapitalization.words),
          const SizedBox(height: 20),
          _Field(
              controller: usernameController,
              label: 'USERNAME',
              hint: 'Choose a username'),
          const SizedBox(height: 20),
          _Field(
            controller: passwordController,
            label: 'PASSWORD',
            hint: 'Minimum 8 characters',
            obscure: obscurePassword,
            suffix: IconButton(
              icon: Icon(
                  obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _kTextDim,
                  size: 18),
              onPressed: onToggleObscure,
            ),
          ),
          const SizedBox(height: 36),
          _BottomNav(onBack: onBack, onNext: onNext),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'By continuing you agree to our Terms of Service',
              style: _body(11, color: _kTextDim),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 4: Info ──────────────────────────────────────────────────────────────

class _Step4Info extends StatelessWidget {
  final String role;
  final TextEditingController ageController;
  final TextEditingController emergencyNameController;
  final TextEditingController emergencyPhoneController;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _Step4Info({
    required this.role,
    required this.ageController,
    required this.emergencyNameController,
    required this.emergencyPhoneController,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isChild = role == 'child';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('A few details', style: _display(36)),
          const SizedBox(height: 10),
          Text(
            isChild
                ? 'These details help in an emergency.'
                : 'Your contact number receives SOS alerts.',
            style: _body(15, color: _kTextMid),
          ),
          const SizedBox(height: 36),
          if (isChild) ...[
            _Field(
                controller: ageController,
                label: 'YOUR AGE',
                hint: 'Optional',
                keyboardType: TextInputType.number),
            const SizedBox(height: 20),
            _Field(
                controller: emergencyNameController,
                label: 'EMERGENCY CONTACT NAME',
                hint: 'e.g. Mum, Guardian',
                capitalization: TextCapitalization.words),
            const SizedBox(height: 20),
            _Field(
                controller: emergencyPhoneController,
                label: 'EMERGENCY PHONE',
                hint: '+91 98765 43210',
                keyboardType: TextInputType.phone),
          ] else ...[
            _Field(
                controller: emergencyPhoneController,
                label: 'YOUR PHONE NUMBER',
                hint: '+91 98765 43210',
                keyboardType: TextInputType.phone),
          ],
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: _kLine),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 16, color: _kTextDim),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isChild
                        ? 'Emergency contacts are used to place calls when you need help fast. This info is only visible to you and your linked family.'
                        : 'This number will receive SMS SOS alerts from linked children if internet is unavailable.',
                    style: _body(12, color: _kTextDim),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          _BottomNav(onBack: onBack, onNext: onNext),
        ],
      ),
    );
  }
}

// ── Step 5: Permissions ───────────────────────────────────────────────────────

class _Step5Permissions extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback onBack;
  const _Step5Permissions(
      {required this.onNext, required this.onSkip, required this.onBack});

  @override
  State<_Step5Permissions> createState() => _Step5PermissionsState();
}

class _Step5PermissionsState extends State<_Step5Permissions>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 12))
          ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    await Permission.location.request();
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Animated location icon
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final angle = _ctrl.value * 2 * pi;
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Rotating ring
                  Transform.rotate(
                    angle: angle,
                    child: CustomPaint(
                      size: const Size(90, 90),
                      painter: _DashedRing(),
                    ),
                  ),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: _kSurface,
                      shape: BoxShape.circle,
                      border: Border.all(color: _kLine),
                    ),
                    child: const Icon(Icons.location_on_outlined,
                        color: _kAccent, size: 28),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 36),
          Text('Location access', style: _display(36)),
          const SizedBox(height: 12),
          Text(
            'SafeNest uses your GPS to detect when you enter or leave safe zones and to share location with family.',
            style: _body(15, color: _kTextMid),
          ),
          const SizedBox(height: 32),
          ..._permItems.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 4, color: _kAccent),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item[0],
                            style: _body(14,
                                color: _kText, weight: FontWeight.w500)),
                        Text(item[1],
                            style: _body(12, color: _kTextDim)),
                      ],
                    ),
                  ],
                ),
              )),
          const Spacer(),
          _PrimaryButton(
              label: 'Allow location access', onPressed: _request),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _BackButton(onPressed: widget.onBack),
              GestureDetector(
                onTap: widget.onSkip,
                child: Text('Skip for now',
                    style: _body(13, color: _kTextDim)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const _permItems = [
  ['Precise GPS', 'Accurate safe zone detection'],
  ['Background access', 'Monitoring continues when app is closed'],
  ['Private by design', 'Location only shared with your linked family'],
];

class _DashedRing extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _kAccent.withValues(alpha: 0.25)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const dashCount = 24;
    const dashAngle = 2 * pi / dashCount;
    final r = size.width / 2;
    final center = Offset(r, r);
    for (int i = 0; i < dashCount; i += 2) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        i * dashAngle,
        dashAngle * 0.5,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Step 6: All set ───────────────────────────────────────────────────────────

class _Step6AllSet extends StatefulWidget {
  final String name;
  final String role;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onFinish;

  const _Step6AllSet({
    required this.name,
    required this.role,
    required this.isLoading,
    required this.errorMessage,
    required this.onFinish,
  });

  @override
  State<_Step6AllSet> createState() => _Step6AllSetState();
}

class _Step6AllSetState extends State<_Step6AllSet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    Future.delayed(
        const Duration(milliseconds: 150), () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isParent = widget.role == 'parent';
    final items = isParent ? _parentFeatures : _childFeatures;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScaleTransition(
            scale: _scale,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _kAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _kAccent.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.check_rounded,
                  color: _kAccent, size: 30),
            ),
          ),
          const SizedBox(height: 28),
          Text('Ready, ${widget.name}.', style: _display(40)),
          const SizedBox(height: 12),
          Text(
            isParent
                ? 'Link your children and start monitoring from your dashboard.'
                : 'Ask a parent or guardian to link your account to get started.',
            style: _body(15, color: _kTextMid),
          ),
          const SizedBox(height: 40),
          const _Rule(),
          const SizedBox(height: 28),
          Text('What you get', style: _body(11, color: _kTextDim, weight: FontWeight.w600)),
          const SizedBox(height: 20),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(item[0] as IconData,
                        size: 16, color: _kAccent),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item[1] as String,
                              style: _body(14,
                                  color: _kText,
                                  weight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text(item[2] as String,
                              style: _body(12, color: _kTextDim)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
          const Spacer(),

          if (widget.errorMessage != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF5A1A1A)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded,
                    color: Color(0xFFEF4444), size: 16),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(widget.errorMessage!,
                        style: _body(12,
                            color: const Color(0xFFEF4444)))),
              ]),
            ),
          ],

          _PrimaryButton(
            label: 'Start using SafeNest',
            onPressed: widget.onFinish,
            loading: widget.isLoading,
          ),
        ],
      ),
    );
  }
}

const _parentFeatures = [
  [Icons.map_outlined, 'Live location map', 'See your child\'s position updated every 30 seconds'],
  [Icons.location_on_outlined, 'Safe zone alerts', 'Notified when they enter or leave zones'],
  [Icons.notifications_outlined, 'Instant SOS', 'Full-screen alert with GPS coordinates'],
];

const _childFeatures = [
  [Icons.sos_outlined, 'Hold-to-SOS', 'Send emergency alert with one touch'],
  [Icons.vibration_outlined, 'Shake SOS', 'Shake phone to alert silently'],
  [Icons.phone_outlined, 'Emergency contacts', 'One-tap calls to family or guardian'],
];

// ── Bottom navigation row ─────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _BottomNav({required this.onBack, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _BackButton(onPressed: onBack),
        const Spacer(),
        SizedBox(
          width: 140,
          height: 48,
          child: ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccent,
              foregroundColor: const Color(0xFF1A1410),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Continue', style: _body(14, color: const Color(0xFF1A1410), weight: FontWeight.w600)),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward, size: 14, color: Color(0xFF1A1410)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
