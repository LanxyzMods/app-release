import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ─── Config ───────────────────────────────────────────────────────────────────
const _kBase = 'https://app.atlas-by-erlan.com';

// ─── Permission Store ────────────────────────────────────────────────────────
class DevicePermissionStore {

  static Future<PermissionResult> getFor(String username, String sessionKey) async {
    if (username.toLowerCase() == 'developer') {
      return PermissionResult(approved: true, allDevices: true, devices: []);
    }
    try {
      final res = await http.get(
        Uri.parse('$_kBase/devicePerms?key=$sessionKey&username=${Uri.encodeComponent(username)}'),
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d['valid'] == true) {
          return PermissionResult(
            approved: d['approved'] == true,
            allDevices: d['allDevices'] == true,
            devices: List<String>.from(d['devices'] ?? []),
          );
        }
      }
    } catch (e) {
      debugPrint('[DevicePerm] getFor error: $e');
    }
    return PermissionResult(approved: false, allDevices: false, devices: []);
  }

  static Future<bool> setPerm(String ownerKey, String username,
      {required bool approved, required bool allDevices, required List<String> devices}) async {
    try {
      final res = await http.post(
        Uri.parse('$_kBase/setDevicePerm?key=$ownerKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'approved': approved,
          'allDevices': allDevices,
          'devices': devices,
        }),
      ).timeout(const Duration(seconds: 8));
      final d = jsonDecode(res.body);
      return d['valid'] == true;
    } catch (e) {
      debugPrint('[DevicePerm] setPerm error: $e');
      return false;
    }
  }

  static Future<bool> removePerm(String ownerKey, String username) async {
    return setPerm(ownerKey, username,
        approved: false, allDevices: false, devices: []);
  }

  static Future<Map<String, dynamic>> getAll(String ownerKey) async {
    try {
      final res = await http.get(
        Uri.parse('$_kBase/listDevicePerms?key=$ownerKey'),
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d['valid'] == true) return Map<String, dynamic>.from(d['perms'] ?? {});
      }
    } catch (e) {
      debugPrint('[DevicePerm] getAll error: $e');
    }
    return {};
  }
}

class PermissionResult {
  final bool approved, allDevices;
  final List<String> devices;
  PermissionResult({required this.approved, required this.allDevices, required this.devices});
  bool canSee(String? deviceId) {
    if (!approved) return false;
    if (allDevices) return true;
    return deviceId != null && devices.contains(deviceId);
  }
}

// ─── Neon Colors ─────────────────────────────────────────────────────────────
class _C {
  static const bg       = Color(0xFF050510);
  static const s1       = Color(0xFF0A0A20);
  static const s2       = Color(0xFF0F0F2E);
  static const s3       = Color(0xFF141438);
  static const border   = Color(0xFF1A1A45);
  static const blue     = Color(0xFF00B4FF);
  static const blueDim  = Color(0xFF005A80);
  static const red      = Color(0xFFFF073A);
  static const green    = Color(0xFF00FF88);
  static const textP    = Color(0xFFE8EAFF);
  static const textS    = Color(0xFF8888AA);
  static const textM    = Color(0xFF444466);
  static const white    = Color(0xFFFFFFFF);
}

// ─── Owner Permission Manager ─────────────────────────────────────────────────
class DevicePermissionManagerPage extends StatefulWidget {
  final String sessionKey;
  final List<dynamic> allDevices;
  const DevicePermissionManagerPage({
    super.key, required this.sessionKey, required this.allDevices});
  @override State<DevicePermissionManagerPage> createState() => _DPMState();
}

class _DPMState extends State<DevicePermissionManagerPage> {
  Map<String, dynamic> _perms = {};
  String _selectedUser = '';
  final _inputCtrl = TextEditingController();
  String _inputVal = '';
  bool _loading = true;
  bool _saving = false;

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _inputCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await DevicePermissionStore.getAll(widget.sessionKey);
    setState(() { _perms = data; _loading = false; });
  }

  List<String> get _users => _perms.keys.toList();
  bool _approved(String u) => _perms[u]?['approved'] == true;
  bool _hasAll(String u) => _perms[u]?['allDevices'] == true;
  List<String> _devices(String u) => List<String>.from(_perms[u]?['devices'] ?? []);

  Future<void> _addUser(String username) async {
    if (username.trim().isEmpty) return;
    final key = username.trim().toLowerCase();
    final ok = await DevicePermissionStore.setPerm(
      widget.sessionKey, key,
      approved: true, allDevices: true, devices: [],
    );
    if (ok) {
      await _load();
      setState(() { _selectedUser = key; _inputVal = ''; _inputCtrl.clear(); });
    }
  }

  Future<void> _update(String u, {bool? approved, bool? allDevices, List<String>? devices}) async {
    setState(() => _saving = true);
    final ok = await DevicePermissionStore.setPerm(
      widget.sessionKey, u,
      approved: approved ?? _approved(u),
      allDevices: allDevices ?? _hasAll(u),
      devices: devices ?? _devices(u),
    );
    if (ok) await _load();
    setState(() => _saving = false);
  }

  Widget _neonBox({
    required Widget child,
    Color glowColor = _C.blue,
    double blur = 12,
    double radius = 16,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _C.s1,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: glowColor.withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(color: glowColor.withOpacity(0.08), blurRadius: blur, spreadRadius: -2),
        ],
      ),
      child: child,
    );
  }

  Widget _neonDivider({Color color = _C.blue}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0), color.withOpacity(0.4), color.withOpacity(0)],
          )
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'DEVICE ACCESS',
          style: TextStyle(
            color: _C.textP,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 3
          ),
        ),
        iconTheme: const IconThemeData(color: _C.blue, size: 22),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 18),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(color: _C.red, strokeWidth: 2)
              ),
            ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _C.border, width: 1)),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _C.blue, strokeWidth: 2))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _neonBox(
                    glowColor: _C.blue,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _inputCtrl,
                              onChanged: (v) => setState(() => _inputVal = v),
                              onSubmitted: (_) => _addUser(_inputVal),
                              style: const TextStyle(color: _C.textP, fontSize: 13),
                              decoration: const InputDecoration(
                                hintText: 'Username...',
                                hintStyle: TextStyle(color: _C.textM, fontSize: 13),
                                prefixIcon: Icon(Icons.alternate_email_rounded, color: _C.blueDim, size: 18),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _addUser(_inputVal),
                            child: Container(
                              margin: const EdgeInsets.all(2),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [_C.blue, _C.blueDim]),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(color: _C.blue.withOpacity(0.3), blurRadius: 14, spreadRadius: -2),
                                ],
                              ),
                              child: const Text(
                                'ADD',
                                style: TextStyle(
                                  color: _C.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _users.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Diperbaiki: Menggunakan ikon bawaan yang 100% ada
                              Icon(Icons.block_rounded, color: _C.textM.withOpacity(0.5), size: 52),
                              const SizedBox(height: 18),
                              const Text(
                                'NO USER YET',
                                style: TextStyle(
                                  color: _C.textS,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Type a username above to grant access',
                                style: TextStyle(color: _C.textM, fontSize: 11),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'SELECT USER',
                                style: TextStyle(
                                  color: _C.textM,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 3
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _users.map((u) {
                                  final active = u == _selectedUser;
                                  final appr = _approved(u);
                                  final glow = active ? _C.red : (appr ? _C.blue : _C.border);
                                  return GestureDetector(
                                    onTap: () => setState(() => _selectedUser = u),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: active ? _C.red.withOpacity(0.12) : _C.s2,
                                        borderRadius: BorderRadius.circular(22),
                                        border: Border.all(color: glow.withOpacity(active ? 0.6 : 0.3), width: 1),
                                        boxShadow: active ? [
                                          BoxShadow(color: _C.red.withOpacity(0.15), blurRadius: 16, spreadRadius: -2)
                                        ] : null,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: appr ? _C.green : _C.red,
                                              boxShadow: [
                                                BoxShadow(color: (appr ? _C.green : _C.red).withOpacity(0.6), blurRadius: 6),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            u,
                                            style: TextStyle(
                                              color: active ? _C.white : _C.textS,
                                              fontSize: 12,
                                              fontWeight: active ? FontWeight.bold : FontWeight.w500,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              if (_selectedUser.isNotEmpty) ...[
                                const SizedBox(height: 18),
                                _neonBox(
                                  glowColor: _C.red,
                                  radius: 18,
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: _C.red.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: const Icon(Icons.person_rounded, color: _C.red, size: 16),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _selectedUser,
                                                    style: const TextStyle(
                                                      color: _C.textP,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                      letterSpacing: 0.5
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    _approved(_selectedUser) ? 'Access Granted' : 'Access Revoked',
                                                    style: TextStyle(
                                                      color: _approved(_selectedUser) ? _C.green : _C.red,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w500
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () async {
                                                await DevicePermissionStore.removePerm(widget.sessionKey, _selectedUser);
                                                setState(() => _selectedUser = '');
                                                await _load();
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: _C.red.withOpacity(0.08),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: _C.red.withOpacity(0.2)),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.delete_outline_rounded, color: _C.red, size: 14),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      'REMOVE',
                                                      style: TextStyle(
                                                        color: _C.red,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        letterSpacing: 1
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        _neonDivider(color: _C.red),
                                        Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: _C.s2,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: _C.border),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'Approve Access',
                                                      style: TextStyle(
                                                        color: _C.textP,
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w600
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      _approved(_selectedUser)
                                                          ? 'User can access selected devices'
                                                          : 'User is blocked from all devices',
                                                      style: TextStyle(
                                                        color: _approved(_selectedUser) ? _C.green.withOpacity(0.8) : _C.textM,
                                                        fontSize: 11
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  boxShadow: _approved(_selectedUser)
                                                      ? [BoxShadow(color: _C.green.withOpacity(0.4), blurRadius: 12)]
                                                      : [],
                                                ),
                                                child: Switch(
                                                  value: _approved(_selectedUser),
                                                  activeColor: _C.green,
                                                  activeTrackColor: _C.green.withOpacity(0.2),
                                                  inactiveThumbColor: _C.textM,
                                                  inactiveTrackColor: _C.s3,
                                                  onChanged: (v) => _update(_selectedUser, approved: v),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              if (_selectedUser.isNotEmpty && _approved(_selectedUser) && !_hasAll(_selectedUser)) ...[
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    const Text(
                                      'DEVICES',
                                      style: TextStyle(
                                        color: _C.textM,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 3
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _C.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: _C.blue.withOpacity(0.2)),
                                      ),
                                      child: Text(
                                        '${_devices(_selectedUser).length} selected',
                                        style: const TextStyle(
                                          color: _C.blue,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                if (widget.allDevices.isEmpty)
                                  _neonBox(
                                    glowColor: _C.border,
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 28),
                                      child: Center(
                                        child: Text(
                                          'No devices available',
                                          style: TextStyle(color: _C.textM, fontSize: 12)
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  // Diperbaiki: Menghapus spread operator (...) yang bikin error, diganti langsung menjadi children Column
                                  Column(
                                    children: widget.allDevices.map((d) {
                                      final id = d['id']?.toString() ?? '';
                                      final model = d['model']?.toString() ?? 'Unknown';
                                      final ip = d['ip']?.toString() ?? '-';
                                      final allowed = _devices(_selectedUser).contains(id);
                                      final glow = allowed ? _C.blue : _C.border;

                                      return AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        margin: const EdgeInsets.only(bottom: 8),
                                        decoration: BoxDecoration(
                                          color: allowed ? _C.blue.withOpacity(0.06) : _C.s1,
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: glow.withOpacity(allowed ? 0.35 : 0.15), width: 1),
                                          boxShadow: allowed ? [
                                            BoxShadow(color: _C.blue.withOpacity(0.08), blurRadius: 14, spreadRadius: -4)
                                          ] : null,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: allowed ? _C.blue.withOpacity(0.12) : _C.s3,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Icon(
                                                  Icons.phone_android_rounded,
                                                  color: allowed ? _C.blue : _C.textM,
                                                  size: 16
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      model,
                                                      style: TextStyle(
                                                        color: allowed ? _C.textP : _C.textS,
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w600
                                                      ),
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      'ID: $id  ·  $ip',
                                                      style: const TextStyle(
                                                        color: _C.textM,
                                                        fontSize: 10,
                                                        letterSpacing: 0.3
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: () async {
                                                  final cur = List<String>.from(_devices(_selectedUser));
                                                  if (cur.contains(id)) {
                                                    cur.remove(id);
                                                  } else {
                                                    cur.add(id);
                                                  }
                                                  await _update(_selectedUser, devices: cur);
                                                },
                                                child: AnimatedContainer(
                                                  duration: const Duration(milliseconds: 200),
                                                  width: 44,
                                                  height: 24,
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(12),
                                                    color: allowed ? _C.blue : _C.s3,
                                                    border: Border.all(color: allowed ? _C.blue.withOpacity(0.5) : _C.border),
                                                    boxShadow: allowed ? [
                                                      BoxShadow(color: _C.blue.withOpacity(0.3), blurRadius: 10)
                                                    ] : null,
                                                  ),
                                                  child: AnimatedAlign(
                                                    duration: const Duration(milliseconds: 200),
                                                    alignment: allowed ? Alignment.centerRight : Alignment.centerLeft,
                                                    child: Container(
                                                      width: 18,
                                                      height: 18,
                                                      margin: const EdgeInsets.all(3),
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: allowed ? _C.white : _C.textM,
                                                        boxShadow: allowed ? [
                                                          BoxShadow(color: _C.blue.withOpacity(0.5), blurRadius: 6)
                                                        ] : null,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                              ],
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}