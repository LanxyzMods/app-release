import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

/// Panggil ini dari floating button di halaman manapun:
void showColorSettingsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _ColorSettingsSheet(),
  ).then((_) {
    // Setelah bottom sheet ditutup, force refresh
    // Ini akan memicu rebuild semua widget yang menggunakan Provider
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    theme.notifyListeners(); // Force refresh
  });
}

class _ColorSettingsSheet extends StatelessWidget {
  const _ColorSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: theme.primaryColor.withOpacity(0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.25),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Row(
            children: [
              Icon(Icons.palette_outlined, color: theme.primaryColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'COLOR SETTINGS',
                style: TextStyle(
                  color: theme.primaryColor,
                  fontFamily: 'Orbitron',
                  fontSize: 13,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Dark mode toggle
              GestureDetector(
                onTap: () => theme.toggleDarkMode(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: theme.isDarkMode
                        ? theme.primaryColor.withOpacity(0.15)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.primaryColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        theme.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                        color: theme.primaryColor,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        theme.isDarkMode ? 'VXZ' : 'CR4SH',
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontSize: 10,
                          fontFamily: 'ShareTechMono',
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Preview bar
          Container(
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.primaryColor, theme.accentColor],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: theme.primaryColor.withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'PREVIEW WARNA AKTIF',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Orbitron',
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Label
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'PILIH PRESET WARNA',
              style: TextStyle(
                color: Colors.white54,
                fontFamily: 'ShareTechMono',
                fontSize: 10,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Color grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemCount: ThemeProvider.colorPresets.length,
            itemBuilder: (context, i) {
              final preset = ThemeProvider.colorPresets[i];
              final isActive = theme.isActivePreset(preset);
              return GestureDetector(
                onTap: () => theme.applyPreset(preset),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [preset.primary, preset.accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive ? Colors.white : Colors.transparent,
                      width: isActive ? 2.5 : 0,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: preset.primary.withOpacity(0.6),
                              blurRadius: 10,
                              spreadRadius: 2,
                            )
                          ]
                        : [],
                  ),
                  child: isActive
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Reset button
          TextButton.icon(
            onPressed: () {
              theme.resetToDefault();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.refresh, size: 14, color: Colors.white38),
            label: const Text(
              'Reset ke Default',
              style: TextStyle(
                color: Colors.white38,
                fontFamily: 'ShareTechMono',
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget floating palette button — taruh di Scaffold.floatingActionButton
/// atau Scaffold.bottomNavigationBar (Positioned)
class ColorSettingsFAB extends StatelessWidget {
  const ColorSettingsFAB({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = context.watch<ThemeProvider>().primaryColor;
    return FloatingActionButton(
      heroTag: 'colorFAB',
      mini: true,
      backgroundColor: primary.withOpacity(0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: primary.withOpacity(0.5), width: 1),
      ),
      onPressed: () => showColorSettingsSheet(context),
      child: Icon(Icons.palette_outlined, color: primary, size: 20),
    );
  }
}
