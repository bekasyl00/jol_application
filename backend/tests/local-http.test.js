"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {randomUUID} = require("node:crypto");
const project = "demo-jol";
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
const functionsHost = process.env.JOL_LOCAL_FUNCTIONS_HOST;
assert.ok(authHost?.startsWith("127.0.0.1:") && firestoreHost?.startsWith("127.0.0.1:") && functionsHost === "127.0.0.1:5201", "Run via npm run test:local only");
const api = `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:`;
const functions = `http://${functionsHost}/${project}/europe-west1/`;
const documents = `http://${firestoreHost}/v1/projects/${project}/databases/(default)/documents/`;

async function json(url, body, token) {
 const response = await fetch(url, {method: body === undefined ? "GET" : "POST", headers: {"Content-Type": "application/json", ...(token ? {Authorization: `Bearer ${token}`} : {})}, ...(body === undefined ? {} : {body: JSON.stringify(body)}), signal: AbortSignal.timeout(60000)});
 const data = await response.json();
 if (!response.ok || data.error) throw Object.assign(new Error(data.error?.message || `HTTP ${response.status}`), {status: response.status});
 return data;
}
async function call(name, data = {}, token) { return (await json(functions + name, {data}, token)).result; }
async function proof(phoneNumber) {
 const {sessionInfo} = await json(api + "sendVerificationCode?key=local-emulator-only", {phoneNumber});
 const codes = await json(`http://${authHost}/emulator/v1/projects/${project}/verificationCodes`);
 const code = codes.verificationCodes.find(c => c.sessionInfo === sessionInfo && c.phoneNumber === phoneNumber)?.code;
 assert.match(code, /^\d{6}$/);
 return json(api + "signInWithPhoneNumber?key=local-emulator-only", {sessionInfo, code});
}
async function custom(token) {
 const session = await json(api + "signInWithCustomToken?key=local-emulator-only", {token, returnSecureToken: true});
 const claims = JSON.parse(Buffer.from(session.idToken.split(".")[1], "base64url").toString());
 return {...session, localId: claims.sub};
}
async function user(phone, role) {
 const password = `test-only-${randomUUID()}`, sms = await proof(phone);
 // SMS confirmation alone cannot read a profile or mutate orders.
 await assert.rejects(json(documents + "users/" + sms.localId, undefined, sms.idToken), {status: 403});
 await assert.rejects(call("createDelivery", {}, sms.idToken), {status: 401});
 const session = await custom((await call("registerPhone", {password, name: "Тестовый участник", role, vehicle: role === "courier" ? "Test car" : "", capacityKg: role === "courier" ? 30 : 0}, sms.idToken)).token);
 assert.equal(session.localId, sms.localId);
 const profile = await json(documents + "users/" + session.localId, undefined, session.idToken);
 assert.equal(profile.fields.role.stringValue, role);
 return {...session, phone, password};
}

test("local HTTP: SMS proof, password sessions, two parcels, private GPS and reset revocation", {timeout: 180000}, async () => {
 assert.deepEqual(await json(functions + "localHealth"), {project});
 await assert.rejects(call("createDelivery"), {status: 401});
 const sender = await user("+77000000011", "sender");
 const courier = await user("+77000000012", "courier");
 const outsider = await user("+77000000013", "sender");
 const senderToken = sender.idToken, driverToken = courier.idToken;
 await assert.rejects(call("loginPhonePassword", {phone: sender.phone, password: "wrong-test-only-password"}), {status: 401});
 const login = await custom((await call("loginPhonePassword", {phone: sender.phone, password: sender.password})).token);
 assert.equal(login.localId, sender.localId);
 const now = Date.now() + 3600000, trip = "http-trip", orderIDs = ["http-parcel-1", "http-parcel-2"];
 await call("publishTrip", {id: trip, fromCity: "Алматы", toCity: "Астана", origin: {coordinate: {latitude: 43.2383, longitude: 76.9455}, label: "Тестовая точка A"}, destination: {coordinate: {latitude: 51.1282, longitude: 71.4304}, label: "Тестовая точка B"}, departureAt: now, capacityKg: 30, maxParcels: 3, pickupWindowMinutes: 120, maxDetourKm: 20, maxDetourMinutes: 30}, driverToken);
 for (const id of orderIDs) {
   await call("createDelivery", {id, fromCity: "Алматы", toCity: "Астана", itemDescription: "Тестовые книги", size: "box", weight: 10, volume: 0.06, distanceKm: 100, price: 2100, pickupAt: now, addressFrom: "Тестовый адрес A", addressTo: "Тестовый адрес B", recipientName: "Тестовый получатель", recipientPhone: "+77000000014", comment: "Только тест"}, senderToken);
   await call("createProposal", {tripId: trip, deliveryId: id}, senderToken);
   const data = await json(documents + "trips/" + trip, undefined, senderToken);
   assert.equal(data.fields.origin, undefined); // public catalog excludes exact stops
   await call("respondProposal", {id: `${id}_${trip}`, action: "accepted", version: +data.fields.version.integerValue}, driverToken);
 }
 const saved = await json(documents + "trips/" + trip, undefined, senderToken);
 assert.equal(+saved.fields.acceptedCount.integerValue, 2);
 assert.equal(+(saved.fields.reservedKg.integerValue || saved.fields.reservedKg.doubleValue), 20);
 const id = orderIDs[0];
 await assert.rejects(json(documents + `deliveries/${id}/private/details`, undefined, outsider.idToken), {status: 403});
 await call("transitionDelivery", {id, status: "enRoute"}, driverToken);
 const lease = await call("startTracking", {id}, driverToken);
 await call("updateTracking", {id, sessionId: lease.sessionId, coordinate: {latitude: 43.24, longitude: 76.95}, accuracy: 10, sequence: 1, capturedAt: Date.now()}, driverToken);
 assert.ok((await json(documents + `deliveries/${id}/private/liveLocation`, undefined, senderToken)).fields.coordinate);
 await assert.rejects(json(documents + `deliveries/${id}/private/liveLocation`, undefined, outsider.idToken), {status: 403});
 await call("stopTracking", {id}, driverToken);
 await assert.rejects(json(documents + `deliveries/${id}/private/liveLocation`, undefined, senderToken));
 // A fresh proof resets the password without changing identity; old sessions stop working.
 const freshProof = await proof(sender.phone), replacement = `test-replacement-${randomUUID()}`;
 await call("resetPhonePassword", {password: replacement}, freshProof.idToken);
 await assert.rejects(json(documents + "users/" + sender.localId, undefined, senderToken), {status: 403});
 await assert.rejects(call("loginPhonePassword", {phone: sender.phone, password: sender.password}), {status: 401});
 const resetLogin = await custom((await call("loginPhonePassword", {phone: sender.phone, password: replacement})).token);
 assert.equal(resetLogin.localId, sender.localId);
});
