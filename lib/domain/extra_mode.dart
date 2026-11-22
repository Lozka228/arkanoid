/// Дополнительные режимы Арканоида (открываются после всех достижений).
enum ExtraMode {
  infiniteBalls(
    'Бесконечные мячи',
    'До 100 мячей на поле. Из каждого кирпича падает множитель ×3, '
        'который утраивает все мячи.',
  ),
  doubleSpeed(
    'Двойная скорость',
    'Мяч летит вдвое быстрее с самого начала.',
  );

  const ExtraMode(this.title, this.description);
  final String title;
  final String description;
}
