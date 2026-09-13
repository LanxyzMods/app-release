// change_password_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class ChangePasswordPage extends StatefulWidget {
  final String username;
  final String sessionKey;

  const ChangePasswordPage({
    super.key,
    required this.username,
    required this.sessionKey,
  });

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final oldPassCtrl = TextEditingController();
  final newPassCtrl = TextEditingController();
  final confirmPassCtrl = TextEditingController();

  bool isLoading = false;
  bool _obscurePassword = true;

  Future<void> _changePassword() async {
    final oldPass = oldPassCtrl.text.trim();
    final newPass = newPassCtrl.text.trim();
    final confirmPass = confirmPassCtrl.text.trim();

    if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      _showMessage("Semua field harus diisi.");
      return;
    }

    if (newPass != confirmPass) {
      _showMessage("Password baru tidak cocok dengan konfirmasi.");
      return;
    }

    setState(() => isLoading = true);

    try {
      final res = await http.post(
        Uri.parse("https://app.atlas-by-erlan.com/changepass"),
        body: {
          "username": widget.username,
          "oldPass": oldPass,
          "newPass": newPass,
          "sessionKey": widget.sessionKey,
        },
      );

      final data = jsonDecode(res.body);

      if (data['success'] == true) {
        _showMessage("Password berhasil diubah!", isSuccess: true);
        oldPassCtrl.clear();
        newPassCtrl.clear();
        confirmPassCtrl.clear();
      } else {
        _showMessage(data['message'] ?? "Gagal mengubah password");
      }
    } catch (e) {
      _showMessage("Koneksi error: $e");
    }

    setState(() => isLoading = false);
  }

  void _showMessage(String msg, {bool isSuccess = false}) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: TweenAnimationBuilder(
          duration: const Duration(milliseconds: 300),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, double scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.backgroundColor, theme.backgroundColor.withOpacity(0.95)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: theme.primaryColor.withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.primaryColor.withOpacity(0.4),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: Icon(
                    isSuccess ? Icons.check_circle : Icons.warning_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isSuccess ? "Sukses" : "Peringatan",
                  style: TextStyle(
                    color: theme.textPrimaryColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  msg,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.textSecondaryColor, fontSize: 14),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: theme.primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          "OK",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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

  Widget _buildInput(TextEditingController controller, String label, IconData icon, [bool isPassword = false]) {
    final theme = Provider.of<ThemeProvider>(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.glassSecondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.textPrimaryColor.withOpacity(0.1)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        style: TextStyle(color: theme.textPrimaryColor, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: theme.textSecondaryColor),
          prefixIcon: Icon(icon, color: theme.primaryColor, size: 22),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: theme.textSecondaryColor,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: theme.primaryColor.withOpacity(0.3),
                blurRadius: 10,
              ),
            ],
          ),
          child: const Text(
            "CHANGE PASSWORD",
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.glassSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.textPrimaryColor.withOpacity(0.08)),
            ),
            child: Icon(Icons.arrow_back_ios_new, color: theme.primaryColor, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [theme.primaryColor.withOpacity(0.15), theme.backgroundColor, theme.backgroundColor],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: CustomPaint(
          painter: _GridPainter(accentColor: theme.primaryColor),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // Header Icon
                Center(
                  child: TweenAnimationBuilder(
                    duration: const Duration(milliseconds: 600),
                    tween: Tween<double>(begin: 0, end: 1),
                    builder: (context, double value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.scale(scale: value, child: child),
                      );
                    },
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                        boxShadow: [
                          BoxShadow(
                            color: theme.primaryColor.withOpacity(0.5),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.lock_reset_rounded, color: Colors.white, size: 50),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Center(
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(colors: [theme.primaryColor, theme.accentColor]).createShader(bounds),
                    child: const Text(
                      "SECURITY UPDATE",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    "Masukkan password lama dan baru",
                    style: TextStyle(
                      color: theme.textSecondaryColor,
                      fontSize: 13,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Input Fields
                _buildInput(oldPassCtrl, "Old Password", Icons.lock_outline_rounded, true),
                _buildInput(newPassCtrl, "New Password", Icons.vpn_key_rounded, true),
                _buildInput(confirmPassCtrl, "Confirm Password", Icons.enhanced_encryption_rounded, true),

                const SizedBox(height: 30),

                // Submit Button
                TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 500),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: GestureDetector(
                      onTap: isLoading ? null : _changePassword,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: theme.primaryColor.withOpacity(0.4),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.lock_reset_rounded, color: Colors.white, size: 20),
                                    SizedBox(width: 12),
                                    Text(
                                      "UPDATE PASSWORD",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
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

// Custom Grid Painter for background (DIUBAH AGAR PAKAI WARNA DARI THEME)
class _GridPainter extends CustomPainter {
  final Color accentColor;
  
  _GridPainter({required this.accentColor});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const gridSize = 30.0;

    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final accentPaint = Paint()
      ..color = accentColor.withOpacity(0.08)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (double x = 0; x <= size.width; x += gridSize * 5) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), accentPaint);
    }

    for (double y = 0; y <= size.height; y += gridSize * 5) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), accentPaint);
    }

    final dotPaint = Paint()
      ..color = accentColor.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    for (double x = 0; x <= size.width; x += gridSize) {
      for (double y = 0; y <= size.height; y += gridSize) {
        canvas.drawCircle(Offset(x, y), 1.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor;
  }
}