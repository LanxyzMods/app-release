import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:app_links/app_links.dart'; // ⬅️ IMPORT PACKAGE APP_LINKS

import 'login_page.dart';
import 'dashboard_page.dart';
import 'home_page.dart';
import 'seller_page.dart';
import 'admin_page.dart';
import 'owner_page.dart';
import 'landing.dart';
import 'theme_provider.dart';
import 'maintance_page.dart';
import 'update_page.dart';

// Global Navigator Key untuk mendengarkan deep link di luar widget tree
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final Widget initialScreen = await checkInitialScreen();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: MyApp(initialScreen: initialScreen),
    ),
  );
}

// ================================================================
// CEK VERSI
// ================================================================
bool isUpdateRequired(String currentVersion, String serverVersion) {
  try {
    final currentParts = currentVersion
        .trim()
        .split('.')
        .map((e) => int.parse(e))
        .toList();

    final serverParts = serverVersion
        .trim()
        .split('.')
        .map((e) => int.parse(e))
        .toList();

    final maxLength = currentParts.length > serverParts.length
        ? currentParts.length
        : serverParts.length;

    for (int i = 0; i < maxLength; i++) {
      final current = i < currentParts.length ? currentParts[i] : 0;
      final server = i < serverParts.length ? serverParts[i] : 0;

      if (server > current) return true;
      if (server < current) return false;
    }
    return false;
  } catch (e) {
    debugPrint('❌ Error parsing version: $e');
    return false;
  }
}

// ================================================================
// CEK INITIAL SCREEN
// ================================================================
Future<Widget> checkInitialScreen() async {
  // 1. CEK MAINTENANCE
  try {
    debugPrint('🔍 Mengecek maintenance...');
    final maintenanceUri = Uri.parse('https://app.atlas-by-erlan.com/maintance');
    final response = await http.get(maintenanceUri).timeout(const Duration(seconds: 7));

    if (response.statusCode != 200) return const MaintancePage();

    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (e) {
      return const MaintancePage();
    }

    if (data is! Map<String, dynamic>) return const MaintancePage();

    final status = data['status'];
    if (status == true) return const MaintancePage();
    if (status != false) return const MaintancePage();
  } catch (e) {
    debugPrint('❌ Maintenance server offline/error: $e');
    return const MaintancePage();
  }

  // 2. CEK UPDATE
  try {
    debugPrint('🔍 Mengecek update aplikasi...');
    final packageInfo = await PackageInfo.fromPlatform();
    final String currentAppVersion = packageInfo.version;

    final updateUri = Uri.parse('https://app.atlas-by-erlan.com/update');
    final response = await http.get(updateUri).timeout(const Duration(seconds: 7));

    if (response.statusCode == 200) {
      dynamic data;
      try {
        data = jsonDecode(response.body);
      } catch (e) {
        data = null;
      }

      if (data is Map<String, dynamic>) {
        final String latestVersion = (data['version'] ?? '').toString().trim();
        if (latestVersion.isNotEmpty) {
          if (isUpdateRequired(currentAppVersion, latestVersion)) {
            return UpdatePage(
              currentVersion: currentAppVersion,
              latestVersion: latestVersion,
            );
          }
        }
      }
    }
  } catch (e) {
    debugPrint('⚠️ Error pengecekan update: $e');
  }

  // 3. CEK AUTO LOGIN
  try {
    debugPrint('🔍 Mengecek session login...');
    final prefs = await SharedPreferences.getInstance();

    final String? savedUser = prefs.getString('username');
    final String? savedPass = prefs.getString('password');
    final String? savedKey = prefs.getString('key');

    if (savedUser != null &&
        savedUser.isNotEmpty &&
        savedPass != null &&
        savedPass.isNotEmpty &&
        savedKey != null &&
        savedKey.isNotEmpty) {
      debugPrint('🔄 Mencoba auto-login...');

      String androidId = 'unknown_device';
      try {
        final deviceInfo = DeviceInfoPlugin();
        final android = await deviceInfo.androidInfo;
        androidId = android.id.isEmpty ? 'unknown_device' : android.id;
      } catch (e) {
        debugPrint('⚠️ Gagal mendapatkan Android ID: $e');
      }

      final uri = Uri.parse('https://app.atlas-by-erlan.com/myInfo').replace(
        queryParameters: {
          'username': savedUser,
          'password': savedPass,
          'androidId': androidId,
          'key': savedKey,
        },
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        dynamic data;
        try {
          data = jsonDecode(response.body);
        } catch (e) {
          data = null;
        }

        if (data is Map<String, dynamic>) {
          if (data['valid'] == true) {
            debugPrint('🟢 Auto-login berhasil.');
            return DashboardPage(
              username: savedUser,
              password: savedPass,
              role: data['role'],
              sessionKey: data['key'] ?? savedKey,
              expiredDate: data['expiredDate'],
              listBug: (data['listBug'] as List? ?? [])
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList(),
              news: (data['news'] as List? ?? [])
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList(),
            );
          }

          await prefs.remove('username');
          await prefs.remove('password');
          await prefs.remove('key');
        }
      }
    }
  } catch (e) {
    debugPrint('❌ Error pengecekan auto-login: $e');
  }

  // 4. BELUM LOGIN
  return LandingPage();
}

// ================================================================
// APP
// ================================================================
class MyApp extends StatefulWidget {
  final Widget initialScreen;

  const MyApp({
    super.key,
    required this.initialScreen,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    initDeepLinks();
  }

  // Fungsi untuk menangkap dan menghandle link yang masuk dari website
  Future<void> initDeepLinks() async {
    _appLinks = AppLinks();

    // Ketika aplikasi dibuka dari kondisi tertutup melalui website
    try {
      final initialUri = await _appLinks.getInitialAppLink();
      if (initialUri != null) {
        handleIncomingUri(initialUri);
      }
    } catch (e) {
      debugPrint('❌ Error getInitialAppLink: $e');
    }

    // Ketika aplikasi berjalan di background lalu diklik dari browser
    _appLinks.uriLinkStream.listen((uri) {
      handleIncomingUri(uri);
    }, onError: (err) {
      debugPrint('❌ Error uriLinkStream: $err');
    });
  }

  void handleIncomingUri(Uri uri) {
    debugPrint('🌐 Deep link diterima: $uri');
    // Contoh path handling: misal https://app.atlas-by-erlan.com/login
    if (uri.pathSegments.isNotEmpty) {
      final targetRoute = '/${uri.pathSegments.first}';
      navigatorKey.currentState?.pushNamed(targetRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      navigatorKey: navigatorKey, // ⬅️ PASANG NAVIGATOR KEY DI SINI
      debugShowCheckedModeBanner: false,
      title: 'ATLAS',
      theme: ThemeData(
        brightness: themeProvider.isDarkMode ? Brightness.dark : Brightness.light,
        fontFamily: 'ShareTechMono',
        scaffoldBackgroundColor: themeProvider.backgroundColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeProvider.primaryColor,
          brightness: themeProvider.isDarkMode ? Brightness.dark : Brightness.light,
        ).copyWith(
          primary: themeProvider.primaryColor,
          secondary: themeProvider.accentColor,
        ),
      ),
      home: widget.initialScreen,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => LandingPage());
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginPage());
          case '/maintance':
            return MaterialPageRoute(builder: (_) => const MaintancePage());
          case '/update':
            return MaterialPageRoute(builder: (_) => const UpdatePage());
          case '/dashboard':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
              builder: (_) => DashboardPage(
                username: args['username'] ?? '',
                password: args['password'] ?? '',
                role: args['role'] ?? '',
                sessionKey: args['key'] ?? args['sessionKey'] ?? '',
                expiredDate: args['expiredDate'] ?? '',
                listBug: List<Map<String, dynamic>>.from(args['listBug'] ?? []),
                news: List<Map<String, dynamic>>.from(args['news'] ?? []),
              ),
            );
          case '/home':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
              builder: (_) => HomePage(
                username: args['username'] ?? '',
                password: args['password'] ?? '',
                listBug: List<Map<String, dynamic>>.from(args['listBug'] ?? []),
                role: args['role'] ?? '',
                expiredDate: args['expiredDate'] ?? '',
                sessionKey: args['sessionKey'] ?? args['key'] ?? '',
              ),
            );
          case '/seller':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
              builder: (_) => SellerPage(
                keyToken: args['keyToken'] ?? args['sessionKey'] ?? '',
              ),
            );
          case '/admin':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
              builder: (_) => AdminPage(
                sessionKey: args['sessionKey'] ?? '',
              ),
            );
          case '/owner':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
              builder: (_) => OwnerPage(
                sessionKey: args['sessionKey'] ?? '',
                username: args['username'] ?? '',
              ),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(
                  child: Text('404 - Not Found'),
                ),
              ),
            );
        }
      },
    );
  }
}
