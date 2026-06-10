import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

// Design tokens (duplicated here to keep screens self-contained)
const _kBg = Color(0xFFFAF9F7);
const _kSurface = Color(0xFFFFFFFF);
const _kAccent = Color(0xFFC9A96E);
const _kText = Color(0xFF0F0E0B);
const _kTextMid = Color(0xFF6B6560);
const _kTextDim = Color(0xFFB0A9A0);
const _kLine = Color(0xFFEAE6E0);

TextStyle _display(double size) => GoogleFonts.dmSerifDisplay(
      fontSize: size,
      color: _kText,
      height: 1.2,
      letterSpacing: -0.5,
    );

TextStyle _body(double size,
        {Color? color, FontWeight weight = FontWeight.w400}) =>
    GoogleFonts.inter(
      fontSize: size,
      color: color ?? _kTextMid,
      fontWeight: weight,
      height: 1.5,
    );

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;
  String _selectedRole = 'child';
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String _toFakeEmail(String username) =>
      '${username.trim().toLowerCase().replaceAll(' ', '_')}@safenest.app';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final fakeEmail = _toFakeEmail(_usernameController.text);

    try {
      if (_isSignUp) {
        final response = await supabase.functions.invoke('create-user', body: {
          'username': _usernameController.text.trim(),
          'password': _passwordController.text,
          'full_name': _nameController.text.trim(),
          'role': _selectedRole,
        });
        if (response.data?['error'] != null) {
          setState(() => _errorMessage = response.data['error']);
          return;
        }
        await supabase.auth.signInWithPassword(
            email: fakeEmail, password: _passwordController.text);
      } else {
        await supabase.auth.signInWithPassword(
            email: fakeEmail, password: _passwordController.text);
      }
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (_) => false,
        );
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mark
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: _kAccent.withValues(alpha: 0.4), width: 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.shield_outlined,
                      color: _kAccent, size: 22),
                ),
                const SizedBox(height: 36),

                Text(
                  _isSignUp ? 'Create account' : 'Welcome back.',
                  style: _display(38),
                ),
                const SizedBox(height: 10),
                Text(
                  _isSignUp
                      ? 'Join SafeNest to protect your family.'
                      : 'Sign in to your SafeNest account.',
                  style: _body(15, color: _kTextMid),
                ),

                const SizedBox(height: 44),

                if (_isSignUp) ...[
                  _FormLabel('FULL NAME'),
                  _TextField(
                    controller: _nameController,
                    hint: 'Enter your full name',
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 22),
                ],

                _FormLabel('USERNAME'),
                _TextField(
                  controller: _usernameController,
                  hint: 'Your username',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (v.trim().length < 3) return 'At least 3 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 22),

                _FormLabel('PASSWORD'),
                _TextField(
                  controller: _passwordController,
                  hint: _isSignUp ? 'Minimum 8 characters' : 'Enter password',
                  obscureText: _obscurePassword,
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                      color: _kTextDim,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (_isSignUp && v.length < 8) return 'Minimum 8 characters';
                    return null;
                  },
                ),

                if (_isSignUp) ...[
                  const SizedBox(height: 28),
                  _FormLabel('ACCOUNT TYPE'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _RoleToggle(
                          label: 'Child',
                          icon: Icons.person_outline_rounded,
                          selected: _selectedRole == 'child',
                          onTap: () =>
                              setState(() => _selectedRole = 'child'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RoleToggle(
                          label: 'Parent',
                          icon: Icons.shield_outlined,
                          selected: _selectedRole == 'parent',
                          onTap: () =>
                              setState(() => _selectedRole = 'parent'),
                        ),
                      ),
                    ],
                  ),
                ],

                if (_errorMessage != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF5A1A1A)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Color(0xFFEF4444), size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_errorMessage!,
                              style: _body(12,
                                  color: const Color(0xFFEF4444))),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kAccent,
                      foregroundColor: const Color(0xFF1A1410),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      disabledBackgroundColor: const Color(0xFF8B6E44),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF1A1410)),
                          )
                        : Text(
                            _isSignUp ? 'Create account' : 'Sign in',
                            style: _body(15,
                                color: const Color(0xFF1A1410),
                                weight: FontWeight.w600),
                          ),
                  ),
                ),

                const SizedBox(height: 24),
                Center(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _isSignUp = !_isSignUp;
                      _errorMessage = null;
                    }),
                    child: Text(
                      _isSignUp
                          ? 'Already have an account? Sign in'
                          : "Don't have an account? Sign up",
                      style: _body(14, color: _kTextMid),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FormLabel extends StatelessWidget {
  final String text;
  const _FormLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: _body(10, color: _kTextDim, weight: FontWeight.w600)),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final Widget? suffix;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;

  const _TextField({
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.suffix,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
      style: _body(15, color: _kText),
      cursorColor: _kAccent,
      validator: validator,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: Color(0xFF5A1A1A), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        errorStyle: _body(11, color: const Color(0xFFEF4444)),
      ),
    );
  }
}

class _RoleToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleToggle({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? _kSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _kAccent : _kLine,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 20,
                color: selected ? _kAccent : _kTextDim),
            const SizedBox(height: 6),
            Text(
              label,
              style: _body(13,
                  color: selected ? _kText : _kTextDim,
                  weight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
