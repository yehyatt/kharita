// Account dashboard: keys and usage, talking to the api service (/api/*).
const $ = (id) => document.getElementById(id);
const nf = new Intl.NumberFormat("en");

async function call(method, path, body) {
  const res = await fetch(path, {
    method,
    headers: body ? { "content-type": "application/json" } : {},
    body: body ? JSON.stringify(body) : undefined,
    credentials: "same-origin",
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw Object.assign(new Error(data.error ?? `HTTP ${res.status}`), { status: res.status });
  return data;
}

function showError(message) {
  const el = $("error");
  el.textContent = message;
  el.hidden = !message;
  if (message) setTimeout(() => (el.hidden = true), 6000);
}

const LABELS = { map: "Map loads", search: "Searches", tile: "Tile requests" };

function renderMeters(usage) {
  $("meters").replaceChildren(
    ...["map", "search", "tile"].map((kind) => {
      const used = usage.month[kind] ?? 0;
      const limit = usage.limits[kind];
      const div = document.createElement("div");
      div.className = "meter";
      const pct = limit ? Math.min(100, (used / limit) * 100) : 0;
      div.innerHTML = `
        <p class="fine">${LABELS[kind]}</p>
        <p class="meter-num"><strong>${nf.format(used)}</strong>${limit ? ` <span>of ${nf.format(limit)}</span>` : ` <span>not limited</span>`}</p>
        ${limit ? `<div class="bar"><span style="width:${pct.toFixed(1)}%"${pct >= 90 ? ' class="hot"' : ""}></span></div>` : ""}`;
      return div;
    }),
  );
}

function renderChart(usage) {
  const days = [];
  for (let i = 29; i >= 0; i--) days.push(new Date(Date.now() - i * 86_400_000).toISOString().slice(0, 10));
  const by = {};
  for (const r of usage.daily) (by[r.day] ??= {})[r.kind] = r.count;
  const max = Math.max(1, ...days.flatMap((d) => [by[d]?.map ?? 0, by[d]?.search ?? 0]));
  $("chart").replaceChildren(
    ...days.map((d) => {
      const col = document.createElement("div");
      col.className = "col";
      const m = by[d]?.map ?? 0;
      const s = by[d]?.search ?? 0;
      col.title = `${d}: ${nf.format(m)} map loads, ${nf.format(s)} searches`;
      col.innerHTML = `<span class="map" style="height:${(m / max) * 100}%"></span><span class="search" style="height:${(s / max) * 100}%"></span>`;
      return col;
    }),
  );
}

function renderKeys(keys, usage) {
  const tpl = $("key-row");
  const perKey = {};
  for (const r of usage?.byKey ?? []) (perKey[r.keyId] ??= {})[r.kind] = r.count;
  $("keys").replaceChildren(
    ...keys.map((key) => {
      const row = tpl.content.firstElementChild.cloneNode(true);
      const name = row.querySelector(".key-name");
      const origins = row.querySelector(".key-origins");
      name.value = key.name;
      origins.value = key.origins.join(", ");
      row.querySelector(".key-token").textContent = key.token;
      const u = perKey[key.id] ?? {};
      row.querySelector(".key-meta").textContent =
        `Created ${key.createdAt.slice(0, 10)} · this month ${nf.format(u.map ?? 0)} map loads, ${nf.format(u.search ?? 0)} searches`;
      row.querySelector(".key-copy").addEventListener("click", async (e) => {
        await navigator.clipboard.writeText(key.token);
        e.target.textContent = "Copied";
        setTimeout(() => (e.target.textContent = "Copy"), 1500);
      });
      const save = async (patch) => {
        try {
          await call("PATCH", `/api/keys/${key.id}`, patch);
        } catch (err) {
          showError(err.message);
        }
      };
      name.addEventListener("change", () => save({ name: name.value }));
      origins.addEventListener("change", () => save({ origins: origins.value.split(",") }));
      row.querySelector(".key-delete").addEventListener("click", async () => {
        if (!confirm(`Delete "${key.name}"? Apps using it stop loading maps.`)) return;
        try {
          await call("DELETE", `/api/keys/${key.id}`);
          await load();
        } catch (err) {
          showError(err.message);
        }
      });
      return row;
    }),
  );
  const token = keys[0]?.token ?? "YOUR_KEY";
  $("snippet-flutter").textContent = `MapelevenMap(
  provider: MapelevenProvider.hosted(key: '${token}'),
  initialCenter: const LatLng(31.9539, 35.9106),
  initialZoom: 13,
)`;
  $("snippet-web").textContent = `import { MapelevenMap, hosted } from "mapeleven";

const map = new MapelevenMap("map", {
  provider: hosted({ key: "${token}" }),
  center: [35.9106, 31.9539],
  zoom: 13,
});`;
}

function renderAllowance(limits) {
  $("allowance").innerHTML = `
    <li><strong>${nf.format(limits.map)}</strong> map loads a month</li>
    <li><strong>${nf.format(limits.search)}</strong> searches a month</li>
    <li><strong>Unlimited</strong> tiles for those map loads</li>`;
}

async function load() {
  let me;
  try {
    me = await call("GET", "/api/me");
  } catch (err) {
    $("signed-out").hidden = false;
    $("signed-in").hidden = true;
    renderAllowance({ map: 50000, search: 50000 });
    if (err.status !== 401) showError(err.message);
    return;
  }
  $("signed-out").hidden = true;
  $("signed-in").hidden = false;
  $("avatar").src = me.user.avatar ?? "/static/favicon.svg";
  $("who-name").textContent = me.user.name || me.user.login;
  $("who-login").textContent = `@${me.user.login} on GitHub`;
  const [{ keys }, usage] = await Promise.all([call("GET", "/api/keys"), call("GET", "/api/usage")]);
  renderMeters(usage);
  renderChart(usage);
  renderKeys(keys, usage);
}

$("new-key").addEventListener("click", async () => {
  const name = prompt("Name for the new key (for example the app or website it is for):", "New key");
  if (name === null) return;
  try {
    await call("POST", "/api/keys", { name });
    await load();
  } catch (err) {
    showError(err.message);
  }
});

$("sign-out").addEventListener("click", async () => {
  await call("POST", "/auth/logout").catch(() => {});
  location.reload();
});

for (const tab of document.querySelectorAll("[data-tab]")) {
  tab.addEventListener("click", () => {
    for (const t of document.querySelectorAll("[data-tab]")) t.setAttribute("aria-selected", String(t === tab));
    for (const p of document.querySelectorAll("[data-panel]")) p.hidden = p.dataset.panel !== tab.dataset.tab;
  });
}

load();
