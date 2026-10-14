const {test, before, after} = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const {initializeTestEnvironment, assertSucceeds, assertFails} = require("@firebase/rules-unit-testing");
const {doc, getDoc, setDoc, updateDoc, collection, query, where, getDocs, Timestamp} = require("firebase/firestore");
const {ref, uploadBytes, getMetadata, deleteObject} = require("firebase/storage");
let env;
const {createHash} = require("node:crypto");
const sessionId = uid => { const h = createHash("sha256").update(uid).digest("hex"); return h.slice(0,8)+"-"+h.slice(8,12)+"-"+h.slice(12,16)+"-"+h.slice(16,20)+"-"+h.slice(20,32); };
const fullAuth = uid => ({uid, token: {firebase: {sign_in_provider: "custom"}, jolSession: sessionId(uid), jolVersion: "test-v1", auth_time: Math.floor(Date.now()/1000)}});
const fullContext = uid => env.authenticatedContext(uid, fullAuth(uid).token);
async function seedSession(db, uid) {
 await setDoc(doc(db, `authState/${uid}`), {version: "test-v1"});
 await setDoc(doc(db, `authSessions/${sessionId(uid)}`), {uid, version: "test-v1", revoked: false, expiresAt: Timestamp.fromMillis(Date.now()+86400000)});
}
const user = (id, role = "sender") => ({id, name: "Тест", phone: "+77011234567", role, vehicle: role === "courier" ? "Kia" : "", capacityKg: role === "courier" ? 50 : 0});
const delivery = {id: "order", senderId: "sender", driverId: null, fromCity: "Алматы", toCity: "Астана", itemDescription: "Книги", size: "box", weight: 10, volume: 0.06, distanceKm: 100, price: 2100, status: "waiting", pickupAt: Timestamp.now(), createdAt: Timestamp.now(), updatedAt: Timestamp.now()};
before(async () => {
 env = await initializeTestEnvironment({projectId: "demo-jol", firestore: {rules: fs.readFileSync("backend/firestore.rules", "utf8")}, storage: {rules: fs.readFileSync("backend/storage.rules", "utf8")}});
 await env.withSecurityRulesDisabled(async context => {
  const db = context.firestore();
  for (const [uid, role] of [["sender", "sender"], ["courier", "courier"], ["courier2", "courier"], ["outsider", "sender"]]) { await setDoc(doc(db, "users", uid), user(uid, role)); await seedSession(db, uid); }
  await setDoc(doc(db, "deliveries", "order"), delivery);
  await setDoc(doc(db, "deliveries/order/private/details"), {addressFrom: "Secret address", recipientPhone: "+77011234567"});
 });
});
after(async () => { await env?.cleanup(); });
test("anonymous users cannot browse orders or profiles", async () => {
 const db = env.unauthenticatedContext().firestore();
 await assertFails(getDoc(doc(db, "deliveries", "order")));
 await assertFails(getDoc(doc(db, "users", "sender")));
});
test("couriers can query market but cannot read private contacts or profiles", async () => {
 const db = fullContext("courier").firestore();
 await assertSucceeds(getDocs(query(collection(db, "deliveries"), where("status", "==", "waiting"))));
 await assertFails(getDoc(doc(db, "deliveries/order/private/details")));
 await assertFails(getDoc(doc(db, "users", "sender")));
 await assertFails(getDocs(collection(db, "deliveries")));
});
test("sender query and private data authorized; another sender denied", async () => {
 const db = fullContext("sender").firestore();
 await assertSucceeds(getDocs(query(collection(db, "deliveries"), where("senderId", "==", "sender"))));
 await assertSucceeds(getDoc(doc(db, "deliveries/order/private/details")));
 await assertFails(getDoc(doc(fullContext("outsider").firestore(), "deliveries/order/private/details")));
});
test("all direct order and message mutations denied", async () => {
 const db = fullContext("courier").firestore();
 await assertFails(updateDoc(doc(db, "deliveries/order"), {driverId: "courier", status: "accepted"}));
 const senderDB = fullContext("sender").firestore();
 await assertFails(updateDoc(doc(senderDB, "deliveries/order"), {price: 0}));
 await assertFails(setDoc(doc(senderDB, "deliveries/order/messages/spoof"), {fromUser: "courier", text: "Spoof", timestamp: Timestamp.now()}));
});
test("profile create validates phone, role and protected fields", async () => {
 for (const [uid, patch] of [["new1", {phone: "123"}], ["new2", {role: "admin"}], ["new3", {deleting: false}], ["new4", {capacityKg: -1}]]) {
  await assertFails(setDoc(doc(fullContext(uid).firestore(), "users", uid), {...user(uid), ...patch}));
 }
 const context = fullContext("new-valid");
 await assertFails(setDoc(doc(context.firestore(), "users/new-valid"), user("new-valid")));
 await assertFails(updateDoc(doc(context.firestore(), "users/new-valid"), {role: "courier"}));
});
test("direct Storage access is closed even for a valid session", async () => {
 const storage = fullContext("sender").storage();
 await assertFails(uploadBytes(ref(storage, "parcels/sender/new-order/photo.jpg"), new Uint8Array([255,216,255,217]), {contentType: "image/jpeg"}));
 await assertFails(getMetadata(ref(storage, "parcels/sender/new-order/photo.jpg")));
});
test("deleted account tombstone denies recreation", async () => {
 await env.withSecurityRulesDisabled(async c => setDoc(doc(c.firestore(), "users/deleted"), {id: "deleted", deleting: true}));
 await assertFails(setDoc(doc(fullContext("deleted").firestore(), "users/deleted"), user("deleted")));
});
test("callable transactions: simultaneous claims have one winner; deletion erases PII", async () => {
 // Invoke callable handlers directly against the emulator. Transport/App Check is separately configured for production.
 const functions = require("../functions/index");
 const input = {id: "race-order", fromCity: "Алматы", toCity: "Астана", itemDescription: "Книги", size: "box", weight: 10, volume: 0.06, distanceKm: 100, price: 2100, pickupAt: Date.now() + 3600000, addressFrom: "Secret", addressTo: "Secret 2", recipientName: "Алия", recipientPhone: "+77011234567", comment: ""};
 await functions.createDelivery.run({auth: fullAuth("sender"), data: input});
 const results = await Promise.allSettled(["courier", "courier2"].map(uid => functions.acceptDelivery.run({auth: fullAuth(uid), data: {id: input.id}})));
 assert.equal(results.filter(r => r.status === "fulfilled").length, 1);
 const winner = results[0].status === "fulfilled" ? "courier" : "courier2";
 const db = fullContext(winner).firestore();
 await assertSucceeds(getDoc(doc(db, `deliveries/${input.id}/private/details`)));
 await assert.rejects(functions.transitionDelivery.run({auth: fullAuth(winner), data: {id: input.id, status: "delivered"}}));
 for (const status of ["enRoute", "pickedUp", "delivered"]) await functions.transitionDelivery.run({auth: fullAuth(winner), data: {id: input.id, status}});
 await functions.reviewDelivery.run({auth: fullAuth("sender"), data: {id: input.id, text: "Спасибо!"}});
 await assert.rejects(functions.deliveryContact.run({auth: fullAuth("outsider"), data: {id: input.id}}));
 await assert.rejects(functions.deleteAccount.run({auth: fullAuth("sender"), data: {}})); // First waiting order still active.
 await functions.transitionDelivery.run({auth: fullAuth("sender"), data: {id: "order", status: "cancelled", reason: "Планы изменились"}});
 await functions.deleteAccount.run({auth: fullAuth("sender"), data: {}});
 await env.withSecurityRulesDisabled(async c => {
  const deleted = await getDoc(doc(c.firestore(), "users/sender"));
  assert.deepEqual(deleted.data(), {id: "sender", deleting: true});
  assert.equal((await getDoc(doc(c.firestore(), `deliveries/${input.id}/private/details`))).exists(), false);
 });
});

test("trip proposals reserve multiple parcels atomically, protect addresses, and release cancellations", async () => {
 const functions = require("../functions/index");
 const now = Date.now() + 7200000;
 await env.withSecurityRulesDisabled(async c => {
   await setDoc(doc(c.firestore(), "users/trip-sender"), user("trip-sender"));
   await seedSession(c.firestore(), "trip-sender"); await seedSession(c.firestore(), "trip-driver");
   await setDoc(doc(c.firestore(), "users/trip-driver"), {...user("trip-driver", "courier"), capacityKg: 25});
 });
 const input = {id: "trip-multi", fromCity: "Алматы", toCity: "Астана", origin: {coordinate: {latitude: 43.2383, longitude: 76.9455}, label: "Private origin"}, destination: {coordinate: {latitude: 51.1282, longitude: 71.4304}, label: "Private destination"}, departureAt: now, capacityKg: 25, maxParcels: 5, pickupWindowMinutes: 120, maxDetourKm: 20, maxDetourMinutes: 30};
 await functions.publishTrip.run({auth: fullAuth("trip-driver"), data: input});
 for (let i = 0; i < 3; i++) {
   await functions.createDelivery.run({auth: fullAuth("trip-sender"), data: {id: `multi-${i}`, fromCity: "Алматы", toCity: "Астана", itemDescription: "Книги", size: "box", weight: 10, volume: 0.06, distanceKm: 100, price: 2100, pickupAt: now, addressFrom: "Private pickup", addressTo: "Private dropoff", recipientName: "Алия", recipientPhone: "+77011234567", comment: ""}});
   await functions.createProposal.run({auth: fullAuth("trip-sender"), data: {tripId: input.id, deliveryId: `multi-${i}`}});
 }
 const senderDB = fullContext("trip-sender").firestore();
 await assertSucceeds(getDoc(doc(senderDB, "trips/trip-multi")));
 await assertFails(getDoc(doc(senderDB, "trips/trip-multi/private/details")));
 await assertFails(getDoc(doc(fullContext("outsider").firestore(), "proposals/multi-0_trip-multi")));
 await assertFails(setDoc(doc(senderDB, "trips/spoof"), input));
 let version = (await getDoc(doc(senderDB, "trips/trip-multi"))).data().version;
 const race = await Promise.allSettled([0, 1].map(i => functions.respondProposal.run({auth: fullAuth("trip-driver"), data: {id: `multi-${i}_trip-multi`, action: "accepted", version}})));
 assert.equal(race.filter(r => r.status === "fulfilled").length, 1);
 const loser = race[0].status === "fulfilled" ? 1 : 0;
 version = (await getDoc(doc(senderDB, "trips/trip-multi"))).data().version;
 await functions.respondProposal.run({auth: fullAuth("trip-driver"), data: {id: `multi-${loser}_trip-multi`, action: "accepted", version}});
 const filled = (await getDoc(doc(senderDB, "trips/trip-multi"))).data();
 assert.equal(filled.acceptedCount, 2); assert.equal(filled.reservedKg, 20);
 await assert.rejects(functions.respondProposal.run({auth: fullAuth("trip-driver"), data: {id: "multi-2_trip-multi", action: "accepted", version: filled.version}}));
 await functions.transitionDelivery.run({auth: fullAuth("trip-sender"), data: {id: "multi-0", status: "cancelled", reason: "Передумал"}});
 const freed = (await getDoc(doc(senderDB, "trips/trip-multi"))).data();
 assert.equal(freed.reservedKg, 10);
 await functions.respondProposal.run({auth: fullAuth("trip-driver"), data: {id: "multi-2_trip-multi", action: "accepted", version: freed.version}});
 await functions.closeTrip.run({auth: fullAuth("trip-driver"), data: {id: input.id}});
 await assertFails(getDoc(doc(senderDB, "trips/trip-multi")));
});

test("SMS proof, revoked and old-version sessions cannot read business data", async () => {
 const uid = "trip-driver";
 const proof = env.authenticatedContext(uid, {firebase: {sign_in_provider: "phone"}, phone_number: "+77011234568"}).firestore();
 await assertFails(getDoc(doc(proof, "users", uid)));
 await assertFails(getDoc(doc(proof, "trips/trip-multi")));
 await assertFails(getDoc(doc(fullContext(uid).firestore(), `passwordCredentials/${uid}`)));
 await assertFails(getDoc(doc(fullContext(uid).firestore(), `authSessions/${sessionId(uid)}`)));
 const functions = require("../functions/index");
 await assert.rejects(functions.closeTrip.run({auth: {uid, token: {firebase: {sign_in_provider: "phone"}}}, data: {id: "trip-multi"}}));
 await env.withSecurityRulesDisabled(async c => updateDoc(doc(c.firestore(), `authSessions/${sessionId(uid)}`), {revoked: true}));
 await assertFails(getDoc(doc(fullContext(uid).firestore(), "trips/trip-multi")));
 await assert.rejects(functions.closeTrip.run({auth: fullAuth(uid), data: {id: "trip-multi"}}));
 await env.withSecurityRulesDisabled(async c => {
   await updateDoc(doc(c.firestore(), `authSessions/${sessionId(uid)}`), {revoked: false});
   await updateDoc(doc(c.firestore(), `authState/${uid}`), {version: "reset-v2"});
 });
 await assertFails(getDoc(doc(fullContext(uid).firestore(), "trips/trip-multi")));
});

test("phone/password registration, custom-token login, reset same UID, and proof replay prevention", async () => {
 const functions = require("../functions/index"), {getAuth} = require("node:module").createRequire(require.resolve("../functions/index"))("firebase-admin/auth");
 const uid = "phone-test", phone = "+77010009991", password = "test-only long phrase 123", nextPassword = "test-only replacement phrase 456";
 await getAuth().createUser({uid, phoneNumber: phone});
 const now = Math.floor(Date.now()/1000), proof = {uid, token: {firebase: {sign_in_provider: "phone"}, phone_number: phone, auth_time: now}};
 const registered = await functions.registerPhone.run({auth: proof, data: {password, name: "Тест", role: "sender"}});
 assert.equal(typeof registered.token, "string");
 await assert.rejects(functions.registerPhone.run({auth: proof, data: {password, name: "Тест", role: "sender"}}));
 await assert.rejects(functions.loginPhonePassword.run({data: {phone, password: "test-only wrong password"}}));
 const login = await functions.loginPhonePassword.run({data: {phone, password}});
 const response = await fetch("http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=fake", {method: "POST", headers: {"Content-Type": "application/json"}, body: JSON.stringify({token: login.token, returnSecureToken: true})});
 assert.equal(response.status, 200);
 const session = await response.json(), decoded = await getAuth().verifyIdToken(session.idToken);
 assert.equal(decoded.uid, uid); assert.equal(decoded.firebase.sign_in_provider, "custom");
 const A = require("../functions/auth"); await A.requireSession({uid, token: decoded});
 await assert.rejects(functions.resetPhonePassword.run({auth: proof, data: {password: nextPassword}}));
 await functions.resetPhonePassword.run({auth: {...proof, token: {...proof.token, auth_time: now + 1}}, data: {password: nextPassword}});
 await assert.rejects(A.requireSession({uid, token: decoded}));
 await assert.rejects(functions.loginPhonePassword.run({data: {phone, password}}));
 const secondLogin = await functions.loginPhonePassword.run({data: {phone, password: nextPassword}});
 assert.equal(typeof secondLogin.token, "string");
 await assert.rejects(functions.resetPhonePassword.run({auth: {...proof, token: {...proof.token, auth_time: now + 1}}, data: {password}}));
 assert.equal((await getAuth().getUser(uid)).phoneNumber, phone);
 await env.withSecurityRulesDisabled(async c => updateDoc(doc(c.firestore(), `users/${uid}`), {deleting: true}));
 const resume = await functions.loginPhonePassword.run({data: {phone, password: nextPassword}});
 assert.equal(typeof resume.token, "string"); // A locked profile can reopen the deletion screen.

});

test("login attempt budget is enforced before repeated password hashing", async () => {
 const functions = require("../functions/index"), phone = "+77010009992";
 for (let i = 0; i < 8; i++) await assert.rejects(functions.loginPhonePassword.run({auth: fullAuth("attempt-user-" + i), rawRequest: {ip: "127.0.0.42"}, data: {phone, password: "test-only wrong passphrase"}}), error => error.code === "unauthenticated");
 await assert.rejects(functions.loginPhonePassword.run({rawRequest: {ip: "127.0.0.42"}, data: {phone, password: "test-only wrong passphrase"}}), error => error.code === "resource-exhausted");
});

test("live location is active-only, participant-only, ordered, revocable and expires", async () => {
 const functions = require("../functions/index");
 const s = "gps-sender", d = "gps-driver", orderId = "gps-order";
 await env.withSecurityRulesDisabled(async c => {
   for (const [uid, role] of [[s, "sender"], [d, "courier"]]) { await setDoc(doc(c.firestore(), "users", uid), user(uid, role)); await seedSession(c.firestore(), uid); }
   await setDoc(doc(c.firestore(), "deliveries", orderId), {...delivery, id: orderId, senderId: s, driverId: d, status: "accepted"});
 });
 await assert.rejects(functions.startTracking.run({auth: fullAuth(d), data: {id: orderId}}));
 await functions.transitionDelivery.run({auth: fullAuth(d), data: {id: orderId, status: "enRoute"}});
 await assert.rejects(functions.startTracking.run({auth: fullAuth(s), data: {id: orderId}}));
 const lease = await functions.startTracking.run({auth: fullAuth(d), data: {id: orderId}});
 const input = {id: orderId, sessionId: lease.sessionId, sequence: 1, coordinate: {latitude: 43.2383, longitude: 76.9455}, accuracy: 20, capturedAt: Date.now()};
 await functions.updateTracking.run({auth: fullAuth(d), data: input});
 const path = `deliveries/${orderId}/private/liveLocation`;
 await assertSucceeds(getDoc(doc(fullContext(s).firestore(), path)));
 await assertFails(getDoc(doc(fullContext("outsider").firestore(), path)));
 await assertFails(setDoc(doc(fullContext(d).firestore(), path), {coordinate: input.coordinate}));
 await functions.updateTracking.run({auth: fullAuth(d), data: input}); // Retry is idempotent.
 await assert.rejects(functions.updateTracking.run({auth: fullAuth(d), data: {...input, sequence: 2, capturedAt: Date.now() - 120000}}));
 await assert.rejects(functions.updateTracking.run({auth: fullAuth(d), data: {...input, sequence: 2, coordinate: {latitude: 99, longitude: 0}}}));
 await env.withSecurityRulesDisabled(async c => updateDoc(doc(c.firestore(), path), {visibleUntil: Timestamp.fromMillis(Date.now() - 1)}));
 await assertFails(getDoc(doc(fullContext(s).firestore(), path)));
 await functions.stopTracking.run({auth: fullAuth(d), data: {id: orderId}});
 await assert.rejects(functions.updateTracking.run({auth: fullAuth(d), data: {...input, sequence: 2, capturedAt: Date.now()}}));
 const restarted = await functions.startTracking.run({auth: fullAuth(d), data: {id: orderId}});
 assert.notEqual(restarted.sessionId, lease.sessionId);
 await functions.updateTracking.run({auth: fullAuth(d), data: {...input, sessionId: restarted.sessionId, capturedAt: Date.now()}});
 await env.withSecurityRulesDisabled(async c => updateDoc(doc(c.firestore(), `authSessions/${sessionId(d)}`), {revoked: true}));
 await assertFails(getDoc(doc(fullContext(s).firestore(), path))); // Publisher logout closes sender access too.
 await env.withSecurityRulesDisabled(async c => updateDoc(doc(c.firestore(), `authSessions/${sessionId(d)}`), {revoked: false}));
 await functions.transitionDelivery.run({auth: fullAuth(s), data: {id: orderId, status: "cancelled", reason: "Планы изменились"}});
 await assertFails(getDoc(doc(fullContext(s).firestore(), path)));
 await assert.rejects(functions.updateTracking.run({auth: fullAuth(d), data: {...input, sessionId: restarted.sessionId, sequence: 2, capturedAt: Date.now()}}));
});

test("photo transfer validates session, content, ownership and immutable publication", async () => {
 const functions = require("../functions/index");
 const uid = "photo-sender";
 await env.withSecurityRulesDisabled(async c => { await setDoc(doc(c.firestore(), "users", uid), user(uid)); await seedSession(c.firestore(), uid); });
 const data = {id: "photo-order", base64: Buffer.from([255,216,255,217]).toString("base64")};
 const upload = await functions.uploadParcelPhoto.run({auth: fullAuth(uid), data});
 assert.match(upload.path, /^parcels\/photo-sender\/photo-order\/[a-f0-9-]+\.jpg$/);
 await assert.rejects(functions.uploadParcelPhoto.run({auth: fullAuth(uid), data: {...data, base64: Buffer.from("not a jpeg").toString("base64")}}));
 await functions.createDelivery.run({auth: fullAuth(uid), data: {id: data.id, fromCity: "Алматы", toCity: "Астана", itemDescription: "Книги", size: "box", weight: 10, volume: 0.06, distanceKm: 100, price: 2100, pickupAt: Date.now()+3600000, addressFrom: "A", addressTo: "B", recipientName: "Тест", recipientPhone: "+77011234567", comment: "", photoPath: upload.path}});
 const loaded = await functions.parcelPhoto.run({auth: fullAuth(uid), data: {id: data.id}});
 assert.equal(loaded.base64, data.base64);
 await assert.rejects(functions.parcelPhoto.run({auth: fullAuth("outsider"), data: {id: data.id}}));
 const retry = await functions.uploadParcelPhoto.run({auth: fullAuth(uid), data});
 assert.equal(retry.path, upload.path);
});


test("cleanup removes expired points and orphan photos but retains current data", async () => {
 const adminRequire = require("node:module").createRequire(require.resolve("../functions/index"));
 const {getFirestore, Timestamp: AdminTimestamp} = adminRequire("firebase-admin/firestore");
 const db = getFirestore();
 const now = Date.now(), gone = db.doc("deliveries/cleanup-old/private/liveLocation"), fresh = db.doc("deliveries/cleanup-new/private/liveLocation");
 await gone.set({expiresAt: AdminTimestamp.fromMillis(now - 1)});
 await fresh.set({expiresAt: AdminTimestamp.fromMillis(now + 3600000)});
 await db.doc("deliveries/cleanup-kept").set({photoPath: "parcels/cleanup/kept.jpg"});
 for (const [id, path, deliveryId, age] of [
   ["cleanup-orphan", "parcels/cleanup/orphan.jpg", "cleanup-missing", 49],
   ["cleanup-kept", "parcels/cleanup/kept.jpg", "cleanup-kept", 49],
   ["cleanup-recent", "parcels/cleanup/recent.jpg", "cleanup-missing", 1]
 ]) await db.doc(`photoUploads/${id}`).set({path, deliveryId, createdAt: AdminTimestamp.fromMillis(now - age * 3600000)});
 const removed = [], bucket = {file: path => ({delete: async () => { removed.push(path); }})};
 await require("../functions/cleanup").cleanup(db, bucket, now);
 assert.equal((await gone.get()).exists, false); assert.equal((await fresh.get()).exists, true);
 assert.deepEqual(removed, ["parcels/cleanup/orphan.jpg"]);
 assert.equal((await db.doc("photoUploads/cleanup-recent").get()).exists, true);
});
