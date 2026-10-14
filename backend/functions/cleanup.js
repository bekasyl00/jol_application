"use strict";
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {Timestamp} = require("firebase-admin/firestore");
async function cleanup(db, bucket, now = Date.now()) {
  // Access expires in rules immediately; TTL/scheduled deletion is storage housekeeping.
  const expired = await db.collectionGroup("private").where("expiresAt", "<=", Timestamp.fromMillis(now)).limit(200).get();
  for (const item of expired.docs) if (item.id === "liveLocation") await db.runTransaction(async tx => {
    const latest = (await tx.get(item.ref)).data();
    // An active publisher may have refreshed this document since the expiry query.
    if (latest?.expiresAt?.toMillis() <= now) tx.delete(item.ref);
  });
  const uploads = await db.collection("photoUploads").where("createdAt", "<", Timestamp.fromMillis(now - 48 * 3600000)).limit(100).get();
  for (const upload of uploads.docs) {
    const value = upload.data(), order = await db.doc(`deliveries/${value.deliveryId}`).get();
    if (!order.exists || order.data().photoPath !== value.path) await bucket.file(value.path).delete({ignoreNotFound: true});
    await upload.ref.delete();
  }
}
function handler(db, bucket) { return onSchedule({schedule: "every 60 minutes", region: "europe-west1", timeoutSeconds: 540}, () => cleanup(db, bucket)); }
module.exports = {handler, cleanup};
