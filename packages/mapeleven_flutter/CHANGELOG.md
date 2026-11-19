## Unreleased

- Routing: `controller.router.route([from, to], mode: MapelevenTravelMode.car)` returns routes with duration, distance, line and Arabic or English steps; `controller.showRoute(route, alternatives: ...)` and `clearRoute()` draw them. Uses the server's Valhalla service (`MapelevenProvider.routingUrl`, set for `hosted` and `selfHosted`). Web SDK: `map.router.route()`, `map.showRoute()`, `map.clearRoute()`.
- `MapelevenMap`: `compassPosition`, `compassMargins` and `attributionMargins`, for apps that draw a bottom sheet over the map (the attribution button rides above it). Native only; MapLibre GL JS ignores the margins.

## 0.3.1

- Satellite imagery under the roads and labels: `MapelevenMap(imagery: MapelevenImagery.esri('...'))`, also `MapelevenImagery.mapTiler(...)` and `MapelevenImagery.custom(...)`. Uses your own key from the imagery provider; Mapeleven does not proxy it. Set `imagery` to null to switch back; markers and layers are kept. `hybridStyle()` is exported.
- Web SDK: `imagery` option, `setImagery()`, `esriImagery()`, `mapTilerImagery()`, `customImagery()`, `hybridStyle()`.

## 0.3.0

- API keys for the hosted service: `MapelevenProvider.hosted(key: 'mel_...')` and `selfHosted(url, key: ...)`. Get a free key at https://mapeleven.dev/account/. The key goes on the style URL (the server puts it on the tile URLs) and on search requests. Without a key everything works as before, with searches limited per device.
- Search errors include the server's message (for example a reached monthly limit).
- Web SDK: `hosted({ key })`; `hosted("https://...")` still takes a server URL.

## 0.2.1

- The map language now follows the app: leave `language` null and `MapelevenMap` uses the `MaterialApp` locale (else the device), Arabic for Arabic and English otherwise. Pass `language` to fix it, as before. Previously the default was always Arabic.
- `MapelevenLanguage.fromLocale(locale)`.
- Web SDK: `language` defaults to the page language (`<html lang>`, else the browser); `pageLanguage()` is exported.

## 0.2.0

- `MapelevenProvider.hosted()`: the public server at mapeleven.dev (Jordan and the GCC, Arabic and English search).
- Marker icons: `MapelevenIcon.fromIconData`, `MapelevenIcon.pin`, PNG icons; `registerIcon`, marker `rotation` and `anchor`, `moveMarker` for live vehicles, `data` on markers.
- Camera: `moveTo`, `fitPoints`, `center`, `zoom`; `onCameraIdle(center, zoom)` on the widget for centre-pin pickers.
- Basemap places: `onPoiTap`, `poiAt`, `visiblePois`, `nearbyPois(kinds:)`.
- Search: `osmTags` and `bounds` filters, `nearZoom` for local ranking, and new place fields (`street`, `houseNumber`, `postcode`, `district`, `locality`, `county`, `state`, `adminAreas`).
- GeoJSON options: `lineWidth`, `fillOpacity`, `dashed`; per-feature `color`.
- `compassEnabled` on the widget.

## 0.1.0

- First release: MapelevenMap widget, providers (OpenFreeMap, self-hosted), Arabic/English labels, themes, markers, GeoJSON with clustering, Photon search.
