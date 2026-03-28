import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'menu_page.dart';

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(25)
      ..strokeWidth = 1;

    const spacing = 20.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class LoginPage extends StatefulWidget {
  static const routeName = '/login';
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final _captchaC = TextEditingController();
  final Random _random = Random();
  String? _error;
  bool _obscurePassword = true;
  int _captchaA = 0;
  int _captchaB = 0;
  String _captchaOp = '+';
  int _captchaAnswer = 0;

  @override
  void initState() {
    super.initState();
    _generateCaptcha();
  }

  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    _captchaC.dispose();
    super.dispose();
  }

  void _generateCaptcha() {
    const ops = ['+', '-', 'x'];
    _captchaOp = ops[_random.nextInt(ops.length)];

    if (_captchaOp == '+') {
      _captchaA = _random.nextInt(9) + 1;
      _captchaB = _random.nextInt(9) + 1;
      _captchaAnswer = _captchaA + _captchaB;
      return;
    }

    if (_captchaOp == '-') {
      final first = _random.nextInt(15) + 5;
      final second = _random.nextInt(first) + 1;
      _captchaA = first;
      _captchaB = second;
      _captchaAnswer = _captchaA - _captchaB;
      return;
    }

    _captchaA = _random.nextInt(9) + 1;
    _captchaB = _random.nextInt(5) + 1;
    _captchaAnswer = _captchaA * _captchaB;
  }

  Future<void> _login() async {
    final captchaInput = int.tryParse(_captchaC.text.trim());
    if (captchaInput == null || captchaInput != _captchaAnswer) {
      setState(() {
        _error = 'Captcha salah, coba lagi.';
        _captchaC.clear();
        _generateCaptcha();
      });
      return;
    }

    final auth = context.read<AuthProvider>();
    setState(() => _error = null);
    final success = await auth.login(_emailC.text.trim(), _passC.text);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pushReplacementNamed(MenuPage.routeName);
    } else {
      setState(() {
        _error = auth.lastError ?? 'Email atau password salah';
        _captchaC.clear();
        _generateCaptcha();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1e3a8a), // dark blue
              Color(0xFF1e293b), // navy
              Color(0xFF0f172a), // black
            ],
          ),
        ),
        child: CustomPaint(
          painter: GridPainter(),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo SIGAPTEL
                  Image.asset(
                    'web/gambar/LogoSigaptel.png',
                    height: 120,
                    width: 120,
                  ),
                  const SizedBox(height: 16),
                  // Judul
                  const Text(
                    'Masuk SIGAPTEL',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Belum punya akun?',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Card Form Login
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Input Email
                          TextField(
                            controller: _emailC,                          style: const TextStyle(color: Colors.black),                            decoration: InputDecoration(
                              labelText: 'Email/Username',
                              prefixIcon: const Icon(Icons.email),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Input Password
                          TextField(
                            controller: _passC,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Captcha label
                          Row(
                            children: [
                              Container(
                                width: 3,
                                height: 14,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Color(0xFF3b82f6), Color(0xFF1e40af)],
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 7),
                              const Text(
                                'Verifikasi Captcha',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: const Text(
                                  'Anti-Bot',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF1d4ed8),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Captcha — modern minimalist
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Equation chip
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF1e40af), Color(0xFF3b82f6)],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$_captchaA  $_captchaOp  $_captchaB  =  ?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Answer field
                              Expanded(
                                child: TextField(
                                  controller: _captchaC,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Jawaban',
                                    hintStyle: const TextStyle(color: Color(0xFFADB5BD), fontWeight: FontWeight.normal),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFF3b82f6), width: 1.8),
                                    ),
                                    suffixIcon: Tooltip(
                                      message: 'Ganti soal',
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(10),
                                        onTap: () => setState(() {
                                          _captchaC.clear();
                                          _generateCaptcha();
                                        }),
                                        child: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF94A3B8)),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                          const SizedBox(height: 4),
                          // Lupa Password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                // TODO: Implement forgot password
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Fitur lupa password akan segera hadir')),
                                );
                              },
                              child: const Text('Lupa Password?'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Tombol Masuk
                          Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF3b82f6), Color(0xFF1d4ed8)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ElevatedButton(
                              onPressed: auth.isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: auth.isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Masuk',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}