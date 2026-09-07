# Implementation Plan: Homepage hero image performance

## Summary
Add pre-encoded AVIF and WebP versions of the existing hero and gallery, render them through semantic `<picture>` elements with PNG fallbacks, and defer the below-the-fold gallery images.

## Existing system findings
The public homepage is rendered by `Marketing::PagesController#home` and `app/views/marketing/pages/home.html.erb`. The hero is a fixed, full-viewport section with an inline CSS background. Production caching is already long-lived and digest-safe, so the primary issue is payload and discovery rather than cache configuration.

## Proposed design
Place an absolutely positioned decorative `<picture>` inside the existing hero section. Order AVIF, WebP, and PNG sources from smallest/modern to fallback. Preserve the existing overlay and content stacking. Add native lazy loading and asynchronous decoding to the gallery images below the fold.

## Data changes
None.

## Authorization
None; public presentation only.

## Implementation steps

### Step 1 — Add optimized hero assets
Files likely affected:
- `app/assets/images/hero_image.avif`
- `app/assets/images/hero_image.webp`
- `app/assets/images/home/bild_{1,2,3,4,5}.{avif,webp}`

Changes:
- Encode the existing source at visually appropriate quality while retaining 1920×1080 dimensions.

Why:
- Reduce cold-load transfer cost while keeping the current artwork and crop.

Verification:
- Inspect file types, dimensions, and byte sizes.

Dependencies:
- Existing `hero_image.png` source.

### Step 2 — Improve homepage discovery and prioritization
Files likely affected:
- `app/views/marketing/pages/home.html.erb`

Changes:
- Replace the CSS background with a decorative `<picture>` and eager, high-priority fallback image.
- Mark the static gallery images lazy and asynchronously decoded.

Why:
- Let the preload scanner discover the hero and prevent below-the-fold images from competing for initial bandwidth.

Verification:
- Integration HTML assertions and responsive browser inspection.

Dependencies:
- Step 1.

### Step 3 — Add regression coverage
Files likely affected:
- `test/controllers/cms_blocks_test.rb`

Changes:
- Assert modern hero sources, priority/loading attributes, and lazy gallery attributes.

Why:
- Prevent regression to a large late-discovered hero or eager gallery.

Verification:
- Run the focused test and the repository-required checks.

Dependencies:
- Step 2.

## Test plan
Use an integration response test for the generated markup, the full Rails suite for regressions, RuboCop, Brakeman, JavaScript tests, and responsive browser checks.

## Browser verification
Verify the hero at a desktop viewport and a narrow mobile viewport. Confirm it covers the first viewport and that text/gradient remain on top. Inspect the rendered source selection when possible.

## Risks
- Modern encoding may visibly degrade the image. Mitigation: use conservative quality settings and retain the PNG fallback/source.
- Replacing a background with an image could change stacking. Mitigation: keep the image absolutely positioned and verify both responsive layouts.

## Assumptions
- **CONFIRMED** — The hero is decorative; it previously had no accessible image semantics.
- **CONFIRMED** — There are no authorization, persistence, or external side-effect changes.
- **ASSUMED** — AVIF quality 65 and WebP quality 82 are visually sufficient for this photographic hero.

## Expected changed files
- `app/assets/images/hero_image.avif`
- `app/assets/images/hero_image.webp`
- `app/views/marketing/pages/home.html.erb`
- `test/controllers/cms_blocks_test.rb`
- This specification and plan.

## Definition of done
All acceptance criteria pass; optimized files are below 200 KB; responsive browser checks preserve composition; focused and full tests, lint, and security scan pass; final diff contains no unrelated changes.

## Final assessment
READY FOR IMPLEMENTATION
