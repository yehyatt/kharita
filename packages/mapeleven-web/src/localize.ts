import type { StyleSpecification } from "maplibre-gl";
import type { MapelevenLanguage } from "./provider";

/** Expression that picks the label in `language`, falling back to the local name. */
export function nameExpression(language: MapelevenLanguage): unknown[] {
  return language === "en"
    ? ["coalesce", ["get", "name:en"], ["get", "name_en"], ["get", "name:latin"], ["get", "name"]]
    : ["coalesce", ["get", `name:${language}`], ["get", "name"]];
}

/**
 * Rewrites the place/road/POI labels of an OpenMapTiles-schema style to one language.
 * Labels that are not names (house numbers, road refs) are left alone.
 */
export function localizeStyle(style: StyleSpecification, language: MapelevenLanguage): StyleSpecification {
  const expr = nameExpression(language);
  return {
    ...style,
    layers: style.layers.map((layer) => {
      if (layer.type !== "symbol") return layer;
      const field = layer.layout?.["text-field"];
      if (field == null || !/"name[:_"]/.test(JSON.stringify(field))) return layer;
      return { ...layer, layout: { ...layer.layout, "text-field": expr as never } };
    }),
  };
}
