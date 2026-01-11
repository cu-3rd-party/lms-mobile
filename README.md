# lms-mobile

![Flutter](https://img.shields.io/badge/Flutter-3.38.5-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.10.4-0175C2?logo=dart&logoColor=white)
![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20Android%20-333333)

Приложение на Flutter для LMS Центрального университета.

## Возможности

- Авторизация и профиль пользователя
- Курсы и темы с деталями
- Задания, фильтры и прогресс
- Просмотр материалов и вложений
- Календарь (CalDAV) и расписание
- Уведомления

## Скриншоты

![Screenshot 01](assets/screenshots/screenshot-01.png)
![Screenshot 02](assets/screenshots/screenshot-02.png)
![Screenshot 03](assets/screenshots/screenshot-03.png)
![Screenshot 04](assets/screenshots/screenshot-04.png)
![Screenshot 05](assets/screenshots/screenshot-05.png)
![Screenshot 06](assets/screenshots/screenshot-06.png)

## Требования

- Flutter SDK 3.38.5 (stable)
- Dart SDK 3.10.4
- Xcode (для iOS) / Android Studio (для Android)

## Быстрый старт

1. Установить зависимости:
   ```bash
   flutter pub get
   ```
2. Запуск:
   ```bash
   flutter run
   ```

## Сборка

- iOS:
  ```bash
  flutter build ios
  ```
- Android:
  ```bash
  flutter build apk
  ```

## Архитектура

Проект построен по feature‑first подходу с разделением на слои:

- `lib/app/` — запуск приложения, тема, локализация
- `lib/core/` — общие сервисы и утилиты
- `lib/data/models/` — модели данных
- `lib/data/services/` — API, CalDAV и интеграции
- `lib/features/*/pages/` — экраны по фичам
- `assets/` — статические ресурсы
