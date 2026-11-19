// Mapeleven accounts and API keys.
//
// - Sign in with GitHub, create keys, see usage: /auth/*, /api/* (the dashboard is /account/ on the site).
// - Serves the map styles (/styles/*). With ?key=, tile URLs in the style carry the key.
// - Caddy asks /check before search and routing requests and keyed tile requests (forward_auth): it validates the
//   key, applies the free monthly limits and the per-IP limit for requests without a key, and counts usage.
//
// Runs on Bun with no dependencies: bun run server.ts
import { Database } from "bun:sqlite";
import { createHmac, randomBytes, timingSafeEqual } from "node:crypto";
import { readFileSync, statSync } from "node:fs";

const env = process.env;
const DOMAIN = env.DOMAIN ?? "localhost";
const BASE = `https://${DOMAIN}`;
const PORT = Number(env.PORT ?? 8081);
const STYLES_DIR = env.STYLES_DIR ?? "/srv/styles";
const TILES_URL = env.TILES_URL ?? "http://tiles:8080";
const SESSION_SECRET = env.SESSION_SECRET ?? "";
const GITHUB_CLIENT_ID = env.GITHUB_CLIENT_ID ?? "";
const GITHUB_CLIENT_SECRET = env.GITHUB_CLIENT_SECRET ?? "";
const LIMITS = {
  map: Number(env.FREE_MAP_LOADS ?? 50_000),
  search: Number(env.FREE_SEARCHES ?? 50_000),
};
const ANON_SEARCH_PER_MINUTE = Number(env.ANON_SEARCH_PER_MINUTE ?? 120);
const MAX_KEYS = 20;
const SESSION_DAYS = 30;

// Without a session secret the server still serves styles and checks keys; sign-in is off.
const ACCOUNTS = SESSION_SECRET.length >= 32;
if (!ACCOUNTS) console.warn("SESSION_SECRET not set (32+ characters): sign-in and the account API are off");

// ---------- Database ----------

const db = new Database(env.DB_PATH ?? "/data/mapeleven.db", { create: true });
db.exec(`
  PRAGMA journal_mode = WAL;
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY,
    github_id INTEGER UNIQUE NOT NULL,
    login TEXT NOT NULL,
    name TEXT,
    avatar TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  );
  CREATE TABLE IF NOT EXISTS keys (
    id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),
    token TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    origins TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    revoked_at TEXT
  );
  CREATE TABLE IF NOT EXISTS usage (
    key_id INTEGER NOT NULL,
    day TEXT NOT NULL,
    kind TEXT NOT NULL,
    count INTEGER NOT NULL,
    PRIMARY KEY (key_id, day, kind)
  );
`);

type Kind = "map" | "search" | "tile";
interface Key {
  id: number;
  userId: number;
  token: string;
  name: string;
  origins: string[];
  createdAt: string;
  revoked: boolean;
}

const keysByToken = new Map<string, Key>();
function rowToKey(r: any): Key {
  return {
    id: r.id,
    userId: r.user_id,
    token: r.token,
    name: r.name,
    origins: r.origins ? r.origins.split(",") : [],
    createdAt: r.created_at,
    revoked: !!r.revoked_at,
  };
}
for (const r of db.query("SELECT * FROM keys").all()) {
  const k = rowToKey(r);
  keysByToken.set(k.token, k);
}

// ---------- Usage counting ----------

const today = () => new Date().toISOString().slice(0, 10);
const thisMonth = () => new Date().toISOString().slice(0, 7);

// Pending increments, flushed to SQLite every 15 seconds: "keyId|day|kind" -> n. Key 0 = no key.
const pending = new Map<string, number>();
// Running monthly totals per user for the limits: "userId|month|kind" -> n.
const monthTotals = new Map<string, number>();
for (const r of db
  .query(
    `SELECT k.user_id AS user_id, u.kind AS kind, SUM(u.count) AS n FROM usage u JOIN keys k ON k.id = u.key_id
     WHERE substr(u.day, 1, 7) = ? GROUP BY k.user_id, u.kind`,
  )
  .all(thisMonth()) as any[]) {
  monthTotals.set(`${r.user_id}|${thisMonth()}|${r.kind}`, r.n);
}

function count(keyId: number, userId: number, kind: Kind) {
  const p = `${keyId}|${today()}|${kind}`;
  pending.set(p, (pending.get(p) ?? 0) + 1);
  if (userId) {
    const m = `${userId}|${thisMonth()}|${kind}`;
    monthTotals.set(m, (monthTotals.get(m) ?? 0) + 1);
  }
}

const upsertUsage = db.prepare(
  `INSERT INTO usage (key_id, day, kind, count) VALUES (?, ?, ?, ?)
   ON CONFLICT (key_id, day, kind) DO UPDATE SET count = count + excluded.count`,
);
const flush = db.transaction(() => {
  for (const [p, n] of pending) {
    const [keyId, day, kind] = p.split("|");
    upsertUsage.run(Number(keyId), day, kind, n);
  }
  pending.clear();
});
setInterval(flush, 15_000);
for (const sig of ["SIGTERM", "SIGINT"]) {
  process.on(sig, () => {
    flush();
    process.exit(0);
  });
}

function overLimit(userId: number, kind: Kind): boolean {
  if (kind === "tile") return false;
  return (monthTotals.get(`${userId}|${thisMonth()}|${kind}`) ?? 0) >= LIMITS[kind];
}

// Requests without a key: search is limited per IP per minute.
const anonWindows = new Map<string, { minute: number; n: number }>();
function anonAllowed(ip: string): boolean {
  const minute = Math.floor(Date.now() / 60_000);
  const w = anonWindows.get(ip);
  if (!w || w.minute !== minute) {
    anonWindows.set(ip, { minute, n: 1 });
    return true;
  }
  return ++w.n <= ANON_SEARCH_PER_MINUTE;
}
setInterval(() => {
  const minute = Math.floor(Date.now() / 60_000);
  for (const [ip, w] of anonWindows) if (w.minute < minute) anonWindows.delete(ip);
}, 60_000);

// ---------- Key checks ----------

function json(body: unknown, status = 200, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store", ...headers },
  });
}
const fail = (status: number, error: string) => json({ error }, status);

/** Host of the page that made the request (Origin, else Referer), or null for apps and servers. */
function requestHost(headers: Headers): string | null {
  const from = headers.get("origin") ?? headers.get("referer");
  if (!from || from === "null") return null;
  try {
    return new URL(from).hostname.toLowerCase();
  } catch {
    return null;
  }
}

function originAllowed(key: Key, host: string | null): boolean {
  if (!key.origins.length || host === null) return true; // no restriction, or a mobile app / server
  if (host === "localhost" || host === "127.0.0.1") return true; // local development
  return key.origins.some((o) => (o.startsWith("*.") ? host === o.slice(2) || host.endsWith(o.slice(1)) : host === o));
}

/** Validates a key for a request; returns an error response, or the key (null when no key). */
function checkKey(token: string | null, headers: Headers, kind: Kind): Response | Key | null {
  if (!token) return null;
  const key = keysByToken.get(token);
  if (!key) return fail(401, "Unknown Mapeleven key. Create one at " + BASE + "/account/");
  if (key.revoked) return fail(401, "This Mapeleven key was deleted. Create a new one at " + BASE + "/account/");
  if (!originAllowed(key, requestHost(headers)))
    return fail(403, `This key is not allowed on ${requestHost(headers)}. Add the domain to the key at ${BASE}/account/`);
  if (overLimit(key.userId, kind))
    return fail(
      429,
      `The free monthly limit for this account is reached (${LIMITS[kind].toLocaleString("en")} ${kind === "map" ? "map loads" : "searches"}). It resets on the 1st; write to hello@${DOMAIN} for more.`,
    );
  return key;
}

// ---------- Styles ----------

const styleCache = new Map<string, { mtime: number; style: any; raw: string }>();
function loadStyle(name: string) {
  const path = `${STYLES_DIR}/${name}`;
  const mtime = statSync(path).mtimeMs;
  const hit = styleCache.get(name);
  if (hit && hit.mtime === mtime) return hit;
  const raw = readFileSync(path, "utf8");
  const entry = { mtime, style: JSON.parse(raw), raw };
  styleCache.set(name, entry);
  return entry;
}

const tileJsonCache = new Map<string, { at: number; tj: any }>();
async function tileJson(url: string): Promise<any> {
  const hit = tileJsonCache.get(url);
  if (hit && Date.now() - hit.at < 10 * 60_000) return hit.tj;
  const internal = url.replace(`${BASE}/tiles`, TILES_URL);
  const res = await fetch(internal);
  if (!res.ok) throw new Error(`TileJSON ${internal}: HTTP ${res.status}`);
  const tj = await res.json();
  tileJsonCache.set(url, { at: Date.now(), tj });
  return tj;
}

async function serveStyle(req: Request, url: URL): Promise<Response> {
  const name = url.pathname.slice("/styles/".length);
  if (!/^[a-z0-9-]+\.json$/.test(name)) return fail(404, "No such style");
  let entry;
  try {
    entry = loadStyle(name);
  } catch {
    return fail(404, "No such style");
  }
  const checked = checkKey(url.searchParams.get("key"), req.headers, "map");
  if (checked instanceof Response) return checked;
  if (!checked) {
    count(0, 0, "map");
    return new Response(entry.raw, {
      headers: { "content-type": "application/json", "cache-control": "public, max-age=3600" },
    });
  }
  count(checked.id, checked.userId, "map");
  // Inline each source's TileJSON with the key on the tile URLs, so tile requests carry it.
  const style = structuredClone(entry.style);
  const q = `key=${encodeURIComponent(checked.token)}`;
  for (const source of Object.values<any>(style.sources ?? {})) {
    if (typeof source.url !== "string" || !source.url.startsWith(`${BASE}/tiles/`)) continue;
    const tj = await tileJson(source.url);
    delete source.url;
    source.tiles = (tj.tiles as string[]).map((t) => t + (t.includes("?") ? "&" : "?") + q);
    for (const f of ["minzoom", "maxzoom", "bounds"]) if (tj[f] !== undefined) source[f] = tj[f];
  }
  return new Response(JSON.stringify(style), {
    headers: { "content-type": "application/json", "cache-control": "private, max-age=300" },
  });
}

// ---------- forward_auth from Caddy ----------

function check(req: Request): Response {
  const original = new URL(req.headers.get("x-forwarded-uri") ?? "/", BASE);
  if ((req.headers.get("x-forwarded-method") ?? "GET") === "OPTIONS") return new Response(null, { status: 204 });
  // Routing requests (/routing/*) count as searches.
  const kind: Kind = original.pathname.startsWith("/tiles/") ? "tile" : "search";
  const checked = checkKey(original.searchParams.get("key"), req.headers, kind);
  if (checked instanceof Response) return checked;
  if (checked) {
    count(checked.id, checked.userId, kind);
    return new Response(null, { status: 204 });
  }
  if (kind === "search") {
    const ip = (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim() || "unknown";
    if (!anonAllowed(ip))
      return fail(429, `Too many requests without a key. Get a free key at ${BASE}/account/`);
  }
  count(0, 0, kind);
  return new Response(null, { status: 204 });
}

// ---------- Sessions ----------

function sign(value: string): string {
  return createHmac("sha256", SESSION_SECRET).update(value).digest("base64url");
}
function sessionCookie(userId: number): string {
  const expires = Date.now() + SESSION_DAYS * 86_400_000;
  const value = `${userId}.${expires}`;
  return `ms=${value}.${sign(value)}; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=${SESSION_DAYS * 86_400}`;
}
function cookies(req: Request): Record<string, string> {
  return Object.fromEntries(
    (req.headers.get("cookie") ?? "")
      .split(";")
      .map((c) => c.trim().split("="))
      .filter((p) => p.length >= 2)
      .map(([k, ...v]) => [k, v.join("=")]),
  );
}
function currentUser(req: Request): number | null {
  if (!ACCOUNTS) return null;
  const raw = cookies(req).ms;
  if (!raw) return null;
  const [id, expires, sig] = raw.split(".");
  const expected = sign(`${id}.${expires}`);
  if (!sig || sig.length !== expected.length || !timingSafeEqual(Buffer.from(sig), Buffer.from(expected))) return null;
  if (Number(expires) < Date.now()) return null;
  return Number(id);
}

// ---------- GitHub sign-in ----------

function signIn(): Response {
  if (!ACCOUNTS || !GITHUB_CLIENT_ID) return fail(503, "Sign-in is not configured on this server");
  const state = randomBytes(16).toString("base64url");
  const authorize = new URL("https://github.com/login/oauth/authorize");
  authorize.searchParams.set("client_id", GITHUB_CLIENT_ID);
  authorize.searchParams.set("redirect_uri", `${BASE}/auth/github/callback`);
  authorize.searchParams.set("state", state);
  authorize.searchParams.set("allow_signup", "true");
  return new Response(null, {
    status: 302,
    headers: {
      location: authorize.toString(),
      "set-cookie": `oauth_state=${state}; Path=/auth; HttpOnly; Secure; SameSite=Lax; Max-Age=600`,
    },
  });
}

const insertKey = db.prepare("INSERT INTO keys (user_id, token, name) VALUES (?, ?, ?) RETURNING *");
const newToken = () => "mel_" + randomBytes(24).toString("base64url").replace(/[-_]/g, "x");

async function signInCallback(req: Request, url: URL): Promise<Response> {
  const state = url.searchParams.get("state");
  const code = url.searchParams.get("code");
  if (!code || !state || state !== cookies(req).oauth_state) return fail(400, "Sign-in expired. Try again.");
  const tokenRes = await fetch("https://github.com/login/oauth/access_token", {
    method: "POST",
    headers: { accept: "application/json", "content-type": "application/json" },
    body: JSON.stringify({
      client_id: GITHUB_CLIENT_ID,
      client_secret: GITHUB_CLIENT_SECRET,
      code,
      redirect_uri: `${BASE}/auth/github/callback`,
    }),
  });
  const { access_token } = (await tokenRes.json()) as { access_token?: string };
  if (!access_token) return fail(400, "GitHub did not confirm the sign-in. Try again.");
  const userRes = await fetch("https://api.github.com/user", {
    headers: { authorization: `Bearer ${access_token}`, accept: "application/vnd.github+json", "user-agent": "mapeleven" },
  });
  if (!userRes.ok) return fail(502, "Could not read the GitHub profile. Try again.");
  const gh = (await userRes.json()) as { id: number; login: string; name?: string; avatar_url?: string };
  const user = db
    .query(
      `INSERT INTO users (github_id, login, name, avatar) VALUES (?, ?, ?, ?)
       ON CONFLICT (github_id) DO UPDATE SET login = excluded.login, name = excluded.name, avatar = excluded.avatar
       RETURNING id`,
    )
    .get(gh.id, gh.login, gh.name ?? null, gh.avatar_url ?? null) as { id: number };
  const hasKey = db.query("SELECT 1 FROM keys WHERE user_id = ? LIMIT 1").get(user.id);
  if (!hasKey) {
    const k = rowToKey(insertKey.get(user.id, newToken(), "Default key"));
    keysByToken.set(k.token, k);
  }
  const headers = new Headers({ location: "/account/" });
  headers.append("set-cookie", sessionCookie(user.id));
  headers.append("set-cookie", "oauth_state=; Path=/auth; Max-Age=0");
  return new Response(null, { status: 302, headers });
}

// ---------- Account API ----------

const publicKey = (k: Key) => ({ id: k.id, name: k.name, token: k.token, origins: k.origins, createdAt: k.createdAt });
const userKeys = (userId: number) =>
  [...keysByToken.values()].filter((k) => k.userId === userId && !k.revoked).sort((a, b) => a.id - b.id);

function cleanOrigins(input: unknown): string[] | null {
  if (!Array.isArray(input)) return null;
  const out: string[] = [];
  for (const raw of input) {
    if (typeof raw !== "string") return null;
    let o = raw.trim().toLowerCase();
    if (!o) continue;
    o = o.replace(/^https?:\/\//, "").replace(/[/:].*$/, "");
    if (!/^(\*\.)?[a-z0-9.-]+$/.test(o)) return null;
    out.push(o);
  }
  return [...new Set(out)].slice(0, 20);
}

async function api(req: Request, url: URL): Promise<Response> {
  const userId = currentUser(req);
  if (!userId) return fail(401, "Sign in first");
  // Writes only from our own pages.
  if (req.method !== "GET" && req.headers.get("origin") !== BASE) return fail(403, "Bad origin");
  const path = url.pathname;

  if (path === "/api/me" && req.method === "GET") {
    const u = db.query("SELECT id, login, name, avatar, created_at FROM users WHERE id = ?").get(userId);
    return u ? json({ user: u, limits: LIMITS }) : fail(401, "Sign in first");
  }
  if (path === "/api/keys" && req.method === "GET") return json({ keys: userKeys(userId).map(publicKey) });
  if (path === "/api/keys" && req.method === "POST") {
    if (userKeys(userId).length >= MAX_KEYS) return fail(400, `At most ${MAX_KEYS} keys per account`);
    const body = (await req.json().catch(() => ({}))) as { name?: string; origins?: unknown };
    const name = (body.name ?? "").toString().trim().slice(0, 60) || "New key";
    const origins = cleanOrigins(body.origins ?? []);
    if (!origins) return fail(400, "Domains must look like example.com or *.example.com");
    const k = rowToKey(insertKey.get(userId, newToken(), name));
    if (origins.length) {
      db.query("UPDATE keys SET origins = ? WHERE id = ?").run(origins.join(","), k.id);
      k.origins = origins;
    }
    keysByToken.set(k.token, k);
    return json({ key: publicKey(k) }, 201);
  }
  const m = path.match(/^\/api\/keys\/(\d+)$/);
  if (m) {
    const key = userKeys(userId).find((k) => k.id === Number(m[1]));
    if (!key) return fail(404, "No such key");
    if (req.method === "PATCH") {
      const body = (await req.json().catch(() => ({}))) as { name?: string; origins?: unknown };
      if (body.name !== undefined) key.name = body.name.toString().trim().slice(0, 60) || key.name;
      if (body.origins !== undefined) {
        const origins = cleanOrigins(body.origins);
        if (!origins) return fail(400, "Domains must look like example.com or *.example.com");
        key.origins = origins;
      }
      db.query("UPDATE keys SET name = ?, origins = ? WHERE id = ?").run(key.name, key.origins.join(","), key.id);
      return json({ key: publicKey(key) });
    }
    if (req.method === "DELETE") {
      db.query("UPDATE keys SET revoked_at = datetime('now') WHERE id = ?").run(key.id);
      key.revoked = true;
      return json({ ok: true });
    }
  }
  if (path === "/api/usage" && req.method === "GET") {
    flush();
    const since = new Date(Date.now() - 29 * 86_400_000).toISOString().slice(0, 10);
    const daily = db
      .query(
        `SELECT u.day AS day, u.kind AS kind, SUM(u.count) AS count FROM usage u JOIN keys k ON k.id = u.key_id
         WHERE k.user_id = ? AND u.day >= ? GROUP BY u.day, u.kind ORDER BY u.day`,
      )
      .all(userId, since);
    const byKey = db
      .query(
        `SELECT u.key_id AS keyId, u.kind AS kind, SUM(u.count) AS count FROM usage u JOIN keys k ON k.id = u.key_id
         WHERE k.user_id = ? AND substr(u.day, 1, 7) = ? GROUP BY u.key_id, u.kind`,
      )
      .all(userId, thisMonth());
    const month = Object.fromEntries(
      (["map", "search", "tile"] as Kind[]).map((k) => [k, monthTotals.get(`${userId}|${thisMonth()}|${k}`) ?? 0]),
    );
    return json({ month, limits: LIMITS, daily, byKey });
  }
  return fail(404, "Not found");
}

// ---------- Server ----------

Bun.serve({
  port: PORT,
  hostname: "0.0.0.0",
  async fetch(req) {
    const url = new URL(req.url);
    try {
      if (url.pathname === "/check") return check(req);
      if (url.pathname === "/health") return json({ ok: true });
      if (url.pathname.startsWith("/styles/") && req.method === "GET") return await serveStyle(req, url);
      if (url.pathname === "/auth/github") return signIn();
      if (url.pathname === "/auth/github/callback") return await signInCallback(req, url);
      if (url.pathname === "/auth/logout" && req.method === "POST") {
        if (req.headers.get("origin") !== BASE) return fail(403, "Bad origin");
        return json({ ok: true }, 200, { "set-cookie": "ms=; Path=/; Max-Age=0; HttpOnly; Secure; SameSite=Lax" });
      }
      if (url.pathname.startsWith("/api/")) return await api(req, url);
      return fail(404, "Not found");
    } catch (e) {
      console.error(req.method, url.pathname, e);
      return fail(500, "Server error");
    }
  },
});
console.log(`mapeleven api on :${PORT} for ${BASE}`);
