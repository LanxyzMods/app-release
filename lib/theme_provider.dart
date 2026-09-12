import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ====================================================
// MODEL PRESET WARNA
// ====================================================
class ColorPreset {
  final String name;
  final Color primary;
  final Color accent;

  const ColorPreset({
    required this.name,
    required this.primary,
    required this.accent,
  });
}

// ====================================================
// THEME PROVIDER (SIAP PAKE BUAT collorsetting.dart!)
// ====================================================
class ThemeProvider extends ChangeNotifier {
  // ========== DEFAULT COLOR ==========
  static const Color _defaultPrimary = Color(0xFF00E5FF); // Cyan
  static const Color _defaultAccent = Color(0xFFFF1744);  // Red

  Color _primaryColor = _defaultPrimary;
  Color _accentColor = _defaultAccent;
  bool _isDarkMode = true;
  int _currentPresetIndex = 0;

  // ========== GETTERS ==========
  Color get primaryColor => _primaryColor;
  Color get accentColor => _accentColor;
  bool get isDarkMode => _isDarkMode;

  // Warna-warna UI lainnya
  Color get backgroundColor => _isDarkMode ? const Color(0xFF0A0F1A) : const Color(0xFFF5F5F5);
  Color get textPrimaryColor => _isDarkMode ? Colors.white : Colors.black87;
  Color get textSecondaryColor => _isDarkMode ? Colors.white54 : Colors.black54;
  Color get glassPrimary => _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);
  Color get glassSecondary => _isDarkMode ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08);

  // ========== COLOR PRESETS (INI YANG MUNCUL DI GRID!) ==========
  static const List<ColorPreset> colorPresets = [
    ColorPreset(name: 'Neon Cyan', primary: Color(0xFF00E5FF), accent: Color(0xFFFF1744)),
    ColorPreset(name: 'Hijau', primary: Color(0xFF4CAF50), accent: Color(0xFF1B5E20)),
    ColorPreset(name: 'Biru', primary: Color(0xFF2196F3), accent: Color(0xFF0D47A1)),
    ColorPreset(name: 'Ungu', primary: Color(0xFF9C27B0), accent: Color(0xFF4A148C)),
    ColorPreset(name: 'Oranye', primary: Color(0xFFFF9800), accent: Color(0xFFE65100)),
    ColorPreset(name: 'Pink', primary: Color(0xFFE91E63), accent: Color(0xFF880E4F)),
    ColorPreset(name: 'Emas', primary: Color(0xFFFFD700), accent: Color(0xFF8B6914)),
    ColorPreset(name: 'Merah', primary: Color(0xFFF44336), accent: Color(0xFFB71C1C)),
    ColorPreset(name: 'Putih', primary: Color(0xFFFFFFFF), accent: Color(0xFFB0BEC5)),
    ColorPreset(name: 'Hitam', primary: Color(0xFF607D8B), accent: Color(0xFF263238)),
  ];

  // ========== CONSTRUCTOR ==========
  ThemeProvider() {
    _loadSavedTheme();
  }

  // ========== LOAD SAVED THEME ==========
  Future<void> _loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _currentPresetIndex = prefs.getInt('theme_preset_index') ?? 0;
    _isDarkMode = prefs.getBool('theme_dark_mode') ?? true;
    _applyPresetByIndex(_currentPresetIndex);
    notifyListeners();
  }

  // ========== SAVE THEME ==========
  Future<void> _saveTheme() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_preset_index', _currentPresetIndex);
    await prefs.setBool('theme_dark_mode', _isDarkMode);
  }

  // ========== APPLY PRESET BY OBJECT ==========
  void applyPreset(ColorPreset preset) {
    final index = colorPresets.indexWhere((p) => p.name == preset.name);
    if (index != -1) {
      _applyPresetByIndex(index);
      _saveTheme();
      notifyListeners();
    }
  }

  // ========== APPLY PRESET BY INDEX ==========
  void _applyPresetByIndex(int index) {
    if (index >= 0 && index < colorPresets.length) {
      _currentPresetIndex = index;
      _primaryColor = colorPresets[index].primary;
      _accentColor = colorPresets[index].accent;
    }
  }

  // ========== CEK APAKAH PRESET AKTIF ==========
  bool isActivePreset(ColorPreset preset) {
    return _primaryColor == preset.primary && _accentColor == preset.accent;
  }

  // ========== RESET KE DEFAULT ==========
  void resetToDefault() {
    _currentPresetIndex = 0;
    _primaryColor = _defaultPrimary;
    _accentColor = _defaultAccent;
    _saveTheme();
    notifyListeners();
  }

  // ========== TOGGLE DARK MODE ==========
  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    _saveTheme();
    notifyListeners();
  }

  // ========== SET DARK MODE ==========
  void setDarkMode(bool value) {
    _isDarkMode = value;
    _saveTheme();
    notifyListeners();
  }
}