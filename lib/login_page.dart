import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:provider/provider.dart';
import 'splash.dart';
import 'theme_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final userController = TextEditingController();
  final passController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool isLoading = false;
  bool _obscurePassword = true;
  String? androidId;

  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _initAnim();
    initLogin();
  }

  void _initAnim() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  Future<void> initLogin() async {
  androidId = await getAndroidId();

  final prefs = await SharedPreferences.getInstance();
  final savedUser = prefs.getString("username");
  final savedPass = prefs.getString("password");
  final savedKey = prefs.getString("key");

  if (savedUser != null && savedPass != null && savedKey != null) {
    final uri = Uri.parse(
        "https://app.atlas-by-erlan.com/myInfo?username=$savedUser&password=$savedPass&androidId=$androidId&key=$savedKey");
    try {
      final res = await http.get(uri);
      final data = jsonDecode(res.body);
      if (data['valid'] == true && mounted) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SplashScreen(
              username: savedUser,
              password: savedPass,
              role: data['role'],
              sessionKey: data['key'],
              expiredDate: data['expiredDate'],
              listBug: (data['listBug'] as List? ?? [])
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList(),
              news: (data['news'] as List? ?? [])
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList(),
            ),
          ),
        );
      }
    } catch (_) {}
  }
}

Future<String> getAndroidId() async {
  final deviceInfo = DeviceInfoPlugin();
  final android = await deviceInfo.androidInfo;
  return android.id ?? "unknown_device";
}

Future<void> login() async {
  if (!_formKey.currentState!.validate()) return;

  final username = userController.text.trim();
  final password = passController.text.trim();

  setState(() => isLoading = true);

  try {
    final validate = await http.post(
      Uri.parse("https://app.atlas-by-erlan.com/validate"),
      body: {
        "username": username,
        "password": password,
        "androidId": androidId ?? "unknown_device",
      },
    );

    final validData = jsonDecode(validate.body);

    if (validData['expired'] == true) {
      if (mounted) {
        _showPopup(
          title: "⏳ Akses Habis",
          message: "Masa akses Anda telah berakhir. Silakan perpanjang.",
          showContact: true,
        );
      }
    } else if (validData['valid'] != true) {
      final String errorMsg = (validData['message'] ?? "").toLowerCase();
      if (errorMsg.contains("perangkat") ||
          errorMsg.contains("device") ||
          errorMsg.contains("another")) {
        if (mounted) {
          _showPopup(
            title: "⚠️ Sesi Aktif",
            message: "Akun ini sedang login di perangkat lain. Logout terlebih dahulu.",
          );
        }
      } else {
        if (mounted) {
          _showPopup(
            title: "❌ Login Gagal",
            message: "Username atau password salah.",
          );
        }
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      prefs.setString("username", username);
      prefs.setString("password", password);
      prefs.setString("key", validData['key']);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SplashScreen(
              username: username,
              password: password,
              role: validData['role'],
              sessionKey: validData['key'],
              expiredDate: validData['expiredDate'],
              listBug: (validData['listBug'] as List? ?? [])
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList(),
              // listDoos: (validData['listDDoS'] as List? ?? [])
              //     .map((e) => Map<String, dynamic>.from(e as Map))
              //     .toList(),  // <-- HAPUS BAGIAN INI
              news: (validData['news'] as List? ?? [])
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList(),
            ),
          ),
        );
      }
    }
  } catch (e) {
    if (mounted) {
      _showPopup(
        title: "⚠️ Koneksi Error",
        message: "Gagal terhubung ke server. Periksa internet Anda.",
      );
    }
  }

  if (mounted) {
    setState(() => isLoading = false);
  }
}

  void _showPopup({
    required String title,
    required String message,
    bool showContact = false,
  }) {
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
                    title.contains("Gagal") || title.contains("Habis") || title.contains("Sesi")
                        ? Icons.warning_rounded
                        : Icons.info_outline,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: TextStyle(
                    color: theme.textPrimaryColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.textSecondaryColor, fontSize: 14),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (showContact)
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            await launchUrl(Uri.parse("https://t.me/@ErlanMods"),
                                mode: LaunchMode.externalApplication);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.blue.withOpacity(0.3)),
                            ),
                            child: const Center(
                              child: Text(
                                "HUBUNGI ADMIN",
                                style: TextStyle(
                                  color: Colors.blueAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (showContact) const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
                              "TUTUP",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    userController.dispose();
    passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      backgroundColor: theme.backgroundColor,
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
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo dengan animasi scale
                        TweenAnimationBuilder(
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
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/logo.jpg',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Icon(Icons.person, size: 50, color: theme.textPrimaryColor),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Welcome Text
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [theme.primaryColor, theme.accentColor],
                          ).createShader(bounds),
                          child: Text(
                            "Welcome Back",
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: theme.textPrimaryColor,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Masuk ke akun Anda",
                          style: TextStyle(
                            color: theme.textSecondaryColor,
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Form
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _buildInput(userController, "Username", Icons.person_outline_rounded, false, theme),
                              const SizedBox(height: 20),
                              _buildInput(passController, "Password", Icons.lock_outline_rounded, true, theme),
                              const SizedBox(height: 40),
                              _buildButton(theme),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Footer
                        Container(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 40,
                                height: 1,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "ATLAS SECURE LOGIN",
                                style: TextStyle(
                                  color: theme.textSecondaryColor.withOpacity(0.5),
                                  fontSize: 10,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 40,
                                height: 1,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String label, IconData icon,
      bool isPassword, ThemeProvider theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.glassSecondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.textPrimaryColor.withOpacity(0.1)),
      ),
      child: TextFormField(
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
        validator: (value) {
          if (value == null || value.isEmpty) return "$label tidak boleh kosong";
          return null;
        },
      ),
    );
  }

  Widget _buildButton(ThemeProvider theme) {
    return TweenAnimationBuilder(
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
          onTap: isLoading ? null : login,
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
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 12),
                        const Text(
                          "SIGN IN",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
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