// riwayat_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class RiwayatPage extends StatefulWidget {
  final String sessionKey;
  final String role;

  const RiwayatPage({
    super.key,
    required this.sessionKey,
    required this.role,
  });

  @override
  State<RiwayatPage> createState() => _RiwayatPageState();
}

class _RiwayatPageState extends State<RiwayatPage> {
  List<ActivityModel> activities = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    const baseUrl = "https://app.atlas-by-erlan.com";

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/getMyActivity?key=${widget.sessionKey}'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['valid']) {
          List<dynamic> rawList = data['activities'];

          setState(() {
            activities = rawList.map((item) {
              return ActivityModel(
                type: item['type'] ?? 'system',
                title: item['title'] ?? 'Aktivitas',
                description: item['description'] ?? '-',
                timestamp: DateTime.fromMillisecondsSinceEpoch(
                    item['timestamp'] ?? DateTime.now().millisecondsSinceEpoch
                ),
              );
            }).toList();
            isLoading = false;
          });
        } else {
          setState(() => isLoading = false);
        }
      } else {
        print("Server Error: ${response.statusCode}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Error fetching history: $e");
      setState(() => isLoading = false);
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
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
            "RIWAYAT AKTIVITAS",
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
          child: isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: theme.primaryColor,
                    strokeWidth: 3,
                  ),
                )
              : activities.isEmpty
                  ? Center(
                      child: TweenAnimationBuilder(
                        duration: const Duration(milliseconds: 600),
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
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [theme.primaryColor.withOpacity(0.1), theme.accentColor.withOpacity(0.1)],
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
                              ),
                              child: Icon(Icons.history_toggle_off, size: 60, color: theme.primaryColor),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              "Belum ada aktivitas",
                              style: TextStyle(
                                color: theme.textSecondaryColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Pastikan server aktif",
                              style: TextStyle(
                                color: theme.textSecondaryColor.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadActivities,
                      color: theme.primaryColor,
                      backgroundColor: theme.glassSecondary,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: activities.length,
                        itemBuilder: (context, index) {
                          final activity = activities[index];
                          return TweenAnimationBuilder(
                            duration: Duration(milliseconds: 300 + (index * 50)),
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
                            child: _buildActivityCard(activity, index, theme),
                          );
                        },
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildActivityCard(ActivityModel activity, int index, ThemeProvider theme) {
    Color iconColor;
    IconData iconData;
    LinearGradient iconGradient;
    String typeLabel;

    switch (activity.type) {
      case 'login':
        iconColor = Colors.greenAccent;
        iconData = Icons.login_rounded;
        iconGradient = const LinearGradient(
          colors: [Color(0xFF00E676), Color(0xFF00C853)],
        );
        typeLabel = "LOGIN";
        break;
      case 'bug':
        iconColor = Colors.orangeAccent;
        iconData = Icons.bug_report_outlined;
        iconGradient = const LinearGradient(
          colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
        );
        typeLabel = "ATTACK";
        break;
      case 'create':
        iconColor = Colors.cyanAccent;
        iconData = Icons.person_add_alt_1_rounded;
        iconGradient = const LinearGradient(
          colors: [Color(0xFF00BCD4), Color(0xFF0097A7)],
        );
        typeLabel = "ACCOUNT";
        break;
      default:
        iconColor = theme.textSecondaryColor;
        iconData = Icons.info_outline;
        iconGradient = LinearGradient(
          colors: [theme.textSecondaryColor, theme.textSecondaryColor.withOpacity(0.7)],
        );
        typeLabel = "SYSTEM";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: iconGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: iconColor.withOpacity(0.3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(iconData, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        activity.title,
                        style: TextStyle(
                          color: theme.textPrimaryColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        typeLabel,
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  activity.description,
                  style: TextStyle(
                    color: theme.textSecondaryColor,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 12, color: theme.textSecondaryColor.withOpacity(0.7)),
                    const SizedBox(width: 6),
                    Text(
                      _formatDate(activity.timestamp),
                      style: TextStyle(
                        color: theme.textSecondaryColor.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ActivityModel {
  final String type;
  final String title;
  final String description;
  final DateTime timestamp;

  ActivityModel({
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
  });
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