import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripgenie/core/constants/app_colors.dart';
import 'package:tripgenie/core/routes/app_routes.dart';
import 'package:tripgenie/core/services/auth_api_service.dart';
import 'package:tripgenie/core/services/app_data_reset_service.dart';
import 'package:tripgenie/features/onboarding/screens/onboarding_screen.dart';
import 'package:tripgenie/main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _darkMode = prefs.getBool('dark_mode') ?? false;
      });
    }
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor, elevation: 0,
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader('Preferences'),
          _SettingsTile(
            icon: Icons.notifications_outlined, title: 'Notifications',
            subtitle: 'Receive chat and trip updates',
            trailing: Switch(
              value: _notificationsEnabled,
              activeColor: AppColors.primary,
              onChanged: (v) { setState(() => _notificationsEnabled = v); _savePreference('notifications_enabled', v); },
            ),
          ),
          _SettingsTile(
            icon: Icons.dark_mode_outlined, title: 'Dark Mode',
            subtitle: 'Switch between light and dark theme',
            trailing: Switch(
              value: _darkMode,
              activeColor: AppColors.primary,
              onChanged: (v) { 
                setState(() => _darkMode = v); 
                _savePreference('dark_mode', v); 
                themeNotifier.value = v ? ThemeMode.dark : ThemeMode.light;
              },
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader('Data'),
          _SettingsTile(
            icon: Icons.delete_outline, title: 'Clear Cache',
            subtitle: 'Remove offline data and cached images',
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear Cache?'),
                  content: const Text('This will clear all cached data. You will need to re-download content.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
                  ],
                ),
              );
              if (confirm == true) {
                await AppDataResetService.clearLocalClientState();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache cleared')));
              }
            },
          ),
          const SizedBox(height: 24),
          _SectionHeader('Help'),
          _SettingsTile(
            icon: Icons.play_circle_outline, title: 'Replay Onboarding',
            subtitle: 'Watch the app walkthrough again',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OnboardingScreen(isReplay: true)));
            },
          ),
          const SizedBox(height: 24),
          _SectionHeader('About'),
          _SettingsTile(icon: Icons.info_outline, title: 'Version', subtitle: '2.0.0'),
          _SettingsTile(icon: Icons.code, title: 'Built with', subtitle: 'Flutter + SQLite + Firebase'),
          const SizedBox(height: 32),
          Center(
            child: TextButton(
              onPressed: () async {
                await AuthApiService.logout();
                if (mounted) context.go(AppRoutes.login);
              },
              child: const Text('Sign Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant)),
  );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({required this.icon, required this.title, this.subtitle = '', this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: subtitle.isNotEmpty ? Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)) : null,
        trailing: trailing ?? (onTap != null ? Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.outline) : null),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
