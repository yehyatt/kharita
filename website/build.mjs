// Builds the static site into dist/: the home page, docs rendered from ../docs/*.md,
// the web SDK and MapLibre files for the live map, and the Explorer web app if built.
// Usage: node build.mjs   (build the Explorer first: see deploy.sh)
import { marked } from "marked";
import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..");
const dist = join(here, "dist");
const src = join(here, "src");

rmSync(dist, { recursive: true, force: true });
mkdirSync(join(dist, "docs"), { recursive: true });
mkdirSync(join(dist, "static/js"), { recursive: true });

// Static pages and assets.
cpSync(src, dist, { recursive: true, filter: (p) => !p.endsWith("template.html") });

// Web SDK and MapLibre for the live map (served locally, no CDN).
const sdk = join(root, "packages/mapeleven-web/dist");
if (!existsSync(join(sdk, "mapeleven.js"))) throw new Error("Build the web SDK first: cd packages/mapeleven-web && npm run build");
cpSync(join(sdk, "mapeleven.js"), join(dist, "static/js/mapeleven.js"));
cpSync(join(sdk, "mapeleven.css"), join(dist, "static/mapeleven.css"));
const ml = join(root, "packages/mapeleven-web/node_modules/maplibre-gl/dist");
for (const f of ["maplibre-gl.mjs", "maplibre-gl-shared.mjs", "maplibre-gl-worker.mjs"]) {
  cpSync(join(ml, f), join(dist, "static/js", f));
}

// Explorer (Flutter web build with --base-href /explorer/).
const explorer = join(root, "apps/explorer/build/web");
if (existsSync(join(explorer, "index.html"))) cpSync(explorer, join(dist, "explorer"), { recursive: true });
else console.warn("Explorer not built; /explorer/ will be missing");

// Docs: front matter (title, order) + Markdown body.
const template = readFileSync(join(src, "docs/template.html"), "utf8");
const pages = readdirSync(join(root, "docs"))
  .filter((f) => f.endsWith(".md") && f !== "ROADMAP.md")
  .map((file) => {
    const raw = readFileSync(join(root, "docs", file), "utf8");
    const fm = raw.match(/^---\n([\s\S]*?)\n---\n/);
    const meta = Object.fromEntries((fm?.[1] ?? "").split("\n").map((l) => l.split(/:\s*/, 2)));
    return { slug: file.replace(/\.md$/, ""), title: meta.title ?? file, order: Number(meta.order ?? 99), body: raw.slice(fm?.[0].length ?? 0) };
  })
  .sort((a, b) => a.order - b.order);

const escape = (s) => s.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
const slugify = (s) => s.toLowerCase().replace(/<[^>]+>/g, "").replace(/[^\p{L}\p{N}]+/gu, "-").replace(/^-|-$/g, "");

for (const page of pages) {
  const toc = [];
  const renderer = new marked.Renderer();
  renderer.heading = ({ tokens, depth }) => {
    const text = marked.Parser.parseInline(tokens);
    const id = slugify(text);
    if (depth === 2) toc.push(`<a href="#${id}">${text}</a>`);
    return `<h${depth} id="${id}"><a class="anchor" href="#${id}">${text}</a></h${depth}>`;
  };
  // Links between docs: flutter.md -> flutter.html; repo files -> GitHub.
  renderer.link = ({ href, title, tokens }) => {
    let url = href.replace(/^([a-z-]+)\.md(#.*)?$/, "$1.html$2");
    if (/^(\.\.\/|packages\/|apps\/|server\/)/.test(url)) url = `https://github.com/yehyatt/mapeleven/blob/main/${url.replace(/^\.\.\//, "")}`;
    const external = /^https?:/.test(url) && !url.includes("mapeleven.dev");
    return `<a href="${url}"${title ? ` title="${escape(title)}"` : ""}${external ? ' rel="noopener" target="_blank"' : ""}>${marked.Parser.parseInline(tokens)}</a>`;
  };
  const html = marked.parse(page.body, { renderer, gfm: true });
  const nav = pages
    .map((p) => `<a href="${p.slug}.html"${p.slug === page.slug ? ' aria-current="page"' : ""}>${escape(p.title)}</a>`)
    .join("\n");
  const out = template
    .replaceAll("{{title}}", escape(page.title))
    .replace("{{nav}}", nav)
    .replace("{{toc}}", toc.join("\n"))
    .replace("{{content}}", html)
    .replace("{{source}}", `https://github.com/yehyatt/mapeleven/blob/main/docs/${page.slug}.md`);
  writeFileSync(join(dist, "docs", `${page.slug}.html`), out);
}
writeFileSync(join(dist, "docs/index.html"), '<!doctype html><meta http-equiv="refresh" content="0; url=getting-started.html">');
console.log(`Built ${pages.length} docs pages into ${dist}`);
