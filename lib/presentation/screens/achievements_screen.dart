import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/achievements.dart';
import '../app_state.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = AppScope.of(context).achievements;
    return Scaffold(
      appBar: AppBar(
        title: Text('Достижения ${service.unlockedCount}/$achievementTotal'),
        backgroundColor: AppColors.bg,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: achievementList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final a = achievementList[i];
                final done = service.isUnlocked(a.id);
                final progress = service.progress(a);
                final color = done ? AppColors.gold : AppColors.muted;
                final status = a.counter == null
                    ? (done ? 'получено' : 'не получено')
                    : '${service.currentValue(a)} из ${a.goal}';
                return Semantics(
                  container: true,
                  label: '${a.title}. ${a.description}. $status',
                  child: ExcludeSemantics(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(a.icon, size: 36, color: color),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.title,
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    a.description,
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (a.counter != null) ...[
                                    const SizedBox(height: 8),
                                    LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 6,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      status,
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (done)
                              const Icon(Icons.check_circle, color: AppColors.gold),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
