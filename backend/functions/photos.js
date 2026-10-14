"use strict";
const {randomUUID} = require("node:crypto");
const {getStorage} = require("firebase-admin/storage");
const {Timestamp} = require("firebase-admin/firestore");
const D = require("./domain");
function handlers({db, callable, profile, existing}) {
  return {
    uploadParcelPhoto: callable(async (uid, data) => {
      const id = D.id(data.id);
      await profile(uid);
      const savedOrder = (await db.doc(`deliveries/${id}`).get()).data();
      if (savedOrder) {
        if (savedOrder.senderId === uid && savedOrder.photoPath) return {path: savedOrder.photoPath};
        throw new D.DomainError("permission-denied", "Фото заказа уже зафиксировано.");
      }
      if (typeof data.base64 !== "string" || data.base64.length > 7 * 1024 * 1024 || !/^[A-Za-z0-9+/]*={0,2}$/.test(data.base64)) throw new D.DomainError("invalid-argument", "Выберите JPEG до 5 МБ.");
      const bytes = Buffer.from(data.base64, "base64");
      if (bytes.length < 4 || bytes.length > 5 * 1024 * 1024 || bytes[0] !== 255 || bytes[1] !== 216 || bytes[2] !== 255 || bytes.at(-2) !== 255 || bytes.at(-1) !== 217) throw new D.DomainError("invalid-argument", "Выберите JPEG до 5 МБ.");
      await db.runTransaction(async tx => {
        const user = await profile(uid, tx), order = await tx.get(db.doc(`deliveries/${id}`));
        const ref = db.doc(`photoQuotas/${uid}`), quota = (await tx.get(ref)).data(), now = Date.now();
        if (user.role !== "sender" || order.exists) throw new D.DomainError("permission-denied", "Фото заказа уже зафиксировано.");
        const fresh = !quota || now - quota.start > 60000;
        if (!fresh && quota.count >= 6) throw new D.DomainError("resource-exhausted", "Подождите минуту перед загрузкой.");
        tx.set(ref, {start: fresh ? now : quota.start, count: fresh ? 1 : quota.count + 1});
      });
      // A fresh object name makes retries immutable even if publication races with upload.
      const uploadId = randomUUID(), path = `parcels/${uid}/${id}/${uploadId}.jpg`;
      await db.doc(`photoUploads/${uploadId}`).set({uid, path, deliveryId: id, createdAt: Timestamp.now()});
      await getStorage().bucket().file(path).save(bytes, {resumable: false, metadata: {contentType: "image/jpeg"}});
      return {path};
    }),
    parcelPhoto: callable(async (uid, data) => {
      const p = await profile(uid), d = existing(await db.doc(`deliveries/${D.id(data.id)}`).get());
      if (![d.senderId, d.driverId].includes(uid) && !(p.role === "courier" && d.status === "waiting")) throw new D.DomainError("permission-denied", "Нет доступа к фото.");
      if (!d.photoPath) return {};
      const file = getStorage().bucket().file(d.photoPath);
      const [metadata] = await file.getMetadata();
      if (Number(metadata.size) > 5 * 1024 * 1024) throw new D.DomainError("failed-precondition", "Фото слишком большое.");
      const [bytes] = await file.download(); return {base64: bytes.toString("base64")};
    })
  };
}
module.exports = {handlers};
