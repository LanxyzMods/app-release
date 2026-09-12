// profile_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'change_password_page.dart';
import 'theme_provider.dart';

class ProfilePage extends StatefulWidget {
  final String username;
  final String password;
  final String role;
  final String expiredDate;
  final String sessionKey;

  const ProfilePage({
    super.key,
    required this.username,
    required this.password,
    required this.role,
    required this.expiredDate,
    required this.sessionKey,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('profile_image_${widget.username}');
    if (imagePath != null && imagePath.isNotEmpty) {
      setState(() {
        _profileImage = File(imagePath);
      });
    }
  }

  String _censorText(String text, {bool isPassword = false}) {
    if (text.isEmpty) return "N/A";
    if (isPassword) {
      return "••••••••";
    }
    if (text.length <= 2) return "${text.substring(0, 1)}••";
    return "${text.substring(0, 2)}${'•' * (text.length - 2)}";
  }

  Future<void> _showImageSourceDialog() async {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.backgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          border: Border.all(color: theme.textPrimaryColor.withOpacity(0.08)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.glassPrimary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.primaryColor.withOpacity(0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      "Pilih Sumber",
                      style: TextStyle(
                        color: theme.textPrimaryColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.camera_alt, color: theme.primaryColor, size: 20),
                ),
                title: Text("Kamera", style: TextStyle(color: theme.textPrimaryColor)),
                trailing: Icon(Icons.arrow_forward_ios, color: theme.textSecondaryColor, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.photo_library, color: theme.primaryColor, size: 20),
                ),
                title: Text("Galeri", style: TextStyle(color: theme.textPrimaryColor)),
                trailing: Icon(Icons.arrow_forward_ios, color: theme.textSecondaryColor, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_image_${widget.username}', imageFile.path);

        setState(() {
          _profileImage = imageFile;
        });
      }
    } catch (e) {
      print("Error picking image: $e");
    }
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
            "MY PROFILE",
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
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // --- AVATAR PROFILE dengan animasi ---
                TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 600),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.scale(scale: value, child: child),
                    );
                  },
                  child: Center(
                    child: GestureDetector(
                      onTap: _showImageSourceDialog,
                      child: Stack(
                        children: [
                          Container(
                            width: 130,
                            height: 130,
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
                              child: _profileImage != null
                                  ? Image.file(
                                      _profileImage!,
                                      fit: BoxFit.cover,
                                    )
                                  : Center(
                                      child: Icon(
                                        FontAwesomeIcons.userAstronaut,
                                        size: 55,
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                    ),
                            ),
                          ),
                          Positioned(
                            bottom: 5,
                            right: 5,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                                shape: BoxShape.circle,
                                border: Border.all(color: theme.backgroundColor, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.primaryColor.withOpacity(0.4),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Username & Role
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(colors: [theme.primaryColor, theme.accentColor]).createShader(bounds),
                  child: Text(
                    widget.username,
                    style: TextStyle(
                      color: theme.textPrimaryColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    widget.role.toUpperCase(),
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // --- INFO CARDS dalam bentuk list (1 kolom penuh) ---
                _buildInfoCard(
                  icon: Icons.person_outline_rounded,
                  label: "Username",
                  value: _censorText(widget.username),
                  delay: 0,
                  theme: theme,
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  icon: Icons.lock_outline_rounded,
                  label: "Password",
                  value: _censorText(widget.password, isPassword: true),
                  delay: 100,
                  theme: theme,
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  icon: Icons.verified_user_outlined,
                  label: "Role",
                  value: widget.role.toUpperCase(),
                  delay: 200,
                  theme: theme,
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  icon: Icons.calendar_today_outlined,
                  label: "Expired Date",
                  value: widget.expiredDate,
                  delay: 300,
                  theme: theme,
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  icon: Icons.vpn_key_rounded,
                  label: "Session Key",
                  value: "${widget.sessionKey.substring(0, 12)}...",
                  delay: 400,
                  theme: theme,
                ),

                const SizedBox(height: 30),

                // --- CHANGE PASSWORD BUTTON ---
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
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChangePasswordPage(
                              username: widget.username,
                              sessionKey: widget.sessionKey,
                            ),
                          ),
                        );
                      },
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
                        child: const Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock_reset_rounded, color: Colors.white, size: 22),
                              SizedBox(width: 12),
                              Text(
                                "CHANGE PASSWORD",
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

                const SizedBox(height: 30),

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
                        "ATLAS PROFILE",
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
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required int delay,
    required ThemeProvider theme,
  }) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 400 + delay),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double valueAnimation, child) {
        return Opacity(
          opacity: valueAnimation,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - valueAnimation)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.glassPrimary,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.textPrimaryColor.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: theme.primaryColor.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: theme.textSecondaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      color: theme.textPrimaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
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