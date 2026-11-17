export type MapelevenLanguage = "ar" | "en";
/** `light` and `dark` work on every provider; the rest only on a self-hosted Mapeleven server. */
export type MapelevenTheme = "light" | "dark" | "white" | "grayscale" | "black";

/**
 * Where map styles, tiles and search come from. Swap providers without touching map code:
 * start on OpenFreeMap during development, move to your own Mapeleven server for production.
 */
export interface MapelevenProvider {
  readonly id: string;
  /** Style URL for a theme and language. */
  styleUrl(theme: MapelevenTheme, language: MapelevenLanguage): string;
  /** True when the style is single-language and labels must be rewritten on the client. */
  readonly localizeOnClient: boolean;
  /** Photon-compatible search endpoint (no trailing slash), or undefined to disable search. */
  readonly searchUrl?: string;
  /** Languages the search index holds; others fall back to local names. */
  readonly searchLanguages: readonly string[];
  /** Font stack available on the provider's glyph server, used for SDK-drawn labels. */
  readonly fontStack: string[];
  /** Script that shapes Arabic and Hebrew text in MapLibre GL JS. */
  readonly rtlPluginUrl: string;
}

const PUBLIC_RTL_PLUGIN = "https://unpkg.com/@mapbox/mapbox-gl-rtl-text@0.3.0/dist/mapbox-gl-rtl-text.js";

/** Your own Mapeleven server (see server/README.md), e.g. `https://maps.example.com`. */
export function selfHosted(baseUrl: string): MapelevenProvider {
  const base = baseUrl.replace(/\/$/, "");
  return {
    id: "self-hosted",
    styleUrl: (theme, language) => `${base}/styles/${theme}-${language}.json`,
    localizeOnClient: false,
    searchUrl: `${base}/search`,
    searchLanguages: ["ar", "en"],
    fontStack: ["Noto Sans Regular"],
    rtlPluginUrl: `${base}/assets/rtl/mapbox-gl-rtl-text.js`,
  };
}

/**
 * OpenFreeMap public tiles (free, no key) and the public Photon demo for search.
 * Good for development and small apps. Both are community services under fair-use terms:
 * use `selfHosted` before real traffic.
 */
export function openFreeMap(options: { searchUrl?: string } = {}): MapelevenProvider {
  return {
    id: "openfreemap",
    styleUrl: (theme) =>
      `https://tiles.openfreemap.org/styles/${theme === "dark" || theme === "black" ? "dark" : theme === "light" ? "liberty" : "positron"}`,
    localizeOnClient: true,
    searchUrl: options.searchUrl ?? "https://photon.komoot.io",
    searchLanguages: ["en", "de", "fr"],
    fontStack: ["Noto Sans Regular"],
    rtlPluginUrl: PUBLIC_RTL_PLUGIN,
  };
}

export const providers = { selfHosted, openFreeMap };
