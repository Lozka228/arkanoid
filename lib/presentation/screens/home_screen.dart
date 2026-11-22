import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../domain/achievements.dart';
import '../app_state.dart';
import 'achievements_screen.dart';
import 'arkanoid_screen.dart';
import 'extra_screen.dart';
import 'fuseball_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _open(BuildContext context, Widget screen) async {
    final app = AppScope.read(context);
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    app.refresh();
  }

  Future<void> _confirmExit(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выйти из игры?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final unlocked = app.achievements.unlockedCount;
    final total = achievementTotal;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ExcludeSemantics(child: _LogoBricks()),
                  const SizedBox(height: 16),
                  Semantics(
                    header: true,
                    child: Text(
                      'АРКАНОИД',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineLarge,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _RecordTile(
                          label: 'Рекорд\nАрканоид',
                          value: app.arkanoidRecord,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RecordTile(
                          label: 'Рекорд\nFuseball',
                          value: app.fuseballRecord,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _open(context, const ArkanoidScreen()),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Играть в Арканоид'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () => _open(context, const FuseballScreen()),
                    icon: const Icon(Icons.sports_basketball_rounded),
                    label: const Text('Играть в Fuseball'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _open(context, const AchievementsScreen()),
                    icon: const Icon(Icons.emoji_events_outlined),
                    label: Text('Достижения ($unlocked/$total)'),
                  ),
                  if (unlocked == total) ...[
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: () => _open(context, const ExtraScreen()),
                      icon: const Icon(Icons.star_rounded),
                      label: const Text('Extra'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => _confirmExit(context),
                    icon: const Icon(Icons.exit_to_app_rounded),
                    label: const Text('Выход'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '${label.replaceAll('\n', ' ')}: $value',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold.withAlpha(120)),
          ),
          child: Column(
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                '$value',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoBricks extends StatelessWidget {
  const _LogoBricks();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final c in AppColors.brickRows.take(6))
          Container(
            width: 36,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}
