#!/usr/bin/env node
"use strict";

const http = require("http");
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
const { URL } = require("url");

const ROOT = __dirname;
const HUB_ROOT = path.resolve(ROOT, "..");
const PORT = Number(process.env.KULZLX_PORT || process.env.VGC_PORT || 8787);
const HOST = process.env.KULZLX_HOST || process.env.VGC_HOST || "127.0.0.1";
const SESSION_TTL_MS = 6 * 60 * 60 * 1000;
const HB_TTL_MS = 90 * 1000;

function mustRead(p) {
  if (!fs.existsSync(p)) {
    throw new Error("missing " + p + " — run: node gen-keys.js");
  }
  return fs.readFileSync(p, "utf8");
}

const PRIVATE_PEM = mustRead(path.join(ROOT, "keys", "private.pem"));
const PUBLIC_PEM = mustRead(path.join(ROOT, "keys", "public.pem"));
const FINGERPRINT = crypto.createHash("sha256").update(PUBLIC_PEM).digest("hex");
const workink = require("./workink");
const CATALOG = JSON.parse(fs.readFileSync(path.join(ROOT, "catalog.json"), "utf8"));
const licensesPath = path.join(ROOT, "data", "licenses.json");

function loadLicenses() {
  return JSON.parse(fs.readFileSync(licensesPath, "utf8"));
}

function saveLicenses(data) {
  fs.writeFileSync(licensesPath, JSON.stringify(data, null, 2));
}

const sessions = new Map();

function sign(data) {
  return crypto
    .sign("sha256", Buffer.from(data), {
      key: PRIVATE_PEM,
      padding: crypto.constants.RSA_PKCS1_PSS_PADDING,
      saltLength: 32,
    })
    .toString("base64");
}

function verify(data, sigB64) {
  try {
    return crypto.verify(
      "sha256",
      Buffer.from(data),
      {
        key: PUBLIC_PEM,
        padding: crypto.constants.RSA_PKCS1_PSS_PADDING,
        saltLength: 32,
      },
      Buffer.from(sigB64, "base64")
    );
  } catch {
    return false;
  }
}

function sha256(buf) {
  return crypto.createHash("sha256").update(buf).digest("hex");
}

function envelope(payload) {
  const body = typeof payload === "string" ? payload : JSON.stringify(payload);
  const hash = sha256(body);
  return {
    ok: true,
    alg: "RSA-PSS-SHA256",
    fingerprint: FINGERPRINT,
    sha256: hash,
    sig: sign(hash),
    ts: Date.now(),
    payload: typeof payload === "string" ? undefined : payload,
    body: typeof payload === "string" ? body : undefined,
  };
}

function html(res, code, body) {
  res.writeHead(code, {
    "Content-Type": "text/html; charset=utf-8",
    "Access-Control-Allow-Origin": "*",
  });
  res.end(body);
}

function redeemPage(token, uid, hwid) {
  const shown = token && token !== "{TOKEN}" ? token : "waiting for Work.ink…";
  return `<!doctype html>
<html><head><meta charset="utf-8"><title>Kulzlx Hub key</title>
<style>
body{margin:0;font-family:Segoe UI,sans-serif;background:#0e1016;color:#e8eef8;display:flex;min-height:100vh;align-items:center;justify-content:center}
.card{width:460px;background:#161821;border-radius:14px;padding:28px;box-shadow:0 12px 40px #0008}
h1{margin:0 0 8px;font-size:22px}p{color:#9aa6b8;line-height:1.45}
code{display:block;margin:16px 0;padding:14px;background:#0b0d14;border-radius:8px;word-break:break-all;font-size:14px;color:#7ec8ff}
</style></head>
<body><div class="card">
<h1>Kulzlx Hub</h1>
<p>Work.ink finished. Copy this token into the loader Unlock box.</p>
<code>${shown}</code>
<p>uid ${uid || 0} · hwid ${hwid || "-"}</p>
</div></body></html>`;
}

function json(res, code, obj) {
  const raw = JSON.stringify(obj);
  res.writeHead(code, {
    "Content-Type": "application/json; charset=utf-8",
    "Content-Length": Buffer.byteLength(raw),
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type, Authorization, X-KULZLX-Key, X-KULZLX-HWID, X-KULZLX-Session, X-VGC-Key, X-VGC-HWID, X-VGC-Session",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  });
  res.end(raw);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => {
      const raw = Buffer.concat(chunks).toString("utf8");
      if (!raw) return resolve({});
      try {
        resolve(JSON.parse(raw));
      } catch (err) {
        reject(err);
      }
    });
    req.on("error", reject);
  });
}

function bearer(req) {
  const auth = req.headers.authorization || "";
  const m = auth.match(/^Bearer\s+(.+)$/i);
  if (m) return m[1];
  return req.headers["x-kulzlx-session"] || req.headers["x-vgc-session"] || "";
}

function getSession(req) {
  const token = bearer(req);
  if (!token) return null;
  const s = sessions.get(token);
  if (!s) return null;
  if (Date.now() > s.expires) {
    sessions.delete(token);
    return null;
  }
  return s;
}

function requireSession(req, res) {
  const s = getSession(req);
  if (!s) {
    json(res, 401, { ok: false, error: "invalid_session" });
    return null;
  }
  return s;
}

function findGame(placeId, universeId, scriptId) {
  if (scriptId) {
    return CATALOG.games.find((g) => g.id === scriptId) || null;
  }
  const pid = Number(placeId);
  const uid = Number(universeId);
  return (
    CATALOG.games.find(
      (g) =>
        (pid && (g.placeIds || []).includes(pid)) ||
        (uid && (g.universeIds || []).includes(uid))
    ) || null
  );
}

function readHubFile(file) {
  const full = path.join(HUB_ROOT, file);
  if (!fs.existsSync(full)) return null;
  return fs.readFileSync(full, "utf8");
}

function issueSession(license, hwid, userId) {
  const nonce = crypto.randomBytes(16).toString("hex");
  const claims = {
    sub: license.key,
    role: license.role,
    hwid,
    uid: userId || 0,
    nonce,
    iat: Date.now(),
    exp: Date.now() + SESSION_TTL_MS,
  };
  const payload = JSON.stringify(claims);
  const token = Buffer.from(payload).toString("base64url") + "." + sign(payload);
  sessions.set(token, {
    ...claims,
    token,
    expires: claims.exp,
    lastHb: Date.now(),
  });
  return { token, claims };
}

async function handle(req, res) {
  const url = new URL(req.url, `http://${HOST}:${PORT}`);
  const route = url.pathname.replace(/\/+$/, "") || "/";

  if (req.method === "OPTIONS") {
    json(res, 204, { ok: true });
    return;
  }

  if (req.method === "GET" && (route === "/auth" || route === "/auth/pubkey")) {
    json(res, 200, envelope({ fingerprint: FINGERPRINT, publicKey: PUBLIC_PEM, alg: "RSA-PSS-SHA256" }));
    return;
  }

    if (req.method === "GET" && route === "/auth/redeem") {
      html(
        res,
        200,
        redeemPage(url.searchParams.get("token"), url.searchParams.get("uid"), url.searchParams.get("hwid"))
      );
      return;
    }

    if (req.method === "POST" && route === "/auth/keylink") {
      const body = await readBody(req);
      const made = await workink.makeKeyLink(body.hwid, body.userId);
      if (!made.ok) {
        json(res, 400, made);
        return;
      }
      json(res, 200, envelope({ url: made.url }));
      return;
    }

    if (req.method === "POST" && (route === "/auth/access" || route === "/access")) {
    const body = await readBody(req);
    const key = String(body.key || req.headers["x-kulzlx-key"] || req.headers["x-vgc-key"] || "").trim();
    const hwid = String(body.hwid || req.headers["x-kulzlx-hwid"] || req.headers["x-vgc-hwid"] || "").trim();
    const userId = Number(body.userId || 0);
    const executor = String(body.executor || "");
    const placeId = Number(body.placeId || 0);
    const universeId = Number(body.universeId || 0);

    if (!key) {
      json(res, 400, { ok: false, error: "missing_key" });
      return;
    }

    const store = loadLicenses();
    let license = (store.licenses || []).find((l) => {
      if (l.key === key) return true;
      return (l.aliases || []).includes(key);
    });

    if (!license && workink.isWorkinkToken(key)) {
      const cached = workink.findGrant(key);
      if (cached) {
        if (cached.hwid && hwid && cached.hwid !== hwid) {
          json(res, 403, { ok: false, error: "hwid_mismatch" });
          return;
        }
        license = {
          key,
          role: "user",
          source: "workink",
          hwid: cached.hwid || hwid,
          expires: cached.expiresAfter ? new Date(Number(cached.expiresAfter)).toISOString() : null,
        };
      } else {
        const checked = await workink.validateToken(key);
        if (!checked.ok) {
          json(res, 401, { ok: false, error: checked.error || "invalid_key" });
          return;
        }
        const info = checked.info || {};
        license = {
          key,
          role: "user",
          source: "workink",
          hwid,
          expires: info.expiresAfter ? new Date(Number(info.expiresAfter)).toISOString() : null,
        };
        workink.saveGrant({
          token: key,
          hwid,
          userId,
          linkId: info.linkId,
          expiresAfter: info.expiresAfter || Date.now() + SESSION_TTL_MS,
        });
      }
    }

    if (!license) {
      json(res, 401, { ok: false, error: "invalid_key" });
      return;
    }
    if (license.expires && Date.parse(license.expires) < Date.now()) {
      json(res, 403, { ok: false, error: "key_expired" });
      return;
    }
    if (license.hwid && hwid && license.hwid !== hwid) {
      json(res, 403, { ok: false, error: "hwid_mismatch" });
      return;
    }
    if (!license.hwid && hwid) {
      license.hwid = hwid;
      license.boundAt = new Date().toISOString();
      saveLicenses(store);
    }

    const { token, claims } = issueSession(license, hwid, userId);
    const game = findGame(placeId, universeId, body.scriptId);
    json(
      res,
      200,
      envelope({
        access: true,
        token,
        role: license.role,
        claims,
        fingerprint: FINGERPRINT,
        executor,
        game: game && { id: game.id, name: game.name, file: game.file, label: game.label },
      })
    );
    return;
  }

  if (req.method === "GET" && route === "/hub") {
    const s = requireSession(req, res);
    if (!s) return;
    json(
      res,
      200,
      envelope({
        name: CATALOG.name,
        version: CATALOG.version,
        games: CATALOG.games.map((g) => ({
          id: g.id,
          name: g.name,
          placeIds: g.placeIds,
          universeIds: g.universeIds,
          file: g.file,
          label: g.label,
        })),
      })
    );
    return;
  }

  if (req.method === "GET" && route.startsWith("/cdn/")) {
    const s = requireSession(req, res);
    if (!s) return;
    const scriptId = decodeURIComponent(route.slice("/cdn/".length));
    const game = findGame(url.searchParams.get("placeId"), url.searchParams.get("universeId"), scriptId);
    if (!game) {
      json(res, 404, { ok: false, error: "unknown_script" });
      return;
    }
    const src = readHubFile(game.file);
    if (!src) {
      json(res, 404, { ok: false, error: "script_missing", file: game.file });
      return;
    }
    json(
      res,
      200,
      envelope({
        id: game.id,
        name: game.name,
        file: game.file,
        label: game.label,
        sha256: sha256(src),
        script: src,
      })
    );
    return;
  }

  if (req.method === "POST" && (route === "/hb" || route === "/heartbeat")) {
    const s = requireSession(req, res);
    if (!s) return;
    if (Date.now() - s.lastHb > HB_TTL_MS * 3) {
      sessions.delete(s.token);
      json(res, 401, { ok: false, error: "session_expired" });
      return;
    }
    s.lastHb = Date.now();
    s.expires = Date.now() + SESSION_TTL_MS;
    json(res, 200, envelope({ hb: true, role: s.role, serverTime: Date.now() }));
    return;
  }

  if (req.method === "GET" && route === "/task") {
    const s = requireSession(req, res);
    if (!s) return;
    json(
      res,
      200,
      envelope({
        tasks: [
          { id: "hb", every: 45, path: "/hb" },
          { id: "revalidate", every: 300, path: "/auth/access" },
        ],
      })
    );
    return;
  }

  if (req.method === "GET" && route.startsWith("/model/")) {
    const s = requireSession(req, res);
    if (!s) return;
    const name = decodeURIComponent(route.slice("/model/".length));
    json(
      res,
      200,
      envelope({
        model: name,
        rsa: { alg: "RSA-PSS-SHA256", fingerprint: FINGERPRINT },
        catalog: CATALOG.name,
      })
    );
    return;
  }

  if (req.method === "POST" && route === "/auth/verify") {
    const body = await readBody(req);
    const ok = body && body.sha256 && body.sig && verify(String(body.sha256), String(body.sig));
    json(res, 200, { ok: !!ok, fingerprint: FINGERPRINT });
    return;
  }

  json(res, 404, { ok: false, error: "not_found", route });
}

const server = http.createServer((req, res) => {
  handle(req, res).catch((err) => {
    json(res, 500, { ok: false, error: "server_error", detail: String(err && err.message) });
  });
});

server.listen(PORT, HOST, () => {
  console.log(`Kulzlx Hub auth listening on http://${HOST}:${PORT}`);
  console.log("RSA fingerprint", FINGERPRINT);
  console.log("routes  /auth/access  /auth/keylink  /auth/redeem  /hub  /cdn/:id  /hb  /task  /model/:name");
});
