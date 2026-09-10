#!/usr/bin/env node
"use strict";

const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const ROOT = __dirname;
const SRC = path.resolve(ROOT, "..", "loader.lua")
const OUT = path.resolve(ROOT, "..", "loader.obf.lua");
const STUB = path.join(ROOT, "stub_rsa_aes.lua");
const PRIVATE_PEM = fs.readFileSync(path.join(ROOT, "keys", "private.pem"), "utf8");
const PUBLIC_PEM = fs.readFileSync(path.join(ROOT, "keys", "public.pem"), "utf8");

const src = fs.readFileSync(SRC);
const aesKey = crypto.randomBytes(32);
const iv = crypto.randomBytes(16);
const cipher = crypto.createCipheriv("aes-256-cbc", aesKey, iv);
const ct = Buffer.concat([cipher.update(src), cipher.final()]);

const wrap = crypto.privateEncrypt(
  { key: PRIVATE_PEM, padding: crypto.constants.RSA_PKCS1_PADDING },
  aesKey
);

const check = crypto.publicDecrypt(
  { key: PUBLIC_PEM, padding: crypto.constants.RSA_PKCS1_PADDING },
  wrap
);
if (!check.equals(aesKey)) {
  throw new Error("RSA wrap roundtrip failed");
}

const dec = crypto.createDecipheriv("aes-256-cbc", aesKey, iv);
const plain = Buffer.concat([dec.update(ct), dec.final()]);
if (!plain.equals(src)) {
  throw new Error("AES roundtrip failed");
}

const jwk = crypto.createPublicKey(PUBLIC_PEM).export({ format: "jwk" });
const nhex = Buffer.from(jwk.n, "base64url").toString("hex");
const ehex = Buffer.from(jwk.e, "base64url").toString("hex");

let stub = fs.readFileSync(STUB, "utf8");
stub = stub
  .replace("{{NHEX}}", nhex)
  .replace("{{EHEX}}", ehex)
  .replace("{{WRAP}}", wrap.toString("base64"))
  .replace("{{IV}}", iv.toString("base64"))
  .replace("{{CT}}", ct.toString("base64"));

if (stub.includes("{{")) {
  throw new Error("placeholder leftover");
}

fs.writeFileSync(OUT, stub);
console.log("wrote", OUT);
console.log("src", src.length, "bytes → cipher", ct.length, "bytes");
console.log("RSA-2048 wrap + AES-256-CBC, public n", nhex.slice(0, 16) + "…");
