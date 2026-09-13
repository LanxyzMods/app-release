import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'role_helper.dart';
import 'theme_provider.dart';

class OwnerPage extends StatefulWidget {
  final String sessionKey;
  final String username;
  final String currentUserRole;

  const OwnerPage({
    super.key,
    required this.sessionKey,
    required this.username,
    this.currentUserRole = 'owner',
  });

  @override
  State<OwnerPage> createState() => _OwnerPageState();
}

class _OwnerPageState extends State<OwnerPage> {
  late String sessionKey;
  late String currentUserRole;
  List<dynamic> fullUserList = [];
  List<dynamic> filteredList = [];

  // Dropdown filter menampilkan SEMUA role (agar bisa lihat semua user)
  late List<String> allRoleList;
  String selectedFilterRole = 'all'; // 'all' artinya tampilkan semua user

  // Role yang bisa DIBUAT oleh current user (untuk create account)
  List<String> creatableRoleList = [];
  String selectedCreateRole = 'member';

  int currentPage = 1;
  int itemsPerPage = 25;

  final createUsernameController = TextEditingController();
  final createPasswordController = TextEditingController();
  final createDayController = TextEditingController();
  final deleteController = TextEditingController();
  final editUsernameController = TextEditingController();
  final editDayController = TextEditingController();

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    sessionKey = widget.sessionKey;
    currentUserRole = widget.currentUserRole;
    _initRoleLists();
    _fetchUsers();
  }

  void _initRoleLists() {
    // Daftar semua role untuk filter (termasuk 'all')
    allRoleList = ['all', ...getAllRoles()];
    // Daftar role yang bisa dibuat oleh current user
    creatableRoleList = creatableRoles(currentUserRole);
    if (creatableRoleList.isNotEmpty) {
      selectedCreateRole = creatableRoleList.first;
    }
    selectedFilterRole = 'all';
  }

  Future<void> _fetchUsers() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('https://app.atlas-by-erlan.com/listUsers?key=$sessionKey'),
      );
      final data = jsonDecode(res.body);
      if (data['valid'] == true && data['authorized'] == true) {
        fullUserList = data['users'] ?? [];
        _applyFilter();
      } else {
        _alert("Info", data['message'] ?? 'Gagal memuat user.');
      }
    } catch (_) {
      _alert("Error", "Gagal terhubung ke server.");
    }
    setState(() => isLoading = false);
  }

  void _applyFilter() {
    setState(() {
      currentPage = 1;
      if (selectedFilterRole == 'all') {
        filteredList = List.from(fullUserList);
      } else {
        filteredList = fullUserList
            .where((u) => u['role'].toString().toLowerCase() == selectedFilterRole.toLowerCase())
            .toList();
      }
    });
  }

  List<dynamic> _getCurrentPageData() {
    if (filteredList.isEmpty) return [];
    final start = (currentPage - 1) * itemsPerPage;
    final end = start + itemsPerPage;
    if (start >= filteredList.length) return [];
    return filteredList.sublist(start, end > filteredList.length ? filteredList.length : end);
  }

  int get totalPages => filteredList.isEmpty ? 1 : (filteredList.length / itemsPerPage).ceil();

  // Izin hapus & edit (dari role_helper)
  bool _canDeleteUser(String targetRole) => canDeleteUser(currentUserRole, targetRole);
  bool _canEditUser(String targetRole) => canEditUser(currentUserRole, targetRole);

  Future<void> _deleteUser() async {
    final username = deleteController.text.trim();
    if (username.isEmpty) {
      _alert("Peringatan", "Masukkan username yang ingin dihapus.");
      return;
    }

    final targetUser = fullUserList.firstWhere(
      (u) => u['username'] == username,
      orElse: () => null,
    );

    if (targetUser == null) {
      _alert("Error", "User tidak ditemukan.");
      return;
    }

    final targetRole = targetUser['role'].toString().toLowerCase();
    if (!_canDeleteUser(targetRole)) {
      _alert("⛔ Akses Ditolak",
          "Anda tidak memiliki izin untuk menghapus user dengan role ${roleLabel(targetRole)}.\nHanya bisa menghapus role yang levelnya lebih rendah.");
      return;
    }

    setState(() => isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('https://app.atlas-by-erlan.com/deleteUser?key=$sessionKey&username=$username'),
      );
      final data = jsonDecode(res.body);
      if (data['deleted'] == true) {
        _alert("Sukses", "User berhasil dihapus.");
        deleteController.clear();
        _fetchUsers();
      } else {
        _alert("Gagal", data['message'] ?? 'Gagal menghapus user.');
      }
    } catch (_) {
      _alert("Error", "Gagal menghubungi server.");
    }
    setState(() => isLoading = false);
  }

  Future<void> _createAccount() async {
    final u = createUsernameController.text.trim();
    final p = createPasswordController.text.trim();
    final d = createDayController.text.trim();

    if (u.isEmpty || p.isEmpty || d.isEmpty) {
      _alert("Peringatan", "Semua field wajib diisi.");
      return;
    }

    if (!canCreateRole(currentUserRole, selectedCreateRole)) {
      _alert("⛔ Akses Ditolak",
          "Anda tidak memiliki izin untuk membuat user dengan role ${roleLabel(selectedCreateRole)}.");
      return;
    }

    final days = int.tryParse(d);
    final maxDur = maxDays(currentUserRole);
    if (days != null && days > maxDur) {
      _alert("Peringatan",
          "Maksimal durasi untuk ${roleLabel(currentUserRole)} adalah $maxDur hari.");
      return;
    }

    setState(() => isLoading = true);
    try {
      final url = Uri.parse(
        'https://app.atlas-by-erlan.com/userAdd?key=$sessionKey&username=$u&password=$p&day=$d&role=$selectedCreateRole',
      );
      final res = await http.get(url);
      final data = jsonDecode(res.body);

      if (data['created'] == true) {
        _alert("Sukses", "Akun berhasil dibuat sebagai ${roleLabel(selectedCreateRole)}.");
        createUsernameController.clear();
        createPasswordController.clear();
        createDayController.clear();
        selectedCreateRole = creatableRoleList.isNotEmpty ? creatableRoleList.first : 'member';
        _fetchUsers();
      } else {
        _alert("Gagal", data['message'] ?? 'Gagal membuat akun.');
      }
    } catch (_) {
      _alert("Error", "Gagal menghubungi server.");
    }
    setState(() => isLoading = false);
  }

  Future<void> _editUser() async {
    final u = editUsernameController.text.trim();
    final d = editDayController.text.trim();

    if (u.isEmpty || d.isEmpty) {
      _alert("Peringatan", "Semua field wajib diisi.");
      return;
    }

    final targetUser = fullUserList.firstWhere(
      (user) => user['username'] == u,
      orElse: () => null,
    );

    if (targetUser == null) {
      _alert("Error", "User tidak ditemukan.");
      return;
    }

    final targetRole = targetUser['role'].toString().toLowerCase();
    if (!_canEditUser(targetRole)) {
      _alert("⛔ Akses Ditolak",
          "Anda tidak memiliki izin untuk mengedit user dengan role ${roleLabel(targetRole)}.");
      return;
    }

    final days = int.tryParse(d);
    final maxDur = maxDays(currentUserRole);
    if (days != null && days > maxDur) {
      _alert("Peringatan",
          "Maksimal tambahan durasi untuk ${roleLabel(currentUserRole)} adalah $maxDur hari.");
      return;
    }

    setState(() => isLoading = true);
    try {
      final url = Uri.parse(
        'https://app.atlas-by-erlan.com/editUser?key=$sessionKey&username=$u&addDays=$d',
      );
      final res = await http.get(url);
      final data = jsonDecode(res.body);

      if (data['edited'] == true) {
        _alert("Sukses", "Durasi berhasil diperbarui.");
        editUsernameController.clear();
        editDayController.clear();
        _fetchUsers();
      } else {
        _alert("Gagal", data['message'] ?? 'Gagal mengubah durasi.');
      }
    } catch (_) {
      _alert("Error", "Gagal menghubungi server.");
    }
    setState(() => isLoading = false);
  }

  void _alert(String title, String message) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: TweenAnimationBuilder(
          duration: const Duration(milliseconds: 300),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, double scale, child) => Transform.scale(scale: scale, child: child),
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
                    boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.4), blurRadius: 15)],
                  ),
                  child: Icon(title == "Sukses" ? Icons.check_circle : Icons.warning_rounded,
                      color: Colors.white, size: 32),
                ),
                const SizedBox(height: 20),
                Text(title, style: TextStyle(color: theme.textPrimaryColor, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center, style: TextStyle(color: theme.textSecondaryColor, fontSize: 14)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.3), blurRadius: 8)],
                      ),
                      child: Center(child: Text("OK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
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

  Widget _buildInput({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType type = TextInputType.text,
    String hint = "",
  }) {
    final theme = Provider.of<ThemeProvider>(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: theme.glassSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.textPrimaryColor.withOpacity(0.1)),
        ),
        child: TextField(
          controller: controller,
          keyboardType: type,
          style: TextStyle(color: theme.textPrimaryColor),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            hintStyle: TextStyle(color: theme.textSecondaryColor),
            labelStyle: TextStyle(color: theme.textSecondaryColor),
            prefixIcon: Icon(icon, color: theme.primaryColor, size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Provider.of<ThemeProvider>(context);
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 500),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 20 * (1 - value)), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.glassPrimary,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.textPrimaryColor.withOpacity(0.08)),
          boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.3), blurRadius: 8)],
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(title, style: TextStyle(color: theme.textPrimaryColor, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildUserItem(Map user) {
    final theme = Provider.of<ThemeProvider>(context);
    final targetRole = user['role'].toString().toLowerCase();
    final canDelete = _canDeleteUser(targetRole);
    final canEdit = _canEditUser(targetRole);

    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 300),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 20 * (1 - value)), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.glassSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.textPrimaryColor.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.3), blurRadius: 8)],
              ),
              child: Text(user['username'][0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user['username'], style: TextStyle(color: theme.textPrimaryColor, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
                        ),
                        child: Text(roleLabel(targetRole),
                            style: TextStyle(color: theme.primaryColor, fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                      Text("Exp: ${user['expiredDate']}", style: TextStyle(color: theme.textSecondaryColor, fontSize: 11)),
                      Text("Parent: ${user['parent'] ?? 'SYSTEM'}", style: TextStyle(color: theme.textSecondaryColor, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            if (canEdit)
              GestureDetector(
                onTap: () {
                  editUsernameController.text = user['username'];
                  _alert("Info", "Masukkan jumlah hari untuk memperpanjang durasi ${user['username']}.");
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: const Icon(Icons.edit_calendar, color: Colors.blueAccent, size: 20),
                ),
              ),
            if (canDelete)
              GestureDetector(
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => Dialog(
                      backgroundColor: Colors.transparent,
                      child: TweenAnimationBuilder(
                        duration: const Duration(milliseconds: 300),
                        tween: Tween<double>(begin: 0, end: 1),
                        builder: (context, double scale, child) => Transform.scale(scale: scale, child: child),
                        child: Container(
                          margin: const EdgeInsets.all(20),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [theme.backgroundColor, theme.backgroundColor.withOpacity(0.95)]),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3), width: 1.5),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                                ),
                                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 32),
                              ),
                              const SizedBox(height: 20),
                              const Text("Konfirmasi Hapus",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                              const SizedBox(height: 8),
                              Text("Hapus user ${user['username']}?",
                                  style: TextStyle(color: theme.textSecondaryColor, fontSize: 14), textAlign: TextAlign.center),
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
                                        child: Center(child: Text("BATAL", style: TextStyle(color: theme.textSecondaryColor, fontWeight: FontWeight.w600))),
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
                                          color: const Color(0xFFEF4444).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                                        ),
                                        child: const Center(child: Text("HAPUS", style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600))),
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
                  if (confirm == true) {
                    deleteController.text = user['username'];
                    _deleteUser();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
                  ),
                  child: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination() {
    final theme = Provider.of<ThemeProvider>(context);
    if (totalPages <= 1) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(totalPages > 10 ? 10 : totalPages, (index) {
        final page = index + 1;
        return GestureDetector(
          onTap: () => setState(() => currentPage = page),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: currentPage == page ? LinearGradient(colors: [theme.primaryColor, theme.accentColor]) : null,
              color: currentPage == page ? null : theme.glassSecondary,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: currentPage == page ? theme.primaryColor : theme.textPrimaryColor.withOpacity(0.1)),
            ),
            child: Text("$page",
                style: TextStyle(
                    color: currentPage == page ? Colors.white : theme.textSecondaryColor,
                    fontSize: 12,
                    fontWeight: currentPage == page ? FontWeight.bold : FontWeight.normal)),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final maxDur = maxDays(currentUserRole);
    final canCreate = creatableRoleList.isNotEmpty;

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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Header
                  TweenAnimationBuilder(
                    duration: const Duration(milliseconds: 600),
                    tween: Tween<double>(begin: 0, end: 1),
                    builder: (context, double value, child) =>
                        Opacity(opacity: value, child: Transform.scale(scale: value, child: child)),
                    child: Column(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.5), blurRadius: 30, spreadRadius: 5)],
                          ),
                          child: Center(child: Icon(Icons.workspace_premium, color: Colors.white, size: 36)),
                        ),
                        const SizedBox(height: 16),
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(colors: [theme.primaryColor, theme.accentColor]).createShader(bounds),
                          child: Text("${roleLabel(currentUserRole)} DASHBOARD",
                              style: TextStyle(color: theme.textPrimaryColor, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2)),
                        ),
                        const SizedBox(height: 8),
                        if (maxDur > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
                            ),
                            child: Text("Maksimal Durasi: $maxDur Hari", style: TextStyle(color: theme.primaryColor, fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // DELETE USER
                  _buildGlassCard(
                    title: "DELETE USER",
                    icon: FontAwesomeIcons.userSlash,
                    children: [
                      _buildInput(label: "Username Target", controller: deleteController, icon: FontAwesomeIcons.user),
                      const SizedBox(height: 8),
                      Container(
                        height: 50,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFB91C1C)]),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: const Color(0xFFEF4444).withOpacity(0.3), blurRadius: 8)],
                        ),
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _deleteUser,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.delete, size: 18, color: Colors.white),
                              SizedBox(width: 8),
                              Text("DELETE ACCOUNT", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // CREATE ACCOUNT (hanya jika bisa membuat role)
                  if (canCreate)
                    _buildGlassCard(
                      title: "CREATE ACCOUNT",
                      icon: FontAwesomeIcons.userPlus,
                      children: [
                        _buildInput(label: "Username", controller: createUsernameController, icon: FontAwesomeIcons.user),
                        _buildInput(label: "Password", controller: createPasswordController, icon: FontAwesomeIcons.lock),
                        _buildInput(
                          label: "Durasi (Hari)",
                          controller: createDayController,
                          icon: FontAwesomeIcons.calendarDay,
                          type: TextInputType.number,
                          hint: "Maksimal $maxDur hari",
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.glassSecondary,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: theme.textPrimaryColor.withOpacity(0.1)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedCreateRole,
                              dropdownColor: theme.backgroundColor,
                              style: TextStyle(color: theme.textPrimaryColor),
                              items: creatableRoleList.map((role) {
                                return DropdownMenuItem(value: role, child: Text(roleLabel(role)));
                              }).toList(),
                              onChanged: (val) => setState(() => selectedCreateRole = val ?? 'member'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 50,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.3), blurRadius: 8)],
                          ),
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _createAccount,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                            child: isLoading
                                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text("CREATE ACCOUNT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          ),
                        ),
                      ],
                    ),

                  // EXTEND DURATION
                  _buildGlassCard(
                    title: "EXTEND DURATION",
                    icon: FontAwesomeIcons.clock,
                    children: [
                      _buildInput(label: "Username Target", controller: editUsernameController, icon: FontAwesomeIcons.userEdit),
                      _buildInput(
                        label: "Tambah Hari",
                        controller: editDayController,
                        icon: FontAwesomeIcons.calendarPlus,
                        type: TextInputType.number,
                        hint: "Maksimal $maxDur hari",
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 50,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)]),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 8)],
                        ),
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _editUser,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                          child: const Text("ADD DAYS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ),
                      ),
                    ],
                  ),

                  // USER LIST (dengan filter semua role)
                  _buildGlassCard(
                    title: "USER LIST",
                    icon: FontAwesomeIcons.users,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.glassSecondary,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.textPrimaryColor.withOpacity(0.1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedFilterRole,
                            dropdownColor: theme.backgroundColor,
                            style: TextStyle(color: theme.textPrimaryColor),
                            items: allRoleList.map((role) {
                              return DropdownMenuItem(
                                value: role,
                                child: Text(role == 'all' ? 'SEMUA ROLE' : roleLabel(role)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                selectedFilterRole = val;
                                _applyFilter();
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      isLoading
                          ? Center(child: CircularProgressIndicator(color: theme.primaryColor, strokeWidth: 3))
                          : filteredList.isEmpty
                              ? Center(child: Text("Tidak ada user", style: TextStyle(color: theme.textSecondaryColor)))
                              : Column(
                                  children: [
                                    ..._getCurrentPageData().map((u) => _buildUserItem(u)).toList(),
                                    const SizedBox(height: 16),
                                    _buildPagination(),
                                  ],
                                ),
                    ],
                  ),
                  const SizedBox(height: 30),
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