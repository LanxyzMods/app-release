import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class UcapanPage extends StatefulWidget {
  final String? sessionKey;
  final String? username;
  final String? role;

  const UcapanPage({super.key, this.sessionKey, this.username, this.role});

  @override
  State<UcapanPage> createState() => _UcapanPageState();
}

class _UcapanPageState extends State<UcapanPage> {
  List<UcapanModel> _ucapanList = [];
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _pesanController = TextEditingController();
  bool _isLoading = true;
  String? _sessionKey;
  String? _username;
  String? _role;

  // Kata-kata kasar (filter client side juga)
  final List<String> _forbiddenWords = [
    'anjing', 'bangsat', 'kontol', 'memek', 'ngentot', 'jembut', 'peler',
    'toket', 'goblok', 'tolol', 'babi', 'asu', 'sialan', 'brengsek',
    'kampret', 'bajingan', 'tai', 'ampas'
  ];

  String _filterText(String text) {
    String filtered = text;
    for (String word in _forbiddenWords) {
      if (filtered.toLowerCase().contains(word.toLowerCase())) {
        filtered = filtered.replaceAll(RegExp(word, caseSensitive: false), '****');
      }
    }
    return filtered;
  }

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionKey = widget.sessionKey ?? prefs.getString('sessionKey') ?? '';
    _username = widget.username ?? prefs.getString('username') ?? '';
    _role = widget.role ?? prefs.getString('role') ?? 'member';

    _namaController.text = _username ?? '';
    await _loadUcapan();
  }

  Future<void> _loadUcapan() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('https://app.atlas-by-erlan.com/getUcapan?key=$_sessionKey'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['valid'] == true) {
          setState(() {
            _ucapanList = (data['ucapan'] as List)
                .map((item) => UcapanModel.fromJson(item))
                .toList();
          });
        }
      }
    } catch (e) {
      print('Error loading ucapan: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _tambahUcapan() async {
    final nama = _namaController.text.trim();
    final pesan = _pesanController.text.trim();

    if (nama.isEmpty || pesan.isEmpty) {
      _showSnackBar('Nama dan pesan tidak boleh kosong', isError: true);
      return;
    }

    if (pesan.length > 500) {
      _showSnackBar('Pesan maksimal 500 karakter', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('https://app.atlas-by-erlan.com/addUcapan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'key': _sessionKey,
          'nama': _filterText(nama),
          'pesan': _filterText(pesan),
        }),
      );

      final data = jsonDecode(response.body);
      if (data['valid'] == true) {
        _pesanController.clear();
        await _loadUcapan();

        if (mounted) {
          _showSnackBar('✅ Ucapan berhasil dikirim!', isError: false);
        }
      } else {
        _showSnackBar(data['message'] ?? 'Gagal mengirim ucapan', isError: true);
      }
    } catch (e) {
      print('Error: $e');
      _showSnackBar('Gagal mengirim ucapan', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _likeUcapan(String id, String type) async {
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('https://app.atlas-by-erlan.com/likeUcapan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'key': _sessionKey,
          'id': id,
          'type': type,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['valid'] == true) {
          setState(() {
            final index = _ucapanList.indexWhere((u) => u.id == id);
            if (index != -1) {
              _ucapanList[index] = UcapanModel(
                id: _ucapanList[index].id,
                nama: _ucapanList[index].nama,
                pesan: _ucapanList[index].pesan,
                waktu: _ucapanList[index].waktu,
                likes: data['likes'],
                dislikes: data['dislikes'],
              );
            }
          });

          String message = '';
          if (data['action'] == 'liked') message = 'Berhasil like';
          else if (data['action'] == 'unliked') message = 'Batal like';
          else if (data['action'] == 'disliked') message = 'Berhasil dislike';
          else if (data['action'] == 'undisliked') message = 'Batal dislike';

          _showSnackBar(message, isError: false);
        }
      }
    } catch (e) {
      print('Error like: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteUcapan(String id) async {
    if (_role != 'developer') return;

    final theme = Provider.of<ThemeProvider>(context, listen: false);
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: TweenAnimationBuilder(
          duration: const Duration(milliseconds: 300),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, double scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
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
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 32),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Hapus Ucapan",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Yakin ingin menghapus ucapan ini?",
                  style: TextStyle(color: theme.textSecondaryColor, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Center(
                            child: Text(
                              "BATAL",
                              style: TextStyle(color: theme.textSecondaryColor, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: const Center(
                            child: Text(
                              "HAPUS",
                              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.delete(
        Uri.parse('https://app.atlas-by-erlan.com/deleteUcapan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'key': _sessionKey,
          'id': id,
        }),
      );

      final data = jsonDecode(response.body);
      if (data['valid'] == true) {
        await _loadUcapan();
        _showSnackBar('Ucapan berhasil dihapus', isError: false);
      }
    } catch (e) {
      print('Error delete: $e');
    }
  }

  String _formatWaktu(String isoString) {
    try {
      final waktu = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(waktu);

      if (diff.inMinutes < 1) return 'baru saja';
      if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';
      if (diff.inDays < 1) return '${diff.inHours} jam lalu';
      if (diff.inDays < 7) return '${diff.inDays} hari lalu';
      return '${diff.inDays ~/ 7} minggu lalu';
    } catch (e) {
      return 'baru saja';
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
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
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showTambahUcapanDialog() {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: TweenAnimationBuilder(
          duration: const Duration(milliseconds: 300),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, double scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
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
                  child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Kirim Ucapan",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Kirim ucapan spesial untuk aplikasi",
                  style: TextStyle(color: theme.textSecondaryColor, fontSize: 13),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: theme.glassSecondary,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.textPrimaryColor.withOpacity(0.1)),
                  ),
                  child: TextField(
                    controller: _namaController,
                    style: TextStyle(color: theme.textPrimaryColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "Nama Anda",
                      hintStyle: TextStyle(color: theme.textSecondaryColor.withOpacity(0.5)),
                      prefixIcon: Icon(Icons.person, color: theme.primaryColor, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: theme.glassSecondary,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.textPrimaryColor.withOpacity(0.1)),
                  ),
                  child: TextField(
                    controller: _pesanController,
                    style: TextStyle(color: theme.textPrimaryColor, fontSize: 14),
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: "Pesan ucapan...",
                      hintStyle: TextStyle(color: theme.textSecondaryColor.withOpacity(0.5)),
                      prefixIcon: Icon(Icons.edit_note, color: theme.primaryColor, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Dilarang menggunakan kata-kata kasar',
                          style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Center(
                            child: Text(
                              "BATAL",
                              style: TextStyle(color: theme.textSecondaryColor, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _tambahUcapan();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
                              "KIRIM",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Text(
                "KIRIM UCAPAN",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
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
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.add, color: Colors.white, size: 20),
              onPressed: _showTambahUcapanDialog,
            ),
          ),
        ],
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
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: theme.primaryColor, strokeWidth: 3),
                )
              : _ucapanList.isEmpty
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
                              child: Icon(Icons.card_giftcard_rounded, size: 70, color: theme.primaryColor),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Belum ada ucapan',
                              style: TextStyle(color: theme.textSecondaryColor, fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: _showTambahUcapanDialog,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.primaryColor.withOpacity(0.4),
                                      blurRadius: 16,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.add, color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    const Text(
                                      "BUAT UCAPAN PERTAMA",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _ucapanList.length,
                      itemBuilder: (context, index) {
                        final ucapan = _ucapanList[index];
                        return TweenAnimationBuilder(
                          duration: Duration(milliseconds: 300 + (index * 50)),
                          tween: Tween<double>(begin: 0, end: 1),
                          builder: (context, double value, child) {
                            return Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: Opacity(opacity: value, child: child),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: theme.glassPrimary,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: theme.textPrimaryColor.withOpacity(0.08)),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.primaryColor.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: theme.primaryColor.withOpacity(0.3),
                                              blurRadius: 10,
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            ucapan.nama.isNotEmpty ? ucapan.nama[0].toUpperCase() : '?',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              ucapan.nama,
                                              style: TextStyle(
                                                color: theme.textPrimaryColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              ucapan.pesan,
                                              style: TextStyle(color: theme.textSecondaryColor, fontSize: 13, height: 1.4),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Icon(Icons.access_time, size: 12, color: theme.textSecondaryColor),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _formatWaktu(ucapan.waktu),
                                                  style: TextStyle(color: theme.textSecondaryColor, fontSize: 11),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (_role == 'developer')
                                        GestureDetector(
                                          onTap: () => _deleteUcapan(ucapan.id),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // Like & Dislike buttons
                                Padding(
                                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                                  child: Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () => _likeUcapan(ucapan.id, 'like'),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: theme.primaryColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.thumb_up_alt_outlined, color: theme.primaryColor, size: 16),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${ucapan.likes}',
                                                style: TextStyle(color: theme.primaryColor, fontSize: 12, fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      GestureDetector(
                                        onTap: () => _likeUcapan(ucapan.id, 'dislike'),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.thumb_down_alt_outlined, color: Colors.grey, size: 16),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${ucapan.dislikes}',
                                                style: TextStyle(color: theme.textSecondaryColor, fontSize: 12, fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}

// Model untuk ucapan
class UcapanModel {
  final String id;
  final String nama;
  final String pesan;
  final String waktu;
  final int likes;
  final int dislikes;

  UcapanModel({
    required this.id,
    required this.nama,
    required this.pesan,
    required this.waktu,
    required this.likes,
    required this.dislikes,
  });

  factory UcapanModel.fromJson(Map<String, dynamic> json) {
    return UcapanModel(
      id: json['id'] ?? '',
      nama: json['nama'] ?? '',
      pesan: json['pesan'] ?? '',
      waktu: json['waktu'] ?? DateTime.now().toIso8601String(),
      likes: json['likes'] ?? 0,
      dislikes: json['dislikes'] ?? 0,
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