/// Размерные токены приложения — отступы, радиусы, фиксированные размеры.
///
/// Шкала отступов: 4-8-12-16-24-32 (см. UI_GUIDELINES.md).
/// Радиус и высота кнопок взяты из auth-экранов (Figma 12-633).
class AppRadii {
  AppRadii._();

  static const double xs = 8.0; // мелкие чипы, теги
  static const double sm = 12.0; // вторичные карточки, секции
  static const double md = 16.0; // _kRadius — основной радиус инпутов/кнопок
  static const double lg = 20.0; // sheet-углы сверху
  static const double pill = 999.0; // pill-кнопки
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;
}

class AppSizes {
  AppSizes._();

  static const double buttonHeight = 56.0; // _kBtnH
  static const double inputHeight = 56.0;
  static const double formMaxWidth = 361.0; // _kWidth для desktop-форм
  static const double bottomNavHeight = 64.0;
}
