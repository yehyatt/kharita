# mapeleven

Open maps made simple for the web: OpenStreetMap + MapLibre GL JS with Arabic-first styles,
place search and a self-hostable tile server.

```ts
import { MapelevenMap, openFreeMap } from "mapeleven";
import "mapeleven/style.css";

const map = new MapelevenMap("map", { provider: openFreeMap(), language: "ar" });
map.addMarker([35.9106, 31.9539], { popup: "عمّان" });
```

Full guide (including the Vite worker note), server setup and roadmap: https://github.com/yehyatt/mapeleven

Map data © OpenStreetMap contributors (ODbL). Keep the attribution control visible.
