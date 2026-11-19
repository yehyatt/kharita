import type { MapelevenLanguage, MapelevenProvider } from "./provider";

/** How the route is travelled. */
export type MapelevenTravelMode = "car" | "walk" | "bike";

const COSTING: Record<MapelevenTravelMode, string> = { car: "auto", walk: "pedestrian", bike: "bicycle" };

export type MapelevenManeuver =
  | "start" | "arrive" | "continue" | "slightRight" | "right" | "sharpRight" | "uTurn" | "sharpLeft"
  | "left" | "slightLeft" | "rampRight" | "rampLeft" | "exitRight" | "exitLeft" | "keepRight"
  | "keepLeft" | "merge" | "roundabout" | "ferry" | "other";

/** One instruction of a route. */
export interface MapelevenStep {
  maneuver: MapelevenManeuver;
  /** Ready-to-show text in the requested language. */
  instruction: string;
  distanceMeters: number;
  durationSeconds: number;
  /** Where the maneuver happens, [lng, lat]. */
  position: [number, number];
  streetNames: string[];
  /** Which exit to take at a roundabout. */
  roundaboutExit?: number;
}

/** A route from `MapelevenRouter.route`. */
export interface MapelevenRoute {
  mode: MapelevenTravelMode;
  distanceMeters: number;
  /** Travel time from road types and speed limits, without live traffic. */
  durationSeconds: number;
  /** The route line, [lng, lat] pairs from start to end. */
  coordinates: [number, number][];
  steps: MapelevenStep[];
  /** [west, south, east, north] */
  bbox: [number, number, number, number];
}

export interface RouteOptions {
  mode?: MapelevenTravelMode;
  language?: MapelevenLanguage;
  /** Extra route choices to return when the road network has them (two stops only). */
  alternatives?: number;
}

export class MapelevenRoutingError extends Error {
  /** True when no road connects the stops. */
  readonly noRoute: boolean;
  constructor(message: string, noRoute: boolean) {
    super(message);
    this.noRoute = noRoute;
  }
}

/** Road routing with the provider's routing service (Valhalla). */
export class MapelevenRouter {
  constructor(readonly provider: MapelevenProvider) {}

  get available(): boolean {
    return this.provider.routingUrl !== undefined;
  }

  /** Routes through `stops` ([lng, lat], at least two) in order; the best route comes first. */
  async route(stops: [number, number][], options: RouteOptions = {}): Promise<MapelevenRoute[]> {
    if (stops.length < 2) throw new Error("A route needs at least two stops");
    const base = this.provider.routingUrl;
    if (!base) throw new Error(`Provider "${this.provider.id}" has no routing service`);
    const mode = options.mode ?? "car";
    const request = {
      locations: stops.map(([lon, lat]) => ({ lat, lon })),
      costing: COSTING[mode],
      units: "kilometers",
      language: "en-US",
      ...(options.alternatives && stops.length === 2 ? { alternates: options.alternatives } : {}),
    };
    const params = new URLSearchParams({ json: JSON.stringify(request) });
    if (this.provider.key) params.set("key", this.provider.key);
    const res = await fetch(`${base}/route?${params}`);
    const body = await res.json();
    if (!res.ok) {
      const reason = body.error ?? body.message;
      throw new MapelevenRoutingError(
        `Routing failed: HTTP ${res.status}${reason ? `: ${reason}` : ""}`,
        body.error_code === 442 || body.error_code === 171,
      );
    }
    const trips = [body.trip, ...(body.alternates ?? []).map((a: { trip: unknown }) => a.trip)];
    return trips.map((t) => toRoute(t, mode, options.language ?? "ar"));
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function toRoute(trip: any, mode: MapelevenTravelMode, language: MapelevenLanguage): MapelevenRoute {
  const coordinates: [number, number][] = [];
  const steps: MapelevenStep[] = [];
  for (const leg of trip.legs) {
    const shape = decodePolyline6(leg.shape);
    // Each leg starts where the previous one ended; keep that point once.
    const start = coordinates.length ? coordinates.length - 1 : 0;
    if (coordinates.length) shape.shift();
    coordinates.push(...shape);
    for (const m of leg.maneuvers) {
      const maneuver = MANEUVERS[m.type] ?? "other";
      const names: string[] = m.street_names ?? [];
      const exit: number | undefined = m.roundabout_exit_count;
      steps.push({
        maneuver,
        instruction: language === "en" ? m.instruction ?? "" : arabic(maneuver, names, exit, mode),
        distanceMeters: m.length * 1000,
        durationSeconds: m.time,
        position: coordinates[Math.min(start + m.begin_shape_index, coordinates.length - 1)],
        streetNames: names,
        roundaboutExit: exit,
      });
    }
  }
  const lngs = coordinates.map((c) => c[0]);
  const lats = coordinates.map((c) => c[1]);
  return {
    mode,
    distanceMeters: trip.summary.length * 1000,
    durationSeconds: Math.round(trip.summary.time),
    coordinates,
    steps,
    bbox: [Math.min(...lngs), Math.min(...lats), Math.max(...lngs), Math.max(...lats)],
  };
}

const MANEUVERS: Record<number, MapelevenManeuver> = {
  1: "start", 2: "start", 3: "start", 4: "arrive", 5: "arrive", 6: "arrive",
  7: "continue", 8: "continue", 17: "continue", 22: "continue",
  9: "slightRight", 10: "right", 11: "sharpRight", 12: "uTurn", 13: "uTurn", 14: "sharpLeft",
  15: "left", 16: "slightLeft", 18: "rampRight", 19: "rampLeft", 20: "exitRight", 21: "exitLeft",
  23: "keepRight", 24: "keepLeft", 25: "merge", 37: "merge", 38: "merge",
  26: "roundabout", 27: "roundabout", 28: "ferry", 29: "ferry",
};

const ORDINALS_AR = ["الأول", "الثاني", "الثالث", "الرابع", "الخامس", "السادس", "السابع", "الثامن"];

/** Arabic instruction text (Valhalla has no Arabic narrative). */
function arabic(m: MapelevenManeuver, names: string[], exit: number | undefined, mode: MapelevenTravelMode): string {
  const onto = names.length ? ` إلى ${names[0]}` : "";
  const along = names.length ? ` على ${names[0]}` : "";
  const go = mode === "walk" ? "امشِ" : "انطلق";
  switch (m) {
    case "start": return go + along;
    case "arrive": return "وصلت إلى وجهتك";
    case "continue": return "تابع مباشرة" + along;
    case "slightRight": return "انعطف قليلًا إلى اليمين" + onto;
    case "right": return "انعطف يمينًا" + onto;
    case "sharpRight": return "انعطف بحدة إلى اليمين" + onto;
    case "uTurn": return "استدر للخلف" + onto;
    case "sharpLeft": return "انعطف بحدة إلى اليسار" + onto;
    case "left": return "انعطف يسارًا" + onto;
    case "slightLeft": return "انعطف قليلًا إلى اليسار" + onto;
    case "rampRight": return "اسلك المنحدر على اليمين" + onto;
    case "rampLeft": return "اسلك المنحدر على اليسار" + onto;
    case "exitRight": return "اسلك المخرج على اليمين" + onto;
    case "exitLeft": return "اسلك المخرج على اليسار" + onto;
    case "keepRight": return "ابقَ على اليمين" + along;
    case "keepLeft": return "ابقَ على اليسار" + along;
    case "merge": return "اندمج في الطريق" + onto;
    case "roundabout":
      return exit && exit >= 1 && exit <= ORDINALS_AR.length
        ? `عند الدوار، اسلك المخرج ${ORDINALS_AR[exit - 1]}${onto}`
        : "ادخل الدوار" + onto;
    case "ferry": return "استقل العبّارة";
    default: return "تابع" + along;
  }
}

/** Decodes a Valhalla shape (Google polyline format, 6-digit precision) to [lng, lat] pairs. */
export function decodePolyline6(encoded: string): [number, number][] {
  const out: [number, number][] = [];
  let index = 0, lat = 0, lng = 0;
  while (index < encoded.length) {
    for (let i = 0; i < 2; i++) {
      let shift = 0, result = 0, b: number;
      do {
        b = encoded.charCodeAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      const delta = result & 1 ? ~(result >> 1) : result >> 1;
      if (i === 0) lat += delta;
      else lng += delta;
    }
    out.push([lng / 1e6, lat / 1e6]);
  }
  return out;
}
