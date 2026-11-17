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
      layers: layers("protomaps", namedFlavor(theme), { lang }),
    };
    writeFileSync(`${out}/${theme}-${lang}.json`, JSON.stringify(style));
  }
}
console.log(`Wrote ${THEMES.length * LANGUAGES.length} styles to ${out} for ${baseUrl}`);
