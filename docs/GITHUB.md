# GitHub, проверки и публикация

Репозиторий: https://github.com/bekasyl00/application. Приватный, основная ветка `main`.

В `AGENTS.md` сохранено требование пользователя: каждое завершённое изменение после необходимых проверок коммитить и пушить. Это правило для работы агента с проектом; фонового наблюдателя, автоматически публикующего каждое сохранение файла в редакторе, нет.

## GitHub Actions

После push в `main` и при pull request запускается `CI`:

- Node 22 / Java 21: доменные тесты, синтаксис Functions, аудит production-зависимостей и тесты правил в Firebase Emulator Suite.
- macOS / Xcode: проверка Swift-ядра, XCTest и unsigned iOS simulator build без Firebase-конфигурации. Такая сборка проверяет SDK-интеграцию и деморежим; для TestFlight нужны настройки подписи.

## Автоматическое развёртывание Firebase

Workflow `Deploy Firebase` подготовлен, но по умолчанию отключён. Он запускается после успешного CI для push в `main`; также предусмотрен ручной запуск. Он деплоит конкретный проверенный commit, а не произвольную более новую версию ветки.

После выбора и настройки собственного Firebase-проекта:

1. Создать GitHub Environment `production`.
2. Добавить Repository Variables `FIREBASE_PROJECT_ID` с реальным ID проекта и `FIREBASE_DEPLOY_ENABLED` со значением `true`.
3. Добавить Environment Secret `FIREBASE_SERVICE_ACCOUNT` — JSON сервисного аккаунта с необходимыми правами для развёртывания Functions, Firestore и Storage. Не коммитить файл ключа. При дальнейшем развитии заменить долгоживущий ключ на Workload Identity Federation.
4. Убедиться, что Firebase/GCP API, биллинг, Storage bucket и App Check подготовлены; выполнить первый контролируемый запуск и проверить результат.

Firebase CLI локально авторизован, создан проект `jolparcel-kz-2026`, правила Firestore развёрнуты. Functions заблокированы отсутствием Blaze, Storage ещё не настроен. Учётные данные для GitHub deployment не добавлены, workflow остаётся отключённым. GitHub-репозиторий содержит исходники и workflow; мобильное приложение не становится доступным пользователям от одного push. Для установки реального iOS-приложения нужна отдельная доставка через TestFlight/App Store (см. RELEASE.md).
