import 'package:flutter/material.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_dimensions.dart';

class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({super.key});

  static const _entries = <_ChangelogEntry>[
    _ChangelogEntry(
      version: '1.29.0',
      date: '3 июня 2026',
      changes: [
        'Тактильная обратная связь при взаимодействии с элементами',
        'Анимация конфетти при обновлении приложения и завершении чеклистов',
        'Пружинная анимация новых сообщений в чате',
        'Анимация сжатия при удалении заметок',
        'Skeleton-шиммер при загрузке списков',
        'Страница истории изменений',
      ],
    ),
    _ChangelogEntry(
      version: '1.28.0',
      date: '2 июня 2026',
      changes: [
        'Панель форматирования в редакторе заметок',
        'Действия с блоками в тулбаре',
        'Улучшения UX для чеклистов',
      ],
    ),
    _ChangelogEntry(
      version: '1.27.0',
      date: '31 мая 2026',
      changes: [
        'Оверлей панели форматирования',
        'Действия с блоками в тулбаре редактора',
        'Исправления UX чеклистов',
      ],
    ),
    _ChangelogEntry(
      version: '1.26.0',
      date: '29 мая 2026',
      changes: [
        'Подсказки @упоминаний в чатах',
        'Система ответов на сообщения (reply)',
        'Улучшения интерфейса',
      ],
    ),
    _ChangelogEntry(
      version: '1.25.0',
      date: '27 мая 2026',
      changes: [
        'Личные чаты между пользователями',
        'Онлайн-статус и индикатор "был(а) в сети"',
        'Исправление отображения аватаров',
      ],
    ),
    _ChangelogEntry(
      version: '1.24.0',
      date: '25 мая 2026',
      changes: [
        'Группы: создание, приглашения, управление участниками',
        'Чат группы и чат заметки',
        'Перемещение заметок между группами',
      ],
    ),
    _ChangelogEntry(
      version: '1.23.0',
      date: '22 мая 2026',
      changes: [
        'Блочный редактор заметок (текст, чеклист, изображения, разделители)',
        'Команды через "/" для вставки блоков',
        'Перетаскивание блоков для изменения порядка',
      ],
    ),
    _ChangelogEntry(
      version: '1.22.0',
      date: '19 мая 2026',
      changes: [
        'Поиск заметок по тексту и чеклистам',
        'Подсветка найденных совпадений',
        'Архив заметок',
      ],
    ),
    _ChangelogEntry(
      version: '1.21.0',
      date: '16 мая 2026',
      changes: [
        'Цветовые метки для заметок',
        'Закрепление заметок (pin)',
        'Виджет сетки заметок',
      ],
    ),
    _ChangelogEntry(
      version: '1.20.0',
      date: '13 мая 2026',
      changes: [
        'Система обновлений приложения',
        'Push-уведомления о новых версиях',
        'Автоматическая проверка при запуске',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('История изменений')),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: _entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 24),
        itemBuilder: (context, index) {
          final entry = _entries[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      'v${entry.version}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    entry.date,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.fgSoft,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...entry.changes.map(
                (change) => Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Icon(Icons.circle, size: 5, color: AppColors.fgSoft),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          change,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.white,
                            height: 1.4,
                          ),
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
    );
  }
}

class _ChangelogEntry {
  final String version;
  final String date;
  final List<String> changes;

  const _ChangelogEntry({
    required this.version,
    required this.date,
    required this.changes,
  });
}
