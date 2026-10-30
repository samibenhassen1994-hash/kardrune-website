# Summon Banner Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a framed, section-aware hero banner to the Flutter Summon page while preserving all existing controls and rules.

**Architecture:** Import only the approved Dren banner into the Flutter asset bundle. Keep selection state in the existing `SummonScreen`; render a dedicated framed banner widget whose artwork is nullable and changes with the existing `section` value.

**Tech Stack:** Flutter/Dart, widget tests, existing WebP asset pipeline.

**Spec:** `docs/superpowers/specs/2026-10-30-summon-banner-redesign-design.md`

## Global Constraints

- Do not change Summon costs, probabilities, callbacks, free-pull timing, notifications, or backend behavior.
- Do not invent artwork for Standard or Event.
- Preserve the existing player header, INFO popup, buttons, and labels.
- Avoid page-level vertical overflow at 320×568, 390×844, and 430×932.

## Review Focus

- Standard and Event must not accidentally reuse Dren artwork.
- Featured must display Dren artwork after switching tabs.
- Rapid tab changes must leave the banner matching the selected section.
- The framed banner must not hide or intercept INFO and summon buttons.
- Small viewports must retain access to every current action without overflow.

---

### Task 1: Framed section banner

**Files:**
- Create: `idle_flutter/assets/idle/summon/banners/Dren_banner.webp`
- Modify: `idle_flutter/lib/features/summon/summon_screen.dart`
- Modify: `idle_flutter/test/app_shell_test.dart`
- Modify: `idle_flutter/test/golden_test.dart`
- Modify: `idle_flutter/test/goldens/summon_390x844.png`

**Interfaces:**
- Consumes: existing `_SummonScreenState.section` values `0`, `1`, and `2`.
- Produces: a framed banner widget with nullable artwork; only section `1` maps to the Dren asset.

- [x] **Step 1: Add failing widget assertions**

Assert that the Summon page initially exposes a framed banner without a banner image, Featured exposes `Dren_banner.webp`, Event removes the image again, and the 320×568 layout reports no overflow.

- [x] **Step 2: Run the targeted tests and verify failure**

Run: `flutter test test/app_shell_test.dart`

Expected: FAIL because the new banner keys and Dren asset are absent.

- [x] **Step 3: Import the approved Dren asset**

Copy `assets/summon/banners/Dren_banner.webp` from `samibenhassen1994-hash/Idlekardrune-assets` to `idle_flutter/assets/idle/summon/banners/Dren_banner.webp` without adding Standard or Event artwork.

- [x] **Step 4: Implement the framed banner**

Add a private banner widget in `summon_screen.dart` that uses the existing section state, a gold fantasy frame, neutral artwork-free Standard/Event surfaces, `AnimatedSwitcher` fade behavior, and the Featured Dren asset. Rebalance only presentation sizing so existing actions remain reachable.

- [x] **Step 5: Run targeted tests**

Run: `flutter test test/app_shell_test.dart test/golden_test.dart`

Expected: PASS after intentionally updating the Summon golden.

- [x] **Step 6: Run verification**

Run: `flutter analyze`

Run: `flutter test`

Run: `flutter build web --release --base-href /idle/`

Expected: all commands succeed.

- [x] **Step 7: Commit**

Commit the asset, UI, tests, golden, spec, and plan in one focused commit.
