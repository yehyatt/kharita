---
title: Printing paper maps
order: 4.95
description: Make a paper road map as a PDF, one large sheet or an A4 booklet, with a grid, legend, scale bar and index of places. For when the internet or GPS is down.
---

# Printing paper maps

Phones need the internet to load a map they have not saved, and they need GPS to show where you are. When either is down, a paper map still works. The [print page](https://mapeleven.dev/print/) makes one as a PDF from Mapeleven's map data, ready for a home printer or a print shop.

Open it from the Explorer too: the layers button, then **Print a paper map**. The frame starts where the Explorer map was.

## What you get

- **A road-map style** made for paper: cream background, red motorways, yellow main roads, white streets with outlines, dashed borders, and dots for hospitals, fuel, police and places of worship.
- **Arabic, or English and Arabic** names on the map, the legend and the index.
- **A grid** with letters across and numbers down, sized to a round distance (for example 2 km squares at 1:50,000), so you can judge distances by eye.
- **A scale bar, a north arrow and a legend** on every page.
- **An index of places** at the end: each town or neighbourhood with its grid square, and in a booklet its page number too.

## Two layouts

**A4 booklet.** Choose how many pages across and down. The pages overlap by 1 cm so nothing falls between them. Each page shows the numbers of the pages next to it at its edges, and the first page is an overview of the whole area with every page outlined.

**One sheet.** A4 to A0, portrait or landscape. A2 at 1:1,000,000 holds all of Jordan. Big sheets are for a print shop; the page tells you if your device can only draw them at a lower resolution, and a computer can do more than a phone.

## Scales

| Scale | 1 cm on paper | Good for |
|---|---|---|
| 1:10,000 | 100 m | Streets in one neighbourhood |
| 1:25,000 | 250 m | A city centre |
| 1:50,000 | 500 m | A city and its suburbs |
| 1:250,000 | 2.5 km | A region and the roads between towns |
| 1:1,000,000 | 10 km | A whole country |

The scale is exact at the centre of the map. Over a whole country it drifts by a few percent towards the north and south edges, as on any flat map.

## Printing it right

- Print at **actual size (100%)**, not "fit to page", or the scale bar and grid will not match the map.
- The top of every page is north. With a compass you can turn the map to match the ground.
- Keep one copy in the car and one at home, and print a new one now and then: roads change.

## How it works

The page draws the map with MapLibre at print resolution in a hidden map, then adds the frame, grid, legend and index with the browser's canvas, which shapes Arabic text correctly. Each page goes into the PDF as one image ([jsPDF](https://github.com/parallax/jsPDF)), so the PDF looks the same on every printer. Nothing is uploaded: the PDF is made in your browser.

Map data © OpenStreetMap contributors. The credit is printed on every page, as the data licence requires. Satellite imagery is not offered for printing: imagery providers' terms limit it.
