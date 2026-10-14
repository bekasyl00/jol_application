const {test} = require("node:test");
const assert = require("node:assert/strict");
const A = require("../functions/auth");
const T = require("../functions/tracking");
const {isLocalSuite} = require("../functions/runtime");
test("App Check bypass requires the exact demo project and all local emulators", () => {
 const env = {FUNCTIONS_EMULATOR: "true", GCLOUD_PROJECT: "demo-jol", FIREBASE_AUTH_EMULATOR_HOST: "127.0.0.1:9099", FIRESTORE_EMULATOR_HOST: "192.168.1.10:8080", FIREBASE_STORAGE_EMULATOR_HOST: "localhost:9199"};
 assert.equal(isLocalSuite(env), true);
 for (const key of Object.keys(env)) { const incomplete = {...env}; delete incomplete[key]; assert.equal(isLocalSuite(incomplete), false); }
 for (const value of ["jolparcel-kz-2026", "demo-other"]) assert.equal(isLocalSuite({...env, GCLOUD_PROJECT: value}), false);
 for (const host of ["8.8.8.8:9099", "0.0.0.0:9099", "localhost.evil:9099", "http://localhost:9099", "127.0.0.1:0", "192.168.1.1:99999"]) assert.equal(isLocalSuite({...env, FIREBASE_AUTH_EMULATOR_HOST: host}), false);
});
test("password policy supports passphrases without truncation and scrypt verifies only exact bytes", async () => {
 const password = "test-only long pass phrase";
 const verifier = await A.makeVerifier(password);
 assert.equal(verifier.algorithm, "scrypt-131072-8-1-v1");
 assert.equal(await A.checkPassword(password, verifier), true);
 assert.equal(await A.checkPassword(password + " ", verifier), false);
 assert.throws(() => A.password("short"));
 assert.throws(() => A.password("a".repeat(129)));
 assert.equal(A.password("x".repeat(64)).length, 64);
 const other = await A.makeVerifier(password);
 assert.notEqual(other.salt, verifier.salt); assert.notEqual(other.hash, verifier.hash);
});
test("location payload rejects invalid, stale and inaccurate positions", () => {
 const valid = {coordinate: {latitude: 43.2, longitude: 76.9}, accuracy: 20, capturedAt: 1000000, sequence: 1};
 assert.equal(T.validatePoint(valid, 1000000).sequence, 1);
 for (const patch of [{accuracy: -1}, {accuracy: 1500}, {sequence: 1.1}, {capturedAt: 0}, {coordinate: {latitude: NaN, longitude: 0}}]) assert.throws(() => T.validatePoint({...valid, ...patch}, 1000000));
});
