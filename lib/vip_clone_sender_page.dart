import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class VipCloneSenderPage extends StatefulWidget {
  final String sessionKey;
  const VipCloneSenderPage({super.key, required this.sessionKey});

  @override
  State<VipCloneSenderPage> createState() => _VipCloneSenderPageState();
}

class _VipCloneSenderPageState extends State<VipCloneSenderPage>
    with TickerProviderStateMixin {
  static const String baseUrl = 'https://app.atlas-by-erlan.com';

  List<Map<String, dynamic>> _senders = [];
  bool _isLoading = false;
  String? _errorMsg;
  final Set<String> _cloningIds = {};

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _fetchSenders();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchSenders() async {
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/scanSenders?key=${widget.sessionKey}'))
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      if (data['valid'] == true) {
        setState(() {
          _senders = List<Map<String, dynamic>>.from(data['senders'] ?? []);
        });
      } else {
        setState(() => _errorMsg = data['message'] ?? 'Gagal memuat data.');
      }
    } catch (e) {
      setState(() => _errorMsg = 'Koneksi gagal: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cloneSender(Map<String, dynamic> sender) async {
    final uid = '${sender['ownerUsername']}_${sender['sessionName']}';
    setState(() => _cloningIds.add(uid));

    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/cloneSender'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'key': widget.sessionKey,
              'sessionName': sender['sessionName'],
              'ownerUsername': sender['ownerUsername'],
            }),
          )
          .timeout(const Duration(seconds: 20));

      final data = jsonDecode(res.body);
      if (!mounted) return;

      if (data['valid'] == true) {
        _showSnack('✅ ${data['message']}', isError: false);
        // Update UI - tandai sudah di-clone
        setState(() {
          final idx = _senders.indexWhere((s) =>
              s['sessionName'] == sender['sessionName'] &&
              s['ownerUsername'] == sender['ownerUsername']);
          if (idx != -1) _senders[idx]['alreadyCloned'] = true;
        });
      } else {
        _showSnack('❌ ${data['message'] ?? 'Gagal clone sender.'}');
      }
    } catch (e) {
      if (mounted) _showSnack('❌ Koneksi gagal: $e');
    } finally {
      if (mounted) setState(() => _cloningIds.remove(uid));
    }
  }

  void _showSnack(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'developer': return const Color(0xFFFFD700);
      case 'partner': return const Color(0xFFFF6B81);
      case 'reseller': return const Color(0xFF70A1FF);
      default: return const Color(0xFF57606F);
    }
  }

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
          'SCAN SENDER',
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
            onPressed: _fetchSenders,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: theme.primaryColor,
        onRefresh: _fetchSenders,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Info Card ────────────────────────────────────────────
              _buildInfoCard(theme),
              const SizedBox(height: 20),

              // ── Content ──────────────────────────────────────────────
              if (_isLoading)
                _buildLoadingState(theme)
              else if (_errorMsg != null)
                _buildErrorState(theme)
              else if (_senders.isEmpty)
                _buildEmptyState(theme)
              else
                _buildSenderList(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(ThemeProvider theme) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: theme.primaryColor.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.primaryColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.radar_rounded, color: theme.primaryColor, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('VIP Sender Scanner',
          style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Orbitron')),
        const SizedBox(height: 3),
        Text(
          'Scan sender aktif dari semua akun. Klik Tambah untuk clone ke private sender kamu.',
          style: TextStyle(color: theme.textSecondaryColor, fontSize: 11, height: 1.4),
        ),
      ])),
    ]),
  );

  Widget _buildLoadingState(ThemeProvider theme) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Transform.scale(
            scale: _pulseAnim.value,
            child: Icon(Icons.radar_rounded, color: theme.primaryColor, size: 48),
          ),
        ),
        const SizedBox(height: 16),
        Text('Scanning sender aktif...',
          style: TextStyle(color: theme.primaryColor, fontFamily: 'Orbitron', fontSize: 12, letterSpacing: 1)),
      ]),
    ),
  );

  Widget _buildErrorState(ThemeProvider theme) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.red.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.red.withOpacity(0.3)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(_errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 12))),
    ]),
  );

  Widget _buildEmptyState(ThemeProvider theme) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.wifi_off_rounded, color: theme.primaryColor.withOpacity(0.4), size: 48),
        const SizedBox(height: 12),
        Text('Tidak ada sender aktif ditemukan',
          style: TextStyle(color: theme.textSecondaryColor, fontSize: 13)),
        const SizedBox(height: 6),
        Text('Refresh untuk scan ulang',
          style: TextStyle(color: theme.textSecondaryColor.withOpacity(0.5), fontSize: 11)),
      ]),
    ),
  );

  Widget _buildSenderList(ThemeProvider theme) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Icon(Icons.sensors_rounded, color: theme.primaryColor, size: 16),
        const SizedBox(width: 6),
        Text(
          '${_senders.length} SENDER DITEMUKAN',
          style: TextStyle(
            color: theme.primaryColor,
            fontFamily: 'Orbitron',
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ]),
      const SizedBox(height: 12),
      ..._senders.map((sender) => _buildSenderCard(sender, theme)),
    ],
  );

  Widget _buildSenderCard(Map<String, dynamic> sender, ThemeProvider theme) {
    final uid = '${sender['ownerUsername']}_${sender['sessionName']}';
    final isCloning = _cloningIds.contains(uid);
    final alreadyCloned = sender['alreadyCloned'] == true;
    final roleColor = _roleColor(sender['ownerRole'] ?? 'member');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alreadyCloned
              ? Colors.green.withOpacity(0.4)
              : theme.primaryColor.withOpacity(0.2),
        ),
      ),
      child: Row(children: [
        // Icon sender
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: theme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            alreadyCloned ? Icons.check_circle_rounded : Icons.phone_android_rounded,
            color: alreadyCloned ? Colors.green : theme.primaryColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),

        // Info
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            sender['sessionName'] ?? '-',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              fontFamily: 'Orbitron',
            ),
          ),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.person_rounded, size: 11, color: Colors.white38),
            const SizedBox(width: 3),
            Text(
              sender['ownerUsername'] ?? '-',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: roleColor.withOpacity(0.4)),
              ),
              child: Text(
                (sender['ownerRole'] ?? 'member').toUpperCase(),
                style: TextStyle(color: roleColor, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8),
              ),
            ),
          ]),
          if (alreadyCloned) ...[
            const SizedBox(height: 4),
            Text('✓ Sudah di-clone ke private sender',
              style: TextStyle(color: Colors.green.shade400, fontSize: 10)),
          ],
        ])),

        // Tombol Clone
        if (alreadyCloned)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: const Text('Cloned',
              style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
          )
        else if (isCloning)
          SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryColor),
          )
        else
          GestureDetector(
            onTap: () => _showConfirmDialog(sender, theme),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.primaryColor.withOpacity(0.5)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, color: theme.primaryColor, size: 14),
                const SizedBox(width: 4),
                Text('Tambah',
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  )),
              ]),
            ),
          ),
      ]),
    );
  }

  void _showConfirmDialog(Map<String, dynamic> sender, ThemeProvider theme) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(children: [
          Icon(Icons.copy_all_rounded, color: theme.primaryColor, size: 20),
          const SizedBox(width: 8),
          Text('Clone Sender',
            style: TextStyle(color: theme.primaryColor, fontSize: 14, fontFamily: 'Orbitron', fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Clone sender ini ke private sender kamu?',
            style: TextStyle(color: theme.textSecondaryColor, fontSize: 13)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _infoRow('Sender', sender['sessionName'] ?? '-', theme),
              const SizedBox(height: 4),
              _infoRow('Dari akun', sender['ownerUsername'] ?? '-', theme),
              const SizedBox(height: 4),
              _infoRow('Role', (sender['ownerRole'] ?? 'member').toUpperCase(), theme),
            ]),
          ),
          const SizedBox(height: 10),
          Text(
            '⚠️ Sender asli tidak akan terhapus. Clone akan aktif di private sender kamu dan bisa dipakai untuk bug.',
            style: TextStyle(color: Colors.orange.shade300, fontSize: 10, height: 1.4),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: TextStyle(color: theme.textSecondaryColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _cloneSender(sender);
            },
            child: const Text('Clone', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String val, ThemeProvider theme) => Row(
    children: [
      Text('$label: ', style: TextStyle(color: theme.textSecondaryColor, fontSize: 11)),
      Text(val, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    ],
  );
}