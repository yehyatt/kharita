import * as maplibregl from "maplibre-gl";
import type {
  GeoJSONSource,
  LngLatLike,
  MapGeoJSONFeature,
  MapOptions,
  StyleSpecification,
} from "maplibre-gl";
import { localizeStyle } from "./localize";
import { openFreeMap, type MapelevenLanguage, type MapelevenProvider, type MapelevenTheme } from "./provider";
import { ensureRtlPlugin } from "./rtl";
import { MapelevenSearch } from "./search";

export interface MapelevenMapOptions {
  /** Defaults to OpenFreeMap (development use). */
  provider?: MapelevenProvider;
  /** Label language. Defaults to the page language (`<html lang>`, else the browser): Arabic for Arabic, English otherwise. */
  language?: MapelevenLanguage;
  theme?: MapelevenTheme;
  /** [lng, lat]. Defaults to Amman. */
  center?: [number, number];
  zoom?: number;
  controls?: { navigation?: boolean; locate?: boolean; scale?: boolean; fullscreen?: boolean };
  /**
   * URL of `maplibre-gl/dist/maplibre-gl-worker.mjs` as served by your app. MapLibre 6 finds its
   * worker next to `maplibre-gl.mjs`; bundlers that rename or inline that file need this.
   * Vite: `import workerUrl from "maplibre-gl/dist/maplibre-gl-worker.mjs?url"`.
   */
  workerUrl?: string;
  /** Escape hatch: extra MapLibre options (container, style and attribution are managed by Mapeleven). */
  maplibre?: Omit<Partial<MapOptions>, "container" | "style" | "attributionControl">;
}

export interface MarkerOptions {
  color?: string;
  /** Plain text shown in a popup on click. */
  popup?: string;
  draggable?: boolean;
}

export interface GeoJSONLayerOptions {
  /** Group nearby points into numbered bubbles. */
  cluster?: boolean;
  color?: string;
  /** Point radius in pixels. */
  radius?: number;
  /** Called with the clicked (non-cluster) feature. */
  onClick?: (feature: MapGeoJSONFeature) => void;
}

export interface GeoJSONLayerHandle {
  readonly id: string;
  setData(data: GeoJSON.GeoJSON): void;
  remove(): void;
}

const PREFIX = "mapeleven-";
const DEFAULT_COLOR = "#0066FF";

/** A map with sensible defaults: labels in the page language (Arabic or English), attribution, RTL shaping, theme and language switching. */
export class MapelevenMap {
  /** The underlying MapLibre map, for anything Mapeleven does not wrap. */
  readonly map: maplibregl.Map;
  readonly search: MapelevenSearch;
  readonly provider: MapelevenProvider;
  /** Resolves when the first style has loaded. */
  readonly ready: Promise<void>;

  private _language: MapelevenLanguage;
  private _theme: MapelevenTheme;
  private geolocate?: maplibregl.GeolocateControl;
  private styleRequest = 0;
  private styleReady = false;

  constructor(container: HTMLElement | string, options: MapelevenMapOptions = {}) {
    this.provider = options.provider ?? openFreeMap();
    this._language = options.language ?? pageLanguage();
    this._theme = options.theme ?? "light";
    if (options.workerUrl) maplibregl.setWorkerUrl(options.workerUrl);
    ensureRtlPlugin(this.provider.rtlPluginUrl);

    this.map = new maplibregl.Map({
      ...options.maplibre,
      container,
      center: options.center ?? [35.9106, 31.9539],
      zoom: options.zoom ?? 11,
      style: { version: 8, sources: {}, layers: [] },
      // OSM's licence (ODbL) requires visible attribution; Mapeleven keeps it on.
      attributionControl: { compact: true },
    });
    this.search = new MapelevenSearch(this.provider);

    const c = { navigation: true, locate: true, scale: false, fullscreen: false, ...options.controls };
    const side = this._language === "ar" ? "top-left" : "top-right";
    if (c.navigation) this.map.addControl(new maplibregl.NavigationControl(), side);
    if (c.locate) {
      this.geolocate = new maplibregl.GeolocateControl({
        positionOptions: { enableHighAccuracy: true },
        trackUserLocation: true,
      });
      this.map.addControl(this.geolocate, side);
    }
    if (c.fullscreen) this.map.addControl(new maplibregl.FullscreenControl(), side);
    if (c.scale) this.map.addControl(new maplibregl.ScaleControl(), "bottom-left");

    this.ready = this.applyStyle().then(() => {
      this.styleReady = true;
    });
  }

  get language(): MapelevenLanguage {
    return this._language;
  }

  get theme(): MapelevenTheme {
    return this._theme;
  }

  /** Switch label language. Your markers and GeoJSON layers are kept. */
  setLanguage(language: MapelevenLanguage): Promise<void> {
    this._language = language;
    return this.applyStyle();
  }

  /** Switch visual theme. Your markers and GeoJSON layers are kept. */
  setTheme(theme: MapelevenTheme): Promise<void> {
    this._theme = theme;
    return this.applyStyle();
  }

  flyTo(center: LngLatLike, zoom?: number): void {
    this.map.flyTo({ center, zoom: zoom ?? Math.max(this.map.getZoom(), 14) });
  }

  fitBounds(bbox: [number, number, number, number], padding = 40): void {
    this.map.fitBounds(bbox, { padding, maxZoom: 16 });
  }

  /** Ask for the device location and follow it. Requires HTTPS (or localhost). */
  locate(): void {
    this.geolocate?.trigger();
  }

  addMarker(lngLat: LngLatLike, options: MarkerOptions = {}): maplibregl.Marker {
    const marker = new maplibregl.Marker({ color: options.color ?? DEFAULT_COLOR, draggable: options.draggable });
    marker.setLngLat(lngLat);
    if (options.popup) marker.setPopup(new maplibregl.Popup({ offset: 24 }).setText(options.popup));
    return marker.addTo(this.map);
  }

  /** Draw points, lines and polygons from GeoJSON, optionally clustered. */
  addGeoJSON(name: string, data: GeoJSON.GeoJSON | string, options: GeoJSONLayerOptions = {}): GeoJSONLayerHandle {
    const id = PREFIX + name;
    const color = options.color ?? DEFAULT_COLOR;
    const add = () => {
      this.map.addSource(id, {
        type: "geojson",
        data,
        cluster: options.cluster ?? false,
        clusterRadius: 50,
        clusterMaxZoom: 14,
      });
      const notCluster: maplibregl.FilterSpecification = ["!", ["has", "point_count"]];
      this.map.addLayer({
        id: `${id}-fill`, type: "fill", source: id,
        filter: ["==", ["geometry-type"], "Polygon"],
        paint: { "fill-color": color, "fill-opacity": 0.2 },
      });
      this.map.addLayer({
        id: `${id}-line`, type: "line", source: id,
        filter: ["in", ["geometry-type"], ["literal", ["LineString", "Polygon"]]],
        paint: { "line-color": color, "line-width": 2 },
      });
      this.map.addLayer({
        id: `${id}-point`, type: "circle", source: id,
        filter: ["all", ["==", ["geometry-type"], "Point"], notCluster],
        paint: {
          "circle-color": color, "circle-radius": options.radius ?? 6,
          "circle-stroke-color": "#ffffff", "circle-stroke-width": 2,
        },
      });
      if (options.cluster) {
        this.map.addLayer({
          id: `${id}-cluster`, type: "circle", source: id,
          filter: ["has", "point_count"],
          paint: {
            "circle-color": color, "circle-opacity": 0.85,
            "circle-radius": ["step", ["get", "point_count"], 16, 10, 20, 50, 26],
            "circle-stroke-color": "#ffffff", "circle-stroke-width": 2,
          },
        });
        this.map.addLayer({
          id: `${id}-count`, type: "symbol", source: id,
          filter: ["has", "point_count"],
          layout: { "text-field": ["get", "point_count_abbreviated"], "text-font": this.provider.fontStack, "text-size": 12 },
          paint: { "text-color": "#ffffff" },
        });
      }
    };
    if (this.styleReady) add();
    else void this.ready.then(add);

    const onClusterClick = async (e: maplibregl.MapLayerMouseEvent) => {
      const f = e.features?.[0];
      if (!f) return;
      const zoom = await (this.map.getSource(id) as GeoJSONSource).getClusterExpansionZoom(f.properties.cluster_id);
      this.map.easeTo({ center: (f.geometry as GeoJSON.Point).coordinates as [number, number], zoom });
    };
    const onPointClick = (e: maplibregl.MapLayerMouseEvent) => {
      const f = e.features?.[0];
      if (f && options.onClick) options.onClick(f);
    };
    const pointer = () => (this.map.getCanvas().style.cursor = "pointer");
    const unpointer = () => (this.map.getCanvas().style.cursor = "");
    const clickable = [`${id}-point`, `${id}-fill`];
    this.map.on("click", `${id}-cluster`, onClusterClick);
    this.map.on("click", clickable, onPointClick);
    for (const layer of [...clickable, `${id}-cluster`]) {
      this.map.on("mouseenter", layer, pointer);
      this.map.on("mouseleave", layer, unpointer);
    }

    return {
      id,
      setData: (next) => (this.map.getSource(id) as GeoJSONSource | undefined)?.setData(next),
      remove: () => {
        this.map.off("click", `${id}-cluster`, onClusterClick);
        this.map.off("click", clickable, onPointClick);
        for (const layer of [...clickable, `${id}-cluster`]) {
          this.map.off("mouseenter", layer, pointer);
          this.map.off("mouseleave", layer, unpointer);
        }
        for (const suffix of ["count", "cluster", "point", "line", "fill"]) {
          if (this.map.getLayer(`${id}-${suffix}`)) this.map.removeLayer(`${id}-${suffix}`);
        }
        if (this.map.getSource(id)) this.map.removeSource(id);
      },
    };
  }

  destroy(): void {
    this.map.remove();
  }

  private async applyStyle(): Promise<void> {
    const request = ++this.styleRequest;
    const url = this.provider.styleUrl(this._theme, this._language);
    let style: StyleSpecification | string = url;
    if (this.provider.localizeOnClient) {
      const res = await fetch(url);
      if (!res.ok) throw new Error(`Style failed to load: HTTP ${res.status} ${url}`);
      style = localizeStyle((await res.json()) as StyleSpecification, this._language);
    }
    if (request !== this.styleRequest) return; // a newer theme/language call won
    const loaded = new Promise<void>((resolve) => this.map.once("style.load", () => resolve()));
    this.map.setStyle(style, {
      diff: false,
      // Carry Mapeleven-owned sources and layers (markers are DOM elements and survive anyway).
      transformStyle: (previous: StyleSpecification | undefined, next: StyleSpecification): StyleSpecification => ({
            ...next,
            sources: {
              ...next.sources,
              ...Object.fromEntries(Object.entries(previous?.sources ?? {}).filter(([k]) => k.startsWith(PREFIX))),
            },
            layers: [...next.layers, ...(previous?.layers ?? []).filter((l: { id: string }) => l.id.startsWith(PREFIX))],
          }),
    });
    await loaded;
  }
}

/** Arabic when the page (`<html lang>`) or, failing that, the browser is Arabic; English otherwise. */
export function pageLanguage(): MapelevenLanguage {
  const lang = (typeof document !== "undefined" && document.documentElement.lang) || (typeof navigator !== "undefined" ? navigator.language : "");
  return lang.toLowerCase().startsWith("ar") ? "ar" : "en";
}
