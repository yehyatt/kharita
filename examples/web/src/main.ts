import { KharitaMap, selfHosted, openFreeMap, type KharitaPlace } from "kharita";
import workerUrl from "maplibre-gl/dist/maplibre-gl-worker.mjs?url";
import "./style.css";

// VITE_KHARITA_SERVER=https://maps.example.com uses your own server; otherwise OpenFreeMap.
const server = import.meta.env.VITE_KHARITA_SERVER as string | undefined;
const kharita = new KharitaMap("map", {
  provider: server ? selfHosted(server) : openFreeMap(),
  language: "ar",
  theme: "light",
  controls: { scale: true },
  workerUrl,
});

// Synthetic sample data: 60 points scattered around Amman, clustered.
const rand = (seed: number) => () => ((seed = (seed * 16807) % 2147483647) / 2147483647);
const r = rand(42);
const points: GeoJSON.FeatureCollection = {
  type: "FeatureCollection",
  features: Array.from({ length: 60 }, (_, i) => ({
    type: "Feature",
    properties: { name: `Sample site ${i + 1}` },
    geometry: { type: "Point", coordinates: [35.85 + r() * 0.15, 31.9 + r() * 0.1] },
  })),
};
kharita.addGeoJSON("sites", points, {
  cluster: true,
  color: "#00D4AA",
  onClick: (f) => alert(String(f.properties.name)),
});
kharita.addMarker([35.9106, 31.9539], { popup: "عمّان" });

// Language and theme toggles.
const t = {
  ar: { other: "English", dark: "داكن", light: "فاتح", placeholder: "ابحث عن مكان", dir: "rtl" },
  en: { other: "العربية", dark: "Dark", light: "Light", placeholder: "Search for a place", dir: "ltr" },
} as const;
const langBtn = document.querySelector<HTMLButtonElement>("#lang")!;
const themeBtn = document.querySelector<HTMLButtonElement>("#theme")!;
const input = document.querySelector<HTMLInputElement>("#q")!;
const list = document.querySelector<HTMLUListElement>("#results")!;
const refreshLabels = () => {
  const s = t[kharita.language];
  langBtn.textContent = s.other;
  themeBtn.textContent = kharita.theme === "dark" ? s.light : s.dark;
  input.placeholder = s.placeholder;
  document.documentElement.lang = kharita.language;
  document.documentElement.dir = s.dir;
};
langBtn.onclick = async () => {
  await kharita.setLanguage(kharita.language === "ar" ? "en" : "ar");
  refreshLabels();
};
themeBtn.onclick = async () => {
  await kharita.setTheme(kharita.theme === "dark" ? "light" : "dark");
  refreshLabels();
};

// Search-as-you-type, biased to the map centre.
let pending: AbortController | undefined;
let timer: number | undefined;
const show = (places: KharitaPlace[]) => {
  list.replaceChildren(
    ...places.map((p) => {
      const li = document.createElement("li");
      li.innerHTML = `<span></span><small></small>`;
      li.querySelector("span")!.textContent = p.name;
      li.querySelector("small")!.textContent = p.address;
      li.onclick = () => {
        list.hidden = true;
        input.value = p.name;
        if (p.bbox) kharita.fitBounds(p.bbox);
        else kharita.flyTo([p.lng, p.lat], 16);
      };
      return li;
    }),
  );
  list.hidden = places.length === 0;
};
input.addEventListener("input", () => {
  clearTimeout(timer);
  timer = window.setTimeout(async () => {
    pending?.abort();
    pending = new AbortController();
    const c = kharita.map.getCenter();
    try {
      show(await kharita.search.search(input.value, {
        language: kharita.language, near: { lat: c.lat, lng: c.lng }, signal: pending.signal,
      }));
    } catch (e) {
      if ((e as Error).name !== "AbortError") console.error(e);
    }
  }, 250);
});
document.querySelector("form")!.onsubmit = (e) => e.preventDefault();

// Long-press / right-click: what is here?
kharita.map.on("contextmenu", async (e) => {
  const place = await kharita.search.reverse(e.lngLat.lat, e.lngLat.lng, { language: kharita.language });
  if (place) kharita.addMarker(e.lngLat, { color: "#1E293B", popup: place.label }).togglePopup();
});

refreshLabels();
(window as unknown as { kharita: KharitaMap }).kharita = kharita;
