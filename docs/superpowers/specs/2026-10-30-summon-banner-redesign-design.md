# Summon Banner Redesign

## Intent

Make the Flutter Summon page feel like a polished KardRune summon screen by giving the selected summon type a large, framed banner area. Preserve every current action, label, probability, timer, cost, and summon rule.

## Approved design

- Place a large banner area below the existing player header and above the existing summon information/actions.
- Give the banner area a fantasy gold frame consistent with the current KardRune palette.
- Featured uses `assets/summon/banners/Dren_banner.webp` from `samibenhassen1994-hash/Idlekardrune-assets`.
- Standard and Event intentionally show no artwork until their final images are supplied; use only the neutral framed surface and section name, without invented imagery.
- Switching Standard, Featured, or Event updates the large banner with a restrained fade transition.
- Keep the existing INFO popup, free-pull count and timer, notification behavior, costs, probabilities, enabled states, and summon callbacks unchanged.
- Keep the page responsive on small iPhone viewports without page-level vertical overflow.

## Approaches considered

1. **One large selected banner (chosen):** maximizes the supplied art and leaves the controls readable on mobile.
2. Large banner plus three image thumbnails: richer navigation but consumes too much vertical space on small phones.

## Non-goals

- No new Standard or Event artwork.
- No economy, probability, backend, notification, or summon-result changes.
- No redesign of other screens.
