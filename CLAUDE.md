# CLAUDE.md - kyte-web

## What this is

The Kyte promote site: the marketing home plus the full language guide, built with
[VitePress](https://vitepress.dev). This is a static site, not a Kyte package and not part of any build that
consumes Kyte. See [README.md](README.md) for the layout. It lives under `/Users/kamlesh/kytelang/`
alongside the other, separate Kyte repos (kyte, kynalyzer, kyte-vscode-extension).

## Build and serve

Prerequisites: Node.js and npm.

```bash
npm install      # once
npm run dev      # local dev server with hot reload (vitepress dev)
npm run build    # static build into .vitepress/dist (vitepress build)
npm run preview  # serve the built site (vitepress preview)
```

## Layout map

- `index.md` + `.vitepress/theme/` - the custom home and theme (styles in `theme/custom.css`).
- `guide/` - the language guide, chapters 01 to 24. These are a COPY; the canonical source is in the
  **kyte** repo under `docs/guide`, so substantive guide edits belong there and are mirrored here.
- `.vitepress/config.mts` - nav, the guide sidebar, and the syntax grammar wiring.
- `assets/` and `public/` - images, logos and illustrations served at the site root.

## Working in this repo (how to make a change)

1. Understand, then plan: read the relevant markdown or `.vitepress/` config before editing, and match the
   surrounding style.
2. Verify real behaviour: run `npm run dev` (or `npm run build` then `npm run preview`) and check the page
   actually renders, not just that the build passed.
3. For guide content, remember `guide/` is a copy of the **kyte** repo's `docs/guide`; fix the canonical
   source there when the change is substantive.
4. Commit only when asked; if you are on `main`, branch first. This is a docs/site repo and separate from the
   other Kyte repos.
5. Prose follows Indian English with British spellings and no em dashes.
