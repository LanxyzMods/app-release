import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'theme_provider.dart';

class UpgradePrice {
  final String fromRole;
  final String toRole;
  final int price;

  UpgradePrice({required this.fromRole, required this.toRole, required this.price});
}

class UpgradeRolePage extends StatefulWidget {
  final String sessionKey;
  final String role;
  final String username;

  const UpgradeRolePage({
    super.key,
    required this.sessionKey,
    required this.role,
    required this.username,
  });

  @override
  State<UpgradeRolePage> createState() => _UpgradeRolePageState();
}

class _UpgradeRolePageState extends State<UpgradeRolePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Ganti dengan API key QRIS Atlas Anda
  final String atlasApiKey = "atlas_0ff250e07243c63d";
  final List<String> roleOrder = ["member", "reseller", "partner"];

  final List<UpgradePrice> upgradePrices = [
    UpgradePrice(fromRole: "member", toRole: "reseller", price: 25000),
    UpgradePrice(fromRole: "reseller", toRole: "partner", price: 45000),
  ];

  String? selectedTargetRole;
  int? selectedPrice;
  bool isLoading = false;

  final List<String> consoleLogs = [];

  void addLog(String message) {
    if (!mounted) return;
    setState(() {
      consoleLogs.insert(0, "${DateTime.now().toString().substring(11, 19)} - $message");
      if (consoleLogs.length > 20) consoleLogs.removeLast();
    });
  }

  @override
  void initState() {
    super.initState();
    _initAnimations();

    final currentIndex = roleOrder.indexOf(widget.role.toLowerCase());
    if (currentIndex != -1 && currentIndex < roleOrder.length - 1) {
      final nextRole = roleOrder[currentIndex + 1];
      final priceItem = upgradePrices.firstWhere(
        (item) => item.fromRole == widget.role.toLowerCase() && item.toRole == nextRole,
        orElse: () => UpgradePrice(fromRole: "", toRole: "", price: 0),
      );
      selectedTargetRole = nextRole;
      selectedPrice = priceItem.price;
    }
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  List<String> getAvailableUpgrades() {
    final currentIndex = roleOrder.indexOf(widget.role.toLowerCase());
    if (currentIndex == -1) return [];
    return roleOrder.sublist(currentIndex + 1);
  }

  int? getUpgradePrice(String targetRole) {
    final priceItem = upgradePrices.firstWhere(
      (item) => item.fromRole == widget.role.toLowerCase() && item.toRole == targetRole,
      orElse: () => UpgradePrice(fromRole: "", toRole: "", price: 0),
    );
    return priceItem.price > 0 ? priceItem.price : null;
  }

  void _showSnackBar(String msg, bool isError) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.withOpacity(0.9) : theme.primaryColor.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> createTopup() async {
    if (selectedTargetRole == null || selectedPrice == null) {
      _showSnackBar("Pilih role tujuan terlebih dahulu", true);
      return;
    }

    setState(() => isLoading = true);
    final int nominal = selectedPrice!;
    final String reference = "UPG-${widget.username}-${DateTime.now().millisecondsSinceEpoch}";

    try {
      final response = await http.get(
        Uri.parse('https://qris.atlas-by-erlan.com/topup?nominal=$nominal&apikey=$atlasApiKey&reference=$reference'),
      );

      final decoded = jsonDecode(response.body);
      setState(() => isLoading = false);

      if (decoded['ok'] == true && decoded['data'] != null) {
        final data = decoded['data'];
        final String orderId = data['id'];
        final String qrisString = data['qris'];
        final int payAmount = data['pay_amount'] ?? nominal;

        addLog("✅ Transaksi dibuat: $orderId");
        _showQrisDialog(
          orderId: orderId,
          qrisString: qrisString,
          total: payAmount,
        );
      } else {
        addLog("❌ Gagal: ${decoded['message'] ?? "Gagal membuat order QRIS."}");
        _showSnackBar(decoded['message'] ?? "Gagal membuat order QRIS.", true);
      }
    } catch (e) {
      setState(() => isLoading = false);
      addLog("⚠️ Error: $e");
      _showSnackBar("Terjadi kesalahan koneksi QRIS Gateway.", true);
    }
  }

  void _showQrisDialog({
    required String orderId,
    required String qrisString,
    required int total,
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
                    addLog("✅ Pembayaran BERHASIL!");
                    await callUpgradeApi();
                  } else if (status == 'expired' || status == 'failed' || status == 'cancelled') {
                    t.cancel();
                    setDialogState(() {
                      paymentStatus = "Pembayaran Kadaluarsa / Gagal!";
                    });
                    addLog("⏰ Transaksi kadaluarsa / gagal / dibatalkan.");
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
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textSecondaryColor,
                        ),
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
                          NumberFormat.currency(
                            locale: 'id',
                            symbol: 'Rp ',
                            decimalDigits: 0,
                          ).format(total),
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
                        "Setelah bayar, role otomatis ter-upgrade\nStatus dicek tiap 4 detik",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.textSecondaryColor,
                          fontSize: 12,
                        ),
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
                            addLog("🚫 Order dibatalkan manual.");
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
                              "CLOSE / BATALKAN",
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

  Future<void> callUpgradeApi() async {
    if (selectedTargetRole == null) return;
    final url = Uri.parse("https://app.atlas-by-erlan.com/upRole?key=${widget.sessionKey}&uprole=${selectedTargetRole!.toLowerCase()}");
    addLog("📡 Memanggil API upgrade ke role: ${selectedTargetRole!.toUpperCase()}");
    try {
      final response = await http.get(url);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && (data["status"] == true || data["success"] == true)) {
        addLog("🎉 Upgrade role BERHASIL! Role baru: ${selectedTargetRole!.toUpperCase()}");
        _showSnackBar("🎉 Upgrade berhasil! Role Anda sekarang: ${selectedTargetRole!.toUpperCase()}", false);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context, true);
        });
      } else {
        addLog("❌ Gagal upgrade: ${data["message"] ?? "Unknown error"}");
        _showSnackBar("Upgrade gagal: ${data["message"] ?? "Silakan coba lagi"}", true);
      }
    } catch (e) {
      addLog("⚠️ Error upgrade: $e");
      _showSnackBar("Error upgrade: $e", true);
    }
  }

  Widget _buildCurrentRoleCard(ThemeProvider theme) {
    final currentIndex = roleOrder.indexOf(widget.role.toLowerCase());
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.stars_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "ROLE SAAT INI",
                      style: TextStyle(
                        color: theme.textSecondaryColor,
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.role.toUpperCase(),
                      style: TextStyle(
                        color: theme.textPrimaryColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
                ),
                child: Text(
                  "${currentIndex + 1}/${roleOrder.length}",
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (currentIndex + 1) / roleOrder.length,
              backgroundColor: theme.textPrimaryColor.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleOptions(ThemeProvider theme, List<String> availableRoles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.arrow_circle_up_rounded, color: theme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                "PILIH ROLE TUJUAN",
                style: TextStyle(
                  color: theme.textPrimaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Text(
                "${availableRoles.length} Tersedia",
                style: TextStyle(color: theme.textSecondaryColor, fontSize: 12),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: availableRoles.length,
            itemBuilder: (context, index) {
              final role = availableRoles[index];
              final price = getUpgradePrice(role);
              final isSelected = selectedTargetRole == role;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedTargetRole = role;
                    selectedPrice = price;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 150,
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [theme.primaryColor, theme.accentColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : LinearGradient(
                            colors: [theme.glassPrimary, theme.glassSecondary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? Colors.white.withOpacity(0.5)
                          : theme.textPrimaryColor.withOpacity(0.08),
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: theme.primaryColor.withOpacity(0.3),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        role == "reseller" ? Icons.storefront : Icons.handshake,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        role.toUpperCase(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : theme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (price != null)
                        Text(
                          NumberFormat.currency(
                            locale: 'id',
                            symbol: 'Rp ',
                            decimalDigits: 0,
                          ).format(price),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white.withOpacity(0.9) : theme.textSecondaryColor,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
            onTap: selectedTargetRole != null && selectedPrice != null && !isLoading
                ? createTopup
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryColor.withOpacity(0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "BAYAR VIA QRIS",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMaxRoleState(ThemeProvider theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
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
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.workspace_premium, color: Colors.white, size: 48),
          ),
          const SizedBox(height: 16),
          Text(
            "ROLE TERTINGGI",
            style: TextStyle(
              color: theme.textPrimaryColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Selamat! Anda sudah berada di tingkat role paling tinggi.",
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.textSecondaryColor, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildConsoleLog(ThemeProvider theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.textPrimaryColor.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: theme.glassSecondary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.terminal, color: theme.primaryColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  "CONSOLE LOGS",
                  style: TextStyle(
                    color: theme.textPrimaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.textPrimaryColor.withOpacity(0.08)),
          SizedBox(
            height: 120,
            child: consoleLogs.isEmpty
                ? Center(
                    child: Text(
                      "Belum ada aktivitas transaksi...",
                      style: TextStyle(color: theme.textSecondaryColor, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: consoleLogs.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        consoleLogs[index],
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final availableRoles = getAvailableUpgrades();

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
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
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
            "UPGRADE ROLE",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 1,
            ),
          ),
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
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildCurrentRoleCard(theme),
                  if (availableRoles.isNotEmpty)
                    _buildRoleOptions(theme, availableRoles)
                  else
                    _buildMaxRoleState(theme),
                  _buildConsoleLog(theme),
                  const SizedBox(height: 20),
                ],
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
