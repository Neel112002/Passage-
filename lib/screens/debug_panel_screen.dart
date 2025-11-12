import 'package:flutter/material.dart';
import 'package:passage/services/auth_store.dart';

class DebugPanelScreen extends StatelessWidget {
  const DebugPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AuthStore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Auth Debug Panel')),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final theme = Theme.of(context);
          final user = store.user;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Text('Auth State', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                _row('authReady', store.authReady.toString()),
                _row('user.id', user?.uid ?? 'null'),
                _row('email', user?.email ?? 'null'),
                _row('role', store.role ?? 'null'),
                _row('company_id', store.companyId ?? 'null'),
                _row('lastCheckedAt', store.lastCheckedAt?.toIso8601String() ?? 'null'),
                const SizedBox(height: 16),
                Text('Recent Auth Events (newest first)', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                ...store.events.take(10).map((e) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.bolt_outlined),
                      title: Text(e.message),
                      subtitle: Text(e.timestamp.toIso8601String()),
                    )),
                const SizedBox(height: 16),
                Text('Diffs (between successive snapshots)', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                _DiffViewer(snapshots: store.snapshots),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(k)),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.withValues(alpha: 0.08),
              ),
              child: Text(v),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiffViewer extends StatelessWidget {
  const _DiffViewer({required this.snapshots});
  final List<AuthSnapshot> snapshots;

  @override
  Widget build(BuildContext context) {
    final diffs = <String>[];
    for (int i = 1; i < snapshots.length; i++) {
      final a = snapshots[i - 1];
      final b = snapshots[i];
      final d = b.diff(a);
      if (d.isNotEmpty) {
        diffs.add('${b.timestamp.toIso8601String()} — ${d.join(' | ')}');
      }
    }
    if (diffs.isEmpty) {
      return const Text('No changes recorded yet.');
    }
    return Column(
      children: diffs.reversed
          .take(10)
          .map((line) => ListTile(
                dense: true,
                leading: const Icon(Icons.change_circle_outlined),
                title: Text(line),
              ))
          .toList(),
    );
  }
}
