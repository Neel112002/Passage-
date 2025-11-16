import 'package:flutter/material.dart';
import 'package:passage/models/notification_prefs.dart';
import 'package:passage/services/local_notification_prefs_store.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  NotificationPrefs _prefs = NotificationPrefs.defaults();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await LocalNotificationPrefsStore.load();
    if (!mounted) return;
    setState(() {
      _prefs = p;
      _loading = false;
    });
  }

  Future<void> _save(NotificationPrefs p) async {
    setState(() => _prefs = p);
    try {
      await LocalNotificationPrefsStore.save(p);
    } catch (_) {}
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notification Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final disabledColor = theme.colorScheme.onSurface.withValues(alpha: 0.4);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Restore defaults?'),
                  content: const Text('All notification preferences will be reset.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore')),
                  ],
                ),
              );
              if (ok == true) {
                final def = NotificationPrefs.defaults();
                await _save(def);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preferences restored')));
              }
            },
            icon: const Icon(Icons.restart_alt, color: Colors.red),
            label: const Text('Reset'),
          )
        ],
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          // Master switch
          SwitchListTile.adaptive(
            value: _prefs.pushEnabled,
            onChanged: (v) async {
              await _save(_prefs.copyWith(pushEnabled: v));
            },
            title: const Text('Push notifications'),
            subtitle: const Text('Receive updates on your device'),
            secondary: const Icon(Icons.notifications_active_outlined, color: Colors.blue),
          ),
          const Divider(height: 1),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('Categories', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          _CategorySwitch(
            enabled: _prefs.pushEnabled,
            value: _prefs.promotions,
            icon: Icons.local_offer_outlined,
            color: Colors.deepOrange,
            title: 'Promotions',
            subtitle: 'Deals, coupons and special offers',
            onChanged: (v) => _save(_prefs.copyWith(promotions: v)),
          ),
          _CategorySwitch(
            enabled: _prefs.pushEnabled,
            value: _prefs.priceDrops,
            icon: Icons.trending_down_outlined,
            color: Colors.purple,
            title: 'Price drops',
            subtitle: 'Alerts when saved items get cheaper',
            onChanged: (v) => _save(_prefs.copyWith(priceDrops: v)),
          ),

          const Divider(height: 20),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('In-app', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          SwitchListTile.adaptive(
            value: _prefs.inAppSound,
            onChanged: _prefs.pushEnabled ? (v) => _save(_prefs.copyWith(inAppSound: v)) : null,
            title: const Text('Sound'),
            subtitle: Text(_prefs.pushEnabled ? 'Play a sound for in-app alerts' : 'Enable push notifications to manage this',
                style: TextStyle(color: _prefs.pushEnabled ? null : disabledColor)),
            secondary: const Icon(Icons.volume_up_outlined, color: Colors.blue),
          ),
          SwitchListTile.adaptive(
            value: _prefs.inAppVibrate,
            onChanged: _prefs.pushEnabled ? (v) => _save(_prefs.copyWith(inAppVibrate: v)) : null,
            title: const Text('Vibrate'),
            subtitle: Text(_prefs.pushEnabled ? 'Vibrate for in-app alerts' : 'Enable push notifications to manage this',
                style: TextStyle(color: _prefs.pushEnabled ? null : disabledColor)),
            secondary: const Icon(Icons.vibration_outlined, color: Colors.blue),
          ),

          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Note: This demo saves your preferences locally. You can connect Firebase later in Dreamflow to enable real push notifications.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _CategorySwitch extends StatelessWidget {
  final bool enabled;
  final bool value;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final ValueChanged<bool> onChanged;

  const _CategorySwitch({
    required this.enabled,
    required this.value,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = !enabled;
    final theme = Theme.of(context);
    return SwitchListTile.adaptive(
      value: value && enabled,
      onChanged: enabled ? onChanged : null,
      title: Text(title),
      subtitle: Text(
        disabled ? 'Enable push notifications to manage this' : subtitle,
        style: TextStyle(color: disabled ? theme.colorScheme.onSurface.withValues(alpha: 0.4) : null),
      ),
      secondary: CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, color: color),
      ),
    );
  }
}

// ignore: unused_element
class _TimePickerField extends StatelessWidget {
  final String label;
  final String value;
  final bool enabled;
  final VoidCallback onTap;
  const _TimePickerField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule, color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: enabled ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
