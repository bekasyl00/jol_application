# Подключение Firebase

1. Перед выбором расположения данных проверьте требования к хранению персональных данных в Казахстане (см. RELEASE.md). Этот Firebase-вариант предназначен для разработки и проверки интеграции; изменение региона Functions не локализует Auth, Firestore или Storage.
2. Создайте Firebase-проект и iOS-приложение с Bundle ID из Xcode (`kz.jol.parcel` — заменяемый пример). В Auth включите Phone provider; настройте разрешённые регионы SMS и тестовые номера. Для настоящих SMS нужен Blaze. Email/Password оставьте только для миграции существующих аккаунтов. Телефон + пароль реализован через серверные custom sessions; пароль 15–128 символов. Подробно: [AUTH_AND_TRACKING.md](AUTH_AND_TRACKING.md).
3. Создайте Firestore в production mode и Storage bucket. Выберите расположения осознанно; расположение базы Firestore после создания не меняется. Для развёртывания Functions потребуется доступный для проекта биллинг.
4. Скачайте `GoogleService-Info.plist` в `App/Resources/GoogleService-Info.plist`; задайте `JOL_AUTH_CALLBACK_SCHEME` в игнорируемом `LocalSigning.xcconfig` значением Encoded App ID из настройки Firebase iOS (формат `app-` + Google App ID с заменой двоеточий на дефисы); выполните `python3 scripts/generate-project.py`. Без URL-схемы SMS-вход покажет ошибку конфигурации.
5. Зарегистрируйте iOS-приложение в App Check с App Attest. В Debug используется Firebase debug provider; зарегистрируйте его тестовый токен в консоли для своей сборки. В Release используется App Attest. Cloud Functions проверяют App Check; не отключайте его для рабочего проекта.
6. Для уведомлений добавьте capability Push Notifications, заполните Apple Development Team и загрузите APNs .p8 key / Team ID / Key ID в Firebase Cloud Messaging. Подпись development/production и App Attest environment заданы отдельно для Debug/Release. Проверьте на физическом iPhone. В профиле пользователь запрашивает разрешение на push.
7. Для разработки установите Node 22 и Java 21+. Выполните `npm ci` и `npm ci --prefix backend/functions`.
8. Запустите локальные проверки `npm run test:rules`. Используется `demo-jol`; тесты не обращаются к рабочей базе.
9. После подготовки собственного проекта: `npx firebase login`, затем `npx firebase deploy --project YOUR_PROJECT_ID --only firestore,storage,functions`. Здесь `YOUR_PROJECT_ID` нужно заменить. Для `jolparcel-kz-2026` правила Firestore уже развёрнуты; Functions требуют Blaze, Storage ещё не создан. См. CLOUD_SETUP_STATUS.md.
10. При необходимости измените регион `europe-west1` во всех серверных модулях с `region` и `App/Services/AppStore.swift`. Регион взят как технический пример, не как решение правовых требований.

## Схема хранения

- `users/{uid}` — собственный профиль. Другим клиентам недоступен. Создаётся только серверной функцией после подтверждения телефона; прямая запись запрещена. Редактирование профиля в UI не включено в эту версию.
- `users/{uid}/tokens/{token}` — токены устройств; чужие токены недоступны.
- `deliveries/{id}` — города, посылка, цена, дата и статусы. Доступ участникам или перевозчику для ожидающего заказа. Нет точных адресов или телефонов.
- `deliveries/{id}/private/details` — адреса, получатель и условия, только для участников.
- `deliveries/{id}/messages/{id}` — сообщения участников, запись через сервер.
- `parcels/{senderId}/{orderId}/{uuid}.jpg` — JPEG до 5 МБ. Новое фото может загрузить отправитель до создания заказа, существующее фото заказа нельзя перезаписать.
- `quotas/{uid}` — внутренний лимит API. Чтение/запись клиентом запрещены.

Все изменения заказов выполняются callable Functions: `createDelivery`, `acceptDelivery`, `transitionDelivery`, `deliveryContact`, `sendMessage`, `reviewDelivery`, `deleteAccount`. Создание поддерживает повтор с тем же ID и тем же владельцем после неизвестного сетевого результата. Квоты аккаунта не заменяют бюджетные оповещения и мониторинг проекта.

Гонки принятия/статусов проверяются транзакциями. Удаление сначала блокирует профиль; параллельные операции с тем же пользователем перечитывают документ внутри своих транзакций. Полностью завершённый заказ удаляется целиком, включая историю другой стороны; это осознанное упрощение MVP, перед коммерческим запуском нужно определить правила хранения и обезличивания истории.

Фото читаются/загружаются через callable API с проверкой полной сессии; прямой Storage доступ закрыт. `cleanupEphemeral` ежечасно удаляет непривязанные фото старше 48 часов и истёкшие GPS-документы. Deploy также включает TTL и индексы из firestore.indexes.json; проверьте их готовность в консоли. Триггеры FCM могут доставлять дубликаты при повторной обработке события; идемпотентность отправки уведомлений требует отдельной доработки.

Документация: [Swift Codable в Firestore](https://firebase.google.com/docs/firestore/solutions/swift-codable-data-mapping), [транзакции](https://firebase.google.com/docs/firestore/manage-data/transactions), [App Attest](https://firebase.google.com/docs/app-check/ios/app-attest-provider), [debug provider](https://firebase.google.com/docs/app-check/ios/debug-provider), [тестирование правил](https://firebase.google.com/docs/firestore/security/test-rules-emulator).

Схема поездок, приватной позиции, парольных verifier и сессий описана в [AUTH_AND_TRACKING.md](AUTH_AND_TRACKING.md).
