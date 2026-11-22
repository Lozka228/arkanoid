import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/theme.dart';
import '../../domain/fuseball_engine.dart';
import '../app_state.dart';
import '../painters.dart';
import '../widgets.dart';

class FuseballScreen extends StatefulWidget {
  const FuseballScreen({super.key});

  @override
  State<FuseballScreen> createState() => _FuseballScreenState();
}

class _FuseballScreenState extends State<FuseballScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final FuseballEngine _engine;
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
    _engine = FuseballEngine(
      onScore: _app.achievements.handleFuseballScore,
      onGameOver: (s) => _newRecord = _app.submitFuseballScore(s),
    );
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _engine.pause();
  }

  @override
  void dispose() {
    if (_engine.phase != FusePhase.gameOver) {
      _app.submitFuseballScore(_engine.score);
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
      if (_engine.phase == FusePhase.ready) _engine.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _hud(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, cons) {
                  final t = WorldTransform.fit(Size(cons.maxWidth, cons.maxHeight));
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: Semantics(
                          label: 'Игровое поле Fuseball. Проведите пальцем в любом месте, чтобы двигать платформу',
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
                              painter: FuseballPainter(_engine),
                              size: Size.infinite,
                            ),
                          ),
                        ),
                      ),
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

  Widget _hud() {
    return ListenableBuilder(
      listenable: _engine,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            IconButton(
              tooltip: 'В меню',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const Spacer(),
            Text(
              'Счёт ${_engine.score}   Рекорд ${_app.fuseballRecord}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Пауза',
              onPressed: _engine.phase == FusePhase.gameOver ? null : _engine.pause,
              icon: const Icon(Icons.pause_rounded),
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
          case FusePhase.ready:
            return const HintText(
              'Подбрасывайте мяч платформой и попадайте в кирпич.\nКоснитесь, чтобы начать',
            );
          case FusePhase.playing:
            return const SizedBox.shrink();
          case FusePhase.gameOver:
            return OverlayCard(
              title: 'Мяч упал',
              children: [
                Text(
                  'Счёт: ${_engine.score}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  _newRecord ? 'Новый рекорд!' : 'Рекорд: ${_app.fuseballRecord}',
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
