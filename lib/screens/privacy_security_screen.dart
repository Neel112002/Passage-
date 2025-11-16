import 'package:flutter/material.dart';
import 'package:passage/services/local_auth_store.dart';
import 'package:passage/services/local_user_profile_store.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  LocalAuthState? _auth;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final a = await LocalAuthStore.load();
      await LocalUserProfileStore.load();
      if (!mounted) return;
      setState(() {
        _auth = a;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }


  Future<void> _toggleBiometric(bool v) async {
    await LocalAuthStore.setBiometricEnabled(v);
    final s = await LocalAuthStore.load();
    if (!mounted) return;
    setState(() => _auth = s);
  }




  Future<void> _changePassword() async {
    final hasPw = await LocalAuthStore.hasPassword();
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        final bottom = MediaQuery.of(context).viewInsets.bottom;
        return StatefulBuilder(builder: (context, setLocal) {
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lock_reset, color: Colors.red),
                        const SizedBox(width: 8),
                        Text('Change password', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        const Spacer(),
                        IconButton(onPressed: () => Navigator.pop(context, false), icon: const Icon(Icons.close)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (hasPw)
                      TextFormField(
                        controller: currentController,
                        obscureText: obscureCurrent,
                        decoration: InputDecoration(
                          labelText: 'Current password',
                          prefixIcon: const Icon(Icons.vpn_key_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setLocal(() => obscureCurrent = !obscureCurrent),
                          ),
                        ),
                        validator: (v) {
                          if ((v ?? '').isEmpty) return 'Enter your current password';
                          return null;
                        },
                      ),
                    if (hasPw) const SizedBox(height: 12),
                    TextFormField(
                      controller: newController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'New password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setLocal(() => obscureNew = !obscureNew),
                        ),
                      ),
                      validator: (v) {
                        final t = (v ?? '');
                        if (t.length < 8) return 'At least 8 characters';
                        if (!t.contains(RegExp(r'[A-Z]'))) return 'Add an uppercase letter';
                        if (!t.contains(RegExp(r'[a-z]'))) return 'Add a lowercase letter';
                        if (!t.contains(RegExp(r'[0-9]'))) return 'Add a number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm new password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setLocal(() => obscureConfirm = !obscureConfirm),
                        ),
                      ),
                      validator: (v) {
                        if (v != newController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context, false),
                            icon: const Icon(Icons.close, color: Colors.red),
                            label: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              if (hasPw) {
                                final valid = await LocalAuthStore.verifyPassword(currentController.text);
                                if (!valid) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Current password is incorrect')));
                                  }
                                  return;
                                }
                              }
                              Navigator.pop(context, true);
                            },
                            icon: const Icon(Icons.check_circle, color: Colors.green),
                            label: const Text('Update'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );

    if (ok == true) {
      await LocalAuthStore.setPassword(newController.text);
      if (!mounted) return;
      final s = await LocalAuthStore.load();
      setState(() => _auth = s);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated')));
    }
  }

  Future<void> _signOutOthers() async {
    await LocalAuthStore.updateSessions(signOutOthers: true);
    final s = await LocalAuthStore.load();
    if (!mounted) return;
    setState(() => _auth = s);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Other sessions signed out')));
  }

  Future<void> _signOutAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out of all devices?'),
        content: const Text('You will be signed out from all other devices. This device will remain active.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out all')),
        ],
      ),
    );
    if (ok == true) {
      await LocalAuthStore.updateSessions(signOutAll: true);
      final s = await LocalAuthStore.load();
      if (!mounted) return;
      setState(() => _auth = s);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed out of all sessions')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Security')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _SectionCard(children: [
                    ListTile(
                      leading: _tileIcon(Icons.lock_reset_rounded, Colors.red),
                      title: const Text('Change password'),
                      subtitle: Text(_auth?.lastPasswordChangeMs != null
                          ? 'Updated '+_timeAgo(_auth!.lastPasswordChangeMs!)
                          : 'Never set'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _changePassword,
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _SectionCard(children: [
                    SwitchListTile(
                      secondary: _tileIcon(Icons.fingerprint_rounded, Colors.purple),
                      title: const Text('Biometric unlock'),
                      subtitle: const Text('Use Face ID / Touch ID to unlock the app'),
                      value: _auth?.biometricEnabled ?? false,
                      onChanged: (v) => _toggleBiometric(v),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _SectionCard(children: [
                    ListTile(
                      leading: _tileIcon(Icons.devices_other_rounded, Colors.orange),
                      title: const Text('Devices & sessions'),
                      subtitle: Text('${_auth?.sessions.length ?? 1} session(s) active'),
                    ),
                    ...(_auth?.sessions ?? []).map((s) => Column(
                          children: [
                            const Divider(height: 0),
                            ListTile(
                              title: Text(s.deviceName),
                              subtitle: Text(s.platform + ' • Last active: ' + _formatTime(s.lastActiveMs)),
                              trailing: s.isCurrent
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Text('Current', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                                    )
                                  : null,
                            ),
                          ],
                        )),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _signOutOthers,
                              icon: const Icon(Icons.logout, color: Colors.red),
                              label: const Text('Sign out others'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _signOutAll,
                              icon: const Icon(Icons.logout, color: Colors.red),
                              label: const Text('Sign out all'),
                            ),
                          ),
                        ],
                      ),
                    )
                  ]),
                  const SizedBox(height: 12),
                  _SectionCard(children: [
                    ListTile(
                      leading: _tileIcon(Icons.delete_outline, Colors.red),
                      title: const Text('Delete account'),
                      subtitle: const Text('Permanently remove your data on this device'),
                      onTap: _deleteAccount,
                    ),
                  ]),
                ],
              ),
            ),
    );
  }

  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text('This will clear your local profile and security settings on this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await LocalUserProfileStore.clear();
      } catch (_) {}
      try {
        await LocalAuthStore.clear();
      } catch (_) {}
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account data cleared on this device')));
    }
  }

  Widget _tileIcon(IconData icon, Color color) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: color.withOpacity(0.12),
      child: Icon(icon, color: color),
    );
  }

  String _timeAgo(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays >= 1) return '${diff.inDays} day(s) ago';
    if (diff.inHours >= 1) return '${diff.inHours} hour(s) ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes} minute(s) ago';
    return 'just now';
  }

  String _formatTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (isToday) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}
