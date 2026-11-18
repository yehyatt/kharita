import type { LayerSpecification, RasterSourceSpecification, StyleSpecification } from "maplibre-gl";

/**
 * Satellite or aerial imagery drawn under the map's roads and labels. Imagery comes straight from
 * the provider you pick, with your own key from that provider; Mapeleven does not proxy or pay for
 * it. Each provider's terms apply, and its attribution is added to the map for you.
 */
export interface MapelevenImagery {
  readonly source: RasterSourceSpecification;
}

/** Your own XYZ tiles (`{z}`, `{x}`, `{y}`) or a TileJSON URL. */
export function customImagery(options: {
  tiles?: string[];
  tileJsonUrl?: string;
  attribution: string;
  tileSize?: number;
  maxZoom?: number;
}): MapelevenImagery {
  return {
    source: {
      type: "raster",
      ...(options.tileJsonUrl ? { url: options.tileJsonUrl } : { tiles: options.tiles ?? [] }),
      tileSize: options.tileSize ?? 256,
      maxzoom: options.maxZoom ?? 19,
      attribution: options.attribution,
    },
  };
}

/**
 * Esri World Imagery. Needs an ArcGIS Location Platform API key with the basemap privilege
 * (developers.arcgis.com). Esri's free tier covers 2 million tiles a month at the time of writing.
 */
export function esriImagery(apiKey: string): MapelevenImagery {
  return customImagery({
    tiles: [
      `https://ibasemaps-api.arcgis.com/arcgis/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}?token=${encodeURIComponent(apiKey)}`,
    ],
    attribution: "Imagery: Esri, Maxar, Earthstar Geographics, and the GIS User Community",
    maxZoom: 19,
  });
}

/**
 * MapTiler Satellite. Needs a MapTiler Cloud key (maptiler.com). The free MapTiler plan is for
 * non-commercial use; live commercial apps need a paid plan.
 */
export function mapTilerImagery(apiKey: string): MapelevenImagery {
  return customImagery({
    tileJsonUrl: `https://api.maptiler.com/tiles/satellite-v4/tiles.json?key=${encodeURIComponent(apiKey)}`,
    attribution: '<a href="https://www.maptiler.com/copyright/">© MapTiler</a>',
    tileSize: 512,
    maxZoom: 20,
  });
}

export const IMAGERY_SOURCE = "imagery";

/**
 * Turns a vector style into a hybrid map: imagery at the bottom, then the style's roads, borders and
 * labels, recoloured to read over photos (white text on a dark halo, light semi-transparent roads).
 * Fills, casings, water and the background are dropped so the imagery shows through.
 */
export function hybridStyle(style: StyleSpecification, imagery: MapelevenImagery): StyleSpecification {
  const kept: LayerSpecification[] = [];
  for (const layer of style.layers) {
    const id = layer.id;
    if (layer.type === "symbol") {
      const text = layer.layout?.["text-field"] !== undefined && id !== "roads_shields";
      kept.push(text
        ? { ...layer, paint: { ...layer.paint, "text-color": "#ffffff", "text-halo-color": "rgba(0,0,0,0.8)", "text-halo-width": 1.4 } }
        : layer);
    } else if (layer.type === "line" && id.startsWith("boundaries")) {
      kept.push({ ...layer, paint: { ...layer.paint, "line-color": "#ffffff", "line-opacity": 0.7 } });
    } else if (layer.type === "line" && id.startsWith("roads_") && !/casing|runway|taxiway|pier|rail/.test(id)) {
      const major = id.includes("highway") || id.includes("major");
      kept.push({
        ...layer,
        paint: { ...layer.paint, "line-color": id.includes("highway") ? "#ffd166" : "#ffffff", "line-opacity": major ? 0.7 : 0.4 },
      });
    }
  }
  return {
    ...style,
    sources: { ...style.sources, [IMAGERY_SOURCE]: imagery.source },
    layers: [
      { id: "imagery-background", type: "background", paint: { "background-color": "#0b1a12" } },
      { id: IMAGERY_SOURCE, type: "raster", source: IMAGERY_SOURCE },
      ...kept,
    ],
  };
}
