import "maplibre-gl/dist/maplibre-gl.css";

export { KharitaMap } from "./map";
export type { GeoJSONLayerHandle, GeoJSONLayerOptions, KharitaMapOptions, MarkerOptions } from "./map";
export { KharitaSearch } from "./search";
export type { KharitaPlace, SearchOptions } from "./search";
export { openFreeMap, providers, selfHosted } from "./provider";
export type { KharitaLanguage, KharitaProvider, KharitaTheme } from "./provider";
export { localizeStyle, nameExpression } from "./localize";
