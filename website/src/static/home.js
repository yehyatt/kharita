// Live map on the home page: the web SDK against the hosted server.
import { MapelevenMap, hosted } from "/static/js/mapeleven.js";

const map = new MapelevenMap("map", {
  provider: hosted(location.hostname === "localhost" || location.hostname === "127.0.0.1" ? "https://mapeleven.dev" : location.origin),
  language: "ar",
  center: [35.9106, 31.9566],
  zoom: 13,
  controls: { navigation: false, locate: false },
  workerUrl: "/static/js/maplibre-gl-worker.mjs",
  maplibre: { cooperativeGestures: matchMedia("(pointer: coarse)").matches },
});

const lang = document.getElementById("lang");
const theme = document.getElementById("theme");
const q = document.getElementById("q");
const results = document.getElementById("results");
const themes = ["light", "dark", "grayscale"];
let marker;

lang.addEventListener("click", async () => {
  const next = map.language === "ar" ? "en" : "ar";
  lang.textContent = next === "ar" ? "EN" : "ع";
  q.placeholder = next === "ar" ? "ابحث عن صيدلية أو مدينة" : "Search a pharmacy or a city";
  await map.setLanguage(next);
});

theme.addEventListener("click", () => map.setTheme(themes[(themes.indexOf(map.theme) + 1) % themes.length]));

let timer;
let controller;
q.addEventListener("input", () => {
  clearTimeout(timer);
  timer = setTimeout(search, 250);
});

async function search() {
  controller?.abort();
  const text = q.value.trim();
  if (text.length < 2) {
    results.hidden = true;
    return;
  }
  controller = new AbortController();
  const c = map.map.getCenter();
  try {
    const places = await map.search.search(text, {
      language: map.language,
      near: { lat: c.lat, lng: c.lng },
      limit: 6,
      signal: controller.signal,
    });
    results.replaceChildren(
      ...places.map((p) => {
        const li = document.createElement("li");
        li.dir = "auto";
        li.innerHTML = `<strong></strong><span></span>`;
        li.querySelector("strong").textContent = p.name;
        li.querySelector("span").textContent = p.address;
        li.addEventListener("click", () => show(p));
        return li;
      }),
    );
    results.hidden = places.length === 0;
  } catch (e) {
    if (e.name !== "AbortError") results.hidden = true;
  }
}

function show(p) {
  results.hidden = true;
  q.value = p.name;
  marker?.remove();
  marker = map.addMarker([p.lng, p.lat], { color: "#0F766E", popup: p.label });
  if (p.bbox) map.fitBounds(p.bbox, 60);
  else map.flyTo([p.lng, p.lat], 16);
}

document.addEventListener("click", (e) => {
  if (!e.target.closest(".map-search")) results.hidden = true;
});

// Code tabs.
for (const tab of document.querySelectorAll("[data-tab]")) {
  tab.addEventListener("click", () => {
    for (const t of document.querySelectorAll("[data-tab]")) t.setAttribute("aria-selected", String(t === tab));
    for (const p of document.querySelectorAll("[data-panel]")) p.hidden = p.dataset.panel !== tab.dataset.tab;
  });
}
