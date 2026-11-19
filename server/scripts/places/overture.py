"""Turn Overture Maps places into extra map points and search entries.

Reads the Overture download (GeoJSONSeq) and the Photon OSM dumps, keeps
places in the covered countries that OpenStreetMap does not already have, and
writes:
  overture-pois.geojsonseq   points for tippecanoe (the `overture` tile layer)
  overture-photon.jsonl      Photon dump records, appended to the search import

Standard library only. Usage:
  python3 overture.py <overture.geojsonseq> <out-dir> <photon-dump.jsonl.zst>...
"""

import json
import math
import re
import subprocess
import sys
import unicodedata
from collections import Counter, defaultdict

COUNTRIES = {"JO", "SA", "AE", "QA", "KW", "BH", "OM", "YE"}
MIN_CONFIDENCE = 0.5  # search
MAP_CONFIDENCE = 0.6  # map points: categorised places only, a bit stricter

# Social handles, links and bare tags rather than place names.
JUNK = re.compile(r"^[@#]|https?:|www\.|\.(com|net|org|ae|sa|jo|qa|kw|om|bh)\b|^[a-z0-9_]+\.[a-z0-9_.]+$", re.I)

# Not added from Overture (OSM's own data is untouched).
SKIP = {
    "bar", "dance_club", "night_club", "pub", "beer_bar", "wine_bar", "cocktail_bar", "lounge",
    "liquor_store", "beer_wine_and_spirits_store", "brewery", "winery", "distillery",
    "casino", "gambling", "adult_entertainment", "adult_store", "hookah_bar", "tobacco_shop",
    "jewish_place_of_worship", "geographic_entities", "mountain", "bridge",
}

# Overture basic_category -> (osm_key, osm_value). osm_value doubles as the
# tile `kind`, matching Protomaps kinds so icons, colours and the SDK's
# category filters work unchanged.
MAP = {
    "restaurant": ("amenity", "restaurant"), "casual_eatery": ("amenity", "restaurant"),
    "food_service": ("amenity", "restaurant"), "food_and_drink": ("amenity", "restaurant"),
    "fast_food_restaurant": ("amenity", "fast_food"),
    "coffee_shop": ("amenity", "cafe"), "cafe": ("amenity", "cafe"),
    "smoothie_juice_bar": ("amenity", "cafe"), "non_alcoholic_beverage_venue": ("amenity", "cafe"),
    "bakery": ("shop", "bakery"), "dessert_shop": ("shop", "pastry"), "ice_cream_shop": ("amenity", "ice_cream"),
    "hotel": ("tourism", "hotel"), "resort": ("tourism", "hotel"), "lodging": ("tourism", "guest_house"),
    "private_lodging": ("tourism", "guest_house"),
    "hospital": ("amenity", "hospital"),
    "outpatient_care_facility": ("amenity", "clinic"), "health_care": ("amenity", "clinic"),
    "medical_service": ("amenity", "clinic"), "specialized_health_care": ("amenity", "clinic"),
    "diagnostics_imaging_or_lab_service": ("amenity", "clinic"), "surgery": ("amenity", "clinic"),
    "reproductive_perinatal_and_womens_care": ("amenity", "clinic"),
    "doctor": ("amenity", "doctors"), "dental_clinic": ("amenity", "dentist"),
    "pharmacy_and_drug_store": ("amenity", "pharmacy"),
    "muslim_place_of_worship": ("amenity", "place_of_worship"),
    "christian_place_of_worship": ("amenity", "place_of_worship"),
    "bank_or_credit_union": ("amenity", "bank"), "atm": ("amenity", "atm"),
    "currency_exchange": ("amenity", "bureau_de_change"), "money_transfer_service": ("amenity", "money_transfer"),
    "gas_station": ("amenity", "fuel"), "car_wash": ("amenity", "car_wash"), "car_rental": ("amenity", "car_rental"),
    "parking": ("amenity", "parking"),
    "shopping_mall": ("shop", "mall"), "department_store": ("shop", "department_store"),
    "warehouse_club_store": ("shop", "department_store"),
    "grocery_store": ("shop", "supermarket"), "supermarket": ("shop", "supermarket"),
    "food_and_beverage_store": ("shop", "convenience"), "convenience_store": ("shop", "convenience"),
    "fruit_and_vegetable_store": ("shop", "greengrocer"), "butcher_shop": ("shop", "butcher"),
    "fashion_and_apparel_store": ("shop", "clothes"), "electronics_store": ("shop", "electronics"),
    "mobile_phone_store": ("shop", "mobile_phone"), "books_music_and_video_store": ("shop", "books"),
    "personal_or_beauty_service": ("shop", "beauty"), "personal_care_and_beauty_store": ("shop", "beauty"),
    "gym": ("leisure", "fitness_centre"), "fitness_studio": ("leisure", "fitness_centre"),
    "sport_or_fitness_facility": ("leisure", "sports_centre"), "stadium_arena": ("leisure", "stadium"),
    "park": ("leisure", "park"), "playground": ("leisure", "playground"), "beach": ("natural", "beach"),
    "museum": ("tourism", "museum"), "art_gallery": ("tourism", "museum"),
    "historic_site": ("tourism", "attraction"), "amusement_park": ("tourism", "attraction"),
    "movie_theater": ("amenity", "cinema"), "library": ("amenity", "library"),
    "college_university": ("amenity", "university"), "campus_building": ("amenity", "university"),
    "place_of_learning": ("amenity", "school"), "education": ("amenity", "school"),
    "specialty_school": ("amenity", "school"), "elementary_school": ("amenity", "school"),
    "high_school": ("amenity", "school"), "educational_service": ("amenity", "school"),
    "preschool": ("amenity", "kindergarten"),
    "government_office": ("amenity", "townhall"), "community_and_government": ("amenity", "townhall"),
    "embassy": ("office", "diplomatic"), "police_station": ("amenity", "police"),
    "fire_station": ("amenity", "fire_station"), "post_office": ("amenity", "post_office"),
    "community_center": ("amenity", "community_centre"), "airport": ("aeroway", "aerodrome"),
    "bus_station": ("amenity", "bus_station"),
}
# Shown from zoom 14; everything else from zoom 15.
BIG = {"hospital", "mall", "hotel", "university", "aerodrome", "stadium", "museum", "department_store"}

ARABIC = re.compile(r"[؀-ۿ]")
DIACRITICS = re.compile(r"[ً-ْـ]")


def norm(name: str) -> str:
    s = unicodedata.normalize("NFKC", name).lower()
    s = DIACRITICS.sub("", s)
    s = s.translate(str.maketrans("أإآىةؤئ", "اااياوي"))
    s = re.sub(r"\bال", "", s)
    s = re.sub(r"\b(the|al|el)\b", "", s)
    return re.sub(r"[\W_]+", "", s)


CELL = 0.002  # about 200 m


def cell(lon: float, lat: float) -> tuple[int, int]:
    return int(math.floor(lon / CELL)), int(math.floor(lat / CELL))


def metres(a, b) -> float:
    dx = (a[0] - b[0]) * 111_320 * math.cos(math.radians(a[1]))
    dy = (a[1] - b[1]) * 110_540
    return math.hypot(dx, dy)


def load_osm(dumps):
    """Named OSM points of interest from the Photon dumps, in a grid."""
    grid = defaultdict(list)
    keys = {"amenity", "shop", "tourism", "leisure", "healthcare", "office", "craft", "historic", "aeroway"}
    count = 0
    for path in dumps:
        proc = subprocess.Popen(["zstd", "-dc", path], stdout=subprocess.PIPE, text=True)
        for line in proc.stdout:
            if '"type":"Place"' not in line[:40]:
                continue
            c = json.loads(line)["content"][0]
            if c.get("osm_key") not in keys or not c.get("centroid"):
                continue
            names = {norm(v) for v in (c.get("name") or {}).values() if isinstance(v, str)}
            names.discard("")
            lon, lat = c["centroid"]
            grid[cell(lon, lat)].append(((lon, lat), names, c.get("osm_value")))
            count += 1
        proc.wait()
    print(f"OSM points of interest: {count}", file=sys.stderr)
    return grid


def in_osm(grid, pos, name_n, kind) -> bool:
    cx, cy = cell(*pos)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for opos, onames, okind in grid.get((cx + dx, cy + dy), ()):
                d = metres(pos, opos)
                if d > 150:
                    continue
                if name_n and any(n and (n == name_n or (len(n) >= 4 and len(name_n) >= 4 and (n in name_n or name_n in n))) for n in onames):
                    return True
                if kind and okind == kind and d <= 30:
                    return True
    return False


def main():
    src, out, *dumps = sys.argv[1:]
    grid = load_osm(dumps)
    stats = Counter()
    added = defaultdict(list)  # Overture repeats some places; keep the first
    pois = open(f"{out}/overture-pois.geojsonseq", "w")
    photon = open(f"{out}/overture-photon.jsonl", "w")
    with open(src) as f:
        for i, line in enumerate(f):
            feat = json.loads(line.strip("\x1e"))
            p = feat["properties"]
            addr = (p.get("addresses") or [{}])[0] or {}
            if addr.get("country") not in COUNTRIES:
                continue
            stats["in_countries"] += 1
            if (p.get("confidence") or 0) < MIN_CONFIDENCE or p.get("operating_status") in ("permanently_closed", "temporarily_closed"):
                stats["low_confidence_or_closed"] += 1
                continue
            cat = p.get("basic_category") or ""
            if cat in SKIP:
                stats["skipped_category"] += 1
                continue
            name = ((p.get("names") or {}).get("primary") or "").strip()
            if len(name) < 3 or JUNK.search(name) or not re.search(r"[^\W\d_]", name):
                stats["junk_name"] += 1
                continue
            key, value = MAP.get(cat, ("office" if cat.endswith("service") else "shop", cat or "yes"))
            lon, lat = feat["geometry"]["coordinates"][:2]
            if in_osm(grid, (lon, lat), norm(name), value):
                stats["already_in_osm"] += 1
                continue
            name_n = norm(name)
            here = cell(lon, lat)
            if any(n == name_n and metres((lon, lat), q) <= 100
                   for dx in (-1, 0, 1) for dy in (-1, 0, 1)
                   for q, n in added.get((here[0] + dx, here[1] + dy), ())):
                stats["duplicate_in_overture"] += 1
                continue
            added[here].append(((lon, lat), name_n))
            stats["added_to_search"] += 1
            lang = "ar" if ARABIC.search(name) else "en"

            if cat in MAP and (p.get("confidence") or 0) >= MAP_CONFIDENCE:
                stats["added_to_map"] += 1
                props = {"name": name, f"name:{lang}": name, "kind": value,
                         "min_zoom": 14 if value in BIG else 15, "source": "overture"}
                if lang == "ar":
                    props["script"] = "Arabic"
                pois.write(json.dumps({
                    "type": "Feature", "geometry": {"type": "Point", "coordinates": [lon, lat]},
                    "properties": props, "tippecanoe": {"minzoom": props["min_zoom"]},
                }, ensure_ascii=False) + "\n")

            address = {k: v for k, v in (("street", addr.get("freeform")), ("city", addr.get("locality")),
                                         ("state", addr.get("region"))) if v}
            n = 9_000_000_000 + i
            photon.write(json.dumps({"type": "Place", "content": [{
                "place_id": str(n), "object_type": "N", "object_id": n,
                "osm_key": key, "osm_value": value,
                "categories": [f"osm.{key}.{value}", f"overture.{cat or 'place'}"],
                "address_type": "house", "importance": 0.00001,
                "name": {"name": name, f"name:{lang}": name},
                "address": address, **({"postcode": addr["postcode"]} if addr.get("postcode") else {}),
                "extra": {"source": "overture"},
                "country_code": addr["country"].lower(),
                "centroid": [lon, lat], "bbox": [lon, lat, lon, lat],
                "geometry": {"type": "Point", "coordinates": [lon, lat]},
            }]}, ensure_ascii=False) + "\n")
    pois.close()
    photon.close()
    print(json.dumps(stats), file=sys.stderr)


if __name__ == "__main__":
    main()
