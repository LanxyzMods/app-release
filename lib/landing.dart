// ignore_for_file: use_build_context_synchronously, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'login_page.dart';
import 'buy_account.dart';
import 'theme_provider.dart';

// ── Tema Dashboard (light blue / neubrutalism) ────────────────────────────────
const Color _lBg      = Color(0xFFDCEEFB);
const Color _lAccent  = Color(0xFF1565C0);
const Color _lBgCard  = Color(0xFFF0F7FF);
const Color _lBorder  = Color(0xFF42A5F5);
const Color _lText    = Colors.black87;
const Color _lTextSub = Colors.black54;
const String _lFont   = "Orbitron";

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> with TickerProviderStateMixin {
  // Entry animation
  late AnimationController _entryController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Loop animation (floating)
  late AnimationController _loopController;
  late Animation<double> _floatingAnimation;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );

    _loopController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _floatingAnimation = Tween<double>(begin: -10.0, end: 10.0).animate(
      CurvedAnimation(parent: _loopController, curve: Curves.easeInOut),
    );

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _loopController.dispose();
    super.dispose();
  }

  // ── Stagger Animation Helper ──────────────────────────────────────────────
  Animation<double> _stagger(double start, double end) {
    return Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      ),
    );
  }

  Widget _fadeSlide({required Animation<double> anim, double offsetY = 22, required Widget child}) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, offsetY * (1.0 - anim.value)),
          child: child,
        ),
      ),
    );
  }

  // ── Button Builders ───────────────────────────────────────────────────────
  Widget _buildLongButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black, width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black, blurRadius: 0, offset: Offset(4, 4)),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 14),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    fontFamily: _lFont,
                    letterSpacing: 0.8)),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white60, size: 14),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: _lBg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── IMAGE BANNER ────────────────────────────────────────────────
                  _fadeSlide(
                    anim: _stagger(0.0, 0.22),
                    offsetY: 0,
                    child: Container(
                      width: double.infinity,
                      height: 290,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.asset(
                              "assets/images/logo.png",
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            bottom: 0, left: 0, right: 0,
                            child: Container(
                              height: 70,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [_lBg, Colors.transparent],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0, bottom: 0, left: 0,
                            child: Container(
                              width: 30,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [Colors.black.withOpacity(0.15), Colors.transparent],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0, bottom: 0, right: 0,
                            child: Container(
                              width: 30,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerRight,
                                  end: Alignment.centerLeft,
                                  colors: [Colors.black.withOpacity(0.15), Colors.transparent],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0, left: 0, right: 0,
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.black.withOpacity(0.1), Colors.transparent],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),

                        // ── VOID ENGINE TITLE ────────────────────────────────────
                        _fadeSlide(
                          anim: _stagger(0.10, 0.32),
                          child: RichText(
                            text: const TextSpan(
                              style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: _lFont,
                                  letterSpacing: 2.5),
                              children: [
                                TextSpan(text: "Ultra", style: TextStyle(color: _lText)),
                                TextSpan(text: "Atlas", style: TextStyle(color: _lAccent)),
                                TextSpan(text: "  "),
                                TextSpan(text: "", style: TextStyle(color: _lAccent)),
                                TextSpan(text: "", style: TextStyle(color: _lText)),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // ── SUBTITLE ─────────────────────────────────────────────
                        _fadeSlide(
                          anim: _stagger(0.16, 0.38),
                          child: const Text(
                            "Aplikasi Yang Dikembangkab Atlas Team",
                            style: TextStyle(
                                color: _lTextSub,
                                fontSize: 12,
                                fontFamily: _lFont,
                                letterSpacing: 0.8,
                                height: 1.5),
                          ),
                        ),

                        const SizedBox(height: 22),

                        // ── INFO BOX ─────────────────────────────────────────────
                        _fadeSlide(
                          anim: _stagger(0.22, 0.44),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _lBgCard,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.black, width: 1.5),
                              boxShadow: const [
                                BoxShadow(color: Colors.black, blurRadius: 0, offset: Offset(4, 4)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Icon(Icons.info_outline_rounded, color: _lAccent, size: 16),
                                  const SizedBox(width: 8),
                                  const Text("Tentang Atlas",
                                      style: TextStyle(
                                          color: _lText,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          fontFamily: _lFont,
                                          letterSpacing: 0.8)),
                                ]),
                                const SizedBox(height: 10),
                                const Text(
                                  "Atlas adalah platform tools canggih yang dirancang untuk memberikan performa terbaik. "
                                  "Dikembangkan secara profesional oleh billyOfficial - heksenOfficial dengan teknologi mutakhir dan sistem keamanan tinggi.",
                                  style: TextStyle(
                                      color: _lTextSub,
                                      fontSize: 12,
                                      fontFamily: _lFont,
                                      height: 1.65),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // ── BUTTON: SIGN IN ──────────────────────────────────────
                        _fadeSlide(
                          anim: _stagger(0.28, 0.50),
                          child: _buildLongButton(
                            icon: Icons.login_rounded,
                            label: "Sign-In To Atlas",
                            color: _lAccent,
                            onTap: () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginPage()),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ── BUTTON: BUY ACCOUNT ──────────────────────────────────
                        _fadeSlide(
                          anim: _stagger(0.34, 0.56),
                          child: _buildLongButton(
                            icon: Icons.shopping_cart_rounded,
                            label: "Buy Account",
                            color: Colors.orange, // warna menonjol
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const BuyAccountPage()),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── FOOTER BOX ────────────────────────────────────────────
                        _fadeSlide(
                          anim: _stagger(0.42, 0.64),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              color: _lBgCard,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.black, width: 1.5),
                              boxShadow: const [
                                BoxShadow(color: Colors.black, blurRadius: 0, offset: Offset(4, 4)),
                              ],
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  "By: Atlas Team",
                                  style: TextStyle(
                                      color: _lAccent,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: _lFont,
                                      letterSpacing: 2),
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  "© 2026 Atlas Team — All Rights Reserved",
                                  style: TextStyle(
                                      color: _lTextSub, fontSize: 10, fontFamily: _lFont, letterSpacing: 0.8),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 36),
                      ],
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