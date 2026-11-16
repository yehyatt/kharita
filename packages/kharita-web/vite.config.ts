import { defineConfig } from "vite";

export default defineConfig({
  build: {
    lib: { entry: "src/index.ts", formats: ["es"], fileName: () => "kharita.js" },
    rollupOptions: { external: ["maplibre-gl"] },
    cssFileName: "kharita",
  },
});
