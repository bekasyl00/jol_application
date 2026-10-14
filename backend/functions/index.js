"use strict";
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue, Timestamp} = require("firebase-admin/firestore");
const {getAuth} = require("firebase-admin/auth");
const {getMessaging} = require("firebase-admin/messaging");
const {getStorage} = require("firebase-admin/storage");
const {onCall, onRequest, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentUpdated, onDocumentCreated} = require("firebase-functions/v2/firestore");
const D = require("./domain");
const A = require("./auth");
const {isLocalSuite} = require("./runtime");
const {AsyncLocalStorage} = require("node:async_hooks");
const requestContext = new AsyncLocalStorage();
initializeApp(process.env.FIRESTORE_EMULATOR_HOST ? {projectId: process.env.GCLOUD_PROJECT || "demo-jol", storageBucket: "demo-jol.appspot.com"} : undefined);
const db = getFirestore();
const options = {region: "europe-west1", enforceAppCheck: !isLocalSuite(), timeoutSeconds: 540};
// This endpoint is discovered only by the local Functions runtime, never deployed.
if (process.env.FUNCTIONS_EMULATOR === "true") {
  exports.localHealth = onRequest({region: options.region, timeoutSeconds: 10}, async (_req, res) => {
    if (!isLocalSuite()) { res.sendStatus(503); return; }
    try {
      await Promise.all([db.doc("_localHealth/connectivity").get(), getAuth().listUsers(1), getStorage().bucket().getFiles({maxResults: 1})]);
      res.json({project: "demo-jol"});
    } catch { res.sendStatus(503); }
  });
}
function callable(handler) {
  return onCall(options, async request => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Войдите в аккаунт.");
    try {
      await A.requireSession(request.auth);
      // Per-account budget also limits expensive reads and message spam.
      const quotaRef = db.doc(`quotas/${request.auth.uid}`);
      await db.runTransaction(async tx => {
        const snap = await tx.get(quotaRef);
        const now = Date.now(); const quota = snap.data();
        const fresh = !quota || now - quota.start >= 60000;
        if (!fresh && quota.count >= 60) throw new HttpsError("resource-exhausted", "Слишком много действий. Подождите минуту.");
        tx.set(quotaRef, {start: fresh ? now : quota.start, count: fresh ? 1 : quota.count + 1});
      });
      return await requestContext.run(request.auth, () => handler(request.auth.uid, request.data || {}, request.auth));
    }
    catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof D.DomainError) throw new HttpsError(error.code, error.message);
      console.error("Callable failure", {code: error.code || "unknown"});
      throw new HttpsError("internal", "Не удалось выполнить действие. Повторите позже.");
    }
  });
}
async function profile(uid, tx) {
  await A.requireSession(requestContext.getStore(), tx);
  const ref = db.doc(`users/${uid}`);
  const snap = tx ? await tx.get(ref) : await ref.get();
  if (!snap.exists) throw new HttpsError("failed-precondition", "Завершите регистрацию.");
  if (snap.data().deleting) throw new HttpsError("failed-precondition", "Аккаунт удаляется.");
  return snap.data();
}
function deliveryRef(input) { return db.doc(`deliveries/${D.id(input.id)}`); }
function existing(snap) { if (!snap.exists) throw new HttpsError("not-found", "Заказ не найден."); return snap.data(); }
exports.createDelivery = callable(async (uid, data) => {
  const {order, details} = D.validateOrder(data);
  const ref = deliveryRef(data);
  let photoPath = null;
  if (data.photoPath != null) {
    const expected = data.photoPath;
    const prefix = `parcels/${uid}/${order.id}/`;
    if (typeof expected !== "string" || !expected.startsWith(prefix) || !/^[a-f0-9-]{36}\.jpg$/.test(expected.slice(prefix.length))) throw new HttpsError("invalid-argument", "Некорректное фото.");
    const [metadata] = await getStorage().bucket().file(expected).getMetadata();
    if (Number(metadata.size) > 5 * 1024 * 1024 || metadata.contentType !== "image/jpeg") throw new HttpsError("invalid-argument", "Некорректное фото.");
    photoPath = expected;
  }
  await db.runTransaction(async tx => {
    const p = await profile(uid, tx);
    if (p.role !== "sender") throw new HttpsError("permission-denied", "Создание доступно отправителю.");
    const old = await tx.get(ref);
    if (old.exists) {
      if (old.data().senderId !== uid) throw new HttpsError("already-exists", "Этот ID уже используется.");
      return; // Retry after an unknown network outcome returns the original order.
    }
    if (photoPath) {
      const uploadId = photoPath.split("/")[3].replace(/\.jpg$/, "");
      const uploadRef = db.doc(`photoUploads/${uploadId}`), upload = (await tx.get(uploadRef)).data();
      if (!upload || upload.uid !== uid || upload.path !== photoPath || upload.createdAt.toMillis() < Date.now() - 86400000) throw new HttpsError("failed-precondition", "Загрузите фото заново.");
      tx.delete(uploadRef);
    }
    tx.create(ref, {...order, pickupAt: Timestamp.fromMillis(order.pickupAt), senderId: uid, driverId: null, status: "waiting", photoPath, createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()});
    tx.create(ref.collection("private").doc("details"), {...details, ...(details.route ? {route: {...details.route, calculatedAt: Timestamp.fromMillis(details.route.calculatedAt)}} : {})});
  });
  return {id: ref.id};
});
exports.acceptDelivery = callable(async (uid, data) => {
  const ref = deliveryRef(data);
  await db.runTransaction(async tx => {
    const p = await profile(uid, tx); const d = existing(await tx.get(ref));
    D.authorizeAccept(d, p, uid);
    const proposals = await tx.get(db.collection("proposals").where("deliveryId", "==", ref.id).where("status", "==", "pending"));
    proposals.docs.forEach(s => tx.update(s.ref, {status: "expired"}));
    tx.update(ref, {driverId: uid, status: "accepted", updatedAt: FieldValue.serverTimestamp()});
  });
  return {ok: true};
});
exports.transitionDelivery = callable(async (uid, data) => {
  const ref = deliveryRef(data);
  await db.runTransaction(async tx => {
    await profile(uid, tx); const d = existing(await tx.get(ref));
    const patch = D.authorizeTransition(d, uid, data.status, data.reason);
    let trip, tripRef, tripDetails, pending;
    if (data.status === "cancelled") {
      pending = await tx.get(db.collection("proposals").where("deliveryId", "==", ref.id).where("status", "==", "pending"));
      if (d.tripId) {
        tripRef = db.doc(`trips/${d.tripId}`); trip = existing(await tx.get(tripRef));
        tripDetails = existing(await tx.get(tripRef.collection("private").doc("details")));
      }
    }
    if (trip) {
      tx.update(tripRef, {reservedKg: Math.max(0, trip.reservedKg - d.weight), acceptedCount: Math.max(0, trip.acceptedCount - 1), version: trip.version + 1});
      tx.update(tripRef.collection("private").doc("details"), {deliveryIds: tripDetails.deliveryIds.filter(id => id !== d.id)});
    }
    pending?.docs.forEach(s => tx.update(s.ref, {status: "expired"}));
    if (["delivered", "cancelled"].includes(data.status)) {
      tx.set(db.doc(`trackingSessions/${ref.id}`), {active: false}, {merge: true});
      tx.delete(ref.collection("private").doc("liveLocation"));
    }
    tx.update(ref, {...patch, updatedAt: FieldValue.serverTimestamp()});
  });
  return {ok: true};
});
exports.deliveryContact = callable(async (uid, data) => {
  await profile(uid);
  const d = existing(await deliveryRef(data).get()); D.participant(d, uid);
  const other = d.senderId === uid ? d.driverId : d.senderId;
  if (!other) return {};
  const snap = await db.doc(`users/${other}`).get();
  if (!snap.exists || snap.data().deleting) return {};
  const {name, phone, role, vehicle, capacityKg} = snap.data();
  return {id: other, name, phone, role, vehicle, capacityKg};
});
exports.sendMessage = callable(async (uid, data) => {
  const ref = deliveryRef(data); const text = D.text(data.text, "сообщение", 1, 2000);
  await db.runTransaction(async tx => {
    await profile(uid, tx); const d = existing(await tx.get(ref)); D.participant(d, uid);
    if (!d.driverId || ["cancelled", "delivered"].includes(d.status)) throw new HttpsError("failed-precondition", "Чат закрыт.");
    const message = ref.collection("messages").doc();
    tx.create(message, {id: message.id, fromUser: uid, text, timestamp: FieldValue.serverTimestamp()});
  });
  return {ok: true};
});
exports.reviewDelivery = callable(async (uid, data) => {
  const ref = deliveryRef(data); const text = D.text(data.text, "отзыв", 1, 500);
  await db.runTransaction(async tx => {
    await profile(uid, tx); const d = existing(await tx.get(ref));
    if (d.senderId !== uid || d.status !== "delivered" || d.review) throw new HttpsError("permission-denied", "Отзыв недоступен.");
    tx.update(ref, {review: text, updatedAt: FieldValue.serverTimestamp()});
  });
  return {ok: true};
});
// Lock the profile first: order mutations read the same document in their transactions.
// Retries resume the deletion if a storage/network operation failed.
exports.deleteAccount = callable(async (uid, data, auth) => {
  if (!auth?.token?.auth_time || Date.now() / 1000 - auth.token.auth_time > 300) throw new HttpsError("unauthenticated", "Подтвердите пароль перед удалением аккаунта.");
  const userRef = db.doc(`users/${uid}`);
  await db.runTransaction(async tx => {
    await A.requireSession(auth, tx);
    const user = await tx.get(userRef);
    if (!user.exists) return;
    const sender = await tx.get(db.collection("deliveries").where("senderId", "==", uid));
    const driver = await tx.get(db.collection("deliveries").where("driverId", "==", uid));
    if ([...sender.docs, ...driver.docs].some(s => !["delivered", "cancelled"].includes(s.data().status))) throw new HttpsError("failed-precondition", "Сначала завершите или отмените активные доставки.");
    tx.update(userRef, {deleting: true});
  });
  const [sender, driver] = await Promise.all([db.collection("deliveries").where("senderId", "==", uid).get(), db.collection("deliveries").where("driverId", "==", uid).get()]);
  const docs = new Map([...sender.docs, ...driver.docs].map(s => [s.id, s]));
  for (const snap of docs.values()) {
    if (snap.data().photoPath) await getStorage().bucket().file(snap.data().photoPath).delete({ignoreNotFound: true});
    await db.doc(`trackingSessions/${snap.id}`).delete();
    await db.recursiveDelete(snap.ref); // Removes order contacts, recipient data, chat and review.
  }
  const ownedTrips = await db.collection("trips").where("driverId", "==", uid).get();
  for (const trip of ownedTrips.docs) await db.recursiveDelete(trip.ref);
  const proposalGroups = await Promise.all(["senderId", "driverId"].map(field => db.collection("proposals").where(field, "==", uid).get()));
  for (const group of proposalGroups) for (const proposal of group.docs) await proposal.ref.delete();
  await getStorage().bucket().deleteFiles({prefix: `parcels/${uid}/`});
  // Keep a PII-free tombstone: cached auth tokens cannot recreate a deleted profile.
  const storedUser = (await userRef.get()).data();
  if (storedUser?.phone) await db.doc(`phoneIndex/${A.hashKey(storedUser.phone)}`).delete();
  await db.doc(`passwordCredentials/${uid}`).delete();
  await db.doc(`authState/${uid}`).delete();
  const sessions = await db.collection("authSessions").where("uid", "==", uid).get();
  for (const session of sessions.docs) await session.ref.delete();
  await userRef.set({id: uid, deleting: true});
  const tokens = await userRef.collection("tokens").get();
  await Promise.all(tokens.docs.map(snap => snap.ref.delete()));
  await db.doc(`quotas/${uid}`).delete();
  await db.doc(`photoQuotas/${uid}`).delete();
  const uploads = await db.collection("photoUploads").where("uid", "==", uid).get();
  for (const upload of uploads.docs) await upload.ref.delete();
  try { await getAuth().deleteUser(uid); } catch (error) { if (error.code !== "auth/user-not-found") throw error; }
  return {ok: true};
});
async function notify(uid, title, body, deliveryId) {
  // FCM has no emulator. Never send real notifications from an emulator process.
  if (process.env.FUNCTIONS_EMULATOR === "true") return;
  if (!uid) return;
  const user = await db.doc(`users/${uid}`).get(); if (!user.exists || user.data().deleting) return;
  const snaps = await db.collection(`users/${uid}/tokens`).get();
  for (let i = 0; i < snaps.docs.length; i += 500) {
    const chunk = snaps.docs.slice(i, i + 500); if (!chunk.length) continue;
    const response = await getMessaging().sendEachForMulticast({tokens: chunk.map(s => s.data().token), notification: {title, body}, data: {deliveryId}, apns: {payload: {aps: {sound: "default"}}}});
    await Promise.all(response.responses.map((result, index) => {
      if (["messaging/invalid-registration-token", "messaging/registration-token-not-registered"].includes(result.error?.code)) return chunk[index].ref.delete();
      return Promise.resolve();
    }));
  }
}
exports.statusNotification = onDocumentUpdated({region: options.region, document: "deliveries/{id}"}, async event => {
  const before = event.data.before.data(), after = event.data.after.data();
  if (before.status === after.status) return;
  await Promise.all([notify(after.senderId, "Статус доставки обновлён", "Откройте заказ, чтобы посмотреть подробности.", event.params.id), notify(after.driverId, "Статус доставки обновлён", "Откройте заказ, чтобы посмотреть подробности.", event.params.id)]);
});
exports.messageNotification = onDocumentCreated({region: options.region, document: "deliveries/{id}/messages/{messageId}"}, async event => {
  const snap = await db.doc(`deliveries/${event.params.id}`).get(); if (!snap.exists) return;
  const d = snap.data(); const m = event.data.data();
  await notify(m.fromUser === d.senderId ? d.driverId : d.senderId, "Новое сообщение", "У вас новое сообщение по доставке.", event.params.id);
});

Object.assign(exports, require("./trips").handlers({db, callable, profile, existing}));

Object.assign(exports, A.handlers());

Object.assign(exports, require("./photos").handlers({db, callable, profile, existing}));

Object.assign(exports, require("./tracking").handlers({db, callable, profile, existing}));

exports.cleanupEphemeral = require("./cleanup").handler(db, getStorage().bucket());
