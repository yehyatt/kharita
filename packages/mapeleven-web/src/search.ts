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
  street?: string;
  houseNumber?: string;
  postcode?: string;
  /** Neighbourhood or district (حي / منطقة) when OSM has one. */
  district?: string;
  /** Locality inside a city, when OSM has one. */
  locality?: string;
  county?: string;
  /** Governorate, province or emirate. */
  state?: string;
  /** Admin names from most to least specific (district, locality, city, county, state), for zone matching. */
  adminAreas: string[];
  /** The raw Photon properties. */
  properties: Record<string, unknown>;
}

export interface SearchOptions {
  language?: MapelevenLanguage;
  /** Rank results near this point first (e.g. the map centre). */
  near?: { lat: number; lng: number };
  /** How local `near` is: 14 (default) is about a city, lower widens it. */
  nearZoom?: number;
  /** Category filter, e.g. ["amenity:pharmacy"] or ["shop"]. */
  osmTags?: string[];
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
      params.set("zoom", String(options.nearZoom ?? 14));
    }
    if (options.bbox) params.set("bbox", options.bbox.join(","));
    for (const tag of options.osmTags ?? []) params.append("osm_tag", tag);
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
    const separator = options.language === "en" ? ", " : "، ";
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
    street: p.street,
    houseNumber: p.housenumber,
    postcode: p.postcode,
    district: p.district,
    locality: p.locality,
    county: p.county,
    state: p.state,
    adminAreas: [...new Set([p.district, p.locality, p.city, p.county, p.state].filter((x): x is string => Boolean(x)))],
    properties: f.properties,
  };
}
