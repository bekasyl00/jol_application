"use strict";
const {randomBytes, randomUUID, scrypt, timingSafeEqual, createHash} = require("node:crypto");
const {promisify} = require("node:util");
const {getFirestore, Timestamp, FieldValue} = require("firebase-admin/firestore");
const {getAuth} = require("firebase-admin/auth");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const D = require("./domain");
const derive = promisify(scrypt);
const cost = {N: 131072, r: 8, p: 1, maxmem: 192 * 1024 * 1024};
const hashKey = value => createHash("sha256").update(value).digest("hex");
function phone(value) { if (typeof value !== "string" || !/^\+7\d{10}$/.test(value)) throw new HttpsError("invalid-argument", "Введите телефон в формате +7XXXXXXXXXX."); return value; }
function password(value) {
  if (typeof value !== "string" || [...value].length < 15 || [...value].length > 128 || Buffer.byteLength(value, "utf8") > 512) throw new HttpsError("invalid-argument", "Пароль: от 15 до 128 символов.");
  return value;
}
async function makeVerifier(value) {
  const salt = randomBytes(16).toString("hex");
  const result = await derive(password(value), salt, 64, cost);
  return {salt, hash: result.toString("hex"), algorithm: "scrypt-131072-8-1-v1"};
}
async function checkPassword(value, verifier) {
  // A missing account still performs the same expensive derivation.
  const salt = verifier?.salt || "00000000000000000000000000000000";
  const hash = await derive(password(value), salt, 64, cost);
  const expected = Buffer.from(verifier?.hash || "00".repeat(64), "hex");
  return !!verifier && verifier.algorithm === "scrypt-131072-8-1-v1" && expected.length === hash.length && timingSafeEqual(hash, expected);
}
async function requireSession(auth, tx) {
  const db = getFirestore(), token = auth?.token;
  if (!auth?.uid || token?.firebase?.sign_in_provider !== "custom" || typeof token.jolSession !== "string" || !/^[a-f0-9-]{36}$/.test(token.jolSession)) throw new HttpsError("unauthenticated", "Войдите по телефону и паролю.");
  const read = ref => tx ? tx.get(ref) : ref.get();
  const session = (await read(db.doc(`authSessions/${token.jolSession}`))).data();
  const state = (await read(db.doc(`authState/${auth.uid}`))).data();
  if (!session || session.uid !== auth.uid || session.revoked || session.expiresAt.toMillis() <= Date.now() || !state || state.version !== session.version || token.jolVersion !== state.version) throw new HttpsError("unauthenticated", "Сессия завершена. Войдите снова.");
  return session;
}
async function issueSession(uid, version) {
  const db = getFirestore(), sessionId = randomUUID();
  await db.runTransaction(async tx => {
    const state = (await tx.get(db.doc(`authState/${uid}`))).data();
    const user = (await tx.get(db.doc(`users/${uid}`))).data();
    if (!state || state.version !== version || !user) throw new HttpsError("unauthenticated", "Войдите снова.");
    // A deleting profile may sign in to resume cleanup; business operations still reject it.
    tx.create(db.doc(`authSessions/${sessionId}`), {uid, version, revoked: false, issuedAt: Timestamp.now(), expiresAt: Timestamp.fromMillis(Date.now() + 30 * 86400000)});
  });
  return {token: await getAuth().createCustomToken(uid, {jolSession: sessionId, jolVersion: version})};
}
async function quota(request, scope) {
  const db = getFirestore(), now = Date.now();
  // Raw request IP is supplied by the Functions HTTP runtime. Do not read user supplied IP fields.
  const ip = request.rawRequest?.ip || "unknown";
  const identity = scope === "login" ? (request.data?.phone || "unknown") : (request.auth?.uid || "unknown");
  const keys = [[`ip:${ip}`, 30], [`identity:${identity}`, 8]];
  await db.runTransaction(async tx => {
    const refs = keys.map(([key]) => db.doc(`authQuotas/${hashKey(scope + key)}`));
    const snaps = await Promise.all(refs.map(ref => tx.get(ref)));
    const values = snaps.map(s => s.data());
    values.forEach((v, i) => { if (v && now - v.start < 900000 && v.count >= keys[i][1]) throw new HttpsError("resource-exhausted", "Слишком много попыток. Повторите через 15 минут."); });
    refs.forEach((ref, i) => tx.set(ref, {start: values[i] && now - values[i].start < 900000 ? values[i].start : now, count: values[i] && now - values[i].start < 900000 ? values[i].count + 1 : 1, expiresAt: Timestamp.fromMillis(now + 86400000)}));
  });
}
function endpoint(scope, handler) {
  return onCall({region: "europe-west1", enforceAppCheck: true, memory: "512MiB", concurrency: 2, maxInstances: 5, timeoutSeconds: 60}, async request => {
    try { await quota(request, scope); return await handler(request); }
    catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof D.DomainError) throw new HttpsError(error.code, error.message);
      console.error("Authentication operation failed", {code: error.code || "internal"});
      throw new HttpsError("internal", "Не удалось выполнить вход. Повторите позже.");
    }
  });
}
async function phoneProof(request) {
  const auth = request.auth, token = auth?.token, now = Math.floor(Date.now() / 1000);
  if (!auth?.uid || token?.firebase?.sign_in_provider !== "phone" || !Number.isFinite(token.auth_time) || now - token.auth_time > 300 || token.auth_time > now + 30) throw new HttpsError("unauthenticated", "Подтвердите номер новым SMS-кодом.");
  const verifiedPhone = phone(token.phone_number);
  const record = await getAuth().getUser(auth.uid);
  if (record.disabled || record.phoneNumber !== verifiedPhone) throw new HttpsError("unauthenticated", "Подтверждение номера недействительно.");
  return {uid: auth.uid, phone: verifiedPhone, authTime: token.auth_time};
}
function handlers() {
  const db = getFirestore();
  return {
    loginPhonePassword: endpoint("login", async request => {
      const number = phone(request.data?.phone), value = password(request.data?.password);
      const index = (await db.doc(`phoneIndex/${hashKey(number)}`).get()).data();
      const credential = index ? (await db.doc(`passwordCredentials/${index.uid}`).get()).data() : null;
      const valid = await checkPassword(value, credential);
      if (!valid) throw new HttpsError("unauthenticated", "Неверный телефон или пароль.");
      const user = await getAuth().getUser(index.uid);
      if (user.disabled || user.phoneNumber !== number) throw new HttpsError("unauthenticated", "Неверный телефон или пароль.");
      return issueSession(index.uid, credential.version);
    }),
    registerPhone: endpoint("proof", async request => {
      const proof = await phoneProof(request), input = request.data || {};
      const verifier = await makeVerifier(input.password), version = randomUUID();
      await db.runTransaction(async tx => {
        const userRef = db.doc(`users/${proof.uid}`), credentialRef = db.doc(`passwordCredentials/${proof.uid}`), indexRef = db.doc(`phoneIndex/${hashKey(proof.phone)}`);
        const [user, credential, index] = await Promise.all([userRef, credentialRef, indexRef].map(ref => tx.get(ref)));
        if (credential.exists || (index.exists && index.data().uid !== proof.uid)) throw new HttpsError("already-exists", "Аккаунт уже зарегистрирован. Войдите или восстановите пароль.");
        if (user.data()?.deleting) throw new HttpsError("permission-denied", "Аккаунт удаляется.");
        // Existing accounts may migrate only after linking and verifying the number on the same UID.
        const role = user.exists ? user.data().role : input.role;
        if (!["sender", "courier"].includes(role)) throw new HttpsError("invalid-argument", "Выберите роль.");
        const profile = user.exists ? {...user.data(), phone: proof.phone} : {id: proof.uid, name: D.text(input.name, "имя", 2, 80), phone: proof.phone, role,
          vehicle: role === "courier" ? D.text(input.vehicle, "автомобиль", 1, 100) : "", capacityKg: role === "courier" ? D.number(input.capacityKg, "грузоподъёмность", 0.1, 5000) : 0};
        tx.set(userRef, profile); tx.create(credentialRef, {...verifier, version, lastProofAuthTime: proof.authTime});
        tx.set(indexRef, {uid: proof.uid}); tx.set(db.doc(`authState/${proof.uid}`), {version});
      });
      return issueSession(proof.uid, version);
    }),
    resetPhonePassword: endpoint("proof", async request => {
      const proof = await phoneProof(request), verifier = await makeVerifier(request.data?.password), version = randomUUID();
      await db.runTransaction(async tx => {
        const ref = db.doc(`passwordCredentials/${proof.uid}`), current = (await tx.get(ref)).data();
        const user = (await tx.get(db.doc(`users/${proof.uid}`))).data();
        const index = (await tx.get(db.doc(`phoneIndex/${hashKey(proof.phone)}`))).data();
        if (!current || !user || user.deleting || index?.uid !== proof.uid) throw new HttpsError("failed-precondition", "Завершите регистрацию.");
        if (proof.authTime <= current.lastProofAuthTime) throw new HttpsError("unauthenticated", "Запросите новый SMS-код для восстановления.");
        tx.set(ref, {...verifier, version, lastProofAuthTime: proof.authTime}); tx.set(db.doc(`authState/${proof.uid}`), {version});
      });
      await getAuth().revokeRefreshTokens(proof.uid);
      return {ok: true};
    }),
    revokeSession: endpoint("session", async request => {
      await db.runTransaction(async tx => {
        await requireSession(request.auth, tx);
        tx.update(db.doc(`authSessions/${request.auth.token.jolSession}`), {revoked: true});
      });
      return {ok: true};
    })
  };
}
module.exports = {handlers, requireSession, makeVerifier, checkPassword, phone, password, hashKey};
