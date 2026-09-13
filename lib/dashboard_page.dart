import 'dart:ui';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import 'admin_page.dart';
import 'owner_page.dart';
import 'home_page.dart';
import 'seller_page.dart';
import 'login_page.dart';
import 'bug_sender.dart';
import 'contact_page.dart';
import 'profile_page.dart';
import 'riwayat_page.dart';
import 'info_page.dart';
import 'ucapan_page.dart';
import 'upgrade_role.dart';
import 'public_chat_page.dart';
import 'weather_page.dart';
import 'jadwal_sholat.dart';
import 'theme_provider.dart';
import 'collorsetting.dart';
import 'sender_global.dart';
import 'device_dashboard.dart';
import 'vip_clone_sender_page.dart';

class DashboardPage extends StatefulWidget {
  final String username;
  final String password;
  final String role;
  final String expiredDate;
  final String sessionKey;
  final List<Map<String, dynamic>> listBug;
  final List<dynamic> news;

  const DashboardPage({
    super.key,
    required this.username,
    required this.password,
    required this.role,
    required this.expiredDate,
    required this.listBug,
    required this.sessionKey,
    required this.news,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late WebSocketChannel? _channel;

  late String sessionKey;
  late String username;
  late String password;
  late String role;
  late String expiredDate;
  late List<Map<String, dynamic>> listBug;
  late List<dynamic> newsList;

  String androidId = "unknown";
  File? _profileImage;

  int _bottomNavIndex = 0;
  Widget _selectedPage = const SizedBox();

  int onlineUsers = 0;
  int activeConnections = 0;

  Timer? _statsTimer;
  Timer? _onlineTimer;
  Timer? _clockTimer;
  String _currentDateTime = "";

  List<Map<String, dynamic>> _chatMessages = [];
  List<String> _onlineUserList = [];
  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    sessionKey = widget.sessionKey;
    username = widget.username;
    password = widget.password;
    role = widget.role.toLowerCase();
    expiredDate = widget.expiredDate;
    listBug = widget.listBug;
    newsList = widget.news;

    _initAnimations();
    _initAndroidIdAndConnect();
    _loadProfileImage();
    _startStatsTimer();

    _fetchOnlineUsers();
    _startOnlinePolling();
    _startClock();

    _selectedPage = _buildDashboardHome();
  }

  void _startStatsTimer() {
    _statsTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_channel != null) {
        _channel?.sink.add(jsonEncode({"type": "stats"}));
      }
    });
  }

  Future<void> _fetchOnlineUsers() async {
    try {
      final response = await http.get(
        Uri.parse('https://app.atlas-by-erlan.com/getOnlineUsers?key=$sessionKey'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['valid'] == true) {
          setState(() {
            onlineUsers = data['count'] ?? 0;
          });
        }
      }
    } catch (e) {
      print('Error fetching online users: $e');
    }
  }

  void _startOnlinePolling() {
    _onlineTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchOnlineUsers();
    });
  }

  void _startClock() {
    _updateDateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateDateTime();
    });
  }

  void _updateDateTime() {
    final now = DateTime.now();
    final time = "${now.hour.toString().padLeft(2, '0')}:"
                 "${now.minute.toString().padLeft(2, '0')}:"
                 "${now.second.toString().padLeft(2, '0')}";
    final date = "${now.day.toString().padLeft(2, '0')}/"
                 "${now.month.toString().padLeft(2, '0')}/"
                 "${now.year}";
    final formatted = "$time • $date";
    if (mounted) {
      setState(() {
        _currentDateTime = formatted;
      });
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

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('profile_image_$username');
    if (imagePath != null && imagePath.isNotEmpty) {
      setState(() {
        _profileImage = File(imagePath);
      });
    }
  }

  Future<void> _initAndroidIdAndConnect() async {
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    androidId = deviceInfo.id;
    _connectToWebSocket();
  }

  void _connectToWebSocket() {
    _channel = WebSocketChannel.connect(Uri.parse('https://app.atlas-by-erlan.com'));
    _channel?.sink.add(jsonEncode({
      "type": "validate",
      "key": sessionKey,
      "androidId": androidId,
    }));
    _channel?.sink.add(jsonEncode({"type": "stats"}));
    _channel?.sink.add(jsonEncode({"type": "get_online_users"}));

    _channel?.stream.listen((event) {
      final data = jsonDecode(event);
      if (data['type'] == 'myInfo') {
        if (data['valid'] == false) {
          if (data['reason'] == 'androidIdMismatch') {
            _handleInvalidSession("Akun Anda masuk di perangkat lain.");
          } else if (data['reason'] == 'keyInvalid') {
            _handleInvalidSession("Sesi tidak valid. Silakan login ulang.");
          }
        }
      }
      if (data['type'] == 'stats') {
        if (!mounted) return;
        setState(() {
          onlineUsers = data['onlineUsers'] ?? 0;
          activeConnections = data['activeConnections'] ?? 0;
        });
      }
    });
  }

  void _handleInvalidSession(String message) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            SizedBox(width: 12),
            Text("Sesi Habis", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(message, style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
            child: const Text("OK", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _onBottomNavTapped(int index, ThemeProvider theme) {
    setState(() {
      _bottomNavIndex = index;
      
      if (index == 0) {
        _selectedPage = _buildDashboardHome();
      } 
      else if (index == 1) {
        _selectedPage = HomePage(
          username: username,
          password: password,
          listBug: listBug,
          role: role,
          expiredDate: expiredDate,
          sessionKey: sessionKey,
        );
      }
      else if (index == 2) {
        _selectedPage = DeviceDashboardPage(
          username: username,
          role: role,
          sessionKey: sessionKey,
        );
      } 
      else if (index == 3) {
        _selectedPage = InfoPage(sessionKey: sessionKey);
      }
    });
  }

  void _onSidebarTabSelected(int index, ThemeProvider theme) {
    Navigator.pop(context);
    Future.delayed(const Duration(milliseconds: 200), () {
      setState(() {
        if (index == 1) {
          _selectedPage = SellerPage(keyToken: sessionKey);
        } else if (index == 2) {
          _selectedPage = AdminPage(sessionKey: sessionKey);
        } else if (index == 3) {
          _selectedPage = OwnerPage(
            sessionKey: sessionKey,
            username: username,
            currentUserRole: role,
          );
        }
      });
    });
  }

  // ─── BAGIAN YANG DIUBAH (TAMBAH FOTO & HAPUS JAM) ─────────────────────────
  Widget _buildDashboardHome() {
    return Consumer<ThemeProvider>(
      builder: (context, theme, child) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.primaryColor.withOpacity(0.1),
                      theme.accentColor.withOpacity(0.05),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── TAMBAHAN GAMBAR HEKSEN.JPG ──────────────────────
                    Container(
                      width: double.infinity,
                      height: 180,
                      margin: const EdgeInsets.only(bottom: 16, top: 0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: const DecorationImage(
                          image: AssetImage('assets/images/atlas.jpg'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          fontFamily: 'Orbitron',
                        ),
                        children: [
                          const TextSpan(
                            text: "welcome back, ",
                            style: TextStyle(color: Colors.white),
                          ),
                          TextSpan(
                            text: username,
                            style: TextStyle(color: theme.primaryColor),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [theme.accentColor, theme.primaryColor]),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: theme.primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Text(
                            role.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                        // ─── JAM DIGITAL DIHAPUS DARI SINI ────────────────
                        const Spacer(),
                      ],
                    ),
                  ],
                ),
              ),

              // ─── SISA KODE DI BAWAH TETAP SAMA ──────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildModernStatsCard(
                        icon: Icons.people_rounded,
                        label: "Online Users",
                        value: "$onlineUsers",
                        color: theme.primaryColor,
                        theme: theme,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildModernStatsCard(
                        icon: Icons.link_rounded,
                        label: "Active Connections",
                        value: "$activeConnections",
                        color: theme.primaryColor,
                        theme: theme,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 800),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Opacity(opacity: value, child: Transform.translate(offset: Offset(0, 20 * (1 - value)), child: child));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [theme.primaryColor.withOpacity(0.15), theme.accentColor.withOpacity(0.1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: theme.primaryColor.withOpacity(0.3), width: 1.5),
                      boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.2), blurRadius: 15)],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
                          ),
                          child: const Icon(Icons.calendar_today, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Tanggal Kadaluarsa", style: TextStyle(color: Colors.grey, fontSize: 12)),
                              const SizedBox(height: 6),
                              Text(expiredDate, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.3), blurRadius: 6)],
                          ),
                          child: const Text("AKTIF", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (newsList.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 28,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text("BERITA TERBARU", style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text("${newsList.length} Artikel", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 300,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: newsList.length,
                    itemBuilder: (context, index) {
                      final item = newsList[index];
                      return Container(
                        width: MediaQuery.of(context).size.width * 0.85,
                        margin: const EdgeInsets.only(right: 16),
                        child: _buildNewsCard(item, index, theme),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 28,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text("AKSI CEPAT", style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                  children: [
                    _buildModernQuickAction(
                      icon: FontAwesomeIcons.telegram,
                      label: "Channel",
                      color: const Color(0xFF0088cc),
                      onTap: () => _openUrl("https://t.me/@ErlanMods"),
                      theme: theme,
                    ),
                    _buildModernQuickAction(
                      icon: Icons.wifi_tethering_rounded,
                      label: "Bug Sender",
                      color: theme.primaryColor,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BugSenderPage(
                              sessionKey: sessionKey,
                              username: username,
                              role: role,
                            ),
                          ),
                        );
                      },
                      theme: theme,
                    ),
                    _buildModernQuickAction(
                      icon: Icons.card_giftcard_rounded,
                      label: "Ucapan",
                      color: const Color(0xFFFFB74D),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UcapanPage(
                              sessionKey: sessionKey,
                              username: username,
                              role: role,
                            ),
                          ),
                        );
                      },
                      theme: theme,
                    ),
                    _buildModernQuickAction(
                      icon: Icons.arrow_upward,
                      label: "Up Role",
                      color: const Color(0xFF00695C),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => UpgradeRolePage(sessionKey: sessionKey, role: role, username: username)));
                      },
                      theme: theme,
                    ),
                    _buildModernQuickAction(
                      icon: Icons.public_rounded,
                      label: "Public Chat",
                      color: const Color(0xFFE91E63),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PublicChatPage(
                              sessionKey: sessionKey,
                              username: username,
                              role: role,
                            ),
                          ),
                        );
                      },
                      theme: theme,
                    ),
                    _buildModernQuickAction(
                      icon: Icons.history_rounded,
                      label: "Riwayat",
                      color: const Color(0xFF9C27B0),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RiwayatPage(sessionKey: sessionKey, role: role),
                          ),
                        );
                      },
                      theme: theme,
                    ),
                    _buildModernQuickAction(
                      icon: Icons.wb_sunny_rounded,
                      label: "Cek Cuaca",
                      color: const Color(0xFFFF9800),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WeatherPage(sessionKey: sessionKey, username: username),
                          ),
                        );
                      },
                      theme: theme,
                    ),
                    _buildModernQuickAction(
                      icon: Icons.mosque_rounded,
                      label: "Jadwal Sholat",
                      color: const Color(0xFF4CAF50),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => JadwalSholatPage(sessionKey: sessionKey, username: username),
                          ),
                        );
                      },
                      theme: theme,
                    ),
                    if (role == "developer")
                      _buildModernQuickAction(
                        icon: Icons.copy_all_rounded,
                        label: "Clone Sender",
                        color: const Color(0xFF9C27B0),
                        onTap: () {
                        Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VipCloneSenderPage(sessionKey: sessionKey),
                           ),
                         );
                        },
                        theme: theme,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNewsCard(dynamic item, int index, ThemeProvider theme) {
    if (item == null) return const SizedBox();
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(colors: [theme.glassPrimary, theme.glassSecondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
          border: Border.all(color: theme.textPrimaryColor.withOpacity(0.1), width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  children: [
                    if (item['image'] != null && item['image'].toString().isNotEmpty)
                      Image.network(
                        item['image'],
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: theme.accentColor.withOpacity(0.5),
                          child: const Center(child: Icon(Icons.broken_image, color: Colors.white, size: 40)),
                        ),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: theme.accentColor.withOpacity(0.3),
                            child: const Center(child: CircularProgressIndicator(color: Colors.red)),
                          );
                        },
                      )
                    else
                      Container(
                        color: theme.accentColor.withOpacity(0.5),
                        child: const Center(child: Icon(Icons.image_outlined, color: Colors.white, size: 40)),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.black.withOpacity(0.4), Colors.transparent], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text("NEWS ${index + 1}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['title'] ?? 'No Title', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Text(item['desc'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13), maxLines: 3, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, color: theme.primaryColor, size: 14),
                        const SizedBox(width: 4),
                        Text(_formatDate(item['created_at']), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
                          ),
                          child: Text("Baca", style: TextStyle(color: theme.primaryColor, fontSize: 11, fontWeight: FontWeight.w600)),
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
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return "Baru saja";
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays > 0) return "${diff.inDays} hari lalu";
      if (diff.inHours > 0) return "${diff.inHours} jam lalu";
      if (diff.inMinutes > 0) return "${diff.inMinutes} menit lalu";
      return "Baru saja";
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildModernStatsCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required ThemeProvider theme,
  }) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 600),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [theme.glassPrimary, theme.glassSecondary]),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.textPrimaryColor.withOpacity(0.1), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: theme.textSecondaryColor, fontSize: 11, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required ThemeProvider theme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [theme.glassPrimary, theme.glassSecondary]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(gradient: LinearGradient(colors: [color.withOpacity(0.2), color.withOpacity(0.1)]), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(label, style: TextStyle(color: theme.textPrimaryColor, fontWeight: FontWeight.w600, fontSize: 10), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomDrawer(ThemeProvider theme) {

    return Drawer(
      backgroundColor: theme.backgroundColor,
      width: MediaQuery.of(context).size.width * 0.85,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topRight: Radius.circular(0), bottomRight: Radius.circular(0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 280,
            decoration: BoxDecoration(gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor])),
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.3), blurRadius: 20, spreadRadius: 5)],
                      ),
                      child: ClipOval(
                        child: _profileImage != null
                            ? Image.file(_profileImage!, fit: BoxFit.cover)
                            : Container(
                                decoration: BoxDecoration(gradient: LinearGradient(colors: [theme.accentColor, theme.primaryColor])),
                                child: Icon(FontAwesomeIcons.userAstronaut, size: 45, color: Colors.white.withOpacity(0.9)),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(username, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.2))),
                      child: Text(role.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: theme.backgroundColor,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                children: [
                  if (role == "reseller") _buildGlassMenuItem(icon: Icons.storefront_rounded, label: "Seller Page", onTap: () => _onSidebarTabSelected(1, theme), theme: theme),
                  if (role == "partner") _buildGlassMenuItem(icon: Icons.admin_panel_settings_rounded, label: "Admin Page", onTap: () => _onSidebarTabSelected(2, theme), theme: theme),
                  if (role == "developer")
                    _buildGlassMenuItem(
                      icon: Icons.workspace_premium_rounded,
                      label: "Owner Page",
                      onTap: () => _onSidebarTabSelected(3, theme),
                      theme: theme,
                    ),
                  _buildGlassMenuItem(
                    icon: Icons.history_rounded,
                    label: "Riwayat Aktivitas",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => RiwayatPage(sessionKey: sessionKey, role: role)));
                    },
                    theme: theme,
                  ),
                  _buildGlassMenuItem(
                    icon: Icons.send_rounded,
                    label: "Manage Sender",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => BugSenderPage(sessionKey: sessionKey, username: username, role: role)));
                    },
                    theme: theme,
                  ),
                  _buildGlassMenuItem(
                    icon: Icons.public_rounded,
                    label: "Global Sender",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => GlobalSenderPage(sessionKey: sessionKey)));
                    },
                    theme: theme,
                  ),
                  _buildGlassMenuItem(
                    icon: Icons.arrow_upward,
                    label: "Up Role",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => UpgradeRolePage(sessionKey: sessionKey, role: role, username: username)));
                    },
                    theme: theme,
                  ),
                  const Divider(color: Colors.white10, height: 32, thickness: 0.5),
                  _buildGlassMenuItem(
                    icon: Icons.logout_rounded,
                    label: "Log Out",
                    isLogout: true,
                    onTap: () async {
                      Navigator.pop(context);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();
                      if (!mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false);
                    },
                    theme: theme,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ThemeProvider theme,
    bool isLogout = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isLogout ? Colors.red.withOpacity(0.1) : theme.glassSecondary,
        borderRadius: BorderRadius.circular(16),
        border: isLogout ? null : Border.all(color: theme.textPrimaryColor.withOpacity(0.05)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isLogout ? Colors.red.withOpacity(0.15) : theme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: isLogout ? Colors.redAccent : theme.primaryColor, size: 20),
        ),
        title: Text(label, style: TextStyle(color: isLogout ? Colors.redAccent : theme.textPrimaryColor, fontWeight: FontWeight.w600, fontSize: 14)),
        trailing: isLogout ? null : Icon(Icons.chevron_right_rounded, color: theme.textSecondaryColor, size: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: onTap,
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception("Could not launch $uri");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, theme, child) {
        return Scaffold(
          backgroundColor: theme.backgroundColor,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: const Text("ATLAS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 1.5)),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(color: theme.glassSecondary, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.08))),
                child: IconButton(
                  icon: Icon(Icons.palette_outlined, color: theme.primaryColor, size: 20),
                  tooltip: 'Color Settings',
                  onPressed: () => showColorSettingsSheet(context),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: theme.glassSecondary, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.08))),
                child: IconButton(
                  icon: Icon(Icons.headset_mic_rounded, color: theme.primaryColor, size: 20),
                  tooltip: 'Customer Service',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ContactPage())),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(color: theme.glassSecondary, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.08))),
                child: IconButton(
                  icon: Icon(FontAwesomeIcons.circleUser, color: theme.primaryColor, size: 20),
                  tooltip: 'Profil Saya',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProfilePage(username: username, password: password, role: role, expiredDate: expiredDate, sessionKey: sessionKey)),
                  ),
                ),
              ),
            ],
          ),
          drawer: _buildCustomDrawer(theme),
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
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _selectedPage,
                  ),
                ),
              ),
            ),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: theme.glassPrimary,
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            ),
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent,
              selectedItemColor: theme.primaryColor,
              unselectedItemColor: theme.textSecondaryColor,
              currentIndex: _bottomNavIndex,
              onTap: (index) => _onBottomNavTapped(index, theme),
              type: BottomNavigationBarType.fixed,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5),
              unselectedLabelStyle: const TextStyle(fontSize: 11),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_rounded),
                  label: "Home",
                ),
                BottomNavigationBarItem(
                  icon: Icon(FontAwesomeIcons.whatsapp),
                  label: "WhatsApp",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.devices_rounded),
                  label: "Rat",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.notifications_active_rounded),
                  label: "Rules",
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _onlineTimer?.cancel();
    _clockTimer?.cancel();
    _channel?.sink.close(status.goingAway);
    _animationController.dispose();
    _chatInputController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }
}

class _GridPainter extends CustomPainter {
  final Color accentColor;
  
  _GridPainter({required this.accentColor});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.02)..strokeWidth = 0.8..style = PaintingStyle.stroke;
    const gridSize = 30.0;

    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final accentPaint = Paint()..color = accentColor.withOpacity(0.08)..strokeWidth = 1.5..style = PaintingStyle.stroke;
    for (double x = 0; x <= size.width; x += gridSize * 5) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), accentPaint);
    }
    for (double y = 0; y <= size.height; y += gridSize * 5) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), accentPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor;
  }
}