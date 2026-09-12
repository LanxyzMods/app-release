import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdatePage extends StatefulWidget {
  final String? currentVersion;
  final String? latestVersion;
  final String? releaseNotes;

  const UpdatePage({
    super.key,
    this.currentVersion = "1.0.0",
    this.latestVersion = "2.0.0",
    this.releaseNotes = "• Perbaikan bug & peningkatan performa\n• Penambahan fitur baru\n• Peningkatan keamanan sistem",
  });

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isLoading = false;

  final Color bgDark = const Color(0xFF0A0A0A);
  final Color bgCard = const Color(0xFF140808);
  final Color primaryRed = const Color(0xFFB71C1C);
  final Color accentRed = const Color(0xFFFF1744);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _launchUpdateUrl() async {
    setState(() => _isLoading = true);

    final String updateUrl = "https://app.atlas-by-erlan.com/app-reales.app";
    final Uri url = Uri.parse(updateUrl);

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
      } else {
        _showErrorSnackBar("Gagal membuka tautan pembaruan.");
      }
    } catch (e) {
      _showErrorSnackBar("Terjadi kesalahan: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: primaryRed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final scale = 1.0 + 0.05 * _pulseController.value;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: bgCard,
                          border: Border.all(
                            color: accentRed.withOpacity(0.6),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accentRed.withOpacity(
                                0.2 + 0.2 * _pulseController.value,
                              ),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.system_update_rounded,
                          size: 60,
                          color: accentRed,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 32),

                const Text(
                  "Pembaruan Tersedia!",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "Versi baru aplikasi sudah siap diunduh.",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildVersionBadge(
                      "Versi Saat Ini",
                      widget.currentVersion ?? "1.0.0",
                      Colors.grey[800]!,
                      Colors.white54,
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white30, size: 20),
                    const SizedBox(width: 12),
                    _buildVersionBadge(
                      "Versi Terbaru",
                      widget.latestVersion ?? "2.0.0",
                      primaryRed.withOpacity(0.3),
                      accentRed,
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: bgCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.new_releases_outlined, color: accentRed, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            "Catatan Pembaruan",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.releaseNotes ?? "Perbaikan sistem dan peningkatan kinerja.",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _launchUpdateUrl,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 8,
                      shadowColor: accentRed.withOpacity(0.5),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.download_rounded, size: 22),
                              SizedBox(width: 10),
                              Text(
                                "UPDATE SEKARANG",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
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
    );
  }

  Widget _buildVersionBadge(String label, String version, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            "v$version",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
