import 'package:flutter/material.dart';
import 'package:arkanoid/app.dart';
import 'package:arkanoid/data/game_repository.dart';
import 'package:arkanoid/data/game_storage.dart';
import 'package:arkanoid/presentation/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, MemoryStorage storage) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ArkanoidApp(state: AppState(GameRepository(storage))),
    );
  }

  testWidgets('главное меню: рекорды и кнопки', (tester) async {
    final storage = MemoryStorage();
    await storage.writeInt('record_arkanoid', 1234);
    await storage.writeInt('record_fuseball', 17);
    await pumpApp(tester, storage);

    expect(find.text('1234'), findsOneWidget);
    expect(find.text('17'), findsOneWidget);
    expect(find.text('Играть в Арканоид'), findsOneWidget);
    expect(find.text('Играть в Fuseball'), findsOneWidget);
    expect(find.text('Выход'), findsOneWidget);
  });

  testWidgets('пустой рекорд показывается как 0', (tester) async {
    await pumpApp(tester, MemoryStorage());
    expect(find.text('0'), findsNWidgets(2));
  });

  testWidgets('выход требует подтверждения', (tester) async {
    await pumpApp(tester, MemoryStorage());
    await tester.tap(find.text('Выход'));
    await tester.pumpAndSettle();
    expect(find.text('Выйти из игры?'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(find.text('Выйти из игры?'), findsNothing);
  });

  testWidgets('экран достижений показывает все достижения', (tester) async {
    await pumpApp(tester, MemoryStorage());
    await tester.tap(find.textContaining('Достижения ('));
    await tester.pumpAndSettle();
    expect(find.text('Разрушитель'), findsOneWidget);
    expect(find.text('Без единой царапины'), findsOneWidget);
  });

  testWidgets('игровой экран Арканоида открывается и возвращает в меню', (tester) async {
    await pumpApp(tester, MemoryStorage());
    await tester.tap(find.text('Играть в Арканоид'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('Уровень 1'), findsOneWidget);
    expect(find.textContaining('Коснитесь, чтобы запустить мяч'), findsOneWidget);

    await tester.tap(find.byTooltip('В меню'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Играть в Арканоид'), findsOneWidget);
  });
}
