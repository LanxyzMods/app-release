import 'package:flutter/material.dart';
import 'dart:math' as math;

class MaintancePage extends StatefulWidget {
  const MaintancePage({super.key});

  @override
  State<MaintancePage> createState() => _MaintancePageState();
}

class _MaintancePageState extends State<MaintancePage>
    with TickerProviderStateMixin {
  late AnimationController _rotateController;
  late AnimationController _pulseController;
  late AnimationController _gradientController;

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _pulseController.dispose();
    _gradientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _gradientController,
        builder: (context, child) {
          final angle = _gradientController.value * 2 * math.pi;
          final dx = 0.5 + 0.5 * math.cos(angle);
          final dy = 0.5 + 0.5 * math.sin(angle);
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(dx, dy),
                radius: 1.2,
                colors: const [
                  Color(0xFF2A0A0A),
                  Color(0xFF0D0D0D),
                  Color(0xFF050505),
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 200,
                    width: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        RotationTransition(
                          turns: _rotateController,
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFFF1744).withOpacity(0.15),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        RotationTransition(
                          turns: Tween(begin: 0.0, end: -1.0).animate(
                            _rotateController,
                          ),
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFFF1744).withOpacity(0.10),
                                width: 1.0,
                              ),
                            ),
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final scale = 1.0 + 0.04 * _pulseController.value;
                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF1744).withOpacity(
                                        0.3 + 0.2 * _pulseController.value,
                                      ),
                                      blurRadius: 50 * (0.8 + 0.2 * _pulseController.value),
                                      spreadRadius: 20 * (0.5 + 0.5 * _pulseController.value),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Color(0xFFFF1744),
                        Color(0xFFFF6B81),
                        Color(0xFFFF1744),
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ).createShader(bounds),
                    child: const Text(
                      'LanxyzMods',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        const Color(0xFFFF1744).withOpacity(0.3),
                        const Color(0xFFFF1744).withOpacity(0.9),
                        const Color(0xFFFF1744).withOpacity(0.3),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ).createShader(bounds),
                    child: const Text(
                      'MAINTENANCE MODE',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 6,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.06),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF1744).withOpacity(
                                0.05 + 0.03 * _pulseController.value,
                              ),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Transform.translate(
                              offset: Offset(
                                0,
                                4 * math.sin(_pulseController.value * 2 * math.pi),
                              ),
                              child: const Icon(
                                Icons.build_circle_outlined,
                                color: Color(0xFFFF1744),
                                size: 64,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Sistem sedang maintance',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Sedang kami update.\nHarap tunggu beberapa saat.',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 14,
                                height: 1.6,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                3,
                                (index) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 600),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color.lerp(
                                      Colors.white.withOpacity(0.2),
                                      const Color(0xFFFF1744),
                                      (_pulseController.value + index / 3) % 1.0,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 48),

                  Text(
                    '© 2026 Devil — All rights reserved',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.15),
                      fontSize: 10,
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
