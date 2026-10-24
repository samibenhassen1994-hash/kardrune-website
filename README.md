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
