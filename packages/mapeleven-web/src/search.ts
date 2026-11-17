import type { MapelevenLanguage, MapelevenProvider } from "./provider";

export interface MapelevenPlace {
  name: string;
  /** Where it is, without the name: street, district, city, country. */
  address: string;
  /** Name and address on one line. */
  label: string;
  lat: number;
  lng: number;
  /** OSM category, e.g. "city", "restaurant", "street". */
  type?: string;
  city?: string;
  country?: string;
  countryCode?: string;
  /** [minLng, minLat, maxLng, maxLat] when the place is an area. */
  bbox?: [number, number, number, number];
  osmId?: string;
}

export interface SearchOptions {
  language?: MapelevenLanguage;
  /** Bias results towards this point (e.g. the map centre). */
  near?: { lat: number; lng: number };
  /** Restrict to [minLng, minLat, maxLng, maxLat]. */
  bbox?: [number, number, number, number];
  limit?: number;
  signal?: AbortSignal;
}

/** Forward and reverse geocoding against a Photon server. */
export class MapelevenSearch {
  constructor(private readonly provider: MapelevenProvider) {}

  get available(): boolean {
    return Boolean(this.provider.searchUrl);
  }

  async search(query: string, options: SearchOptions = {}): Promise<MapelevenPlace[]> {
    const q = query.trim();
    if (!q) return [];
    const params = this.params(options);
    params.set("q", q);
    params.set("limit", String(options.limit ?? 8));
    if (options.near) {
      params.set("lat", String(options.near.lat));
      params.set("lon", String(options.near.lng));
    }
    if (options.bbox) params.set("bbox", options.bbox.join(","));
    return this.fetchPlaces("api", params, options);
  }

  async reverse(lat: number, lng: number, options: Omit<SearchOptions, "near" | "bbox"> = {}): Promise<MapelevenPlace | null> {
    const params = this.params(options);
    params.set("lat", String(lat));
    params.set("lon", String(lng));
    params.set("limit", "1");
    const places = await this.fetchPlaces("reverse", params, options);
    return places[0] ?? null;
  }

  private params(options: SearchOptions): URLSearchParams {
    const params = new URLSearchParams();
    const lang = options.language;
    // Photon only accepts languages present in its index; "default" returns local names.
    params.set("lang", lang && this.provider.searchLanguages.includes(lang) ? lang : "default");
    return params;
  }

  private async fetchPlaces(path: string, params: URLSearchParams, options: SearchOptions): Promise<MapelevenPlace[]> {
    if (!this.provider.searchUrl) throw new Error(`Provider "${this.provider.id}" has no search service`);
    const res = await fetch(`${this.provider.searchUrl}/${path}?${params}`, { signal: options.signal });
    if (!res.ok) throw new Error(`Search failed: HTTP ${res.status}`);
    const body = (await res.json()) as PhotonResponse;
    const separator = options.language === "ar" ? "، " : ", ";
    return body.features.map((f) => toPlace(f, separator));
  }
}

interface PhotonResponse {
  features: {
    geometry: { coordinates: [number, number] };
    properties: Record<string, string | number[] | undefined>;
  }[];
}

function toPlace(f: PhotonResponse["features"][number], separator: string): MapelevenPlace {
  const p = f.properties as Record<string, string | undefined>;
  const [lng, lat] = f.geometry.coordinates;
  const street = p.street ? [p.street, p.housenumber].filter(Boolean).join(" ") : undefined;
  const name = p.name ?? street ?? p.city ?? p.country ?? "";
  const address = [street !== name ? street : undefined, p.district, p.city !== name ? p.city : undefined, p.country !== name ? p.country : undefined]
    .filter(Boolean)
    .join(separator);
  const label = address ? `${name}${separator}${address}` : name;
  const extent = f.properties.extent as number[] | undefined;
  return {
    name,
    address,
    label,
    lat,
    lng,
    type: p.osm_value ?? p.type,
    city: p.city,
    country: p.country,
    countryCode: p.countrycode,
    // Photon extent is [minLon, maxLat, maxLon, minLat].
    bbox: extent ? [extent[0], extent[3], extent[2], extent[1]] : undefined,
    osmId: p.osm_type && p.osm_id ? `${p.osm_type}${p.osm_id}` : undefined,
  };
}
