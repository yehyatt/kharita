---
title: Coming from Google Maps
order: 4
---

# Coming from Google Maps

This guide moves a Flutter app (and the backend behind it) from Google Maps Platform to Mapeleven. Most apps finish in a day or two: the map widgets map one to one, and the backend geocoding change is one new provider class.

What you gain: no API keys in your builds, no per-request billing, Arabic and English place data you can host yourself, and location data that stays on servers you choose. What you give up today: road routing and ETAs (on the roadmap), live traffic, and Google's business listings (ratings, photos, opening hours).

## 1. Flutter: the map widget

| google_maps_flutter | Mapeleven |
|---|---|
| `GoogleMap(...)` | `MapelevenMap(provider: MapelevenProvider.hosted(), ...)` |
| `GoogleMapController` | `MapelevenController` (from `onMapReady`) |
| `initialCameraPosition: CameraPosition(target: t, zoom: z)` | `initialCenter: t, initialZoom: z` |
| `onMapCreated: (c) {}` | `onMapReady: (map) {}` (fires once the style has loaded) |
| `controller.animateCamera(CameraUpdate.newLatLng(t))` | `map.flyTo(t)` |
| `controller.moveCamera(CameraUpdate.newLatLng(t))` | `map.moveTo(t)` |
| `CameraUpdate.newLatLngBounds(bounds, padding)` | `map.fitBounds(bounds, padding: p)` or `map.fitPoints([a, b])` |
| `onCameraIdle` + `getVisibleRegion()` to find the centre | `onCameraIdle: (center, zoom) {}` |
| `markers: {Marker(markerId: ..., position: ...)}` | `map.addMarker(position, id: ...)`; call again with the same id to move it |
| `BitmapDescriptor.bytes(png)` | `map.registerIcon(MapelevenIcon('name', png))`, then `addMarker(..., icon: 'name')` |
| `BitmapDescriptor.defaultMarkerWithHue(...)` | `addMarker(..., color: Colors.green)` |
| `Marker(anchor: Offset(0.5, 0.5), flat: true)` | `anchor: MapelevenAnchor.center`, `rotation: degrees` |
| `polylines`, `polygons`, `circles` | `map.addGeoJson(name, geojson, options: ...)` |
| `myLocationEnabled: true` | `showUserLocation: true` |
| `compassEnabled: false` | `compassEnabled: false` |
| `zoomControlsEnabled`, `mapToolbarEnabled`, `myLocationButtonEnabled` | Not needed: Mapeleven shows none of these |
| `onTap`, `onLongPress` | `onTap`, `onLongPress`; plus `onPoiTap` for basemap places |

Both packages export a `LatLng` class with the same constructor. Remove the `google_maps_flutter` import from a file and the code that builds `LatLng(lat, lng)` keeps working.

### Example: centred-pin address picker

Before:

```dart
GoogleMap(
  initialCameraPosition: CameraPosition(target: LatLng(lat, lng), zoom: 16),
  onMapCreated: (c) => _controller = c,
  onCameraIdle: () {
    _controller?.getVisibleRegion().then((b) {
      final lat = (b.northeast.latitude + b.southwest.latitude) / 2;
      final lng = (b.northeast.longitude + b.southwest.longitude) / 2;
      widget.onCameraIdle(lat, lng);
    });
  },
  zoomControlsEnabled: false,
  myLocationButtonEnabled: false,
  mapToolbarEnabled: false,
  compassEnabled: false,
)
```

After:

```dart
MapelevenMap(
  provider: MapelevenProvider.hosted(),
  language: isArabic ? MapelevenLanguage.ar : MapelevenLanguage.en,
  initialCenter: LatLng(lat, lng),
  initialZoom: 16,
  compassEnabled: false,
  onMapReady: (map) => _map = map,
  onCameraIdle: (center, _) => widget.onCameraIdle(center.latitude, center.longitude),
)
```

`animateToLocation(lat, lng)` becomes `_map?.flyTo(LatLng(lat, lng))`. If you queued a target before the map existed, keep doing that and apply it in `onMapReady` with `moveTo`.

### Example: tracking map with a custom vehicle icon

If you already paint a vehicle icon into PNG bytes for `BitmapDescriptor.bytes`, register the same bytes:

```dart
onMapReady: (map) async {
  _map = map;
  await map.registerIcon(MapelevenIcon('driver', driverPngBytes, pixelRatio: 120 / 46));
  await map.addMarker(address, id: 'address', color: Colors.green);
  _syncDriver();
},

Future<void> _syncDriver() async {
  final d = widget.driver;
  if (_map == null || d == null) return;
  await _map!.addMarker(d, id: 'driver', icon: 'driver');
  await _map!.fitPoints([d, widget.address], padding: 72);
}
```

Call `_syncDriver()` from `didUpdateWidget` when the driver position changes, as you did with `animateCamera`. Or skip the painting code entirely: `MapelevenIcon.fromIconData('driver', Icons.local_shipping, background: brandGreen)` draws the same disc.

### Builds without an API key

Google Maps needs a key in every build, and many apps carry a flag to switch the map off when the key is missing. Mapeleven needs no key, so that flag can go, or stay as a kill switch.

### Platform settings

- iOS: Mapeleven needs iOS 15.5 or later. Remove the Google Maps API key from `AppDelegate` and `Info.plist`.
- Android: remove the `com.google.android.geo.API_KEY` meta-data from `AndroidManifest.xml`.
- Remove `google_maps_flutter` from `pubspec.yaml` once nothing imports it.

## 2. Backend: geocoding and place search

Many backends hide Google behind an interface like this one:

```ts
interface GeocodingProvider {
  reverseGeocode(lat: number, lng: number): Promise<{ street_name: string | null; formatted_address: string | null }>;
  resolveAdminAreas(lat: number, lng: number): Promise<AdminAreas>;     // for zone matching
  autocomplete(query: string, sessionToken?: string): Promise<Prediction[]>;
  placeDetails(placeId: string, sessionToken?: string): Promise<PlaceLocation>;
}
```

Add a Mapeleven implementation next to the Google one and choose it with configuration. The search API is [Photon](https://github.com/komoot/photon), served at `https://mapeleven.dev/search` (or your own server).

| Google endpoint | Mapeleven request |
|---|---|
| Geocoding `latlng=...&language=ar` | `GET /search/reverse?lat=..&lon=..&lang=ar` |
| Places Autocomplete `input=..&components=country:jo&location=..&radius=..` | `GET /search/api?q=..&lang=ar&lat=..&lon=..&zoom=14&bbox=34.9,29.1,39.4,33.4&limit=8` |
| Place Details `place_id=..` | Not needed: encode what you need into your own place id (below) |

Each result is a GeoJSON feature. The useful properties are `name`, `street`, `housenumber`, `postcode`, `district`, `locality`, `city`, `county`, `state`, `country`, `countrycode`, `osm_key`, `osm_value`, `osm_type`, `osm_id`; coordinates are `[lng, lat]`.

```ts
const BASE = process.env.MAPELEVEN_URL ?? "https://mapeleven.dev";
const JORDAN_BBOX = "34.9,29.1,39.4,33.4";

type Feature = { geometry: { coordinates: [number, number] }; properties: Record<string, string | undefined> };

async function photon(path: string, params: Record<string, string>): Promise<Feature[]> {
  const res = await fetch(`${BASE}/search/${path}?${new URLSearchParams(params)}`, { signal: AbortSignal.timeout(5000) });
  if (!res.ok) throw new Error(`Mapeleven search HTTP ${res.status}`);
  return ((await res.json()) as { features: Feature[] }).features;
}

const address = (p: Feature["properties"]) =>
  [p.street && [p.street, p.housenumber].filter(Boolean).join(" "), p.district ?? p.locality, p.city, p.country]
    .filter(Boolean).join("، ");

export class MapelevenGeocodingProvider implements GeocodingProvider {
  async reverseGeocode(lat: number, lng: number) {
    const [f] = await photon("reverse", { lat: `${lat}`, lon: `${lng}`, lang: "ar", limit: "1" });
    if (!f) return { street_name: null, formatted_address: null };
    return { street_name: f.properties.street ?? null, formatted_address: address(f.properties) || null };
  }

  async resolveAdminAreas(lat: number, lng: number) {
    const [f] = await photon("reverse", { lat: `${lat}`, lon: `${lng}`, lang: "ar", limit: "1" });
    const p = f?.properties ?? {};
    const out = {
      neighborhood: p.locality ?? null,     // حي, when OSM maps it
      district: p.district ?? null,         // منطقة
      locality: p.city ?? null,             // the city
      adminAreaLevel2: p.county ?? null,    // قضاء / ناحية
      adminAreaLevel1: p.state ?? null,     // محافظة
    };
    const candidates = [...new Set(Object.values(out).filter((x): x is string => !!x))];
    return { ...out, candidates };
  }

  async autocomplete(query: string) {
    const q = query.trim();
    if (q.length < 2) return [];
    const features = await photon("api", { q, lang: "ar", lat: "31.9539", lon: "35.9106", zoom: "12", bbox: JORDAN_BBOX, limit: "8" });
    return features.map((f) => {
      const [lng, lat] = f.geometry.coordinates;
      const main = f.properties.name ?? f.properties.street ?? "";
      const secondary = address(f.properties);
      // The id carries everything placeDetails needs, so no second lookup.
      const place_id = Buffer.from(JSON.stringify({ lat, lng, s: f.properties.street ?? null, a: secondary })).toString("base64url");
      return { place_id, description: [main, secondary].filter(Boolean).join("، "), main_text: main, secondary_text: secondary };
    });
  }

  async placeDetails(placeId: string) {
    const { lat, lng, s, a } = JSON.parse(Buffer.from(placeId, "base64url").toString());
    return { lat, lng, street_name: s, formatted_address: a };
  }
}
```

Session tokens are a Google billing feature; accept the argument and ignore it.

### Zone matching on administrative names

If your delivery zones are matched against admin-area names from Google (`neighborhood`, `sublocality`, `locality`, `administrative_area_level_1/2`), plan for different spellings. OpenStreetMap names often carry a type prefix (`منطقة زهران`, `قضاء الجامعة`, `محافظة العاصمة`) and may differ in hamza or tashkeel from Google's (`عمّان` vs `عمان`). Normalise both sides before comparing:

```ts
const PREFIXES = /^(منطقة|حي|قضاء|ناحية|لواء|محافظة|مدينة)\s+/;
export const normalise = (s: string) =>
  s.normalize("NFKC")
    .replace(/[\u064B-\u0652\u0670\u0640]/g, "")   // tashkeel and tatweel
    .trim()
    .replace(PREFIXES, "")                            // before the ة/ه step, so the prefixes still match
    .replace(/[أإآ]/g, "ا")
    .replace(/ة(?=\s|$)/g, "ه")                       // \b does not see Arabic letters
    .replace(/ى(?=\s|$)/g, "ي");
```

Then add the OSM spellings to your alias table where they still differ.

### Roll out safely: shadow mode first

1. Deploy the Mapeleven provider behind a setting (for example `GEOCODING_PROVIDER=mapeleven`), with Google still active.
2. For one to two weeks, on every address save, call both providers and log when the resolved zone differs. Do not change what customers see.
3. Fix aliases until mismatches are rare, then switch the setting. Keep the Google provider class for a while as a fallback.
4. Remove the Google key from servers and builds when you no longer need the fallback.

Autocomplete and reverse geocoding can switch earlier than zone matching: compare a sample of searches side by side, then switch them on their own.

## 3. Driver and staff apps

Opening the phone's navigation app (`geo:` or `maps.apple.com` links) does not use the Maps SDK and needs no change.

## 4. Checklist

- [ ] Map attribution (the "i" button) is visible and not covered by sheets or buttons.
- [ ] RTL: run the app in Arabic and check labels, the attribution corner and your overlay buttons.
- [ ] Privacy policy: location and search text now go to the Mapeleven server (or yours), not Google. Update the policy and the store data-safety forms.
- [ ] Remove the Google Maps keys from apps, CI secrets and servers once the fallback is retired.
- [ ] Widget tests: keep the stub-map flag; `MapelevenMap` needs a platform view, like `GoogleMap`.
- [ ] Load test autocomplete if you expect many users at once, or self-host the server.
