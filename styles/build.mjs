// Generates MapLibre style JSONs (theme x language) for a Mapeleven server.
// Usage: node build.mjs --base-url=https://maps.example.com --tiles=mena --out=dist
import { layers, namedFlavor } from "@protomaps/basemaps";
import { mkdirSync, writeFileSync } from "node:fs";

const arg = (name, fallback) =>
  process.argv.find((a) => a.startsWith(`--${name}=`))?.split("=").slice(1).join("=") ?? fallback;

const baseUrl = arg("base-url", "http://localhost:8080").replace(/\/$/, "");
const tiles = arg("tiles", "mena");
const out = arg("out", "dist");

export const THEMES = ["light", "dark", "white", "grayscale", "black"];
export const LANGUAGES = ["ar", "en"];

const ATTRIBUTION =
  '<a href="https://protomaps.com">Protomaps</a> © <a href="https://openstreetmap.org/copyright">OpenStreetMap</a>';

// Kinds the default Protomaps style leaves out but people in the region look
// for. The sprite has no icon for them, so they use the generic dot.
export const EXTRA_POI_KINDS = [
  "hospital", "clinic", "doctors", "dentist", "pharmacy", "chemist",
  "place_of_worship", "fuel", "bank", "atm", "bureau_de_change", "money_transfer",
  "hotel", "guest_house", "bakery", "pastry", "mall", "department_store",
  "police", "fire_station", "courthouse", "cinema", "fitness_centre", "sports_centre",
  "kindergarten", "college", "mobile_phone", "car_wash", "car_rental", "parking",
  "bus_station", "community_centre", "playground", "greengrocer", "butcher", "ice_cream",
];

function widenPois(layerList) {
  for (const layer of layerList) {
    if (layer.id !== "pois") continue;
    const kinds = layer.filter?.[1]?.[2]?.[1];
    if (!Array.isArray(kinds)) throw new Error("pois filter changed upstream; update widenPois()");
    for (const k of EXTRA_POI_KINDS) if (!kinds.includes(k)) kinds.push(k);
    const fallback = EXTRA_POI_KINDS.flatMap((k) => [k, "townspot"]);
    layer.layout["icon-image"] = ["match", ["get", "kind"], "station", "train_station", ...fallback, ["get", "kind"]];
  }
  return layerList;
}

mkdirSync(out, { recursive: true });
for (const theme of THEMES) {
  for (const lang of LANGUAGES) {
    const style = {
      version: 8,
      name: `mapeleven-${theme}-${lang}`,
      glyphs: `${baseUrl}/assets/fonts/{fontstack}/{range}.pbf`,
      sprite: `${baseUrl}/assets/sprites/v4/${theme}`,
      sources: {
        protomaps: { type: "vector", url: `${baseUrl}/tiles/${tiles}.json`, attribution: ATTRIBUTION },
      },
      layers: widenPois(layers("protomaps", namedFlavor(theme), { lang })),
    };
    writeFileSync(`${out}/${theme}-${lang}.json`, JSON.stringify(style));
  }
}
console.log(`Wrote ${THEMES.length * LANGUAGES.length} styles to ${out} for ${baseUrl}`);
