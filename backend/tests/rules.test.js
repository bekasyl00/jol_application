const {test, before, after} = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const {initializeTestEnvironment, assertSucceeds, assertFails} = require("@firebase/rules-unit-testing");
const {doc, getDoc, setDoc, updateDoc, collection, query, where, getDocs, Timestamp} = require("firebase/firestore");
const {ref, uploadBytes, getMetadata, deleteObject} = require("firebase/storage");
let env;
const user = (id, role = "sender") => ({id, name: "Тест", phone: "+77011234567", role, vehicle: role === "courier" ? "Kia" : "", capacityKg: role === "courier" ? 50 : 0});
const delivery = {id: "order", senderId: "sender", driverId: null, fromCity: "Алматы", toCity: "Астана", itemDescription: "Книги", size: "box", weight: 10, volume: 0.06, distanceKm: 100, price: 2100, status: "waiting", pickupAt: Timestamp.now(), createdAt: Timestamp.now(), updatedAt: Timestamp.now()};
before(async () => {
 env = await initializeTestEnvironment({projectId: "demo-jol", firestore: {rules: fs.readFileSync("backend/firestore.rules", "utf8")}, storage: {rules: fs.readFileSync("backend/storage.rules", "utf8")}});
 await env.withSecurityRulesDisabled(async context => {
  const db = context.firestore();
  for (const [uid, role] of [["sender", "sender"], ["courier", "courier"], ["courier2", "courier"], ["outsider", "sender"]]) await setDoc(doc(db, "users", uid), user(uid, role));
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
 const db = env.authenticatedContext("courier").firestore();
 await assertSucceeds(getDocs(query(collection(db, "deliveries"), where("status", "==", "waiting"))));
 await assertFails(getDoc(doc(db, "deliveries/order/private/details")));
 await assertFails(getDoc(doc(db, "users", "sender")));
 await assertFails(getDocs(collection(db, "deliveries")));
});
test("sender query and private data authorized; another sender denied", async () => {
 const db = env.authenticatedContext("sender").firestore();
 await assertSucceeds(getDocs(query(collection(db, "deliveries"), where("senderId", "==", "sender"))));
 await assertSucceeds(getDoc(doc(db, "deliveries/order/private/details")));
 await assertFails(getDoc(doc(env.authenticatedContext("outsider").firestore(), "deliveries/order/private/details")));
});
test("all direct order and message mutations denied", async () => {
 const db = env.authenticatedContext("courier").firestore();
 await assertFails(updateDoc(doc(db, "deliveries/order"), {driverId: "courier", status: "accepted"}));
 const senderDB = env.authenticatedContext("sender").firestore();
 await assertFails(updateDoc(doc(senderDB, "deliveries/order"), {price: 0}));
 await assertFails(setDoc(doc(senderDB, "deliveries/order/messages/spoof"), {fromUser: "courier", text: "Spoof", timestamp: Timestamp.now()}));
});
test("profile create validates phone, role and protected fields", async () => {
 for (const [uid, patch] of [["new1", {phone: "123"}], ["new2", {role: "admin"}], ["new3", {deleting: false}], ["new4", {capacityKg: -1}]]) {
  await assertFails(setDoc(doc(env.authenticatedContext(uid).firestore(), "users", uid), {...user(uid), ...patch}));
 }
 const context = env.authenticatedContext("new-valid");
 await assertSucceeds(setDoc(doc(context.firestore(), "users/new-valid"), user("new-valid")));
 await assertFails(updateDoc(doc(context.firestore(), "users/new-valid"), {role: "courier"}));
});
test("storage uploads: only own JPEG below 5 MB; order photos immutable", async () => {
 const storage = env.authenticatedContext("sender").storage();
 await assertSucceeds(uploadBytes(ref(storage, "parcels/sender/new-order/photo.jpg"), new Uint8Array([255,216,255,217]), {contentType: "image/jpeg"}));
 await assertFails(uploadBytes(ref(storage, "parcels/sender/order/photo.jpg"), new Uint8Array([1]), {contentType: "image/jpeg"}));
 await assertFails(uploadBytes(ref(storage, "parcels/sender/not-jpeg/photo.jpg"), new Uint8Array([1]), {contentType: "text/plain"}));
 await assertFails(uploadBytes(ref(env.authenticatedContext("courier").storage(), "parcels/sender/foreign/photo.jpg"), new Uint8Array([1]), {contentType: "image/jpeg"}));
 await assertFails(getMetadata(ref(env.unauthenticatedContext().storage(), "parcels/sender/new-order/photo.jpg")));
 await assertSucceeds(deleteObject(ref(storage, "parcels/sender/new-order/photo.jpg")));
});
test("deleted account tombstone denies recreation", async () => {
 await env.withSecurityRulesDisabled(async c => setDoc(doc(c.firestore(), "users/deleted"), {id: "deleted", deleting: true}));
 await assertFails(setDoc(doc(env.authenticatedContext("deleted").firestore(), "users/deleted"), user("deleted")));
});
test("callable transactions: simultaneous claims have one winner; deletion erases PII", async () => {
 // Invoke callable handlers directly against the emulator. Transport/App Check is separately configured for production.
 const functions = require("../functions/index");
 const input = {id: "race-order", fromCity: "Алматы", toCity: "Астана", itemDescription: "Книги", size: "box", weight: 10, volume: 0.06, distanceKm: 100, price: 2100, pickupAt: Date.now() + 3600000, addressFrom: "Secret", addressTo: "Secret 2", recipientName: "Алия", recipientPhone: "+77011234567", comment: ""};
 await functions.createDelivery.run({auth: {uid: "sender"}, data: input});
 const results = await Promise.allSettled(["courier", "courier2"].map(uid => functions.acceptDelivery.run({auth: {uid}, data: {id: input.id}})));
 assert.equal(results.filter(r => r.status === "fulfilled").length, 1);
 const winner = results[0].status === "fulfilled" ? "courier" : "courier2";
 const db = env.authenticatedContext(winner).firestore();
 await assertSucceeds(getDoc(doc(db, `deliveries/${input.id}/private/details`)));
 await assert.rejects(functions.transitionDelivery.run({auth: {uid: winner}, data: {id: input.id, status: "delivered"}}));
 for (const status of ["enRoute", "pickedUp", "delivered"]) await functions.transitionDelivery.run({auth: {uid: winner}, data: {id: input.id, status}});
 await functions.reviewDelivery.run({auth: {uid: "sender"}, data: {id: input.id, text: "Спасибо!"}});
 await assert.rejects(functions.deliveryContact.run({auth: {uid: "outsider"}, data: {id: input.id}}));
 await assert.rejects(functions.deleteAccount.run({auth: {uid: "sender", token: {auth_time: Math.floor(Date.now()/1000)}}, data: {}})); // First waiting order still active.
 await functions.transitionDelivery.run({auth: {uid: "sender"}, data: {id: "order", status: "cancelled", reason: "Планы изменились"}});
 await functions.deleteAccount.run({auth: {uid: "sender", token: {auth_time: Math.floor(Date.now()/1000)}}, data: {}});
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
   await setDoc(doc(c.firestore(), "users/trip-driver"), {...user("trip-driver", "courier"), capacityKg: 25});
 });
 const input = {id: "trip-multi", fromCity: "Алматы", toCity: "Астана", origin: {coordinate: {latitude: 43.2383, longitude: 76.9455}, label: "Private origin"}, destination: {coordinate: {latitude: 51.1282, longitude: 71.4304}, label: "Private destination"}, departureAt: now, capacityKg: 25, maxParcels: 5, pickupWindowMinutes: 120, maxDetourKm: 20, maxDetourMinutes: 30};
 await functions.publishTrip.run({auth: {uid: "trip-driver"}, data: input});
 for (let i = 0; i < 3; i++) {
   await functions.createDelivery.run({auth: {uid: "trip-sender"}, data: {id: `multi-${i}`, fromCity: "Алматы", toCity: "Астана", itemDescription: "Книги", size: "box", weight: 10, volume: 0.06, distanceKm: 100, price: 2100, pickupAt: now, addressFrom: "Private pickup", addressTo: "Private dropoff", recipientName: "Алия", recipientPhone: "+77011234567", comment: ""}});
   await functions.createProposal.run({auth: {uid: "trip-sender"}, data: {tripId: input.id, deliveryId: `multi-${i}`}});
 }
 const senderDB = env.authenticatedContext("trip-sender").firestore();
 await assertSucceeds(getDoc(doc(senderDB, "trips/trip-multi")));
 await assertFails(getDoc(doc(senderDB, "trips/trip-multi/private/details")));
 await assertFails(getDoc(doc(env.authenticatedContext("outsider").firestore(), "proposals/multi-0_trip-multi")));
 await assertFails(setDoc(doc(senderDB, "trips/spoof"), input));
 let version = (await getDoc(doc(senderDB, "trips/trip-multi"))).data().version;
 const race = await Promise.allSettled([0, 1].map(i => functions.respondProposal.run({auth: {uid: "trip-driver"}, data: {id: `multi-${i}_trip-multi`, action: "accepted", version}})));
 assert.equal(race.filter(r => r.status === "fulfilled").length, 1);
 const loser = race[0].status === "fulfilled" ? 1 : 0;
 version = (await getDoc(doc(senderDB, "trips/trip-multi"))).data().version;
 await functions.respondProposal.run({auth: {uid: "trip-driver"}, data: {id: `multi-${loser}_trip-multi`, action: "accepted", version}});
 const filled = (await getDoc(doc(senderDB, "trips/trip-multi"))).data();
 assert.equal(filled.acceptedCount, 2); assert.equal(filled.reservedKg, 20);
 await assert.rejects(functions.respondProposal.run({auth: {uid: "trip-driver"}, data: {id: "multi-2_trip-multi", action: "accepted", version: filled.version}}));
 await functions.transitionDelivery.run({auth: {uid: "trip-sender"}, data: {id: "multi-0", status: "cancelled", reason: "Передумал"}});
 const freed = (await getDoc(doc(senderDB, "trips/trip-multi"))).data();
 assert.equal(freed.reservedKg, 10);
 await functions.respondProposal.run({auth: {uid: "trip-driver"}, data: {id: "multi-2_trip-multi", action: "accepted", version: freed.version}});
 await functions.closeTrip.run({auth: {uid: "trip-driver"}, data: {id: input.id}});
 await assertFails(getDoc(doc(senderDB, "trips/trip-multi")));
});
