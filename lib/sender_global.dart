import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class GlobalSenderPage extends StatefulWidget {
  final String sessionKey;
  const GlobalSenderPage({super.key, required this.sessionKey});

  @override
  State<GlobalSenderPage> createState() => _GlobalSenderPageState();
}

class _GlobalSenderPageState extends State<GlobalSenderPage>
    with TickerProviderStateMixin {
  static const String baseUrl = "https://app.atlas-by-erlan.com";

  // State
  List<Map<String, dynamic>> _globalSessions = [];
  bool _isLoading = false;
  String? _errorMsg;

  // Pairing
  final TextEditingController _pairingNumberCtrl = TextEditingController();
  bool _isPairing = false;
  String? _pairingCode;
  String? _pairingStatus;
  Timer? _pairingTimer;
  int _pairingCountdown = 60;
  Timer? _countdownTimer;

  // Delete
  String? _deletingSession;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _fetchGlobalSessions();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _pairingNumberCtrl.dispose();
    _pairingTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ─── FETCH ───────────────────────────────────────────────
  Future<void> _fetchGlobalSessions() async {
    setState(() => _isLoading = true);
    try {
      final res = await http
          .get(Uri.parse("$baseUrl/mySender?key=${widget.sessionKey}"))
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);
      if (data["valid"] == true) {
        setState(() {
          _globalSessions = List<Map<String, dynamic>>.from(
              data["globalConnections"] ?? []);
          _errorMsg = null;
        });
      } else {
        setState(() => _errorMsg = "Gagal memuat global sender.");
      }
    } catch (e) {
      setState(() => _errorMsg = "Koneksi gagal: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ─── PAIRING ─────────────────────────────────────────────
  Future<void> _startPairing() async {
    final number = _pairingNumberCtrl.text.trim().replaceAll(RegExp(r'\D'), '');
    if (number.isEmpty) {
      _showSnack("Masukkan nomor WA dulu!", isError: true);
      return;
    }
    if (number.length < 10 || number.length > 15) {
      _showSnack("Nomor tidak valid! Contoh: 6281234567890", isError: true);
      return;
    }

    setState(() {
      _isPairing = true;
      _pairingCode = null;
      _pairingStatus = "Meminta pairing code...";
      _pairingCountdown = 60;
    });

    try {
      final res = await http.post(
        Uri.parse("$baseUrl/pairingGlobal"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "key": widget.sessionKey,
          "number": number,
        }),
      ).timeout(const Duration(seconds: 20));

      final data = jsonDecode(res.body);

      if (data["valid"] == true || data["pairingCode"] != null) {
        final code = data["pairingCode"]?.toString() ?? "";
        setState(() {
          _pairingCode = code;
          _pairingStatus = "Pairing code berhasil didapat!";
        });
        // Countdown & polling status
        _startPairingCountdown(number);
      } else {
        setState(() {
          _isPairing = false;
          _pairingStatus = data["message"] ?? "Gagal mendapat pairing code.";
        });
        _showSnack(_pairingStatus!, isError: true);
      }
    } catch (e) {
      setState(() {
        _isPairing = false;
        _pairingStatus = "Error: $e";
      });
      _showSnack("Koneksi gagal!", isError: true);
    }
  }

  void _startPairingCountdown(String number) {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _pairingCountdown--);
      if (_pairingCountdown <= 0) {
        t.cancel();
        _checkPairingStatus(number);
      }
    });
  }

  Future<void> _checkPairingStatus(String number) async {
    try {
      final res = await http
          .get(Uri.parse("$baseUrl/mySender?key=${widget.sessionKey}"))
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);
      if (data["valid"] == true) {
        final globals = List<Map<String, dynamic>>.from(
            data["globalConnections"] ?? []);
        final connected = globals.any((s) =>
            (s["number"]?.toString() ?? "").contains(number) ||
            (s["id"]?.toString() ?? "").contains(number));

        if (connected) {
          setState(() {
            _isPairing = false;
            _pairingCode = null;
            _pairingStatus = "✅ Sender berhasil terhubung!";
            _globalSessions = globals;
          });
          _showSnack("Global sender berhasil ditambahkan!", isError: false);
          _pairingNumberCtrl.clear();
        } else {
          setState(() {
            _isPairing = false;
            _pairingStatus = "⚠️ Pairing belum selesai. Coba lagi.";
          });
          _showSnack("Pairing belum terdeteksi, coba ulangi.", isError: true);
        }
      }
    } catch (_) {
      setState(() {
        _isPairing = false;
        _pairingStatus = "Gagal cek status.";
      });
    }
    await _fetchGlobalSessions();
  }

  // ─── DELETE ──────────────────────────────────────────────
  Future<void> _deleteSession(String sessionName) async {
    setState(() => _deletingSession = sessionName);
    try {
      final res = await http.delete(
        Uri.parse("$baseUrl/removeGlobalSender"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "key": widget.sessionKey,
          "sessionName": sessionName,
        }),
      ).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);
      if (data["valid"] == true) {
        _showSnack("Sender dihapus!", isError: false);
        await _fetchGlobalSessions();
      } else {
        _showSnack(data["error"] ?? "Gagal hapus sender.", isError: true);
      }
    } catch (e) {
      _showSnack("Error: $e", isError: true);
    } finally {
      setState(() => _deletingSession = null);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  // ─── BUILD ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.primaryColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'GLOBAL SENDER',
          style: TextStyle(
            color: theme.primaryColor,
            fontFamily: 'Orbitron',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: theme.primaryColor),
            onPressed: _fetchGlobalSessions,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: theme.primaryColor,
        onRefresh: _fetchGlobalSessions,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info card
              _buildInfoCard(theme),
              const SizedBox(height: 20),

              // Pairing section
              _buildPairingSection(theme),
              const SizedBox(height: 20),

              // List global senders
              _buildSenderList(theme),
            ],
          ),
        ),
      ),
    );
  }

  // ─── INFO CARD ────────────────────────────────────────────
  Widget _buildInfoCard(ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.public_rounded, color: theme.primaryColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Global Sender',
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sender yang bisa dipakai semua user VIP untuk ngebug. Pairing WA ke slot global di sini.',
                  style: TextStyle(color: theme.textSecondaryColor, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── PAIRING SECTION ─────────────────────────────────────
  Widget _buildPairingSection(ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.add_link_rounded, color: theme.primaryColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'TAMBAH SENDER BARU',
                style: TextStyle(
                  color: theme.primaryColor,
                  fontFamily: 'Orbitron',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Input nomor
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
            ),
            child: TextField(
              controller: _pairingNumberCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              enabled: !_isPairing,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Nomor WA (contoh: 6281234567890)',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: Icon(Icons.phone_android_rounded, color: theme.primaryColor, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Tombol pair
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isPairing ? null : _startPairing,
              icon: _isPairing
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.qr_code_rounded, size: 18),
              label: Text(_isPairing ? 'Menghubungkan...' : 'Dapatkan Pairing Code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),

          // Pairing code box
          if (_pairingCode != null && _isPairing) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.primaryColor.withOpacity(0.4)),
              ),
              child: Column(
                children: [
                  Text(
                    'PAIRING CODE',
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _pairingCode!));
                      _showSnack("Kode disalin!", isError: false);
                    },
                    child: AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, child) => Opacity(opacity: _pulseAnim.value, child: child),
                      child: Text(
                        _pairingCode!,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 6,
                          fontFamily: 'Orbitron',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Buka WA → Perangkat Tertaut → Tautkan Perangkat → Masukkan kode',
                    style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _pairingCountdown / 60,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sisa waktu: ${_pairingCountdown}s',
                    style: TextStyle(color: theme.textSecondaryColor, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],

          // Status message
          if (_pairingStatus != null && _pairingCode == null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Icon(
                    _pairingStatus!.startsWith('✅') ? Icons.check_circle : Icons.info_outline,
                    color: _pairingStatus!.startsWith('✅') ? Colors.green : theme.primaryColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _pairingStatus!,
                      style: TextStyle(color: theme.textSecondaryColor, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── SENDER LIST ─────────────────────────────────────────
  Widget _buildSenderList(ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.sensors_rounded, color: theme.primaryColor, size: 18),
            const SizedBox(width: 8),
            Text(
              'GLOBAL SENDER AKTIF',
              style: TextStyle(
                color: theme.primaryColor,
                fontFamily: 'Orbitron',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_globalSessions.length} sender',
                style: TextStyle(color: theme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_isLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: CircularProgressIndicator(color: theme.primaryColor, strokeWidth: 2),
            ),
          )
        else if (_errorMsg != null)
          _buildEmptyState(theme, _errorMsg!, isError: true)
        else if (_globalSessions.isEmpty)
          _buildEmptyState(theme, 'Belum ada global sender.\nTambahkan sender baru di atas.', isError: false)
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _globalSessions.length,
            itemBuilder: (context, index) {
              final sender = _globalSessions[index];
              final name = sender["id"]?.toString() ?? sender["number"]?.toString() ?? "Sender ${index + 1}";
              final isActive = sender["connected"] == true || sender["status"] == "connected";
              final isDeleting = _deletingSession == name;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isActive ? theme.primaryColor.withOpacity(0.4) : Colors.white12,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isActive
                            ? theme.primaryColor.withOpacity(0.15)
                            : Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.phone_android_rounded,
                        color: isActive ? theme.primaryColor : Colors.white38,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isActive ? Colors.green : Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isActive ? 'Terhubung' : 'Terputus',
                                style: TextStyle(
                                  color: isActive ? Colors.green : Colors.red,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.primaryColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'GLOBAL',
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
                        ],
                      ),
                    ),
                    // Delete button
                    isDeleting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.red,
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                            onPressed: () => _confirmDelete(context, name, theme),
                            tooltip: 'Hapus sender',
                          ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, String name, ThemeProvider theme) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F3F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Sender?', style: TextStyle(color: theme.primaryColor, fontSize: 16)),
        content: Text(
          'Sender "$name" akan dihapus dari slot global.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSession(name);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeProvider theme, String msg, {required bool isError}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.sensors_off_rounded,
            color: isError ? Colors.red : Colors.white24,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            msg,
            style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
          if (isError) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchGlobalSessions,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
