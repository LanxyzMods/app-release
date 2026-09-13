import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class HomePage extends StatefulWidget {
  final String username;
  final String password;
  final String sessionKey;
  final List<Map<String, dynamic>> listBug;
  final String role;
  final String expiredDate;

  const HomePage({
    super.key,
    required this.username,
    required this.password,
    required this.sessionKey,
    required this.listBug,
    required this.role,
    required this.expiredDate,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  // ── Controllers ──────────────────────────────────────────────
  final TextEditingController targetController = TextEditingController();
  final TextEditingController _senderInputController = TextEditingController();
  final TextEditingController _globalSenderNumberController = TextEditingController();
  final TextEditingController _globalMessageController = TextEditingController();

  // ── Animations ──────────────────────────────────────────────
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _floatController;
  late AnimationController _shimmerController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _floatAnimation;
  late Animation<double> _shimmerAnimation;

  // ── State ────────────────────────────────────────────────────
  String selectedBugId = "";
  String _selectedBugMode = "number";
  bool isSending = false;
  String? responseMessage;

  // Private Sender
  List<Map<String, dynamic>> _privateSenders = [];
  bool _isLoadingSenders = false;
  bool _isAddingSender = false;
  Timer? _senderPollingTimer;
  static const String baseUrl = "https://app.atlas-by-erlan.com";
  static const _pollingInterval = Duration(seconds: 10);

  // Global Sender
  bool _showGlobalSenderPanel = false;
  bool _isSendingGlobal = false;
  List<Map<String, dynamic>> _globalSenders = [];
  bool _isLoadingGlobalSenders = false;

  // Sender type selection
  String _selectedSenderType = 'private'; // 'private' atau 'global'

  // Getters
  bool get _isMember => widget.role.toLowerCase() == 'member';
  bool get _canSendBug => _privateSenders.isNotEmpty;
  bool get _isVip => widget.role.toLowerCase() == 'developer';

  // ─── Warna (dari AttackPage) ──────────────────────────────
  final Color _primaryColor = const Color(0xFF050810);
  final Color _secondaryColor = const Color(0xFF0D1421);
  final Color _accentColor = const Color(0xFF00D4FF);
  final Color _accentSoft = const Color(0xFF0099CC);
  final Color _successColor = const Color(0xFF00E5A0);
  final Color _warningColor = const Color(0xFFFFB547);
  final Color _dangerColor = const Color(0xFFFF4D6A);
  final Color _textPrimary = const Color(0xFFEEF2FF);
  final Color _textSecondary = const Color(0xFF8B9BBE);
  final Color _cardColor = const Color(0xFF0E1628);
  final Color _cardBorder = const Color(0xFF1E2D4A);

  // ─── Init ─────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initAnimations();
    if (widget.listBug.isNotEmpty) {
      selectedBugId = widget.listBug[0]['bug_id'];
    }
    _fetchSenders();
    _fetchGlobalSenders();
    _startPolling();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _floatAnimation = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _shimmerAnimation = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
  }

  void _startPolling() {
    _senderPollingTimer = Timer.periodic(_pollingInterval, (_) {
      if (mounted) {
        _fetchSendersSilent();
        _fetchGlobalSendersSilent();
      }
    });
  }

  // ─── Fungsi Sender (tetap dari HomePage asli) ──────────────
  Future<void> _fetchSendersSilent() async {
    try {
      final res = await http
          .get(Uri.parse("$baseUrl/mySender?key=${widget.sessionKey}"))
          .timeout(const Duration(seconds: 8));
      final data = jsonDecode(res.body);
      if (data["valid"] == true && mounted) {
        final newPrivate = List<Map<String, dynamic>>.from(data["privateConnections"] ?? []);
        if (_listChanged(_privateSenders, newPrivate)) {
          setState(() {
            _privateSenders = newPrivate;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchGlobalSendersSilent() async {
    if (!_isVip) return;
    try {
      final res = await http
          .get(Uri.parse("$baseUrl/mySender?key=${widget.sessionKey}"))
          .timeout(const Duration(seconds: 8));
      final data = jsonDecode(res.body);
      if (data["valid"] == true && mounted) {
        final newGlobal = List<Map<String, dynamic>>.from(data["globalConnections"] ?? []);
        if (_listChanged(_globalSenders, newGlobal)) {
          setState(() {
            _globalSenders = newGlobal;
          });
        }
      }
    } catch (_) {}
  }

  bool _listChanged(List<Map<String, dynamic>> oldList, List<Map<String, dynamic>> newList) {
    if (oldList.length != newList.length) return true;
    final oldIds = oldList.map((e) => e['id']?.toString() ?? '').toSet();
    final newIds = newList.map((e) => e['id']?.toString() ?? '').toSet();
    return !oldIds.containsAll(newIds) || !newIds.containsAll(oldIds);
  }

  Future<void> _fetchSenders() async {
    setState(() => _isLoadingSenders = true);
    try {
      final res = await http.get(Uri.parse("$baseUrl/mySender?key=${widget.sessionKey}"));
      final data = jsonDecode(res.body);
      if (data["valid"] == true) {
        setState(() {
          _privateSenders = List<Map<String, dynamic>>.from(data["privateConnections"] ?? []);
        });
      }
    } catch (_) {
      _showAlert("❌ Error", "Gagal memuat data private sender.");
    } finally {
      setState(() => _isLoadingSenders = false);
    }
  }

  Future<void> _fetchGlobalSenders() async {
    if (!_isVip) return;
    setState(() => _isLoadingGlobalSenders = true);
    try {
      final res = await http.get(Uri.parse("$baseUrl/mySender?key=${widget.sessionKey}"));
      final data = jsonDecode(res.body);
      if (data["valid"] == true) {
        setState(() {
          _globalSenders = List<Map<String, dynamic>>.from(data["globalConnections"] ?? []);
        });
      }
    } catch (_) {
      _showAlert("❌ Error", "Gagal memuat data global sender.");
    } finally {
      setState(() => _isLoadingGlobalSenders = false);
    }
  }

  Future<void> _addSender(String number) async {
    if (number.isEmpty) {
      _showAlert("❌ Error", "Nomor sender tidak boleh kosong.");
      return;
    }
    String formatted = number.trim();
    if (formatted.startsWith('0')) {
      formatted = '62${formatted.substring(1)}';
    } else if (formatted.startsWith('+')) {
      formatted = formatted.replaceAll('+', '');
    } else if (!formatted.startsWith('62')) {
      formatted = '62$formatted';
    }
    setState(() => _isAddingSender = true);
    try {
      final uri = Uri.parse("$baseUrl/getPairing?key=${widget.sessionKey}&number=$formatted&global=0");
      final res = await http.get(uri).timeout(const Duration(seconds: 30));
      final data = jsonDecode(res.body);
      if (data["valid"] == true && data["pairingCode"] != null) {
        _senderInputController.clear();
        if (mounted) {
          _showPairingDialog(
            number: formatted,
            pairingCode: data["pairingCode"].toString(),
          );
        }
      } else {
        final msg = data["message"] ?? data["error"] ?? "Gagal mendapatkan pairing code.";
        _showAlert("❌ Gagal", msg);
      }
    } on SocketException {
      _showAlert("❌ Error", "Tidak ada koneksi internet.");
    } catch (e) {
      _showAlert("❌ Error", "Terjadi kesalahan: $e");
    } finally {
      if (mounted) setState(() => _isAddingSender = false);
    }
  }

  void _showPairingDialog({required String number, required String pairingCode}) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final formatted = pairingCode.length == 8
        ? '${pairingCode.substring(0, 4)}-${pairingCode.substring(4)}'
        : pairingCode;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: theme.backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: theme.primaryColor.withOpacity(0.4), width: 1),
        ),
        title: Row(children: [
          Icon(FontAwesomeIcons.whatsapp, color: theme.primaryColor, size: 20),
          const SizedBox(width: 10),
          Text("Private Sender Pairing",
              style: TextStyle(color: theme.textPrimaryColor, fontFamily: 'Orbitron', fontSize: 14)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text("Masukkan kode ini di WhatsApp nomor:",
              style: TextStyle(color: theme.textSecondaryColor, fontFamily: 'ShareTechMono', fontSize: 12)),
          const SizedBox(height: 4),
          Text(number,
              style: TextStyle(color: theme.primaryColor, fontFamily: 'ShareTechMono', fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.primaryColor.withOpacity(0.4)),
            ),
            child: Text(formatted,
                style: TextStyle(color: theme.textPrimaryColor, fontFamily: 'Orbitron', fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 8)),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: theme.glassSecondary, borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _pairingStep("1", "Buka WhatsApp di HP nomor $number", theme),
              _pairingStep("2", "Ketuk ⋮ Menu → Perangkat Tertaut", theme),
              _pairingStep("3", "Ketuk \"Tautkan dengan nomor telepon\"", theme),
              _pairingStep("4", "Masukkan kode di atas", theme),
            ]),
          ),
          const SizedBox(height: 12),
          Text("Kode berlaku ±60 detik.",
              style: TextStyle(color: theme.textSecondaryColor, fontFamily: 'ShareTechMono', fontSize: 10),
              textAlign: TextAlign.center),
        ]),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _fetchSenders();
            },
            child: Text("Selesai", style: TextStyle(color: theme.primaryColor, fontFamily: 'Orbitron'))),
        ],
      ),
    );
  }

  Widget _pairingStep(String step, String text, ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.2), shape: BoxShape.circle),
          child: Text(step,
              style: TextStyle(color: theme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(color: theme.textSecondaryColor, fontFamily: 'ShareTechMono', fontSize: 11)),
        ),
      ]),
    );
  }

  Future<void> _deleteSender(String number) async {
    try {
      final res = await http.delete(
        Uri.parse("$baseUrl/deleteSender?key=${widget.sessionKey}&id=$number&scope=private"),
      );
      final data = jsonDecode(res.body);
      if (data["valid"] == true) {
        _showAlert("✅ Berhasil", "Private sender berhasil dihapus.");
        await _fetchSenders();
      } else {
        _showAlert("❌ Gagal", data["message"] ?? "Gagal menghapus sender.");
      }
    } catch (_) {
      _showAlert("❌ Error", "Terjadi kesalahan saat menghapus sender.");
    }
  }

  Future<void> _deleteGlobalSender(String number) async {
    try {
      final res = await http.delete(
        Uri.parse("$baseUrl/deleteSender?key=${widget.sessionKey}&id=$number&scope=global"),
      );
      final data = jsonDecode(res.body);
      if (data["valid"] == true) {
        _showAlert("✅ Berhasil", "Global sender berhasil dihapus.");
        await _fetchGlobalSenders();
      } else {
        _showAlert("❌ Gagal", data["message"] ?? "Gagal menghapus global sender.");
      }
    } catch (_) {
      _showAlert("❌ Error", "Terjadi kesalahan saat menghapus global sender.");
    }
  }

  void _showDeleteConfirmation(String number, {bool isGlobal = false}) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: theme.primaryColor.withOpacity(0.4), width: 1),
        ),
        title: Text("⚠️ Konfirmasi Hapus",
            style: TextStyle(color: theme.textPrimaryColor, fontFamily: 'Orbitron', fontSize: 15)),
        content: Text("Hapus ${isGlobal ? 'global' : 'private'} sender $number dari daftar?",
            style: TextStyle(color: theme.textSecondaryColor, fontFamily: 'ShareTechMono')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Batal", style: TextStyle(color: theme.textSecondaryColor))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (isGlobal) {
                _deleteGlobalSender(number);
              } else {
                _deleteSender(number);
              }
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  String? _formatPhoneNumber(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^\d+]'), '');
    if (!cleaned.startsWith('+') || cleaned.length < 8) return null;
    return cleaned;
  }

  bool isValidGroupLink(String input) {
    return input.contains('chat.whatsapp.com') && input.contains('https://');
  }

  // ─── Kirim Bug ──────────────────────────────────────────────
  Future<void> _sendBug() async {
    final rawInput = targetController.text.trim();
    final key = widget.sessionKey;

    if (_selectedBugMode == "number") {
      final target = _formatPhoneNumber(rawInput);
      if (target == null || key.isEmpty) {
        _showMessageDialog(
          "Invalid Number",
          "Use international format (e.g., +62, +1, +44)",
        );
        return;
      }
    } else {
      if (!isValidGroupLink(rawInput)) {
        _showMessageDialog(
          "Invalid Link",
          "Enter a valid WhatsApp group link",
        );
        return;
      }
    }

    if (_selectedSenderType == 'private' && !_canSendBug) {
      _showAlert("❌ No Private Sender", "Tambahkan private sender terlebih dahulu!");
      return;
    }
    if (_selectedSenderType == 'global' && _globalSenders.isEmpty) {
      _showAlert("❌ No Global Sender", "Belum ada global sender aktif. Hubungi developer!");
      return;
    }

    setState(() {
      isSending = true;
      responseMessage = null;
    });

    try {
      final res = await http.get(
        Uri.parse(
          "$baseUrl/sendBug?key=$key&target=$rawInput&bug=$selectedBugId&senderType=$_selectedSenderType",
        ),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(res.body);

      if (!mounted) return;

      if (data["cooldown"] == true) {
        final wait = data["wait"];
        setState(() => responseMessage = wait == null
            ? "⏳ Cooldown: Please wait a moment"
            : "⏳ Cooldown: Wait $wait seconds");
      } else if (data["valid"] == false) {
        setState(() => responseMessage = "❌ Invalid Session: Please login again");
      } else if (data["sended"] == false) {
        setState(() => responseMessage = "⚠️ ${data["message"] ?? "Failed to send bug"}");
      } else {
        setState(() => responseMessage = "✅ Attack sent successfully!");
        targetController.clear();
      }
    } catch (e) {
      if (mounted) {
        setState(() => responseMessage = "❌ Error: Connection failed");
      }
    } finally {
      if (mounted) {
        setState(() => isSending = false);
      }
    }
  }

  // ─── Kirim Pesan Global ─────────────────────────────────────
  Future<void> _sendGlobalMessage() async {
    final targetNumber = _globalSenderNumberController.text.trim();
    final message = _globalMessageController.text.trim();

    if (targetNumber.isEmpty) {
      _showAlert("❌ Error", "Masukkan nomor target!");
      return;
    }
    if (message.isEmpty) {
      _showAlert("❌ Error", "Masukkan pesan yang akan dikirim!");
      return;
    }

    final formattedTarget = _formatPhoneNumber(targetNumber);
    if (formattedTarget == null) {
      _showAlert("❌ Error", "Format nomor tidak valid! Gunakan format +62xxx");
      return;
    }

    setState(() => _isSendingGlobal = true);

    try {
      final res = await http.get(
        Uri.parse(
          "$baseUrl/sendMessageViaGlobal?key=${widget.sessionKey}&target=$formattedTarget&message=${Uri.encodeComponent(message)}",
        ),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(res.body);

      if (data["success"] == true) {
        _showAlert("✅ Berhasil", "Pesan berhasil dikirim ke $formattedTarget via Global Sender!");
        _globalMessageController.clear();
        _globalSenderNumberController.clear();
      } else {
        _showAlert("❌ Gagal", data["message"] ?? "Gagal mengirim pesan via Global Sender");
      }
    } catch (e) {
      _showAlert("❌ Error", "Terjadi kesalahan: $e");
    } finally {
      setState(() => _isSendingGlobal = false);
    }
  }

  // ─── Dialog / Alert ──────────────────────────────────────────
  void _showAlert(String title, String msg) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: theme.primaryColor.withOpacity(0.3), width: 1),
        ),
        title: Text(title, style: TextStyle(color: theme.textPrimaryColor, fontFamily: 'Orbitron')),
        content: Text(msg, style: TextStyle(color: theme.textSecondaryColor, fontFamily: 'ShareTechMono')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK", style: TextStyle(color: theme.primaryColor))),
        ],
      ),
    );
  }

  void _showMessageDialog(String title, String msg) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => Dialog(
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
              Text(title, style: TextStyle(color: theme.textPrimaryColor, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(msg, textAlign: TextAlign.center, style: TextStyle(color: theme.textSecondaryColor, fontSize: 14)),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(child: Text("OK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _senderPollingTimer?.cancel();
    _pulseController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _floatController.dispose();
    _shimmerController.dispose();
    targetController.dispose();
    _senderInputController.dispose();
    _globalSenderNumberController.dispose();
    _globalMessageController.dispose();
    super.dispose();
  }

  // ─── UI BUILDERS ─────────────────────────────────────────────
  Widget _buildHeaderPanel() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 248,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _accentColor.withOpacity(0.25),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _accentColor.withOpacity(0.08),
                  blurRadius: 30,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _accentColor.withOpacity(0.5),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _accentColor.withOpacity(0.25),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logo.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(Icons.person, color: _textPrimary, size: 40),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.username,
                              style: TextStyle(
                                fontFamily: 'Debrosee',
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.6,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.6),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [_accentColor, _accentSoft],
                              ).createShader(bounds),
                              child: Text(
                                widget.role.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _accentColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.timer_outlined, color: _accentColor, size: 12),
                            const SizedBox(width: 6),
                            Text(
                              widget.expiredDate,
                              style: TextStyle(
                                color: _textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(Icons.bug_report_rounded, "${widget.listBug.length}", "Total Bugs", _accentColor),
                            Container(width: 1, height: 36, color: Colors.white.withOpacity(0.1)),
                            _buildStatItem(Icons.bolt_rounded, "GACOR", "Success Rate", _successColor),
                            Container(width: 1, height: 36, color: Colors.white.withOpacity(0.1)),
                            _buildStatItem(Icons.verified_rounded, "ACTIVE", "Status", _successColor),
                          ],
                        ),
                      ),
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

  Widget _buildStatItem(dynamic icon, String value, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.12),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.15),
                blurRadius: 8,
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 7),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Debrosee',
            color: _textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: _textSecondary,
            fontSize: 9.5,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildInputPanel() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.07),
                  Colors.white.withOpacity(0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInputSection(
                  title: "NOMOR TARGET",
                  icon: Icons.phone_android_rounded,
                  iconColor: _accentColor,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _secondaryColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _cardBorder,
                      ),
                    ),
                    child: TextField(
                      controller: targetController,
                      keyboardType: _selectedBugMode == "number" ? TextInputType.phone : TextInputType.url,
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      cursorColor: _accentColor,
                      cursorHeight: 20,
                      decoration: InputDecoration(
                        hintText: _selectedBugMode == "number" ? "+62xxxxxxxxxx" : "https://chat.whatsapp.com/...",
                        hintStyle: TextStyle(
                          color: _textSecondary.withOpacity(0.5),
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          _selectedBugMode == "number"
                              ? Icons.phone_android_rounded
                              : Icons.link_rounded,
                          color: _textSecondary.withOpacity(0.5),
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                _buildInputSection(
                  title: "PILIH BUG",
                  icon: Icons.bug_report_rounded,
                  iconColor: _dangerColor,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 140,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: widget.listBug.length,
                          itemBuilder: (context, index) {
                            final bug = widget.listBug[index];
                            final isSelected = selectedBugId == bug['bug_id'];
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedBugId = bug['bug_id'];
                                });
                              },
                              child: AnimatedBuilder(
                                animation: Listenable.merge([_floatController, _shimmerController]),
                                builder: (context, child) {
                                  final floatOffset = isSelected ? _floatAnimation.value : 0.0;
                                  return Transform.translate(
                                    offset: Offset(0, floatOffset),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeOutCubic,
                                      width: 180,
                                      margin: EdgeInsets.only(
                                        right: index < widget.listBug.length - 1 ? 12 : 0,
                                        top: 6,
                                        bottom: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: isSelected
                                            ? LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  _accentColor.withOpacity(0.18),
                                                  _accentColor.withOpacity(0.06),
                                                  _accentSoft.withOpacity(0.12),
                                                ],
                                              )
                                            : LinearGradient(
                                                colors: [
                                                  _secondaryColor,
                                                  _secondaryColor.withOpacity(0.85),
                                                ],
                                              ),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: isSelected
                                              ? _accentColor.withOpacity(
                                                  0.4 + 0.3 * ((_shimmerAnimation.value.clamp(-1.0, 1.0) + 1) / 2))
                                              : _cardBorder,
                                          width: isSelected ? 1.8 : 1,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: _accentColor.withOpacity(
                                                      0.12 + 0.18 * ((_shimmerAnimation.value.clamp(-1.0, 1.0) + 1) / 2)),
                                                  blurRadius: 20 + 8 * ((_shimmerAnimation.value.clamp(-1.0, 1.0) + 1) / 2),
                                                  spreadRadius: 1,
                                                ),
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.3),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 6),
                                                ),
                                              ]
                                            : [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.2),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(18),
                                        child: Stack(
                                          children: [
                                            if (isSelected)
                                              Positioned.fill(
                                                child: IgnorePointer(
                                                  child: AnimatedBuilder(
                                                    animation: _shimmerController,
                                                    builder: (_, __) => Container(
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                          stops: [
                                                            (_shimmerAnimation.value - 0.5).clamp(0.0, 1.0),
                                                            _shimmerAnimation.value.clamp(0.0, 1.0),
                                                            (_shimmerAnimation.value + 0.5).clamp(0.0, 1.0),
                                                          ],
                                                          colors: [
                                                            Colors.transparent,
                                                            Colors.white.withOpacity(0.06),
                                                            Colors.transparent,
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      AnimatedContainer(
                                                        duration: const Duration(milliseconds: 300),
                                                        width: 34,
                                                        height: 34,
                                                        decoration: BoxDecoration(
                                                          shape: BoxShape.circle,
                                                          gradient: isSelected
                                                              ? LinearGradient(
                                                                  colors: [
                                                                    _accentColor.withOpacity(0.3),
                                                                    _accentColor.withOpacity(0.1),
                                                                  ],
                                                                )
                                                              : null,
                                                          color: isSelected ? null : Colors.white.withOpacity(0.06),
                                                          border: Border.all(
                                                            color: isSelected
                                                                ? _accentColor.withOpacity(0.6)
                                                                : Colors.transparent,
                                                            width: 1.2,
                                                          ),
                                                          boxShadow: isSelected
                                                              ? [
                                                                  BoxShadow(
                                                                    color: _accentColor.withOpacity(0.3),
                                                                    blurRadius: 8,
                                                                  ),
                                                                ]
                                                              : null,
                                                        ),
                                                        child: Icon(
                                                          Icons.security_rounded,
                                                          color: isSelected ? _accentColor : _textSecondary,
                                                          size: 16,
                                                        ),
                                                      ),
                                                      const Spacer(),
                                                      AnimatedSwitcher(
                                                        duration: const Duration(milliseconds: 300),
                                                        transitionBuilder: (child, animation) =>
                                                            ScaleTransition(scale: animation, child: child),
                                                        child: isSelected
                                                            ? Container(
                                                                key: const ValueKey('check'),
                                                                width: 22,
                                                                height: 22,
                                                                decoration: BoxDecoration(
                                                                  shape: BoxShape.circle,
                                                                  gradient: LinearGradient(
                                                                    colors: [_successColor, _successColor.withOpacity(0.7)],
                                                                  ),
                                                                  boxShadow: [
                                                                    BoxShadow(
                                                                      color: _successColor.withOpacity(0.45),
                                                                      blurRadius: 8,
                                                                      spreadRadius: 1,
                                                                    ),
                                                                  ],
                                                                ),
                                                                child: const Icon(
                                                                  Icons.check,
                                                                  size: 13,
                                                                  color: Colors.white,
                                                                ),
                                                              )
                                                            : const SizedBox.shrink(key: ValueKey('empty')),
                                                      ),
                                                    ],
                                                  ),
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        bug['bug_name'] ?? 'Unknown',
                                                        style: TextStyle(
                                                          color: isSelected ? _textPrimary : _textSecondary,
                                                          fontSize: 13.5,
                                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                                          letterSpacing: 0.2,
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: isSelected
                                                              ? _accentColor.withOpacity(0.1)
                                                              : Colors.black.withOpacity(0.3),
                                                          borderRadius: BorderRadius.circular(6),
                                                          border: Border.all(
                                                            color: isSelected
                                                                ? _accentColor.withOpacity(0.25)
                                                                : Colors.transparent,
                                                          ),
                                                        ),
                                                        child: Text(
                                                          bug['bug_id'] ?? 'ID',
                                                          style: TextStyle(
                                                            color: isSelected ? _accentColor : _textSecondary,
                                                            fontSize: 10.5,
                                                            fontFamily: 'RobotoMono',
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      if (widget.listBug.length > 1) ...[
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            widget.listBug.length,
                            (index) {
                              final bug = widget.listBug[index];
                              final isSelected = selectedBugId == bug['bug_id'];
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: isSelected ? 20 : 6,
                                height: 6,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? LinearGradient(
                                          colors: [_accentColor, _accentSoft],
                                        )
                                      : null,
                                  color: isSelected
                                      ? null
                                      : Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
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

  Widget _buildInputSection({
    required String title,
    required dynamic icon,
    required Widget child,
    Color? iconColor,
  }) {
    final color = iconColor ?? _accentColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.12),
                border: Border.all(
                  color: color.withOpacity(0.25),
                ),
              ),
              child: Icon(icon, color: color, size: 15),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Debrosee',
                color: _textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildSenderSelector() {
    if (!_isVip) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1E2D4A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00D4FF).withOpacity(0.12),
                border: Border.all(color: const Color(0xFF00D4FF).withOpacity(0.3)),
              ),
              child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF00D4FF), size: 14),
            ),
            const SizedBox(width: 8),
            const Text('PILIH SENDER', style: TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold,
              letterSpacing: 1.0, fontFamily: 'Debrosee')),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _globalSenders.isNotEmpty
                  ? const Color(0xFF00E5A0).withOpacity(0.12)
                  : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _globalSenders.isNotEmpty
                    ? const Color(0xFF00E5A0).withOpacity(0.4)
                    : Colors.red.withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 5, height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _globalSenders.isNotEmpty ? const Color(0xFF00E5A0) : Colors.red)),
                const SizedBox(width: 4),
                Text(
                  _globalSenders.isNotEmpty ? '${_globalSenders.length} sender online' : 'Global offline',
                  style: TextStyle(
                    color: _globalSenders.isNotEmpty ? const Color(0xFF00E5A0) : Colors.red,
                    fontSize: 10)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            // Private
            Expanded(child: GestureDetector(
              onTap: () => setState(() => _selectedSenderType = "private"),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: _selectedSenderType == "private"
                    ? const LinearGradient(
                        colors: [Color(0xFF00D4FF), Color(0xFF0099BB)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight)
                    : null,
                  color: _selectedSenderType == "private" ? null : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: _selectedSenderType == "private"
                      ? Colors.transparent : Colors.white.withOpacity(0.1)),
                  boxShadow: _selectedSenderType == "private" ? [
                    BoxShadow(color: const Color(0xFF00D4FF).withOpacity(0.3),
                      blurRadius: 12, offset: const Offset(0, 4))] : [],
                ),
                child: Column(children: [
                  Icon(Icons.person_rounded, size: 20,
                    color: _selectedSenderType == "private" ? Colors.white : Colors.white38),
                  const SizedBox(height: 4),
                  Text('Private', style: TextStyle(
                    color: _selectedSenderType == "private" ? Colors.white : Colors.white38,
                    fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('Bawaan akun',
                    style: TextStyle(
                      color: _selectedSenderType == "private" ? Colors.white70 : Colors.white24,
                      fontSize: 9)),
                ]),
              ),
            )),
            const SizedBox(width: 10),
            // Global
            Expanded(child: GestureDetector(
              onTap: () {
                setState(() => _selectedSenderType = "global");
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: _selectedSenderType == "global"
                    ? const LinearGradient(
                        colors: [Color(0xFF00E5A0), Color(0xFF06D6A0)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight)
                    : null,
                  color: _selectedSenderType == "global" ? null : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: _selectedSenderType == "global"
                      ? Colors.transparent : Colors.white.withOpacity(0.1)),
                  boxShadow: _selectedSenderType == "global" ? [
                    BoxShadow(color: const Color(0xFF00E5A0).withOpacity(0.3),
                      blurRadius: 12, offset: const Offset(0, 4))] : [],
                ),
                child: Column(children: [
                  Icon(Icons.public_rounded, size: 20,
                    color: _selectedSenderType == "global" ? Colors.white : Colors.white38),
                  const SizedBox(height: 4),
                  Text('Global', style: TextStyle(
                    color: _selectedSenderType == "global" ? Colors.white : Colors.white38,
                    fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(_globalSenders.isNotEmpty ? '${_globalSenders.length} sender' : 'Offline',
                    style: TextStyle(
                      color: _selectedSenderType == "global" ? Colors.white70 : Colors.white24,
                      fontSize: 9)),
                ]),
              ),
            )),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.info_outline_rounded, size: 11,
              color: Colors.white.withOpacity(0.35)),
            const SizedBox(width: 5),
            Flexible(child: Text(
              'Pilih sender yang akan digunakan untuk mengirim bug',
              style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10))),
          ]),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    final bool canSend = _selectedSenderType == 'private'
        ? _canSendBug
        : _globalSenders.isNotEmpty;
    final String btnLabel = _selectedSenderType == 'private'
        ? (!_canSendBug ? "TAMBAH PRIVATE SENDER DULU" : "SEND BUG ATTACK")
        : (_globalSenders.isEmpty ? "GLOBAL SENDER KOSONG" : "SEND BUG (GLOBAL)");
    return ScaleTransition(
      scale: _scaleAnimation,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: isSending ? null : _sendBug,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 56,
            decoration: BoxDecoration(
              gradient: isSending
                  ? LinearGradient(
                      colors: [
                        _accentColor.withOpacity(0.4),
                        _accentSoft.withOpacity(0.4),
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_accentColor, _accentSoft],
                    ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: isSending
                  ? []
                  : [
                      BoxShadow(
                        color: _accentColor.withOpacity(0.35),
                        blurRadius: 22,
                        spreadRadius: 0,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isSending
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "MENGIRIM...",
                            style: TextStyle(
                              fontFamily: 'Debrosee',
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _selectedSenderType == 'global'
                                ? Icons.public_rounded
                                : Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            btnLabel,
                            style: TextStyle(
                              fontFamily: 'Debrosee',
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
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

  Widget _buildPrivateSenderPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.07),
            Colors.white.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4, 
                height: 20, 
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_accentColor, _accentSoft]), 
                  borderRadius: BorderRadius.circular(2)
                )
              ),
              const SizedBox(width: 8),
              Text("PRIVATE SENDER (WHATSAPP)",
                  style: TextStyle(color: _textSecondary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _secondaryColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _cardBorder),
                  ),
                  child: TextField(
                    controller: _senderInputController,
                    style: TextStyle(color: _textPrimary),
                    decoration: InputDecoration(
                      hintText: "Nomor WhatsApp (628xxxx)",
                      hintStyle: TextStyle(color: _textSecondary.withOpacity(0.5)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_accentColor, _accentSoft]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: _accentColor.withOpacity(0.3), blurRadius: 8)],
                ),
                child: ElevatedButton(
                  onPressed: _isAddingSender ? null : () => _addSender(_senderInputController.text.trim()),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                  child: _isAddingSender
                      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(Icons.add, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingSenders)
            Center(child: CircularProgressIndicator(color: _accentColor))
          else if (_privateSenders.isEmpty)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _secondaryColor, borderRadius: BorderRadius.circular(16)),
                child: Text("Belum ada private sender yang terdaftar!..", style: TextStyle(color: _textSecondary, fontSize: 12)),
              ),
            )
          else
            ..._privateSenders.map((sender) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _secondaryColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          sender['sessionName'] ?? sender['id'] ?? 'Unknown',
                          style: TextStyle(color: _textPrimary),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showDeleteConfirmation(sender['sessionName'] ?? sender['id'] ?? ''),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _accentColor.withOpacity(0.2)),
                          ),
                          child: Icon(Icons.delete_outline, color: _accentColor, size: 18),
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildGlobalSenderPanel() {
    if (!_showGlobalSenderPanel) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {
            if (!_isVip) {
              _showAlert("❌ Akses Ditolak", "Global sender hanya untuk role VIP!");
              return;
            }
            setState(() => _showGlobalSenderPanel = true);
            _fetchGlobalSenders();
          },
          icon: Icon(FontAwesomeIcons.globe, color: _textSecondary, size: 15),
          label: Text(
            "OPEN GLOBAL SENDER",
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'Orbitron',
              color: _isVip ? _textSecondary : _textSecondary.withOpacity(0.5),
              fontWeight: FontWeight.bold,
            ),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: BorderSide(color: _textSecondary.withOpacity(_isVip ? 0.2 : 0.1)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.07),
            Colors.white.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 4, 
              height: 20, 
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_accentColor, _accentSoft]), 
                borderRadius: BorderRadius.circular(2)
              )
            ),
            const SizedBox(width: 8),
            Text("GLOBAL SENDER (WHATSAPP)", style: TextStyle(color: _textSecondary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.close, color: _textSecondary, size: 18),
              onPressed: () => setState(() => _showGlobalSenderPanel = false),
              padding: EdgeInsets.zero,
            ),
          ]),
          const SizedBox(height: 12),
          if (_isLoadingGlobalSenders)
            Center(child: CircularProgressIndicator(color: _accentColor))
          else if (_globalSenders.isEmpty)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _secondaryColor, borderRadius: BorderRadius.circular(16)),
                child: Text("Belum ada global sender terdaftar", style: TextStyle(color: _textSecondary, fontSize: 12)),
              ),
            )
          else
            ..._globalSenders.map((sender) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _secondaryColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          sender['sessionName'] ?? sender['id'] ?? 'Unknown',
                          style: TextStyle(color: _textPrimary),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showDeleteConfirmation(sender['sessionName'] ?? sender['id'] ?? '', isGlobal: true),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _accentColor.withOpacity(0.2)),
                          ),
                          child: Icon(Icons.delete_outline, color: _accentColor, size: 18),
                        ),
                      ),
                    ],
                  ),
                )),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          Text("KIRIM PESAN VIA GLOBAL SENDER",
              style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: _secondaryColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _cardBorder),
            ),
            child: TextField(
              controller: _globalSenderNumberController,
              style: TextStyle(color: _textPrimary),
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: "Nomor Target (+62xxxxxxxxxx)",
                hintStyle: TextStyle(color: _textSecondary.withOpacity(0.5)),
                prefixIcon: Icon(Icons.phone, color: _accentColor, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: _secondaryColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _cardBorder),
            ),
            child: TextField(
              controller: _globalMessageController,
              style: TextStyle(color: _textPrimary),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Pesan yang akan dikirim",
                hintStyle: TextStyle(color: _textSecondary.withOpacity(0.5)),
                prefixIcon: Icon(Icons.message, color: _accentColor, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _isSendingGlobal ? null : _sendGlobalMessage,
              icon: _isSendingGlobal
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(FontAwesomeIcons.paperPlane, color: Colors.white, size: 14),
              label: Text(_isSendingGlobal ? "SENDING..." : "KIRIM PESAN",
                  style: const TextStyle(fontSize: 12, fontFamily: 'Orbitron', fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.withOpacity(0.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.green.withOpacity(0.4))),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _accentColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: _accentColor, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Global sender hanya bisa digunakan oleh role VIP",
                    style: TextStyle(color: _accentColor.withOpacity(0.8), fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── MAIN BUILD ──────────────────────────────────────────────
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
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Title
                  SlideTransition(
                    position: _slideAnimation,
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: _accentColor.withOpacity(0.1),
                            border: Border.all(
                              color: _accentColor.withOpacity(0.3),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _accentColor.withOpacity(0.1),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.security_rounded,
                            color: _accentColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [_textPrimary, _accentColor],
                            stops: const [0.4, 1.0],
                          ).createShader(bounds),
                          child: Text(
                            "ATLAS",
                            style: TextStyle(
                              fontFamily: 'Debrosee',
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _accentColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _accentColor.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            "v1.0",
                            style: TextStyle(
                              color: _accentColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _buildHeaderPanel(),
                  const SizedBox(height: 20),
                  _buildInputPanel(),
                  const SizedBox(height: 20),
                  _buildPrivateSenderPanel(),
                  const SizedBox(height: 16),
                  _buildGlobalSenderPanel(),
                  const SizedBox(height: 16),
                  _buildSenderSelector(),
                  _buildSendButton(),
                  const SizedBox(height: 18),
                  if (responseMessage != null)
                    SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: responseMessage!.contains('✅')
                              ? _successColor.withOpacity(0.08)
                              : _dangerColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: responseMessage!.contains('✅')
                                ? _successColor.withOpacity(0.25)
                                : _dangerColor.withOpacity(0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: responseMessage!.contains('✅')
                                    ? _successColor
                                    : _dangerColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: responseMessage!.contains('✅')
                                        ? _successColor.withOpacity(0.4)
                                        : _dangerColor.withOpacity(0.4),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Icon(
                                responseMessage!.contains('✅')
                                    ? Icons.check
                                    : Icons.close,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                responseMessage!,
                                style: TextStyle(
                                  color: _textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              color: _textSecondary,
                              onPressed: () {
                                setState(() {
                                  responseMessage = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Center(
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [
                              _textSecondary.withOpacity(0.6),
                              _accentColor.withOpacity(0.6),
                            ],
                          ).createShader(bounds),
                          child: const Text(
                            "ATLAS TEAM",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "© 2026 ATLAS Always For You",
                          style: TextStyle(
                            color: _textSecondary.withOpacity(0.3),
                            fontSize: 10,
                            letterSpacing: 0.5,
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
    );
  }
}

// Custom Grid Painter for background
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
