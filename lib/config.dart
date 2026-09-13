// ============================================================================
// API CONFIGURATION - RODSxRAT
// ============================================================================
//
// File ini berisi konfigurasi URL API untuk seluruh aplikasi.
// UBAH URL DI SINI untuk mengganti endpoint API secara global.
//
// ============================================================================

class ApiConfig {
  // Base URL untuk API (GANTI DI SINI)
  static const String baseUrl = "https://app.atlas-by-erlan.com";

  // Timeout untuk request (dalam detik)
  static const int connectionTimeout = 30;
  static const int receiveTimeout = 30;

  // Endpoint API
  static const String validateEndpoint = "$baseUrl/validate";
  static const String myInfoEndpoint = "$baseUrl/myInfo";
  static const String changePassEndpoint = "$baseUrl/changepass";
  static const String sendBugEndpoint = "$baseUrl/sendBug";
  static const String createAccountEndpoint = "$baseUrl/createAccount";
  static const String deleteUserEndpoint = "$baseUrl/deleteUser";
  static const String getPairingEndpoint = "$baseUrl/getPairing";
  static const String mySenderEndpoint = "$baseUrl/mySender";
  static const String globalSendersEndpoint = "$baseUrl/globalSenders";
  static const String addGlobalSenderEndpoint = "$baseUrl/addGlobalSender";
  static const String confirmGlobalSenderEndpoint =
      "$baseUrl/confirmGlobalSender";
  static const String deleteGlobalSenderEndpoint =
      "$baseUrl/deleteGlobalSender";
  static const String addServerEndpoint = "$baseUrl/addServer";
  static const String delServerEndpoint = "$baseUrl/delServer";
  static const String sendCommandEndpoint = "$baseUrl/sendCommand";
  static const String myServerEndpoint = "$baseUrl/myServer";
  static const String spamCallEndpoint = "$baseUrl/spamCall";
  static const String getInfoEndpoint = "$baseUrl/getInfo";

  // WebSocket URL
  static const String wsUrl = "https://app.atlas-by-erlan.com";

  // Chat Global Endpoints
  static const String getChatMessagesEndpoint = "$baseUrl/getChatMessages";
  static const String sendChatMessageEndpoint = "$baseUrl/sendChatMessage";
  static const String uploadChatMediaEndpoint = "$baseUrl/uploadChatMedia";
  static const String getChatRoomsEndpoint = "$baseUrl/getChatRooms";
  static const String getChatUsersEndpoint = "$baseUrl/getChatUsers";
}
