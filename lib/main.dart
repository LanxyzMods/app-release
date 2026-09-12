import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ============================================================
  // CEK INITIAL SCREEN
  // ============================================================

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

      // Server lebih baru
      if (server > current) {
        return true;
      }

      // Server lebih lama
      if (server < current) {
        return false;
      }
    }

    // Sama
    return false;
  } catch (e) {
    debugPrint('❌ Error parsing version: $e');

    // Kalau format versi server aneh,
    // jangan memaksa update.
    return false;
  }
}

// ================================================================
// CEK INITIAL SCREEN
// URUTAN:
//
// 1. MAINTENANCE
// 2. UPDATE
// 3. AUTO LOGIN
// 4. LANDING
// ================================================================

Future<Widget> checkInitialScreen() async {
  // ==============================================================
  // 1. CEK MAINTENANCE
  // ==============================================================

  try {
    debugPrint('🔍 Mengecek maintenance...');

    final maintenanceUri = Uri.parse('https://app.atlas-by-erlan.com/maintance');

    final response = await http.get(maintenanceUri).timeout(
          const Duration(seconds: 7),
        );

    debugPrint(
      '📡 Maintenance response: ${response.statusCode}',
    );

    // --------------------------------------------------------------
    // Kalau HTTP bukan 200
    // --------------------------------------------------------------

    if (response.statusCode != 200) {
      debugPrint(
        '❌ Maintenance API HTTP error: ${response.statusCode}',
      );

      return const MaintancePage();
    }

    // --------------------------------------------------------------
    // Decode JSON
    // --------------------------------------------------------------

    dynamic data;

    try {
      data = jsonDecode(response.body);
    } catch (e) {
      debugPrint(
        '❌ Response maintenance bukan JSON valid: $e',
      );

      return const MaintancePage();
    }

    // --------------------------------------------------------------
    // Pastikan response berupa object/map
    // --------------------------------------------------------------

    if (data is! Map<String, dynamic>) {
      debugPrint(
        '❌ Format maintenance tidak valid.',
      );

      return const MaintancePage();
    }

    // --------------------------------------------------------------
    // Ambil status
    // --------------------------------------------------------------

    final status = data['status'];

    debugPrint(
      '🛠️ Maintenance status: $status',
    );

    // ==============================================================
    // STATUS TRUE = MAINTENANCE
    // ==============================================================

    if (status == true) {
      debugPrint(
        '🔴 Maintenance aktif.',
      );

      return const MaintancePage();
    }

    // ==============================================================
    // STATUS FALSE = LANJUT NORMAL
    // ==============================================================

    if (status == false) {
      debugPrint(
        '🟢 Maintenance tidak aktif.',
      );
    }

    // ==============================================================
    // STATUS SELAIN TRUE/FALSE
    //
    // Contoh:
    // {"status":"test"}
    // {"status":1}
    // {"status":null}
    //
    // Semuanya dianggap MAINTENANCE.
    // ==============================================================

    else {
      debugPrint(
        '⚠️ Status maintenance tidak valid: $status',
      );

      return const MaintancePage();
    }
  } catch (e) {
    // ==============================================================
    // SERVER MATI / INTERNET ERROR / TIMEOUT
    //
    // Sesuai permintaan:
    // kalau maintenance API tidak bisa diakses,
    // otomatis masuk MaintancePage.
    // ==============================================================

    debugPrint(
      '❌ Maintenance server offline/error: $e',
    );

    return const MaintancePage();
  }

  // ==============================================================
  // 2. CEK UPDATE
  // ==============================================================

  try {
    debugPrint('🔍 Mengecek update aplikasi...');

    // --------------------------------------------------------------
    // Ambil versi aplikasi langsung dari APK
    //
    // Contoh pubspec:
    //
    // version: 1.0.0+1
    //
    // packageInfo.version = 1.0.0
    // packageInfo.buildNumber = 1
    //
    // Yang dibandingkan dengan API adalah 1.0.0
    // --------------------------------------------------------------

    final packageInfo = await PackageInfo.fromPlatform();

    final String currentAppVersion = packageInfo.version;

    debugPrint(
      '📱 Versi aplikasi: $currentAppVersion',
    );

    // --------------------------------------------------------------
    // Request update API
    // --------------------------------------------------------------

    final updateUri = Uri.parse('https://app.atlas-by-erlan.com/update');

    final response = await http.get(updateUri).timeout(
          const Duration(seconds: 7),
        );

    debugPrint(
      '📡 Update response: ${response.statusCode}',
    );

    // --------------------------------------------------------------
    // Kalau server update error
    //
    // Berbeda dengan maintenance:
    // update API error tidak membuat aplikasi masuk
    // MaintenancePage.
    //
    // Aplikasi lanjut normal.
    // --------------------------------------------------------------

    if (response.statusCode != 200) {
      debugPrint(
        '⚠️ Update API HTTP error: ${response.statusCode}',
      );
    } else {
      dynamic data;

      try {
        data = jsonDecode(response.body);
      } catch (e) {
        debugPrint(
          '⚠️ Response update bukan JSON valid: $e',
        );

        data = null;
      }

      // ------------------------------------------------------------
      // Pastikan JSON valid dan berupa Map
      // ------------------------------------------------------------

      if (data is Map<String, dynamic>) {
        final String latestVersion =
            (data['version'] ?? '').toString().trim();

        debugPrint(
          '🌐 Versi terbaru server: $latestVersion',
        );

        // ----------------------------------------------------------
        // Kalau versi server valid
        // ----------------------------------------------------------

        if (latestVersion.isNotEmpty) {
          final bool updateRequired = isUpdateRequired(
            currentAppVersion,
            latestVersion,
          );

          debugPrint(
            '📦 Update diperlukan: $updateRequired',
          );

          // --------------------------------------------------------
          // Versi server lebih tinggi
          // --------------------------------------------------------

          if (updateRequired) {
            debugPrint(
              '🔴 Aplikasi harus update.',
            );

            return UpdatePage(
              currentVersion: currentAppVersion,
              latestVersion: latestVersion,
            );
          }

          debugPrint(
            '🟢 Aplikasi sudah versi terbaru.',
          );
        } else {
          debugPrint(
            '⚠️ Field version kosong.',
          );
        }
      } else {
        debugPrint(
          '⚠️ Format response update tidak valid.',
        );
      }
    }
  } catch (e) {
    // ==============================================================
    // Kalau update server mati / timeout
    //
    // Aplikasi tetap boleh lanjut normal.
    // ==============================================================

    debugPrint(
      '⚠️ Error pengecekan update: $e',
    );
  }

  // ==============================================================
  // 3. CEK AUTO LOGIN
  // ==============================================================

  try {
    debugPrint('🔍 Mengecek session login...');

    final prefs = await SharedPreferences.getInstance();

    final String? savedUser = prefs.getString('username');
    final String? savedPass = prefs.getString('password');
    final String? savedKey = prefs.getString('key');

    debugPrint(
      '👤 Username tersimpan: ${savedUser != null}',
    );

    debugPrint(
      '🔑 Password tersimpan: ${savedPass != null}',
    );

    debugPrint(
      '🎫 Session key tersimpan: ${savedKey != null}',
    );

    // --------------------------------------------------------------
    // Kalau semua data login tersedia
    // --------------------------------------------------------------

    if (savedUser != null &&
        savedUser.isNotEmpty &&
        savedPass != null &&
        savedPass.isNotEmpty &&
        savedKey != null &&
        savedKey.isNotEmpty) {
      debugPrint(
        '🔄 Mencoba auto-login...',
      );

      // ------------------------------------------------------------
      // Ambil Android ID
      // ------------------------------------------------------------

      String androidId = 'unknown_device';

      try {
        final deviceInfo = DeviceInfoPlugin();
        final android = await deviceInfo.androidInfo;

        androidId = android.id;

        if (androidId.isEmpty) {
          androidId = 'unknown_device';
        }
      } catch (e) {
        debugPrint(
          '⚠️ Gagal mendapatkan Android ID: $e',
        );
      }

      // ------------------------------------------------------------
      // Encode parameter agar username/password aman
      // ------------------------------------------------------------

      final uri = Uri.parse('https://app.atlas-by-erlan.com/myInfo').replace(
        queryParameters: {
          'username': savedUser,
          'password': savedPass,
          'androidId': androidId,
          'key': savedKey,
        },
      );

      // ------------------------------------------------------------
      // Request session
      // ------------------------------------------------------------

      final response = await http.get(uri).timeout(
            const Duration(seconds: 10),
          );

      debugPrint(
        '📡 Auto-login response: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        dynamic data;

        try {
          data = jsonDecode(response.body);
        } catch (e) {
          debugPrint(
            '❌ Response myInfo bukan JSON valid: $e',
          );

          data = null;
        }

        // ----------------------------------------------------------
        // Pastikan response Map
        // ----------------------------------------------------------

        if (data is Map<String, dynamic>) {
          // --------------------------------------------------------
          // Session masih valid
          // --------------------------------------------------------

          if (data['valid'] == true) {
            debugPrint(
              '🟢 Auto-login berhasil.',
            );

            return DashboardPage(
              username: savedUser,
              password: savedPass,
              role: data['role'],
              sessionKey: data['key'] ?? savedKey,
              expiredDate: data['expiredDate'],
              listBug: (data['listBug'] as List? ?? [])
                  .map(
                    (e) => Map<String, dynamic>.from(
                      e as Map,
                    ),
                  )
                  .toList(),
              news: (data['news'] as List? ?? [])
                  .map(
                    (e) => Map<String, dynamic>.from(
                      e as Map,
                    ),
                  )
                  .toList(),
            );
          }

          // --------------------------------------------------------
          // Session tidak valid
          // --------------------------------------------------------

          debugPrint(
            '🔴 Session login sudah tidak valid.',
          );

          // Hapus session supaya user tidak terjebak
          // dengan akun yang sudah invalid.
          await prefs.remove('username');
          await prefs.remove('password');
          await prefs.remove('key');
        }
      }
    }
  } catch (e) {
    debugPrint(
      '❌ Error pengecekan auto-login: $e',
    );
  }

  // ==============================================================
  // 4. BELUM LOGIN
  // ==============================================================

  debugPrint(
    '➡️ Masuk ke LandingPage.',
  );

  return LandingPage();
}

// ================================================================
// APP
// ================================================================

class MyApp extends StatelessWidget {
  final Widget initialScreen;

  const MyApp({
    super.key,
    required this.initialScreen,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'ATLAS',

      theme: ThemeData(
        brightness: themeProvider.isDarkMode
            ? Brightness.dark
            : Brightness.light,

        fontFamily: 'ShareTechMono',

        scaffoldBackgroundColor:
            themeProvider.backgroundColor,

        colorScheme: ColorScheme.fromSeed(
          seedColor: themeProvider.primaryColor,

          brightness: themeProvider.isDarkMode
              ? Brightness.dark
              : Brightness.light,
        ).copyWith(
          primary: themeProvider.primaryColor,
          secondary: themeProvider.accentColor,
        ),
      ),

      // ============================================================
      // INITIAL SCREEN
      // ============================================================

      home: initialScreen,

      // ============================================================
      // ROUTES
      // ============================================================

      onGenerateRoute: (settings) {
        switch (settings.name) {
          // --------------------------------------------------------
          // LANDING
          // --------------------------------------------------------

          case '/':
            return MaterialPageRoute(
              builder: (_) => LandingPage(),
            );

          // --------------------------------------------------------
          // LOGIN
          // --------------------------------------------------------

          case '/login':
            return MaterialPageRoute(
              builder: (_) => const LoginPage(),
            );

          // --------------------------------------------------------
          // MAINTENANCE
          // --------------------------------------------------------

          case '/maintance':
            return MaterialPageRoute(
              builder: (_) => const MaintancePage(),
            );

          // --------------------------------------------------------
          // UPDATE
          // --------------------------------------------------------

          case '/update':
            return MaterialPageRoute(
              builder: (_) => const UpdatePage(),
            );

          // --------------------------------------------------------
          // DASHBOARD
          // --------------------------------------------------------

          case '/dashboard':
            final args =
                settings.arguments as Map<String, dynamic>;

            return MaterialPageRoute(
              builder: (_) => DashboardPage(
                username: args['username'],
                password: args['password'],
                role: args['role'],
                sessionKey: args['key'] ?? args['sessionKey'],
                expiredDate: args['expiredDate'],

                listBug:
                    List<Map<String, dynamic>>.from(
                  args['listBug'] ?? [],
                ),

                news:
                    List<Map<String, dynamic>>.from(
                  args['news'] ?? [],
                ),
              ),
            );

          // --------------------------------------------------------
          // HOME
          // --------------------------------------------------------

          case '/home':
            final args =
                settings.arguments as Map<String, dynamic>;

            return MaterialPageRoute(
              builder: (_) => HomePage(
                username: args['username'],
                password: args['password'],

                listBug:
                    List<Map<String, dynamic>>.from(
                  args['listBug'] ?? [],
                ),

                role: args['role'],
                expiredDate: args['expiredDate'],

                sessionKey:
                    args['sessionKey'] ?? args['key'],
              ),
            );

          // --------------------------------------------------------
          // SELLER
          // --------------------------------------------------------

          case '/seller':
            final args =
                settings.arguments as Map<String, dynamic>;

            return MaterialPageRoute(
              builder: (_) => SellerPage(
                keyToken:
                    args['keyToken'] ?? args['sessionKey'],
              ),
            );

          // --------------------------------------------------------
          // ADMIN
          // --------------------------------------------------------

          case '/admin':
            final args =
                settings.arguments as Map<String, dynamic>;

            return MaterialPageRoute(
              builder: (_) => AdminPage(
                sessionKey: args['sessionKey'],
              ),
            );

          // --------------------------------------------------------
          // OWNER
          // --------------------------------------------------------

          case '/owner':
            final args =
                settings.arguments as Map<String, dynamic>;

            return MaterialPageRoute(
              builder: (_) => OwnerPage(
                sessionKey: args['sessionKey'],
                username: args['username'],
              ),
            );

          // --------------------------------------------------------
          // 404
          // --------------------------------------------------------

          default:
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(
                  child: Text(
                    '404 - Not Found',
                  ),
                ),
              ),
            );
        }
      },
    );
  }
}