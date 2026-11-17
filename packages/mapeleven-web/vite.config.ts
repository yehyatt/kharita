import { defineConfig } from "vite";

export default defineConfig({
  build: {
    lib: { entry: "src/index.ts", formats: ["es"], fileName: () => "mapeleven.js" },
    rollupOptions: { external: ["maplibre-gl"] },
    cssFileName: "mapeleven",
  },
});
