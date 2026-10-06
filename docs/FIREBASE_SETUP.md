# Подключение Firebase

1. Перед выбором расположения данных проверьте требования к хранению персональных данных в Казахстане (см. RELEASE.md). Этот Firebase-вариант предназначен для разработки и проверки интеграции; изменение региона Functions не локализует Auth, Firestore или Storage.
2. Создайте Firebase-проект и iOS-приложение с Bundle ID из Xcode (`kz.jol.parcel` — заменяемый пример). В Auth включите Email/Password и настройте password policy минимум 8 символов. Интерфейс принимает email и пароль; телефон хранится как контакт, SMS-авторизация не реализована.
3. Создайте Firestore в production mode и Storage bucket. Выберите расположения осознанно; расположение базы Firestore после создания не меняется. Для развёртывания Functions потребуется доступный для проекта биллинг.
4. Скачайте `GoogleService-Info.plist` в `App/Resources/GoogleService-Info.plist`; выполните `python3 scripts/generate-project.py`.
5. Зарегистрируйте iOS-приложение в App Check с App Attest. В Debug используется Firebase debug provider; зарегистрируйте его тестовый токен в консоли для своей сборки. В Release используется App Attest. Cloud Functions проверяют App Check; не отключайте его для рабочего проекта.
6. Для уведомлений добавьте capability Push Notifications, заполните Apple Development Team и загрузите APNs .p8 key / Team ID / Key ID в Firebase Cloud Messaging. Подпись development/production и App Attest environment заданы отдельно для Debug/Release. Проверьте на физическом iPhone. В профиле пользователь запрашивает разрешение на push.
7. Для разработки установите Node 22 и Java 21+. Выполните `npm ci` и `npm ci --prefix backend/functions`.
8. Запустите локальные проверки `npm run test:rules`. Используется `demo-jol`; тесты не обращаются к рабочей базе.
9. После подготовки собственного проекта: `npx firebase login`, затем `npx firebase deploy --project YOUR_PROJECT_ID --only firestore,storage,functions`. Здесь `YOUR_PROJECT_ID` нужно заменить. Команда не выполнялась агентом.
10. При необходимости измените регион `europe-west1` одновременно в `backend/functions/index.js` и `App/Services/AppStore.swift`. Регион взят как технический пример, не как решение правовых требований.

## Схема хранения

- `users/{uid}` — собственный профиль. Другим клиентам недоступен. Создание валидируется правилами, изменение роли запрещено. Редактирование профиля в UI не включено в эту версию.
- `users/{uid}/tokens/{token}` — токены устройств; чужие токены недоступны.
- `deliveries/{id}` — города, посылка, цена, дата и статусы. Доступ участникам или перевозчику для ожидающего заказа. Нет точных адресов или телефонов.
- `deliveries/{id}/private/details` — адреса, получатель и условия, только для участников.
- `deliveries/{id}/messages/{id}` — сообщения участников, запись через сервер.
- `parcels/{senderId}/{orderId}/photo.jpg` — JPEG до 5 МБ. Новое фото может загрузить отправитель до создания заказа, существующее фото заказа нельзя перезаписать.
- `quotas/{uid}` — внутренний лимит API. Чтение/запись клиентом запрещены.

Все изменения заказов выполняются callable Functions: `createDelivery`, `acceptDelivery`, `transitionDelivery`, `deliveryContact`, `sendMessage`, `reviewDelivery`, `deleteAccount`. Создание поддерживает повтор с тем же ID и тем же владельцем после неизвестного сетевого результата. Квоты аккаунта не заменяют бюджетные оповещения и мониторинг проекта.

Гонки принятия/статусов проверяются транзакциями. Удаление сначала блокирует профиль; параллельные операции с тем же пользователем перечитывают документ внутри своих транзакций. Полностью завершённый заказ удаляется целиком, включая историю другой стороны; это осознанное упрощение MVP, перед коммерческим запуском нужно определить правила хранения и обезличивания истории.

Фото до публикации может остаться сиротой после аварийного закрытия приложения. Настройте отдельную очистку непривязанных фото по согласованному сроку перед масштабированием. Триггеры FCM могут доставлять дубликаты при повторной обработке события; идемпотентность отправки уведомлений требует отдельной доработки.

Документация: [Swift Codable в Firestore](https://firebase.google.com/docs/firestore/solutions/swift-codable-data-mapping), [транзакции](https://firebase.google.com/docs/firestore/manage-data/transactions), [App Attest](https://firebase.google.com/docs/app-check/ios/app-attest-provider), [debug provider](https://firebase.google.com/docs/app-check/ios/debug-provider), [тестирование правил](https://firebase.google.com/docs/firestore/security/test-rules-emulator).
