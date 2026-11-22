import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../domain/arkanoid_engine.dart';
import '../../domain/extra_mode.dart';
import '../../domain/models.dart';
import '../app_state.dart';
import '../painters.dart';
import '../widgets.dart';

class ArkanoidScreen extends StatefulWidget {
  /// [mode] == null — обычная игра; иначе один из Extra-режимов
  /// (рекорды и достижения в них не засчитываются).
  const ArkanoidScreen({super.key, this.mode});

  final ExtraMode? mode;

  @override
  State<ArkanoidScreen> createState() => _ArkanoidScreenState();
}

class _ArkanoidScreenState extends State<ArkanoidScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final ArkanoidEngine _engine;
  late final Ticker _ticker;
  late final AppState _app;
  Duration _last = Duration.zero;
  Offset? _down;
  double? _lastX;
  bool _newRecord = false;

  @override
  void initState() {
    super.initState();
    _app = AppScope.read(context);
    _engine = switch (widget.mode) {
      null => ArkanoidEngine(onEvent: _onEvent),
      ExtraMode.infiniteBalls => ArkanoidEngine(
          onEvent: _onEvent,
          maxBalls: 100,
          forcedDrop: PowerUpType.multi,
          multiplyAll: true,
        ),
      ExtraMode.doubleSpeed => ArkanoidEngine(
          onEvent: _onEvent,
          speedMultiplier: 2.0,
        ),
    };
    _app.achievements.onUnlocked = (a) {
      if (mounted) showAchievementToast(context, a.title, a.icon);
    };
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker((elapsed) {
      final dt = (elapsed - _last).inMicroseconds / 1e6;
      _last = elapsed;
      _engine.update(dt);
    })..start();
  }

  bool get _isExtra => widget.mode != null;

  void _onEvent(GameEvent e) {
    if (e is PowerUpCollected) HapticFeedback.lightImpact();
    if (e is LifeLost) HapticFeedback.mediumImpact();
    if (_isExtra) return; // Extra-режимы не влияют на рекорды и достижения
    _app.achievements.handleArkanoidEvent(e);
    if (e is GameOver) _newRecord = _app.submitArkanoidScore(e.score);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _engine.pause();
  }

  @override
  void dispose() {
    // выход посреди партии тоже сохраняет рекорд
    if (!_isExtra && _engine.phase != ArkanoidPhase.gameOver) {
      _app.submitArkanoidScore(_engine.score);
    }
    _app.achievements.onUnlocked = null;
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _engine.dispose();
    super.dispose();
  }

  void _handleUp(PointerUpEvent e) {
    final d = _down;
    _down = null;
    if (d != null && (e.localPosition - d).distance < 14) {
      if (_engine.phase == ArkanoidPhase.ready) _engine.launch();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _hud(context),
            Expanded(
              child: LayoutBuilder(
                builder: (context, cons) {
                  final t = WorldTransform.fit(Size(cons.maxWidth, cons.maxHeight));
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: Semantics(
                          label: 'Игровое поле Арканоид. Проведите пальцем в любом месте, чтобы двигать платформу',
                          child: Listener(
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: (e) {
                              _down = e.localPosition;
                              _lastX = e.localPosition.dx;
                            },
                            onPointerMove: (e) {
                              // относительное управление: платформа сдвигается
                              // на ту же величину, что и палец, где бы он ни был
                              final last = _lastX;
                              _lastX = e.localPosition.dx;
                              if (last != null && t.scale > 0) {
                                _engine.movePaddleBy((e.localPosition.dx - last) / t.scale);
                              }
                            },
                            onPointerUp: _handleUp,
                            child: CustomPaint(
                              painter: ArkanoidPainter(_engine),
                              size: Size.infinite,
                            ),
                          ),
                        ),
                      ),
                      Positioned(top: 6, left: 8, child: _bonusChips()),
                      Positioned.fill(child: _overlay()),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hud(BuildContext context) {
    return ListenableBuilder(
      listenable: _engine,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              IconButton(
                tooltip: 'В меню',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Semantics(
                label: 'Жизни: ${_engine.lives}',
                child: ExcludeSemantics(
                  child: Row(
                    children: [
                      for (var i = 0; i < ArkanoidEngine.startLives; i++)
                        Icon(
                          i < _engine.lives
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: AppColors.accent2,
                          size: 22,
                        ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _isExtra
                    ? 'Мячи ${_engine.balls.length}   Счёт ${_engine.score}'
                    : 'Уровень ${_engine.level}   Счёт ${_engine.score}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Пауза',
                onPressed: _engine.phase == ArkanoidPhase.gameOver
                    ? null
                    : _engine.pause,
                icon: const Icon(Icons.pause_rounded),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bonusChips() {
    return IgnorePointer(
      child: ListenableBuilder(
        listenable: _engine,
        builder: (context, _) => Row(
          children: [
            if (_engine.wideTimer > 0)
              BonusChip(
                icon: Icons.open_in_full_rounded,
                label: 'Платформа ${_engine.wideTimer.ceil()} с',
              ),
            if (_engine.fastTimer > 0)
              BonusChip(
                icon: Icons.fast_forward_rounded,
                label: 'Ускорение ${_engine.fastTimer.ceil()} с',
              ),
          ],
        ),
      ),
    );
  }

  Widget _overlay() {
    return ListenableBuilder(
      listenable: _engine,
      builder: (context, _) {
        if (_engine.paused) {
          return OverlayCard(
            title: 'Пауза',
            children: [
              FilledButton(onPressed: _engine.resume, child: const Text('Продолжить')),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('В меню'),
              ),
            ],
          );
        }
        switch (_engine.phase) {
          case ArkanoidPhase.ready:
            return const HintText(
              'Двигайте платформу пальцем.\nКоснитесь, чтобы запустить мяч',
            );
          case ArkanoidPhase.playing:
            return const SizedBox.shrink();
          case ArkanoidPhase.levelCleared:
            return OverlayCard(
              title: 'Уровень ${_engine.level} пройден!',
              children: [
                Text(
                  'Счёт: ${_engine.score}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _engine.nextLevel,
                  child: const Text('Следующий уровень'),
                ),
              ],
            );
          case ArkanoidPhase.gameOver:
            return OverlayCard(
              title: 'Игра окончена',
              children: [
                Text(
                  'Счёт: ${_engine.score}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  _isExtra
                      ? widget.mode!.title
                      : (_newRecord
                          ? 'Новый рекорд!'
                          : 'Рекорд: ${_app.arkanoidRecord}'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: AppColors.gold),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    _newRecord = false;
                    _engine.restart();
                  },
                  child: const Text('Играть снова'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('В меню'),
                ),
              ],
            );
        }
      },
    );
  }
}
