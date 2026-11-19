---
title: Routing and directions
order: 4.9
description: Road routes for car, walking and bicycle in Flutter and on the web, with Arabic and English step-by-step instructions, from Mapeleven's own routing server.
---

# Routing and directions

Mapeleven finds road routes by car, on foot and by bicycle, with the travel time, the distance, other route choices and step-by-step instructions in Arabic or English. Routes come from [Valhalla](https://github.com/valhalla/valhalla) running on the Mapeleven server over OpenStreetMap roads, so the request never goes to Google or Mapbox.

Routes cover the same region as the hosted map (Jordan and the Gulf). On your own server they cover whatever extracts you build ([self-hosting](self-hosting.md)).

## Flutter

```dart
final routes = await controller.router.route(
  [from, to],                      // two or more LatLng stops, in order
  mode: MapelevenTravelMode.car,   // .walk, .bike
  language: MapelevenLanguage.ar,  // instruction language
  alternatives: 2,                 // up to 2 other choices, when the roads allow
);
final best = routes.first;
print('${best.duration.inMinutes} min, ${(best.distanceMeters / 1000).toStringAsFixed(1)} km');

await controller.showRoute(best, alternatives: routes.skip(1).toList());
// later
await controller.clearRoute();
```

`showRoute` draws the route in blue under your markers, other choices in grey, and fits them on screen. Pass `padding` to keep the route clear of a bottom sheet. Each `MapelevenStep` has an `instruction` ready to show ("انعطف يمينًا إلى شارع المدينة المنورة"), a `maneuver` for picking an arrow icon, its distance and its position.

Without a map, use `MapelevenRouter(provider)` directly.

## Web

```js
const routes = await map.router.route([[35.91, 31.95], [35.87, 31.99]], {
  mode: "car", language: "en", alternatives: 2,
});
map.showRoute(routes[0], { alternatives: routes.slice(1), padding: { bottom: 280, top: 40, left: 40, right: 40 } });
map.clearRoute();
```

Coordinates are `[lng, lat]`, as everywhere in the web SDK.

## What to expect

- **Times do not include live traffic.** They come from road types and speed limits, so rush hour in a big city takes longer than shown. Say so in your app.
- **Road data is OpenStreetMap's.** A missing one-way sign or turn restriction gives a wrong route in that spot; anyone can fix it on OpenStreetMap and the fix arrives with the monthly refresh.
- **Not turn-by-turn navigation yet.** There is no voice guidance or rerouting while driving; that is on the [roadmap](https://github.com/yehyatt/mapeleven/blob/main/docs/ROADMAP.md).
- **Usage:** on the hosted service, one route request counts as one search toward your monthly allowance.

When no road connects the stops, `route` throws `MapelevenRoutingException` (web: `MapelevenRoutingError`) with `noRoute` set.
