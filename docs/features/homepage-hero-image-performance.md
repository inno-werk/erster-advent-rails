# Feature: Homepage hero image performance

## Goal
Make the homepage hero appear promptly on a cold visit without changing its visual design.

## Actors
Public visitors to the marketing homepage on desktop and mobile devices.

## Current behavior
The hero uses `hero_image.png` as an inline CSS background. The deployed 1920×1080 PNG is 3,467,183 bytes, and the browser cannot discover it as an image element. The five below-the-fold gallery PNGs are also loaded eagerly.

## Desired behavior
The browser should discover and prioritize a substantially smaller modern-format hero immediately, retain compatible PNG fallbacks, and serve the deferred gallery in modern formats too.

## Functional requirements
- REQ-001 — Render the same hero artwork in AVIF and WebP, with the existing PNG as fallback.
- REQ-002 — Mark the hero as eager and high priority while preserving its decorative semantics and cover layout.
- REQ-003 — Lazy-load the five static gallery images below the hero and offer AVIF and WebP sources for each.
- REQ-004 — Preserve the existing page copy, overlays, responsive height, and navigation behavior.

## Acceptance criteria
- AC-001 — Given a browser with AVIF or WebP support, when it requests the homepage, then it can select a hero asset smaller than 200 KB.
- AC-002 — Given any supported browser, when it parses the homepage, then it finds a high-priority eager hero image with a PNG fallback.
- AC-003 — Given the initial homepage viewport, when the document is parsed, then the five static gallery images are marked for lazy loading.
- AC-004 — Given the homepage at desktop and mobile widths, when it renders, then the hero still fills the first viewport and the gradient and text remain visible above it.

## Authorization
None. The homepage is public and this change does not alter access control.

## Data and persistence
None.

## External side effects
None.

## Security and privacy
No new input, data exposure, external host, or active content is introduced.

## UI states
The PNG remains the compatibility/failure fallback. Intrinsic dimensions are supplied to the image, while CSS continues to size and crop it to the viewport.

## Edge cases
- Browsers without AVIF support can choose WebP; browsers without either modern format use PNG.
- Cold-cache visits benefit from the reduced payload; digest-stamped production assets retain the existing one-year cache policy.

## Compatibility / migration
Additive asset rollout only. Rollback consists of restoring the CSS background markup; no data migration is required.

## Out of scope
CMS-uploaded image variants, CDN changes, and redesigning or recropping the artwork.

## Evidence
- **CONFIRMED** — `app/assets/images/hero_image.png` is 1920×1080 and about 3.3 MiB locally; production reports a 3,467,183-byte response.
- **CONFIRMED** — `app/views/marketing/pages/home.html.erb` uses the hero as a CSS background and eagerly renders five gallery PNGs.
- **CONFIRMED** — production sends digest-stamped assets with a one-year public cache header.
- **ASSUMED** — preserving the current artwork and crop is preferable to introducing a mobile-specific art direction.

## Open questions
### BLOCKING
None.

### NON-BLOCKING
None. The conservative default is to keep the original PNG as fallback and preserve the existing crop.

## Requirement-to-verification matrix
| Requirement | Acceptance criteria | Verification approach |
|---|---|---|
| REQ-001 | AC-001, AC-002 | Asset size check and integration HTML assertions |
| REQ-002 | AC-002, AC-004 | Integration assertions and responsive browser checks |
| REQ-003 | AC-003 | Integration HTML assertions |
| REQ-004 | AC-004 | Existing test suite and responsive browser checks |

## Final assessment
READY FOR PLANNING
