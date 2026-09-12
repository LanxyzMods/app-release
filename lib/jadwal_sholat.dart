import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class JadwalSholatPage extends StatefulWidget {
  final String sessionKey;
  final String username;

  const JadwalSholatPage({
    super.key,
    required this.sessionKey,
    required this.username,
  });

  @override
  State<JadwalSholatPage> createState() => _JadwalSholatPageState();
}

class _JadwalSholatPageState extends State<JadwalSholatPage> {
  final TextEditingController _cityController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _sholatData;
  String? _errorMessage;

  Future<void> _fetchJadwalSholat() async {
    final city = _cityController.text.trim();
    if (city.isEmpty) {
      setState(() {
        _errorMessage = "Masukkan nama kota";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _sholatData = null;
    });

    try {
      final url = Uri.parse("https://api.deline.web.id/info/jadwalsholat?kota=$city");
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true) {
          setState(() {
            _sholatData = data['result'];
          });
        } else {
          setState(() {
            _errorMessage = "Kota tidak ditemukan";
          });
        }
      } else {
        setState(() {
          _errorMessage = "Gagal mengambil data jadwal sholat";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Koneksi gagal: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  IconData _getSholatIcon(String name) {
    switch (name) {
      case 'Imsak':
        return Icons.bedtime;
      case 'Fajr':
        return Icons.brightness_5;
      case 'Sunrise':
        return Icons.wb_sunny;
      case 'Dhuhr':
        return Icons.sunny;
      case 'Asr':
        return Icons.brightness_6;
      case 'Sunset':
        return Icons.nightlight;
      case 'Maghrib':
        return Icons.nightlight_round;
      case 'Isha':
        return Icons.nights_stay;
      case 'Midnight':
        return Icons.bedtime;
      default:
        return Icons.access_time;
    }
  }

  String _formatSholatName(String name) {
    switch (name) {
      case 'Fajr': return 'Subuh';
      case 'Sunrise': return 'Terbit';
      case 'Dhuhr': return 'Dzuhur';
      case 'Asr': return 'Ashar';
      case 'Sunset': return 'Terbenam';
      case 'Maghrib': return 'Maghrib';
      case 'Isha': return 'Isya';
      case 'Imsak': return 'Imsak';
      case 'Midnight': return 'Tengah Malam';
      case 'Firstthird': return 'Sepertiga Malam';
      case 'Lastthird': return 'Sepertiga Akhir';
      default: return name;
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
          child: Text(
            "JADWAL SHOLAT",
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
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: theme.glassSecondary,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.textPrimaryColor.withOpacity(0.1)),
                  ),
                  child: TextField(
                    controller: _cityController,
                    style: TextStyle(color: theme.textPrimaryColor),
                    decoration: InputDecoration(
                      hintText: "Cari kota...",
                      hintStyle: TextStyle(color: theme.textSecondaryColor.withOpacity(0.5)),
                      prefixIcon: Icon(Icons.search, color: theme.primaryColor),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.send_rounded, color: theme.primaryColor),
                        onPressed: _fetchJadwalSholat,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    onSubmitted: (_) => _fetchJadwalSholat(),
                  ),
                ),

                const SizedBox(height: 24),

                // Loading
                if (_isLoading)
                  Center(
                    child: CircularProgressIndicator(color: theme.primaryColor),
                  ),

                // Error Message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Jadwal Sholat Data
                if (_sholatData != null) ...[
                  // Lokasi & Tanggal Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.glassPrimary,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: theme.textPrimaryColor.withOpacity(0.08)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.mosque, color: theme.primaryColor, size: 40),
                        const SizedBox(height: 12),
                        Text(
                          _sholatData!['lokasi'] ?? "Tidak diketahui",
                          style: TextStyle(
                            color: theme.textPrimaryColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.glassSecondary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _sholatData!['tanggal'] ?? "",
                            style: TextStyle(color: theme.textSecondaryColor, fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _sholatData!['hijri'] ?? "",
                          style: const TextStyle(color: Color(0xFF22C55E), fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Waktu Sholat Grid
                  Text(
                    "WAKTU SHOLAT",
                    style: TextStyle(
                      color: theme.textSecondaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),

                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.5,
                    children: _buildSholatList(theme),
                  ),

                  const SizedBox(height: 20),

                  // Catatan
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.glassSecondary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.textPrimaryColor.withOpacity(0.05)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: theme.primaryColor, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Jadwal sholat berdasarkan lokasi yang dipilih",
                            style: TextStyle(color: theme.textSecondaryColor, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSholatList(ThemeProvider theme) {
    final waktu = _sholatData!['waktu'] as Map<String, dynamic>;
    final List<String> order = [
      'Imsak', 'Fajr', 'Sunrise', 'Dhuhr', 'Asr', 
      'Sunset', 'Maghrib', 'Isha', 'Midnight'
    ];
    
    final List<Widget> widgets = [];
    
    for (String key in order) {
      if (waktu.containsKey(key)) {
        widgets.add(_buildSholatCard(
          name: _formatSholatName(key),
          time: waktu[key].toString(),
          theme: theme,
        ));
      }
    }
    
    return widgets;
  }

  Widget _buildSholatCard({
    required String name,
    required String time,
    required ThemeProvider theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.glassPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.textPrimaryColor.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getSholatIcon(name),
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: theme.textPrimaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            time,
            style: TextStyle(
              color: theme.primaryColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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