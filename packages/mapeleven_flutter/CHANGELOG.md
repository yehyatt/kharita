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
