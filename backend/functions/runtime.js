"use strict";
const {isIP} = require("node:net");

function localEndpoint(value) {
  if (typeof value !== "string") return false;
  const match = /^(localhost|[0-9.]+):([0-9]+)$/.exec(value);
  if (!match || +match[2] < 1 || +match[2] > 65535) return false;
  const host = match[1], parts = host.split(".").map(Number);
  return host === "localhost" || (isIP(host) === 4 && (host === "127.0.0.1" || parts[0] === 10 ||
    (parts[0] === 192 && parts[1] === 168) || (parts[0] === 172 && parts[1] >= 16 && parts[1] <= 31)));
}

// Never relax production App Check. Every local service and the demo project must agree.
function isLocalSuite(env = process.env) {
  return env.FUNCTIONS_EMULATOR === "true" && env.GCLOUD_PROJECT === "demo-jol" &&
    ["FIREBASE_AUTH_EMULATOR_HOST", "FIRESTORE_EMULATOR_HOST", "FIREBASE_STORAGE_EMULATOR_HOST"].every(key => localEndpoint(env[key]));
}
module.exports = {isLocalSuite};
