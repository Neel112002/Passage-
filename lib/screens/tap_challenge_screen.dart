import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:passage/services/local_points_store.dart';

class TapChallengeScreen extends StatefulWidget {
  const TapChallengeScreen({super.key});

  @override
  State<TapChallengeScreen> createState() => _TapChallengeScreenState();
}

class _TapChallengeScreenState extends State<TapChallengeScreen> {
  static const int roundSeconds = 30;
  static const double targetSize = 56;

  bool _running = false;
  int _timeLeft = roundSeconds;
  int _hits = 0;
  late Timer _timer;
  final math.Random _rng = math.Random();

  // Target position (top, left) in the playfield
  double _top = 120;
  double _left = 120;

  @override
  void dispose() {
    if (_running) {
      _timer.cancel();
    }
    super.dispose();
  }

  void _start() {
    setState(() {
      _running = true;
      _timeLeft = roundSeconds;
      _hits = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timeLeft <= 1) {
        t.cancel();
        setState(() {
          _running = false;
          _timeLeft = 0;
        });
        _finishRound();
      } else {
        setState(() => _timeLeft -= 1);
      }
    });
  }

  void _moveTarget(BoxConstraints c) {
    final maxTop = c.maxHeight - targetSize - 12; // padding
    final maxLeft = c.maxWidth - targetSize - 12;
    setState(() {
      _top = 6 + _rng.nextDouble() * math.max(6, maxTop);
      _left = 6 + _rng.nextDouble() * math.max(6, maxLeft);
    });
  }

  Future<void> _finishRound() async {
    final earned = _hits; // 1 point per hit
    await LocalPointsStore.addPoints(earned, reason: 'TapChallenge');
    if (!mounted) return;
    final earnedCash = LocalPointsStore.pointsToCash(earned);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.stars_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Round complete', style: TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _metric(label: 'Hits', value: _hits.toString(), color: Colors.teal),
                  const SizedBox(width: 12),
                  _metric(label: 'Points', value: '+$earned', color: Colors.orange),
                  const SizedBox(width: 12),
                  _metric(label: 'Value', value: '+${LocalPointsStore.formatCash(earnedCash)}', color: Colors.green),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.blue),
                      label: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _start();
                      },
                      icon: const Icon(Icons.replay, color: Colors.white),
                      label: const Text('Play again'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tap Challenge')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      _infoPill(icon: Icons.timer, color: Colors.blue, text: '${_timeLeft}s'),
                      const SizedBox(width: 8),
                      _infoPill(icon: Icons.bolt_rounded, color: Colors.teal, text: 'Hits: $_hits'),
                      const Spacer(),
                      ValueListenableBuilder<int>(
                        valueListenable: LocalPointsStore.pointsNotifier,
                        builder: (context, points, _) {
                          final cash = LocalPointsStore.pointsToCash(points);
                          return _infoPill(icon: Icons.stars_rounded, color: Colors.orange, text: '$points pts · ${LocalPointsStore.formatCash(cash)}');
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Stack(
                      children: [
                        // Playfield border
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                            ),
                          ),
                        ),
                        if (!_running) _preGameOverlay(),
                        if (_running)
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.easeOut,
                            top: _top,
                            left: _left,
                            child: _TargetButton(
                              onTap: () {
                                setState(() => _hits += 1);
                                _moveTarget(constraints);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _preGameOverlay() {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: theme.colorScheme.surface.withValues(alpha: 0.9),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded, color: Colors.teal, size: 48),
              const SizedBox(height: 12),
              Text('Tap Challenge', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                'Hit as many targets as you can in 30 seconds.\nEach hit earns 1 point.\nEvery 1000 points = \$0.50.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoPill({required IconData icon, required Color color, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _metric({required String label, required String value, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.25)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.circle, color: color, size: 10),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(value, style: TextStyle(fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }
}

class _TargetButton extends StatelessWidget {
  const _TargetButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: _TapChallengeScreenState.targetSize,
          height: _TapChallengeScreenState.targetSize,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Colors.teal, Colors.cyan],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
            ],
          ),
          child: const Center(
            child: Icon(Icons.touch_app, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
