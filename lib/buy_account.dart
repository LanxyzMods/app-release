import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'theme_provider.dart';

class BuyAccountPage extends StatefulWidget {
  const BuyAccountPage({super.key});

  @override
  State<BuyAccountPage> createState() => _BuyAccountPageState();
}

class _BuyAccountPageState extends State<BuyAccountPage>
    with SingleTickerProviderStateMixin {
  // Ganti dengan API key QRIS Atlas Anda
  final String atlasApiKey = "atlas_0ff250e07243c63d";
  final String createAccountApiUrl = "https://app.atlas-by-erlan.com/CreateAccount";
  final String adminPw = "000419";

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  int _selectedPackageIndex = 0;

  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final List<Map<String, dynamic>> _packages = [
    {
      'title': 'Member 1 Hari',
      'role': 'member',
      'days': 1,
      'desc': 'Akses harian · role member',
      'price': 2000,
      'originalPrice': 2500,
      'discount': '-20%',
    },
    {
      'title': 'Member 2 Hari',
      'role': 'member',
      'days': 2,
      'desc': 'Akses 2 hari · role member',
      'price': 4000,
      'originalPrice': 5000,
      'discount': '-20%',
    },
    {
      'title': 'Member 3 Hari',
      'role': 'member',
      'days': 3,
      'desc': 'Akses 3 hari · role member',
      'price': 6000,
      'originalPrice': 7500,
      'discount': '-20%',
    },
    {
      'title': 'Member 4 Hari',
      'role': 'member',
      'days': 4,
      'desc': 'Akses 4 hari · role member',
      'price': 8000,
      'originalPrice': 10000,
      'discount': '-20%',
    },
    {
      'title': 'Member 7 Hari',
      'role': 'member',
      'days': 7,
      'desc': 'Akses 7 hari · role member',
      'price': 15000,
      'originalPrice': 17000,
      'discount': '-12%',
    },
    {
      'title': 'Member 1 Bulan',
      'role': 'member',
      'days': 30,
      'desc': 'Akses 30 hari · role member',
      'price': 25000,
      'originalPrice': 35000,
      'discount': '-20%',
    },
    {
      'title': 'Member Permanen',
      'role': 'member',
      'days': 9999,
      'desc': 'Akses permanen · role member',
      'price': 40000,
      'originalPrice': 50000,
      'discount': '-20%',
    },
    {
      'title': 'Reseller Permanen',
      'role': 'reseller',
      'days': 9999,
      'desc': 'Akses reseller · slot unlimited',
      'price': 55000,
      'originalPrice': 65000,
      'discount': '-18%',
    },
    {
      'title': 'Partner Permanen',
      'role': 'partner',
      'days': 9999,
      'desc': 'Akses partner · slot unlimited',
      'price': 80000,
      'originalPrice': 105000,
      'discount': '-24%',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initAnim();
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

  @override
  void dispose() {
    _controller.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    String username = _usernameController.text.trim();
    String password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showPopup(
        title: "⚠️ Data Belum Lengkap",
        message: "Harap isi Username dan Password terlebih dahulu.",
      );
      return;
    }

    setState(() => _isLoading = true);

    final selectedPkg = _packages[_selectedPackageIndex];
    final int nominal = selectedPkg['price'];
    final String reference = "BUY-$username-${DateTime.now().millisecondsSinceEpoch}";

    try {
      final response = await http.get(
        Uri.parse('https://qris.atlas-by-erlan.com/topup?nominal=$nominal&apikey=$atlasApiKey&reference=$reference'),
      );

      final decoded = jsonDecode(response.body);

      setState(() => _isLoading = false);

      if (decoded['ok'] == true && decoded['data'] != null) {
        final data = decoded['data'];
        final String orderId = data['id'];
        final String qrisString = data['qris'];
        final int payAmount = data['pay_amount'] ?? nominal;

        _showQrisDialog(
          orderId: orderId,
          qrisString: qrisString,
          total: payAmount,
          role: selectedPkg['role'],
          days: selectedPkg['days'],
          username: username,
          password: password,
        );
      } else {
        _showPopup(
          title: "❌ Gagal Order",
          message: decoded['message'] ?? "Gagal membuat order QRIS.",
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showPopup(
        title: "⚠️ Koneksi Error",
        message: "Terjadi kesalahan koneksi QRIS Gateway.",
      );
    }
  }

  void _showQrisDialog({
    required String orderId,
    required String qrisString,
    required int total,
    required String role,
    required int days,
    required String username,
    required String password,
  }) {
    Timer? timer;
    final theme = Provider.of<ThemeProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        String paymentStatus = "Menunggu Pembayaran...";

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            timer ??= Timer.periodic(const Duration(seconds: 4), (t) async {
              try {
                final res = await http.get(
                  Uri.parse('https://qris.atlas-by-erlan.com/check-status?id=$orderId'),
                );
                final statusDecoded = jsonDecode(res.body);

                if (statusDecoded['ok'] == true && statusDecoded['data'] != null) {
                  final statusData = statusDecoded['data'];
                  final String status = statusData['status'];

                  if (status == 'paid' || status == 'success') {
                    t.cancel();
                    Navigator.pop(dialogContext);
                    _executeCreateAccount(
                      username: username,
                      password: password,
                      role: role,
                      days: days,
                    );
                  } else if (status == 'expired' || status == 'failed' || status == 'cancelled') {
                    t.cancel();
                    setDialogState(() {
                      paymentStatus = "Pembayaran Kadaluarsa / Gagal!";
                    });
                  }
                }
              } catch (_) {}
            });

            return Dialog(
              backgroundColor: Colors.transparent,
              child: TweenAnimationBuilder(
                duration: const Duration(milliseconds: 300),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double scale, child) {
                  return Transform.scale(scale: scale, child: child);
                },
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [theme.backgroundColor, theme.backgroundColor.withOpacity(0.95)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: theme.primaryColor.withOpacity(0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primaryColor.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
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
                        child: const Icon(Icons.qr_code_2, color: Colors.white, size: 32),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Scan QRIS",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: theme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "ID: $orderId",
                        style: TextStyle(fontSize: 12, color: theme.textSecondaryColor),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          "Rp ${total.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: 200,
                        height: 200,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
                          boxShadow: [
                            BoxShadow(
                              color: theme.primaryColor.withOpacity(0.1),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Center(
                          child: QrImageView(
                            data: qrisString,
                            version: QrVersions.auto,
                            size: 180.0,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Setelah bayar, akun otomatis aktif.\nStatus dicek tiap 4 detik.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.textSecondaryColor, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          paymentStatus,
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: () async {
                          timer?.cancel();
                          try {
                            await http.get(
                              Uri.parse('https://qris.atlas-by-erlan.com/cancel-order?id=$orderId'),
                            );
                          } catch (_) {}
                          Navigator.pop(dialogContext);
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Center(
                            child: Text(
                              "TUTUP / BATALKAN",
                              style: TextStyle(
                                color: theme.textSecondaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) => timer?.cancel());
  }

  Future<void> _executeCreateAccount({
    required String username,
    required String password,
    required String role,
    required int days,
  }) async {
    final theme = Provider.of<ThemeProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: theme.primaryColor),
      ),
    );

    try {
      final uri = Uri.parse(
        '$createAccountApiUrl?pw=$adminPw&username=$username&password=$password&role=$role&day=$days',
      );

      final res = await http.get(uri);
      final data = jsonDecode(res.body);

      if (mounted) Navigator.pop(context);

      if (data['valid'] == true && data['created'] == true) {
        final user = data['user'];
        if (mounted) {
          _showSuccessDialog(
            username: user['username'] ?? username,
            password: user['password'] ?? password,
            role: user['role'] ?? role,
            expired: user['expiredDate'] ?? '-',
          );
        }
      } else {
        if (mounted) {
          _showPopup(
            title: "❌ Pembuatan Gagal",
            message: data['message'] ?? "Gagal membuat akun.",
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        _showPopup(
          title: "⚠️ Koneksi Error",
          message: "Gagal menghubungi server CreateAccount.",
        );
      }
    }
  }

  void _showSuccessDialog({
    required String username,
    required String password,
    required String role,
    required String expired,
  }) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        "PEMBAYARAN SUKSES",
                        style: TextStyle(
                          color: theme.textPrimaryColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  "Akun Anda berhasil dibuat & diaktifkan!",
                  style: TextStyle(color: theme.textSecondaryColor, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.glassSecondary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.textPrimaryColor.withOpacity(0.08)),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow("Username", username, theme),
                      const SizedBox(height: 8),
                      _buildDetailRow("Password", password, theme),
                      const SizedBox(height: 8),
                      _buildDetailRow("Role", role.toUpperCase(), theme),
                      const SizedBox(height: 8),
                      _buildDetailRow("Expired", expired, theme),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: double.infinity,
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
                    child: const Center(
                      child: Text(
                        "SELESAI",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, ThemeProvider theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "$label:",
          style: TextStyle(color: theme.textSecondaryColor, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            color: theme.textPrimaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  void _showPopup({required String title, required String message}) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
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
                ),
                child: const Icon(Icons.warning_rounded, color: Colors.white, size: 32),
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
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      "TUTUP",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(
      TextEditingController controller, String label, IconData icon, bool isPassword, ThemeProvider theme) {
    return Container(
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
    final selectedPkg = _packages[_selectedPackageIndex];

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
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: theme.glassSecondary,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: theme.textPrimaryColor.withOpacity(0.1)),
                              ),
                              child: Icon(Icons.arrow_back_ios_new_rounded, color: theme.primaryColor, size: 18),
                            ),
                          ),
                          const Expanded(
                            child: Text(
                              "BELI AKSES",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 38),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [theme.glassPrimary, theme.glassSecondary],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: theme.textPrimaryColor.withOpacity(0.08)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ShaderMask(
                                    shaderCallback: (bounds) => LinearGradient(
                                      colors: [theme.primaryColor, theme.accentColor],
                                    ).createShader(bounds),
                                    child: const Text(
                                      "XCUBE STORE",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Pilih paket, isi akun, bayar QRIS – dan langsung gunakan.",
                                    style: TextStyle(
                                      color: theme.textSecondaryColor,
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 28),

                            Text(
                              "PILIH PAKET",
                              style: TextStyle(
                                color: theme.textPrimaryColor,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 12),

                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _packages.length,
                              itemBuilder: (context, index) {
                                final item = _packages[index];
                                final bool isSelected = _selectedPackageIndex == index;

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedPackageIndex = index;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? theme.primaryColor.withOpacity(0.12)
                                          : theme.glassSecondary,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected
                                            ? theme.primaryColor
                                            : theme.textPrimaryColor.withOpacity(0.08),
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Radio<int>(
                                          value: index,
                                          groupValue: _selectedPackageIndex,
                                          activeColor: theme.primaryColor,
                                          onChanged: (val) {
                                            setState(() {
                                              _selectedPackageIndex = val!;
                                            });
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    item['title'],
                                                    style: TextStyle(
                                                      color: theme.textPrimaryColor,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: theme.primaryColor.withOpacity(0.2),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      item['discount'],
                                                      style: TextStyle(
                                                        color: theme.primaryColor,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                item['desc'],
                                                style: TextStyle(
                                                  color: theme.textSecondaryColor,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              "Rp ${item['originalPrice']}",
                                              style: TextStyle(
                                                color: theme.textSecondaryColor.withOpacity(0.5),
                                                fontSize: 11,
                                                decoration: TextDecoration.lineThrough,
                                              ),
                                            ),
                                            Text(
                                              "Rp ${item['price']}",
                                              style: TextStyle(
                                                color: theme.primaryColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 28),

                            Text(
                              "BUAT AKUN BARU",
                              style: TextStyle(
                                color: theme.textPrimaryColor,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 12),

                            Column(
                              children: [
                                _buildInput(_usernameController, "Username",
                                    Icons.person_outline_rounded, false, theme),
                                const SizedBox(height: 16),
                                _buildInput(_passwordController, "Password",
                                    Icons.lock_outline_rounded, true, theme),
                              ],
                            ),
                            const SizedBox(height: 28),
                          ],
                        ),
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      decoration: BoxDecoration(
                        color: theme.glassSecondary,
                        border: Border(
                          top: BorderSide(color: theme.textPrimaryColor.withOpacity(0.08)),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "TOTAL",
                                style: TextStyle(
                                  color: theme.textSecondaryColor,
                                  fontSize: 10,
                                  letterSpacing: 1,
                                ),
                              ),
                              Text(
                                "Rp ${selectedPkg['price']}",
                                style: TextStyle(
                                  color: theme.primaryColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: 50,
                            child: GestureDetector(
                              onTap: _isLoading ? null : _processPayment,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                      colors: [theme.primaryColor, theme.accentColor]),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.primaryColor.withOpacity(0.4),
                                      blurRadius: 12,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Row(
                                          children: [
                                            Icon(Icons.qr_code_scanner_rounded,
                                                color: Colors.white, size: 20),
                                            SizedBox(width: 8),
                                            Text(
                                              "BAYAR QRIS",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                          ],
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
