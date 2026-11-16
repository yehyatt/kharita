import { defineConfig } from "vite";
import { fileURLToPath } from "node:url";

// Point at the SDK sources so edits show up without rebuilding the package.
export default defineConfig({
  // MapLibre 6 loads its worker as a separate module next to maplibre-gl.mjs;
  // Vite's dependency pre-bundling moves the file and breaks that URL.
  optimizeDeps: { exclude: ["maplibre-gl"] },
  resolve: {
    dedupe: ["maplibre-gl"],
    alias: [{ find: /^kharita$/, replacement: fileURLToPath(new URL("../../packages/kharita-web/src/index.ts", import.meta.url)) }],
  },
});
