// Print a paper road map: one sheet (A4 to A0) or an A4 booklet, as a PDF.
// The map is drawn by MapLibre at print resolution in a hidden map; the frame, grid, legend,
// scale bar and town index are drawn on a 2D canvas (it shapes Arabic), and each page goes
// into the PDF as one image, so what you preview is what prints.
import * as maplibregl from "maplibre-gl";
import { MapelevenSearch, hosted } from "/static/js/mapeleven.js";

const ORIGIN = ["localhost", "127.0.0.1"].includes(location.hostname) ? "https://mapeleven.dev" : location.origin;
const provider = hosted(ORIGIN);
const search = new MapelevenSearch(provider);
maplibregl.setWorkerUrl("/static/js/maplibre-gl-worker.mjs");
const rtlReady = maplibregl.setRTLTextPlugin(provider.rtlPluginUrl, false).catch(() => {});

// ---------- Paper and geometry ----------

const PAPER = { A4: [210, 297], A3: [297, 420], A2: [420, 594], A1: [594, 841], A0: [841, 1189] };
/** One map pixel is a quarter millimetre on paper: style text of 12 px prints about 3 mm tall. */
const MM_PER_PX = 0.25;
/** Booklet pages share this much map at each edge, so nothing falls between pages. */
const OVERLAP_MM = 10;
const EARTH = 2 * Math.PI * 6378137;

/** Where everything sits on a page, in millimetres. Margins and type grow a little on big sheets. */
function layout(W, H) {
  const f = Math.min(2.2, Math.max(1, Math.sqrt((W * H) / (210 * 297)) * 0.8));
  const margin = 8;
  const header = 11 * f;
  const footer = 19 * f;
  const band = 5.5 * f;
  const map = { x: margin + band, y: margin + header + band, w: W - 2 * margin - 2 * band, h: H - 2 * margin - header - footer - 2 * band };
  return { W, H, f, margin, header, footer, band, map };
}

function zoomFor(scale, lat) {
  return Math.log2((EARTH * Math.cos((lat * Math.PI) / 180)) / (512 * scale * MM_PER_PX * 0.001));
}

function niceStep(x) {
  const p = 10 ** Math.floor(Math.log10(x));
  for (const m of [1, 2, 2.5, 5, 10]) if (m * p >= x * 0.8) return m * p;
  return 10 * p;
}

function niceFloor(x) {
  const p = 10 ** Math.floor(Math.log10(x));
  for (const m of [10, 5, 2, 1]) if (m * p <= x) return m * p;
  return p;
}

const fmtKm = (km) => (km >= 1 ? `${+km.toFixed(1)} km` : `${Math.round(km * 1000)} m`);
const fmtScale = (s) => `1:${s.toLocaleString("en")}`;
const letter = (i) => (i < 26 ? String.fromCharCode(65 + i) : String.fromCharCode(64 + Math.floor(i / 26)) + String.fromCharCode(65 + (i % 26)));

/** Everything needed to print: pages with their centres, at one zoom so they join exactly. */
function plan(s, center) {
  const [pw, ph] = PAPER[s.mode === "booklet" ? "A4" : s.paper];
  const [W, H] = s.orient === "landscape" ? [ph, pw] : [pw, ph];
  const L = layout(W, H);
  const zoom = zoomFor(s.scale, center.lat);
  const world = 512 * 2 ** zoom;
  const cols = s.mode === "booklet" ? s.cols : 1;
  const rows = s.mode === "booklet" ? s.rows : 1;
  const pageW = L.map.w / MM_PER_PX;
  const pageH = L.map.h / MM_PER_PX;
  const stepX = (L.map.w - OVERLAP_MM) / MM_PER_PX;
  const stepY = (L.map.h - OVERLAP_MM) / MM_PER_PX;
  const totalW = stepX * (cols - 1) + pageW;
  const totalH = stepY * (rows - 1) + pageH;
  const c = maplibregl.MercatorCoordinate.fromLngLat(center);
  const left = c.x * world - totalW / 2;
  const top = c.y * world - totalH / 2;
  const toLngLat = (x, y) => new maplibregl.MercatorCoordinate(x / world, y / world).toLngLat();
  const pages = [];
  for (let j = 0; j < rows; j++) {
    for (let i = 0; i < cols; i++) {
      const x = left + stepX * i;
      const y = top + stepY * j;
      pages.push({
        n: j * cols + i + 1, i, j,
        center: toLngLat(x + pageW / 2, y + pageH / 2),
        nw: toLngLat(x, y), se: toLngLat(x + pageW, y + pageH),
      });
    }
  }
  const metresPerPx = s.scale * MM_PER_PX * 0.001;
  const gridKm = niceStep((40 * s.scale) / 1e6);
  return {
    s, W, H, L, zoom, cols, rows, pages, pageW, pageH,
    area: { nw: toLngLat(left, top), se: toLngLat(left + totalW, top + totalH), center },
    widthKm: (totalW * metresPerPx) / 1000, heightKm: (totalH * metresPerPx) / 1000,
    gridKm, gridPx: (gridKm * 1000) / metresPerPx,
    // Overview page: the whole area on one A4 frame.
    overviewZoom: zoom - Math.log2(Math.max(totalW / pageW, totalH / pageH) * 1.08),
  };
}

// ---------- Print style: the light style recoloured as a paper road map ----------

const POI_KINDS = ["hospital", "clinic", "fuel", "police", "place_of_worship"];
const POI_COLORS = { hospital: "#D62828", clinic: "#D62828", fuel: "#1D4ED8", police: "#111827", place_of_worship: "#15803D" };
// Road widths in map pixels (a quarter millimetre each) by zoom, wider than on screen at
// country scales so main roads stay readable on paper.
const curve = (...stops) => ["interpolate", ["exponential", 1.5], ["zoom"], ...stops];
const ROADS = {
  highway: { fill: "#D8352A", casing: "#6E1A12", width: curve(5, 1.6, 8, 2.6, 11, 3.4, 13, 4.2, 15, 6, 18, 16), outline: curve(5, 0.5, 10, 0.7, 14, 0.9) },
  major: { fill: "#F5BF3C", casing: "#8A5A0B", width: curve(6, 1, 8, 1.6, 10, 2.2, 12, 2.8, 15, 4.5, 18, 13), outline: curve(8, 0, 9, 0.5, 14, 0.8) },
  link: { fill: "#F8D374", casing: "#8A5A0B", width: curve(11, 0.6, 13, 1.1, 18, 11), outline: curve(12, 0, 13, 0.6) },
  minor: { fill: "#FFFFFF", casing: "#9B8F7B", width: curve(11, 0, 12, 0.6, 15, 2.2, 18, 11), outline: curve(11.5, 0, 12.5, 0.6) },
};
const PAPER_BG = "#F4EEDB";
const HALO = "#FFFBEF";

/** Multiplies the numbers a style value produces, through zoom curves and case/match branches. */
function scaleValue(v, k) {
  if (typeof v === "number") return v * k;
  if (!Array.isArray(v)) return v;
  const o = v.slice();
  const at = (i) => (o[i] = scaleValue(o[i], k));
  if (o[0] === "interpolate" || o[0] === "interpolate-hcl" || o[0] === "interpolate-lab") for (let i = 4; i < o.length; i += 2) at(i);
  else if (o[0] === "step") { at(2); for (let i = 4; i < o.length; i += 2) at(i); }
  else if (o[0] === "case") { for (let i = 2; i < o.length - 1; i += 2) at(i); at(o.length - 1); }
  else if (o[0] === "match") { for (let i = 3; i < o.length - 1; i += 2) at(i); at(o.length - 1); }
  return o;
}

function roadClass(id) {
  if (id.includes("highway")) return "highway";
  if (id.includes("major")) return "major";
  if (id.includes("link")) return "link";
  if (/minor|other|service|pier/.test(id)) return "minor";
  return null;
}

function printStyle(style, lang) {
  const nameExpr = ["coalesce", ["get", `name:${lang}`], ["get", "name"]];
  const layers = [];
  for (const src of style.layers) {
    const l = structuredClone(src);
    const p = (l.paint ??= {});
    if (["pois", "pois-overture", "address_label", "roads_oneway"].includes(l.id)) continue;
    if (l.id === "background") p["background-color"] = PAPER_BG;
    else if (l.id === "earth") p["fill-color"] = PAPER_BG;
    else if (l.id.startsWith("landcover") || l.id.startsWith("landuse_park") || l.id === "landuse_urban_green") p["fill-opacity"] = 0.4;
    else if (l.id === "buildings") { p["fill-color"] = "#DDD2BC"; p["fill-opacity"] = 0.85; }
    else if (l.id === "water" && l.type === "fill") p["fill-color"] = "#A6CDE4";
    else if (l.id.startsWith("water_") && l.type === "line") p["line-color"] = "#7DB0D3";
    else if (l.id.startsWith("water") && l.type === "symbol") { p["text-color"] = "#2E6490"; p["text-halo-color"] = HALO; }
    else if (l.id === "roads_rail") p["line-color"] = "#4B4B4B";
    else if (l.id === "boundaries_country") {
      p["line-color"] = "#7E3A8C"; p["line-width"] = scaleValue(p["line-width"] ?? 1, 2); p["line-dasharray"] = [3, 1.5];
    } else if (l.id === "boundaries") p["line-color"] = "#A98BB5";
    else if (l.type === "line" && l.id.startsWith("roads_") && roadClass(l.id)) {
      const r = ROADS[roadClass(l.id)];
      const casing = l.id.includes("casing");
      p["line-color"] = casing ? r.casing : r.fill;
      if (casing) { p["line-gap-width"] = r.width; p["line-width"] = r.outline; } else p["line-width"] = r.width;
      if (l.id.includes("tunnels")) p["line-opacity"] = 0.5;
    } else if (l.type === "symbol" && l.id.startsWith("roads_labels")) {
      p["text-color"] = "#333333"; p["text-halo-color"] = HALO; p["text-halo-width"] = 1.5;
    } else if (l.type === "symbol" && l.id.startsWith("places_")) {
      p["text-color"] = l.id === "places_country" ? "#6B2E78" : l.id === "places_locality" ? "#161616" : "#5A4E3C";
      p["text-halo-color"] = HALO;
      p["text-halo-width"] = 2;
      if (l.layout?.["text-size"] !== undefined) l.layout["text-size"] = scaleValue(l.layout["text-size"], l.id === "places_locality" ? 1.15 : 1.05);
    }
    layers.push(l);
  }
  const kindFilter = ["in", ["get", "kind"], ["literal", POI_KINDS]];
  const poiLayers = [
    {
      id: "print-poi", type: "circle", source: "protomaps", "source-layer": "pois", minzoom: 11, filter: kindFilter,
      paint: {
        "circle-radius": ["interpolate", ["linear"], ["zoom"], 11, 2.4, 15, 4.5],
        "circle-color": ["match", ["get", "kind"], ...Object.entries(POI_COLORS).flat(), "#666666"],
        "circle-stroke-color": "#FFFFFF", "circle-stroke-width": 1,
      },
    },
    {
      id: "print-poi-label", type: "symbol", source: "protomaps", "source-layer": "pois", minzoom: 13.5,
      filter: ["all", kindFilter, ["!=", ["get", "kind"], "place_of_worship"]],
      layout: {
        "text-field": nameExpr, "text-font": ["Noto Sans Regular"], "text-size": 10,
        "text-variable-anchor": ["left", "right"], "text-radial-offset": 0.7, "text-optional": true, "text-max-width": 9,
      },
      paint: { "text-color": "#3A3A3A", "text-halo-color": HALO, "text-halo-width": 1.5 },
    },
  ];
  const at = layers.findIndex((l) => l.id.startsWith("places_"));
  layers.splice(at < 0 ? layers.length : at, 0, ...poiLayers);
  return { ...style, layers };
}

const styles = {};
async function loadStyle(lang) {
  styles[lang] ??= fetch(provider.styleUrl("light", lang)).then(async (r) => {
    if (!r.ok) throw new Error(`Style failed: HTTP ${r.status}`);
    return printStyle(await r.json(), lang);
  });
  return styles[lang];
}

// ---------- Words printed on the paper ----------

const WORDS = {
  en: {
    scale: "Scale", printed: "Printed", page: (n, t) => `Page ${n} of ${t}`, overview: "Pages in this booklet", index: "Index of places",
    grid: (d) => `Grid square: ${d}`, legend: [["highway", "Motorway"], ["major", "Main road"], ["minor", "Road"], ["border", "Border"], ["hospital", "Hospital"], ["fuel", "Fuel"], ["police", "Police"], ["place_of_worship", "Place of worship"]],
    credit: "Map data © OpenStreetMap contributors · mapeleven.dev",
    notes: (d) => [
      "Print at actual size (100%), not \"fit to page\", so the scale is true.",
      "The top of every page is north.",
      `Each grid square is ${d} across.`,
      "Numbers at the page edges show which page continues the map.",
    ],
    north: "N",
  },
  ar: {
    scale: "مقياس الرسم", printed: "طُبعت في", page: (n, t) => `صفحة ${n} من ${t}`, overview: "صفحات هذا الكتيّب", index: "فهرس الأماكن",
    grid: (d) => `مربع الشبكة: ${d.replace("km", "كم").replace(" m", " م")}`,
    legend: [["highway", "طريق سريع"], ["major", "طريق رئيسي"], ["minor", "طريق"], ["border", "حدود دولية"], ["hospital", "مستشفى"], ["fuel", "محطة وقود"], ["police", "شرطة"], ["place_of_worship", "دار عبادة"]],
    credit: "بيانات الخريطة © مساهمو OpenStreetMap · mapeleven.dev",
    notes: (d) => [
      "اطبع بالحجم الفعلي (100%) وليس \"ملاءمة للصفحة\" ليبقى المقياس صحيحًا.",
      "أعلى كل صفحة هو الشمال.",
      `ضلع كل مربع في الشبكة ${d.replace("km", "كم").replace(" m", " م")}.`,
      "الأرقام على حواف الصفحة تدل على الصفحة التي تكمل الخريطة.",
    ],
    north: "ش",
  },
};

// ---------- Drawing a page ----------

const FONT = '"Inter", "IBM Plex Sans Arabic", system-ui, sans-serif';
const FONT_AR = '"IBM Plex Sans Arabic", "Inter", system-ui, sans-serif';
const INK = "#1E1A14";

function pen(ctx, dpi) {
  const u = dpi / 25.4; // pixels per millimetre
  const mm = (v) => v * u;
  return {
    mm,
    text(str, x, y, size, { align = "left", weight = 400, color = INK, ar = false, baseline = "alphabetic" } = {}) {
      ctx.font = `${weight} ${mm(size)}px ${ar ? FONT_AR : FONT}`;
      ctx.fillStyle = color;
      ctx.textAlign = align;
      ctx.textBaseline = baseline;
      ctx.direction = ar ? "rtl" : "ltr";
      ctx.fillText(str, mm(x), mm(y));
      ctx.direction = "ltr";
    },
    width(str, size, { weight = 400, ar = false } = {}) {
      ctx.font = `${weight} ${mm(size)}px ${ar ? FONT_AR : FONT}`;
      return ctx.measureText(str).width / u;
    },
    rect(x, y, w, h, { fill, stroke, width = 0.3 } = {}) {
      if (fill) { ctx.fillStyle = fill; ctx.fillRect(mm(x), mm(y), mm(w), mm(h)); }
      if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = mm(width); ctx.strokeRect(mm(x), mm(y), mm(w), mm(h)); }
    },
    line(x1, y1, x2, y2, color, width, dash) {
      ctx.strokeStyle = color; ctx.lineWidth = mm(width); ctx.setLineDash(dash ? dash.map(mm) : []);
      ctx.beginPath(); ctx.moveTo(mm(x1), mm(y1)); ctx.lineTo(mm(x2), mm(y2)); ctx.stroke(); ctx.setLineDash([]);
    },
    dot(x, y, r, fill) {
      ctx.fillStyle = fill; ctx.beginPath(); ctx.arc(mm(x), mm(y), mm(r), 0, 2 * Math.PI); ctx.fill();
      ctx.strokeStyle = "#fff"; ctx.lineWidth = mm(0.25); ctx.stroke();
    },
    triangle(x, y, size, dir, color = INK) {
      const h = size / 2;
      const pts = { up: [[0, -h], [h, h], [-h, h]], down: [[0, h], [h, -h], [-h, -h]], left: [[-h, 0], [h, -h], [h, h]], right: [[h, 0], [-h, -h], [-h, h]] }[dir];
      ctx.fillStyle = color; ctx.beginPath();
      pts.forEach(([dx, dy], k) => (k ? ctx.lineTo : ctx.moveTo).call(ctx, mm(x + dx), mm(y + dy)));
      ctx.closePath(); ctx.fill();
    },
  };
}

function drawHeader(P, plan, title, right) {
  const { L } = plan;
  const ar = plan.s.lang === "ar";
  const y = L.margin + L.header * 0.68;
  const t = 5 * L.f;
  const sub = 2.7 * L.f;
  if (ar) {
    P.text(title, L.W - L.margin, y, t, { align: "right", weight: 700, ar: true });
    P.text(right, L.margin, y, sub, { align: "left", ar: true, color: "#4A4238" });
  } else {
    P.text(title, L.margin, y, t, { weight: 700 });
    P.text(right, L.W - L.margin, y, sub, { align: "right", color: "#4A4238" });
  }
}

function drawLegend(P, plan) {
  const { L, s } = plan;
  const ar = s.lang === "ar";
  const w = WORDS[s.lang];
  const size = 2.6 * L.f;
  const top = L.H - L.margin - L.footer + 4 * L.f;
  const blockW = 58 * L.f; // scale bar block on the far side
  const start = ar ? L.W - L.margin : L.margin;
  const limit = L.W - 2 * L.margin - blockW - 6;
  let x = 0;
  let row = 0;
  for (const [key, label] of w.legend) {
    const itemW = 9 * L.f + P.width(label, size, { ar }) + 5 * L.f;
    if (x + itemW > limit) { x = 0; row++; }
    const y = top + row * 5.5 * L.f;
    const sx = ar ? start - x - 7 * L.f : start + x;
    const mid = y - size * 0.35;
    if (key in ROADS || key === "border") {
      if (key === "border") P.line(sx, mid, sx + 7 * L.f, mid, "#7E3A8C", 0.6 * L.f, [1.4 * L.f, 0.7 * L.f]);
      else {
        const r = ROADS[key];
        P.line(sx, mid, sx + 7 * L.f, mid, r.casing, (key === "minor" ? 1.3 : 1.7) * L.f);
        P.line(sx + 0.2, mid, sx + 7 * L.f - 0.2, mid, r.fill, (key === "minor" ? 0.8 : 1.15) * L.f);
      }
    } else P.dot(sx + 3.5 * L.f, mid, 1.1 * L.f, POI_COLORS[key]);
    const tx = ar ? sx - 2 * L.f : sx + 9 * L.f;
    P.text(label, tx, y, size, { align: ar ? "right" : "left", ar });
    x += itemW;
  }
}

function drawScaleBlock(P, plan) {
  const { L, s } = plan;
  const ar = s.lang === "ar";
  const w = WORDS[s.lang];
  const size = 2.5 * L.f;
  const top = L.H - L.margin - L.footer + 2.5 * L.f;
  // Scale bar: a round distance no longer than about 45 mm.
  const km = niceFloor((45 * L.f * s.scale) / 1e6);
  const len = (km * 1e6) / s.scale;
  const x0 = ar ? L.margin : L.W - L.margin - len;
  const barY = top + 1.5 * L.f;
  const h = 1.6 * L.f;
  for (let k = 0; k < 4; k++) P.rect(x0 + (len / 4) * k, barY, len / 4, h, { fill: k % 2 ? "#FFFFFF" : INK });
  P.rect(x0, barY, len, h, { stroke: INK, width: 0.25 });
  const ly = barY + h + size + 0.6;
  P.text("0", x0, ly, size, { align: "center" });
  P.text(fmtKm(km), x0 + len, ly, size, { align: "center" });
  const anchor = ar ? L.margin : L.W - L.margin;
  const align = ar ? "left" : "right";
  P.text(`${w.scale} ${fmtScale(s.scale)} · ${w.grid(fmtKm(plan.gridKm))}`, anchor, ly + size * 1.6, size, { align, ar });
  P.text(w.credit, anchor, L.H - L.margin - 0.5, 2.1 * L.f, { align, ar, color: "#5B5246" });
}

/** Grid lines over the map and their letters and numbers in the band around it. */
function drawGrid(P, plan, cellPx, page) {
  const { L } = plan;
  const m = L.map;
  const cell = cellPx * MM_PER_PX;
  const size = 2.6 * L.f;
  const cols = Math.ceil(m.w / cell);
  const rows = Math.ceil(m.h / cell);
  for (let i = 1; i < cols; i++) P.line(m.x + i * cell, m.y, m.x + i * cell, m.y + m.h, "rgba(70,50,30,0.38)", 0.18);
  for (let j = 1; j < rows; j++) P.line(m.x, m.y + j * cell, m.x + m.w, m.y + j * cell, "rgba(70,50,30,0.38)", 0.18);
  // Leave room for the neighbouring-page boxes in the middle of each edge (booklet pages).
  const box = NEIGHBOUR_BOX * L.f / 2 + 3;
  const free = (side, at) => !page || !hasNeighbour(plan, page, side) || Math.abs(at) > box;
  const label = (t, x, y) => P.text(t, x, y, size, { align: "center", weight: 600, baseline: "middle" });
  for (let i = 0; i < cols; i++) {
    const w = Math.min(cell, m.w - i * cell);
    if (w < cell * 0.3) continue;
    const cx = m.x + i * cell + w / 2;
    if (free("up", cx - m.x - m.w / 2)) label(letter(i), cx, m.y - L.band / 2);
    if (free("down", cx - m.x - m.w / 2)) label(letter(i), cx, m.y + m.h + L.band / 2);
  }
  for (let j = 0; j < rows; j++) {
    const h = Math.min(cell, m.h - j * cell);
    if (h < cell * 0.3) continue;
    const cy = m.y + j * cell + h / 2;
    if (free("left", cy - m.y - m.h / 2)) label(String(j + 1), m.x - L.band / 2, cy);
    if (free("right", cy - m.y - m.h / 2)) label(String(j + 1), m.x + m.w + L.band / 2, cy);
  }
}

const NEIGHBOUR_BOX = 16;
function hasNeighbour(plan, page, side) {
  return { up: page.j > 0, down: page.j < plan.rows - 1, left: page.i > 0, right: page.i < plan.cols - 1 }[side];
}

/** Neighbouring page numbers in the middle of each edge of a booklet page. */
function drawNeighbours(P, plan, page) {
  const { L, cols, rows } = plan;
  const m = L.map;
  const size = 2.8 * L.f;
  const tri = 2.2 * L.f;
  const n = (i, j) => j * cols + i + 1;
  const boxes = [];
  if (page.j > 0) boxes.push([m.x + m.w / 2, m.y - L.band / 2, "up", n(page.i, page.j - 1)]);
  if (page.j < rows - 1) boxes.push([m.x + m.w / 2, m.y + m.h + L.band / 2, "down", n(page.i, page.j + 1)]);
  if (page.i > 0) boxes.push([m.x - L.band / 2, m.y + m.h / 2, "left", n(page.i - 1, page.j)]);
  if (page.i < cols - 1) boxes.push([m.x + m.w + L.band / 2, m.y + m.h / 2, "right", n(page.i + 1, page.j)]);
  for (const [x, y, dir, num] of boxes) {
    const vertical = dir === "up" || dir === "down";
    const bw = vertical ? NEIGHBOUR_BOX * L.f : L.band;
    const bh = vertical ? L.band : NEIGHBOUR_BOX * L.f;
    P.rect(x - bw / 2, y - bh / 2, bw, bh, { fill: INK });
    P.triangle(vertical ? x - 3.5 * L.f : x, vertical ? y : y - 4 * L.f, tri, dir, "#FFFFFF");
    P.text(String(num), vertical ? x + 2.5 * L.f : x, vertical ? y : y + 3 * L.f, size, { align: "center", weight: 700, color: "#FFFFFF", baseline: "middle" });
  }
}

function drawNorth(P, plan) {
  const { L } = plan;
  const m = L.map;
  const x = m.x + m.w - 7 * L.f;
  const y = m.y + 9 * L.f;
  P.rect(x - 4 * L.f, y - 7.5 * L.f, 8 * L.f, 12 * L.f, { fill: "rgba(255,251,239,0.9)", stroke: INK, width: 0.2 });
  P.triangle(x, y - 1.5 * L.f, 4.5 * L.f, "up");
  P.text(WORDS[plan.s.lang].north, x, y + 3.2 * L.f, 3 * L.f, { align: "center", weight: 700, ar: plan.s.lang === "ar" });
}

function drawFrame(P, plan) {
  const { L } = plan;
  const m = L.map;
  P.rect(m.x - L.band, m.y - L.band, m.w + 2 * L.band, m.h + 2 * L.band, { stroke: INK, width: 0.5 });
  P.rect(m.x, m.y, m.w, m.h, { stroke: INK, width: 0.3 });
}

// ---------- Rendering ----------

let gpuMax;
function glLimit() {
  return (gpuMax ??= readGlLimit());
}
function readGlLimit() {
  const gl = document.createElement("canvas").getContext("webgl2") ?? document.createElement("canvas").getContext("webgl");
  if (!gl) return 4096;
  const vp = gl.getParameter(gl.MAX_VIEWPORT_DIMS);
  const max = Math.min(gl.getParameter(gl.MAX_RENDERBUFFER_SIZE), vp[0], vp[1], 16384);
  gl.getExtension("WEBGL_lose_context")?.loseContext();
  return max;
}

/** The dpi this device can manage for a page: big sheets are limited by canvas and GPU size. */
function usableDpi(plan, wanted) {
  const touch = matchMedia("(pointer: coarse)").matches;
  const budget = touch ? 16e6 : 80e6; // page pixels; iOS Safari stops near 16.7 million
  const byArea = 25.4 * Math.sqrt(budget / (plan.W * plan.H));
  const byGpu = (glLimit() * 25.4) / Math.max(plan.L.map.w, plan.L.map.h);
  return Math.floor(Math.min(wanted, byArea, byGpu));
}

function waitIdle(map) {
  return new Promise((resolve) => {
    const done = () => { clearTimeout(timer); resolve(); };
    const timer = setTimeout(() => { map.off("idle", done); resolve(); }, 90000);
    map.once("idle", done);
    map.triggerRepaint();
  });
}

async function makePdf(s, center, status) {
  const p = plan(s, center);
  const dpi = usableDpi(p, s.dpi);
  const words = WORDS[s.lang];
  const ar = s.lang === "ar";
  await Promise.all([rtlReady, document.fonts.load(`700 20px "IBM Plex Sans Arabic"`, "عربي"), document.fonts.load(`700 20px Inter`), document.fonts.ready]);

  const style = await loadStyle(s.lang);
  const holder = document.createElement("div");
  holder.className = "pm-offscreen";
  holder.style.width = `${p.pageW}px`;
  holder.style.height = `${p.pageH}px`;
  document.body.append(holder);
  const limit = glLimit();
  const map = new maplibregl.Map({
    container: holder, style, center: p.pages[0].center, zoom: p.zoom,
    pixelRatio: (dpi * MM_PER_PX) / 25.4, maxCanvasSize: [limit, limit],
    interactive: false, attributionControl: false, fadeDuration: 0,
    canvasContextAttributes: { preserveDrawingBuffer: true, antialias: true },
  });
  await new Promise((r) => map.once("load", r));

  const canvas = document.createElement("canvas");
  canvas.width = Math.round((p.W * dpi) / 25.4);
  canvas.height = Math.round((p.H * dpi) / 25.4);
  const ctx = canvas.getContext("2d");
  const P = pen(ctx, dpi);
  const { jsPDF } = window.jspdf;
  const orientation = p.W > p.H ? "landscape" : "portrait";
  const pdf = new jsPDF({ unit: "mm", format: [p.W, p.H], orientation, compress: true });
  let first = true;
  const addPage = async () => {
    const blob = await new Promise((r) => canvas.toBlob(r, "image/jpeg", 0.9));
    const bytes = new Uint8Array(await blob.arrayBuffer());
    if (!first) pdf.addPage([p.W, p.H], orientation);
    first = false;
    pdf.addImage(bytes, "JPEG", 0, 0, p.W, p.H, undefined, "FAST");
  };
  const blank = () => { ctx.fillStyle = "#FFFFFF"; ctx.fillRect(0, 0, canvas.width, canvas.height); };
  const drawMap = () => ctx.drawImage(map.getCanvas(), P.mm(p.L.map.x), P.mm(p.L.map.y), P.mm(p.L.map.w), P.mm(p.L.map.h));
  const date = new Date().toLocaleDateString(ar ? "ar-JO" : "en-GB", { day: "numeric", month: "long", year: "numeric" });
  const booklet = s.mode === "booklet" && p.pages.length > 1;
  const total = p.pages.length;

  try {
    // Overview page for a booklet: the whole area with page outlines and numbers.
    if (booklet) {
      status(ar ? "صفحة النظرة العامة…" : "Overview page…");
      map.jumpTo({ center: p.area.center, zoom: p.overviewZoom });
      await waitIdle(map);
      blank();
      drawMap();
      ctx.save();
      ctx.beginPath(); ctx.rect(P.mm(p.L.map.x), P.mm(p.L.map.y), P.mm(p.L.map.w), P.mm(p.L.map.h)); ctx.clip();
      for (const page of p.pages) {
        const a = map.project(page.nw);
        const b = map.project(page.se);
        const x = p.L.map.x + a.x * MM_PER_PX;
        const y = p.L.map.y + a.y * MM_PER_PX;
        const w = (b.x - a.x) * MM_PER_PX;
        const h = (b.y - a.y) * MM_PER_PX;
        P.rect(x, y, w, h, { fill: "rgba(30,26,20,0.06)", stroke: "#1E1A14", width: 0.45 });
        const size = Math.max(5, Math.min(w, h) * 0.22);
        P.rect(x + w / 2 - size * 0.75, y + h / 2 - size * 0.7, size * 1.5, size * 1.3, { fill: "rgba(255,251,239,0.92)" });
        P.text(String(page.n), x + w / 2, y + h / 2, size, { align: "center", weight: 700, baseline: "middle" });
      }
      ctx.restore();
      // Notes box.
      const notes = words.notes(fmtKm(p.gridKm));
      const nSize = 2.7;
      const boxW = Math.min(p.L.map.w - 12, 120);
      const boxH = notes.length * nSize * 1.7 + 5;
      const bx = ar ? p.L.map.x + p.L.map.w - boxW - 4 : p.L.map.x + 4;
      const by = p.L.map.y + p.L.map.h - boxH - 4;
      P.rect(bx, by, boxW, boxH, { fill: "rgba(255,251,239,0.95)", stroke: INK, width: 0.25 });
      notes.forEach((t, k) => P.text(t, ar ? bx + boxW - 3 : bx + 3, by + 4 + nSize + k * nSize * 1.7, nSize, { align: ar ? "right" : "left", ar }));
      drawFrame(P, p);
      drawNorth(P, p);
      drawHeader(P, p, s.title, `${words.overview} · ${fmtScale(s.scale)} · ${words.printed} ${date}`);
      drawLegend(P, p);
      drawScaleBlock(P, p);
      await addPage();
    }

    // Map pages, collecting town names for the index as we go.
    const names = new Map();
    const layers = ["places_locality", ...(s.scale <= 50000 ? ["places_subplace"] : [])];
    for (const page of p.pages) {
      status(ar ? `رسم الصفحة ${page.n} من ${total}…` : `Drawing page ${page.n} of ${total}…`);
      map.jumpTo({ center: page.center, zoom: p.zoom });
      await waitIdle(map);
      blank();
      drawMap();
      for (const f of map.queryRenderedFeatures({ layers })) {
        const name = f.properties[`name:${s.lang}`] ?? f.properties.name;
        if (!name || f.geometry.type !== "Point") continue;
        const pt = map.project(f.geometry.coordinates);
        if (pt.x < 0 || pt.y < 0 || pt.x > p.pageW || pt.y > p.pageH) continue;
        // A place in the overlap shows on two pages: index it on the page where it sits most central.
        const off = Math.max(Math.abs(pt.x / p.pageW - 0.5), Math.abs(pt.y / p.pageH - 0.5));
        const cell = letter(Math.floor(pt.x / p.gridPx)) + (Math.floor(pt.y / p.gridPx) + 1);
        const key = `${name}|${f.geometry.coordinates.map((c) => c.toFixed(2)).join(",")}`;
        const prev = names.get(key);
        if (!prev || off < prev.off) names.set(key, { name, ref: booklet ? `${page.n} · ${cell}` : cell, off });
      }
      drawGrid(P, p, p.gridPx, booklet ? page : null);
      drawFrame(P, p);
      drawNorth(P, p);
      if (booklet) drawNeighbours(P, p, page);
      const right = [fmtScale(s.scale), booklet ? words.page(page.n, total) : `${words.printed} ${date}`].join(" · ");
      drawHeader(P, p, s.title, right);
      drawLegend(P, p);
      drawScaleBlock(P, p);
      await addPage();
    }

    // Index pages.
    const entries = [...names.values()].sort((a, b) => a.name.localeCompare(b.name, s.lang));
    if (entries.length) {
      status(ar ? "الفهرس…" : "Index…");
      const m = p.L.map;
      const size = 2.7 * p.L.f;
      const lineH = size * 1.6;
      const colW = 62 * p.L.f;
      const perCol = Math.floor((m.h - 8) / lineH);
      const nCols = Math.max(1, Math.floor(m.w / colW));
      const colStep = m.w / nCols;
      const perPage = perCol * nCols;
      for (let start = 0, k = 0; start < entries.length; start += perPage, k++) {
        blank();
        P.rect(m.x - p.L.band, m.y - p.L.band, m.w + 2 * p.L.band, m.h + 2 * p.L.band, { stroke: INK, width: 0.5 });
        entries.slice(start, start + perPage).forEach((e, n) => {
          const c = Math.floor(n / perCol);
          const r = n % perCol;
          const y = m.y + 4 + r * lineH + size;
          const left = ar ? m.x + m.w - c * colStep : m.x + c * colStep;
          const right = ar ? left - colStep + 4 : left + colStep - 4;
          P.text(e.name, left, y, size, { align: ar ? "right" : "left", ar });
          P.text(e.ref, right, y, size, { align: ar ? "left" : "right", weight: 600 });
          // Dotted leader from the name to its page and square.
          const nameW = P.width(e.name, size, { ar });
          const refW = P.width(e.ref, size, { weight: 600 });
          const a = ar ? left - nameW - 1.5 : left + nameW + 1.5;
          const b = ar ? right + refW + 1.5 : right - refW - 1.5;
          if (ar ? a > b : b > a) P.line(a, y - 0.4, b, y - 0.4, "#A89F90", 0.25, [0.3, 1]);
        });
        const pages = Math.ceil(entries.length / perPage);
        drawHeader(P, p, s.title, pages > 1 ? `${words.index} (${k + 1}/${pages})` : words.index);
        drawLegend(P, p);
        drawScaleBlock(P, p);
        await addPage();
      }
    }
  } finally {
    map.remove();
    holder.remove();
  }
  const file = `${(s.title || "map").replace(/[^\p{L}\p{M}\p{N}]+/gu, "-").replace(/^-|-$/g, "") || "map"}-${s.mode === "booklet" ? "booklet" : s.paper}.pdf`;
  pdf.save(file);
  return { dpi, pages: pdf.getNumberOfPages(), file };
}

// ---------- Page controls and preview ----------

const $ = (id) => document.getElementById(id);
const settings = () => ({
  mode: document.querySelector('input[name="mode"]:checked').value,
  paper: $("paper").value,
  orient: $("orient").value,
  cols: Math.min(8, Math.max(1, +$("cols").value || 1)),
  rows: Math.min(8, Math.max(1, +$("rows").value || 1)),
  scale: +$("scale").value,
  lang: $("lang").value,
  dpi: +$("dpi").value,
  title: $("title").value.trim(),
});

const hash = location.hash.slice(1).split(",").map(Number);
const start = hash.length >= 2 && hash.every(Number.isFinite) ? { lng: hash[0], lat: hash[1], zoom: hash[2] } : null;
const preview = new maplibregl.Map({
  container: "map",
  style: { version: 8, sources: {}, layers: [] },
  center: start ? [start.lng, start.lat] : [35.9106, 31.9539],
  zoom: start?.zoom ?? 10,
  attributionControl: { compact: true },
});
preview.addControl(new maplibregl.NavigationControl({ showCompass: false }), "top-right");

async function applyStyle() {
  preview.setStyle(await loadStyle(settings().lang));
}

const svg = $("frames");
function drawFrames() {
  const s = settings();
  const p = plan(s, preview.getCenter());
  const box = (a, b) => {
    const A = preview.project(a);
    const B = preview.project(b);
    return { x: A.x, y: A.y, w: B.x - A.x, h: B.y - A.y };
  };
  const all = box(p.area.nw, p.area.se);
  const pages = p.pages.length > 1 ? p.pages.map((pg) => ({ n: pg.n, ...box(pg.nw, pg.se) })) : [];
  const { width, height } = svg.getBoundingClientRect();
  svg.innerHTML =
    `<path fill="rgba(15,23,42,0.35)" fill-rule="evenodd" d="M0 0H${width}V${height}H0Z M${all.x} ${all.y}h${all.w}v${all.h}h${-all.w}Z"/>` +
    pages.map((r) => `<rect x="${r.x}" y="${r.y}" width="${r.w}" height="${r.h}" fill="none" stroke="#0F766E" stroke-width="1.5" stroke-dasharray="5 4"/>` +
      `<text x="${r.x + r.w / 2}" y="${r.y + r.h / 2}" text-anchor="middle" dominant-baseline="middle" font-family="Inter, sans-serif" font-weight="700" font-size="${Math.max(12, Math.min(40, Math.min(r.w, r.h) / 4))}" fill="#0F766E" fill-opacity="0.8">${r.n}</text>`).join("") +
    `<rect x="${all.x}" y="${all.y}" width="${all.w}" height="${all.h}" fill="none" stroke="#0F766E" stroke-width="3"/>`;
  const sheets = s.mode === "booklet" ? `${p.pages.length} A4 page${p.pages.length > 1 ? "s" : ""}${p.pages.length > 1 ? " + overview" : ""} + index` : `one ${s.paper} sheet + index`;
  const dpi = usableDpi(p, s.dpi);
  $("summary").innerHTML = `Covers about <b>${Math.round(p.widthKm)} × ${Math.round(p.heightKm)} km</b> at ${fmtScale(s.scale)}: ${sheets}. Grid squares are ${fmtKm(p.gridKm)}.` +
    (dpi < s.dpi ? `<br><span class="fine">This device can draw this size at ${dpi} dpi; use a computer for more.</span>` : "");
}

function fitFrames() {
  const p = plan(settings(), preview.getCenter());
  const { clientWidth: w, clientHeight: h } = preview.getContainer();
  if (w < 50 || h < 50) return;
  const padding = Math.min(40, w / 6, h / 6);
  preview.fitBounds([[p.area.nw.lng, p.area.se.lat], [p.area.se.lng, p.area.nw.lat]], { padding, duration: 400 });
}

preview.on("move", drawFrames);
preview.on("resize", drawFrames);
preview.once("load", () => { drawFrames(); if (!start) fitFrames(); });
void applyStyle();

for (const el of document.querySelectorAll("select, input[name='mode'], #cols, #rows")) {
  el.addEventListener("change", () => {
    $("paper-wrap").hidden = settings().mode !== "sheet";
    $("pages-wrap").hidden = settings().mode !== "booklet";
    if (el.id === "lang") void applyStyle();
    drawFrames();
    if (["scale", "cols", "rows", "paper", "orient"].includes(el.id) || el.name === "mode") fitFrames();
  });
}

$("make").addEventListener("click", async () => {
  const btn = $("make");
  const status = (t) => ($("status").textContent = t);
  btn.disabled = true;
  try {
    const out = await makePdf(settings(), preview.getCenter(), status);
    status(`Saved ${out.file}: ${out.pages} page${out.pages > 1 ? "s" : ""} at ${out.dpi} dpi. Print at actual size (100%).`);
  } catch (e) {
    console.error(e);
    status(`Could not make the PDF: ${e.message ?? e}`);
  } finally {
    btn.disabled = false;
  }
});

// Search: jump to a place and use its name as the title.
let timer;
let controller;
$("q").addEventListener("input", () => { clearTimeout(timer); timer = setTimeout(find, 250); });
async function find() {
  const text = $("q").value.trim();
  const results = $("results");
  controller?.abort();
  if (text.length < 2) { results.hidden = true; return; }
  controller = new AbortController();
  try {
    const c = preview.getCenter();
    const places = await search.search(text, { language: /[؀-ۿ]/.test(text) ? "ar" : "en", near: { lat: c.lat, lng: c.lng }, limit: 6, signal: controller.signal });
    results.replaceChildren(...places.map((pl) => {
      const li = document.createElement("li");
      li.dir = "auto";
      li.append(Object.assign(document.createElement("strong"), { textContent: pl.name }), Object.assign(document.createElement("span"), { textContent: pl.address }));
      li.addEventListener("click", () => {
        results.hidden = true;
        $("q").value = pl.name;
        $("title").value = pl.name;
        preview.jumpTo({ center: [pl.lng, pl.lat] });
        fitFrames();
      });
      return li;
    }));
    results.hidden = places.length === 0;
  } catch (e) {
    if (e.name !== "AbortError") results.hidden = true;
  }
}
document.addEventListener("click", (e) => { if (!e.target.closest(".pm-search")) $("results").hidden = true; });
