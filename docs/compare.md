---
title: Mapeleven, Mapbox and Google Maps
order: 7
description: An honest comparison of Mapeleven, Mapbox and Google Maps for Flutter and web apps, covering licences, API keys, billing, data, search, routing and self-hosting.
---

# Mapeleven, Mapbox and Google Maps

All three put an interactive map, markers and address search in a Flutter or web app. They differ in who owns the stack, how you pay, and where your users' locations go. This page is written to help you pick, including when Mapeleven is the wrong choice.

## At a glance

| | Mapeleven | Mapbox | Google Maps Platform |
|---|---|---|---|
| SDK licence | MIT (open source) | Proprietary since GL JS v2 (2020) | Proprietary |
| Map engine | MapLibre (open-source fork of Mapbox GL) | Mapbox GL | Google |
| Map data | OpenStreetMap | OpenStreetMap plus Mapbox's own sources | Google's own |
| API key or token | Free key, no card; optional while developing | Required | Required |
| Billing | None for the software; you pay for your server | Usage-based beyond a free tier | Usage-based beyond a monthly credit |
| Self-hosting | Yes: one Docker Compose stack | No | No |
| Where locations go | Your server, or mapeleven.dev | Mapbox | Google |
| Flutter | `mapeleven` package | `mapbox_maps_flutter` | `google_maps_flutter` |
| Web | `mapeleven` (on MapLibre GL JS) | Mapbox GL JS | Maps JavaScript API |
| Arabic labels and RTL | Yes, switchable at runtime | Yes | Yes |
| Place search and reverse geocoding | Yes (Photon on OpenStreetMap) | Yes | Yes, with the richest business data |
| Business ratings, photos, opening hours | No | Limited | Yes |
| Road routing and ETAs | Not yet ([roadmap](https://github.com/yehyatt/mapeleven/blob/main/docs/ROADMAP.md)) | Yes | Yes |
| Live traffic | No | Yes | Yes |
| Satellite imagery | With your own Esri or MapTiler key ([guide](satellite.md)) | Yes | Yes |
| Offline maps | Planned | Yes | No |

Pricing of the other two changes often; check their pricing pages for current numbers.

## Choose Mapeleven when

- You want a free key with no card and no bill that grows with your users.
- Locations must stay on servers you choose, for example for a bank, a public body, or a data protection review.
- Your map is for delivery, logistics, field work or store finders: address picking, zones, clusters and moving vehicles.
- You build in Arabic and English and want both to look right without extra work.
- You already use MapLibre or OpenStreetMap and want a ready SDK and server instead of assembling the parts.

## Choose Mapbox or Google Maps when

- You need turn-by-turn navigation, traffic-aware ETAs or live traffic today.
- You need satellite imagery included, without a separate imagery account.
- Your users search for businesses by rating, photos or opening hours (Google's place data is the strongest here).
- You want a managed service with a commercial SLA and do not want to run any server.

## Moving over

- From Google Maps: [Coming from Google Maps](google-maps.md)
- From Mapbox: [Coming from Mapbox](mapbox.md)
- Plain OpenStreetMap in Flutter: [OpenStreetMap in Flutter](openstreetmap-flutter.md)
