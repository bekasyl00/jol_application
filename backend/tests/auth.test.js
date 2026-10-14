const {test} = require("node:test");
const assert = require("node:assert/strict");
const A = require("../functions/auth");
const T = require("../functions/tracking");
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
