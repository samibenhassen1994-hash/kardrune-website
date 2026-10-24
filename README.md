# KardRune Website

Static, responsive landing site for KardRune built with plain HTML/CSS/JS and the supplied game assets.

## Local preview

From this folder:

```bash
python -m http.server 8080
```

Then open `http://localhost:8080`.

## Cloudflare Pages

This project does not require a build step.

- Framework preset: `None`
- Build command: leave empty
- Build output directory: `/` (repository root)

Connect the GitHub repository to Cloudflare Pages and every push can redeploy the site automatically.

## Main sections

- Hero / game identity
- D20 dice-roll combat (includes `d20.glb` via `<model-viewer>`)
- Hero evolution
- Real-time PvP Conquest
- Hero roster
- Gacha / Summon banners
- World / story videos
- Enemies / Vaelor
- Mobile CTA

## Note on the 3D D20

The site loads Google's `<model-viewer>` component from a public CDN. The supplied `d20.glb` is included locally. If the CDN is unavailable, the section still retains the supplied dice artwork as a visual fallback.

## KardRune Playground (static browser tools)

The website includes seven SEO-friendly pages: `playground.html`, `dice-roller.html`, `gacha-calculator.html`, `card-creator.html`, `battle-simulator.html`, `loot-generator.html`, and `heroes-wiki.html`. Each page has a canonical URL, meta description, static explanatory content and internal links. Tools share `playground.css` and `playground.js`, require no server or build, and reuse the existing `assets/` image catalog. User-uploaded card pictures stay in the browser. Browser simulators are illustrative and never affect player accounts or in-game balances.

To preview: `python -m http.server 8080` then navigate to `http://localhost:8080/playground.html`.

## Playground 2 — Shared game art (2026-10-24)

The game art library includes 289 optimized artwork previews, deduplicated into seven tiled WebP atlases (`assets/playground/atlas-*.webp`). All image paths and atlas coordinates are indexed in `game-assets.json`. Every public Playground tool uses the shared `playground-experience.js` to show different appropriate assets, including hero stage selector, gacha reveals, custom card presets, loot icons, the turn-based battle simulator, and the searchable Art Library (`art-library.html`).

The D20 animation uses the user's actual `dice_comparison/kr_v2` frame sheets: `d20-spin.webp` (6x5 = 30 frames) and `d20-settle_01.webp … d20-settle_20.webp` (6x4 = 24 frames each), with official face outcomes from secure browser RNG when available. D4/D6/D8/D10/D12/D100 remain numeric.

Audio and cinematic videos are intentionally excluded from the site to avoid ~130 MB in unnecessary downloads. Those remain in the Flutter game and are summarized in `game-media-inventory.json` (local pipeline only). The public site is free/static and requires no backend.
