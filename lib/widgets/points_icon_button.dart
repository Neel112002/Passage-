import 'package:flutter/material.dart';
import 'package:passage/services/local_points_store.dart';
import 'package:passage/screens/games_hub_screen.dart';

class PointsIconButton extends StatelessWidget {
  final Color iconColor;
  final VoidCallback? onPressed;
  const PointsIconButton({super.key, this.iconColor = Colors.orange, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ValueListenableBuilder<int>(
        valueListenable: LocalPointsStore.pointsNotifier,
        builder: (context, points, _) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: onPressed ?? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GamesHubScreen()),
                  );
                },
                icon: const Icon(Icons.sports_esports_outlined, color: Colors.orange),
                tooltip: 'Play & Earn',
              ),
              Positioned(
                right: 2,
                top: 2,
                child: _PointsBadge(points: points),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PointsBadge extends StatelessWidget {
  final int points;
  const _PointsBadge({required this.points});

  @override
  Widget build(BuildContext context) {
    final display = points > 999 ? '${(points / 1000).toStringAsFixed(1)}k' : points.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1))],
      ),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 18),
      child: Center(
        child: Text(
          display,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
