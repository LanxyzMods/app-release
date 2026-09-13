import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'dashboard_page.dart';
import 'login_page.dart';
import 'theme_provider.dart';

class SplashScreen extends StatefulWidget {
  final String username;
  final String password;
  final String role;
  final String sessionKey;
  final String expiredDate;
  final List<Map<String, dynamic>> listBug;
  final List<dynamic> news;

  const SplashScreen({
    super.key,
    required this.username,
    required this.password,
    required this.role,
    required this.sessionKey,
    required this.expiredDate,
    required this.listBug,
    required this.news,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // ── State onboarding ──
  late PageController _pageController;
  double _page = 0;
  bool _onboardingComplete = false;

  // ── State video ──
  late VideoPlayerController _videoController;
  bool _videoReady = false;
  bool _skipPressed = false;

  // ── Animasi onboarding ──
  late AnimationController _introController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ── Warna (dari splash_video_page) ──
  static const Color bgMain = Color(0xFFDCEEFB);
  static const Color bgCard = Color(0xFFFFFFFF);
  static const Color accentBlue = Color(0xFF1565C0);
  static const Color borderBlue = Color(0xFF42A5F5);
  static const Color textMain = Colors.black87;
  static const Color textSub = Colors.black54;

  // ── Langkah onboarding ──
  late final List<_OnboardStep> _steps;

  @override
  void initState() {
    super.initState();

    _steps = [
      _OnboardStep(
        badge: "WELCOME !!!",
        title: "Welcome To Atlas\n${widget.username.toUpperCase()}",
        subtitle: "Nikmati pengalaman terbaik bersama kami",
        buttonLabel: "LANJUT",
      ),
      const _OnboardStep(
        badge: "TERIMA KASIH YA !!",
        title: "SETIA DENGAN KAMI",
        subtitle:
            "terima kasih telah mensupport kami, walaupun terkadang project kami sering ampas / error, tapi kalian hebat selalu setia dengan ATLAS",
        buttonLabel: "LANJUT",
      ),
      const _OnboardStep(
        badge: "ARE YOU READY ?!",
        title: "ENTER SPLASH",
        subtitle: "Nikmati apps atlas bro!!",
        buttonLabel: "MULAI SEKARANG",
        filledButton: true,
      ),
    ];

    _pageController = PageController()..addListener(() {
      if (mounted) setState(() => _page = _pageController.page ?? 0);
    });

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();

    _fadeAnim = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _initializeVideo();
  }

  // ── Inisialisasi video (disiapkan, belum diputar) ──
  void _initializeVideo() {
    _videoController = VideoPlayerController.asset('assets/videos/splash.mp4')
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _videoReady = true);
          _videoController.setLooping(false);
          _videoController.setVolume(1.0);
        }
      }).catchError((err) {
        debugPrint('Video splash error: $err');
        if (mounted) setState(() => _videoReady = true); // lanjut tanpa video
      });
  }

  // ── Mulai video (dipanggil saat onboarding selesai) ──
  void _startVideo() {
    if (_skipPressed) return;
    setState(() => _onboardingComplete = true);

    if (_videoReady && _videoController.value.isInitialized) {
      _videoController.play();
      _videoController.addListener(() {
        if (!mounted || _skipPressed) return;
        if (_videoController.value.position >= _videoController.value.duration) {
          _goToDashboard();
        }
      });
    } else {
      // Jika video gagal, langsung ke dashboard setelah 1 detik
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && !_skipPressed) _goToDashboard();
      });
    }
  }

  // ── Pindah ke Dashboard ──
  void _goToDashboard() {
    if (_skipPressed) return;
    _skipPressed = true;
    _videoController.pause();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DashboardPage(
          username: widget.username,
          password: widget.password,
          role: widget.role,
          expiredDate: widget.expiredDate,
          listBug: widget.listBug,
          sessionKey: widget.sessionKey,
          news: widget.news,
        ),
      ),
    );
  }

  // ── Skip (lewati onboarding atau video) ──
  void _skipSplash() {
    if (_skipPressed) return;
    if (!_onboardingComplete) {
      // Lewati onboarding langsung ke video
      setState(() => _onboardingComplete = true);
      _startVideo();
    } else {
      _goToDashboard();
    }
  }

  int get _currentIndex => _page.round().clamp(0, _steps.length - 1);

  void _nextOnboarding() {
    if (_currentIndex < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
      );
    } else {
      _startVideo(); // Tombol MULAI SEKARANG
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _introController.dispose();
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _onboardingComplete ? _buildVideoSplash() : _buildOnboarding();
  }

  // ─── BUILD ONBOARDING ────────────────────────────────────────────
  Widget _buildOnboarding() {
    return Scaffold(
      backgroundColor: bgMain,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: bgMain),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.35, 0.65, 1.0],
                  colors: [
                    borderBlue.withOpacity(0.10),
                    bgMain,
                    bgMain,
                    const Color(0xFFF0F7FF),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -80,
            top: MediaQuery.of(context).size.height * 0.15,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  borderBlue.withOpacity(0.18),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Header
                FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.3),
                      end: Offset.zero,
                    ).animate(_fadeAnim),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: bgCard,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.black, width: 1.5),
                              boxShadow: const [
                                BoxShadow(color: Colors.black, blurRadius: 0, offset: Offset(3, 3)),
                              ],
                            ),
                            child: const Icon(Icons.bolt_rounded, color: accentBlue, size: 22),
                          ),
                          GestureDetector(
                            onTap: _skipSplash,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: bgCard,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.black, width: 1.5),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black, blurRadius: 0, offset: Offset(3, 3)),
                                ],
                              ),
                              child: Text(
                                "LEWATI",
                                style: TextStyle(
                                  fontFamily: 'Orbitron',
                                  color: textMain,
                                  fontSize: 12,
                                  letterSpacing: 1,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                // PageView
                FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: SizedBox(
                      height: 245,
                      child: PageView.builder(
                        controller: _pageController,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _steps.length,
                        itemBuilder: (context, index) {
                          final distance = (index - _page).abs().clamp(0.0, 1.0);
                          final scale = 1.0 - (distance * 0.08);
                          final opacity = 1.0 - (distance * 0.6);
                          return Transform.scale(
                            scale: scale,
                            child: Opacity(
                              opacity: opacity.clamp(0.0, 1.0),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: _buildCard(_steps[index], index),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                // Dots
                FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    children: [
                      Text(
                        "Geser untuk lanjut",
                        style: TextStyle(
                          fontFamily: 'Orbitron',
                          color: textSub,
                          fontSize: 11,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_steps.length, (i) {
                          final active = i == _currentIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: active ? 22 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: active ? accentBlue : Colors.black.withOpacity(0.18),
                              boxShadow: active
                                  ? [BoxShadow(color: accentBlue.withOpacity(0.5), blurRadius: 6, spreadRadius: 0.5)]
                                  : null,
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // Tombol aksi
                FadeTransition(
                  opacity: _fadeAnim,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: GestureDetector(
                      onTap: _nextOnboarding,
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: _steps[_currentIndex].filledButton ? accentBlue : bgCard,
                          border: Border.all(color: Colors.black, width: 1.5),
                          boxShadow: const [
                            BoxShadow(color: Colors.black, blurRadius: 0, offset: Offset(4, 4)),
                          ],
                        ),
                        child: Text(
                          _steps[_currentIndex].buttonLabel,
                          style: TextStyle(
                            fontFamily: 'Orbitron',
                            color: _steps[_currentIndex].filledButton ? Colors.white : textMain,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
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

  Widget _buildCard(_OnboardStep step, int index) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black, blurRadius: 0, offset: Offset(4, 4)),
          BoxShadow(color: Color(0xFF42A5F5), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 3,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [borderBlue, accentBlue]),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: accentBlue.withOpacity(0.10),
              border: Border.all(color: accentBlue.withOpacity(0.45)),
            ),
            child: Text(
              step.badge,
              style: const TextStyle(
                fontFamily: 'Orbitron',
                color: accentBlue,
                fontSize: 11,
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            step.title,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Orbitron',
              color: textMain,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            step.subtitle,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Orbitron',
              color: textSub,
              fontSize: 12.5,
              height: 1.5,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              "${index + 1} / ${_steps.length}",
              style: TextStyle(
                fontFamily: 'Orbitron',
                color: textSub,
                fontSize: 10.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── BUILD VIDEO SPLASH ──────────────────────────────────────────
  Widget _buildVideoSplash() {
    final bool useVideo = _videoReady && _videoController.value.isInitialized;

    return Scaffold(
      backgroundColor: const Color(0xFF050810),
      body: GestureDetector(
        onTap: _skipSplash,
        child: Stack(
          children: [
            if (useVideo)
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoController.value.size.width,
                    height: _videoController.value.size.height,
                    child: VideoPlayer(_videoController),
                  ),
                ),
              ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                    stops: const [0.0, 0.25, 0.65, 1.0],
                  ),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 1,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          const Color(0xFF00D4FF).withOpacity(0.7),
                        ],
                      ),
                    ),
                    margin: const EdgeInsets.only(bottom: 28),
                  ),
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        const Color(0xFFEEF2FF),
                        const Color(0xFF00D4FF),
                        const Color(0xFFEEF2FF),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ).createShader(bounds),
                    child: Text(
                      "ATLAS",
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                        letterSpacing: 14,
                        height: 1.1,
                        fontFamily: 'Orbitron',
                        shadows: [
                          Shadow(
                            color: const Color(0xFF00D4FF).withOpacity(0.6),
                            blurRadius: 24,
                            offset: const Offset(0, 0),
                          ),
                          Shadow(
                            color: Colors.black.withOpacity(0.8),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Text(
                      "Hanya Untuk Bersenang - Senang",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w300,
                        color: const Color(0xFFEEF2FF).withOpacity(0.75),
                        letterSpacing: 2.5,
                        fontStyle: FontStyle.italic,
                        fontFamily: 'Orbitron',
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.9),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Container(
                    width: 80,
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          const Color(0xFF00D4FF).withOpacity(0.5),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    margin: const EdgeInsets.only(top: 28),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 44,
              right: 20,
              child: GestureDetector(
                onTap: _skipSplash,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: const Color(0xFF00D4FF).withOpacity(0.6),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00D4FF).withOpacity(0.15),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.fast_forward_rounded,
                        color: const Color(0xFF00D4FF),
                        size: 15,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'LEWATI',
                        style: TextStyle(
                          color: const Color(0xFFEEF2FF),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.8,
                          fontFamily: 'Orbitron',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 28,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    'Klik di mana saja untuk melanjutkan',
                    style: TextStyle(
                      color: const Color(0xFFEEF2FF).withOpacity(0.35),
                      fontSize: 10.5,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "ATLAS",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w300,
                      color: const Color(0xFF00D4FF).withOpacity(0.3),
                      letterSpacing: 8,
                      fontFamily: 'Orbitron',
                      shadows: [
                        Shadow(
                          color: const Color(0xFF00D4FF).withOpacity(0.3),
                          blurRadius: 6,
                        ),
                      ],
                    ),
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

// ─── MODEL UNTUK ONBOARDING STEP ─────────────────────────────────
class _OnboardStep {
  final String badge;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final bool filledButton;

  const _OnboardStep({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    this.filledButton = false,
  });
}