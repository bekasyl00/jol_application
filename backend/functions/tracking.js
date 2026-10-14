"use strict";
const {randomUUID} = require("node:crypto");
const {Timestamp} = require("firebase-admin/firestore");
const D = require("./domain");
function active(order, uid) {
  if (order.driverId !== uid || !["enRoute", "pickedUp"].includes(order.status)) throw new D.DomainError("permission-denied", "Трансляция доступна только перевозчику активной доставки.");
}
function validatePoint(data, now = Date.now()) {
  const coordinate = D.point(data.coordinate);
  const accuracy = D.number(data.accuracy, "точность", 0, 1000);
  const capturedAt = D.number(data.capturedAt, "время позиции", now - 60000, now + 10000);
  const sequence = D.number(data.sequence, "номер обновления", 1, Number.MAX_SAFE_INTEGER);
  if (!Number.isInteger(sequence)) throw new D.DomainError("invalid-argument", "Некорректное обновление.");
  return {coordinate, accuracy, capturedAt, sequence};
}
function handlers({db, callable, profile, existing}) {
  return {
    startTracking: callable(async (uid, data, auth) => {
      const id = D.id(data.id); let sessionId, sequence;
      await db.runTransaction(async tx => {
        await profile(uid, tx); const order = existing(await tx.get(db.doc(`deliveries/${id}`))); active(order, uid);
        const ref = db.doc(`trackingSessions/${id}`), previous = (await tx.get(ref)).data();
        if (previous?.active && previous.publisherSessionId === auth.token.jolSession && previous.expiresAt.toMillis() > Date.now()) {
          sessionId = previous.sessionId; sequence = previous.sequence; return;
        }
        sessionId = randomUUID(); sequence = 0;
        tx.set(ref, {sessionId, publisherSessionId: auth.token.jolSession, driverId: uid, active: true, sequence: 0, lastReceivedAt: 0, lastCapturedAt: 0, expiresAt: Timestamp.fromMillis(Date.now()+86400000)});
        tx.delete(db.doc(`deliveries/${id}/private/liveLocation`));
      });
      return {sessionId, sequence};
    }),
    updateTracking: callable(async (uid, data, auth) => {
      const id = D.id(data.id), location = validatePoint(data);
      await db.runTransaction(async tx => {
        await profile(uid, tx); const order = existing(await tx.get(db.doc(`deliveries/${id}`))); active(order, uid);
        const ref = db.doc(`trackingSessions/${id}`), lease = existing(await tx.get(ref)), now = Date.now();
        if (!lease.active || lease.sessionId !== data.sessionId || lease.publisherSessionId !== auth.token.jolSession || lease.expiresAt.toMillis() <= now) throw new D.DomainError("permission-denied", "Сессия передачи завершена.");
        if (location.sequence === lease.sequence) return {ok: true}; // Idempotent retry; never overwrite a newer point.
        if (location.sequence < lease.sequence || location.capturedAt <= lease.lastCapturedAt) throw new D.DomainError("failed-precondition", "Устаревшая позиция.");
        if (now - lease.lastReceivedAt < 10000) throw new D.DomainError("resource-exhausted", "Слишком частые обновления позиции.");
        const expiresAt = Timestamp.fromMillis(now + 23 * 3600000);
        tx.update(ref, {sequence: location.sequence, lastReceivedAt: now, lastCapturedAt: location.capturedAt, expiresAt});
        tx.set(db.doc(`deliveries/${id}/private/liveLocation`), {coordinate: location.coordinate, accuracy: location.accuracy, capturedAt: Timestamp.fromMillis(location.capturedAt), receivedAt: Timestamp.fromMillis(now), visibleUntil: Timestamp.fromMillis(now + 120000), expiresAt,
          sessionId: lease.sessionId, publisherSessionId: auth.token.jolSession, publisherVersion: auth.token.jolVersion, driverId: uid});
      });
      return {ok: true};
    }),
    stopTracking: callable(async (uid, data) => {
      const id = D.id(data.id);
      await db.runTransaction(async tx => {
        await profile(uid, tx); const d = existing(await tx.get(db.doc(`deliveries/${id}`)));
        if (d.driverId !== uid) throw new D.DomainError("permission-denied", "Трансляцией управляет перевозчик.");
        const ref = db.doc(`trackingSessions/${id}`), current = await tx.get(ref);
        if (current.exists) tx.update(ref, {active: false});
        tx.delete(db.doc(`deliveries/${id}/private/liveLocation`));
      });
      return {ok: true};
    })
  };
}
module.exports = {handlers, active, validatePoint};
