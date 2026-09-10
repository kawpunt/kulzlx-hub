"use strict";

const fs = require("fs");
const path = require("path");

const cfgPath = path.join(__dirname, "data", "workink.json");
const grantsPath = path.join(__dirname, "data", "workink-grants.json");
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function loadCfg() {
  const env = {
    link: process.env.WORKINK_LINK || "",
    apiKey: process.env.WORKINK_API_KEY || "",
    deleteToken: process.env.WORKINK_DELETE_TOKEN === "1",
    publicUrl: process.env.KULZLX_PUBLIC_URL || "",
  };
  if (fs.existsSync(cfgPath)) {
    const file = JSON.parse(fs.readFileSync(cfgPath, "utf8"));
    return {
      link: env.link || file.link || "",
      apiKey: env.apiKey || file.apiKey || "",
      deleteToken: env.deleteToken || file.deleteToken === true,
      publicUrl: env.publicUrl || file.publicUrl || "",
    };
  }
  return env;
}

function isWorkinkToken(key) {
  return UUID.test(String(key || "").trim());
}

function loadGrants() {
  if (!fs.existsSync(grantsPath)) {
    return { grants: [] };
  }
  return JSON.parse(fs.readFileSync(grantsPath, "utf8"));
}

function saveGrants(data) {
  fs.writeFileSync(grantsPath, JSON.stringify(data, null, 2));
}

function findGrant(token) {
  const store = loadGrants();
  const g = (store.grants || []).find((x) => x.token === token);
  if (!g) return null;
  if (g.expiresAfter && Date.now() > Number(g.expiresAfter)) {
    return null;
  }
  return g;
}

function saveGrant(grant) {
  const store = loadGrants();
  store.grants = (store.grants || []).filter((x) => x.token !== grant.token);
  store.grants.unshift(grant);
  saveGrants(store);
}

async function fetchJson(url, headers) {
  const res = await fetch(url, { headers: headers || {} });
  const text = await res.text();
  let data = null;
  try {
    data = JSON.parse(text);
  } catch {
    data = { raw: text };
  }
  return { status: res.status, data };
}

async function makeKeyLink(hwid, userId) {
  const cfg = loadCfg();
  if (!cfg.link || cfg.link.includes("YOUR_ID")) {
    return { ok: false, error: "workink_not_configured" };
  }
  const base = (cfg.publicUrl || "http://127.0.0.1:8787").replace(/\/+$/, "");
  const destination =
    base +
    "/auth/redeem?token={TOKEN}&uid=" +
    encodeURIComponent(String(userId || 0)) +
    "&hwid=" +
    encodeURIComponent(String(hwid || ""));
  const overrideUrl =
    "https://work.ink/_api/v2/override?destination=" + encodeURIComponent(destination);
  const headers = {};
  if (cfg.apiKey) {
    headers["X-Api-Key"] = cfg.apiKey;
  }
  const { status, data } = await fetchJson(overrideUrl, headers);
  if (!data || !data.sr) {
    return {
      ok: false,
      error: "workink_override_failed",
      detail: data,
      status,
    };
  }
  const url = cfg.link + (cfg.link.includes("?") ? "&" : "?") + "sr=" + encodeURIComponent(data.sr);
  return { ok: true, url, destination };
}

async function validateToken(token) {
  const cfg = loadCfg();
  const q = cfg.deleteToken ? "?deleteToken=1" : "";
  const headers = {};
  let url = "https://work.ink/_api/v2/token/isValid/" + encodeURIComponent(token) + q;
  if (cfg.apiKey) {
    url = "https://work.ink/_api/v2/token/verify/" + encodeURIComponent(token) + q;
    headers["X-Api-Key"] = cfg.apiKey;
  }
  const { status, data } = await fetchJson(url, headers);
  if (status === 401 || status === 403) {
    return { ok: false, error: "workink_misconfigured", status };
  }
  if (!data || data.valid !== true) {
    return { ok: false, error: "invalid_key" };
  }
  return { ok: true, info: data.info || { token }, deleted: data.deleted === true };
}

module.exports = {
  loadCfg,
  isWorkinkToken,
  findGrant,
  saveGrant,
  makeKeyLink,
  validateToken,
};
