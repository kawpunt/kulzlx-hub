#!/usr/bin/env node
"use strict";

const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const root = __dirname;
const keysDir = path.join(root, "keys");
const dataDir = path.join(root, "data");
fs.mkdirSync(keysDir, { recursive: true });
fs.mkdirSync(dataDir, { recursive: true });

const { publicKey, privateKey } = crypto.generateKeyPairSync("rsa", {
  modulusLength: 2048,
  publicKeyEncoding: { type: "spki", format: "pem" },
  privateKeyEncoding: { type: "pkcs8", format: "pem" },
});

fs.writeFileSync(path.join(keysDir, "private.pem"), privateKey, { mode: 0o600 });
fs.writeFileSync(path.join(keysDir, "public.pem"), publicKey);

const fingerprint = crypto.createHash("sha256").update(publicKey).digest("hex");
fs.writeFileSync(
  path.join(keysDir, "fingerprint.txt"),
  fingerprint + "\n"
);

function makeKey() {
  const raw = crypto.randomBytes(9).toString("hex").toUpperCase();
  return `KULZLX-${raw.slice(0, 4)}-${raw.slice(4, 8)}-${raw.slice(8, 12)}-${raw.slice(12, 18)}`;
}

const licensesPath = path.join(dataDir, "licenses.json");
let licenses = { licenses: [] };
if (fs.existsSync(licensesPath)) {
  licenses = JSON.parse(fs.readFileSync(licensesPath, "utf8"));
}

const ownerKey = makeKey();
licenses.licenses = licenses.licenses.filter((l) => l.role !== "owner");
licenses.licenses.unshift({
  key: ownerKey,
  role: "owner",
  hwid: null,
  maxHwid: 3,
  expires: null,
  note: "local owner key — regenerate with npm run keys",
  createdAt: new Date().toISOString(),
});
fs.writeFileSync(licensesPath, JSON.stringify(licenses, null, 2));

console.log("RSA-2048 keypair written to hub_loader/keys/");
console.log("fingerprint", fingerprint);
console.log("owner key", ownerKey);
