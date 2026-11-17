import * as maplibregl from "maplibre-gl";

let requested = false;

/** Loads the RTL text plugin once per page so Arabic labels are shaped and ordered correctly. */
export function ensureRtlPlugin(url: string): void {
  if (requested || maplibregl.getRTLTextPluginStatus() !== "unavailable") return;
  requested = true;
  maplibregl.setRTLTextPlugin(url, true).catch((err: unknown) => {
    requested = false;
    console.warn("[mapeleven] RTL text plugin failed to load; Arabic labels may render incorrectly", err);
  });
}
